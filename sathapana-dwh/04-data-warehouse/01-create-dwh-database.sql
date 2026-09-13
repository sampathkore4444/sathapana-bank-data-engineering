-- ============================================================================
-- SATHAPANA BANK - DATA WAREHOUSE DATABASE CREATION
-- ============================================================================
-- Purpose: Create the enterprise data warehouse with dimensional model
-- Database: sathapana_dwh
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

-- ============================================================================
-- 1. CREATE DATABASE
-- ============================================================================
USE master;
GO

-- Drop database if exists (for development/testing)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_dwh')
BEGIN
    ALTER DATABASE sathapana_dwh SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_dwh;
END
GO

-- Create the data warehouse database
CREATE DATABASE sathapana_dwh
ON PRIMARY (
    NAME = 'sathapana_dwh_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dwh_dat.mdf',
    SIZE = 500MB,
    MAXSIZE = 50GB,
    FILEGROWTH = 250MB
)
LOG ON (
    NAME = 'sathapana_dwh_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dwh_log.ldf',
    SIZE = 200MB,
    MAXSIZE = 10GB,
    FILEGROWTH = 100MB
);
GO

USE sathapana_dwh;
GO

-- ============================================================================
-- 2. CREATE SCHEMAS
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'audit')
    EXEC('CREATE SCHEMA audit');
GO

-- ============================================================================
-- 3. CREATE DIMENSION TABLES
-- ============================================================================

-- ============================================================================
-- 3.1 DIM_DATE - Date Dimension
-- ============================================================================
CREATE TABLE dw.dim_date (
    date_key                INT PRIMARY KEY,  -- YYYYMMDD format
    full_date               DATE NOT NULL,
    day_of_week             TINYINT NOT NULL,
    day_name                VARCHAR(10) NOT NULL,
    day_name_short          CHAR(3) NOT NULL,
    day_of_month            TINYINT NOT NULL,
    day_of_year             SMALLINT NOT NULL,
    week_of_year            TINYINT NOT NULL,
    iso_week                TINYINT NOT NULL,
    month_number            TINYINT NOT NULL,
    month_name              VARCHAR(10) NOT NULL,
    month_name_short        CHAR(3) NOT NULL,
    quarter_number          TINYINT NOT NULL,
    quarter_name            VARCHAR(6) NOT NULL,
    year_number             SMALLINT NOT NULL,
    year_month              CHAR(7) NOT NULL,
    year_quarter            CHAR(6) NOT NULL,
    fiscal_year             SMALLINT NOT NULL,
    fiscal_quarter          TINYINT NOT NULL,
    fiscal_month            TINYINT NOT NULL,
    is_weekday              BIT NOT NULL,
    is_weekend              BIT NOT NULL,
    is_business_day         BIT NOT NULL,
    is_holiday              BIT NOT NULL,
    holiday_name            VARCHAR(100),
    is_month_start          BIT NOT NULL,
    is_month_end            BIT NOT NULL,
    is_quarter_start        BIT NOT NULL,
    is_quarter_end          BIT NOT NULL,
    is_year_start           BIT NOT NULL,
    is_year_end             BIT NOT NULL,
    prev_day_key            INT,
    prev_week_key           INT,
    prev_month_key          INT,
    prev_quarter_key        INT,
    prev_year_key           INT,
    created_date            DATETIME NOT NULL DEFAULT GETDATE()
);

-- Create indexes for dim_date
CREATE INDEX IX_dim_date_full_date ON dw.dim_date(full_date);
CREATE INDEX IX_dim_date_year_month ON dw.dim_date(year_number, month_number);

-- ============================================================================
-- 3.2 DIM_BRANCH - Branch Dimension
-- ============================================================================
CREATE TABLE dw.dim_branch (
    branch_key              INT IDENTITY(1,1) PRIMARY KEY,
    branch_code             VARCHAR(10) NOT NULL,
    branch_name             NVARCHAR(200) NOT NULL,
    branch_name_kh          NVARCHAR(200),
    branch_type             VARCHAR(20) NOT NULL,
    region                  VARCHAR(50),
    province                VARCHAR(100),
    district                VARCHAR(100),
    commune                 NVARCHAR(200),
    village                 NVARCHAR(200),
    address                 NVARCHAR(500),
    phone                   VARCHAR(20),
    email                   VARCHAR(100),
    manager_name            NVARCHAR(200),
    is_active               BIT NOT NULL,
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    expiry_date             DATE NOT NULL DEFAULT '9999-12-31',
    is_current              BIT NOT NULL DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key              VARCHAR(50),
    created_date            DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date           DATETIME NOT NULL DEFAULT GETDATE(),
    batch_id                UNIQUEIDENTIFIER
);

-- Create unique index for SCD Type 2
CREATE UNIQUE INDEX IX_dim_branch_code_current 
ON dw.dim_branch(branch_code, is_current) 
WHERE is_current = 1;

