-- ============================================================================
-- SATHAPANA BANK - SOURCE DATABASE CREATION
-- ============================================================================
-- Purpose: Create the OLTP source database that simulates the core banking system
-- Database: sathapana_source
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

-- ============================================================================
-- 1. CREATE DATABASE
-- ============================================================================
USE master;
GO

-- Drop database if exists (for development/testing)
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_source')
BEGIN
    ALTER DATABASE sathapana_source SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_source;
END
GO

-- Create the source database
CREATE DATABASE sathapana_source
ON PRIMARY (
    NAME = 'sathapana_source_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_source_dat.mdf',
    SIZE = 100MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 50MB
)
LOG ON (
    NAME = 'sathapana_source_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_source_log.ldf',
    SIZE = 50MB,
    MAXSIZE = 2GB,
    FILEGROWTH = 25MB
);
GO

USE sathapana_source;
GO

-- ============================================================================
-- 2. CREATE SCHEMA
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'oltp')
    EXEC('CREATE SCHEMA oltp');
GO

-- ============================================================================
-- 3. CREATE TABLES - BRANCHES
-- ============================================================================
CREATE TABLE oltp.branches (
    branch_id           INT IDENTITY(1,1) PRIMARY KEY,
    branch_code         VARCHAR(10) NOT NULL UNIQUE,
    branch_name         NVARCHAR(200) NOT NULL,
    branch_name_kh      NVARCHAR(200),
    branch_type         VARCHAR(20) NOT NULL CHECK (branch_type IN ('HEAD_OFFICE', 'BRANCH', 'SUB_BRANCH', 'AGENT')),
    region              VARCHAR(50) NOT NULL,
    province            VARCHAR(100) NOT NULL,
    district            VARCHAR(100),
    commune             NVARCHAR(200),
    village             NVARCHAR(200),
    address             NVARCHAR(500),
    phone               VARCHAR(20),
    email               VARCHAR(100),
    manager_id          INT,
    is_active           BIT NOT NULL DEFAULT 1,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE()
);

-- ============================================================================
-- 4. CREATE TABLES - EMPLOYEES
-- ============================================================================
CREATE TABLE oltp.employees (
    employee_id         INT IDENTITY(1,1) PRIMARY KEY,
    employee_code       VARCHAR(20) NOT NULL UNIQUE,
    national_id         VARCHAR(20),
    first_name          NVARCHAR(100) NOT NULL,
    last_name           NVARCHAR(100) NOT NULL,
    date_of_birth       DATE,
    gender              CHAR(1) CHECK (gender IN ('M', 'F')),
    email               VARCHAR(100),
    phone               VARCHAR(20),
    hire_date           DATE NOT NULL,
    termination_date    DATE,
    job_title           NVARCHAR(200),
    department          VARCHAR(100),
    branch_id           INT NOT NULL,
    reports_to          INT,
    salary_grade        VARCHAR(10),
    is_active           BIT NOT NULL DEFAULT 1,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (branch_id) REFERENCES oltp.branches(branch_id),
    FOREIGN KEY (reports_to) REFERENCES oltp.employees(employee_id)
);

-- Add foreign key for branch manager
ALTER TABLE oltp.branches
ADD FOREIGN KEY (manager_id) REFERENCES oltp.employees(employee_id);

-- ============================================================================
-- 5. CREATE TABLES - CUSTOMERS
-- ============================================================================
CREATE TABLE oltp.customers (
    customer_id         INT IDENTITY(1,1) PRIMARY KEY,
    customer_code       VARCHAR(20) NOT NULL UNIQUE,
    customer_type       VARCHAR(20) NOT NULL CHECK (customer_type IN ('INDIVIDUAL', 'CORPORATE', 'GOVERNMENT', 'NGO')),
    title               VARCHAR(10),
    first_name          NVARCHAR(200) NOT NULL,
    last_name           NVARCHAR(200),
    company_name        NVARCHAR(500),
    national_id_type    VARCHAR(20),
    national_id         VARCHAR(30),
    passport_number     VARCHAR(30),
    date_of_birth       DATE,
    gender              CHAR(1) CHECK (gender IN ('M', 'F', 'O')),
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
    customer_segment    VARCHAR(50) CHECK (customer_segment IN ('RETAIL', 'SME', 'CORPORATE', 'PRIVATE_BANKING', 'MICRO')),
    risk_rating         VARCHAR(20) CHECK (risk_rating IN ('LOW', 'MEDIUM', 'HIGH', 'VERY_HIGH')),
    kyc_status          VARCHAR(20) CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'EXPIRED', 'REJECTED')),
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
    is_active           BIT NOT NULL DEFAULT 1,
    is_pep              BIT DEFAULT 0,  -- Politically Exposed Person
    is_sanctioned       BIT DEFAULT 0,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (opening_branch_id) REFERENCES oltp.branches(branch_id)
);

-- ============================================================================
-- 6. CREATE TABLES - PRODUCTS
-- ============================================================================
CREATE TABLE oltp.products (
    product_id          INT IDENTITY(1,1) PRIMARY KEY,
    product_code        VARCHAR(20) NOT NULL UNIQUE,
    product_name        NVARCHAR(200) NOT NULL,
    product_name_kh     NVARCHAR(200),
    product_category    VARCHAR(50) NOT NULL CHECK (product_category IN ('DEPOSIT', 'LOAN', 'CARD', 'TRANSFER', 'FOREIGN_EXCHANGE', 'INSURANCE', 'INVESTMENT')),
    product_subcategory VARCHAR(100),
    gl_account_code     VARCHAR(20),
    currency            VARCHAR(3) DEFAULT 'USD',
    interest_rate       DECIMAL(10,6),
    min_balance         DECIMAL(18,2),
    max_balance         DECIMAL(18,2),
    min_amount          DECIMAL(18,2),
    max_amount          DECIMAL(18,2),
    term_months         INT,
    fee_structure       XML,  -- JSON-like structure for fees
    is_active           BIT NOT NULL DEFAULT 1,
    effective_date      DATE NOT NULL,
    expiry_date         DATE,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE()
);

