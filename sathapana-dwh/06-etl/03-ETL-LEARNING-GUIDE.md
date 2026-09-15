# 📚 ETL Learning Guide - Sathapana Bank Data Engineering

## Table of Contents
1. [ETL Overview](#1-etl-overview)
2. [Pipeline Architecture](#2-pipeline-architecture)
3. [Extract Phase Deep Dive](#3-extract-phase-deep-dive)
4. [Transform Phase Deep Dive](#4-transform-phase-deep-dive)
5. [Load Phase Deep Dive](#5-load-phase-deep-dive)
6. [SCD Type 2 Deep Dive](#6-scd-type-2-deep-dive)
7. [Incremental Load Patterns](#7-incremental-load-patterns)
8. [Error Handling Best Practices](#8-error-handling-best-practices)
9. [Performance Optimization](#9-performance-optimization)
10. [Hands-On Examples](#10-hands-on-examples)

---

## 1. ETL Overview

### What is ETL?

**ETL** stands for **Extract, Transform, Load** — the foundational process for moving data from operational source systems into a data warehouse for analysis and reporting.

```
┌─────────────────────────────────────────────────────────────────┐
│                         ETL PROCESS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   EXTRACT              TRANSFORM              LOAD                │
│   ┌─────┐             ┌─────────┐           ┌─────┐             │
│   │     │  ────────►  │         │  ───────► │     │             │
│   │ SRC │             │ CLEANSE │           │ DWH │             │
│   │     │             │ ENRICH  │           │     │             │
│   └─────┘             │ VALIDATE│           └─────┘             │
│                       └─────────┘                                 │
│                                                                  │
│   • Pull data         • Clean data          • Insert into        │
│   • From sources      • Apply rules         • Data warehouse     │
│   • To staging        • Create keys         • Dimension & Fact   │
└─────────────────────────────────────────────────────────────────┘
```

### Why ETL Matters

| Benefit | Description |
|---------|-------------|
| **Data Integration** | Combine data from multiple disparate sources |
| **Data Quality** | Cleanse and validate data before analysis |
| **Historical Tracking** | Maintain history via SCD patterns |
| **Performance** | Pre-aggregate and optimize for reporting |
| **Single Source of Truth** | Centralized, consistent data for the organization |

---

## 2. Pipeline Architecture

### Sathapana Bank ETL Schedule

```
┌─────────────────────────────────────────────────────────────────┐
│                    DAILY ETL PIPELINE                            │
│                    Schedule: 2:00 AM - 6:00 AM                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ STEP 1: EXTRACT (2:00 AM - 2:30 AM)                    │    │
│  │ ─────────────────────────────────────                   │    │
│  │ sathapana_source ──► sathapana_staging                  │    │
│  │                                                         │    │
│  │ • Full/incremental copy                                 │    │
│  │ • Source-to-raw validation                              │    │
│  │ • Row count reconciliation                              │    │
│  │ • Batch ID generation                                   │    │
│  └─────────────────────────┬───────────────────────────────┘    │
│                            │                                    │
│  ┌─────────────────────────▼───────────────────────────────┐    │
│  │ STEP 2: STAGE (2:30 AM - 3:00 AM)                      │    │
│  │ ───────────────────────────────                         │    │
│  │ sathapana_staging                                        │    │
│  │                                                         │    │
│  │ • Data cleansing                                        │    │
│  │ • Data type conversions                                 │    │
│  │ • Duplicate detection                                   │    │
│  │ • Business rule validation                              │    │
│  │ • NULL handling                                         │    │
│  └─────────────────────────┬───────────────────────────────┘    │
│                            │                                    │
│  ┌─────────────────────────▼───────────────────────────────┐    │
│  │ STEP 3: TRANSFORM (3:00 AM - 4:00 AM)                  │    │
│  │ ────────────────────────────────────                    │    │
│  │ Transformation Engine                                    │    │
│  │                                                         │    │
│  │ • Surrogate key generation                              │    │
│  │ • SCD processing (Type 1 & 2)                           │    │
│  │ • Business rule application                             │    │
│  │ • Currency conversion                                   │    │
│  │ • Data aggregation                                      │    │
│  │ • Lookup resolution                                     │    │
│  └─────────────────────────┬───────────────────────────────┘    │
│                            │                                    │
│  ┌─────────────────────────▼───────────────────────────────┐    │
│  │ STEP 4: LOAD (4:00 AM - 5:00 AM)                       │    │
│  │ ─────────────────────────────                           │    │
│  │ sathapana_dwh                                            │    │
│  │                                                         │    │
│  │ • Dimension loads (SCD)                                 │    │
│  │ • Fact loads (incremental)                              │    │
│  │ • Index maintenance                                     │    │
│  │ • Statistics update                                     │    │
│  └─────────────────────────┬───────────────────────────────┘    │
│                            │                                    │
│  ┌─────────────────────────▼───────────────────────────────┐    │
│  │ STEP 5: SERVE (5:00 AM - 6:00 AM)                      │    │
│  │ ─────────────────────────────                           │    │
│  │ Data Marts                                               │    │
│  │                                                         │    │
│  │ • Credit Risk mart refresh                              │    │
│  │ • Customer Analytics mart refresh                       │    │
│  │ • Treasury mart refresh                                 │    │
│  │ • Compliance mart refresh                               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Data Zone Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DATA ZONES                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │   LAYER 0   │  Source Systems (OLTP)                        │
│  │   Source     │  sathapana_source.oltp.*                      │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │   LAYER 1   │  Raw Zone (as-is from source)                 │
│  │   Raw       │  sathapana_raw.raw.*                           │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │   LAYER 2   │  Staging Zone (cleaned, validated)            │
│  │   Staging   │  sathapana_staging.staging.stg_*               │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │   LAYER 3   │  Enterprise Data Warehouse                    │
│  │   DW        │  sathapana_dwh.dw.dim_* / dw.fact_*           │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │   LAYER 4   │  Data Marts (business-specific)               │
│  │   Marts     │  Credit Risk, Customer Analytics, etc.        │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Extract Phase Deep Dive

### Extraction Strategies

#### Strategy 1: Full Load (Truncate & Reload)

```sql
-- Best for: Small, slowly changing tables (branches, products)
-- Pros: Simple, always accurate
-- Cons: Slow for large tables, high source system load

CREATE OR ALTER PROCEDURE staging.usp_ExtractBranches
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    -- Step 1: Truncate staging table (remove all previous data)
    TRUNCATE TABLE staging.stg_branches;
    
    -- Step 2: Extract ALL records from source
    INSERT INTO staging.stg_branches (
        branch_code, branch_name, branch_name_kh, branch_type,
        region, province, district, is_active,
        source_key, batch_id
    )
    SELECT 
        b.branch_code,
        b.branch_name,
        b.branch_name_kh,
        b.branch_type,
        b.region,
        b.province,
        b.district,
        b.is_active,
        CAST(b.branch_id AS VARCHAR(50)),  -- Natural key as string
        @BatchID
    FROM sathapana_source.oltp.branches b;
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Step 3: Log the extraction
    INSERT INTO sathapana_dwh.audit.etl_log (
        batch_id, step_name, table_name, operation, 
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Extract_Branches', 'stg_branches', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' branches.';
END;
```

#### Strategy 2: Incremental Load (Delta Only)

```sql
-- Best for: Large, frequently updated tables (transactions)
-- Pros: Fast, low source load
-- Cons: More complex, requires tracking mechanism

CREATE OR ALTER PROCEDURE staging.usp_ExtractTransactions
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    DECLARE @LastExtractDate DATETIME;
    DECLARE @LastExtractKey BIGINT;
    
    -- Step 1: Get the last extraction point
    SELECT 
        @LastExtractDate = last_extract_date,
        @LastExtractKey = last_extract_key
    FROM staging.etl_control
    WHERE source_table = 'transactions';
    
    -- Handle first-time extraction
    IF @LastExtractDate IS NULL
    BEGIN
        SET @LastExtractDate = '1900-01-01';
        SET @LastExtractKey = 0;
    END
    
    -- Step 2: Truncate staging (we'll reload only new records)
    TRUNCATE TABLE staging.stg_transactions;
    
    -- Step 3: Extract ONLY records created/modified since last run
    INSERT INTO staging.stg_transactions (
        transaction_code, account_number, customer_code,
        transaction_type, amount, currency, transaction_date,
        source_key, batch_id
    )
    SELECT 
        t.transaction_code,
        a.account_number,
        c.customer_code,
        t.transaction_type,
        t.amount,
        t.currency,
        t.transaction_date,
        CAST(t.transaction_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.transactions t
    JOIN sathapana_source.oltp.accounts a ON t.account_id = a.account_id
    JOIN sathapana_source.oltp.customers c ON a.customer_id = c.customer_id
    WHERE t.created_date > @LastExtractDate  -- Only new records
       OR t.modified_date > @LastExtractDate; -- Or updated records
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Step 4: Update control table with new high-water mark
    UPDATE staging.etl_control
    SET 
        last_extract_date = GETDATE(),
        last_extract_key = (
            SELECT MAX(transaction_id) 
            FROM sathapana_source.oltp.transactions
        ),
        row_count = @RecordCount,
        status = 'EXTRACTED',
        modified_date = GETDATE()
    WHERE source_table = 'transactions';
    
    -- Step 5: Log the extraction
    INSERT INTO sathapana_dwh.audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Extract_Transactions', 'stg_transactions', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' transactions.';
END;
```

### Extraction Control Table

```sql
-- ETL Control Table - Tracks extraction metadata
CREATE TABLE staging.etl_control (
    control_id INT IDENTITY(1,1) PRIMARY KEY,
    source_table VARCHAR(100) NOT NULL,
    last_extract_date DATETIME,
    last_extract_key BIGINT,
    row_count BIGINT,
    status VARCHAR(20),
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT UQ_etl_control_source UNIQUE (source_table)
);

-- Sample data
INSERT INTO staging.etl_control (source_table, status)
VALUES 
    ('branches', 'PENDING'),
    ('customers', 'PENDING'),
    ('transactions', 'PENDING'),
    ('accounts', 'PENDING');
```

### Extraction Patterns Summary

| Pattern | When to Use | Pros | Cons |
|---------|-------------|------|------|
| **Full Load** | Small tables (<100K rows) | Simple, reliable | Slow for large data |
| **Incremental (Date)** | Tables with timestamps | Fast, efficient | Misses deleted records |
| **Incremental (Key)** | Auto-increment IDs | Very fast | Complex to implement |
| **CDC (Change Data Capture)** | Real-time requirements | Captures all changes | Requires DB support |
| **Log-based** | Minimal source impact | Non-intrusive | Complex setup |

---

## 4. Transform Phase Deep Dive

### Transformation Types

#### 1. Data Cleansing

```sql
-- Remove leading/trailing spaces
TRIM(first_name) AS first_name

-- Standardize phone numbers
REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '+855', '0') AS phone_clean

-- Convert to proper case
UPPER(LEFT(first_name, 1)) + LOWER(SUBSTRING(first_name, 2, LEN(first_name))) AS first_name_proper

-- Handle NULLs
ISNULL(nickname, first_name) AS display_name
```

#### 2. Data Type Conversions

```sql
-- String to Date
CONVERT(DATE, dob_string, 103) AS date_of_birth  -- dd/mm/yyyy format

-- Numeric to String (for codes)
CAST(branch_id AS VARCHAR(10)) AS branch_code

-- String to Decimal
CAST(amount_string AS DECIMAL(18,2)) AS amount
```

#### 3. Lookup/Reference Resolution

```sql
-- Resolve natural keys to surrogate keys
INSERT INTO dw.fact_transactions (account_key, customer_key, ...)
SELECT
    a.account_key,      -- Surrogate key from dimension
    c.customer_key,     -- Surrogate key from dimension
    ...
FROM staging.stg_transactions s
-- Lookup account surrogate key
JOIN dw.dim_account a 
    ON s.account_number = a.account_number 
    AND a.is_current = 1
-- Lookup customer surrogate key
JOIN dw.dim_customer c 
    ON s.customer_code = c.customer_code 
    AND c.is_current = 1;
```

#### 4. Business Rule Application

```sql
-- Risk classification based on days past due
CASE 
    WHEN days_past_due = 0 THEN 'Performing'
    WHEN days_past_due BETWEEN 1 AND 30 THEN 'Special Mention'
    WHEN days_past_due BETWEEN 31 AND 60 THEN 'Substandard'
    WHEN days_past_due BETWEEN 61 AND 90 THEN 'Doubtful'
    WHEN days_past_due > 90 THEN 'Loss'
END AS risk_classification

-- Customer segmentation
CASE 
    WHEN annual_income >= 100000 THEN 'Premium'
    WHEN annual_income >= 50000 THEN 'Gold'
    WHEN annual_income >= 20000 THEN 'Silver'
    ELSE 'Standard'
END AS customer_segment
```

#### 5. Currency Conversion

```sql
-- Convert all amounts to USD
SELECT
    transaction_code,
    amount AS amount_local,
    currency,
    CASE 
        WHEN currency = 'KHR' THEN amount / 4100.00  -- KHR to USD
        WHEN currency = 'USD' THEN amount
        WHEN currency = 'THB' THEN amount * 0.029     -- THB to USD
        ELSE amount * ISNULL(er.rate, 1.0)
    END AS amount_usd
FROM staging.stg_transactions t
LEFT JOIN staging.stg_exchange_rates er
    ON t.currency = er.source_currency
    AND er.target_currency = 'USD'
    AND er.rate_date = CAST(t.transaction_date AS DATE);
```

---

## 5. Load Phase Deep Dive

### Load Order Rules

```
┌─────────────────────────────────────────────────────────────────┐
│                    LOAD ORDER (Critical!)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  DIMENSIONS (Must load first - referenced by facts)             │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 1. dim_date          (No dependencies)                  │    │
│  │ 2. dim_branch        (No dependencies)                  │    │
│  │ 3. dim_product       (No dependencies)                  │    │
│  │ 4. dim_customer      (No dependencies)                  │    │
│  │ 5. dim_account       (References: customer, product,    │    │
│  │                       branch)                           │    │
│  │ 6. dim_employee      (References: branch)               │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                    │
│                            ▼                                    │
│  FACTS (Load after all dimensions exist)                        │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 7. fact_transactions     (References: account, customer,│    │
│  │                           product, branch, channel)     │    │
│  │ 8. fact_loan_portfolio   (References: customer, product,│    │
│  │                           branch, employee)             │    │
│  │ 9. fact_deposit_snapshot (References: account, customer,│    │
│  │                           product, branch)              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Load Strategies

#### Strategy 1: Insert Only (Append)

```sql
-- Best for: Fact tables, transaction logs
-- Pattern: Never update, only add new records

INSERT INTO dw.fact_transactions (...)
SELECT ...
FROM staging.stg_transactions s
WHERE NOT EXISTS (
    SELECT 1 FROM dw.fact_transactions d
    WHERE d.transaction_code = s.transaction_code
);
```

#### Strategy 2: Merge (Upsert)

```sql
-- Best for: Dimensions with SCD Type 1
-- Pattern: Insert new, update existing

-- Insert new records
INSERT INTO dw.dim_product (product_code, product_name, ...)
SELECT s.product_code, s.product_name, ...
FROM staging.stg_products s
WHERE NOT EXISTS (
    SELECT 1 FROM dw.dim_product d
    WHERE d.product_code = s.product_code
);

-- Update existing records
UPDATE d
SET 
    d.product_name = s.product_name,
    d.category = s.category,
    d.modified_date = GETDATE()
FROM dw.dim_product d
JOIN staging.stg_products s ON d.product_code = s.product_code;
```

#### Strategy 3: SCD Type 2 (Historical)

```sql
-- Best for: Dimensions where history matters
-- Pattern: Expire old record, insert new version

-- See Section 6 for detailed explanation
```

---

## 6. SCD Type 2 Deep Dive

### What is SCD Type 2?

**Slowly Changing Dimension Type 2** preserves full historical changes by creating a new row for each change.

```
┌─────────────────────────────────────────────────────────────────┐
│                    SCD TYPE 2 CONCEPT                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Customer "John Smith" changes phone number:                    │
│                                                                  │
│  BEFORE:                                                         │
│  ┌─────┬──────────────┬─────────────┬────────────┬────────┐    │
│  │ Key │ Customer Code│ Name        │ Phone      │ Active │    │
│  ├─────┼──────────────┼─────────────┼────────────┼────────┤    │
│  │ 100 │ C001         │ John Smith  │ 012-345-678│ Yes    │    │
│  └─────┴──────────────┴─────────────┴────────────┴────────┘    │
│                                                                  │
│  AFTER:                                                          │
│  ┌─────┬──────────────┬─────────────┬────────────┬────────┬─────────────────┬─────────────────┬──────────┐
│  │ Key │ Customer Code│ Name        │ Phone      │ Active │ Valid From      │ Valid To        │ Current  │
│  ├─────┼──────────────┼─────────────┼────────────┼────────┼─────────────────┼─────────────────┼──────────┤
│  │ 100 │ C001         │ John Smith  │ 012-345-678│ Yes    │ 2024-01-01      │ 2024-06-14      │ No       │
│  │ 200 │ C001         │ John Smith  │ 012-999-888│ Yes    │ 2024-06-15      │ 9999-12-31      │ Yes      │
│  └─────┴──────────────┴─────────────┴────────────┴────────┴─────────────────┴─────────────────┴──────────┘
│                                                                  │
│  Key Points:                                                     │
│  • Old record is NOT deleted, just marked as "not current"       │
│  • New record gets new surrogate key (200)                       │
│  • Valid To date = Day before new record's Valid From            │
│  • is_current flag = 1 for latest version only                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### SCD Type 2 Implementation

#### Step 1: Create Dimension Table with SCD Columns

```sql
CREATE TABLE dw.dim_customer (
    -- Surrogate Key (auto-generated)
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Natural Key (from source)
    customer_code VARCHAR(20) NOT NULL,
    
    -- Descriptive Attributes
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    email VARCHAR(255),
    phone_primary VARCHAR(20),
    customer_segment VARCHAR(50),
    risk_rating VARCHAR(20),
    is_active BIT,
    
    -- SCD Type 2 Columns (Critical!)
    effective_date DATE NOT NULL,        -- When this version became valid
    expiry_date DATE NOT NULL,           -- When this version expired
    is_current BIT NOT NULL,             -- 1 = current version, 0 = historical
    
    -- Audit Columns
    source_system VARCHAR(50),
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    -- Indexes for performance
    CONSTRAINT UQ_dim_customer_code_current 
        UNIQUE (customer_code, is_current)
);

-- Index for fast lookups
CREATE INDEX IX_dim_customer_code ON dw.dim_customer(customer_code);
CREATE INDEX IX_dim_customer_current ON dw.dim_customer(is_current);
```

#### Step 2: SCD Type 2 Load Procedure

```sql
CREATE OR ALTER PROCEDURE dw.usp_LoadDimCustomer
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @NewCount BIGINT = 0;
    DECLARE @UpdateCount BIGINT = 0;
    DECLARE @TotalCount BIGINT = 0;
    
    PRINT 'Loading Customer Dimension (SCD Type 2)...';
    
    --------------------------------------------------------
    -- PHASE 1: INSERT NEW CUSTOMERS (Never seen before)
    --------------------------------------------------------
    INSERT INTO dw.dim_customer (
        customer_code, customer_type, first_name, last_name,
        email, phone_primary, customer_segment, risk_rating,
        is_active, effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT
        s.customer_code,
        s.customer_type,
        s.first_name,
        s.last_name,
        s.email,
        s.phone_primary,
        s.customer_segment,
        s.risk_rating,
        s.is_active,
        CAST(GETDATE() AS DATE),        -- effective_date = today
        '9999-12-31',                    -- expiry_date = far future
        1,                               -- is_current = yes
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_customers s
    WHERE NOT EXISTS (
        -- Only insert if customer doesn't exist at all
        SELECT 1 FROM dw.dim_customer d
        WHERE d.customer_code = s.customer_code
    );
    
    SET @NewCount = @@ROWCOUNT;
    PRINT 'Inserted ' + CAST(@NewCount AS VARCHAR(10)) + ' new customers.';
    
    --------------------------------------------------------
    -- PHASE 2: EXPIRE CHANGED CUSTOMERS
    --------------------------------------------------------
    UPDATE d
    SET
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),  -- Yesterday
        d.is_current = 0,                                            -- No longer current
        d.modified_date = GETDATE()
    FROM dw.dim_customer d
    JOIN sathapana_staging.staging.stg_customers s
        ON d.customer_code = s.customer_code
    WHERE d.is_current = 1  -- Only update current records
    AND (
        -- Check if any tracked attribute has changed
        ISNULL(d.first_name, '') != ISNULL(s.first_name, '')
        OR ISNULL(d.last_name, '') != ISNULL(s.last_name, '')
        OR ISNULL(d.email, '') != ISNULL(s.email, '')
        OR ISNULL(d.phone_primary, '') != ISNULL(s.phone_primary, '')
        OR ISNULL(d.customer_segment, '') != ISNULL(s.customer_segment, '')
        OR ISNULL(d.risk_rating, '') != ISNULL(s.risk_rating, '')
        OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
    );
    
    SET @UpdateCount = @@ROWCOUNT;
    PRINT 'Expired ' + CAST(@UpdateCount AS VARCHAR(10)) + ' changed customers.';
    
    --------------------------------------------------------
    -- PHASE 3: INSERT NEW VERSIONS OF CHANGED CUSTOMERS
    --------------------------------------------------------
    INSERT INTO dw.dim_customer (
        customer_code, customer_type, first_name, last_name,
        email, phone_primary, customer_segment, risk_rating,
        is_active, effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT
        s.customer_code,
        s.customer_type,
        s.first_name,
        s.last_name,
        s.email,
        s.phone_primary,
        s.customer_segment,
        s.risk_rating,
        s.is_active,
        CAST(GETDATE() AS DATE),        -- effective_date = today
        '9999-12-31',                    -- expiry_date = far future
        1,                               -- is_current = yes (new version)
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_customers s
    WHERE EXISTS (
        -- Find customers that were just expired in Phase 2
        SELECT 1 FROM dw.dim_customer d
        WHERE d.customer_code = s.customer_code
        AND d.is_current = 0
        AND d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    );
    
    SET @TotalCount = @NewCount + @UpdateCount + @@ROWCOUNT;
    
    --------------------------------------------------------
    -- PHASE 4: LOG THE OPERATION
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Load_DimCustomer', 'dim_customer', 'LOAD',
        @TotalCount, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT 'Loaded ' + CAST(@NewCount AS VARCHAR(10)) + ' new, ' 
        + CAST(@UpdateCount AS VARCHAR(10)) + ' updated customer records.';
END;
```

### SCD Type 2 Querying Patterns

#### Find Current Version

```sql
-- Get current version of all customers
SELECT *
FROM dw.dim_customer
WHERE is_current = 1;

-- Get current version of specific customer
SELECT *
FROM dw.dim_customer
WHERE customer_code = 'C001'
AND is_current = 1;
```

#### Find Historical Version at Specific Date

```sql
-- What did customer C001 look like on 2024-03-15?
SELECT *
FROM dw.dim_customer
WHERE customer_code = 'C001'
AND effective_date <= '2024-03-15'
AND expiry_date >= '2024-03-15';
```

#### Find All Changes Over Time

```sql
-- Full history of customer C001
SELECT 
    customer_key,
    first_name,
    phone_primary,
    customer_segment,
    effective_date,
    expiry_date,
    is_current
FROM dw.dim_customer
WHERE customer_code = 'C001'
ORDER BY effective_date;
```

#### Join Fact with Dimension History

```sql
-- Transactions with customer info at time of transaction
SELECT
    t.transaction_code,
    t.amount,
    t.transaction_date,
    c.first_name,
    c.customer_segment,
    c.risk_rating
FROM dw.fact_transactions t
JOIN dw.dim_customer c
    ON t.customer_key = c.customer_key
-- This works because fact stores the surrogate key
-- at the time of the transaction!
```

### SCD Type 2 Decision Guide

| Scenario | Use SCD Type 2? | Why |
|----------|-----------------|-----|
| Customer changes address | ✅ Yes | Need to analyze by location at time of transaction |
| Customer changes phone | ⚠️ Maybe | Usually not analytically relevant |
| Customer changes risk rating | ✅ Yes | Critical for risk analysis |
| Product name changes | ❌ No | Use SCD Type 1 |
| Branch region reorganization | ✅ Yes | Need historical regional analysis |
| Employee department transfer | ✅ Yes | Need historical org structure |

---

## 7. Incremental Load Patterns

### Pattern 1: High-Water Mark (Date-Based)

```sql
-- Track the maximum date processed
-- Only extract records newer than this date

-- Control table
CREATE TABLE staging.etl_control (
    source_table VARCHAR(100) PRIMARY KEY,
    last_extract_date DATETIME,
    last_extract_key BIGINT,
    row_count BIGINT,
    status VARCHAR(20)
);

-- Extraction procedure
CREATE OR ALTER PROCEDURE staging.usp_ExtractIncremental
    @SourceTable VARCHAR(100),
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @LastExtractDate DATETIME;
    
    -- Get high-water mark
    SELECT @LastExtractDate = last_extract_date
    FROM staging.etl_control
    WHERE source_table = @SourceTable;
    
    IF @LastExtractDate IS NULL
        SET @LastExtractDate = '1900-01-01';
    
    -- Dynamic SQL for flexibility (or use specific procedure)
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = N'
        INSERT INTO staging.stg_' + @SourceTable + '
        SELECT *
        FROM sathapana_source.oltp.' + @SourceTable + '
        WHERE created_date > @LastDate
           OR modified_date > @LastDate';
    
    EXEC sp_executesql @SQL, N'@LastDate DATETIME', @LastExtractDate;
    
    -- Update high-water mark
    UPDATE staging.etl_control
    SET last_extract_date = GETDATE(),
        status = 'EXTRACTED'
    WHERE source_table = @SourceTable;
END;
```

### Pattern 2: Identity/Auto-Increment Based

```sql
-- Track the maximum ID processed
-- Only extract records with ID > last processed ID

CREATE OR ALTER PROCEDURE staging.usp_ExtractByIdentity
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @LastKey BIGINT;
    
    -- Get last processed key
    SELECT @LastKey = last_extract_key
    FROM staging.etl_control
    WHERE source_table = 'transactions';
    
    IF @LastKey IS NULL
        SET @LastKey = 0;
    
    -- Extract only new records (by ID)
    INSERT INTO staging.stg_transactions (...)
    SELECT ...
    FROM sathapana_source.oltp.transactions
    WHERE transaction_id > @LastKey;
    
    -- Update control
    UPDATE staging.etl_control
    SET last_extract_key = (
        SELECT MAX(transaction_id) 
        FROM sathapana_source.oltp.transactions
    ),
    last_extract_date = GETDATE()
    WHERE source_table = 'transactions';
END;
```

### Pattern 3: Timestamp + Soft Delete Detection

```sql
-- Handle both updates AND soft deletes

CREATE OR ALTER PROCEDURE staging.usp_ExtractWithDeletes
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @LastExtractDate DATETIME;
    
    SELECT @LastExtractDate = last_extract_date
    FROM staging.etl_control
    WHERE source_table = 'customers';
    
    IF @LastExtractDate IS NULL
        SET @LastExtractDate = '1900-01-01';
    
    -- Extract new/updated records
    INSERT INTO staging.stg_customers (
        customer_code, first_name, last_name, is_active,
        is_deleted, source_key, batch_id
    )
    SELECT
        c.customer_code,
        c.first_name,
        c.last_name,
        c.is_active,
        0 AS is_deleted,  -- Not deleted
        CAST(c.customer_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.customers c
    WHERE c.modified_date > @LastExtractDate;
    
    -- Also extract soft-deleted records
    INSERT INTO staging.stg_customers (
        customer_code, first_name, last_name, is_active,
        is_deleted, source_key, batch_id
    )
    SELECT
        c.customer_code,
        c.first_name,
        c.last_name,
        0,  -- Mark as inactive
        1,  -- is_deleted = yes
        CAST(c.customer_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.customers c
    WHERE c.is_active = 0
    AND c.modified_date > @LastExtractDate;
    
    -- Update control
    UPDATE staging.etl_control
    SET last_extract_date = GETDATE()
    WHERE source_table = 'customers';
END;
```

### Pattern 4: Batch Processing (Chunked)

```sql
-- Process large tables in manageable chunks

CREATE OR ALTER PROCEDURE staging.usp_ExtractBatched
    @BatchID UNIQUEIDENTIFIER,
    @BatchSize INT = 10000
AS
BEGIN
    DECLARE @LastKey BIGINT = 0;
    DECLARE @RowsInserted INT = 1;
    
    WHILE @RowsInserted > 0
    BEGIN
        INSERT INTO staging.stg_transactions (...)
        SELECT TOP (@BatchSize) ...
        FROM sathapana_source.oltp.transactions
        WHERE transaction_id > @LastKey
        ORDER BY transaction_id;
        
        SET @RowsInserted = @@ROWCOUNT;
        
        -- Update high-water mark for next batch
        SELECT @LastKey = MAX(transaction_id)
        FROM staging.stg_transactions;
        
        PRINT 'Processed batch. Rows: ' + CAST(@RowsInserted AS VARCHAR(10));
    END;
END;
```

### Incremental Load Decision Matrix

| Scenario | Recommended Pattern | Notes |
|----------|---------------------|-------|
| Table with `created_date` | High-Water Mark (Date) | Simple and reliable |
| Table with auto-increment ID | Identity-Based | Very efficient |
| Table with soft deletes | Timestamp + Soft Delete | Captures all changes |
| Very large tables (>10M rows) | Batch Processing | Prevents transaction log bloat |
| Real-time requirements | CDC (Change Data Capture) | Requires DB support |

---

## 8. Error Handling Best Practices

### Error Handling Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ERROR HANDLING FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │ TRY BLOCK   │  Execute ETL operation                        │
│  │             │                                                │
│  │  • Extract  │                                                │
│  │  • Transform│                                                │
│  │  • Load     │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│         │ Success                                                │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ LOG SUCCESS │  Record in audit.etl_log                      │
│  │             │  status = 'COMPLETED'                          │
│  └─────────────┘                                                │
│                                                                  │
│  ┌──────┬──────┐                                                │
│  │      │      │  Error                                        │
│  │      ▼      │                                                │
│  │ CATCH BLOCK │                                                │
│  │             │                                                │
│  │  • Log error│  Record in audit.etl_error_log                │
│  │  • Rollback │  Undo partial changes                         │
│  │  • Alert    │  Notify DWH operator                          │
│  │  • Rethrow  │  Propagate error                              │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Error Logging Tables

```sql
-- ETL Error Log Table
CREATE TABLE audit.etl_error_log (
    error_id INT IDENTITY(1,1) PRIMARY KEY,
    batch_id UNIQUEIDENTIFIER NOT NULL,
    step_name VARCHAR(100),
    table_name VARCHAR(100),
    error_type VARCHAR(50),      -- SYSTEM_ERROR, DATA_ERROR, VALIDATION_ERROR
    error_message NVARCHAR(MAX),
    error_number INT,
    error_severity INT,
    error_state INT,
    error_line INT,
    error_procedure VARCHAR(100),
    severity VARCHAR(20),        -- CRITICAL, HIGH, MEDIUM, LOW
    created_date DATETIME DEFAULT GETDATE(),
    
    -- For analysis
    source_system VARCHAR(50),
    source_table VARCHAR(100),
    records_processed BIGINT,
    records_failed BIGINT
);

-- ETL Execution Log Table
CREATE TABLE audit.etl_log (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    batch_id UNIQUEIDENTIFIER NOT NULL,
    step_name VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    operation VARCHAR(50),       -- EXTRACT, TRANSFORM, LOAD
    records_affected BIGINT,
    status VARCHAR(20),          -- RUNNING, COMPLETED, FAILED
    start_time DATETIME,
    end_time DATETIME,
    duration_seconds AS DATEDIFF(SECOND, start_time, end_time),
    created_date DATETIME DEFAULT GETDATE()
);
```

### Comprehensive Error Handling Example

```sql
CREATE OR ALTER PROCEDURE staging.usp_ExtractWithFullErrorHandling
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- Automatic rollback on error
    
    -- Generate batch ID if not provided
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @StepName VARCHAR(100) = 'Extract_Customers';
    DECLARE @RecordCount BIGINT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorNumber INT;
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
    DECLARE @ErrorLine INT;
    
    --------------------------------------------------------
    -- LOG BATCH START
    --------------------------------------------------------
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        status, start_time
    )
    VALUES (
        @BatchID, @StepName, 'stg_customers', 'EXTRACT',
        'RUNNING', @StartTime
    );
    
    BEGIN TRY
        --------------------------------------------------------
        -- VALIDATION: Check source table exists and has data
        --------------------------------------------------------
        IF NOT EXISTS (
            SELECT 1 FROM sathapana_source.INFORMATION_SCHEMA.TABLES
            WHERE TABLE_NAME = 'customers'
        )
        BEGIN
            RAISERROR('Source table customers does not exist', 16, 1);
        END
        
        DECLARE @SourceCount BIGINT;
        SELECT @SourceCount = COUNT(*)
        FROM sathapana_source.oltp.customers;
        
        IF @SourceCount = 0
        BEGIN
            PRINT 'Warning: Source table is empty';
            -- Log warning but continue
            INSERT INTO audit.etl_error_log (
                batch_id, step_name, error_type, error_message, severity
            )
            VALUES (
                @BatchID, @StepName, 'WARNING', 
                'Source table customers is empty', 'LOW'
            );
        END
        
        --------------------------------------------------------
        -- EXTRACTION
        --------------------------------------------------------
        BEGIN TRANSACTION;
        
        -- Truncate staging
        TRUNCATE TABLE staging.stg_customers;
        
        -- Extract with row count verification
        INSERT INTO staging.stg_customers (
            customer_code, first_name, last_name, email,
            phone_primary, is_active, source_key, batch_id
        )
        SELECT
            c.customer_code,
            c.first_name,
            c.last_name,
            c.email,
            c.phone_primary,
            c.is_active,
            CAST(c.customer_id AS VARCHAR(50)),
            @BatchID
        FROM sathapana_source.oltp.customers c;
        
        SET @RecordCount = @@ROWCOUNT;
        
        --------------------------------------------------------
        -- VALIDATION: Row count reconciliation
        --------------------------------------------------------
        IF @RecordCount != @SourceCount
        BEGIN
            DECLARE @DiffMsg NVARCHAR(500) = 
                'Row count mismatch. Source: ' + CAST(@SourceCount AS VARCHAR(20)) +
                ', Staging: ' + CAST(@RecordCount AS VARCHAR(20));
            
            RAISERROR(@DiffMsg, 16, 1);
        END
        
        --------------------------------------------------------
        -- VALIDATION: Check for NULLs in required fields
        --------------------------------------------------------
        DECLARE @NullCount BIGINT;
        SELECT @NullCount = COUNT(*)
        FROM staging.stg_customers
        WHERE customer_code IS NULL
           OR first_name IS NULL;
        
        IF @NullCount > 0
        BEGIN
            DECLARE @NullMsg NVARCHAR(500) = 
                'Found ' + CAST(@NullCount AS VARCHAR(10)) + 
                ' records with NULL values in required fields';
            
            RAISERROR(@NullMsg, 16, 1);
        END
        
        --------------------------------------------------------
        -- VALIDATION: Check for duplicates
        --------------------------------------------------------
        DECLARE @DupCount BIGINT;
        SELECT @DupCount = COUNT(*)
        FROM (
            SELECT customer_code, COUNT(*) AS cnt
            FROM staging.stg_customers
            GROUP BY customer_code
            HAVING COUNT(*) > 1
        ) d;
        
        IF @DupCount > 0
        BEGIN
            DECLARE @DupMsg NVARCHAR(500) = 
                'Found ' + CAST(@DupCount AS VARCHAR(10)) + 
                ' duplicate customer codes';
            
            RAISERROR(@DupMsg, 16, 1);
        END
        
        COMMIT TRANSACTION;
        
        --------------------------------------------------------
        -- LOG SUCCESS
        --------------------------------------------------------
        UPDATE audit.etl_log
        SET 
            records_affected = @RecordCount,
            status = 'COMPLETED',
            end_time = GETDATE()
        WHERE batch_id = @BatchID
        AND step_name = @StepName
        AND status = 'RUNNING';
        
        PRINT 'Successfully extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' customers.';
        
    END TRY
    BEGIN CATCH
        --------------------------------------------------------
        -- ROLLBACK on error
        --------------------------------------------------------
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        --------------------------------------------------------
        -- CAPTURE error details
        --------------------------------------------------------
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorNumber = ERROR_NUMBER(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE(),
            @ErrorLine = ERROR_LINE();
        
        --------------------------------------------------------
        -- LOG ERROR
        --------------------------------------------------------
        INSERT INTO audit.etl_error_log (
            batch_id, step_name, table_name, error_type,
            error_message, error_number, error_severity,
            error_state, error_line, severity
        )
        VALUES (
            @BatchID, @StepName, 'stg_customers', 'SYSTEM_ERROR',
            @ErrorMessage, @ErrorNumber, @ErrorSeverity,
            @ErrorState, @ErrorLine,
            CASE 
                WHEN @ErrorSeverity >= 16 THEN 'CRITICAL'
                WHEN @ErrorSeverity >= 11 THEN 'HIGH'
                ELSE 'MEDIUM'
            END
        );
        
        --------------------------------------------------------
        -- UPDATE ETL LOG
        --------------------------------------------------------
        UPDATE audit.etl_log
        SET 
            status = 'FAILED',
            end_time = GETDATE()
        WHERE batch_id = @BatchID
        AND step_name = @StepName
        AND status = 'RUNNING';
        
        --------------------------------------------------------
        -- RE-THROW error (or handle gracefully)
        --------------------------------------------------------
        THROW;
    END CATCH
END;
```

### Error Handling Patterns

#### Pattern 1: Continue on Error (Best for batch processing)

```sql
CREATE OR ALTER PROCEDURE staging.usp_ExtractAll_ContinueOnError
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @StepResults TABLE (
        step_name VARCHAR(100),
        status VARCHAR(20),
        error_message NVARCHAR(MAX)
    );
    
    -- Try each extraction, capture results
    BEGIN TRY
        EXEC staging.usp_ExtractBranches @BatchID;
        INSERT INTO @StepResults VALUES ('Branches', 'SUCCESS', NULL);
    END TRY
    BEGIN CATCH
        INSERT INTO @StepResults VALUES ('Branches', 'FAILED', ERROR_MESSAGE());
    END CATCH
    
    BEGIN TRY
        EXEC staging.usp_ExtractCustomers @BatchID;
        INSERT INTO @StepResults VALUES ('Customers', 'SUCCESS', NULL);
    END TRY
    BEGIN CATCH
        INSERT INTO @StepResults VALUES ('Customers', 'FAILED', ERROR_MESSAGE());
    END CATCH
    
    -- Continue with other extractions...
    
    -- Report results
    SELECT * FROM @StepResults;
    
    -- Fail if any critical step failed
    IF EXISTS (SELECT 1 FROM @StepResults WHERE status = 'FAILED')
    BEGIN
        PRINT 'WARNING: Some extraction steps failed. Check error log.';
    END
END;
```

#### Pattern 2: Retry Logic

```sql
CREATE OR ALTER PROCEDURE staging.usp_ExtractWithRetry
    @BatchID UNIQUEIDENTIFIER,
    @MaxRetries INT = 3
AS
BEGIN
    DECLARE @RetryCount INT = 0;
    DECLARE @Success BIT = 0;
    
    WHILE @RetryCount < @MaxRetries AND @Success = 0
    BEGIN
        BEGIN TRY
            EXEC staging.usp_ExtractCustomers @BatchID;
            SET @Success = 1;
        END TRY
        BEGIN CATCH
            SET @RetryCount += 1;
            
            IF @RetryCount < @MaxRetries
            BEGIN
                PRINT 'Attempt ' + CAST(@RetryCount AS VARCHAR(10)) + 
                      ' failed. Retrying in 5 seconds...';
                WAITFOR DELAY '00:00:05';  -- Wait 5 seconds
            END
            ELSE
            BEGIN
                PRINT 'All ' + CAST(@MaxRetries AS VARCHAR(10)) + 
                      ' attempts failed.';
                THROW;
            END
        END CATCH
    END
END;
```

---

## 9. Performance Optimization

### Optimization Strategies

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERFORMANCE OPTIMIZATION                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 1. INDEX MANAGEMENT                                     │    │
│  │    • Drop non-clustered indexes during bulk load        │    │
│  │    • Rebuild indexes after load                         │    │
│  │    • Update statistics                                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 2. BATCH PROCESSING                                     │    │
│  │    • Process records in configurable batch sizes        │    │
│  │    • Prevent transaction log bloat                      │    │
│  │    • Allow for incremental progress                     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 3. INCREMENTAL LOADS                                    │    │
│  │    • Only process new/changed records                   │    │
│  │    • Reduce source system load                          │    │
│  │    • Faster execution times                             │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ 4. PARALLEL PROCESSING                                  │    │
│  │    • Independent dimensions in parallel                 │    │
│  │    • Fact tables after dimensions complete              │    │
│  │    • Use SQL Server Agent job steps                     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Index Management During ETL

```sql
-- ============================================================
-- BEFORE LOAD: Drop non-clustered indexes for faster inserts
-- ============================================================
CREATE OR ALTER PROCEDURE dw.usp_DropIndexesForLoad
    @TableName VARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Drop non-clustered indexes (keep clustered)
    DECLARE index_cursor CURSOR FOR
        SELECT 'DROP INDEX ' + i.name + ' ON dw.' + @TableName
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic
            ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.object_id = OBJECT_ID('dw.' + @TableName)
        AND i.type_desc = 'NONCLUSTERED'
        AND i.is_primary_key = 0;
    
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @SQL;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_executesql @SQL;
        FETCH NEXT FROM index_cursor INTO @SQL;
    END
    
    CLOSE index_cursor;
    DEALLOCATE index_cursor;
    
    PRINT 'Dropped indexes for ' + @TableName;
END;

-- ============================================================
-- AFTER LOAD: Recreate indexes and update statistics
-- ============================================================
CREATE OR ALTER PROCEDURE dw.usp_RebuildIndexesForLoad
    @TableName VARCHAR(100)
AS
BEGIN
    -- Rebuild all indexes
    EXEC sp_REBUILD @objname = 'dw.' + @TableName;
    
    -- Update statistics
    EXEC sp_updatestats;
    
    PRINT 'Rebuilt indexes and updated statistics for ' + @TableName;
END;
```

### Batch Processing Implementation

```sql
CREATE OR ALTER PROCEDURE dw.usp_LoadFactTransactionsBatched
    @BatchID UNIQUEIDENTIFIER,
    @BatchSize INT = 50000
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @TotalRows BIGINT = 0;
    DECLARE @BatchRows BIGINT = 1;
    DECLARE @BatchNum INT = 0;
    
    PRINT 'Loading Transaction Facts in batches of ' + CAST(@BatchSize AS VARCHAR(10));
    
    WHILE @BatchRows > 0
    BEGIN
        SET @BatchNum += 1;
        
        BEGIN TRANSACTION;
        
        INSERT INTO dw.fact_transactions (
            transaction_code, account_key, customer_key,
            amount, currency, transaction_date_key, ...
        )
        SELECT TOP (@BatchSize)
            s.transaction_code,
            a.account_key,
            c.customer_key,
            s.amount,
            s.currency,
            CAST(FORMAT(s.transaction_date, 'yyyyMMdd') AS INT),
            ...
        FROM sathapana_staging.staging.stg_transactions s
        JOIN dw.dim_account a ON s.account_number = a.account_number AND a.is_current = 1
        JOIN dw.dim_customer c ON s.customer_code = c.customer_code AND c.is_current = 1
        WHERE NOT EXISTS (
            SELECT 1 FROM dw.fact_transactions d
            WHERE d.transaction_code = s.transaction_code
        )
        ORDER BY s.transaction_code;  -- Consistent ordering
        
        SET @BatchRows = @@ROWCOUNT;
        SET @TotalRows += @BatchRows;
        
        COMMIT TRANSACTION;
        
        PRINT 'Batch ' + CAST(@BatchNum AS VARCHAR(10)) + 
              ': Processed ' + CAST(@BatchRows AS VARCHAR(10)) + 
              ' rows. Total: ' + CAST(@TotalRows AS VARCHAR(10));
    END
    
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Load_FactTransactions', 'fact_transactions', 'LOAD',
        @TotalRows, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT 'Transaction fact load completed. Total rows: ' + CAST(@TotalRows AS VARCHAR(10));
END;
```

### Parallel Processing Example

```sql
-- SQL Server Agent Job Configuration
-- Step 1: Load Dimensions (can run in parallel where no dependencies)

-- Job Step: Load DimBranch (No dependencies)
EXEC dw.usp_LoadDimBranch @BatchID;

-- Job Step: Load DimProduct (No dependencies)
EXEC dw.usp_LoadDimProduct @BatchID;

-- Job Step: Load DimCustomer (No dependencies)
EXEC dw.usp_LoadDimCustomer @BatchID;

-- These three can run in PARALLEL!

-- Then wait for all dimension steps to complete...

-- Step 2: Load Fact Tables (must wait for dimensions)

-- Job Step: Load FactTransactions (Depends on all dimensions)
EXEC dw.usp_LoadFactTransactions @BatchID;
```

### Performance Monitoring Query

```sql
-- Monitor ETL performance
SELECT 
    step_name,
    table_name,
    operation,
    records_affected,
    status,
    start_time,
    end_time,
    DATEDIFF(SECOND, start_time, end_time) AS duration_seconds,
    CASE 
        WHEN records_affected > 0 
        THEN DATEDIFF(SECOND, start_time, end_time) * 1.0 / records_affected
        ELSE 0
    END AS seconds_per_record
FROM audit.etl_log
WHERE batch_id = @BatchID
ORDER BY start_time;

-- Find slowest steps
SELECT TOP 10
    step_name,
    AVG(DATEDIFF(SECOND, start_time, end_time)) AS avg_duration_seconds,
    SUM(records_affected) AS total_records
FROM audit.etl_log
WHERE operation = 'LOAD'
AND start_time >= DATEADD(DAY, -7, GETDATE())
GROUP BY step_name
ORDER BY avg_duration_seconds DESC;
```

---

## 10. Hands-On Examples

### Complete ETL Exercise

```sql
-- ============================================================
-- EXERCISE: Build a mini ETL pipeline for a simple table
-- ============================================================

-- STEP 1: Create source table (simulating OLTP)
CREATE TABLE source_db.dbo.products (
    product_id INT IDENTITY(1,1) PRIMARY KEY,
    product_code VARCHAR(20),
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2),
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE()
);

-- STEP 2: Create staging table
CREATE TABLE staging_db.dbo.stg_products (
    product_code VARCHAR(20),
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2),
    is_active BIT,
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER
);

-- STEP 3: Create dimension table with SCD Type 2
CREATE TABLE dw_db.dbo.dim_product (
    product_key INT IDENTITY(1,1) PRIMARY KEY,
    product_code VARCHAR(20),
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2),
    is_active BIT,
    effective_date DATE,
    expiry_date DATE,
    is_current BIT,
    batch_id UNIQUEIDENTIFIER
);

-- STEP 4: Create ETL control table
CREATE TABLE staging_db.dbo.etl_control (
    source_table VARCHAR(100) PRIMARY KEY,
    last_extract_date DATETIME,
    last_extract_key BIGINT
);

-- STEP 5: Create extraction procedure
CREATE PROCEDURE staging_db.dbo.usp_ExtractProducts
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @LastDate DATETIME;
    
    SELECT @LastDate = last_extract_date
    FROM staging_db.dbo.etl_control
    WHERE source_table = 'products';
    
    IF @LastDate IS NULL
        SET @LastDate = '1900-01-01';
    
    TRUNCATE TABLE staging_db.dbo.stg_products;
    
    INSERT INTO staging_db.dbo.stg_products
    SELECT 
        product_code, product_name, category, price, is_active,
        CAST(product_id AS VARCHAR(50)),
        @BatchID
    FROM source_db.dbo.products
    WHERE modified_date > @LastDate;
    
    UPDATE staging_db.dbo.etl_control
    SET last_extract_date = GETDATE()
    WHERE source_table = 'products';
END;

-- STEP 6: Create load procedure with SCD Type 2
CREATE PROCEDURE dw_db.dbo.usp_LoadDimProduct
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    -- Insert new products
    INSERT INTO dw_db.dbo.dim_product
    SELECT 
        product_code, product_name, category, price, is_active,
        GETDATE(), '9999-12-31', 1, @BatchID
    FROM staging_db.dbo.stg_products s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw_db.dbo.dim_product d
        WHERE d.product_code = s.product_code AND d.is_current = 1
    );
    
    -- Expire changed products
    UPDATE d
    SET expiry_date = DATEADD(DAY, -1, GETDATE()),
        is_current = 0
    FROM dw_db.dbo.dim_product d
    JOIN staging_db.dbo.stg_products s ON d.product_code = s.product_code
    WHERE d.is_current = 1
    AND (
        d.product_name != s.product_name
        OR d.category != s.category
        OR d.price != s.price
    );
    
    -- Insert new versions
    INSERT INTO dw_db.dbo.dim_product
    SELECT 
        s.product_code, s.product_name, s.category, s.price, s.is_active,
        GETDATE(), '9999-12-31', 1, @BatchID
    FROM staging_db.dbo.stg_products s
    WHERE EXISTS (
        SELECT 1 FROM dw_db.dbo.dim_product d
        WHERE d.product_code = s.product_code AND d.is_current = 0
    );
END;

-- STEP 7: Execute the ETL
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC staging_db.dbo.usp_ExtractProducts @BatchID;
EXEC dw_db.dbo.usp_LoadDimProduct @BatchID;

-- STEP 8: Verify results
-- Check current version
SELECT * FROM dw_db.dbo.dim_product WHERE is_current = 1;

-- Check history
SELECT * FROM dw_db.dbo.dim_product ORDER BY product_code, effective_date;
```

---

## Summary

| Topic | Key Takeaway |
|-------|--------------|
| **ETL Overview** | Extract, Transform, Load is the foundation of data warehousing |
| **Pipeline Architecture** | Follow a clear sequence: Source → Staging → DW → Marts |
| **Extract Phase** | Choose Full vs Incremental based on data size and change rate |
| **Transform Phase** | Cleanse, validate, and reshape data for analysis |
| **Load Phase** | Load Dimensions first, then Facts |
| **SCD Type 2** | Preserve history with effective/expiry dates and is_current flag |
| **Incremental Loads** | Track high-water marks to only process changed data |
| **Error Handling** | Use TRY/CATCH, log errors, and implement retry logic |
| **Performance** | Manage indexes, use batch processing, and parallelize |

---

## Quick Reference

### ETL Checklist

- [ ] Source tables exist and have data
- [ ] Staging tables are created
- [ ] Dimension tables have SCD columns
- [ ] ETL control table is initialized
- [ ] Audit logging is in place
- [ ] Error handling is implemented
- [ ] Batch ID is tracked end-to-end
- [ ] Row count reconciliation is performed
- [ ] Indexes are managed during loads
- [ ] Statistics are updated after loads

---

*Last Updated: September 2024*
*Based on Sathapana Bank Data Engineering Project*
