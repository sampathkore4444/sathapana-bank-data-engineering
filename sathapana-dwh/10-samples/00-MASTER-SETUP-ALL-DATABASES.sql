-- ============================================================================
-- SATHAPANA BANK - MASTER SETUP SCRIPT
-- ============================================================================
-- Purpose: ONE-CLICK setup for entire data warehouse (10 databases)
-- Author: DWH Development Team
-- Version: 2.0 (Complete Layered Architecture)
-- 
-- INSTRUCTIONS:
-- 1. Open SQL Server Management Studio (SSMS)
-- 2. Connect to your SQL Server instance
-- 3. Open this script
-- 4. Press F5 or click "Execute"
-- 5. Wait for completion (5-10 minutes)
-- ============================================================================

-- ============================================================================
-- PREREQUISITES CHECK
-- ============================================================================
PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║     SATHAPANA BANK - MASTER SETUP SCRIPT                         ║';
PRINT '║     Enterprise Layered Architecture (10 Databases)               ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'This script will create:';
PRINT '  1. sathapana_source (Layer 0 - Source System)';
PRINT '  2. sathapana_raw (Layer 1 - Raw Zone)';
PRINT '  3. sathapana_staging (Staging Area)';
PRINT '  4. sathapana_dwh (Layer 2 - Enterprise DW)';
PRINT '  5. sathapana_dm_credit (Layer 3 - Credit Risk Mart)';
PRINT '  6. sathapana_dm_customer (Layer 3 - Customer Analytics)';
PRINT '  7. sathapana_dm_treasury (Layer 3 - Treasury Mart)';
PRINT '  8. sathapana_dm_compliance (Layer 3 - Compliance/AML)';
PRINT '  9. sathapana_dm_alm (Layer 3 - ALM Mart)';
PRINT ' 10. sathapana_dm_operations (Layer 3 - Operations Mart)';
PRINT '';
PRINT 'Estimated time: 5-10 minutes';
PRINT '';
PRINT 'Starting setup...';
PRINT '';

DECLARE @MasterStart DATETIME = GETDATE();

-- ============================================================================
-- STEP 1: CREATE SOURCE DATABASE (Layer 0)
-- ============================================================================
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'STEP 1: Creating Source Database (Layer 0)...';
PRINT '═══════════════════════════════════════════════════════════════════════';

USE master;
GO

-- Drop if exists
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_source')
BEGIN
    ALTER DATABASE sathapana_source SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_source;
END
GO

CREATE DATABASE sathapana_source;
GO

USE sathapana_source;
GO

-- Create schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'oltp')
    EXEC('CREATE SCHEMA oltp');
GO