-- ============================================================================
-- 3.3 DIM_CUSTOMER - Customer Dimension (SCD Type 2)
-- ============================================================================
CREATE TABLE dw.dim_customer (
    customer_key            INT IDENTITY(1,1) PRIMARY KEY,
    customer_code           VARCHAR(20) NOT NULL,
    customer_type           VARCHAR(20) NOT NULL,
    title                   VARCHAR(10),
    first_name              NVARCHAR(200) NOT NULL,
    last_name               NVARCHAR(200),
    full_name               AS (CONCAT(first_name, ' ', ISNULL(last_name, ''))) PERSISTED,
    company_name            NVARCHAR(500),
    national_id_type        VARCHAR(20),
    national_id             VARCHAR(30),
    passport_number         VARCHAR(30),
    date_of_birth           DATE,
    age                     AS (DATEDIFF(YEAR, date_of_birth, GETDATE())),
    gender                  CHAR(1),
    nationality             VARCHAR(50),
    email                   VARCHAR(100),
    phone_primary           VARCHAR(20),
    phone_secondary         VARCHAR(20),
    address_line1           NVARCHAR(300),
    address_line2           NVARCHAR(300),
    province                VARCHAR(100),
    district                VARCHAR(100),
    commune                 NVARCHAR(200),
    village                 NVARCHAR(200),
    postal_code             VARCHAR(10),
    customer_segment        VARCHAR(50),
    risk_rating             VARCHAR(20),
    kyc_status              VARCHAR(20),
    kyc_verified_date       DATE,
    kyc_expiry_date         DATE,
    tax_id                  VARCHAR(30),
    employer_name           NVARCHAR(300),
    occupation              VARCHAR(100),
    annual_income           DECIMAL(18,2),
    income_bracket          AS (
        CASE 
            WHEN annual_income IS NULL THEN 'UNKNOWN'
            WHEN annual_income < 1000 THEN 'LOW'
            WHEN annual_income < 5000 THEN 'MEDIUM'
            WHEN annual_income < 20000 THEN 'HIGH'
            ELSE 'VERY_HIGH'
        END
    ),
    marital_status          VARCHAR(20),
    referrer_code           VARCHAR(20),
    acquisition_channel     VARCHAR(50),
    opening_branch_key      INT,
    is_active               BIT NOT NULL,
    is_pep                  BIT DEFAULT 0,
    is_sanctioned           BIT DEFAULT 0,
    -- Customer lifecycle
    customer_tenure_days    AS (DATEDIFF(DAY, created_date, GETDATE())),
    customer_tenure_months  AS (DATEDIFF(MONTH, created_date, GETDATE())),
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    expiry_date             DATE NOT NULL DEFAULT '9999-12-31',
    is_current              BIT NOT NULL DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key              VARCHAR(50),
    created_date            DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date           DATETIME NOT NULL DEFAULT GETDATE(),
    batch_id                UNIQUEIDENTIFIER
);

-- Create indexes for dim_customer
CREATE UNIQUE INDEX IX_dim_customer_code_current 
ON dw.dim_customer(customer_code, is_current) 
WHERE is_current = 1;

CREATE INDEX IX_dim_customer_segment ON dw.dim_customer(customer_segment);
CREATE INDEX IX_dim_customer_province ON dw.dim_customer(province);

-- ============================================================================
-- 3.4 DIM_PRODUCT - Product Dimension
-- ============================================================================
CREATE TABLE dw.dim_product (
    product_key             INT IDENTITY(1,1) PRIMARY KEY,
    product_code            VARCHAR(20) NOT NULL,
    product_name            NVARCHAR(200) NOT NULL,
    product_name_kh         NVARCHAR(200),
    product_category        VARCHAR(50) NOT NULL,
    product_subcategory     VARCHAR(100),
    gl_account_code         VARCHAR(20),
    currency                VARCHAR(3),
    interest_rate           DECIMAL(10,6),
    min_balance             DECIMAL(18,2),
    max_balance             DECIMAL(18,2),
    min_amount              DECIMAL(18,2),
    max_amount              DECIMAL(18,2),
    term_months             INT,
    is_active               BIT NOT NULL,
    effective_date          DATE NOT NULL,
    expiry_date             DATE,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'PRODUCT_CATALOG',
    source_key              VARCHAR(50),
    created_date            DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date           DATETIME NOT NULL DEFAULT GETDATE(),
    batch_id                UNIQUEIDENTIFIER
);

-- Create unique index for product
CREATE UNIQUE INDEX IX_dim_product_code 
ON dw.dim_product(product_code, effective_date);

