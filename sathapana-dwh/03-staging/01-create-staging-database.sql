-- ============================================================================
-- SATHAPANA BANK - STAGING DATABASE CREATION
-- ============================================================================
-- Purpose: Create the staging database for data cleansing and transformation
-- Database: sathapana_staging
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

-- ============================================================================
-- 1. CREATE DATABASE
-- ============================================================================
USE master;
GO

-- Drop database if exists (for development/testing)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_staging')
BEGIN
    ALTER DATABASE sathapana_staging SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_staging;
END
GO

-- Create the staging database
CREATE DATABASE sathapana_staging
ON PRIMARY (
    NAME = 'sathapana_staging_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_staging_dat.mdf',
    SIZE = 200MB,
    MAXSIZE = 10GB,
    FILEGROWTH = 100MB
)
LOG ON (
    NAME = 'sathapana_staging_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_staging_log.ldf',
    SIZE = 100MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 50MB
);
GO

USE sathapana_staging;
GO

-- ============================================================================
-- 2. CREATE SCHEMA
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO

-- ============================================================================
-- 3. CREATE CONTROL TABLE FOR ETL METADATA
-- ============================================================================
CREATE TABLE staging.etl_control (
    control_id          INT IDENTITY(1,1) PRIMARY KEY,
    source_system       VARCHAR(50) NOT NULL,
    source_table        VARCHAR(100) NOT NULL,
    extract_query       NVARCHAR(MAX),
    last_extract_date   DATETIME,
    last_extract_key    BIGINT,
    row_count           BIGINT,
    status              VARCHAR(20) DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'EXTRACTING', 'EXTRACTED', 'TRANSFORMING', 'TRANSFORMED', 'LOADING', 'LOADED', 'FAILED')),
    error_message       NVARCHAR(MAX),
    start_time          DATETIME,
    end_time            DATETIME,
    duration_seconds    AS DATEDIFF(SECOND, start_time, end_time),
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE()
);