-- Create source tables
CREATE TABLE oltp.branches (
    branch_id INT IDENTITY(1,1) PRIMARY KEY,
    branch_code VARCHAR(10) NOT NULL UNIQUE,
    branch_name NVARCHAR(200) NOT NULL,
    branch_name_kh NVARCHAR(200),
    branch_type VARCHAR(20) NOT NULL,
    region VARCHAR(50) NOT NULL,
    province VARCHAR(100) NOT NULL,
    district VARCHAR(100),
    commune NVARCHAR(200),
    village NVARCHAR(200),
    address NVARCHAR(500),
    phone VARCHAR(20),
    email VARCHAR(100),
    manager_id INT,
    is_active BIT NOT NULL DEFAULT 1,
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.employees (
    employee_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_code VARCHAR(20) NOT NULL UNIQUE,
    national_id VARCHAR(20),
    first_name NVARCHAR(100) NOT NULL,
    last_name NVARCHAR(100),
    date_of_birth DATE,
    gender CHAR(1),
    email VARCHAR(100),
    phone VARCHAR(20),
    hire_date DATE NOT NULL,
    termination_date DATE,
    job_title NVARCHAR(200),
    department VARCHAR(100),
    branch_id INT NOT NULL,
    reports_to INT,
    salary_grade VARCHAR(10),
    is_active BIT NOT NULL DEFAULT 1,
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL UNIQUE,
    customer_type VARCHAR(20) NOT NULL,
    title VARCHAR(10),
    first_name NVARCHAR(200) NOT NULL,
    last_name NVARCHAR(200),
    company_name NVARCHAR(500),
    national_id_type VARCHAR(20),
    national_id VARCHAR(30),
    passport_number VARCHAR(30),
    date_of_birth DATE,
    gender CHAR(1),
    nationality VARCHAR(50),
    email VARCHAR(100),
    phone_primary VARCHAR(20),
    phone_secondary VARCHAR(20),
    address_line1 NVARCHAR(300),
    address_line2 NVARCHAR(300),
    province VARCHAR(100),
    district VARCHAR(100),
    commune NVARCHAR(200),
    village NVARCHAR(200),
    postal_code VARCHAR(10),
    customer_segment VARCHAR(50),
    risk_rating VARCHAR(20),
    kyc_status VARCHAR(20),
    kyc_verified_date DATE,
    kyc_expiry_date DATE,
    tax_id VARCHAR(30),
    employer_name NVARCHAR(300),
    occupation VARCHAR(100),
    annual_income DECIMAL(18,2),
    marital_status VARCHAR(20),
    referrer_code VARCHAR(20),
    acquisition_channel VARCHAR(50),
    opening_branch_id INT NOT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    is_pep BIT DEFAULT 0,
    is_sanctioned BIT DEFAULT 0,
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.products (
    product_id INT IDENTITY(1,1) PRIMARY KEY,
    product_code VARCHAR(20) NOT NULL UNIQUE,
    product_name NVARCHAR(200) NOT NULL,
    product_name_kh NVARCHAR(200),
    product_category VARCHAR(50) NOT NULL,
    product_subcategory VARCHAR(100),
    gl_account_code VARCHAR(20),
    currency VARCHAR(3) DEFAULT 'USD',
    interest_rate DECIMAL(10,6),
    min_balance DECIMAL(18,2),
    max_balance DECIMAL(18,2),
    min_amount DECIMAL(18,2),
    max_amount DECIMAL(18,2),
    term_months INT,
    is_active BIT NOT NULL DEFAULT 1,
    effective_date DATE NOT NULL,
    expiry_date DATE,
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.accounts (
    account_id INT IDENTITY(1,1) PRIMARY KEY,
    account_number VARCHAR(30) NOT NULL UNIQUE,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    branch_id INT NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    account_type VARCHAR(20) NOT NULL,
    account_status VARCHAR(20) NOT NULL,
    open_date DATE NOT NULL,
    close_date DATE,
    maturity_date DATE,
    balance DECIMAL(18,2) NOT NULL DEFAULT 0,
    available_balance DECIMAL(18,2) NOT NULL DEFAULT 0,
    hold_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
    credit_limit DECIMAL(18,2),
    interest_rate DECIMAL(10,6),
    last_transaction_date DATE,
    dormant_date DATE,
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.transactions (
    transaction_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    transaction_code VARCHAR(30) NOT NULL UNIQUE,
    account_id INT NOT NULL,
    transaction_type VARCHAR(30) NOT NULL,
    transaction_channel VARCHAR(30) NOT NULL,
    transaction_date DATETIME NOT NULL,
    value_date DATE NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    exchange_rate DECIMAL(10,6) DEFAULT 1.0,
    balance_before DECIMAL(18,2),
    balance_after DECIMAL(18,2),
    fee_amount DECIMAL(18,2) DEFAULT 0,
    tax_amount DECIMAL(18,2) DEFAULT 0,
    description NVARCHAR(500),
    reference_number VARCHAR(30),
    counterparty_account VARCHAR(30),
    counterparty_bank VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    posted_by INT,
    authorized_by INT,
    branch_id INT NOT NULL,
    created_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.loans (
    loan_id INT IDENTITY(1,1) PRIMARY KEY,
    loan_number VARCHAR(30) NOT NULL UNIQUE,
    application_number VARCHAR(30) NOT NULL,
    customer_id INT NOT NULL,
    product_id INT NOT NULL,
    branch_id INT NOT NULL,
    loan_amount DECIMAL(18,2) NOT NULL,
    approved_amount DECIMAL(18,2),
    disbursed_amount DECIMAL(18,2) DEFAULT 0,
    outstanding_principal DECIMAL(18,2) DEFAULT 0,
    interest_rate DECIMAL(10,6) NOT NULL,
    interest_type VARCHAR(20),
    term_months INT NOT NULL,
    emi_amount DECIMAL(18,2),
    disbursement_date DATE,
    maturity_date DATE,
    first_payment_date DATE,
    loan_status VARCHAR(20) NOT NULL,
    collateral_type VARCHAR(50),
    collateral_value DECIMAL(18,2),
    guarantee_amount DECIMAL(18,2),
    provision_amount DECIMAL(18,2) DEFAULT 0,
    days_past_due INT DEFAULT 0,
    risk_classification VARCHAR(20),
    relationship_officer_id INT,
    approval_date DATE,
    approval_authority VARCHAR(50),
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.exchange_rates (
    rate_id INT IDENTITY(1,1) PRIMARY KEY,
    source_currency VARCHAR(3) NOT NULL,
    target_currency VARCHAR(3) NOT NULL,
    rate DECIMAL(10,6) NOT NULL,
    bid_rate DECIMAL(10,6),
    ask_rate DECIMAL(10,6),
    rate_date DATE NOT NULL,
    created_date DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE oltp.aml_alerts (
    alert_id INT IDENTITY(1,1) PRIMARY KEY,
    alert_code VARCHAR(30) NOT NULL UNIQUE,
    customer_id INT,
    transaction_id BIGINT,
    alert_type VARCHAR(50) NOT NULL,
    alert_description NVARCHAR(1000),
    risk_score INT,
    status VARCHAR(20) NOT NULL,
    assigned_to INT,
    review_date DATE,
    resolution_notes NVARCHAR(1000),
    sar_reference VARCHAR(50),
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);

PRINT '✓ Source tables created';
GO

-- ============================================================================
-- INSERT SAMPLE DATA INTO SOURCE
-- ============================================================================
USE sathapana_source;
GO

-- Insert Branches
SET IDENTITY_INSERT oltp.branches ON;
INSERT INTO oltp.branches (branch_id, branch_code, branch_name, branch_name_kh, branch_type, region, province, district, is_active) VALUES
(1, 'HO001', 'Head Office', N'ការិយាល័យកណ្តាល', 'HEAD_OFFICE', 'Phnom Penh', 'Phnom Penh', 'Chamkarmon', 1),
(2, 'BR001', 'Phnom Penh Main', N'សាខាព្រៃវែង', 'BRANCH', 'Phnom Penh', 'Phnom Penh', 'Prampir Meakkakra', 1),
(3, 'BR002', 'Siem Reap', N'សាខាសៀមរាប', 'BRANCH', 'North West', 'Siem Reap', 'Siem Reap', 1),
(4, 'BR003', 'Battambang', N'សាខាបាត់ដំបង', 'BRANCH', 'West', 'Battambang', 'Battambang', 1),
(5, 'BR004', 'Sihanoukville', N'សាខាខេត្តព្រះសីហនុ', 'BRANCH', 'South West', 'Sihanoukville', 'Sihanoukville', 1),
(6, 'BR005', 'Kampong Cham', N'សាខាកំពូញចាម', 'BRANCH', 'East', 'Kampong Cham', 'Kampong Cham', 1),
(7, 'SB001', 'Toul Kork Sub Branch', N'សាខាត្បូងឃ្មុំ', 'SUB_BRANCH', 'Phnom Penh', 'Phnom Penh', 'Toul Kork', 1),
(8, 'SB002', 'Chbar Ampov Sub Branch', N'សាខាជ្រោយអំពិល', 'SUB_BRANCH', 'Phnom Penh', 'Phnom Penh', 'Chbar Ampov', 1),
(9, 'AG001', 'Monivong Agent', N'ភ្នំពេញ មុនីវង្ស', 'AGENT', 'Phnom Penh', 'Phnom Penh', 'Prampir Meakkakra', 1),
(10, 'BR006', 'Kampong Chhnang', N'សាខាកំពុងឆ្នាំង', 'BRANCH', 'Central', 'Kampong Chhnang', 'Kampong Chhnang', 1);
SET IDENTITY_INSERT oltp.branches OFF;

-- Insert Employees
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

-- Insert Products
SET IDENTITY_INSERT oltp.products ON;
INSERT INTO oltp.products (product_id, product_code, product_name, product_category, product_subcategory, currency, interest_rate, min_balance, is_active, effective_date) VALUES
(1, 'SAV001', 'Regular Savings', 'DEPOSIT', 'SAVINGS', 'USD', 0.5000, 1.00, 1, '2024-01-01'),
(2, 'FIX001', 'Fixed Deposit 3M', 'DEPOSIT', 'TERM_DEPOSIT', 'USD', 4.5000, 100.00, 1, '2024-01-01'),
(3, 'FIX002', 'Fixed Deposit 6M', 'DEPOSIT', 'TERM_DEPOSIT', 'USD', 5.0000, 100.00, 1, '2024-01-01'),
(4, 'FIX003', 'Fixed Deposit 12M', 'DEPOSIT', 'TERM_DEPOSIT', 'USD', 5.5000, 100.00, 1, '2024-01-01'),
(5, 'CUR001', 'Current Account', 'DEPOSIT', 'CURRENT', 'USD', 0.0000, 0.00, 1, '2024-01-01'),
(10, 'PLN001', 'Personal Loan', 'LOAN', 'PERSONAL', 'USD', 12.0000, NULL, 1, '2024-01-01'),
(11, 'PLN002', 'Home Loan', 'LOAN', 'MORTGAGE', 'USD', 8.5000, NULL, 1, '2024-01-01'),
(12, 'PLN003', 'Auto Loan', 'LOAN', 'VEHICLE', 'USD', 9.5000, NULL, 1, '2024-01-01'),
(13, 'PLN004', 'Business Loan', 'LOAN', 'SME', 'USD', 10.0000, NULL, 1, '2024-01-01'),
(14, 'PLN005', 'Micro Loan', 'LOAN', 'MICRO', 'USD', 18.0000, NULL, 1, '2024-01-01');
SET IDENTITY_INSERT oltp.products OFF;

-- Insert Customers
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

-- Insert Accounts
SET IDENTITY_INSERT oltp.accounts ON;
INSERT INTO oltp.accounts (account_id, account_number, customer_id, product_id, branch_id, currency, account_type, account_status, open_date, balance, available_balance) VALUES
(1, '1001-001-001', 1, 1, 2, 'USD', 'SAVINGS', 'ACTIVE', '2020-01-15', 5230.50, 5230.50),
(2, '1001-001-002', 1, 5, 2, 'USD', 'CURRENT', 'ACTIVE', '2020-01-15', 12450.00, 12450.00),
(3, '1001-002-001', 2, 1, 2, 'USD', 'SAVINGS', 'ACTIVE', '2021-03-20', 3875.25, 3875.25),
(4, '1001-003-001', 3, 5, 2, 'USD', 'CURRENT', 'ACTIVE', '2019-06-10', 156789.00, 156789.00),
(5, '1001-003-002', 3, 2, 2, 'USD', 'TERM_DEPOSIT', 'ACTIVE', '2024-01-01', 50000.00, 50000.00),
(6, '1001-004-001', 4, 1, 3, 'USD', 'SAVINGS', 'ACTIVE', '2020-06-15', 8920.75, 8920.75),
(7, '1001-005-001', 5, 1, 4, 'USD', 'SAVINGS', 'ACTIVE', '2021-09-10', 2345.00, 2345.00),
(8, '1001-006-001', 6, 5, 2, 'USD', 'CURRENT', 'ACTIVE', '2018-01-20', 234567.89, 234567.89),
(9, '1001-006-002', 6, 3, 2, 'USD', 'TERM_DEPOSIT', 'ACTIVE', '2024-06-01', 100000.00, 100000.00),
(10, '1001-007-001', 7, 1, 6, 'USD', 'SAVINGS', 'ACTIVE', '2022-01-05', 4567.89, 4567.89),
(11, '1001-008-001', 8, 1, 5, 'USD', 'SAVINGS', 'ACTIVE', '2022-05-20', 6789.00, 6789.00),
(12, '1001-009-001', 9, 5, 7, 'USD', 'CURRENT', 'ACTIVE', '2023-01-10', 89012.34, 89012.34),
(13, '1001-010-001', 10, 1, 8, 'USD', 'SAVINGS', 'ACTIVE', '2023-06-15', 1234.56, 1234.56);
SET IDENTITY_INSERT oltp.accounts OFF;

-- Insert Transactions (Generate 200 sample transactions)
SET IDENTITY_INSERT oltp.transactions ON;
DECLARE @i INT = 1;
WHILE @i <= 200
BEGIN
    DECLARE @acct_id INT = (SELECT TOP 1 account_id FROM oltp.accounts ORDER BY NEWID());
    DECLARE @trans_type VARCHAR(30) = CASE ABS(CHECKSUM(NEWID()) % 3) WHEN 0 THEN 'DEPOSIT' WHEN 1 THEN 'WITHDRAWAL' ELSE 'TRANSFER_IN' END;
    DECLARE @amt DECIMAL(18,2) = ROUND(RAND() * 5000 + 10, 2);
    DECLARE @tdate DATE = DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 30), DATEADD(DAY, -30, GETDATE()));
    DECLARE @tdatetime DATETIME = DATEADD(HOUR, ABS(CHECKSUM(NEWID()) % 12) + 8, @tdate);
    
    INSERT INTO oltp.transactions (transaction_id, transaction_code, account_id, transaction_type, transaction_channel, transaction_date, value_date, amount, balance_before, balance_after, status, branch_id)
    VALUES (@i, 'TXN' + FORMAT(@i, '000000'), @acct_id, @trans_type, 
            CASE ABS(CHECKSUM(NEWID()) % 4) WHEN 0 THEN 'COUNTER' WHEN 1 THEN 'ATM' WHEN 2 THEN 'MOBILE' ELSE 'INTERNET' END,
            @tdatetime, @tdate, @amt, @amt * 0.8, @amt * 1.2, 'COMPLETED',
            (SELECT branch_id FROM oltp.accounts WHERE account_id = @acct_id));
    SET @i = @i + 1;
END
SET IDENTITY_INSERT oltp.transactions OFF;

-- Insert Loans
SET IDENTITY_INSERT oltp.loans ON;
INSERT INTO oltp.loans (loan_id, loan_number, application_number, customer_id, product_id, branch_id, loan_amount, approved_amount, disbursed_amount, outstanding_principal, interest_rate, term_months, emi_amount, disbursement_date, maturity_date, loan_status, risk_classification, days_past_due) VALUES
(1, 'LN20240001', 'APP20240001', 1, 10, 2, 10000.00, 10000.00, 10000.00, 7500.00, 12.0000, 24, 470.72, '2024-01-15', '2026-01-15', 'REPAYING', 'STANDARD', 0),
(2, 'LN20240002', 'APP20240002', 4, 13, 3, 50000.00, 50000.00, 50000.00, 42000.00, 10.0000, 60, 1062.43, '2024-02-01', '2029-02-01', 'REPAYING', 'STANDARD', 0),
(3, 'LN20240003', 'APP20240003', 5, 11, 4, 25000.00, 25000.00, 25000.00, 22500.00, 8.5000, 120, 308.51, '2024-03-15', '2034-03-15', 'REPAYING', 'STANDARD', 0),
(4, 'LN20240004', 'APP20240004', 8, 12, 5, 15000.00, 15000.00, 15000.00, 13500.00, 9.5000, 60, 314.59, '2024-04-01', '2029-04-01', 'REPAYING', 'STANDARD', 0),
(5, 'LN20240005', 'APP20240005', 10, 14, 8, 2000.00, 2000.00, 2000.00, 1800.00, 18.0000, 12, 183.33, '2024-05-15', '2025-05-15', 'REPAYING', 'STANDARD', 0),
(6, 'LN20240006', 'APP20240006', 2, 10, 2, 8000.00, 8000.00, 8000.00, 6500.00, 12.0000, 24, 376.58, '2024-06-01', '2026-06-01', 'REPAYING', 'STANDARD', 0),
(7, 'LN20240007', 'APP20240007', 7, 11, 6, 30000.00, 30000.00, 30000.00, 28000.00, 8.5000, 120, 370.21, '2024-07-15', '2034-07-15', 'REPAYING', 'SPECIAL_MENTION', 15),
(8, 'LN20240008', 'APP20240008', 9, 13, 7, 100000.00, 100000.00, 100000.00, 85000.00, 10.0000, 60, 2124.86, '2024-08-01', '2029-08-01', 'REPAYING', 'STANDARD', 0);
SET IDENTITY_INSERT oltp.loans OFF;

-- Insert Exchange Rates
INSERT INTO oltp.exchange_rates (source_currency, target_currency, rate, bid_rate, ask_rate, rate_date) VALUES
('USD', 'KHR', 4100.00, 4095.00, 4105.00, GETDATE()),
('EUR', 'USD', 1.0850, 1.0830, 1.0870, GETDATE()),
('GBP', 'USD', 1.2650, 1.2630, 1.2670, GETDATE()),
('THB', 'USD', 0.0285, 0.0283, 0.0287, GETDATE()),
('JPY', 'USD', 0.0067, 0.0066, 0.0068, GETDATE());

-- Insert AML Alerts
SET IDENTITY_INSERT oltp.aml_alerts ON;
INSERT INTO oltp.aml_alerts (alert_id, alert_code, customer_id, transaction_id, alert_type, alert_description, risk_score, status) VALUES
(1, 'AML20240001', 10, 1, 'STRUCTURING', 'Multiple cash deposits just below reporting threshold', 75, 'UNDER_REVIEW'),
(2, 'AML20240002', 8, 15, 'HIGH_VALUE', 'Large single transaction exceeding usual pattern', 60, 'NEW'),
(3, 'AML20240003', NULL, 25, 'UNUSUAL_PATTERN', 'Unusual transfer pattern detected', 45, 'CLOSED_FALSE_POSITIVE');
SET IDENTITY_INSERT oltp.aml_alerts OFF;

PRINT '✓ Source database populated with sample data';
PRINT '';

-- ============================================================================
-- SUMMARY
-- ============================================================================
DECLARE @MasterEnd DATETIME = GETDATE();
DECLARE @Duration INT = DATEDIFF(SECOND, @MasterStart, @MasterEnd);

PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║              SOURCE DATABASE SETUP COMPLETE                       ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'Duration: ' + CAST(@Duration AS VARCHAR) + ' seconds';
PRINT '';
PRINT 'Data Loaded:';
SELECT 'Branches' AS entity, COUNT(*) AS count FROM oltp.branches
UNION ALL SELECT 'Employees', COUNT(*) FROM oltp.employees
UNION ALL SELECT 'Customers', COUNT(*) FROM oltp.customers
UNION ALL SELECT 'Products', COUNT(*) FROM oltp.products
UNION ALL SELECT 'Accounts', COUNT(*) FROM oltp.accounts
UNION ALL SELECT 'Transactions', COUNT(*) FROM oltp.transactions
UNION ALL SELECT 'Loans', COUNT(*) FROM oltp.loans
UNION ALL SELECT 'Exchange Rates', COUNT(*) FROM oltp.exchange_rates
UNION ALL SELECT 'AML Alerts', COUNT(*) FROM oltp.aml_alerts;
PRINT '';
PRINT 'NEXT STEP: Create the remaining 9 databases by running:';
PRINT '  - 02-source-systems/02-create-raw-zone-database.sql';
PRINT '  - 03-staging/01-create-staging-database.sql';
PRINT '  - 04-data-warehouse/01-create-dwh-database.sql';
PRINT '  - 05-data-marts/*/*.sql';
PRINT '';
PRINT 'Or run: 10-samples/03-run-complete-pipeline.sql';
PRINT '';
GO
