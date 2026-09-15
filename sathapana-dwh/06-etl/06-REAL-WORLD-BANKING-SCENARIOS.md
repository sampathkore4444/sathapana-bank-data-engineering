# 🏦 Real-World Banking ETL Scenarios - Sathapana Bank

## Table of Contents
1. [Overview](#1-overview)
2. [Scenario 1: Daily Transaction Processing](#2-scenario-1-daily-transaction-processing)
3. [Scenario 2: Loan Portfolio Management](#3-scenario-2-loan-portfolio-management)
4. [Scenario 3: Customer Onboarding & KYC](#4-scenario-3-customer-onboarding--kyc)
5. [Scenario 4: AML/CFT Compliance](#5-scenario-4-amlcft-compliance)
6. [Scenario 5: Regulatory Reporting (NBC)](#6-scenario-5-regulatory-reporting-nbc)
7. [Scenario 6: Treasury & FX Operations](#7-scenario-6-treasury--fx-operations)
8. [Scenario 7: End-of-Day Reconciliation](#8-scenario-7-end-of-day-reconciliation)

---

## 1. Overview

This document provides **real-world ETL examples** based on Sathapana Bank's actual business operations in Cambodia. Each scenario includes:

- Business context
- Source system details
- ETL implementation
- Sample queries
- Common challenges and solutions

```
┌─────────────────────────────────────────────────────────────────┐
│                    SATHAPANA BANK ETL SCENARIOS                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📊 DAILY OPERATIONS                                             │
│  ├── Transaction Processing (100,000+ daily)                    │
│  ├── End-of-Day Reconciliation                                  │
│  └── Account Balance Snapshots                                  │
│                                                                  │
│  📋 COMPLIANCE                                                   │
│  ├── AML/CFT Monitoring                                         │
│  ├── KYC/CDD Updates                                            │
│  └── PEP/Sanctions Screening                                    │
│                                                                  │
│  💰 REGULATORY                                                   │
│  ├── NBC Reporting (Prudential)                                 │
│  ├── CAR Calculation                                            │
│  └── Large Exposure Reporting                                   │
│                                                                  │
│  🏦 TREASURY                                                     │
│  ├── FX Position Management                                     │
│  ├── Liquidity Monitoring                                       │
│  └── Interest Rate Risk                                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Scenario 1: Daily Transaction Processing

### Business Context

Sathapana Bank processes **100,000+ transactions daily** across:
- Branch counter transactions
- ATM withdrawals
- Mobile banking transfers
- Internet banking
- Agent banking

### Source System

```sql
-- Core Banking System (CBS) - Source Tables
CREATE TABLE cbs.dbo.transactions (
    txn_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    txn_ref VARCHAR(30) NOT NULL,
    acct_id INT NOT NULL,
    txn_type VARCHAR(20) NOT NULL,  -- DEP, WDR, TRF, FEE
    txn_channel VARCHAR(20),        -- BRANCH, ATM, MOBILE, INTERNET
    amount DECIMAL(18,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'KHR',
    txn_date DATETIME NOT NULL,
    value_date DATE NOT NULL,
    balance_before DECIMAL(18,2),
    balance_after DECIMAL(18,2),
   Narration NVARCHAR(500),
    status VARCHAR(10) DEFAULT 'POSTED',
    created_at DATETIME DEFAULT GETDATE()
);

-- Index for incremental extraction
CREATE INDEX IX_transactions_txn_date ON cbs.dbo.transactions(txn_date);
CREATE INDEX IX_transactions_status ON cbs.dbo.transactions(status);
```

### ETL Implementation

```sql
-- ============================================================
-- SCENARIO 1: DAILY TRANSACTION PROCESSING ETL
-- ============================================================

CREATE PROCEDURE etl.usp_ExtractDailyTransactions
    @BusinessDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    DECLARE @SourceCount BIGINT;
    
    PRINT '========================================';
    PRINT 'DAILY TRANSACTION EXTRACTION';
    PRINT 'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '========================================';
    
    --------------------------------------------------------
    -- STEP 1: Validate source data
    --------------------------------------------------------
    SELECT @SourceCount = COUNT(*)
    FROM cbs.dbo.transactions
    WHERE CAST(txn_date AS DATE) = @BusinessDate
    AND status = 'POSTED';
    
    PRINT 'Source transaction count: ' + CAST(@SourceCount AS VARCHAR(10));
    
    IF @SourceCount = 0
    BEGIN
        PRINT 'WARNING: No transactions found for business date!';
        RETURN;
    END
    
    --------------------------------------------------------
    -- STEP 2: Extract transactions with full context
    --------------------------------------------------------
    TRUNCATE TABLE staging.stg_transactions;
    
    INSERT INTO staging.stg_transactions (
        transaction_code, account_number, customer_code,
        transaction_type, transaction_channel,
        amount, currency, amount_usd,
        transaction_date, value_date,
        balance_before, balance_after,
        narration, status,
        source_key, batch_id
    )
    SELECT
        t.txn_ref,
        a.acct_number,
        c.cust_code,
        t.txn_type,
        t.txn_channel,
        t.amount,
        t.currency,
        -- Convert to USD for reporting
        CASE 
            WHEN t.currency = 'KHR' THEN t.amount / 4100.00
            WHEN t.currency = 'USD' THEN t.amount
            ELSE t.amount * ISNULL(fx.rate, 1.0)
        END AS amount_usd,
        t.txn_date,
        t.value_date,
        t.balance_before,
        t.balance_after,
        t.Narration,
        t.status,
        CAST(t.txn_id AS VARCHAR(50)),
        @BatchID
    FROM cbs.dbo.transactions t
    JOIN cbs.dbo.accounts a ON t.acct_id = a.acct_id
    JOIN cbs.dbo.customers c ON a.cust_id = c.cust_id
    LEFT JOIN staging.stg_exchange_rates fx
        ON t.currency = fx.source_currency
        AND fx.target_currency = 'USD'
        AND fx.rate_date = CAST(t.txn_date AS DATE)
    WHERE CAST(t.txn_date AS DATE) = @BusinessDate
    AND t.status = 'POSTED';
    
    SET @RecordCount = @@ROWCOUNT;
    
    --------------------------------------------------------
    -- STEP 3: Validate extraction
    --------------------------------------------------------
    IF @RecordCount != @SourceCount
    BEGIN
        DECLARE @DiffMsg NVARCHAR(500) = 
            'Row count mismatch! Source: ' + CAST(@SourceCount AS VARCHAR(10)) +
            ', Extracted: ' + CAST(@RecordCount AS VARCHAR(10));
        
        RAISERROR(@DiffMsg, 16, 1);
    END
    
    --------------------------------------------------------
    -- STEP 4: Log extraction
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time,
        notes
    )
    VALUES (
        @BatchID, 'Extract_DailyTransactions', 'stg_transactions', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE(),
        'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120)
    );
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' transactions.';
END;
```

### Transaction Summary Report

```sql
-- Daily Transaction Summary for Management
CREATE PROCEDURE report.usp_DailyTransactionSummary
    @BusinessDate DATE
AS
BEGIN
    PRINT '=== DAILY TRANSACTION SUMMARY ===';
    PRINT 'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '';
    
    -- Overall summary
    SELECT 
        COUNT(*) AS total_transactions,
        SUM(amount_usd) AS total_amount_usd,
        AVG(amount_usd) AS avg_transaction_size,
        MIN(amount_usd) AS min_transaction,
        MAX(amount_usd) AS max_transaction
    FROM dw.fact_transactions t
    JOIN dw.dim_date d ON t.date_key = d.date_key
    WHERE d.full_date = @BusinessDate;
    
    -- By transaction type
    SELECT 
        transaction_type,
        COUNT(*) AS txn_count,
        SUM(amount_usd) AS total_amount_usd
    FROM dw.fact_transactions t
    JOIN dw.dim_date d ON t.date_key = d.date_key
    WHERE d.full_date = @BusinessDate
    GROUP BY transaction_type
    ORDER BY total_amount_usd DESC;
    
    -- By channel
    SELECT 
        ch.channel_name,
        COUNT(*) AS txn_count,
        SUM(t.amount_usd) AS total_amount_usd
    FROM dw.fact_transactions t
    JOIN dw.dim_date d ON t.date_key = d.date_key
    JOIN dw.dim_channel ch ON t.channel_key = ch.channel_key
    WHERE d.full_date = @BusinessDate
    GROUP BY ch.channel_name
    ORDER BY total_amount_usd DESC;
    
    -- By branch (top 10)
    SELECT TOP 10
        b.branch_name,
        COUNT(*) AS txn_count,
        SUM(t.amount_usd) AS total_amount_usd
    FROM dw.fact_transactions t
    JOIN dw.dim_date d ON t.date_key = d.date_key
    JOIN dw.dim_branch b ON t.branch_key = b.branch_key
    WHERE d.full_date = @BusinessDate
    GROUP BY b.branch_name
    ORDER BY total_amount_usd DESC;
END;
```

---

## 3. Scenario 2: Loan Portfolio Management

### Business Context

Sathapana Bank manages **$500M+ loan portfolio** with various products:
- Micro loans (58 Samakis)
- SME loans
- Housing loans
- Agricultural loans
- Auto loans

### Source System

```sql
-- Loan Management System - Source Tables
CREATE TABLE lms.dbo.loans (
    loan_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    loan_number VARCHAR(20) NOT NULL,
    app_number VARCHAR(20),
    cust_id INT NOT NULL,
    product_id INT NOT NULL,
    branch_id INT NOT NULL,
    loan_amount DECIMAL(18,2),
    disbursed_amount DECIMAL(18,2),
    outstanding_principal DECIMAL(18,2),
    outstanding_interest DECIMAL(18,2),
    interest_rate DECIMAL(5,2),
    term_months INT,
    disbursement_date DATE,
    maturity_date DATE,
    first_payment_date DATE,
    loan_status VARCHAR(20),  -- ACTIVE, CLOSED, WRITTEN_OFF, RESTRUCTURED
    days_past_due INT,
    risk_classification VARCHAR(20),  -- NORMAL, SUBSTANDARD, DOUBTFUL, LOSS
    provision_amount DECIMAL(18,2),
    collateral_type VARCHAR(50),
    collateral_value DECIMAL(18,2),
    ro_code VARCHAR(20),  -- Relationship Officer
    created_at DATETIME DEFAULT GETDATE()
);
```

### ETL Implementation

```sql
-- ============================================================
-- SCENARIO 2: LOAN PORTFOLIO ETL
-- ============================================================

CREATE PROCEDURE etl.usp_LoadLoanPortfolio
    @SnapshotDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    DECLARE @SnapshotDateKey INT = CAST(FORMAT(@SnapshotDate, 'yyyyMMdd') AS INT);
    
    PRINT '========================================';
    PRINT 'LOAN PORTFOLIO SNAPSHOT';
    PRINT 'Snapshot Date: ' + CONVERT(VARCHAR(10), @SnapshotDate, 120);
    PRINT '========================================';
    
    --------------------------------------------------------
    -- STEP 1: Extract current loan positions
    --------------------------------------------------------
    TRUNCATE TABLE staging.stg_loans;
    
    INSERT INTO staging.stg_loans (
        loan_number, application_number, customer_code,
        product_code, branch_code, loan_amount, disbursed_amount,
        outstanding_principal, outstanding_interest,
        interest_rate, term_months, disbursement_date, maturity_date,
        loan_status, days_past_due, risk_classification,
        provision_amount, collateral_type, collateral_value,
        relationship_officer_code,
        source_key, batch_id
    )
    SELECT
        l.loan_number,
        l.app_number,
        c.cust_code,
        p.product_code,
        b.branch_code,
        l.loan_amount,
        l.disbursed_amount,
        l.outstanding_principal,
        l.outstanding_interest,
        l.interest_rate,
        l.term_months,
        l.disbursement_date,
        l.maturity_date,
        l.loan_status,
        l.days_past_due,
        l.risk_classification,
        l.provision_amount,
        l.collateral_type,
        l.collateral_value,
        e.emp_code,
        CAST(l.loan_id AS VARCHAR(50)),
        @BatchID
    FROM lms.dbo.loans l
    JOIN cbs.dbo.customers c ON l.cust_id = c.cust_id
    JOIN cbs.dbo.products p ON l.product_id = p.product_id
    JOIN cbs.dbo.branches b ON l.branch_id = b.branch_id
    LEFT JOIN cbs.dbo.employees e ON l.ro_code = e.emp_code
    WHERE l.loan_status IN ('ACTIVE', 'RESTRUCTURED');
    
    SET @RecordCount = @@ROWCOUNT;
    
    --------------------------------------------------------
    -- STEP 2: Load into fact table (monthly snapshot)
    --------------------------------------------------------
    INSERT INTO dw.fact_loan_portfolio (
        loan_key, customer_key, product_key, branch_key, employee_key,
        snapshot_date_key, loan_amount, disbursed_amount,
        outstanding_principal, outstanding_interest,
        interest_rate, term_months, disbursement_date, maturity_date,
        days_past_due, risk_classification,
        provision_amount, collateral_type, collateral_value,
        source_system, etl_batch_id
    )
    SELECT
        l.loan_id,  -- In production, use surrogate key
        c.customer_key,
        p.product_key,
        b.branch_key,
        e.employee_key,
        @SnapshotDateKey,
        s.loan_amount,
        s.disbursed_amount,
        s.outstanding_principal,
        s.outstanding_interest,
        s.interest_rate,
        s.term_months,
        s.disbursement_date,
        s.maturity_date,
        s.days_past_due,
        s.risk_classification,
        s.provision_amount,
        s.collateral_type,
        s.collateral_value,
        'LOAN_SYSTEM',
        @BatchID
    FROM staging.stg_loans s
    JOIN dw.dim_customer c ON s.customer_code = c.customer_code AND c.is_current = 1
    JOIN dw.dim_product p ON s.product_code = p.product_code
    JOIN dw.dim_branch b ON s.branch_code = b.branch_code AND b.is_current = 1
    LEFT JOIN dw.dim_employee e ON s.relationship_officer_code = e.employee_code AND e.is_current = 1;
    
    --------------------------------------------------------
    -- STEP 3: Log completion
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time,
        notes
    )
    VALUES (
        @BatchID, 'Load_LoanPortfolio', 'fact_loan_portfolio', 'LOAD',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE(),
        'Snapshot Date: ' + CONVERT(VARCHAR(10), @SnapshotDate, 120)
    );
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' loan records.';
END;
```

### Loan Portfolio Analysis Queries

```sql
-- NPL (Non-Performing Loan) Analysis
CREATE PROCEDURE report.usp_NPLAnalysis
    @SnapshotDate DATE
AS
BEGIN
    DECLARE @SnapshotDateKey INT = CAST(FORMAT(@SnapshotDate, 'yyyyMMdd') AS INT);
    
    PRINT '=== NPL ANALYSIS REPORT ===';
    PRINT 'Date: ' + CONVERT(VARCHAR(10), @SnapshotDate, 120);
    PRINT '';
    
    -- Overall NPL Ratio
    SELECT
        SUM(outstanding_principal) AS total_portfolio,
        SUM(CASE WHEN days_past_due > 90 THEN outstanding_principal ELSE 0 END) AS npl_amount,
        CAST(
            SUM(CASE WHEN days_past_due > 90 THEN outstanding_principal ELSE 0 END) * 100.0 /
            NULLIF(SUM(outstanding_principal), 0) AS DECIMAL(5,2)
        ) AS npl_ratio_pct
    FROM dw.fact_loan_portfolio
    WHERE snapshot_date_key = @SnapshotDateKey;
    
    -- NPL by Product
    SELECT
        p.product_name,
        COUNT(*) AS loan_count,
        SUM(f.outstanding_principal) AS total_outstanding,
        SUM(CASE WHEN f.days_past_due > 90 THEN f.outstanding_principal ELSE 0 END) AS npl_amount,
        CAST(
            SUM(CASE WHEN f.days_past_due > 90 THEN f.outstanding_principal ELSE 0 END) * 100.0 /
            NULLIF(SUM(f.outstanding_principal), 0) AS DECIMAL(5,2)
        ) AS npl_ratio_pct
    FROM dw.fact_loan_portfolio f
    JOIN dw.dim_product p ON f.product_key = p.product_key
    WHERE f.snapshot_date_key = @SnapshotDateKey
    GROUP BY p.product_name
    ORDER BY npl_ratio_pct DESC;
    
    -- NPL by Branch (Top 10)
    SELECT TOP 10
        b.branch_name,
        COUNT(*) AS loan_count,
        SUM(f.outstanding_principal) AS total_outstanding,
        SUM(CASE WHEN f.days_past_due > 90 THEN f.outstanding_principal ELSE 0 END) AS npl_amount,
        CAST(
            SUM(CASE WHEN f.days_past_due > 90 THEN f.outstanding_principal ELSE 0 END) * 100.0 /
            NULLIF(SUM(f.outstanding_principal), 0) AS DECIMAL(5,2)
        ) AS npl_ratio_pct
    FROM dw.fact_loan_portfolio f
    JOIN dw.dim_branch b ON f.branch_key = b.branch_key
    WHERE f.snapshot_date_key = @SnapshotDateKey
    GROUP BY b.branch_name
    ORDER BY npl_ratio_pct DESC;
    
    -- Provision Coverage
    SELECT
        risk_classification,
        COUNT(*) AS loan_count,
        SUM(outstanding_principal) AS total_outstanding,
        SUM(provision_amount) AS total_provision,
        CAST(
            SUM(provision_amount) * 100.0 /
            NULLIF(SUM(outstanding_principal), 0) AS DECIMAL(5,2)
        ) AS provision_coverage_pct
    FROM dw.fact_loan_portfolio
    WHERE snapshot_date_key = @SnapshotDateKey
    GROUP BY risk_classification
    ORDER BY 
        CASE risk_classification
            WHEN 'NORMAL' THEN 1
            WHEN 'SUBSTANDARD' THEN 2
            WHEN 'DOUBTFUL' THEN 3
            WHEN 'LOSS' THEN 4
        END;
END;
```

---

## 4. Scenario 3: Customer Onboarding & KYC

### Business Context

Sathapana Bank must comply with **KYC/CDD regulations**:
- Customer identification and verification
- Ongoing due diligence
- Risk-based approach
- Enhanced due diligence for high-risk customers

### Source System

```sql
-- Core Banking System - Customer Tables
CREATE TABLE cbs.dbo.customers (
    cust_id INT IDENTITY(1,1) PRIMARY KEY,
    cust_code VARCHAR(20) NOT NULL,
    cust_type VARCHAR(10),  -- IND, COM
    title VARCHAR(10),
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    company_name NVARCHAR(200),
    national_id_type VARCHAR(20),  -- NATIONAL_ID, PASSPORT, BIRTH_CERT
    national_id VARCHAR(50),
    passport_number VARCHAR(50),
    date_of_birth DATE,
    gender CHAR(1),
    nationality VARCHAR(50),
    email VARCHAR(255),
    phone_primary VARCHAR(20),
    address_line1 NVARCHAR(200),
    province VARCHAR(100),
    district VARCHAR(100),
    commune VARCHAR(100),
    customer_segment VARCHAR(20),
    risk_rating VARCHAR(20),  -- LOW, MEDIUM, HIGH, VERY_HIGH
    kyc_status VARCHAR(20),   -- PENDING, VERIFIED, EXPIRED, REJECTED
    kyc_verified_date DATE,
    kyc_expiry_date DATE,
    is_pep BIT,  -- Politically Exposed Person
    is_sanctioned BIT,
    pep_class VARCHAR(20),
    source_of_wealth VARCHAR(100),
    purpose_of_account VARCHAR(100),
    created_at DATETIME DEFAULT GETDATE(),
    modified_at DATETIME DEFAULT GETDATE()
);
```

### ETL Implementation

```sql
-- ============================================================
-- SCENARIO 3: CUSTOMER ONBOARDING & KYC ETL
-- ============================================================

CREATE PROCEDURE etl.usp_ExtractKYCData
    @BusinessDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT '========================================';
    PRINT 'KYC DATA EXTRACTION';
    PRINT 'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '========================================';
    
    --------------------------------------------------------
    -- Extract customers with KYC status
    --------------------------------------------------------
    TRUNCATE TABLE staging.stg_customers_kyc;
    
    INSERT INTO staging.stg_customers_kyc (
        customer_code, customer_type, title, first_name, last_name,
        company_name, national_id_type, national_id, passport_number,
        date_of_birth, gender, nationality, email, phone_primary,
        address_line1, province, district, commune,
        customer_segment, risk_rating,
        kyc_status, kyc_verified_date, kyc_expiry_date,
        is_pep, is_sanctioned, pep_class,
        source_of_wealth, purpose_of_account,
        days_until_kyc_expiry,
        source_key, batch_id
    )
    SELECT
        c.cust_code,
        c.cust_type,
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
        c.address_line1,
        c.province,
        c.district,
        c.commune,
        c.customer_segment,
        c.risk_rating,
        c.kyc_status,
        c.kyc_verified_date,
        c.kyc_expiry_date,
        c.is_pep,
        c.is_sanctioned,
        c.pep_class,
        c.source_of_wealth,
        c.purpose_of_account,
        DATEDIFF(DAY, @BusinessDate, c.kyc_expiry_date),
        CAST(c.cust_id AS VARCHAR(50)),
        @BatchID
    FROM cbs.dbo.customers c;
    
    SET @RecordCount = @@ROWCOUNT;
    
    --------------------------------------------------------
    -- Log extraction
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time,
        notes
    )
    VALUES (
        @BatchID, 'Extract_KYCData', 'stg_customers_kyc', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE(),
        'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120)
    );
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' customer records.';
END;
```

### KYC Monitoring Queries

```sql
-- KYC Status Dashboard
CREATE PROCEDURE report.usp_KYCDashboard
    @BusinessDate DATE
AS
BEGIN
    PRINT '=== KYC STATUS DASHBOARD ===';
    PRINT 'Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '';
    
    -- Overall KYC Status
    SELECT
        kyc_status,
        COUNT(*) AS customer_count,
        CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM dw.dim_customer WHERE is_current = 1) AS DECIMAL(5,1)) AS percentage
    FROM dw.dim_customer
    WHERE is_current = 1
    GROUP BY kyc_status
    ORDER BY customer_count DESC;
    
    -- KYC Expiry Warning (Next 30 days)
    SELECT
        customer_code,
        first_name + ' ' + last_name AS customer_name,
        risk_rating,
        kyc_verified_date,
        kyc_expiry_date,
        DATEDIFF(DAY, @BusinessDate, kyc_expiry_date) AS days_until_expiry
    FROM dw.dim_customer
    WHERE is_current = 1
    AND kyc_expiry_date BETWEEN @BusinessDate AND DATEADD(DAY, 30, @BusinessDate)
    ORDER BY kyc_expiry_date;
    
    -- Expired KYC
    SELECT
        customer_code,
        first_name + ' ' + last_name AS customer_name,
        risk_rating,
        kyc_verified_date,
        kyc_expiry_date,
        DATEDIFF(DAY, kyc_expiry_date, @BusinessDate) AS days_expired
    FROM dw.dim_customer
    WHERE is_current = 1
    AND kyc_expiry_date < @BusinessDate
    ORDER BY kyc_expiry_date;
    
    -- PEP Customers
    SELECT
        customer_code,
        first_name + ' ' + last_name AS customer_name,
        customer_segment,
        risk_rating,
        pep_class
    FROM dw.dim_customer
    WHERE is_current = 1
    AND is_pep = 1
    ORDER BY risk_rating, customer_code;
    
    -- High Risk Customers
    SELECT
        customer_code,
        first_name + ' ' + last_name AS customer_name,
        customer_segment,
        risk_rating,
        is_pep,
        is_sanctioned
    FROM dw.dim_customer
    WHERE is_current = 1
    AND risk_rating IN ('HIGH', 'VERY_HIGH')
    ORDER BY risk_rating, customer_code;
END;
```

---

## 5. Scenario 4: AML/CFT Compliance

### Business Context

Sathapana Bank must monitor for **money laundering and terrorism financing**:
- Suspicious Transaction Reports (STR)
- Large Transaction Reports (LTR)
- Transaction Monitoring
- Risk Scoring

### Source System

```sql
-- AML Monitoring System - Source Tables
CREATE TABLE aml.dbo.alerts (
    alert_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    alert_code VARCHAR(20) NOT NULL,
    cust_id INT,
    txn_id BIGINT,
    alert_type VARCHAR(50),  -- STRUCTURING, UNUSUAL_PATTERN, HIGH_RISK_COUNTRY
    alert_description NVARCHAR(500),
    risk_score INT,  -- 1-100
    risk_level VARCHAR(20),  -- LOW, MEDIUM, HIGH, CRITICAL
    status VARCHAR(20),  -- NEW, INVESTIGATING, ESCALATED, CLOSED, SAR_FILED
    assigned_to INT,
    investigation_notes NVARCHAR(MAX),
    sar_reference VARCHAR(50),
    created_at DATETIME DEFAULT GETDATE(),
    updated_at DATETIME DEFAULT GETDATE()
);
```

### ETL Implementation

```sql
-- ============================================================
-- SCENARIO 4: AML/CFT COMPLIANCE ETL
-- ============================================================

CREATE PROCEDURE etl.usp_ExtractAMLAlerts
    @BusinessDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT '========================================';
    PRINT 'AML ALERT EXTRACTION';
    PRINT 'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '========================================';
    
    --------------------------------------------------------
    -- Extract AML alerts with customer context
    --------------------------------------------------------
    TRUNCATE TABLE staging.stg_aml_alerts;
    
    INSERT INTO staging.stg_aml_alerts (
        alert_code, customer_code, transaction_code,
        alert_type, alert_description, risk_score, risk_level,
        status, assigned_to_code, investigation_notes,
        sar_reference, created_date, updated_date,
        source_key, batch_id
    )
    SELECT
        a.alert_code,
        c.cust_code,
        t.txn_ref,
        a.alert_type,
        a.alert_description,
        a.risk_score,
        a.risk_level,
        a.status,
        e.emp_code,
        a.investigation_notes,
        a.sar_reference,
        a.created_at,
        a.updated_at,
        CAST(a.alert_id AS VARCHAR(50)),
        @BatchID
    FROM aml.dbo.alerts a
    LEFT JOIN cbs.dbo.customers c ON a.cust_id = c.cust_id
    LEFT JOIN cbs.dbo.transactions t ON a.txn_id = t.txn_id
    LEFT JOIN cbs.dbo.employees e ON a.assigned_to = e.emp_id
    WHERE CAST(a.created_at AS DATE) = @BusinessDate;
    
    SET @RecordCount = @@ROWCOUNT;
    
    --------------------------------------------------------
    -- Log extraction
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time,
        notes
    )
    VALUES (
        @BatchID, 'Extract_AMLAlerts', 'stg_aml_alerts', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE(),
        'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120)
    );
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' AML alerts.';
END;
```

### AML Monitoring Queries

```sql
-- AML Dashboard
CREATE PROCEDURE report.usp_AMLDashboard
    @BusinessDate DATE
AS
BEGIN
    PRINT '=== AML COMPLIANCE DASHBOARD ===';
    PRINT 'Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '';
    
    -- Alert Summary by Status
    SELECT
        status,
        COUNT(*) AS alert_count,
        AVG(risk_score) AS avg_risk_score
    FROM staging.stg_aml_alerts
    GROUP BY status
    ORDER BY alert_count DESC;
    
    -- Alert Summary by Type
    SELECT
        alert_type,
        COUNT(*) AS alert_count,
        AVG(risk_score) AS avg_risk_score,
        SUM(CASE WHEN risk_level IN ('HIGH', 'CRITICAL') THEN 1 ELSE 0 END) AS high_risk_count
    FROM staging.stg_aml_alerts
    GROUP BY alert_type
    ORDER BY alert_count DESC;
    
    -- Critical Alerts Requiring Immediate Attention
    SELECT
        alert_code,
        customer_code,
        alert_type,
        risk_score,
        risk_level,
        status,
        created_date
    FROM staging.stg_aml_alerts
    WHERE risk_level IN ('HIGH', 'CRITICAL')
    AND status IN ('NEW', 'INVESTIGATING')
    ORDER BY risk_score DESC;
    
    -- SAR (Suspicious Activity Report) Status
    SELECT
        status,
        COUNT(*) AS report_count
    FROM staging.stg_aml_alerts
    WHERE sar_reference IS NOT NULL
    GROUP BY status;
    
    -- Alerts by Branch (Top 10)
    SELECT TOP 10
        b.branch_name,
        COUNT(*) AS alert_count,
        AVG(a.risk_score) AS avg_risk_score
    FROM staging.stg_aml_alerts a
    JOIN dw.dim_customer c ON a.customer_code = c.customer_code AND c.is_current = 1
    JOIN dw.dim_branch b ON c.opening_branch_key = b.branch_key
    WHERE CAST(a.created_date AS DATE) = @BusinessDate
    GROUP BY b.branch_name
    ORDER BY alert_count DESC;
END;
```

---

## 6. Scenario 5: Regulatory Reporting (NBC)

### Business Context

Sathapana Bank must report to **National Bank of Cambodia (NBC)**:
- Prudential returns
- Capital Adequacy Ratio (CAR)
- Large Exposure reports
- Liquidity reports

### ETL Implementation

```sql
-- ============================================================
-- SCENARIO 5: REGULATORY REPORTING ETL
-- ============================================================

CREATE PROCEDURE etl.usp_CalculateCAR
    @ReportDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    
    PRINT '========================================';
    PRINT 'CAPITAL ADEQUACY RATIO CALCULATION';
    PRINT 'Report Date: ' + CONVERT(VARCHAR(10), @ReportDate, 120);
    PRINT '========================================';
    
    DECLARE @Tier1Capital DECIMAL(18,2);
    DECLARE @Tier2Capital DECIMAL(18,2);
    DECLARE @RiskWeightedAssets DECIMAL(18,2);
    DECLARE @CAR DECIMAL(10,4);
    
    --------------------------------------------------------
    -- Calculate Tier 1 Capital
    --------------------------------------------------------
    SELECT @Tier1Capital = 
        ISNULL(SUM(CASE WHEN gl_account LIKE '31%' THEN balance ELSE 0 END), 0) -  -- Share Capital
        ISNULL(SUM(CASE WHEN gl_account LIKE '32%' THEN balance ELSE 0 END), 0)    -- Less: Deductions
    FROM dw.fact_gl_balance
    WHERE report_date = @ReportDate;
    
    --------------------------------------------------------
    -- Calculate Tier 2 Capital
    --------------------------------------------------------
    SELECT @Tier2Capital = 
        ISNULL(SUM(CASE WHEN gl_account LIKE '33%' THEN balance ELSE 0 END), 0)    -- Reserves
    FROM dw.fact_gl_balance
    WHERE report_date = @ReportDate;
    
    --------------------------------------------------------
    -- Calculate Risk-Weighted Assets
    --------------------------------------------------------
    SELECT @RiskWeightedAssets = 
        -- Credit Risk
        ISNULL(SUM(
            CASE risk_weight
                WHEN '0%' THEN 0
                WHEN '20%' THEN outstanding_principal * 0.20
                WHEN '50%' THEN outstanding_principal * 0.50
                WHEN '100%' THEN outstanding_principal * 1.00
                WHEN '150%' THEN outstanding_principal * 1.50
                ELSE outstanding_principal
            END
        ), 0)
    FROM dw.fact_loan_portfolio f
    JOIN dw.dim_product p ON f.product_key = p.product_key
    WHERE f.snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT);
    
    --------------------------------------------------------
    -- Calculate CAR
    --------------------------------------------------------
    SET @CAR = (@Tier1Capital + @Tier2Capital) / NULLIF(@RiskWeightedAssets, 0) * 100;
    
    --------------------------------------------------------
    -- Store results
    --------------------------------------------------------
    INSERT INTO dw.fact_regulatory_car (
        report_date, tier1_capital, tier2_capital,
        total_capital, risk_weighted_assets,
        car_ratio, etl_batch_id
    )
    VALUES (
        @ReportDate, @Tier1Capital, @Tier2Capital,
        @Tier1Capital + @Tier2Capital, @RiskWeightedAssets,
        @CAR, @BatchID
    );
    
    --------------------------------------------------------
    -- Print results
    --------------------------------------------------------
    PRINT '';
    PRINT '=== CAPITAL ADEQUACY RATIO ===';
    PRINT 'Tier 1 Capital:     $' + FORMAT(@Tier1Capital, 'N2');
    PRINT 'Tier 2 Capital:     $' + FORMAT(@Tier2Capital, 'N2');
    PRINT 'Total Capital:      $' + FORMAT(@Tier1Capital + @Tier2Capital, 'N2');
    PRINT 'Risk-Weighted Assets: $' + FORMAT(@RiskWeightedAssets, 'N2');
    PRINT 'CAR Ratio:          ' + FORMAT(@CAR, 'N2') + '%';
    PRINT '';
    
    -- Check compliance (minimum 15% for Cambodia)
    IF @CAR < 15
        PRINT '⚠️  WARNING: CAR below minimum requirement of 15%!';
    ELSE
        PRINT '✅ CAR meets regulatory requirement.';
    
    --------------------------------------------------------
    -- Log
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time,
        notes
    )
    VALUES (
        @BatchID, 'Calculate_CAR', 'fact_regulatory_car', 'LOAD',
        1, 'COMPLETED', @StartTime, GETDATE(),
        'CAR: ' + FORMAT(@CAR, 'N2') + '%'
    );
END;
```

### Large Exposure Report

```sql
CREATE PROCEDURE etl.usp_CalculateLargeExposure
    @ReportDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @TotalCapital DECIMAL(18,2);
    DECLARE @ExposureLimit DECIMAL(18,2);
    
    -- Get total capital
    SELECT @TotalCapital = tier1_capital + tier2_capital
    FROM dw.fact_regulatory_car
    WHERE report_date = @ReportDate;
    
    -- Large exposure limit = 25% of total capital
    SET @ExposureLimit = @TotalCapital * 0.25;
    
    PRINT 'Large Exposure Limit: $' + FORMAT(@ExposureLimit, 'N2');
    
    -- Find exposures exceeding limit
    SELECT
        c.customer_code,
        c.first_name + ' ' + c.last_name AS customer_name,
        c.customer_segment,
        SUM(f.outstanding_principal) AS total_exposure,
        CAST(SUM(f.outstanding_principal) * 100.0 / @TotalCapital AS DECIMAL(5,2)) AS pct_of_capital,
        CASE 
            WHEN SUM(f.outstanding_principal) > @ExposureLimit THEN 'EXCEEDS LIMIT'
            ELSE 'WITHIN LIMIT'
        END AS status
    FROM dw.fact_loan_portfolio f
    JOIN dw.dim_customer c ON f.customer_key = c.customer_key AND c.is_current = 1
    WHERE f.snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
    GROUP BY c.customer_code, c.first_name, c.last_name, c.customer_segment
    HAVING SUM(f.outstanding_principal) > @ExposureLimit * 0.5  -- Show exposures > 50% of limit
    ORDER BY total_exposure DESC;
END;
```

---

## 7. Scenario 6: Treasury & FX Operations

### Business Context

Sathapana Bank manages:
- Foreign exchange positions (USD, KHR, THB, EUR)
- Liquidity management
- Interest rate risk
- Investment portfolio

### ETL Implementation

```sql
-- ============================================================
-- SCENARIO 6: TREASURY & FX ETL
-- ============================================================

CREATE PROCEDURE etl.usp_LoadFXPositions
    @BusinessDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    
    PRINT '========================================';
    PRINT 'FX POSITION LOADING';
    PRINT 'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '========================================';
    
    --------------------------------------------------------
    -- Load FX Rates
    --------------------------------------------------------
    INSERT INTO dw.dim_exchange_rate (
        source_currency, target_currency, rate_date,
        bid_rate, ask_rate, mid_rate,
        source_system, etl_batch_id
    )
    SELECT
        fx.source_currency,
        fx.target_currency,
        fx.rate_date,
        fx.bid_rate,
        fx.ask_rate,
        (fx.bid_rate + fx.ask_rate) / 2,
        'TREASURY_SYSTEM',
        @BatchID
    FROM treasury.dbo.fx_rates fx
    WHERE fx.rate_date = @BusinessDate
    AND NOT EXISTS (
        SELECT 1 FROM dw.dim_exchange_rate d
        WHERE d.source_currency = fx.source_currency
        AND d.target_currency = fx.target_currency
        AND d.rate_date = fx.rate_date
    );
    
    --------------------------------------------------------
    -- Calculate FX Positions
    --------------------------------------------------------
    INSERT INTO dw.fact_fx_positions (
        position_date_key, currency, long_position, short_position,
        net_position, unrealized_pnl, source_system, etl_batch_id
    )
    SELECT
        CAST(FORMAT(@BusinessDate, 'yyyyMMdd') AS INT),
        p.currency,
        SUM(CASE WHEN p.amount > 0 THEN p.amount ELSE 0 END),
        SUM(CASE WHEN p.amount < 0 THEN ABS(p.amount) ELSE 0 END),
        SUM(p.amount),
        SUM(p.amount * p.unrealized_rate),
        'TREASURY_SYSTEM',
        @BatchID
    FROM treasury.dbo.positions p
    WHERE p.position_date = @BusinessDate
    GROUP BY p.currency;
    
    --------------------------------------------------------
    -- Log
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time,
        notes
    )
    VALUES (
        @BatchID, 'Load_FXPositions', 'fact_fx_positions', 'LOAD',
        @@ROWCOUNT, 'COMPLETED', @StartTime, GETDATE(),
        'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120)
    );
    
    PRINT 'FX positions loaded successfully.';
