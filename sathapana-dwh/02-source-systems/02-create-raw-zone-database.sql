-- ============================================================================
-- SATHAPANA BANK - LAYER 1: RAW ZONE DATABASE
-- ============================================================================
-- Purpose: Create the Raw Zone database for exact source data copy
-- Database: sathapana_raw
-- Architecture: Layer 1 (Source Copy - No Transformations)
-- Author: DWH Development Team
-- ============================================================================

-- ============================================================================
-- 1. CREATE DATABASE
-- ============================================================================
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_raw')
BEGIN
    ALTER DATABASE sathapana_raw SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_raw;
END
GO

CREATE DATABASE sathapana_raw
ON PRIMARY (
    NAME = 'sathapana_raw_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_raw_dat.mdf',
    SIZE = 200MB,
    MAXSIZE = 20GB,
    FILEGROWTH = 100MB
)
LOG ON (
    NAME = 'sathapana_raw_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_raw_log.ldf',
    SIZE = 100MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 50MB
);
GO

USE sathapana_raw;
GO

-- ============================================================================
-- 2. CREATE SCHEMA
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'raw')
    EXEC('CREATE SCHEMA raw');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'meta')
    EXEC('CREATE SCHEMA meta');
GO

-- ============================================================================
-- 3. CREATE EXACT COPY OF SOURCE TABLES (No transformations)
-- ============================================================================

-- 3.1 Branches (exact copy)
CREATE TABLE raw.branches (
    branch_id           INT PRIMARY KEY,
    branch_code         VARCHAR(10) NOT NULL,
    branch_name         NVARCHAR(200) NOT NULL,
    branch_name_kh      NVARCHAR(200),
    branch_type         VARCHAR(20) NOT NULL,
    region              VARCHAR(50) NOT NULL,
    province            VARCHAR(100) NOT NULL,
    district            VARCHAR(100),
    commune             NVARCHAR(200),
    village             NVARCHAR(200),
    address             NVARCHAR(500),
    phone               VARCHAR(20),
    email               VARCHAR(100),
    manager_id          INT,
    is_active           BIT NOT NULL,
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    -- Raw zone metadata
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'CORE_BANKING'
);

-- 3.2 Employees (exact copy)
CREATE TABLE raw.employees (
    employee_id         INT PRIMARY KEY,
    employee_code       VARCHAR(20) NOT NULL,
    national_id         VARCHAR(20),
    first_name          NVARCHAR(100) NOT NULL,
    last_name           NVARCHAR(100),
    date_of_birth       DATE,
    gender              CHAR(1),
    email               VARCHAR(100),
    phone               VARCHAR(20),
    hire_date           DATE NOT NULL,
    termination_date    DATE,
    job_title           NVARCHAR(200),
    department          VARCHAR(100),
    branch_id           INT NOT NULL,
    reports_to          INT,
    salary_grade        VARCHAR(10),
    is_active           BIT NOT NULL,
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'HR_SYSTEM'
);

-- 3.3 Customers (exact copy)
CREATE TABLE raw.customers (
    customer_id         INT PRIMARY KEY,
    customer_code       VARCHAR(20) NOT NULL,
    customer_type       VARCHAR(20) NOT NULL,
    title               VARCHAR(10),
    first_name          NVARCHAR(200) NOT NULL,
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
    opening_branch_id   INT NOT NULL,
    is_active           BIT NOT NULL,
    is_pep              BIT DEFAULT 0,
    is_sanctioned       BIT DEFAULT 0,
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'CORE_BANKING'
);

-- 3.4 Products (exact copy)
CREATE TABLE raw.products (
    product_id          INT PRIMARY KEY,
    product_code        VARCHAR(20) NOT NULL,
    product_name        NVARCHAR(200) NOT NULL,
    product_name_kh     NVARCHAR(200),
    product_category    VARCHAR(50) NOT NULL,
    product_subcategory VARCHAR(100),
    gl_account_code     VARCHAR(20),
    currency            VARCHAR(3),
    interest_rate       DECIMAL(10,6),
    min_balance         DECIMAL(18,2),
    max_balance         DECIMAL(18,2),
    min_amount          DECIMAL(18,2),
    max_amount          DECIMAL(18,2),
    term_months         INT,
    is_active           BIT NOT NULL,
    effective_date      DATE NOT NULL,
    expiry_date         DATE,
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'PRODUCT_CATALOG'
);

-- 3.5 Accounts (exact copy)
CREATE TABLE raw.accounts (
    account_id          INT PRIMARY KEY,
    account_number      VARCHAR(30) NOT NULL,
    customer_id         INT NOT NULL,
    product_id          INT NOT NULL,
    branch_id           INT NOT NULL,
    currency            VARCHAR(3) NOT NULL,
    account_type        VARCHAR(20) NOT NULL,
    account_status      VARCHAR(20) NOT NULL,
    open_date           DATE NOT NULL,
    close_date          DATE,
    maturity_date       DATE,
    balance             DECIMAL(18,2) NOT NULL,
    available_balance   DECIMAL(18,2) NOT NULL,
    hold_amount         DECIMAL(18,2) NOT NULL,
    credit_limit        DECIMAL(18,2),
    interest_rate       DECIMAL(10,6),
    last_transaction_date DATE,
    dormant_date        DATE,
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'CORE_BANKING'
);