-- ============================================================================
-- 3.5 DIM_ACCOUNT - Account Dimension (SCD Type 2)
-- ============================================================================
CREATE TABLE dw.dim_account (
    account_key             INT IDENTITY(1,1) PRIMARY KEY,
    account_number          VARCHAR(30) NOT NULL,
    customer_key            INT NOT NULL,
    product_key             INT NOT NULL,
    branch_key              INT NOT NULL,
    currency                VARCHAR(3) NOT NULL,
    account_type            VARCHAR(20) NOT NULL,
    account_status          VARCHAR(20) NOT NULL,
    open_date               DATE NOT NULL,
    close_date              DATE,
    maturity_date           DATE,
    credit_limit            DECIMAL(18,2),
    interest_rate           DECIMAL(10,6),
    last_transaction_date   DATE,
    dormant_date            DATE,
    account_tenure_days     AS (DATEDIFF(DAY, open_date, ISNULL(close_date, GETDATE()))),
    is_active               BIT NOT NULL,
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    expiry_date             DATE NOT NULL DEFAULT '9999-12-31',
    is_current              BIT NOT NULL DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key              VARCHAR(50),
    created_date            DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date           DATETIME NOT NULL DEFAULT GETDATE(),
    batch_id                UNIQUEIDENTIFIER,
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key)
);

-- Create unique index for SCD Type 2
CREATE UNIQUE INDEX IX_dim_account_number_current 
ON dw.dim_account(account_number, is_current) 
WHERE is_current = 1;

-- ============================================================================
-- 3.6 DIM_EMPLOYEE - Employee Dimension (SCD Type 2)
-- ============================================================================
CREATE TABLE dw.dim_employee (
    employee_key            INT IDENTITY(1,1) PRIMARY KEY,
    employee_code           VARCHAR(20) NOT NULL,
    national_id             VARCHAR(20),
    first_name              NVARCHAR(100) NOT NULL,
    last_name               NVARCHAR(100),
    full_name               AS (CONCAT(first_name, ' ', ISNULL(last_name, ''))) PERSISTED,
    date_of_birth           DATE,
    gender                  CHAR(1),
    email                   VARCHAR(100),
    phone                   VARCHAR(20),
    hire_date               DATE NOT NULL,
    termination_date        DATE,
    job_title               NVARCHAR(200),
    department              VARCHAR(100),
    branch_key              INT,
    reports_to_key          INT,
    salary_grade            VARCHAR(10),
    employment_tenure_days  AS (DATEDIFF(DAY, hire_date, ISNULL(termination_date, GETDATE()))),
    is_active               BIT NOT NULL,
    -- SCD Type 2 columns
    effective_date          DATE NOT NULL,
    expiry_date             DATE NOT NULL DEFAULT '9999-12-31',
    is_current              BIT NOT NULL DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'HR_SYSTEM',
    source_key              VARCHAR(50),
    created_date            DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date           DATETIME NOT NULL DEFAULT GETDATE(),
    batch_id                UNIQUEIDENTIFIER
);

-- Create unique index for SCD Type 2
CREATE UNIQUE INDEX IX_dim_employee_code_current 
ON dw.dim_employee(employee_code, is_current) 
WHERE is_current = 1;

-- ============================================================================
-- 3.7 DIM_CURRENCY - Currency Dimension
-- ============================================================================
CREATE TABLE dw.dim_currency (
    currency_key            INT IDENTITY(1,1) PRIMARY KEY,
    currency_code           VARCHAR(3) NOT NULL,
    currency_name           VARCHAR(50) NOT NULL,
    currency_symbol         VARCHAR(5),
    decimal_places          TINYINT DEFAULT 2,
    is_base_currency        BIT DEFAULT 0,
    is_active               BIT DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'SYSTEM',
    created_date            DATETIME NOT NULL DEFAULT GETDATE()
);

-- Create unique index for currency
CREATE UNIQUE INDEX IX_dim_currency_code ON dw.dim_currency(currency_code);

-- ============================================================================
-- 3.8 DIM_GL_ACCOUNT - General Ledger Account Dimension
-- ============================================================================
CREATE TABLE dw.dim_gl_account (
    gl_account_key          INT IDENTITY(1,1) PRIMARY KEY,
    gl_account_code         VARCHAR(20) NOT NULL,
    account_name            NVARCHAR(200),
    account_type            VARCHAR(50),
    account_sub_type        VARCHAR(50),
    account_level           TINYINT,
    parent_account_code     VARCHAR(20),
    is_balance_sheet        BIT DEFAULT 0,
    is_income_statement     BIT DEFAULT 0,
    normal_balance          CHAR(1) CHECK (normal_balance IN ('D', 'C')),
    is_active               BIT DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'GL_SYSTEM',
    source_key              VARCHAR(50),
    created_date            DATETIME NOT NULL DEFAULT GETDATE()
);

-- Create unique index for GL account
CREATE UNIQUE INDEX IX_dim_gl_account_code ON dw.dim_gl_account(gl_account_code);