-- ============================================================================
-- 7. CREATE TABLES - ACCOUNTS
-- ============================================================================
CREATE TABLE oltp.accounts (
    account_id          INT IDENTITY(1,1) PRIMARY KEY,
    account_number      VARCHAR(30) NOT NULL UNIQUE,
    customer_id         INT NOT NULL,
    product_id          INT NOT NULL,
    branch_id           INT NOT NULL,
    currency            VARCHAR(3) NOT NULL DEFAULT 'USD',
    account_type        VARCHAR(20) NOT NULL CHECK (account_type IN ('SAVINGS', 'CURRENT', 'TERM_DEPOSIT', 'LOAN', 'OVERDRAFT')),
    account_status      VARCHAR(20) NOT NULL CHECK (account_status IN ('ACTIVE', 'DORMANT', 'FROZEN', 'CLOSED', 'PENDING')),
    open_date           DATE NOT NULL,
    close_date          DATE,
    maturity_date       DATE,
    balance             DECIMAL(18,2) NOT NULL DEFAULT 0,
    available_balance   DECIMAL(18,2) NOT NULL DEFAULT 0,
    hold_amount         DECIMAL(18,2) NOT NULL DEFAULT 0,
    credit_limit        DECIMAL(18,2),
    interest_rate       DECIMAL(10,6),
    last_transaction_date DATE,
    dormant_date        DATE,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES oltp.customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES oltp.products(product_id),
    FOREIGN KEY (branch_id) REFERENCES oltp.branches(branch_id)
);

-- ============================================================================
-- 8. CREATE TABLES - TRANSACTIONS
-- ============================================================================
CREATE TABLE oltp.transactions (
    transaction_id      BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_code    VARCHAR(30) NOT NULL UNIQUE,
    account_id          INT NOT NULL,
    transaction_type    VARCHAR(30) NOT NULL CHECK (transaction_type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN', 'TRANSFER_OUT', 'FEE', 'INTEREST', 'REVERSAL', 'ADJUSTMENT')),
    transaction_channel VARCHAR(30) NOT NULL CHECK (transaction_channel IN ('COUNTER', 'ATM', 'MOBILE', 'INTERNET', 'SWIFT', 'ACH', 'POS', 'CHEQUE')),
    transaction_date    DATETIME NOT NULL,
    value_date          DATE NOT NULL,
    amount              DECIMAL(18,2) NOT NULL,
    currency            VARCHAR(3) NOT NULL DEFAULT 'USD',
    exchange_rate       DECIMAL(10,6) DEFAULT 1.0,
    balance_before      DECIMAL(18,2),
    balance_after       DECIMAL(18,2),
    fee_amount          DECIMAL(18,2) DEFAULT 0,
    tax_amount          DECIMAL(18,2) DEFAULT 0,
    description         NVARCHAR(500),
    reference_number    VARCHAR(30),
    counterparty_account VARCHAR(30),
    counterparty_bank   VARCHAR(100),
    status              VARCHAR(20) NOT NULL DEFAULT 'COMPLETED' CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REVERSED')),
    posted_by           INT,
    authorized_by       INT,
    branch_id           INT NOT NULL,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (account_id) REFERENCES oltp.accounts(account_id),
    FOREIGN KEY (posted_by) REFERENCES oltp.employees(employee_id),
    FOREIGN KEY (branch_id) REFERENCES oltp.branches(branch_id)
);

-- Create indexes for transactions
CREATE INDEX IX_Transactions_AccountDate ON oltp.transactions(account_id, transaction_date);
CREATE INDEX IX_Transactions_Date ON oltp.transactions(transaction_date);
CREATE INDEX IX_Transactions_Type ON oltp.transactions(transaction_type);

-- ============================================================================
-- 9. CREATE TABLES - LOANS
-- ============================================================================
CREATE TABLE oltp.loans (
    loan_id             INT IDENTITY(1,1) PRIMARY KEY,
    loan_number         VARCHAR(30) NOT NULL UNIQUE,
    application_number  VARCHAR(30) NOT NULL,
    customer_id         INT NOT NULL,
    product_id          INT NOT NULL,
    branch_id           INT NOT NULL,
    loan_amount         DECIMAL(18,2) NOT NULL,
    approved_amount     DECIMAL(18,2),
    disbursed_amount    DECIMAL(18,2) DEFAULT 0,
    outstanding_principal DECIMAL(18,2) DEFAULT 0,
    interest_rate       DECIMAL(10,6) NOT NULL,
    interest_type       VARCHAR(20) CHECK (interest_type IN ('FIXED', 'VARIABLE', 'BASE_RATE')),
    term_months         INT NOT NULL,
    emi_amount          DECIMAL(18,2),
    disbursement_date   DATE,
    maturity_date       DATE,
    first_payment_date  DATE,
    loan_status         VARCHAR(20) NOT NULL CHECK (loan_status IN ('APPLICATION', 'UNDER_REVIEW', 'APPROVED', 'DISBURSED', 'REPAYING', 'OVERDUE', 'NPL', 'WRITTEN_OFF', 'CLOSED')),
    collateral_type     VARCHAR(50),
    collateral_value    DECIMAL(18,2),
    guarantee_amount    DECIMAL(18,2),
    provision_amount    DECIMAL(18,2) DEFAULT 0,
    days_past_due       INT DEFAULT 0,
    risk_classification VARCHAR(20) CHECK (risk_classification IN ('STANDARD', 'SPECIAL_MENTION', 'SUBSTANDARD', 'DOUBTFUL', 'LOSS')),
    relationship_officer_id INT,
    approval_date       DATE,
    approval_authority  VARCHAR(50),
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES oltp.customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES oltp.products(product_id),
    FOREIGN KEY (branch_id) REFERENCES oltp.branches(branch_id),
    FOREIGN KEY (relationship_officer_id) REFERENCES oltp.employees(employee_id)
);

-- ============================================================================
-- 10. CREATE TABLES - LOAN SCHEDULES
-- ============================================================================
CREATE TABLE oltp.loan_schedules (
    schedule_id         INT IDENTITY(1,1) PRIMARY KEY,
    loan_id             INT NOT NULL,
    installment_number  INT NOT NULL,
    due_date            DATE NOT NULL,
    principal_amount    DECIMAL(18,2) NOT NULL,
    interest_amount     DECIMAL(18,2) NOT NULL,
    total_amount        DECIMAL(18,2) NOT NULL,
    paid_amount         DECIMAL(18,2) DEFAULT 0,
    paid_date           DATE,
    outstanding_balance DECIMAL(18,2),
    status              VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID', 'PARTIAL', 'OVERDUE', 'WAIVED')),
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (loan_id) REFERENCES oltp.loans(loan_id)
);

-- ============================================================================
-- 11. CREATE TABLES - DEPOSITS
-- ============================================================================
CREATE TABLE oltp.deposits (
    deposit_id          INT IDENTITY(1,1) PRIMARY KEY,
    deposit_number      VARCHAR(30) NOT NULL UNIQUE,
    account_id          INT NOT NULL,
    customer_id         INT NOT NULL,
    product_id          INT NOT NULL,
    deposit_type        VARCHAR(30) NOT NULL CHECK (deposit_type IN ('FIXED', 'RECURRING', 'SAVINGS', 'TERM')),
    principal_amount    DECIMAL(18,2) NOT NULL,
    interest_rate       DECIMAL(10,6) NOT NULL,
    term_months         INT,
    start_date          DATE NOT NULL,
    maturity_date       DATE NOT NULL,
    maturity_amount     DECIMAL(18,2),
    interest_earned     DECIMAL(18,2) DEFAULT 0,
    tax_on_interest     DECIMAL(18,2) DEFAULT 0,
    auto_renew          BIT DEFAULT 0,
    status              VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'MATURED', 'CLOSED', 'PREMATURELY_CLOSED')),
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (account_id) REFERENCES oltp.accounts(account_id),
    FOREIGN KEY (customer_id) REFERENCES oltp.customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES oltp.products(product_id)
);

