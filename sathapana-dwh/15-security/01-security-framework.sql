-- ============================================================================
-- SATHAPANA BANK - SECURITY FRAMEWORK
-- ============================================================================
-- Purpose: Create role-based access control and data masking
-- Author: DWH Development Team
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. CREATE DATABASE ROLES
-- ============================================================================

-- DWH Administrator Role
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'DWH_Admin')
BEGIN
    CREATE ROLE DWH_Admin;
    PRINT '✓ DWH_Admin role created';
END
GO

-- ETL Service Account Role
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'ETL_Service')
BEGIN
    CREATE ROLE ETL_Service;
    PRINT '✓ ETL_Service role created';
END
GO

-- BI Analyst Role (Read-only)
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'BI_Analyst')
BEGIN
    CREATE ROLE BI_Analyst;
    PRINT '✓ BI_Analyst role created';
END
GO

-- Data Steward Role
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Data_Steward')
BEGIN
    CREATE ROLE Data_Steward;
    PRINT '✓ Data_Steward role created';
END
GO

-- Compliance Officer Role
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Compliance_Officer')
BEGIN
    CREATE ROLE Compliance_Officer;
    PRINT '✓ Compliance_Officer role created';
END
GO

-- Auditor Role (Read-only + Audit)
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Auditor')
BEGIN
    CREATE ROLE Auditor;
    PRINT '✓ Auditor role created';
END
GO

-- ============================================================================
-- 2. GRANT PERMISSIONS
-- ============================================================================

-- DWH_Admin: Full control
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dw TO DWH_Admin;
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::audit TO DWH_Admin;
GRANT CONTROL ON DATABASE::sathapana_dwh TO DWH_Admin;
PRINT '✓ DWH_Admin permissions granted';

-- ETL_Service: Read/Write on ETL schemas
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dw TO ETL_Service;
GRANT SELECT ON SCHEMA::audit TO ETL_Service;
GRANT EXECUTE ON SCHEMA::dw TO ETL_Service;
PRINT '✓ ETL_Service permissions granted';

-- BI_Analyst: Read-only on dimensions and facts
GRANT SELECT ON SCHEMA::dw TO BI_Analyst;
DENY DELETE, INSERT, UPDATE ON SCHEMA::dw TO BI_Analyst;
PRINT '✓ BI_Analyst permissions granted';

-- Data_Steward: Read/Write on dimensions, Read on facts
GRANT SELECT, UPDATE ON dw.dim_customer TO Data_Steward;
GRANT SELECT, UPDATE ON dw.dim_account TO Data_Steward;
GRANT SELECT, UPDATE ON dw.dim_branch TO Data_Steward;
GRANT SELECT ON SCHEMA::dw TO Data_Steward;
PRINT '✓ Data_Steward permissions granted';

-- Compliance_Officer: Read on compliance-related tables
GRANT SELECT ON dw.dim_customer TO Compliance_Officer;
GRANT SELECT ON dw.fact_transactions TO Compliance_Officer;
GRANT SELECT ON SCHEMA::audit TO Compliance_Officer;
PRINT '✓ Compliance_Officer permissions granted';

-- Auditor: Read-only on everything + audit logs
GRANT SELECT ON SCHEMA::dw TO Auditor;
GRANT SELECT ON SCHEMA::audit TO Auditor;
PRINT '✓ Auditor permissions granted';

-- ============================================================================
-- 3. ROW-LEVEL SECURITY (Branch-based)
-- ============================================================================

-- Create security predicate function
CREATE OR ALTER FUNCTION dw.fn_SecurityPredicateBranch(@branch_key INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS has_access
    WHERE 
        -- Admins see everything
        IS_MEMBER('DWH_Admin') = 1
        OR
        -- Others see only their branch (simulated)
        @branch_key IN (
            SELECT branch_key 
            FROM dw.vw_user_branch_access 
            WHERE user_name = SYSTEM_USER
        )
);
GO