-- ============================================================================
-- 4. CREATE STAGING TABLES - BRANCHES
-- ============================================================================
CREATE TABLE staging.stg_branches (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    branch_code         VARCHAR(10),
    branch_name         NVARCHAR(200),
    branch_name_kh      NVARCHAR(200),
    branch_type         VARCHAR(20),
    region              VARCHAR(50),
    province            VARCHAR(100),
    district            VARCHAR(100),
    commune             NVARCHAR(200),
    village             NVARCHAR(200),
    address             NVARCHAR(500),
    phone               VARCHAR(20),
    email               VARCHAR(100),
    manager_code        VARCHAR(20),
    is_active           BIT,
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 5. CREATE STAGING TABLES - EMPLOYEES
-- ============================================================================
CREATE TABLE staging.stg_employees (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    employee_code       VARCHAR(20),
    national_id         VARCHAR(20),
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    date_of_birth       DATE,
    gender              CHAR(1),
    email               VARCHAR(100),
    phone               VARCHAR(20),
    hire_date           DATE,
    termination_date    DATE,
    job_title           NVARCHAR(200),
    department          VARCHAR(100),
    branch_code         VARCHAR(10),
    reports_to_code     VARCHAR(20),
    salary_grade        VARCHAR(10),
    is_active           BIT,
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'HR_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 6. CREATE STAGING TABLES - CUSTOMERS
-- ============================================================================
CREATE TABLE staging.stg_customers (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    customer_code       VARCHAR(20),
    customer_type       VARCHAR(20),
    title               VARCHAR(10),
    first_name          NVARCHAR(200),
    last_name           NVARCHAR(200),
    company_name        NVARCHAR(500),
    national_id_type    VARCHAR(20),
    national_id         VARCHAR(30),
    passport_number     VARCHAR(30),
    date_of_birth       DATE,
    gender              CHAR(1),
    nationality         VARCHAR(50),
    email               VARCHAR(100),
    phone_primary       VARCHAR(20),
    phone_secondary     VARCHAR(20),
    address_line1       NVARCHAR(300),
    address_line2       NVARCHAR(300),
    province            VARCHAR(100),
    district            VARCHAR(100),
    commune             NVARCHAR(200),
    village             NVARCHAR(200),
    postal_code         VARCHAR(10),
    customer_segment    VARCHAR(50),
    risk_rating         VARCHAR(20),
    kyc_status          VARCHAR(20),
    kyc_verified_date   DATE,
    kyc_expiry_date     DATE,
    tax_id              VARCHAR(30),
    employer_name       NVARCHAR(300),
    occupation          VARCHAR(100),
    annual_income       DECIMAL(18,2),
    marital_status      VARCHAR(20),
    referrer_code       VARCHAR(20),
    acquisition_channel VARCHAR(50),
    opening_branch_code VARCHAR(10),
    is_active           BIT,
    is_pep              BIT,
    is_sanctioned       BIT,
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 7. CREATE STAGING TABLES - PRODUCTS
-- ============================================================================
CREATE TABLE staging.stg_products (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    product_code        VARCHAR(20),
    product_name        NVARCHAR(200),
    product_name_kh     NVARCHAR(200),
    product_category    VARCHAR(50),
    product_subcategory VARCHAR(100),
    gl_account_code     VARCHAR(20),
    currency            VARCHAR(3),
    interest_rate       DECIMAL(10,6),
    min_balance         DECIMAL(18,2),
    max_balance         DECIMAL(18,2),
    min_amount          DECIMAL(18,2),
    max_amount          DECIMAL(18,2),
    term_months         INT,
    is_active           BIT,
    effective_date      DATE,
    expiry_date         DATE,
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'PRODUCT_CATALOG',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 8. CREATE STAGING TABLES - ACCOUNTS
-- ============================================================================
CREATE TABLE staging.stg_accounts (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    account_number      VARCHAR(30),
    customer_code       VARCHAR(20),
    product_code        VARCHAR(20),
    branch_code         VARCHAR(10),
    currency            VARCHAR(3),
    account_type        VARCHAR(20),
    account_status      VARCHAR(20),
    open_date           DATE,
    close_date          DATE,
    maturity_date       DATE,
    balance             DECIMAL(18,2),
    available_balance   DECIMAL(18,2),
    hold_amount         DECIMAL(18,2),
    credit_limit        DECIMAL(18,2),
    interest_rate       DECIMAL(10,6),
    last_transaction_date DATE,
    dormant_date        DATE,
    is_active           BIT,
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 9. CREATE STAGING TABLES - TRANSACTIONS
-- ============================================================================
CREATE TABLE staging.stg_transactions (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    transaction_code    VARCHAR(30),
    account_number      VARCHAR(30),
    customer_code       VARCHAR(20),
    transaction_type    VARCHAR(30),
    transaction_channel VARCHAR(30),
    transaction_date    DATETIME,
    value_date          DATE,
    amount              DECIMAL(18,2),
    currency            VARCHAR(3),
    exchange_rate       DECIMAL(10,6),
    balance_before      DECIMAL(18,2),
    balance_after       DECIMAL(18,2),
    fee_amount          DECIMAL(18,2),
    tax_amount          DECIMAL(18,2),
    description         NVARCHAR(500),
    reference_number    VARCHAR(30),
    counterparty_account VARCHAR(30),
    counterparty_bank   VARCHAR(100),
    status              VARCHAR(20),
    posted_by_code      VARCHAR(20),
    authorized_by_code  VARCHAR(20),
    branch_code         VARCHAR(10),
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- Create index for transactions
CREATE INDEX IX_stg_Transactions_Account ON staging.stg_transactions(account_number);
CREATE INDEX IX_stg_Transactions_Date ON staging.stg_transactions(transaction_date);
CREATE INDEX IX_stg_Transactions_Batch ON staging.stg_transactions(batch_id);

-- ============================================================================
-- 10. CREATE STAGING TABLES - LOANS
-- ============================================================================
CREATE TABLE staging.stg_loans (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    loan_number         VARCHAR(30),
    application_number  VARCHAR(30),
    customer_code       VARCHAR(20),
    product_code        VARCHAR(20),
    branch_code         VARCHAR(10),
    loan_amount         DECIMAL(18,2),
    approved_amount     DECIMAL(18,2),
    disbursed_amount    DECIMAL(18,2),
    outstanding_principal DECIMAL(18,2),
    interest_rate       DECIMAL(10,6),
    interest_type       VARCHAR(20),
    term_months         INT,
    emi_amount          DECIMAL(18,2),
    disbursement_date   DATE,
    maturity_date       DATE,
    first_payment_date  DATE,
    loan_status         VARCHAR(20),
    collateral_type     VARCHAR(50),
    collateral_value    DECIMAL(18,2),
    guarantee_amount    DECIMAL(18,2),
    provision_amount    DECIMAL(18,2),
    days_past_due       INT,
    risk_classification VARCHAR(20),
    relationship_officer_code VARCHAR(20),
    approval_date       DATE,
    approval_authority  VARCHAR(50),
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'LOAN_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 11. CREATE STAGING TABLES - CARDS
-- ============================================================================
CREATE TABLE staging.stg_cards (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    card_number_masked  VARCHAR(20),
    card_token          VARCHAR(50),
    customer_code       VARCHAR(20),
    account_number      VARCHAR(30),
    card_type           VARCHAR(20),
    card_brand          VARCHAR(20),
    card_class          VARCHAR(20),
    issue_date          DATE,
    expiry_date         DATE,
    credit_limit        DECIMAL(18,2),
    current_balance     DECIMAL(18,2),
    available_credit    DECIMAL(18,2),
    card_status         VARCHAR(20),
    daily_limit         DECIMAL(18,2),
    monthly_limit       DECIMAL(18,2),
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'CARD_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 12. CREATE STAGING TABLES - FX TRANSACTIONS
-- ============================================================================
CREATE TABLE staging.stg_fx_transactions (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    fx_code             VARCHAR(30),
    customer_code       VARCHAR(20),
    account_number      VARCHAR(30),
    transaction_type    VARCHAR(20),
    source_currency     VARCHAR(3),
    target_currency     VARCHAR(3),
    source_amount       DECIMAL(18,2),
    target_amount       DECIMAL(18,2),
    exchange_rate       DECIMAL(10,6),
    spread              DECIMAL(10,6),
    profit_amount       DECIMAL(18,2),
    transaction_date    DATE,
    value_date          DATE,
    counterparty        NVARCHAR(200),
    settlement_status   VARCHAR(20),
    branch_code         VARCHAR(10),
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'TREASURY_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 13. CREATE STAGING TABLES - CHEQUES
-- ============================================================================
CREATE TABLE staging.stg_cheques (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    cheque_number       VARCHAR(20),
    account_number      VARCHAR(30),
    cheque_type         VARCHAR(20),
    face_value          DECIMAL(18,2),
    payee_name          NVARCHAR(200),
    issue_date          DATE,
    presentation_date   DATE,
    clearing_date       DATE,
    status              VARCHAR(20),
    return_reason       NVARCHAR(200),
    branch_code         VARCHAR(10),
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'CHEQUE_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 14. CREATE STAGING TABLES - GL ENTRIES
-- ============================================================================
CREATE TABLE staging.stg_gl_entries (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    gl_account_code     VARCHAR(20),
    transaction_date    DATE,
    debit_amount        DECIMAL(18,2),
    credit_amount       DECIMAL(18,2),
    description         NVARCHAR(500),
    reference_type      VARCHAR(50),
    reference_id        BIGINT,
    branch_code         VARCHAR(10),
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'GL_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 15. CREATE STAGING TABLES - AML ALERTS
-- ============================================================================
CREATE TABLE staging.stg_aml_alerts (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    alert_code          VARCHAR(30),
    customer_code       VARCHAR(20),
    transaction_code    VARCHAR(30),
    alert_type          VARCHAR(50),
    alert_description   NVARCHAR(1000),
    risk_score          INT,
    status              VARCHAR(20),
    assigned_to_code    VARCHAR(20),
    review_date         DATE,
    resolution_notes    NVARCHAR(1000),
    sar_reference       VARCHAR(50),
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'AML_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 16. CREATE STAGING TABLES - EXCHANGE RATES
-- ============================================================================
CREATE TABLE staging.stg_exchange_rates (
    stg_id              INT IDENTITY(1,1) PRIMARY KEY,
    source_currency     VARCHAR(3),
    target_currency     VARCHAR(3),
    rate                DECIMAL(10,6),
    bid_rate            DECIMAL(10,6),
    ask_rate            DECIMAL(10,6),
    rate_date           DATE,
    -- Audit columns
    source_system       VARCHAR(50) DEFAULT 'TREASURY_SYSTEM',
    source_key          VARCHAR(50),
    extract_date        DATETIME DEFAULT GETDATE(),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    is_valid            BIT DEFAULT 1,
    validation_errors   NVARCHAR(MAX)
);

-- ============================================================================
-- 17. CREATE ERROR LOGGING TABLE
-- ============================================================================
CREATE TABLE staging.error_log (
    error_id            INT IDENTITY(1,1) PRIMARY KEY,
    batch_id            UNIQUEIDENTIFIER,
    source_table        VARCHAR(100),
    error_type          VARCHAR(50),
    error_message       NVARCHAR(MAX),
    error_row           NVARCHAR(MAX),
    error_date          DATETIME DEFAULT GETDATE(),
    severity            VARCHAR(20) CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    is_resolved         BIT DEFAULT 0,
    resolved_by         VARCHAR(100),
    resolved_date       DATETIME,
    resolution_notes    NVARCHAR(MAX)
);

-- ============================================================================
-- 18. CREATE BATCH TRACKING TABLE
-- ============================================================================
CREATE TABLE staging.batch_log (
    batch_id            UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    batch_name          VARCHAR(100) NOT NULL,
    source_system       VARCHAR(50),
    start_time          DATETIME DEFAULT GETDATE(),
    end_time            DATETIME,
    status              VARCHAR(20) DEFAULT 'RUNNING' CHECK (status IN ('RUNNING', 'COMPLETED', 'FAILED', 'PARTIAL')),
    records_extracted   BIGINT DEFAULT 0,
    records_staged      BIGINT DEFAULT 0,
    records_valid       BIGINT DEFAULT 0,
    records_invalid     BIGINT DEFAULT 0,
    records_loaded      BIGINT DEFAULT 0,
    error_count         BIGINT DEFAULT 0,
    error_message       NVARCHAR(MAX),
    created_by          VARCHAR(100) DEFAULT SYSTEM_USER
);

-- ============================================================================
-- 19. CREATE DATA LINEAGE TABLE
-- ============================================================================
CREATE TABLE staging.data_lineage (
    lineage_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    batch_id            UNIQUEIDENTIFIER,
    source_system       VARCHAR(50),
    source_table        VARCHAR(100),
    source_key          VARCHAR(50),
    target_table        VARCHAR(100),
    target_key          VARCHAR(50),
    transformation      VARCHAR(100),
    lineage_date        DATETIME DEFAULT GETDATE()
);

-- ============================================================================
-- 20. CREATE VALIDATION RULES TABLE
-- ============================================================================
CREATE TABLE staging.validation_rules (
    rule_id             INT IDENTITY(1,1) PRIMARY KEY,
    source_table        VARCHAR(100) NOT NULL,
    column_name         VARCHAR(100) NOT NULL,
    rule_type           VARCHAR(50) NOT NULL CHECK (rule_type IN ('NOT_NULL', 'DATA_TYPE', 'RANGE', 'LOOKUP', 'PATTERN', 'CUSTOM')),
    rule_definition     NVARCHAR(500) NOT NULL,
    error_message       NVARCHAR(500),
    severity            VARCHAR(20) DEFAULT 'ERROR',
    is_active           BIT DEFAULT 1,
    created_date        DATETIME DEFAULT GETDATE()
);

-- ============================================================================
-- 21. INSERT DEFAULT VALIDATION RULES
-- ============================================================================
INSERT INTO staging.validation_rules (source_table, column_name, rule_type, rule_definition, error_message, severity) VALUES
-- Customer rules
('stg_customers', 'customer_code', 'NOT_NULL', 'customer_code IS NOT NULL', 'Customer code cannot be null', 'ERROR'),
('stg_customers', 'customer_type', 'RANGE', 'customer_type IN (''INDIVIDUAL'', ''CORPORATE'', ''GOVERNMENT'', ''NGO'')', 'Invalid customer type', 'ERROR'),
('stg_customers', 'national_id', 'CUSTOM', 'LEN(national_id) >= 6', 'National ID too short', 'WARNING'),
('stg_customers', 'phone_primary', 'PATTERN', 'phone_primary LIKE ''0[0-9]{8,9}''', 'Invalid phone format', 'WARNING'),
-- Account rules
('stg_accounts', 'account_number', 'NOT_NULL', 'account_number IS NOT NULL', 'Account number cannot be null', 'ERROR'),
('stg_accounts', 'balance', 'CUSTOM', 'balance >= 0 OR account_type = ''OVERDRAFT''', 'Balance cannot be negative for non-overdraft accounts', 'ERROR'),
('stg_accounts', 'currency', 'RANGE', 'currency IN (''USD'', ''KHR'', ''EUR'', ''GBP'', ''JPY'', ''THB'')', 'Unsupported currency', 'ERROR'),
-- Transaction rules
('stg_transactions', 'transaction_code', 'NOT_NULL', 'transaction_code IS NOT NULL', 'Transaction code cannot be null', 'ERROR'),
('stg_transactions', 'amount', 'CUSTOM', 'amount > 0', 'Transaction amount must be positive', 'ERROR'),
('stg_transactions', 'transaction_date', 'NOT_NULL', 'transaction_date IS NOT NULL', 'Transaction date cannot be null', 'ERROR'),
-- Loan rules
('stg_loans', 'loan_number', 'NOT_NULL', 'loan_number IS NOT NULL', 'Loan number cannot be null', 'ERROR'),
('stg_loans', 'loan_amount', 'CUSTOM', 'loan_amount > 0', 'Loan amount must be positive', 'ERROR'),
('stg_loans', 'interest_rate', 'CUSTOM', 'interest_rate >= 0 AND interest_rate <= 100', 'Invalid interest rate', 'ERROR'),
('stg_loans', 'term_months', 'CUSTOM', 'term_months > 0 AND term_months <= 360', 'Invalid loan term', 'ERROR');

-- ============================================================================
-- 22. INSERT ETL CONTROL RECORDS
-- ============================================================================
INSERT INTO staging.etl_control (source_system, source_table, extract_query) VALUES
('CORE_BANKING', 'branches', 'SELECT * FROM sathapana_source.oltp.branches'),
('CORE_BANKING', 'customers', 'SELECT * FROM sathapana_source.oltp.v_customer_extract'),
('CORE_BANKING', 'accounts', 'SELECT * FROM sathapana_source.oltp.v_account_extract'),
('CORE_BANKING', 'transactions', 'SELECT * FROM sathapana_source.oltp.v_transaction_extract'),
('CORE_BANKING', 'products', 'SELECT * FROM sathapana_source.oltp.products'),
('LOAN_SYSTEM', 'loans', 'SELECT * FROM sathapana_source.oltp.v_loan_extract'),
('CARD_SYSTEM', 'cards', 'SELECT * FROM sathapana_source.oltp.cards'),
('TREASURY_SYSTEM', 'fx_transactions', 'SELECT * FROM sathapana_source.oltp.fx_transactions'),
('TREASURY_SYSTEM', 'exchange_rates', 'SELECT * FROM sathapana_source.oltp.exchange_rates'),
('CHEQUE_SYSTEM', 'cheques', 'SELECT * FROM sathapana_source.oltp.cheques'),
('GL_SYSTEM', 'gl_entries', 'SELECT * FROM sathapana_source.oltp.gl_entries'),
('AML_SYSTEM', 'aml_alerts', 'SELECT * FROM sathapana_source.oltp.aml_alerts'),
('HR_SYSTEM', 'employees', 'SELECT * FROM sathapana_source.oltp.employees');

-- ============================================================================
-- 23. VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'SATHAPANA BANK - STAGING DATABASE CREATED';
PRINT '================================================';
PRINT 'Tables Created:';
SELECT COUNT(*) AS table_count FROM sys.tables WHERE schema_id = SCHEMA_ID('staging');
PRINT '';
PRINT 'Staging Tables:';
SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('staging') ORDER BY name;
PRINT '';
PRINT 'Default Validation Rules:';
SELECT COUNT(*) AS rule_count FROM staging.validation_rules;
PRINT '';
PRINT '================================================';
PRINT 'STAGING DATABASE READY FOR ETL OPERATIONS';
PRINT '================================================';
GO