-- ============================================================================
-- 12. CREATE TABLES - CARDS
-- ============================================================================
CREATE TABLE oltp.cards (
    card_id             INT IDENTITY(1,1) PRIMARY KEY,
    card_number         VARCHAR(20) NOT NULL UNIQUE,  -- Masked
    card_token          VARCHAR(50) NOT NULL,
    customer_id         INT NOT NULL,
    account_id          INT NOT NULL,
    card_type           VARCHAR(20) NOT NULL CHECK (card_type IN ('DEBIT', 'CREDIT', 'PREPAID')),
    card_brand          VARCHAR(20) CHECK (card_brand IN ('VISA', 'MASTERCARD', 'UPI', 'JCB')),
    card_class          VARCHAR(20) CHECK (card_class IN ('CLASSIC', 'GOLD', 'PLATINUM', 'INFINITE')),
    issue_date          DATE NOT NULL,
    expiry_date         DATE NOT NULL,
    credit_limit        DECIMAL(18,2),
    current_balance     DECIMAL(18,2) DEFAULT 0,
    available_credit    DECIMAL(18,2) DEFAULT 0,
    card_status         VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (card_status IN ('ACTIVE', 'BLOCKED', 'EXPIRED', 'CANCELLED', 'PENDING')),
    daily_limit         DECIMAL(18,2),
    monthly_limit       DECIMAL(18,2),
    pin_set             BIT DEFAULT 1,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES oltp.customers(customer_id),
    FOREIGN KEY (account_id) REFERENCES oltp.accounts(account_id)
);

-- ============================================================================
-- 13. CREATE TABLES - FX TRANSACTIONS
-- ============================================================================
CREATE TABLE oltp.fx_transactions (
    fx_id               INT IDENTITY(1,1) PRIMARY KEY,
    fx_code             VARCHAR(30) NOT NULL UNIQUE,
    customer_id         INT,
    account_id          INT,
    transaction_type    VARCHAR(20) NOT NULL CHECK (transaction_type IN ('BUY', 'SELL', 'TRANSFER')),
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
    settlement_status   VARCHAR(20) DEFAULT 'SETTLED',
    branch_id           INT NOT NULL,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES oltp.customers(customer_id),
    FOREIGN KEY (account_id) REFERENCES oltp.accounts(account_id),
    FOREIGN KEY (branch_id) REFERENCES oltp.branches(branch_id)
);

-- ============================================================================
-- 14. CREATE TABLES - CHEQUES
-- ============================================================================
CREATE TABLE oltp.cheques (
    cheque_id           INT IDENTITY(1,1) PRIMARY KEY,
    cheque_number       VARCHAR(20) NOT NULL,
    account_id          INT NOT NULL,
    cheque_type         VARCHAR(20) CHECK (cheque_type IN ('ISSUED', 'RECEIVED')),
    face_value          DECIMAL(18,2) NOT NULL,
    payee_name          NVARCHAR(200),
    issue_date          DATE NOT NULL,
    presentation_date   DATE,
    clearing_date       DATE,
    status              VARCHAR(20) NOT NULL DEFAULT 'OUTSTANDING' CHECK (status IN ('OUTSTANDING', 'PRESENTED', 'CLEARED', 'RETURNED', 'STOPPED')),
    return_reason       NVARCHAR(200),
    branch_id           INT NOT NULL,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (account_id) REFERENCES oltp.accounts(account_id),
    FOREIGN KEY (branch_id) REFERENCES oltp.branches(branch_id)
);

-- ============================================================================
-- 15. CREATE TABLES - GL ENTRIES
-- ============================================================================
CREATE TABLE oltp.gl_entries (
    entry_id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    gl_account_code     VARCHAR(20) NOT NULL,
    transaction_date    DATE NOT NULL,
    debit_amount        DECIMAL(18,2) DEFAULT 0,
    credit_amount       DECIMAL(18,2) DEFAULT 0,
    description         NVARCHAR(500),
    reference_type      VARCHAR(50),
    reference_id        BIGINT,
    branch_id           INT NOT NULL,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    posted_by           INT,
    FOREIGN KEY (branch_id) REFERENCES oltp.branches(branch_id)
);

CREATE INDEX IX_GL_Entries_AccountDate ON oltp.gl_entries(gl_account_code, transaction_date);