-- ============================================================================
-- 3.9 DIM_CHANNEL - Transaction Channel Dimension
-- ============================================================================
CREATE TABLE dw.dim_channel (
    channel_key             INT IDENTITY(1,1) PRIMARY KEY,
    channel_code            VARCHAR(30) NOT NULL,
    channel_name            NVARCHAR(100) NOT NULL,
    channel_category        VARCHAR(50),
    is_digital              BIT DEFAULT 0,
    is_branch_based         BIT DEFAULT 0,
    is_active               BIT DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'SYSTEM',
    created_date            DATETIME NOT NULL DEFAULT GETDATE()
);

-- Create unique index for channel
CREATE UNIQUE INDEX IX_dim_channel_code ON dw.dim_channel(channel_code);

-- ============================================================================
-- 4. CREATE FACT TABLES
-- ============================================================================

-- ============================================================================
-- 4.1 FACT_TRANSACTIONS - Transaction Fact Table (Grain: One row per transaction)
-- ============================================================================
CREATE TABLE dw.fact_transactions (
    transaction_key         BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_code        VARCHAR(30) NOT NULL,
    -- Dimension foreign keys
    account_key             INT NOT NULL,
    customer_key            INT NOT NULL,
    product_key             INT NOT NULL,
    branch_key              INT NOT NULL,
    channel_key             INT NOT NULL,
    transaction_date_key    INT NOT NULL,
    value_date_key          INT NOT NULL,
    transaction_type_key    INT NOT NULL,
    -- Measures
    amount                  DECIMAL(18,2) NOT NULL,
    amount_usd              DECIMAL(18,2),  -- Normalized to USD
    currency                VARCHAR(3) NOT NULL,
    exchange_rate           DECIMAL(10,6),
    balance_before          DECIMAL(18,2),
    balance_after           DECIMAL(18,2),
    fee_amount              DECIMAL(18,2) DEFAULT 0,
    tax_amount              DECIMAL(18,2) DEFAULT 0,
    net_amount              AS (amount - fee_amount - tax_amount) PERSISTED,
    -- Degenerate dimensions
    reference_number        VARCHAR(30),
    counterparty_account    VARCHAR(30),
    counterparty_bank       VARCHAR(100),
    status                  VARCHAR(20),
    -- Audit columns
    transaction_datetime    DATETIME NOT NULL,
    source_system           VARCHAR(50) DEFAULT 'CORE_BANKING',
    source_key              BIGINT,
    etl_batch_id            UNIQUEIDENTIFIER,
    etl_load_date           DATETIME DEFAULT GETDATE(),
    -- Foreign keys
    FOREIGN KEY (account_key) REFERENCES dw.dim_account(account_key),
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (channel_key) REFERENCES dw.dim_channel(channel_key),
    FOREIGN KEY (transaction_date_key) REFERENCES dw.dim_date(date_key),
    FOREIGN KEY (value_date_key) REFERENCES dw.dim_date(date_key)
);

-- Create indexes for fact_transactions
CREATE INDEX IX_fact_txn_date ON dw.fact_transactions(transaction_date_key);
CREATE INDEX IX_fact_txn_account ON dw.fact_transactions(account_key);
CREATE INDEX IX_fact_txn_customer ON dw.fact_transactions(customer_key);
CREATE INDEX IX_fact_txn_branch ON dw.fact_transactions(branch_key);
CREATE INDEX IX_fact_txn_type ON dw.fact_transactions(transaction_type_key);

-- ============================================================================
-- 4.2 FACT_ACCOUNT_DAILY_SNAPSHOT - Daily Account Balance Snapshot
-- ============================================================================
CREATE TABLE dw.fact_account_daily_snapshot (
    snapshot_key            BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension foreign keys
    account_key             INT NOT NULL,
    customer_key            INT NOT NULL,
    product_key             INT NOT NULL,
    branch_key              INT NOT NULL,
    snapshot_date_key       INT NOT NULL,
    -- Measures
    opening_balance         DECIMAL(18,2) NOT NULL DEFAULT 0,
    closing_balance         DECIMAL(18,2) NOT NULL DEFAULT 0,
    total_debits            DECIMAL(18,2) NOT NULL DEFAULT 0,
    total_credits           DECIMAL(18,2) NOT NULL DEFAULT 0,
    transaction_count       INT NOT NULL DEFAULT 0,
    debit_count             INT NOT NULL DEFAULT 0,
    credit_count            INT NOT NULL DEFAULT 0,
    average_balance         DECIMAL(18,2),
    min_balance             DECIMAL(18,2),
    max_balance             DECIMAL(18,2),
    -- Balance movement
    balance_change          AS (closing_balance - opening_balance) PERSISTED,
    balance_change_pct      AS (
        CASE 
            WHEN opening_balance = 0 THEN NULL
            ELSE (closing_balance - opening_balance) / ABS(opening_balance) * 100
        END
    ),
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'CORE_BANKING',
    etl_batch_id            UNIQUEIDENTIFIER,
    etl_load_date           DATETIME DEFAULT GETDATE(),
    -- Foreign keys
    FOREIGN KEY (account_key) REFERENCES dw.dim_account(account_key),
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (snapshot_date_key) REFERENCES dw.dim_date(date_key)
);

