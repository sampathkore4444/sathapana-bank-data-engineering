# 🔐 Security Framework Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Security Architecture](#2-security-architecture)
3. [Role-Based Access Control](#3-role-based-access-control)
4. [Data Classification](#4-data-classification)
5. [Row-Level Security](#5-row-level-security)
6. [Data Masking](#6-data-masking)
7. [Encryption](#7-encryption)
8. [Audit Logging](#8-audit-logging)
9. [Compliance Requirements](#9-compliance-requirements)

---

## 1. Overview

Security is critical for banking data warehouses containing sensitive customer and financial information.

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 1. AUTHENTICATION                                        │    │
│    │  Who are you? (Windows Auth / SQL Auth)               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 2. AUTHORIZATION                                         │    │
│    │  What can you do? (RBAC, Permissions)                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 3. DATA PROTECTION                                       │    │
│    │  How is data protected? (Encryption, Masking)         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 4. AUDIT & COMPLIANCE                                    │    │
│    │  Who accessed what? (Audit Logs)                      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Security Architecture

### Security Zones

```sql
-- Create security schema
CREATE SCHEMA security;
GO

-- Security configuration table
CREATE TABLE security.security_config (
    config_id INT IDENTITY(1,1) PRIMARY KEY,
    config_name VARCHAR(100),
    config_value NVARCHAR(500),
    description NVARCHAR(500),
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE()
);

-- Insert security settings
INSERT INTO security.security_config (config_name, config_value, description)
VALUES
    ('PASSWORD_POLICY', 'Complex', 'Minimum 8 chars, special chars required'),
    ('SESSION_TIMEOUT', '30', 'Minutes before session expires'),
    ('MAX_LOGIN_ATTEMPTS', '5', 'Lock account after 5 failed attempts'),
    ('AUDIT_RETENTION_DAYS', '365', 'Keep audit logs for 1 year'),
    ('DATA_MASKING_ENABLED', '1', 'Enable dynamic data masking');
```

---

## 3. Role-Based Access Control (RBAC)

### Create Roles

```sql
-- ============================================================
-- BANKING DWH ROLES
-- ============================================================

-- 1. DWH Administrator (Full Control)
CREATE ROLE DWH_Admin;

-- 2. ETL Service Account (Read/Write to staging & DW)
CREATE ROLE ETL_Service;

-- 3. BI Analyst (Read only to DW and Marts)
CREATE ROLE BI_Analyst;

-- 4. Data Steward (Read/Write to specific tables)
CREATE ROLE Data_Steward;

-- 5. Compliance Officer (Read + Export)
CREATE ROLE Compliance_Officer;

-- 6. Auditor (Read only + Audit logs)
CREATE ROLE Auditor;

-- 7. Branch User (Read own branch data only)
CREATE ROLE Branch_User;

-- 8. Report Viewer (Read only to marts)
CREATE ROLE Report_Viewer;
```

### Grant Permissions

```sql
-- ============================================================
-- PERMISSIONS BY ROLE
-- ============================================================

-- DWH Admin: Full control
USE sathapana_dwh;
GO
ALTER ROLE DWH_Admin ADD MEMBER db_owner;

-- ETL Service: Read/Write to ETL schemas
USE sathapana_staging;
GO
ALTER ROLE ETL_Service ADD MEMBER db_datareader;
ALTER ROLE ETL_Service ADD MEMBER db_datawriter;

USE sathapana_dwh;
GO
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dw TO ETL_Service;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::audit TO ETL_Service;

-- BI Analyst: Read only
USE sathapana_dwh;
GO
GRANT SELECT ON SCHEMA::dw TO BI_Analyst;
GRANT SELECT ON SCHEMA::audit TO BI_Analyst;

-- Compliance Officer: Read + Export
USE sathapana_dwh;
GO
GRANT SELECT ON SCHEMA::dw TO Compliance_Officer;
GRANT SELECT ON SCHEMA::audit TO Compliance_Officer;
GRANT VIEW DEFINITION ON SCHEMA::dw TO Compliance_Officer;

-- Auditor: Read only to audit tables
USE sathapana_dwh;
GO
GRANT SELECT ON SCHEMA::audit TO Auditor;
GRANT VIEW DEFINITION ON SCHEMA::audit TO Auditor;

-- Report Viewer: Read only to data marts
USE sathapana_dm_credit;
GO
GRANT SELECT ON SCHEMA::dm TO Report_Viewer;

USE sathapana_dm_customer;
GO
GRANT SELECT ON SCHEMA::dm TO Report_Viewer;
```

### User Management

```sql
-- ============================================================
-- USER MANAGEMENT PROCEDURES
-- ============================================================

CREATE PROCEDURE security.usp_CreateUser
    @Username NVARCHAR(100),
    @Role NVARCHAR(50),
    @Database NVARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Create login
    SET @SQL = 'CREATE LOGIN [' + @Username + '] FROM WINDOWS WITH DEFAULT_DATABASE=[' + @Database + ']';
    EXEC sp_executesql @SQL;
    
    -- Create user in database
    SET @SQL = 'USE [' + @Database + ']; CREATE USER [' + @Username + '] FOR LOGIN [' + @Username + ']';
    EXEC sp_executesql @SQL;
    
    -- Add to role
    SET @SQL = 'USE [' + @Database + ']; ALTER ROLE [' + @Role + '] ADD MEMBER [' + @Username + ']';
    EXEC sp_executesql @SQL;
    
    PRINT 'User ' + @Username + ' created with role ' + @Role;
END;
GO

-- Usage
EXEC security.usp_CreateUser @Username = 'DOMAIN\john.doe', @Role = 'BI_Analyst', @Database = 'sathapana_dwh';
```

---

## 4. Data Classification

### Classification Levels

| Level | Description | Examples | Protection |
|-------|-------------|----------|------------|
| **Public** | Non-sensitive | Branch names, product names | None |
| **Internal** | Business data | Transaction amounts, balances | Access control |
| **Confidential** | PII data | Customer names, IDs, emails | Encryption + Masking |
| **Restricted** | Highly sensitive | AML alerts, sanctions | Full audit + Encryption |

### Classification Table

```sql
CREATE TABLE security.data_classification (
    classification_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name VARCHAR(200),
    column_name VARCHAR(100),
    classification_level VARCHAR(20), -- PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
    contains_pii BIT DEFAULT 0,
    contains_financial BIT DEFAULT 0,
    masking_type VARCHAR(50), -- NONE, PARTIAL, FULL, HASH
    encryption_required BIT DEFAULT 0,
    audit_access BIT DEFAULT 0,
    created_date DATETIME DEFAULT GETDATE()
);

-- Classify customer table
INSERT INTO security.data_classification 
(table_name, column_name, classification_level, contains_pii, masking_type, audit_access)
VALUES
('dim_customer', 'customer_code', 'INTERNAL', 0, 'NONE', 0),
('dim_customer', 'first_name', 'CONFIDENTIAL', 1, 'PARTIAL', 1),
('dim_customer', 'last_name', 'CONFIDENTIAL', 1, 'PARTIAL', 1),
('dim_customer', 'email', 'CONFIDENTIAL', 1, 'PARTIAL', 1),
('dim_customer', 'phone', 'CONFIDENTIAL', 1, 'PARTIAL', 1),
('dim_customer', 'national_id', 'RESTRICTED', 1, 'FULL', 1),
('fact_transactions', 'amount', 'INTERNAL', 0, 'NONE', 0),
('fact_aml_alerts', 'alert_code', 'RESTRICTED', 0, 'NONE', 1);
```

---

## 5. Row-Level Security (RLS)

### Branch-Based Security

```sql
-- ============================================================
-- ROW-LEVEL SECURITY FOR BRANCH DATA
-- ============================================================

-- User-branch mapping table
CREATE TABLE security.user_branch_access (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    username NVARCHAR(100),
    branch_code VARCHAR(20),
    access_level VARCHAR(20), -- READ, READ_WRITE
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE()
);

-- Insert sample access
INSERT INTO security.user_branch_access (username, branch_code, access_level)
VALUES
('DOMAIN\branch_manager_001', 'BR001', 'READ_WRITE'),
('DOMAIN\branch_user_001', 'BR001', 'READ'),
('DOMAIN\regional_manager', 'ALL', 'READ_WRITE');

-- Security predicate function
CREATE FUNCTION security.fn_BranchAccessPredicate(@branch_code VARCHAR(20))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS result
WHERE 
    -- Admin sees all
    IS_MEMBER('DWH_Admin') = 1
    OR
    -- Regional manager sees all
    EXISTS (
        SELECT 1 FROM security.user_branch_access
        WHERE username = SYSTEM_USER
        AND branch_code = 'ALL'
    )
    OR
    -- User sees own branch
    EXISTS (
        SELECT 1 FROM security.user_branch_access
        WHERE username = SYSTEM_USER
        AND branch_code = @branch_code
        AND is_active = 1
    );
GO

-- Apply security policy to fact_transactions
CREATE SECURITY POLICY security.BranchFilterPolicy
ADD FILTER PREDICATE security.fn_BranchAccessPredicate(branch_code) ON dw.fact_transactions
WITH (STATE = ON);
```

---

## 6. Data Masking

### Dynamic Data Masking

```sql
-- ============================================================
-- DYNAMIC DATA MASKING
-- ============================================================

-- Partial mask (show first 2 characters)
ALTER TABLE dw.dim_customer
ALTER COLUMN first_name ADD MASKED WITH (FUNCTION = 'partial(2,"XXX",0)');

ALTER TABLE dw.dim_customer
ALTER COLUMN last_name ADD MASKED WITH (FUNCTION = 'partial(2,"XXX",0)');

-- Email mask
ALTER TABLE dw.dim_customer
ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');

-- Phone mask
ALTER TABLE dw.dim_customer
ALTER COLUMN phone ADD MASKED WITH (FUNCTION = 'partial(4,"XXXX",4)');

-- Full mask (hide completely)
ALTER TABLE dw.dim_customer
ALTER COLUMN national_id ADD MASKED WITH (FUNCTION = 'default()');

-- Custom mask
ALTER TABLE dw.dim_customer
ALTER COLUMN address ADD MASKED WITH (FUNCTION = 'partial(0,"XXX",0)');

-- Grant UNMASK permission to specific roles
GRANT UNMASK TO DWH_Admin;
GRANT UNMASK TO Compliance_Officer;
```

---

## 7. Encryption

### Transparent Data Encryption (TDE)

```sql
-- ============================================================
-- TRANSPARENT DATA ENCRYPTION (TDE)
-- ============================================================

-- Create master key
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStr0ngP@ssw0rd!';

-- Create certificate
CREATE CERTIFICATE TDECert WITH SUBJECT = 'TDE Certificate';

-- Backup certificate (IMPORTANT!)
BACKUP CERTIFICATE TDECert
TO FILE = 'C:\Backup\TDECert.cer'
WITH PRIVATE KEY (
    FILE = 'C:\Backup\TDECert.pvk',
    ENCRYPTION BY PASSWORD = 'AnotherStr0ngP@ss!'
);

-- Enable TDE on database
USE sathapana_dwh;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE TDECert;

ALTER DATABASE sathapana_dwh SET ENCRYPTION ON;
```

### Column-Level Encryption

```sql
-- ============================================================
-- COLUMN-LEVEL ENCRYPTION (for sensitive columns)
-- ============================================================

-- Create database master key
USE sathapana_dwh;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStr0ngP@ssw0rd!';

-- Create symmetric key
CREATE SYMMETRIC KEY CustomerDataKey
WITH ALGORITHM = AES_256
ENCRYPTION BY MASTER KEY;

-- Open key and encrypt column
OPEN SYMMETRIC KEY CustomerDataKey
DECRYPTION BY MASTER KEY;

-- Encrypt national_id
UPDATE dw.dim_customer
SET national_id_encrypted = EncryptByKey(Key_GUID('CustomerDataKey'), national_id);

-- Decrypt for authorized users
SELECT 
    customer_code,
    CONVERT(VARCHAR, DecryptByKey(national_id_encrypted)) AS national_id
FROM dw.dim_customer;
```

---

## 8. Audit Logging

### Security Audit Table

```sql
CREATE TABLE security.audit_log (
    audit_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    event_time DATETIME DEFAULT GETDATE(),
    event_type VARCHAR(50), -- LOGIN, LOGOUT, SELECT, INSERT, UPDATE, DELETE
    database_name VARCHAR(100),
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    username NVARCHAR(100),
    host_name NVARCHAR(100),
    app_name NVARCHAR(100),
    query_text NVARCHAR(MAX),
    rows_affected BIGINT
);

-- Audit trigger for sensitive tables
CREATE TRIGGER trg_AuditCustomerAccess
ON dw.dim_customer
AFTER SELECT, INSERT, UPDATE, DELETE
AS
BEGIN
    INSERT INTO security.audit_log (
        event_type, database_name, schema_name, table_name,
        username, host_name, app_name
    )
    VALUES (
        CASE 
            WHEN EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted) THEN 'UPDATE'
            WHEN EXISTS(SELECT * FROM inserted) THEN 'INSERT'
            WHEN EXISTS(SELECT * FROM deleted) THEN 'DELETE'
            ELSE 'SELECT'
        END,
        DB_NAME(),
        'dw',
        'dim_customer',
        SYSTEM_USER,
        HOST_NAME(),
        APP_NAME()
    );
END;
```

### Audit Queries

```sql
-- View recent access
SELECT TOP 100 *
FROM security.audit_log
ORDER BY event_time DESC;

-- View access by user
SELECT 
    username,
    COUNT(*) AS access_count,
    MIN(event_time) AS first_access,
    MAX(event_time) AS last_access
FROM security.audit_log
WHERE event_time >= DATEADD(DAY, -7, GETDATE())
GROUP BY username
ORDER BY access_count DESC;

-- View sensitive table access
SELECT *
FROM security.audit_log
WHERE table_name IN ('dim_customer', 'fact_aml_alerts')
AND event_time >= DATEADD(DAY, -1, GETDATE())
ORDER BY event_time DESC;
```

---

## 9. Compliance Requirements

### NBC (National Bank of Cambodia) Requirements

| Requirement | Implementation |
|-------------|----------------|
| Data confidentiality | Encryption, masking |
| Access control | RBAC, RLS |
| Audit trail | Audit logging |
| Data retention | Backup policies |
| Incident response | Monitoring, alerts |

### Compliance Checklist

```markdown
## Compliance Checklist

### Data Protection
- [ ] TDE enabled on all databases
- [ ] Sensitive columns encrypted
- [ ] Data masking applied to PII
- [ ] Backup encryption enabled

### Access Control
- [ ] RBAC implemented
- [ ] Row-level security configured
- [ ] Service accounts limited
- [ ] Regular access reviews

### Audit & Monitoring
- [ ] Audit logging enabled
- [ ] Login monitoring active
- [ ] Sensitive access alerts
- [ ] Audit log retention configured

### Data Governance
- [ ] Data classification complete
- [ ] Data lineage documented
- [ ] Retention policies defined
- [ ] Disposal procedures documented
```

---

## Quick Reference

### Security Commands
```sql
-- Check user permissions
SELECT * FROM fn_my_permissions(NULL, 'DATABASE');

-- Check role members
SELECT 
    r.name AS role_name,
    m.name AS member_name
FROM sys.database_role_members rm
JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id;

-- Check object permissions
SELECT 
    grantee_principal_id,
    permission_name,
    state_desc
FROM sys.database_permissions
WHERE major_id = OBJECT_ID('dw.dim_customer');
```

---

*Created: September 2024*
*Sathapana Bank Data Engineering Project*