-- ============================================================================
-- 16. CREATE TABLES - AML ALERTS
-- ============================================================================
CREATE TABLE oltp.aml_alerts (
    alert_id            INT IDENTITY(1,1) PRIMARY KEY,
    alert_code          VARCHAR(30) NOT NULL UNIQUE,
    customer_id         INT,
    transaction_id      BIGINT,
    alert_type          VARCHAR(50) NOT NULL CHECK (alert_type IN ('STRUCTURING', 'UNUSUAL_PATTERN', 'HIGH_VALUE', 'SANCTIONS_MATCH', 'PEP_TRANSACTION', 'VEHICLE', 'OTHER')),
    alert_description   NVARCHAR(1000),
    risk_score          INT CHECK (risk_score BETWEEN 1 AND 100),
    status              VARCHAR(20) NOT NULL DEFAULT 'NEW' CHECK (status IN ('NEW', 'UNDER_REVIEW', 'ESCALATED', 'CLOSED_FALSE_POSITIVE', 'SAR_FILED')),
    assigned_to         INT,
    review_date         DATE,
    resolution_notes    NVARCHAR(1000),
    sar_reference       VARCHAR(50),
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date       DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (customer_id) REFERENCES oltp.customers(customer_id),
    FOREIGN KEY (transaction_id) REFERENCES oltp.transactions(transaction_id),
    FOREIGN KEY (assigned_to) REFERENCES oltp.employees(employee_id)
);

-- ============================================================================
-- 17. CREATE TABLES - AUDIT LOG
-- ============================================================================
CREATE TABLE oltp.audit_log (
    audit_id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    table_name          VARCHAR(100) NOT NULL,
    record_id           BIGINT NOT NULL,
    action              VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values          NVARCHAR(MAX),
    new_values          NVARCHAR(MAX),
    performed_by        INT,
    performed_date      DATETIME NOT NULL DEFAULT GETDATE(),
    ip_address          VARCHAR(45)
);

-- ============================================================================
-- 18. CREATE TABLES - EXCHANGE RATES
-- ============================================================================
CREATE TABLE oltp.exchange_rates (
    rate_id             INT IDENTITY(1,1) PRIMARY KEY,
    source_currency     VARCHAR(3) NOT NULL,
    target_currency     VARCHAR(3) NOT NULL,
    rate                DECIMAL(10,6) NOT NULL,
    bid_rate            DECIMAL(10,6),
    ask_rate            DECIMAL(10,6),
    rate_date           DATE NOT NULL,
    created_date        DATETIME NOT NULL DEFAULT GETDATE(),
    UNIQUE (source_currency, target_currency, rate_date)
);

-- ============================================================================
-- 19. INSERT SAMPLE DATA - BRANCHES
-- ============================================================================
SET IDENTITY_INSERT oltp.branches ON;

INSERT INTO oltp.branches (branch_id, branch_code, branch_name, branch_name_kh, branch_type, region, province, district, is_active) VALUES
(1, 'HO001', 'Head Office', 'ការិយាល័យកណ្តាល', 'HEAD_OFFICE', 'Phnom Penh', 'Phnom Penh', 'Chamkarmon', 1),
(2, 'BR001', 'Phnom Penh Main', 'សាខាព្រៃវែង', 'BRANCH', 'Phnom Penh', 'Phnom Penh', 'Prampir Meakkakra', 1),
(3, 'BR002', 'Siem Reap', 'សាខាសៀមរាប', 'BRANCH', 'North West', 'Siem Reap', 'Siem Reap', 1),
(4, 'BR003', 'Battambang', 'សាខាបាត់ដំបង', 'BRANCH', 'West', 'Battambang', 'Battambang', 1),
(5, 'BR004', 'Sihanoukville', 'សាខាខេត្តព្រះសីហនុ', 'BRANCH', 'South West', 'Sihanoukville', 'Sihanoukville', 1),
(6, 'BR005', 'Kampong Cham', 'សាខាកំពូញចាម', 'BRANCH', 'East', 'Kampong Cham', 'Kampong Cham', 1),
(7, 'SB001', 'Toul Kork Sub Branch', 'សាខាត្បូងឃ្មុំ', 'SUB_BRANCH', 'Phnom Penh', 'Phnom Penh', 'Toul Kork', 1),
(8, 'SB002', 'Chbar Ampov Sub Branch', 'សាខាជ្រោយអំពិល', 'SUB_BRANCH', 'Phnom Penh', 'Phnom Penh', 'Chbar Ampov', 1),
(9, 'AG001', 'Monivong Agent', 'ភ្នំពេញ មុនីវង្ស', 'AGENT', 'Phnom Penh', 'Phnom Penh', 'Prampir Meakkakra', 1),
(10, 'BR006', 'Kampong Chhnang', 'សាខាកំពុងឆ្នាំង', 'BRANCH', 'Central', 'Kampong Chhnang', 'Kampong Chhnang', 1);

SET IDENTITY_INSERT oltp.branches OFF;

-- ============================================================================
-- 20. INSERT SAMPLE DATA - EMPLOYEES
-- ============================================================================
SET IDENTITY_INSERT oltp.employees ON;

INSERT INTO oltp.employees (employee_id, employee_code, first_name, last_name, gender, hire_date, job_title, department, branch_id, is_active) VALUES
(1, 'EMP001', 'Dara', 'Sok', 'M', '2015-01-15', 'Chief Executive Officer', 'Executive', 1, 1),
(2, 'EMP002', 'Sophea', 'Chen', 'F', '2016-03-20', 'Head of Retail Banking', 'Retail Banking', 1, 1),
(3, 'EMP003', 'Vannak', 'Lim', 'M', '2017-06-10', 'Branch Manager', 'Branch Operations', 2, 1),
(4, 'EMP004', 'Chantrea', 'Ung', 'F', '2018-02-01', 'Branch Manager', 'Branch Operations', 3, 1),
(5, 'EMP005', 'Bopha', 'Ou', 'F', '2018-09-15', 'Branch Manager', 'Branch Operations', 4, 1),
(6, 'EMP006', 'Kosal', 'Pich', 'M', '2019-01-10', 'Branch Manager', 'Branch Operations', 5, 1),
(7, 'EMP007', 'Makara', 'Heng', 'M', '2019-05-20', 'Branch Manager', 'Branch Operations', 6, 1),
(8, 'EMP008', 'Ratha', 'Yorn', 'F', '2020-03-01', 'Sub Branch Manager', 'Branch Operations', 7, 1),
(9, 'EMP009', 'Sovichet', 'Keo', 'M', '2020-07-15', 'Sub Branch Manager', 'Branch Operations', 8, 1),
(10, 'EMP010', 'Borey', 'Tang', 'M', '2021-01-20', 'Teller', 'Branch Operations', 2, 1);