-- 3.6 Transactions (exact copy)
CREATE TABLE raw.transactions (
    transaction_id      BIGINT PRIMARY KEY,
    transaction_code    VARCHAR(30) NOT NULL,
    account_id          INT NOT NULL,
    transaction_type    VARCHAR(30) NOT NULL,
    transaction_channel VARCHAR(30) NOT NULL,
    transaction_date    DATETIME NOT NULL,
    value_date          DATE NOT NULL,
    amount              DECIMAL(18,2) NOT NULL,
    currency            VARCHAR(3) NOT NULL,
    exchange_rate       DECIMAL(10,6),
    balance_before      DECIMAL(18,2),
    balance_after       DECIMAL(18,2),
    fee_amount          DECIMAL(18,2),
    tax_amount          DECIMAL(18,2),
    description         NVARCHAR(500),
    reference_number    VARCHAR(30),
    counterparty_account VARCHAR(30),
    counterparty_bank   VARCHAR(100),
    status              VARCHAR(20) NOT NULL,
    posted_by           INT,
    authorized_by       INT,
    branch_id           INT NOT NULL,
    created_date        DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'CORE_BANKING'
);

-- Create indexes for raw.transactions
CREATE INDEX IX_raw_txn_account ON raw.transactions(account_id);
CREATE INDEX IX_raw_txn_date ON raw.transactions(transaction_date);
CREATE INDEX IX_raw_txn_code ON raw.transactions(transaction_code);

-- 3.7 Loans (exact copy)
CREATE TABLE raw.loans (
    loan_id             INT PRIMARY KEY,
    loan_number         VARCHAR(30) NOT NULL,
    application_number  VARCHAR(30) NOT NULL,
    customer_id         INT NOT NULL,
    product_id          INT NOT NULL,
    branch_id           INT NOT NULL,
    loan_amount         DECIMAL(18,2) NOT NULL,
    approved_amount     DECIMAL(18,2),
    disbursed_amount    DECIMAL(18,2),
    outstanding_principal DECIMAL(18,2),
    interest_rate       DECIMAL(10,6) NOT NULL,
    interest_type       VARCHAR(20),
    term_months         INT NOT NULL,
    emi_amount          DECIMAL(18,2),
    disbursement_date   DATE,
    maturity_date       DATE,
    first_payment_date  DATE,
    loan_status         VARCHAR(20) NOT NULL,
    collateral_type     VARCHAR(50),
    collateral_value    DECIMAL(18,2),
    guarantee_amount    DECIMAL(18,2),
    provision_amount    DECIMAL(18,2),
    days_past_due       INT,
    risk_classification VARCHAR(20),
    relationship_officer_id INT,
    approval_date       DATE,
    approval_authority  VARCHAR(50),
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'LOAN_SYSTEM'
);

-- 3.8 Cards (exact copy)
CREATE TABLE raw.cards (
    card_id             INT PRIMARY KEY,
    card_number         VARCHAR(20) NOT NULL,
    card_token          VARCHAR(50) NOT NULL,
    customer_id         INT NOT NULL,
    account_id          INT NOT NULL,
    card_type           VARCHAR(20) NOT NULL,
    card_brand          VARCHAR(20),
    card_class          VARCHAR(20),
    issue_date          DATE NOT NULL,
    expiry_date         DATE NOT NULL,
    credit_limit        DECIMAL(18,2),
    current_balance     DECIMAL(18,2),
    available_credit    DECIMAL(18,2),
    card_status         VARCHAR(20) NOT NULL,
    daily_limit         DECIMAL(18,2),
    monthly_limit       DECIMAL(18,2),
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'CARD_SYSTEM'
);

-- 3.9 FX Transactions (exact copy)
CREATE TABLE raw.fx_transactions (
    fx_id               INT PRIMARY KEY,
    fx_code             VARCHAR(30) NOT NULL,
    customer_id         INT,
    account_id          INT,
    transaction_type    VARCHAR(20) NOT NULL,
    source_currency     VARCHAR(3) NOT NULL,
    target_currency     VARCHAR(3) NOT NULL,
    source_amount       DECIMAL(18,2) NOT NULL,
    target_amount       DECIMAL(18,2) NOT NULL,
    exchange_rate       DECIMAL(10,6) NOT NULL,
    spread              DECIMAL(10,6),
    profit_amount       DECIMAL(18,2),
    transaction_date    DATE NOT NULL,
    value_date          DATE NOT NULL,
    counterparty        NVARCHAR(200),
    settlement_status   VARCHAR(20),
    branch_id           INT NOT NULL,
    created_date        DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'TREASURY_SYSTEM'
);