END;
```

### Treasury Dashboard Queries

```sql
-- Treasury Dashboard
CREATE PROCEDURE report.usp_TreasuryDashboard
    @BusinessDate DATE
AS
BEGIN
    PRINT '=== TREASURY DASHBOARD ===';
    PRINT 'Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '';
    
    -- FX Position Summary
    SELECT
        currency,
        long_position,
        short_position,
        net_position,
        unrealized_pnl,
        CASE 
            WHEN net_position > 0 THEN 'LONG'
            WHEN net_position < 0 THEN 'SHORT'
            ELSE 'FLAT'
        END AS position_status
    FROM dw.fact_fx_positions
    WHERE position_date_key = CAST(FORMAT(@BusinessDate, 'yyyyMMdd') AS INT);
    
    -- Exchange Rates
    SELECT
        source_currency + '/' + target_currency AS pair,
        bid_rate,
        ask_rate,
        mid_rate,
        (ask_rate - bid_rate) / mid_rate * 10000 AS spread_pips
    FROM dw.dim_exchange_rate
    WHERE rate_date = @BusinessDate;
    
    -- Liquidity Position
    SELECT
        currency,
        SUM(CASE WHEN account_type = 'SAVINGS' THEN balance ELSE 0 END) AS deposits,
        SUM(CASE WHEN account_type = 'LOAN' THEN balance ELSE 0 END) AS loans,
        SUM(balance) AS net_position
    FROM dw.fact_account_daily_snapshot
    WHERE snapshot_date_key = CAST(FORMAT(@BusinessDate, 'yyyyMMdd') AS INT)
    GROUP BY currency;