-- Create security policy
CREATE OR ALTER SECURITY POLICY BranchFilterPolicy
ADD FILTER PREDICATE dw.fn_SecurityPredicateBranch(branch_key) ON dw.fact_transactions,
ADD FILTER PREDICATE dw.fn_SecurityPredicateBranch(branch_key) ON dw.fact_loan_portfolio,
ADD FILTER PREDICATE dw.fn_SecurityPredicateBranch(branch_key) ON dw.fact_deposit_snapshot
WITH (STATE = OFF);  -- Enable when ready
GO

PRINT '✓ Row-level security created (disabled by default)';

-- ============================================================================
-- 4. COLUMN-LEVEL SECURITY (Sensitive Data)
-- ============================================================================

-- Create view with masked columns for non-privileged users
CREATE OR ALTER VIEW dw.vw_customer_masked AS
SELECT 
    customer_key,
    customer_code,
    -- Masked columns
    CONCAT(LEFT(first_name, 1), '****') AS first_name_masked,
    CONCAT(LEFT(last_name, 1), '****') AS last_name_masked,
    customer_type,
    customer_segment,
    -- Visible columns
    province,
    district,
    gender,
    age,
    risk_rating,
    kyc_status,
    is_active
    -- Hidden: national_id, passport_number, phone, email, address
FROM dw.dim_customer
WHERE is_current = 1;
GO

PRINT '✓ Column-level security view created';

-- ============================================================================
-- 5. AUDIT TRAIL FOR SENSITIVE ACCESS
-- ============================================================================

CREATE TABLE audit.sensitive_access_log (
    access_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    user_name           VARCHAR(100) NOT NULL,
    table_name          VARCHAR(100) NOT NULL,
    access_type         VARCHAR(20) NOT NULL,
    query_text          NVARCHAR(MAX),
    access_time         DATETIME DEFAULT GETDATE(),
    ip_address          VARCHAR(45)
);

-- Create trigger for sensitive table access
CREATE OR ALTER TRIGGER trg_AuditCustomerAccess
ON dw.dim_customer
AFTER SELECT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Log access to sensitive customer data
    INSERT INTO audit.sensitive_access_log (user_name, table_name, access_type)
    SELECT SYSTEM_USER, 'dim_customer', 'SELECT';
END
GO

PRINT '✓ Audit trail for sensitive access created';

-- ============================================================================
-- 6. DATABASE ENCRYPTION (Transparent Data Encryption)
-- ============================================================================

-- Note: TDE requires Enterprise Edition
-- This is a placeholder for reference

/*
-- Create master key (run once)
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStrongPassword123!';

-- Create certificate
CREATE CERTIFICATE DWH_TDECert
WITH SUBJECT = 'DWH TDE Certificate';

-- Backup certificate (IMPORTANT!)
BACKUP CERTIFICATE DWH_TDECert
TO FILE = 'C:\Backup\DWH_TDECert.cer'
WITH PRIVATE KEY (
    FILE = 'C:\Backup\DWH_TDECert.pvk',
    ENCRYPTION BY PASSWORD = 'YourStrongPassword123!'
);

-- Create database encryption key
USE sathapana_dwh;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE DWH_TDECert;

-- Enable TDE
ALTER DATABASE sathapana_dwh SET ENCRYPTION ON;
*/

PRINT '✓ TDE setup documented (requires Enterprise Edition)';

-- ============================================================================
-- 7. PASSWORD POLICY (for SQL Logins)
-- ============================================================================

/*
-- Enforce password policy
ALTER LOGIN [ETL_Service_Account]
WITH CHECK_POLICY = ON,
     CHECK_EXPIRATION = ON,
     DEFAULT_DATABASE = sathapana_dwh;
*/

PRINT '✓ Password policy documented';

-- ============================================================================
-- 8. VERIFY SECURITY SETUP
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'SECURITY FRAMEWORK CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Roles Created:';
SELECT name AS role_name, type_desc 
FROM sys.database_principals 
WHERE type = 'R' AND is_fixed_role = 0;
PRINT '';
PRINT 'Security Policies:';
SELECT name, is_enabled 
FROM sys.security_policies;
PRINT '';
PRINT '================================================';
GO