SET IDENTITY_INSERT oltp.employees OFF;

-- Update branch managers
UPDATE oltp.branches SET manager_id = 1 WHERE branch_id = 1;
UPDATE oltp.branches SET manager_id = 3 WHERE branch_id = 2;
UPDATE oltp.branches SET manager_id = 4 WHERE branch_id = 3;
UPDATE oltp.branches SET manager_id = 5 WHERE branch_id = 4;
UPDATE oltp.branches SET manager_id = 6 WHERE branch_id = 5;
UPDATE oltp.branches SET manager_id = 7 WHERE branch_id = 6;
UPDATE oltp.branches SET manager_id = 8 WHERE branch_id = 7;
UPDATE oltp.branches SET manager_id = 9 WHERE branch_id = 8;

-- ============================================================================
-- 21. INSERT SAMPLE DATA - PRODUCTS
-- ============================================================================
SET IDENTITY_INSERT oltp.products ON;

INSERT INTO oltp.products (product_id, product_code, product_name, product_category, product_subcategory, currency, interest_rate, min_balance, is_active, effective_date) VALUES
-- Deposits
(1, 'SAV001', 'Regular Savings', 'DEPOSIT', 'SAVINGS', 'USD', 0.5000, 1.00, 1, '2024-01-01'),
(2, 'FIX001', 'Fixed Deposit 3M', 'DEPOSIT', 'TERM_DEPOSIT', 'USD', 4.5000, 100.00, 1, '2024-01-01'),
(3, 'FIX002', 'Fixed Deposit 6M', 'DEPOSIT', 'TERM_DEPOSIT', 'USD', 5.0000, 100.00, 1, '2024-01-01'),
(4, 'FIX003', 'Fixed Deposit 12M', 'DEPOSIT', 'TERM_DEPOSIT', 'USD', 5.5000, 100.00, 1, '2024-01-01'),
(5, 'CUR001', 'Current Account', 'DEPOSIT', 'CURRENT', 'USD', 0.0000, 0.00, 1, '2024-01-01'),
-- Loans
(10, 'PLN001', 'Personal Loan', 'LOAN', 'PERSONAL', 'USD', 12.0000, NULL, 1, '2024-01-01'),
(11, 'PLN002', 'Home Loan', 'LOAN', 'MORTGAGE', 'USD', 8.5000, NULL, 1, '2024-01-01'),
(12, 'PLN003', 'Auto Loan', 'LOAN', 'VEHICLE', 'USD', 9.5000, NULL, 1, '2024-01-01'),
(13, 'PLN004', 'Business Loan', 'LOAN', 'SME', 'USD', 10.0000, NULL, 1, '2024-01-01'),
(14, 'PLN005', 'Micro Loan', 'LOAN', 'MICRO', 'USD', 18.0000, NULL, 1, '2024-01-01'),
-- Cards
(20, 'CRD001', 'Debit Card Classic', 'CARD', 'DEBIT', 'USD', 0.0000, NULL, 1, '2024-01-01'),
(21, 'CRD002', 'Credit Card Gold', 'CARD', 'CREDIT', 'USD', 1.5000, NULL, 1, '2024-01-01'),
-- Transfers
(30, 'TRF001', 'Local Transfer', 'TRANSFER', 'LOCAL', 'USD', 0.0000, NULL, 1, '2024-01-01'),
(31, 'TRF002', 'International Wire', 'TRANSFER', 'SWIFT', 'USD', 0.0000, NULL, 1, '2024-01-01'),
-- FX
(40, 'FX001', 'Cash Exchange', 'FOREIGN_EXCHANGE', 'CASH', 'USD', 0.0000, NULL, 1, '2024-01-01'),
(41, 'FX002', 'Telegraphic Transfer', 'FOREIGN_EXCHANGE', 'TT', 'USD', 0.0000, NULL, 1, '2024-01-01');

SET IDENTITY_INSERT oltp.products OFF;

-- ============================================================================
-- 22. INSERT SAMPLE DATA - CUSTOMERS
-- ============================================================================
SET IDENTITY_INSERT oltp.customers ON;