END;
```

---

## 8. Scenario 7: End-of-Day Reconciliation

### Business Context

Daily reconciliation ensures:
- All transactions are processed
- Balances are correct
- No data loss in ETL

### ETL Implementation

```sql
-- ============================================================
-- SCENARIO 7: END-OF-DAY RECONCILIATION
-- ============================================================

CREATE PROCEDURE etl.usp_EndOfDayReconciliation
    @BusinessDate DATE,
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @ReconciliationPassed BIT = 1;
    
    PRINT '========================================';
    PRINT 'END-OF-DAY RECONCILIATION';
    PRINT 'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120);
    PRINT '========================================';
    
    --------------------------------------------------------
    -- Check 1: Transaction Count Reconciliation
    --------------------------------------------------------
    DECLARE @SourceTxnCount BIGINT, @DWTxnCount BIGINT;
    
    SELECT @SourceTxnCount = COUNT(*)
    FROM cbs.dbo.transactions
    WHERE CAST(txn_date AS DATE) = @BusinessDate
    AND status = 'POSTED';
    
    SELECT @DWTxnCount = COUNT(*)
    FROM dw.fact_transactions t
    JOIN dw.dim_date d ON t.date_key = d.date_key
    WHERE d.full_date = @BusinessDate;
    
    PRINT '';
    PRINT 'CHECK 1: Transaction Count';
    PRINT '  Source: ' + CAST(@SourceTxnCount AS VARCHAR(10));
    PRINT '  DW:     ' + CAST(@DWTxnCount AS VARCHAR(10));
    
    IF @SourceTxnCount != @DWTxnCount
    BEGIN
        PRINT '  ❌ FAILED: Count mismatch!';
        SET @ReconciliationPassed = 0;
    END
    ELSE
        PRINT '  ✅ PASSED';
    
    --------------------------------------------------------
    -- Check 2: Transaction Amount Reconciliation
    --------------------------------------------------------
    DECLARE @SourceAmount DECIMAL(18,2), @DWAmount DECIMAL(18,2);
    
    SELECT @SourceAmount = SUM(amount)
    FROM cbs.dbo.transactions
    WHERE CAST(txn_date AS DATE) = @BusinessDate
    AND status = 'POSTED'
    AND currency = 'USD';
    
    SELECT @DWAmount = SUM(amount)
    FROM dw.fact_transactions t
    JOIN dw.dim_date d ON t.date_key = d.date_key
    WHERE d.full_date = @BusinessDate
    AND t.currency = 'USD';
    
    PRINT '';
    PRINT 'CHECK 2: Transaction Amount (USD)';
    PRINT '  Source: $' + FORMAT(@SourceAmount, 'N2');
    PRINT '  DW:     $' + FORMAT(@DWAmount, 'N2');
    
    IF ABS(@SourceAmount - @DWAmount) > 0.01
    BEGIN
        PRINT '  ❌ FAILED: Amount mismatch!';
        SET @ReconciliationPassed = 0;
    END
    ELSE
        PRINT '  ✅ PASSED';
    
    --------------------------------------------------------
    -- Check 3: Balance Reconciliation
    --------------------------------------------------------
    DECLARE @SourceBalances DECIMAL(18,2), @DWBalances DECIMAL(18,2);
    
    SELECT @SourceBalances = SUM(balance)
    FROM cbs.dbo.accounts
    WHERE status = 'ACTIVE';
    
    SELECT @DWBalances = SUM(balance)
    FROM dw.dim_account
    WHERE is_current = 1
    AND status = 'ACTIVE';
    
    PRINT '';
    PRINT 'CHECK 3: Total Balances';
    PRINT '  Source: $' + FORMAT(@SourceBalances, 'N2');
    PRINT '  DW:     $' + FORMAT(@DWBalances, 'N2');
    
    IF ABS(@SourceBalances - @DWBalances) > 1.00
    BEGIN
        PRINT '  ❌ FAILED: Balance mismatch!';
        SET @ReconciliationPassed = 0;
    END
    ELSE
        PRINT '  ✅ PASSED';
    
    --------------------------------------------------------
    -- Check 4: Customer Count Reconciliation
    --------------------------------------------------------
    DECLARE @SourceCustCount BIGINT, @DWCustCount BIGINT;
    
    SELECT @SourceCustCount = COUNT(*)
    FROM cbs.dbo.customers
    WHERE status = 'ACTIVE';
    
    SELECT @DWCustCount = COUNT(*)
    FROM dw.dim_customer
    WHERE is_current = 1
    AND is_active = 1;
    
    PRINT '';
    PRINT 'CHECK 4: Active Customer Count';
    PRINT '  Source: ' + CAST(@SourceCustCount AS VARCHAR(10));
    PRINT '  DW:     ' + CAST(@DWCustCount AS VARCHAR(10));
    
    IF @SourceCustCount != @DWCustCount
    BEGIN
        PRINT '  ⚠️  WARNING: Customer count mismatch!';
        -- This might be expected if new customers haven't been loaded yet
    END
    ELSE
        PRINT '  ✅ PASSED';
    
    --------------------------------------------------------
    -- Summary
    --------------------------------------------------------
    PRINT '';
    PRINT '========================================';
    IF @ReconciliationPassed = 1
        PRINT '✅ RECONCILIATION PASSED';
    ELSE
        PRINT '❌ RECONCILIATION FAILED - INVESTIGATE!';
    PRINT '========================================';
    
    --------------------------------------------------------
    -- Log reconciliation
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time,
        notes
    )
    VALUES (
        @BatchID, 'EndOfDay_Reconciliation', 'ALL', 'VALIDATE',
        4, 
        CASE WHEN @ReconciliationPassed = 1 THEN 'COMPLETED' ELSE 'FAILED' END,
        @StartTime, GETDATE(),
        'Business Date: ' + CONVERT(VARCHAR(10), @BusinessDate, 120)
    );
    
    -- Send alert if failed
    IF @ReconciliationPassed = 0
    BEGIN
        EXEC audit.usp_SendFailureAlert @BatchID;
    END
END;
```

---

## Summary

### Real-World Scenarios Covered

| Scenario | Business Value | Key Metrics |
|----------|---------------|-------------|
| **Daily Transactions** | Track all banking operations | Volume, value, channel mix |
| **Loan Portfolio** | Monitor credit risk | NPL ratio, provisions, aging |
| **Customer KYC** | Regulatory compliance | KYC status, expiry tracking |
| **AML/CFT** | Financial crime prevention | Alert count, risk scores |
| **Regulatory (NBC)** | Meet central bank requirements | CAR, large exposures |
| **Treasury/FX** | Manage currency risk | FX positions, liquidity |
| **Reconciliation** | Ensure data accuracy | Count/amount matching |

### Implementation Checklist

- [ ] Source system connections configured
- [ ] Staging tables created
- [ ] Dimension tables with SCD Type 2
- [ ] Fact tables for each scenario
- [ ] ETL procedures implemented
- [ ] Audit logging in place
- [ ] Error handling configured
- [ ] Monitoring alerts set up
- [ ] Report queries developed
- [ ] Reconciliation procedures tested

---

*Created: September 2024*
*Based on Sathapana Bank Cambodia Operations*
