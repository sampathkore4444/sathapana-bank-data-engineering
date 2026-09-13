# Banking Data Warehouse Design — Complete Guide

## Table of Contents

1. [Overview: Banking Data Warehouse](#1-overview)
2. [Source Systems Analysis](#2-source-systems)
3. [Conformed Dimensions](#3-conformed-dimensions)
4. [Fact Table Design](#4-fact-table-design)
5. [Banking Domain Models](#5-banking-domain-models)
6. [ETL Strategy](#6-etl-strategy)
7. [Data Quality Framework](#7-data-quality)
8. [Regulatory Reporting (NBRC)](#8-regulatory-reporting)
9. [Performance Tuning](#9-performance-tuning)
10. [Complete Schema Reference](#10-complete-schema)

---

## 1. Overview: Banking Data Warehouse

### Business Goals

A banking data warehouse serves multiple purposes:

```
┌─────────────────────────────────────────────────────────────┐
│                BANKING DATA WAREHOUSE GOALS                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📊 MANAGEMENT REPORTING                                    │
│  ├── Daily dashboard (CEO, CFO)                             │
│  ├── Branch performance reports                             │
│  └── Product profitability analysis                         │
│                                                             │
│  📋 REGULATORY COMPLIANCE                                   │
│  ├── NBRC (National Bank of Cambodia) reporting             │
│  ├── AML/CFT reports                                        │
│  ├── Capital adequacy reports                               │
│  └── Liquidity reports                                      │
│                                                             │
│  💰 FINANCIAL REPORTING                                     │
│  ├── General Ledger reconciliation                          │
│  ├── Balance sheet reports                                  │
│  ├── Profit & Loss statements                               │
│  └── Inter-branch reconciliation                            │
│                                                             │
│  📈 ANALYTICS                                               │
│  ├── Customer segmentation                                  │
│  ├── Product performance                                    │
│  ├── Channel analysis                                       │
│  └── Risk analytics                                         │
│                                                             │
│  🔍 AUDIT & COMPLIANCE                                      │
│  ├── Transaction monitoring                                 │
│  ├── Suspicious activity reports                            │
│  └── Historical audit trail                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                     SOURCE SYSTEMS                                │
├──────────┬──────────┬──────────┬──────────┬──────────┬──────────┤
│   CBS    │   CMS    │  Mobile  │ Internet │   ATM    │   GL     │
│ (Core    │ (Card    │ Banking  │ Banking  │ System   │ (General │
│  Banking)│  Mgmt)   │          │          │          │  Ledger) │
└────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬─────┘
     │          │          │          │          │          │
     └──────────┴──────────┴──────────┴──────────┴──────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   STAGING AREA   │
                    │  (Raw Data)      │
                    │  - Staging DB    │
                    │  - Temporary     │
                    └────────┬────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │  DATA WAREHOUSE  │
                    │  (Modeled Data)  │
                    │  - Star Schema   │
                    │  - SCD Type 2    │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │  REPORTING   │ │  ANALYTICS   │ │  DATA MARTS  │
    │  (SSRS)      │ │  (Power BI)  │ │  (Finance)   │
    └──────────────┘ └──────────────┘ └──────────────┘
```

---

## 2. Source Systems Analysis

### Core Banking System (CBS)

CBS is the primary source — it contains all account and transaction data.

```sql
-- CBS Source Tables (Typical):
-- These are the tables you'll extract from

-- Customer Information
cbs.dbo.customers
├── customer_id (PK)
├── full_name
├── date_of_birth
├── national_id
├── phone
├── email
├── address
├── customer_type (RETAIL, SME, CORPORATE)
├── risk_rating (LOW, MEDIUM, HIGH)
├── created_date
├── modified_date
└── status (A=Active, I=Inactive)

-- Account Information
cbs.dbo.accounts
├── account_id (PK)
├── account_number
├── customer_id (FK)
├── account_type (SAV, CUR, FDL, LON)
├── currency (USD, KHR)
├── open_date
├── close_date
├── status (A, C, D, F)
├── branch_code
├── product_code
└── modified_date

-- Transactions
cbs.dbo.transactions
├── transaction_id (PK)
├── account_id (FK)
├── transaction_date
├── value_date
├── amount
├── balance_after
├── transaction_type (DR, CR)
├── channel (TELLER, ATM, MOBILE, INTERNET)
├── description
├── reference_number
├── teller_id
├── branch_code
└── modified_date

-- Branch Information
cbs.dbo.branches
├── branch_code (PK)
├── branch_name
├── branch_type (HEAD, PROVINCIAL, SUB)
├── province
├── region
├── manager_name
└── status

-- Products
cbs.dbo.products
├── product_code (PK)
├── product_name
├── product_type (SAVINGS, LOAN, FIXED_DEPOSIT)
├── currency
├── interest_rate
├── min_balance
├── status
└── modified_date
```

### Card Management System (CMS)

```sql
-- CMS Source Tables:
cms.dbo.cards
├── card_id (PK)
├── card_number (masked: **** **** **** 1234)
├── customer_id
├── card_type (DEBIT, CREDIT)
├── expiry_date
├── status (ACTIVE, BLOCKED, EXPIRED)
├── limit_amount
└── issued_date

cms.dbo.card_transactions
├── transaction_id (PK)
├── card_id (FK)
├── transaction_date
├── amount
├── currency
├── merchant_name
├── merchant_category
├── transaction_type (PURCHASE, CASH_ADVANCE, PAYMENT)
├── channel (POS, ATM, ECOM)
├── authorization_code
└── status (APPROVED, DECLINED)
```

### Mobile Banking

```sql
-- Mobile Banking Source Tables:
mobile.dbo.app_users
├── user_id (PK)
├── customer_id (FK)
├── device_id
├── registration_date
├── last_login_date
├── status
└── platform (ANDROID, IOS)

mobile.dbo.mobile_transactions
├── transaction_id (PK)
├── user_id (FK)
├── transaction_date
├── amount
├── transaction_type (TRANSFER, PAYMENT, TOP_UP)
├── recipient_account
├── description
├── status (SUCCESS, FAILED, PENDING)
└── ip_address
```

### Data Extraction Strategy

```sql
-- Full Extract (Small tables: < 100K rows)
-- Use for: branches, products, channels
SELECT * FROM cbs.dbo.branches;

-- Incremental Extract (Large tables: > 1M rows)
-- Use for: transactions, daily balances
SELECT * FROM cbs.dbo.transactions
WHERE modified_date > @LastExtractDate
  AND modified_date <= @CurrentExtractDate;

-- CDC (Change Data Capture) — If enabled on source
-- Best for real-time or near-real-time loads
SELECT * FROM cbs.dbo.transactions_CDC
WHERE __$start_lsn > @LastLSN;
```

---

## 3. Conformed Dimensions

Conformed dimensions are shared across all fact tables, ensuring consistency.

### dim_date — Date Dimension

```sql
CREATE TABLE dim_date (
    date_key            INT PRIMARY KEY,        -- 20250912
    full_date           DATE,
    day_of_week         INT,                     -- 1=Sunday, 2=Monday...
    day_name            VARCHAR(10),             -- Monday
    day_of_month        INT,                     -- 12
    day_of_year         INT,                     -- 255
    week_of_year        INT,                     -- 37
    month_number        INT,                     -- 9
    month_name          VARCHAR(20),             -- September
    quarter             INT,                     -- 3
    year                INT,                     -- 2025
    fiscal_year         INT,                     -- Bank's fiscal year
    fiscal_quarter      INT,
    is_weekend          BIT,
    is_holiday          BIT,
    holiday_name        VARCHAR(100),            -- Pchum Ben, Khmer New Year
    is_month_end        BIT,
    is_quarter_end      BIT,
    is_year_end         BIT
);

-- Populate with 10 years of data
DECLARE @StartDate DATE = '2020-01-01';
DECLARE @EndDate DATE = '2030-12-31';

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO dim_date (
        date_key, full_date, day_of_week, day_name, day_of_month,
        day_of_year, week_of_year, month_number, month_name,
        quarter, year, is_weekend, is_month_end, is_quarter_end, is_year_end
    )
    VALUES (
        CAST(FORMAT(@StartDate, 'yyyyMMdd') AS INT),
        @StartDate,
        DATEPART(WEEKDAY, @StartDate),
        DATENAME(WEEKDAY, @StartDate),
        DAY(@StartDate),
        DATEPART(DAYOFYEAR, @StartDate),
        DATEPART(WEEK, @StartDate),
        MONTH(@StartDate),
        DATENAME(MONTH, @StartDate),
        DATEPART(QUARTER, @StartDate),
        YEAR(@StartDate),
        CASE WHEN DATEPART(WEEKDAY, @StartDate) IN (1, 7) THEN 1 ELSE 0 END,
        CASE WHEN @StartDate = EOMONTH(@StartDate) THEN 1 ELSE 0 END,
        CASE WHEN @StartDate = EOMONTH(@StartDate) AND MONTH(@StartDate) % 3 = 0 THEN 1 ELSE 0 END,
        CASE WHEN MONTH(@StartDate) = 12 AND DAY(@StartDate) = 31 THEN 1 ELSE 0 END
    );
    
    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;
```

### dim_branch — Branch Dimension

```sql
CREATE TABLE dim_branch (
    branch_key          INT IDENTITY(1,1) PRIMARY KEY,
    branch_code         VARCHAR(10),
    branch_name         NVARCHAR(200),
    branch_type         VARCHAR(50),            -- HEAD_OFFICE, PROVINCIAL, SUB_BRANCH
    province            NVARCHAR(100),
    region              NVARCHAR(100),          -- Phnom Penh, Siem Reap, Battambang
    district            NVARCHAR(100),
    branch_manager      NVARCHAR(200),
    open_date           DATE,
    is_active           BIT DEFAULT 1,
    -- SCD Type 2
    effective_date      DATE,
    expiry_date         DATE DEFAULT '9999-12-31',
    is_current          BIT DEFAULT 1,
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

### dim_customer — Customer Dimension (SCD Type 2)

```sql
CREATE TABLE dim_customer (
    customer_key        INT IDENTITY(1,1) PRIMARY KEY,
    customer_id         VARCHAR(20),             -- Natural key from CBS
    full_name           NVARCHAR(200),
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    gender              VARCHAR(10),
    date_of_birth       DATE,
    national_id         NVARCHAR(50),
    customer_type       VARCHAR(20),             -- RETAIL, SME, CORPORATE
    customer_segment    VARCHAR(50),             -- GOLD, SILVER, PLATINUM
    risk_rating         VARCHAR(10),             -- LOW, MEDIUM, HIGH
    province            NVARCHAR(100),
    city                NVARCHAR(100),
    phone               NVARCHAR(20),
    email               NVARCHAR(200),
    registration_date   DATE,
    -- Source system tracking
    cbs_customer_id     VARCHAR(20),
    cms_customer_id     VARCHAR(20),
    -- SCD Type 2
    effective_date      DATE,
    expiry_date         DATE DEFAULT '9999-12-31',
    is_current          BIT DEFAULT 1,
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

### dim_account — Account Dimension

```sql
CREATE TABLE dim_account (
    account_key         INT IDENTITY(1,1) PRIMARY KEY,
    account_number      VARCHAR(20),
    account_type        VARCHAR(30),             -- SAVINGS, CURRENT, FIXED_DEPOSIT, LOAN
    product_name        NVARCHAR(200),
    product_code        VARCHAR(20),
    currency            CHAR(3),                 -- USD, KHR
    open_date           DATE,
    maturity_date       DATE,
    interest_rate       DECIMAL(5,2),
    status              VARCHAR(10),             -- ACTIVE, CLOSED, DORMANT, FROZEN
    -- Foreign keys
    branch_key          INT FOREIGN KEY REFERENCES dim_branch(branch_key),
    customer_key        INT FOREIGN KEY REFERENCES dim_customer(customer_key),
    product_key         INT FOREIGN KEY REFERENCES dim_product(product_key),
    -- SCD Type 2
    effective_date      DATE,
    expiry_date         DATE DEFAULT '9999-12-31',
    is_current          BIT DEFAULT 1,
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

### dim_product — Product Dimension

```sql
CREATE TABLE dim_product (
    product_key         INT IDENTITY(1,1) PRIMARY KEY,
    product_code        VARCHAR(20),
    product_name        NVARCHAR(200),
    product_category    VARCHAR(50),             -- DEPOSIT, LOAN, CARD, INVESTMENT
    product_group       VARCHAR(50),             -- SAVINGS, CURRENT, TERM_DEPOSIT
    currency            CHAR(3),
    interest_rate       DECIMAL(5,2),
    min_balance         DECIMAL(18,2),
    max_balance         DECIMAL(18,2),
    term_months         INT,
    risk_weight         DECIMAL(5,2),
    is_active           BIT DEFAULT 1,
    -- SCD Type 2
    effective_date      DATE,
    expiry_date         DATE DEFAULT '9999-12-31',
    is_current          BIT DEFAULT 1
);
```

### dim_channel — Channel Dimension

```sql
CREATE TABLE dim_channel (
    channel_key         INT IDENTITY(1,1) PRIMARY KEY,
    channel_code        VARCHAR(20),
    channel_name        NVARCHAR(100),           -- Teller, ATM, Mobile Banking
    channel_type        VARCHAR(50),             -- BRANCH, SELF_SERVICE, DIGITAL
    is_digital          BIT,
    is_interbranch      BIT,
    is_active           BIT DEFAULT 1
);
```

---

## 4. Fact Table Design

### fact_transactions — Transaction Fact Table

```sql
CREATE TABLE fact_transactions (
    transaction_key     BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension Keys
    account_key         INT NOT NULL,
    date_key            INT NOT NULL,
    branch_key          INT NOT NULL,
    customer_key        INT NOT NULL,
    channel_key         INT NOT NULL,
    product_key         INT NOT NULL,
    -- Measures
    credit_amount       DECIMAL(18,2) DEFAULT 0,
    debit_amount        DECIMAL(18,2) DEFAULT 0,
    transaction_count   INT DEFAULT 1,
    balance_after       DECIMAL(18,2),
    -- Degenerate Dimensions
    transaction_type    VARCHAR(10),             -- DEBIT, CREDIT
    channel             VARCHAR(20),             -- TELLER, ATM, MOBILE
    source_system       VARCHAR(20),             -- CBS, CMS, MOBILE
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE(),
    etl_batch_id        INT
);

-- Indexes for performance
CREATE INDEX IX_fact_txn_date ON fact_transactions(date_key);
CREATE INDEX IX_fact_txn_account ON fact_transactions(account_key);
CREATE INDEX IX_fact_txn_branch ON fact_transactions(branch_key);
CREATE INDEX IX_fact_txn_customer ON fact_transactions(customer_key);
```

### fact_account_daily_balance — Periodic Snapshot

```sql
CREATE TABLE fact_account_daily_balance (
    balance_key         BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension Keys
    account_key         INT NOT NULL,
    date_key            INT NOT NULL,
    branch_key          INT NOT NULL,
    customer_key        INT NOT NULL,
    product_key         INT NOT NULL,
    -- Measures
    opening_balance     DECIMAL(18,2),
    closing_balance     DECIMAL(18,2),
    total_credits       DECIMAL(18,2) DEFAULT 0,
    total_debits        DECIMAL(18,2) DEFAULT 0,
    credit_count        INT DEFAULT 0,
    debit_count         INT DEFAULT 0,
    transaction_count   INT DEFAULT 0,
    -- SCD tracking
    account_status      VARCHAR(10),
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

### fact_loan_portfolio — Accumulating Snapshot

```sql
CREATE TABLE fact_loan_portfolio (
    loan_key            INT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension Keys
    account_key         INT NOT NULL,
    customer_key        INT NOT NULL,
    branch_key          INT NOT NULL,
    product_key         INT NOT NULL,
    -- Lifecycle Dates
    application_date_key    INT,
    approval_date_key       INT,
    disbursement_date_key   INT,
    maturity_date_key       INT,
    -- Measures
    approved_amount     DECIMAL(18,2),
    disbursed_amount    DECIMAL(18,2),
    outstanding_principal DECIMAL(18,2),
    outstanding_interest  DECIMAL(18,2),
    interest_rate       DECIMAL(5,2),
    days_past_due       INT,
    provision_amount    DECIMAL(18,2),
    -- Status
    loan_status         VARCHAR(20),             -- PENDING, APPROVED, DISBURSED, CLOSED, WRITTEN_OFF
    -- Metadata
    snapshot_date_key   INT NOT NULL,
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

### fact_card_transactions — Transaction Fact

```sql
CREATE TABLE fact_card_transactions (
    card_txn_key        BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Dimension Keys
    card_key            INT NOT NULL,
    date_key            INT NOT NULL,
    customer_key        INT NOT NULL,
    merchant_key        INT,
    channel_key         INT NOT NULL,
    -- Measures
    transaction_amount  DECIMAL(18,2),
    billing_amount      DECIMAL(18,2),
    -- Degenerate Dimensions
    transaction_type    VARCHAR(20),             -- PURCHASE, CASH_ADVANCE, PAYMENT
    merchant_category   VARCHAR(50),
    currency            CHAR(3),
    source_system       VARCHAR(20),
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

---

## 5. Banking Domain Models

### Model 1: Deposit Portfolio

```
Business Question: "What's our total deposit portfolio by branch and product?"

Star Schema:
                    dim_date
                       │
                       │
dim_branch ──── fact_daily_balance ──── dim_account
                       │
                       │
                   dim_product
```

```sql
-- Query: Total deposits by branch for Q3 2025
SELECT 
    b.branch_name,
    p.product_category,
    SUM(f.closing_balance) as total_deposits
FROM fact_account_daily_balance f
JOIN dim_branch b ON f.branch_key = b.branch_key
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2025 AND d.quarter = 3
  AND p.product_category = 'DEPOSIT'
  AND b.is_current = 1
GROUP BY b.branch_name, p.product_category
ORDER BY total_deposits DESC;
```

### Model 2: Loan Portfolio

```
Business Question: "What's our NPL (Non-Performing Loan) ratio by branch?"

Star Schema:
                    dim_date
                       │
                       │
dim_branch ──── fact_loan_portfolio ──── dim_customer
                       │
                       │
                   dim_product
```

```sql
-- Query: NPL ratio by branch
SELECT 
    b.branch_name,
    COUNT(*) as total_loans,
    SUM(CASE WHEN f.days_past_due > 90 THEN 1 ELSE 0 END) as npl_count,
    CAST(SUM(CASE WHEN f.days_past_due > 90 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as npl_ratio
FROM fact_loan_portfolio f
JOIN dim_branch b ON f.branch_key = b.branch_key
JOIN dim_date d ON f.snapshot_date_key = d.date_key
WHERE d.year = 2025 AND d.quarter = 3
  AND f.loan_status = 'DISBURSED'
  AND b.is_current = 1
GROUP BY b.branch_name
ORDER BY npl_ratio DESC;
```

### Model 3: Channel Analysis

```
Business Question: "Which channel has the most transaction volume?"

Star Schema:
                    dim_date
                       │
                       │
dim_channel ──── fact_transactions ──── dim_account
                       │
                       │
                   dim_branch
```

```sql
-- Query: Transaction volume by channel
SELECT 
    c.channel_name,
    c.channel_type,
    COUNT(*) as transaction_count,
    SUM(f.credit_amount + f.debit_amount) as total_volume,
    AVG(f.credit_amount + f.debit_amount) as avg_transaction_size
FROM fact_transactions f
JOIN dim_channel c ON f.channel_key = c.channel_key
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2025 AND d.month_number = 9
GROUP BY c.channel_name, c.channel_type
ORDER BY total_volume DESC;
```

### Model 4: Customer Profitability

```
Business Question: "Which customer segments are most profitable?"

Star Schema:
                    dim_date
                       │
                       │
dim_customer ──── fact_transactions ──── dim_product
                       │
                       │
                   dim_branch
```

```sql
-- Query: Profitability by customer segment
SELECT 
    c.customer_segment,
    c.customer_type,
    COUNT(DISTINCT c.customer_key) as customer_count,
    SUM(f.debit_amount) as total_withdrawals,
    SUM(f.credit_amount) as total_deposits,
    SUM(f.credit_amount) - SUM(f.debit_amount) as net_deposits
FROM fact_transactions f
JOIN dim_customer c ON f.customer_key = c.customer_key
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2025 AND c.is_current = 1
GROUP BY c.customer_segment, c.customer_type
ORDER BY net_deposits DESC;
```

---

## 6. ETL Strategy

### Extraction Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    EXTRACTION STRATEGY                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  FULL EXTRACT (Small tables: < 100K rows)                   │
│  ├── dim_branch                                             │
│  ├── dim_product                                            │
│  ├── dim_channel                                            │
│  └── Frequency: Daily (truncate and reload)                 │
│                                                             │
│  INCREMENTAL EXTRACT (Large tables: > 1M rows)              │
│  ├── fact_transactions (WHERE modified_date > @LastLoad)    │
│  ├── fact_daily_balance (WHERE date_key > @LastDateKey)     │
│  ├── dim_customer (SCD Type 2 processing)                   │
│  └── Frequency: Daily (append only)                         │
│                                                             │
│  CHANGE DATA CAPTURE (Real-time)                            │
│  ├── Enable CDC on source tables                            │
│  ├── Capture INSERT, UPDATE, DELETE                          │
│  └── Frequency: Near real-time (every 15 minutes)           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Loading Strategy

```
┌─────────────────────────────────────────────────────────────┐
│                    LOADING STRATEGY                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  STAGING TABLES                                             │
│  ├── Raw data from source systems                           │
│  ├── No constraints or indexes                              │
│  ├── Truncated before each load                             │
│  └── Used for data validation                               │
│                                                             │
│  DIMENSION TABLES                                           │
│  ├── Load BEFORE fact tables                                │
│  ├── SCD Type 2 for changing attributes                     │
│  ├── Truncate and reload for static dimensions              │
│  └── Always use surrogate keys                              │
│                                                             │
│  FACT TABLES                                                │
│  ├── Load AFTER dimensions                                  │
│  ├── Use surrogate keys from dimensions                     │
│  ├── Append-only (no updates)                               │
│  └── Bulk insert for performance                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### ETL Package Sequence

```
Step 1: Pre-Processing
├── Truncate staging tables
├── Set load parameters (dates, batch IDs)
└── Check source system availability

Step 2: Extraction
├── Extract CBS data → staging_cbs_*
├── Extract CMS data → staging_cms_*
├── Extract Mobile data → staging_mobile_*
└── Extract ATM data → staging_atm_*

Step 3: Validation
├── Check for NULLs in required fields
├── Check for duplicates
├── Check for referential integrity
└── Log any data quality issues

Step 4: Load Dimensions
├── Load dim_branch (truncate and reload)
├── Load dim_product (truncate and reload)
├── Load dim_channel (truncate and reload)
├── Load dim_customer (SCD Type 2)
└── Load dim_account (SCD Type 2)

Step 5: Load Facts
├── Load fact_transactions (incremental)
├── Load fact_daily_balance (daily snapshot)
├── Load fact_loan_portfolio (monthly snapshot)
└── Load fact_card_transactions (incremental)

Step 6: Post-Processing
├── Rebuild indexes
├── Update statistics
├── Send completion email
└── Log audit information
```

---

## 7. Data Quality Framework

### Data Quality Rules

```sql
-- Create data quality rules table
CREATE TABLE etl_data_quality_rules (
    rule_id             INT PRIMARY KEY,
    rule_name           VARCHAR(100),
    rule_description    NVARCHAR(500),
    table_name          VARCHAR(100),
    column_name         VARCHAR(100),
    rule_type           VARCHAR(50),             -- NOT_NULL, UNIQUE, RANGE, LOOKUP, PATTERN
    rule_expression     NVARCHAR(500),
    severity            VARCHAR(20),             -- CRITICAL, WARNING, INFO
    is_active           BIT DEFAULT 1
);

-- Example rules
INSERT INTO etl_data_quality_rules VALUES
(1, 'Customer ID Not Null', 'Customer ID must not be NULL', 'staging_customers', 'customer_id', 'NOT_NULL', NULL, 'CRITICAL', 1),
(2, 'Risk Rating Valid', 'Risk rating must be LOW, MEDIUM, or HIGH', 'staging_customers', 'risk_rating', 'IN_LIST', 'LOW,MEDIUM,HIGH', 'WARNING', 1),
(3, 'Transaction Amount Positive', 'Transaction amount must be > 0', 'staging_transactions', 'amount', 'RANGE', '>0', 'CRITICAL', 1),
(4, 'Account Number Format', 'Account number must be XXX-XXX-XXXXXX', 'staging_accounts', 'account_number', 'PATTERN', '^\d{3}-\d{3}-\d{6}$', 'WARNING', 1);
```

### Data Quality Check Process

```sql
-- Execute data quality checks
CREATE PROCEDURE etl_run_quality_checks
    @batch_id INT,
    @load_date DATE
AS
BEGIN
    -- Check 1: Not Null
    INSERT INTO etl_quality_results (batch_id, rule_id, failed_count, sample_data)
    SELECT 
        @batch_id,
        r.rule_id,
        COUNT(*),
        (SELECT TOP 10 customer_id FROM staging_customers WHERE customer_id IS NULL FOR XML PATH(''))
    FROM etl_data_quality_rules r
    CROSS APPLY (
        SELECT COUNT(*) as cnt FROM staging_customers WHERE customer_id IS NULL
    ) q
    WHERE r.rule_name = 'Customer ID Not Null'
      AND q.cnt > 0;
    
    -- Check 2: Valid values
    INSERT INTO etl_quality_results (batch_id, rule_id, failed_count, sample_data)
    SELECT 
        @batch_id,
        r.rule_id,
        COUNT(*),
        (SELECT TOP 10 risk_rating FROM staging_customers 
         WHERE risk_rating NOT IN ('LOW', 'MEDIUM', 'HIGH') FOR XML PATH(''))
    FROM etl_data_quality_rules r
    CROSS APPLY (
        SELECT COUNT(*) as cnt FROM staging_customers 
        WHERE risk_rating NOT IN ('LOW', 'MEDIUM', 'HIGH')
    ) q
    WHERE r.rule_name = 'Risk Rating Valid'
      AND q.cnt > 0;
    
    -- etc.
END;
```

### Data Quality Dashboard

```sql
-- View quality results
SELECT 
    r.rule_name,
    r.table_name,
    r.column_name,
    r.severity,
    qr.failed_count,
    qr.sample_data,
    qr.check_date
FROM etl_quality_results qr
JOIN etl_data_quality_rules r ON qr.rule_id = r.rule_id
WHERE qr.batch_id = @batch_id
ORDER BY r.severity, r.rule_name;
```

---

## 8. Regulatory Reporting (NBRC)

### NBRC Report Requirements

```
┌─────────────────────────────────────────────────────────────┐
│              NBRC REPORTING REQUIREMENTS                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  📊 DAILY REPORTS                                           │
│  ├── Daily Transaction Summary                              │
│  ├── Daily Balance Report                                   │
│  └── Inter-branch Reconciliation                            │
│                                                             │
│  📊 MONTHLY REPORTS                                         │
│  ├── Monthly Portfolio Report                               │
│  ├── NPL Classification Report                              │
│  ├── Capital Adequacy Report                                │
│  └── Liquidity Report                                       │
│                                                             │
│  📊 QUARTERLY REPORTS                                       │
│  ├── Quarterly Financial Statements                         │
│  ├── Large Exposure Report                                  │
│  ├── Connected Lending Report                               │
│  └── Foreign Exchange Report                                │
│                                                             │
│  📊 ANNUAL REPORTS                                          │
│  ├── Annual Financial Statements                            │
│  ├── Audit Report                                           │
│  └── Risk Assessment Report                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Sample NBRC Data Mart

```sql
-- NBRC Data Mart - Separate from main DW for reporting
CREATE TABLE nbrc_monthly_portfolio (
    report_key          INT IDENTITY(1,1) PRIMARY KEY,
    report_date         DATE,
    branch_code         VARCHAR(10),
    branch_name         NVARCHAR(200),
    province            NVARCHAR(100),
    product_category    VARCHAR(50),
    currency            CHAR(3),
    -- Balance Sheet Items
    total_deposits      DECIMAL(18,2),
    demand_deposits     DECIMAL(18,2),
    savings_deposits    DECIMAL(18,2),
    term_deposits       DECIMAL(18,2),
    total Loans         DECIMAL(18,2),
    standard_loans      DECIMAL(18,2),
    special_mention     DECIMAL(18,2),
    substandard         DECIMAL(18,2),
    doubtful            DECIMAL(18,2),
    loss                DECIMAL(18,2),
    -- Capital
    tier1_capital       DECIMAL(18,2),
    tier2_capital       DECIMAL(18,2),
    risk_weighted_assets DECIMAL(18,2),
    car_ratio           DECIMAL(5,2),            -- Capital Adequacy Ratio
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

---

## 9. Performance Tuning

### Indexing Strategy

```sql
-- Fact Tables: Clustered index on date_key (most common query pattern)
CREATE CLUSTERED INDEX IX_fact_txn_date ON fact_transactions(date_key);

-- Fact Tables: Non-clustered indexes on frequently queried columns
CREATE NONCLUSTERED INDEX IX_fact_txn_account ON fact_transactions(account_key) INCLUDE (credit_amount, debit_amount);
CREATE NONCLUSTERED INDEX IX_fact_txn_branch ON fact_transactions(branch_key) INCLUDE (credit_amount, debit_amount);

-- Dimension Tables: Index on natural key (for lookups)
CREATE NONCLUSTERED INDEX IX_dim_customer_id ON dim_customer(customer_id) WHERE is_current = 1;
CREATE NONCLUSTERED INDEX IX_dim_account_number ON dim_account(account_number) WHERE is_current = 1;
```

### Partitioning (For Large Fact Tables)

```sql
-- Partition fact_transactions by year
CREATE PARTITION FUNCTION pf_transaction_date (INT)
AS RANGE RIGHT FOR VALUES (20230101, 20240101, 20250101, 20260101);

CREATE PARTITION SCHEME ps_transaction_date
AS PARTITION pf_transaction_date ALL TO ([PRIMARY]);

-- Apply to fact table
CREATE TABLE fact_transactions (
    transaction_key     BIGINT IDENTITY(1,1),
    account_key         INT,
    date_key            INT,
    ...
) ON ps_transaction_date(date_key);
```

### Aggregation Tables

```sql
-- Pre-aggregated summary for fast reporting
CREATE TABLE agg_monthly_branch_summary (
    summary_key         INT IDENTITY(1,1) PRIMARY KEY,
    year                INT,
    month               INT,
    branch_key          INT,
    product_key         INT,
    total_transactions  INT,
    total_credits       DECIMAL(18,2),
    total_debits        DECIMAL(18,2),
    avg_balance         DECIMAL(18,2),
    etl_load_date       DATETIME DEFAULT GETDATE()
);

-- Refresh monthly
INSERT INTO agg_monthly_branch_summary
SELECT 
    d.year, d.month_number, f.branch_key, f.product_key,
    COUNT(*), SUM(f.credit_amount), SUM(f.debit_amount), AVG(f.balance_after)
FROM fact_transactions f
JOIN dim_date d ON f.date_key = d.date_key
WHERE d.year = 2025 AND d.month_number = 9
GROUP BY d.year, d.month_number, f.branch_key, f.product_key;
```

---

## 10. Complete Schema Reference

### Full Star Schema Diagram

```
┌──────────────┐                                    ┌──────────────┐
│  dim_date    │                                    │  dim_product │
│──────────────│                                    │──────────────│
│ date_key(PK) │                                    │product_key(PK)│
│ full_date    │                                    │product_code  │
│ year         │                                    │product_name  │
│ month        │                                    │product_category│
│ quarter      │                                    │interest_rate │
│ is_holiday   │                                    └──────┬───────┘
└──────┬───────┘                                           │
       │                                                   │
       │         ┌──────────────┐                          │
       │         │  dim_branch  │                          │
       │         │──────────────│                          │
       │         │branch_key(PK)│                          │
       │         │branch_code   │                          │
       │         │branch_name   │                          │
       │         │province      │                          │
       │         │region        │                          │
       │         └──────┬───────┘                          │
       │                │                                  │
       ▼                ▼                                  ▼
┌──────────────────────────────────────────────────────────────────┐
│                        fact_transactions                         │
│──────────────────────────────────────────────────────────────────│
│ transaction_key (PK) │ account_key (FK) │ date_key (FK)         │
│ branch_key (FK)      │ customer_key (FK)│ channel_key (FK)      │
│ product_key (FK)     │ credit_amount    │ debit_amount          │
│ balance_after        │ transaction_count│ transaction_type      │
│ channel              │ source_system    │ etl_load_date         │
└──────────────────────────────────────────────────────────────────┘
       ▲                ▲                                  ▲
       │                │                                  │
       │         ┌──────┴───────┐                          │
       │         │dim_customer  │                          │
       │         │──────────────│                          │
       │         │customer_key  │                          │
       │         │customer_id   │                          │
       │         │full_name     │                          │
       │         │risk_rating   │                          │
       │         │customer_type │                          │
       │         └──────────────┘                          │
       │                                                   │
       │         ┌──────────────┐                          │
       │         │ dim_channel  │                          │
       │         │──────────────│                          │
       │         │channel_key   │                          │
       │         │channel_name  │                          │
       │         │channel_type  │                          │
       │         │is_digital    │                          │
       │         └──────────────┘                          │
       │                                                   │
       └───────────────────────────────────────────────────┘
```

---

## Quick Reference — Banking DW Checklist

```
┌────────────────────────────────────────────────────────────┐
│           BANKING DATA WAREHOUSE CHECKLIST                  │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ✅ DESIGN PHASE                                           │
│  □ Identify all source systems (CBS, CMS, Mobile, etc.)    │
│  □ Define business questions to answer                     │
│  □ Design dimensional model (Star Schema)                  │
│  □ Define grain for each fact table                        │
│  □ Design conformed dimensions                             │
│  □ Plan SCD strategy for each dimension                    │
│  □ Design data quality rules                               │
│                                                            │
│  ✅ DEVELOPMENT PHASE                                      │
│  □ Create staging database                                 │
│  □ Create data warehouse database                          │
│  □ Build dimension tables                                  │
│  □ Build fact tables                                       │
│  □ Develop SSIS packages                                   │
│  □ Implement data quality checks                           │
│  □ Implement error handling                                │
│  □ Implement logging and auditing                          │
│                                                            │
│  ✅ TESTING PHASE                                          │
│  □ Test data accuracy                                      │
│  □ Test performance                                        │
│  □ Test error scenarios                                    │
│  □ Test incremental loads                                  │
│  □ Validate against source systems                         │
│                                                            │
│  ✅ DEPLOYMENT PHASE                                       │
│  □ Schedule daily ETL jobs                                 │
│  □ Set up monitoring alerts                                │
│  □ Document ETL processes                                  │
│  □ Train users on reporting tools                          │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## Next Steps

Continue to: **[07-modern-alternatives.md](./07-modern-alternatives.md)** to learn about Azure Data Factory, dbt, and modern ETL/ELT approaches.

---

*Last Updated: September 2026*
*Author: Buffy (Codebuff)*