INSERT INTO oltp.customers (customer_id, customer_code, customer_type, first_name, last_name, national_id, date_of_birth, gender, phone_primary, province, district, customer_segment, risk_rating, kyc_status, opening_branch_id, is_active) VALUES
(1, 'CUST001', 'INDIVIDUAL', 'Chamroeun', 'Pan', 'ID001', '1985-03-15', 'M', '012345678', 'Phnom Penh', 'Chamkarmon', 'RETAIL', 'LOW', 'VERIFIED', 2, 1),
(2, 'CUST002', 'INDIVIDUAL', 'Kanya', 'Hak', 'ID002', '1990-07-22', 'F', '098765432', 'Phnom Penh', 'Prampir Meakkakra', 'RETAIL', 'LOW', 'VERIFIED', 2, 1),
(3, 'CUST003', 'CORPORATE', 'Golden', 'Dragon Trading Co.', 'ID003', NULL, NULL, '011223344', 'Phnom Penh', 'Toul Kork', 'CORPORATE', 'LOW', 'VERIFIED', 2, 1),
(4, 'CUST004', 'INDIVIDUAL', 'Sophal', 'Prak', 'ID004', '1978-11-30', 'M', '022334455', 'Siem Reap', 'Siem Reap', 'SME', 'MEDIUM', 'VERIFIED', 3, 1),
(5, 'CUST005', 'INDIVIDUAL', 'Davy', 'Ung', 'ID005', '1992-05-18', 'F', '033445566', 'Battambang', 'Battambang', 'RETAIL', 'LOW', 'VERIFIED', 4, 1),
(6, 'CUST006', 'CORPORATE', 'Mekong', 'Import Export Ltd.', 'ID006', NULL, NULL, '044556677', 'Phnom Penh', 'Chamkarmon', 'CORPORATE', 'MEDIUM', 'VERIFIED', 2, 1),
(7, 'CUST007', 'INDIVIDUAL', 'Bopha', 'Sim', 'ID007', '1988-09-05', 'F', '055667788', 'Kampong Cham', 'Kampong Cham', 'RETAIL', 'LOW', 'VERIFIED', 6, 1),
(8, 'CUST008', 'INDIVIDUAL', 'Vuthy', 'Koam', 'ID008', '1995-01-25', 'M', '066778899', 'Sihanoukville', 'Sihanoukville', 'SME', 'LOW', 'VERIFIED', 5, 1),
(9, 'CUST009', 'INDIVIDUAL', 'Nary', 'Touch', 'ID009', '1982-12-12', 'F', '077889900', 'Phnom Penh', 'Toul Kork', 'PRIVATE_BANKING', 'LOW', 'VERIFIED', 7, 1),
(10, 'CUST010', 'INDIVIDUAL', 'Rith', 'Srun', 'ID010', '1998-04-08', 'M', '088990011', 'Phnom Penh', 'Chbar Ampov', 'MICRO', 'MEDIUM', 'VERIFIED', 8, 1);

SET IDENTITY_INSERT oltp.customers OFF;

-- ============================================================================
-- 23. INSERT SAMPLE DATA - ACCOUNTS
-- ============================================================================
SET IDENTITY_INSERT oltp.accounts ON;

INSERT INTO oltp.accounts (account_id, account_number, customer_id, product_id, branch_id, currency, account_type, account_status, open_date, balance, available_balance, is_active) VALUES
(1, '1001-001-001', 1, 1, 2, 'USD', 'SAVINGS', 'ACTIVE', '2020-01-15', 5230.50, 5230.50, 1),
(2, '1001-001-002', 1, 5, 2, 'USD', 'CURRENT', 'ACTIVE', '2020-01-15', 12450.00, 12450.00, 1),
(3, '1001-002-001', 2, 1, 2, 'USD', 'SAVINGS', 'ACTIVE', '2021-03-20', 3875.25, 3875.25, 1),
(4, '1001-003-001', 3, 5, 2, 'USD', 'CURRENT', 'ACTIVE', '2019-06-10', 156789.00, 156789.00, 1),
(5, '1001-003-002', 3, 2, 2, 'USD', 'TERM_DEPOSIT', 'ACTIVE', '2024-01-01', 50000.00, 50000.00, 1),
(6, '1001-004-001', 4, 1, 3, 'USD', 'SAVINGS', 'ACTIVE', '2020-06-15', 8920.75, 8920.75, 1),
(7, '1001-005-001', 5, 1, 4, 'USD', 'SAVINGS', 'ACTIVE', '2021-09-10', 2345.00, 2345.00, 1),
(8, '1001-006-001', 6, 5, 2, 'USD', 'CURRENT', 'ACTIVE', '2018-01-20', 234567.89, 234567.89, 1),
(9, '1001-006-002', 6, 3, 2, 'USD', 'TERM_DEPOSIT', 'ACTIVE', '2024-06-01', 100000.00, 100000.00, 1),
(10, '1001-007-001', 7, 1, 6, 'USD', 'SAVINGS', 'ACTIVE', '2022-01-05', 4567.89, 4567.89, 1),
(11, '1001-008-001', 8, 1, 5, 'USD', 'SAVINGS', 'ACTIVE', '2022-05-20', 6789.00, 6789.00, 1),
(12, '1001-009-001', 9, 5, 7, 'USD', 'CURRENT', 'ACTIVE', '2023-01-10', 89012.34, 89012.34, 1),
(13, '1001-010-001', 10, 1, 8, 'USD', 'SAVINGS', 'ACTIVE', '2023-06-15', 1234.56, 1234.56, 1);

SET IDENTITY_INSERT oltp.accounts OFF;

-- ============================================================================
-- 24. INSERT SAMPLE DATA - TRANSACTIONS (Last 30 days)
-- ============================================================================
SET IDENTITY_INSERT oltp.transactions ON;

-- Generate sample transactions for the last 30 days
DECLARE @i INT = 1;
DECLARE @trans_date DATE = DATEADD(DAY, -30, GETDATE());
DECLARE @account_ids TABLE (id INT);
INSERT INTO @account_ids VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(13);

DECLARE @counter INT = 1;
WHILE @counter <= 500
BEGIN
    DECLARE @acct_id INT = (SELECT TOP 1 id FROM @account_ids ORDER BY NEWID());
    DECLARE @trans_type VARCHAR(30) = CASE ABS(CHECKSUM(NEWID()) % 4)
        WHEN 0 THEN 'DEPOSIT'
        WHEN 1 THEN 'WITHDRAWAL'
        WHEN 2 THEN 'TRANSFER_IN'
        ELSE 'TRANSFER_OUT'
    END;
    DECLARE @amt DECIMAL(18,2) = ROUND(RAND() * 5000 + 10, 2);
    DECLARE @tdate DATE = DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 30), @trans_date);
    DECLARE @tdatetime DATETIME = DATEADD(HOUR, ABS(CHECKSUM(NEWID()) % 12) + 8, @tdate);
    
    INSERT INTO oltp.transactions (transaction_code, account_id, transaction_type, transaction_channel, transaction_date, value_date, amount, balance_before, balance_after, status, branch_id)
    VALUES (
        'TXN' + FORMAT(@counter, '000000'),
        @acct_id,
        @trans_type,
        CASE ABS(CHECKSUM(NEWID()) % 4)
            WHEN 0 THEN 'COUNTER'
            WHEN 1 THEN 'ATM'
            WHEN 2 THEN 'MOBILE'
            ELSE 'INTERNET'
        END,
        @tdatetime,
        @tdate,
        @amt,
        @amt * 0.8,
        @amt * 1.2,
        'COMPLETED',
        (SELECT branch_id FROM oltp.accounts WHERE account_id = @acct_id)
    );
    
    SET @counter = @counter + 1;