-- 3.10 Exchange Rates (exact copy)
CREATE TABLE raw.exchange_rates (
    rate_id             INT PRIMARY KEY,
    source_currency     VARCHAR(3) NOT NULL,
    target_currency     VARCHAR(3) NOT NULL,
    rate                DECIMAL(10,6) NOT NULL,
    bid_rate            DECIMAL(10,6),
    ask_rate            DECIMAL(10,6),
    rate_date           DATE NOT NULL,
    created_date        DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'TREASURY_SYSTEM'
);

-- 3.11 AML Alerts (exact copy)
CREATE TABLE raw.aml_alerts (
    alert_id            INT PRIMARY KEY,
    alert_code          VARCHAR(30) NOT NULL,
    customer_id         INT,
    transaction_id      BIGINT,
    alert_type          VARCHAR(50) NOT NULL,
    alert_description   NVARCHAR(1000),
    risk_score          INT,
    status              VARCHAR(20) NOT NULL,
    assigned_to         INT,
    review_date         DATE,
    resolution_notes    NVARCHAR(1000),
    sar_reference       VARCHAR(50),
    created_date        DATETIME NOT NULL,
    modified_date       DATETIME NOT NULL,
    _extract_date       DATETIME DEFAULT GETDATE(),
    _batch_id           UNIQUEIDENTIFIER DEFAULT NEWID(),
    _source_system      VARCHAR(50) DEFAULT 'AML_SYSTEM'
);

-- ============================================================================
-- 4. CREATE EXTRACT METADATA TABLE
-- ============================================================================
CREATE TABLE meta.extract_log (
    extract_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    source_system       VARCHAR(50) NOT NULL,
    source_table        VARCHAR(100) NOT NULL,
    target_table        VARCHAR(100) NOT NULL,
    extract_type        VARCHAR(20) CHECK (extract_type IN ('FULL', 'INCREMENTAL')),
    records_extracted   BIGINT DEFAULT 0,
    extract_start       DATETIME DEFAULT GETDATE(),
    extract_end         DATETIME,
    duration_seconds    AS DATEDIFF(SECOND, extract_start, extract_end),
    status              VARCHAR(20) DEFAULT 'RUNNING',
    error_message       NVARCHAR(MAX),
    batch_id            UNIQUEIDENTIFIER DEFAULT NEWID(),
    executed_by         VARCHAR(100) DEFAULT SYSTEM_USER
);

-- ============================================================================
-- 5. CREATE DATA LINEAGE TABLE
-- ============================================================================
CREATE TABLE meta.data_lineage (
    lineage_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    source_database     VARCHAR(100) NOT NULL,
    source_schema       VARCHAR(100) NOT NULL,
    source_table        VARCHAR(100) NOT NULL,
    target_database     VARCHAR(100) NOT NULL,
    target_schema       VARCHAR(100) NOT NULL,
    target_table        VARCHAR(100) NOT NULL,
    transformation_type VARCHAR(50),
    description         NVARCHAR(500),
    created_date        DATETIME DEFAULT GETDATE()
);

-- ============================================================================
-- 6. INSERT DEFAULT DATA LINEAGE
-- ============================================================================
INSERT INTO meta.data_lineage (source_database, source_schema, source_table, target_database, target_schema, target_table, transformation_type, description) VALUES
-- Layer 0 to Layer 1
('sathapana_source', 'oltp', 'branches', 'sathapana_raw', 'raw', 'branches', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'employees', 'sathapana_raw', 'raw', 'employees', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'customers', 'sathapana_raw', 'raw', 'customers', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'products', 'sathapana_raw', 'raw', 'products', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'accounts', 'sathapana_raw', 'raw', 'accounts', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'transactions', 'sathapana_raw', 'raw', 'transactions', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'loans', 'sathapana_raw', 'raw', 'loans', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'cards', 'sathapana_raw', 'raw', 'cards', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'fx_transactions', 'sathapana_raw', 'raw', 'fx_transactions', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'exchange_rates', 'sathapana_raw', 'raw', 'exchange_rates', 'COPY', 'Exact copy from source'),
('sathapana_source', 'oltp', 'aml_alerts', 'sathapana_raw', 'raw', 'aml_alerts', 'COPY', 'Exact copy from source');

-- ============================================================================
-- 7. VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'LAYER 1: RAW ZONE DATABASE CREATED';
PRINT '================================================';
PRINT 'Database: sathapana_raw';
PRINT '';
PRINT 'Tables Created:';
SELECT COUNT(*) AS table_count FROM sys.tables WHERE schema_id = SCHEMA_ID('raw');
PRINT '';
PRINT 'Tables:';
SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('raw') ORDER BY name;
PRINT '';
PRINT 'Extract Metadata:';
SELECT COUNT(*) AS lineage_count FROM meta.data_lineage;
PRINT '';
PRINT '================================================';
PRINT 'RAW ZONE READY FOR DATA EXTRACTION';
PRINT '================================================';
GO