-- Create indexes for daily snapshot
CREATE INDEX IX_snapshot_date ON dw.fact_account_daily_snapshot(snapshot_date_key);
CREATE INDEX IX_snapshot_account ON dw.fact_account_daily_snapshot(account_key);

-- ============================================================================
-- 4.3 FACT_GL_DAILY_BALANCE - GL Daily Balance Fact Table
-- ============================================================================
CREATE TABLE dw.fact_gl_daily_balance (
    gl_balance_key          BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension foreign keys
    gl_account_key          INT NOT NULL,
    branch_key              INT NOT NULL,
    snapshot_date_key       INT NOT NULL,
    -- Measures
    opening_debit           DECIMAL(18,2) DEFAULT 0,
    opening_credit          DECIMAL(18,2) DEFAULT 0,
    period_debit            DECIMAL(18,2) DEFAULT 0,
    period_credit           DECIMAL(18,2) DEFAULT 0,
    closing_debit           DECIMAL(18,2) DEFAULT 0,
    closing_credit          DECIMAL(18,2) DEFAULT 0,
    net_balance             AS (closing_debit - closing_credit) PERSISTED,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'GL_SYSTEM',
    etl_batch_id            UNIQUEIDENTIFIER,
    etl_load_date           DATETIME DEFAULT GETDATE(),
    -- Foreign keys
    FOREIGN KEY (gl_account_key) REFERENCES dw.dim_gl_account(gl_account_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (snapshot_date_key) REFERENCES dw.dim_date(date_key)
);

-- Create indexes for GL balance
CREATE INDEX IX_gl_balance_date ON dw.fact_gl_daily_balance(snapshot_date_key);
CREATE INDEX IX_gl_balance_account ON dw.fact_gl_daily_balance(gl_account_key);

-- ============================================================================
-- 4.4 FACT_LOAN_PORTFOLIO - Monthly Loan Portfolio Snapshot
-- ============================================================================
CREATE TABLE dw.fact_loan_portfolio (
    loan_portfolio_key      BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension foreign keys
    loan_key                INT NOT NULL,
    customer_key            INT NOT NULL,
    product_key             INT NOT NULL,
    branch_key              INT NOT NULL,
    employee_key            INT,  -- Relationship officer
    snapshot_date_key       INT NOT NULL,
    -- Measures
    loan_amount             DECIMAL(18,2) NOT NULL,
    approved_amount         DECIMAL(18,2),
    disbursed_amount        DECIMAL(18,2),
    outstanding_principal   DECIMAL(18,2) NOT NULL,
    accrued_interest        DECIMAL(18,2) DEFAULT 0,
    provision_amount        DECIMAL(18,2) DEFAULT 0,
    days_past_due           INT DEFAULT 0,
    emi_amount              DECIMAL(18,2),
    -- Risk measures
    risk_classification     VARCHAR(20),
    is_npl                  AS (CASE WHEN days_past_due > 90 THEN 1 ELSE 0 END) PERSISTED,
    is_restructured         BIT DEFAULT 0,
    -- Performance measures
    utilization_rate        AS (
        CASE 
            WHEN approved_amount = 0 THEN NULL
            ELSE disbursed_amount / approved_amount * 100
        END
    ),
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'LOAN_SYSTEM',
    etl_batch_id            UNIQUEIDENTIFIER,
    etl_load_date           DATETIME DEFAULT GETDATE(),
    -- Foreign keys
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (snapshot_date_key) REFERENCES dw.dim_date(date_key)
);

-- Create indexes for loan portfolio
CREATE INDEX IX_loan_portfolio_date ON dw.fact_loan_portfolio(snapshot_date_key);
CREATE INDEX IX_loan_portfolio_customer ON dw.fact_loan_portfolio(customer_key);
CREATE INDEX IX_loan_portfolio_branch ON dw.fact_loan_portfolio(branch_key);

-- ============================================================================
-- 4.5 FACT_DEPOSIT_SNAPSHOT - Monthly Deposit Balance Snapshot
-- ============================================================================
CREATE TABLE dw.fact_deposit_snapshot (
    deposit_snapshot_key    BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension foreign keys
    account_key             INT NOT NULL,
    customer_key            INT NOT NULL,
    product_key             INT NOT NULL,
    branch_key              INT NOT NULL,
    snapshot_date_key       INT NOT NULL,
    -- Measures
    balance                 DECIMAL(18,2) NOT NULL,
    available_balance       DECIMAL(18,2),
    interest_earned         DECIMAL(18,2) DEFAULT 0,
    interest_accrued        DECIMAL(18,2) DEFAULT 0,
    average_monthly_balance DECIMAL(18,2),
    -- Product specific
    interest_rate           DECIMAL(10,6),
    maturity_date           DATE,
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'CORE_BANKING',
    etl_batch_id            UNIQUEIDENTIFIER,
    etl_load_date           DATETIME DEFAULT GETDATE(),
    -- Foreign keys
    FOREIGN KEY (account_key) REFERENCES dw.dim_account(account_key),
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (snapshot_date_key) REFERENCES dw.dim_date(date_key)
);

-- Create indexes for deposit snapshot
CREATE INDEX IX_deposit_snapshot_date ON dw.fact_deposit_snapshot(snapshot_date_key);
CREATE INDEX IX_deposit_snapshot_account ON dw.fact_deposit_snapshot(account_key);

-- ============================================================================
-- 4.6 FACT_FX_TRANSACTIONS - FX Transaction Fact Table
-- ============================================================================
CREATE TABLE dw.fact_fx_transactions (
    fx_key                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    fx_code                 VARCHAR(30) NOT NULL,
    -- Dimension foreign keys
    customer_key            INT,
    account_key             INT,
    branch_key              INT NOT NULL,
    transaction_date_key    INT NOT NULL,
    source_currency_key     INT NOT NULL,
    target_currency_key     INT NOT NULL,
    -- Measures
    source_amount           DECIMAL(18,2) NOT NULL,
    target_amount           DECIMAL(18,2) NOT NULL,
    exchange_rate           DECIMAL(10,6) NOT NULL,
    spread                  DECIMAL(10,6),
    profit_amount           DECIMAL(18,2),
    -- Degenerate dimensions
    transaction_type        VARCHAR(20),
    counterparty            NVARCHAR(200),
    settlement_status       VARCHAR(20),
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'TREASURY_SYSTEM',
    source_key              INT,
    etl_batch_id            UNIQUEIDENTIFIER,
    etl_load_date           DATETIME DEFAULT GETDATE(),
    -- Foreign keys
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (transaction_date_key) REFERENCES dw.dim_date(date_key),
    FOREIGN KEY (source_currency_key) REFERENCES dw.dim_currency(currency_key),
    FOREIGN KEY (target_currency_key) REFERENCES dw.dim_currency(currency_key)
);

-- Create indexes for FX transactions
CREATE INDEX IX_fx_txn_date ON dw.fact_fx_transactions(transaction_date_key);
CREATE INDEX IX_fx_txn_branch ON dw.fact_fx_transactions(branch_key);

-- ============================================================================
-- 4.7 FACT_CARD_TRANSACTIONS - Card Transaction Fact Table
-- ============================================================================
CREATE TABLE dw.fact_card_transactions (
    card_txn_key            BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension foreign keys
    customer_key            INT NOT NULL,
    account_key             INT NOT NULL,
    product_key             INT NOT NULL,
    branch_key              INT NOT NULL,
    transaction_date_key    INT NOT NULL,
    channel_key             INT NOT NULL,
    -- Measures
    amount                  DECIMAL(18,2) NOT NULL,
    fee_amount              DECIMAL(18,2) DEFAULT 0,
    -- Card specific
    card_type               VARCHAR(20),
    card_brand              VARCHAR(20),
    card_class              VARCHAR(20),
    -- Audit columns
    source_system           VARCHAR(50) DEFAULT 'CARD_SYSTEM',
    source_key              BIGINT,
    etl_batch_id            UNIQUEIDENTIFIER,
    etl_load_date           DATETIME DEFAULT GETDATE(),
    -- Foreign keys
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (account_key) REFERENCES dw.dim_account(account_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (transaction_date_key) REFERENCES dw.dim_date(date_key),
    FOREIGN KEY (channel_key) REFERENCES dw.dim_channel(channel_key)
);

-- ============================================================================
-- 5. CREATE BRIDGE TABLES (Many-to-Many Relationships)
-- ============================================================================

-- ============================================================================
-- 5.1 BRIDGE_CUSTOMER_PRODUCT - Customer-Product Relationship
-- ============================================================================
CREATE TABLE dw.bridge_customer_product (
    customer_product_key    INT IDENTITY(1,1) PRIMARY KEY,
    customer_key            INT NOT NULL,
    product_key             INT NOT NULL,
    account_key             INT NOT NULL,
    relationship_start_date DATE NOT NULL,
    relationship_end_date   DATE,
    is_active               BIT DEFAULT 1,
    -- Audit columns
    source_system           VARCHAR(50),
    created_date            DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (account_key) REFERENCES dw.dim_account(account_key)
);

-- ============================================================================
-- 6. CREATE AUDIT TABLES
-- ============================================================================

-- ============================================================================
-- 6.1 AUDIT_ETL_LOG - ETL Execution Log
-- ============================================================================
CREATE TABLE audit.etl_log (
    log_id                  BIGINT IDENTITY(1,1) PRIMARY KEY,
    batch_id                UNIQUEIDENTIFIER NOT NULL,
    step_name               VARCHAR(100) NOT NULL,
    table_name              VARCHAR(100),
    operation               VARCHAR(50),
    records_affected        BIGINT DEFAULT 0,
    status                  VARCHAR(20) CHECK (status IN ('STARTED', 'COMPLETED', 'FAILED', 'WARNING')),
    error_message           NVARCHAR(MAX),
    start_time              DATETIME DEFAULT GETDATE(),
    end_time                DATETIME,
    duration_seconds        AS DATEDIFF(SECOND, start_time, end_time),
    executed_by             VARCHAR(100) DEFAULT SYSTEM_USER
);

-- Create index for ETL log
CREATE INDEX IX_etl_log_batch ON audit.etl_log(batch_id);
CREATE INDEX IX_etl_log_time ON audit.etl_log(start_time);

-- ============================================================================
-- 6.2 AUDIT_DATA_QUALITY - Data Quality Results
-- ============================================================================
CREATE TABLE audit.data_quality (
    quality_id              BIGINT IDENTITY(1,1) PRIMARY KEY,
    batch_id                UNIQUEIDENTIFIER,
    check_name              VARCHAR(100) NOT NULL,
    check_description       NVARCHAR(500),
    table_name              VARCHAR(100),
    column_name             VARCHAR(100),
    total_rows              BIGINT,
    passing_rows            BIGINT,
    failing_rows            BIGINT,
    pass_rate               DECIMAL(5,2),
    status                  VARCHAR(20) CHECK (status IN ('PASS', 'FAIL', 'WARNING')),
    severity                VARCHAR(20),
    check_date              DATETIME DEFAULT GETDATE()
);

-- ============================================================================
-- 6.3 AUDIT_ROW_COUNTS - Table Row Count History
-- ============================================================================
CREATE TABLE audit.row_counts (
    count_id                BIGINT IDENTITY(1,1) PRIMARY KEY,
    table_name              VARCHAR(100) NOT NULL,
    row_count               BIGINT NOT NULL,
    count_date              DATETIME DEFAULT GETDATE(),
    batch_id                UNIQUEIDENTIFIER
);

-- ============================================================================
-- 7. INSERT LOOKUP DATA
-- ============================================================================

-- ============================================================================
-- 7.1 INSERT CURRENCIES
-- ============================================================================
SET IDENTITY_INSERT dw.dim_currency ON;

INSERT INTO dw.dim_currency (currency_key, currency_code, currency_name, currency_symbol, decimal_places, is_base_currency) VALUES
(1, 'USD', 'US Dollar', '$', 2, 1),
(2, 'KHR', 'Cambodian Riel', '៛', 0, 0),
(3, 'EUR', 'Euro', '€', 2, 0),
(4, 'GBP', 'British Pound', '£', 2, 0),
(5, 'JPY', 'Japanese Yen', '¥', 0, 0),
(6, 'THB', 'Thai Baht', '฿', 2, 0);

SET IDENTITY_INSERT dw.dim_currency OFF;

-- ============================================================================
-- 7.2 INSERT CHANNELS
-- ============================================================================
SET IDENTITY_INSERT dw.dim_channel ON;

INSERT INTO dw.dim_channel (channel_key, channel_code, channel_name, channel_category, is_digital, is_branch_based) VALUES
(1, 'COUNTER', 'Bank Counter', 'BRANCH', 0, 1),
(2, 'ATM', 'Automated Teller Machine', 'SELF_SERVICE', 1, 0),
(3, 'MOBILE', 'Mobile Banking', 'DIGITAL', 1, 0),
(4, 'INTERNET', 'Internet Banking', 'DIGITAL', 1, 0),
(5, 'SWIFT', 'SWIFT Transfer', 'WIRE', 0, 0),
(6, 'ACH', 'Automated Clearing House', 'CLEARING', 0, 0),
(7, 'POS', 'Point of Sale', 'DIGITAL', 1, 0),
(8, 'CHEQUE', 'Cheque', 'TRADITIONAL', 0, 1);

SET IDENTITY_INSERT dw.dim_channel OFF;

-- ============================================================================
-- 8. CREATE VIEWS FOR REPORTING
-- ============================================================================

-- ============================================================================
-- 8.1 VIEW: vw_customer_360 - Complete Customer View
-- ============================================================================
GO
CREATE VIEW dw.vw_customer_360 AS
SELECT 
    c.customer_key,
    c.customer_code,
    c.full_name,
    c.customer_type,
    c.customer_segment,
    c.gender,
    c.age,
    c.nationality,
    c.province,
    c.district,
    c.risk_rating,
    c.kyc_status,
    c.is_pep,
    c.is_sanctioned,
    c.annual_income,
    c.income_bracket,
    c.occupation,
    c.employer_name,
    c.acquisition_channel,
    c.is_active,
    c.effective_date,
    -- Aggregated measures
    COUNT(DISTINCT a.account_key) AS total_accounts,
    COUNT(DISTINCT CASE WHEN a.account_type = 'SAVINGS' THEN a.account_key END) AS savings_accounts,
    COUNT(DISTINCT CASE WHEN a.account_type = 'CURRENT' THEN a.account_key END) AS current_accounts,
    COUNT(DISTINCT CASE WHEN a.account_type = 'TERM_DEPOSIT' THEN a.account_key END) AS term_deposits,
    -- Will be populated from facts
    NULL AS total_balance,
    NULL AS total_transactions_30d,
    NULL AS average_monthly_balance
FROM dw.dim_customer c
LEFT JOIN dw.dim_account a ON c.customer_key = a.customer_key AND a.is_current = 1
WHERE c.is_current = 1
GROUP BY 
    c.customer_key, c.customer_code, c.full_name, c.customer_type,
    c.customer_segment, c.gender, c.age, c.nationality, c.province,
    c.district, c.risk_rating, c.kyc_status, c.is_pep, c.is_sanctioned,
    c.annual_income, c.income_bracket, c.occupation, c.employer_name,
    c.acquisition_channel, c.is_active, c.effective_date;

-- ============================================================================
-- 8.2 VIEW: vw_branch_performance - Branch Performance Metrics
-- ============================================================================
CREATE VIEW dw.vw_branch_performance AS
SELECT 
    b.branch_key,
    b.branch_code,
    b.branch_name,
    b.branch_type,
    b.region,
    b.province,
    b.is_active,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    SUM(CASE WHEN a.account_type = 'SAVINGS' THEN 1 ELSE 0 END) AS savings_count,
    SUM(CASE WHEN a.account_type = 'CURRENT' THEN 1 ELSE 0 END) AS current_count,
    -- Transaction metrics (last 30 days)
    COUNT(DISTINCT t.transaction_key) AS transactions_30d,
    SUM(t.amount) AS transaction_volume_30d,
    AVG(t.amount) AS avg_transaction_amount
FROM dw.dim_branch b
LEFT JOIN dw.dim_account a ON b.branch_key = a.branch_key AND a.is_current = 1
LEFT JOIN dw.fact_transactions t ON a.account_key = t.account_key
    AND t.transaction_date_key >= CAST(FORMAT(DATEADD(DAY, -30, GETDATE()), 'yyyyMMdd') AS INT)
WHERE b.is_active = 1
GROUP BY 
    b.branch_key, b.branch_code, b.branch_name, b.branch_type,
    b.region, b.province, b.is_active;

-- ============================================================================
-- 8.3 VIEW: vw_loan_portfolio_summary - Loan Portfolio Summary
-- ============================================================================
CREATE VIEW dw.vw_loan_portfolio_summary AS
SELECT 
    b.branch_code,
    b.branch_name,
    p.product_category,
    p.product_name,
    COUNT(*) AS loan_count,
    SUM(l.loan_amount) AS total_loan_amount,
    SUM(l.outstanding_principal) AS total_outstanding,
    SUM(l.provision_amount) AS total_provisions,
    AVG(l.days_past_due) AS avg_days_past_due,
    SUM(CASE WHEN l.days_past_due > 90 THEN 1 ELSE 0 END) AS npl_count,
    SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) AS npl_amount
FROM dw.fact_loan_portfolio l
JOIN dw.dim_branch b ON l.branch_key = b.branch_key
JOIN dw.dim_product p ON l.product_key = p.product_key
JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, p.product_category, p.product_name;

-- ============================================================================
-- 9. VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'SATHAPANA BANK - DATA WAREHOUSE CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Dimension Tables:';
SELECT COUNT(*) AS dimension_count FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'dw' AND t.name LIKE 'dim_%';
PRINT '';
PRINT 'Fact Tables:';
SELECT COUNT(*) AS fact_count FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'dw' AND t.name LIKE 'fact_%';
PRINT '';
PRINT 'Bridge Tables:';
SELECT COUNT(*) AS bridge_count FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'dw' AND t.name LIKE 'bridge_%';
PRINT '';
PRINT 'Audit Tables:';
SELECT COUNT(*) AS audit_count FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'audit';
PRINT '';
PRINT 'Views:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dw');
PRINT '';
PRINT 'Currencies Loaded:';
SELECT COUNT(*) AS currency_count FROM dw.dim_currency;
PRINT '';
PRINT 'Channels Loaded:';
SELECT COUNT(*) AS channel_count FROM dw.dim_channel;
PRINT '';
PRINT '================================================';
PRINT 'DATA WAREHOUSE READY FOR ETL OPERATIONS';
PRINT '================================================';
GO