END;

SET IDENTITY_INSERT oltp.transactions OFF;

-- ============================================================================
-- 25. INSERT SAMPLE DATA - LOANS
-- ============================================================================
SET IDENTITY_INSERT oltp.loans ON;

INSERT INTO oltp.loans (loan_id, loan_number, application_number, customer_id, product_id, branch_id, loan_amount, approved_amount, disbursed_amount, outstanding_principal, interest_rate, term_months, emi_amount, disbursement_date, maturity_date, loan_status, risk_classification, days_past_due, created_date) VALUES
(1, 'LN20240001', 'APP20240001', 1, 10, 2, 10000.00, 10000.00, 10000.00, 7500.00, 12.0000, 24, 470.72, '2024-01-15', '2026-01-15', 'REPAYING', 'STANDARD', 0, GETDATE()),
(2, 'LN20240002', 'APP20240002', 4, 13, 3, 50000.00, 50000.00, 50000.00, 42000.00, 10.0000, 60, 1062.43, '2024-02-01', '2029-02-01', 'REPAYING', 'STANDARD', 0, GETDATE()),
(3, 'LN20240003', 'APP20240003', 5, 11, 4, 25000.00, 25000.00, 25000.00, 22500.00, 8.5000, 120, 308.51, '2024-03-15', '2034-03-15', 'REPAYING', 'STANDARD', 0, GETDATE()),
(4, 'LN20240004', 'APP20240004', 8, 12, 5, 15000.00, 15000.00, 15000.00, 13500.00, 9.5000, 60, 314.59, '2024-04-01', '2029-04-01', 'REPAYING', 'STANDARD', 0, GETDATE()),
(5, 'LN20240005', 'APP20240005', 10, 14, 8, 2000.00, 2000.00, 2000.00, 1800.00, 18.0000, 12, 183.33, '2024-05-15', '2025-05-15', 'REPAYING', 'STANDARD', 0, GETDATE()),
(6, 'LN20240006', 'APP20240006', 2, 10, 2, 8000.00, 8000.00, 8000.00, 6500.00, 12.0000, 24, 376.58, '2024-06-01', '2026-06-01', 'REPAYING', 'STANDARD', 0, GETDATE()),
(7, 'LN20240007', 'APP20240007', 7, 11, 6, 30000.00, 30000.00, 30000.00, 28000.00, 8.5000, 120, 370.21, '2024-07-15', '2034-07-15', 'REPAYING', 'SPECIAL_MENTION', 15, GETDATE()),
(8, 'LN20240008', 'APP20240008', 9, 13, 7, 100000.00, 100000.00, 100000.00, 85000.00, 10.0000, 60, 2124.86, '2024-08-01', '2029-08-01', 'REPAYING', 'STANDARD', 0, GETDATE());

SET IDENTITY_INSERT oltp.loans OFF;

-- ============================================================================
-- 26. INSERT SAMPLE DATA - CARDS
-- ============================================================================
SET IDENTITY_INSERT oltp.cards ON;

INSERT INTO oltp.cards (card_id, card_number, card_token, customer_id, account_id, card_type, card_brand, card_class, issue_date, expiry_date, credit_limit, current_balance, card_status) VALUES
(1, '4***-****-****-1234', 'tok_abc123', 1, 2, 'DEBIT', 'VISA', 'CLASSIC', '2020-01-20', '2025-01-20', NULL, 0, 'ACTIVE'),
(2, '4***-****-****-5678', 'tok_def456', 2, 3, 'DEBIT', 'VISA', 'CLASSIC', '2021-03-25', '2026-03-25', NULL, 0, 'ACTIVE'),
(3, '5***-****-****-9012', 'tok_ghi789', 3, 4, 'CREDIT', 'MASTERCARD', 'GOLD', '2019-06-15', '2024-06-15', 20000.00, 5678.90, 'EXPIRED'),
(4, '4***-****-****-3456', 'tok_jkl012', 9, 12, 'CREDIT', 'VISA', 'PLATINUM', '2023-01-15', '2028-01-15', 50000.00, 12345.67, 'ACTIVE'),
(5, '5***-****-****-7890', 'tok_mno345', 6, 8, 'CREDIT', 'MASTERCARD', 'GOLD', '2022-05-20', '2027-05-20', 30000.00, 8901.23, 'ACTIVE');

SET IDENTITY_INSERT oltp.cards OFF;

-- ============================================================================
-- 27. INSERT SAMPLE DATA - EXCHANGE RATES
-- ============================================================================
INSERT INTO oltp.exchange_rates (source_currency, target_currency, rate, bid_rate, ask_rate, rate_date) VALUES
('USD', 'KHR', 4100.00, 4095.00, 4105.00, GETDATE()),
('USD', 'KHR', 4098.50, 4093.50, 4103.50, DATEADD(DAY, -1, GETDATE())),
('USD', 'KHR', 4097.00, 4092.00, 4102.00, DATEADD(DAY, -2, GETDATE())),
('EUR', 'USD', 1.0850, 1.0830, 1.0870, GETDATE()),
('EUR', 'KHR', 4448.50, 4443.50, 4453.50, GETDATE()),
('GBP', 'USD', 1.2650, 1.2630, 1.2670, GETDATE()),
('GBP', 'KHR', 5186.50, 5181.50, 5191.50, GETDATE()),
('THB', 'USD', 0.0285, 0.0283, 0.0287, GETDATE()),
('THB', 'KHR', 116.85, 116.35, 117.35, GETDATE()),
('JPY', 'USD', 0.0067, 0.0066, 0.0068, GETDATE()),
('JPY', 'KHR', 27.47, 26.97, 27.97, GETDATE());

-- ============================================================================
-- 28. INSERT SAMPLE DATA - AML ALERTS
-- ============================================================================
SET IDENTITY_INSERT oltp.aml_alerts ON;

INSERT INTO oltp.aml_alerts (alert_id, alert_code, customer_id, transaction_id, alert_type, alert_description, risk_score, status, created_date) VALUES
(1, 'AML20240001', 10, 1, 'STRUCTURING', 'Multiple cash deposits just below reporting threshold', 75, 'UNDER_REVIEW', GETDATE()),
(2, 'AML20240002', 8, 15, 'HIGH_VALUE', 'Large single transaction exceeding usual pattern', 60, 'NEW', GETDATE()),
(3, 'AML20240003', NULL, 25, 'UNUSUAL_PATTERN', 'Unusual transfer pattern detected', 45, 'CLOSED_FALSE_POSITIVE', DATEADD(DAY, -5, GETDATE()));

SET IDENTITY_INSERT oltp.aml_alerts OFF;

-- ============================================================================
-- 29. CREATE VIEWS FOR ETL
-- ============================================================================
GO

-- View for customer extract
CREATE VIEW oltp.v_customer_extract AS
SELECT 
    c.customer_id,
    c.customer_code,
    c.customer_type,
    c.title,
    c.first_name,
    c.last_name,
    c.company_name,
    c.national_id_type,
    c.national_id,
    c.passport_number,
    c.date_of_birth,
    c.gender,
    c.nationality,
    c.email,
    c.phone_primary,
    c.phone_secondary,
    c.address_line1,
    c.address_line2,
    c.province,
    c.district,
    c.commune,
    c.village,
    c.postal_code,
    c.customer_segment,
    c.risk_rating,
    c.kyc_status,
    c.kyc_verified_date,
    c.kyc_expiry_date,
    c.tax_id,
    c.employer_name,
    c.occupation,
    c.annual_income,
    c.marital_status,
    c.referrer_code,
    c.acquisition_channel,
    b.branch_code AS opening_branch_code,
    c.is_active,
    c.is_pep,
    c.is_sanctioned,
    c.created_date,
    c.modified_date
FROM oltp.customers c
JOIN oltp.branches b ON c.opening_branch_id = b.branch_id;

-- View for account extract
CREATE VIEW oltp.v_account_extract AS
SELECT 
    a.account_id,
    a.account_number,
    c.customer_code,
    p.product_code,
    b.branch_code,
    a.currency,
    a.account_type,
    a.account_status,
    a.open_date,
    a.close_date,
    a.maturity_date,
    a.balance,
    a.available_balance,
    a.hold_amount,
    a.credit_limit,
    a.interest_rate,
    a.last_transaction_date,
    a.is_active,
    a.created_date,
    a.modified_date
FROM oltp.accounts a
JOIN oltp.customers c ON a.customer_id = c.customer_id
JOIN oltp.products p ON a.product_id = p.product_id
JOIN oltp.branches b ON a.branch_id = b.branch_id;

-- View for transaction extract
CREATE VIEW oltp.v_transaction_extract AS
SELECT 
    t.transaction_id,
    t.transaction_code,
    a.account_number,
    c.customer_code,
    t.transaction_type,
    t.transaction_channel,
    t.transaction_date,
    t.value_date,
    t.amount,
    t.currency,
    t.exchange_rate,
    t.balance_before,
    t.balance_after,
    t.fee_amount,
    t.tax_amount,
    t.description,
    t.reference_number,
    t.counterparty_account,
    t.counterparty_bank,
    t.status,
    b.branch_code,
    t.created_date
FROM oltp.transactions t
JOIN oltp.accounts a ON t.account_id = a.account_id
JOIN oltp.customers c ON a.customer_id = c.customer_id
JOIN oltp.branches b ON t.branch_id = b.branch_id;

-- View for loan extract
CREATE VIEW oltp.v_loan_extract AS
SELECT 
    l.loan_id,
    l.loan_number,
    l.application_number,
    c.customer_code,
    p.product_code,
    b.branch_code,
    l.loan_amount,
    l.approved_amount,
    l.disbursed_amount,
    l.outstanding_principal,
    l.interest_rate,
    l.interest_type,
    l.term_months,
    l.emi_amount,
    l.disbursement_date,
    l.maturity_date,
    l.first_payment_date,
    l.loan_status,
    l.collateral_type,
    l.collateral_value,
    l.guarantee_amount,
    l.provision_amount,
    l.days_past_due,
    l.risk_classification,
    e.employee_code AS relationship_officer_code,
    l.approval_date,
    l.approval_authority,
    l.created_date,
    l.modified_date
FROM oltp.loans l
JOIN oltp.customers c ON l.customer_id = c.customer_id
JOIN oltp.products p ON l.product_id = p.product_id
JOIN oltp.branches b ON l.branch_id = b.branch_id
LEFT JOIN oltp.employees e ON l.relationship_officer_id = e.employee_id;

-- ============================================================================
-- 30. VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'SATHAPANA BANK - SOURCE DATABASE CREATED';
PRINT '================================================';
PRINT 'Tables Created:';
SELECT COUNT(*) AS table_count FROM sys.tables WHERE schema_id = SCHEMA_ID('oltp');
PRINT '';
PRINT 'Views Created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('oltp');
PRINT '';
PRINT 'Sample Data Summary:';
SELECT 'Branches' AS entity, COUNT(*) AS count FROM oltp.branches
UNION ALL
SELECT 'Employees', COUNT(*) FROM oltp.employees
UNION ALL
SELECT 'Customers', COUNT(*) FROM oltp.customers
UNION ALL
SELECT 'Products', COUNT(*) FROM oltp.products
UNION ALL
SELECT 'Accounts', COUNT(*) FROM oltp.accounts
UNION ALL
SELECT 'Transactions', COUNT(*) FROM oltp.transactions
UNION ALL
SELECT 'Loans', COUNT(*) FROM oltp.loans
UNION ALL
SELECT 'Cards', COUNT(*) FROM oltp.cards
UNION ALL
SELECT 'Exchange Rates', COUNT(*) FROM oltp.exchange_rates
UNION ALL
SELECT 'AML Alerts', COUNT(*) FROM oltp.aml_alerts;

PRINT '';
PRINT '================================================';
PRINT 'SOURCE DATABASE READY FOR ETL OPERATIONS';
PRINT '================================================';
GO
