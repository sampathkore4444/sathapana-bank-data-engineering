# 🔄 Change Data Capture (CDC) vs Incremental Loads

## Table of Contents
1. [Overview](#1-overview)
2. [What is Incremental Loading?](#2-what-is-incremental-loading)
3. [What is Change Data Capture (CDC)?](#3-what-is-change-data-capture-cdc)
4. [Comparison Matrix](#4-comparison-matrix)
5. [When to Use Each](#5-when-to-use-each)
6. [Implementation Examples](#6-implementation-examples)
7. [Hands-On Exercise](#7-hands-on-exercise)

---

## 1. Overview

Both **Incremental Loading** and **Change Data Capture (CDC)** are techniques to efficiently extract only changed data from source systems, but they differ significantly in approach, complexity, and capabilities.

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA EXTRACTION METHODS                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FULL EXTRACT                                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Source ──────────────────────────────────► Target       │    │
│  │ [All Data]                           [All Data]         │    │
│  │                                                         │    │
│  │ • Simple but slow                                        │    │
│  │ • High source system load                               │    │
│  │ • No change detection                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  INCREMENTAL LOAD                                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Source ──────────────► [Only New/Changed] ► Target     │    │
│  │ [All Data]                                   [Delta]    │    │
│  │                                                         │    │
│  │ • Faster, lower load                                    │    │
│  │ • Uses timestamps or keys                               │    │
│  │ • May miss deletes                                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  CHANGE DATA CAPTURE (CDC)                                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ Source ──► [Transaction Log] ──► [INSERT/UPDATE/DELETE] │    │
│  │ [All Data]    [CDC]              [Complete Change Set]  │    │
│  │                                                         │    │
│  │ • Real-time change detection                            │    │
│  │ • Captures ALL changes (including deletes)              │    │
│  │ • Low source system impact                              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. What is Incremental Loading?

### Definition

Incremental loading is an ETL technique that extracts only **new or modified records** since the last extraction, rather than extracting the entire dataset each time.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    INCREMENTAL LOAD FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │ Step 1      │  Get the "High-Water Mark"                    │
│  │             │  (Last processed timestamp or key)             │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Step 2      │  Query source for records WHERE               │
│  │             │  timestamp > last_extract_date                 │
│  │             │  OR id > last_extract_key                      │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Step 3      │  Extract only matching records                │
│  │             │  (New + Modified)                              │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Step 4      │  Update high-water mark                       │
│  │             │  (For next extraction)                         │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation Pattern

```sql
-- ============================================================
-- INCREMENTAL LOAD EXAMPLE
-- ============================================================

-- Control table to track last extraction point
CREATE TABLE etl_control (
    source_table VARCHAR(100) PRIMARY KEY,
    last_extract_date DATETIME,
    last_extract_key BIGINT,
    row_count BIGINT,
    status VARCHAR(20)
);

-- Incremental extraction procedure
CREATE PROCEDURE usp_ExtractIncremental
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @LastExtractDate DATETIME;
    DECLARE @LastExtractKey BIGINT;
    
    -- Step 1: Get high-water mark
    SELECT 
        @LastExtractDate = last_extract_date,
        @LastExtractKey = last_extract_key
    FROM etl_control
    WHERE source_table = 'transactions';
    
    IF @LastExtractDate IS NULL
        SET @LastExtractDate = '1900-01-01';
    
    -- Step 2: Extract only new/changed records
    INSERT INTO staging.stg_transactions (...)
    SELECT ...
    FROM source.transactions
    WHERE created_date > @LastExtractDate
       OR modified_date > @LastExtractDate;
    
    -- Step 3: Update high-water mark
    UPDATE etl_control
    SET 
        last_extract_date = GETDATE(),
        last_extract_key = (SELECT MAX(id) FROM source.transactions),
        row_count = @@ROWCOUNT
    WHERE source_table = 'transactions';
END;
```

### Incremental Load Strategies

| Strategy | How It Works | Pros | Cons |
|----------|--------------|------|------|
| **Timestamp-Based** | Track `created_date` / `modified_date` | Simple, widely supported | Misses deletes, depends on source timestamps |
| **Key-Based (Identity)** | Track max `id` processed | Very efficient, reliable | Requires auto-increment column |
| **Checksum/Hash** | Compare row hash values | Detects any change | Expensive to compute |
| **Soft Delete Flag** | Check `is_deleted` column | Captures deletes | Requires source support |
| **Trigger-Based** | Source triggers log changes | Real-time, accurate | Adds source overhead |

### Limitations of Incremental Loads

```
┌─────────────────────────────────────────────────────────────────┐
│                    INCREMENTAL LOAD LIMITATIONS                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ❌ MISSED DELETES                                               │
│  ─────────────────                                               │
│  Source: DELETE FROM transactions WHERE id = 123;                │
│                                                                  │
│  If you only check created_date/modified_date, you'll           │
│  never see this deletion!                                        │
│                                                                  │
│  ❌ CLOCK SKEW ISSUES                                            │
│  ───────────────────                                             │
│  If source and ETL servers have different clocks,               │
│  you might miss records or extract duplicates.                   │
│                                                                  │
│  ❌ DEPENDS ON SOURCE SCHEMA                                     │
│  ────────────────────────────                                    │
│  Requires source tables to have timestamp or                     │
│  auto-increment columns.                                         │
│                                                                  │
│  ❌ NOT REAL-TIME                                                │
│  ───────────────                                                 │
│  Typically runs on schedule (hourly, daily),                     │
│  not truly real-time.                                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. What is Change Data Capture (CDC)?

### Definition

Change Data Capture (CDC) is a technique that captures **all changes** (INSERT, UPDATE, DELETE) made to source data by reading the **database transaction log**.

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    CDC FLOW                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │ Source DB   │  Application makes changes                    │
│  │ Transaction │  (INSERT, UPDATE, DELETE)                      │
│  │ Log         │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ CDC Reader  │  Reads transaction log                        │
│  │ Process     │  Captures change events                       │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Change      │  op: INSERT, UPDATE, DELETE                   │
│  │ Events      │  before_image, after_image                    │
│  │             │  timestamp, transaction_id                    │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ ETL Process │  Apply changes to target                      │
│  │             │  (Insert, Update, Delete)                      │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Characteristics

| Characteristic | Description |
|----------------|-------------|
| **Log-Based** | Reads database transaction log, not the tables |
| **Non-Intrusive** | Minimal impact on source system performance |
| **Complete** | Captures INSERT, UPDATE, and DELETE operations |
| **Ordered** | Changes are captured in transaction order |
| **Timestamped** | Each change has a precise timestamp |
| **Asynchronous** | Changes are captured after they commit |

### CDC Implementation (SQL Server)

```sql
-- ============================================================
-- SQL SERVER CDC SETUP
-- ============================================================

-- Step 1: Enable CDC on the database
USE master;
GO
EXEC sys.sp_cdc_enable_db;
GO

-- Step 2: Enable CDC on a specific table
USE YourDatabase;
GO
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'transactions',
    @role_name = NULL,
    @supports_net_changes = 1;
GO

-- Step 3: CDC creates change tables automatically
-- Table: cdc.dbo_transactions_CT
-- Columns: 
--   __$start_lsn (Log Sequence Number)
--   __$seqval (Sequence value within transaction)
--   __$operation (1=Delete, 2=Insert, 3=Before Update, 4=After Update)
--   __$update_mask (Bitmap of changed columns)
--   * (All original columns)

-- Step 4: Query CDC change tables
SELECT 
    __$start_lsn,
    __$operation,
    __$update_mask,
    transaction_id,
    amount,
    transaction_date
FROM cdc.dbo_transactions_CT
WHERE __$start_lsn >= sys.fn_cdc_get_min_lsn('dbo_transactions')
ORDER BY __$start_lsn;
```

### CDC Operation Codes

| Code | Operation | Description |
|------|-----------|-------------|
| 1 | DELETE | Row was deleted |
| 2 | INSERT | Row was inserted |
| 3 | UPDATE (Before) | Row before update |
| 4 | UPDATE (After) | Row after update |

### CDC Query Examples

```sql
-- ============================================================
-- CDC QUERY EXAMPLES
-- ============================================================

-- Get all changes since last extraction
DECLARE @from_lsn BINARY(10) = sys.fn_cdc_get_min_lsn('dbo_transactions');
DECLARE @to_lsn BINARY(10) = sys.fn_cdc_get_max_lsn();

SELECT 
    CASE __$operation
        WHEN 1 THEN 'DELETE'
        WHEN 2 THEN 'INSERT'
        WHEN 3 THEN 'UPDATE_BEFORE'
        WHEN 4 THEN 'UPDATE_AFTER'
    END AS change_type,
    transaction_id,
    amount,
    transaction_date
FROM cdc.dbo_transactions_CT
WHERE __$start_lsn >= @from_lsn
AND __$start_lsn <= @to_lsn;

-- Get only new inserts and updates (after image)
SELECT *
FROM cdc.dbo_transactions_CT
WHERE __$operation IN (2, 4);  -- INSERT or UPDATE_AFTER

-- Get only deletes
SELECT *
FROM cdc.dbo_transactions_CT
WHERE __$operation = 1;

-- Get changes within a specific time range
SELECT *
FROM cdc.fn_cdc_get_all_changes_dbo_transactions(
    sys.fn_cdc_get_min_lsn('dbo_transactions'),
    sys.fn_cdc_get_max_lsn(),
    'all'
);
```

---

## 4. Comparison Matrix

### Feature Comparison

| Feature | Incremental Load | CDC |
|---------|------------------|-----|
| **Change Detection** | Timestamps / Keys | Transaction Log |
| **Captures INSERTs** | ✅ Yes | ✅ Yes |
| **Captures UPDATEs** | ✅ Yes (if timestamp updated) | ✅ Yes |
| **Captures DELETEs** | ❌ No (usually) | ✅ Yes |
| **Real-Time Capability** | ❌ No (batch only) | ✅ Yes (near real-time) |
| **Source System Impact** | Medium (queries tables) | Low (reads log) |
| **Implementation Complexity** | Low | Medium-High |
| **Requires DB Support** | No (any SQL) | Yes (DB-specific) |
| **Data Latency** | Minutes to hours | Seconds to minutes |
| **Handles Late Arriving Data** | ❌ No | ✅ Yes |
| **Requires Source Schema Changes** | Sometimes | No (usually) |
| **Works with Any Source** | ✅ Yes | ❌ No (DB-specific) |

### Performance Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERFORMANCE COMPARISON                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  METRIC              INCREMENTAL         CDC                     │
│  ─────────────────────────────────────────────────               │
│                                                                  │
│  Source Load         Medium              Low                     │
│  (Impact on OLTP)                                               │
│                                                                  │
│  ETL Complexity      Low                 Medium-High             │
│                                                                  │
│  Data Latency        Hours               Seconds-Minutes         │
│                                                                  │
│  Storage             Low                 Medium                  │
│  (Change tables)                                                 │
│                                                                  │
│  Completeness        80-90%              99-100%                 │
│  (Captures all changes)                                          │
│                                                                  │
│  Cost                Free (SQL)          May need licenses       │
│                                                                  │
│  Setup Time          1-2 days            1-2 weeks               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Decision Matrix

| Scenario | Recommended | Why |
|----------|-------------|-----|
| Daily batch ETL, simple requirements | Incremental Load | Simple, fast to implement |
| Real-time analytics required | CDC | Sub-second latency needed |
| Need to capture deletes | CDC | Incremental can't see deletes |
| Source system is sensitive to load | CDC | Non-intrusive log reading |
| Limited DBA support available | Incremental Load | No special DB setup needed |
| Regulatory compliance (audit trail) | CDC | Complete change history |
| Multiple source databases | Incremental Load | Works with any SQL source |
| High-volume transaction system | CDC | Minimal performance impact |

---

## 5. When to Use Each

### Use Incremental Load When:

```
✅ Batch processing is acceptable (daily, hourly)
✅ Source tables have reliable timestamps
✅ Deletes are rare or not important
✅ Simple implementation is preferred
✅ Source system cannot be modified
✅ Working with multiple heterogeneous sources
✅ Budget for specialized tools is limited
```

**Example Use Cases:**
- Daily sales reporting
- Customer dimension updates
- Product catalog sync
- Historical data archival

### Use CDC When:

```
✅ Real-time or near real-time data is required
✅ Must capture all changes including deletes
✅ Source system is high-volume transaction database
✅ Audit trail and compliance requirements exist
✅ Data warehouse needs to be current within minutes
✅ Source database supports CDC (SQL Server, Oracle, MySQL)
✅ Minimal impact on source system is critical
```

**Example Use Cases:**
- Real-time fraud detection
- Live dashboard updates
- Financial transaction monitoring
- Regulatory reporting (SOX, Basel III)
- Operational analytics

---

## 6. Implementation Examples

### Incremental Load Implementation

```sql
-- ============================================================
-- COMPLETE INCREMENTAL LOAD IMPLEMENTATION
-- ============================================================

-- Step 1: Create control table
CREATE TABLE etl_incremental_control (
    source_table VARCHAR(100) PRIMARY KEY,
    last_extract_date DATETIME,
    last_extract_key BIGINT,
    last_lsn BINARY(10),  -- For CDC
    row_count BIGINT,
    status VARCHAR(20),
    last_run DATETIME
);

-- Step 2: Create extraction procedure
CREATE PROCEDURE usp_ExtractTransactions_Incremental
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @LastExtractDate DATETIME;
    DECLARE @LastExtractKey BIGINT;
    DECLARE @StartTime DATETIME = GETDATE();
    
    -- Get high-water mark
    SELECT 
        @LastExtractDate = last_extract_date,
        @LastExtractKey = last_extract_key
    FROM etl_incremental_control
    WHERE source_table = 'transactions';
    
    IF @LastExtractDate IS NULL
    BEGIN
        SET @LastExtractDate = '1900-01-01';
        SET @LastExtractKey = 0;
    END
    
    -- Extract new and modified records
    INSERT INTO staging.stg_transactions (
        transaction_code, account_number, amount,
        transaction_date, created_date, modified_date,
        source_key, batch_id
    )
    SELECT
        t.transaction_code,
        a.account_number,
        t.amount,
        t.transaction_date,
        t.created_date,
        t.modified_date,
        CAST(t.transaction_id AS VARCHAR(50)),
        @BatchID
    FROM source.transactions t
    JOIN source.accounts a ON t.account_id = a.account_id
    WHERE t.created_date > @LastExtractDate
       OR t.modified_date > @LastExtractDate;
    
    -- Update control table
    UPDATE etl_incremental_control
    SET 
        last_extract_date = GETDATE(),
        last_extract_key = (
            SELECT MAX(transaction_id) 
            FROM source.transactions
        ),
        row_count = @@ROWCOUNT,
        status = 'EXTRACTED',
        last_run = GETDATE()
    WHERE source_table = 'transactions';
    
    PRINT 'Incremental load completed. Rows: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
END;
```

### CDC Implementation

```sql
-- ============================================================
-- COMPLETE CDC IMPLEMENTATION (SQL Server)
-- ============================================================

-- Step 1: Enable CDC on database (run once)
USE master;
GO
EXEC sys.sp_cdc_enable_db;
GO

-- Step 2: Enable CDC on table (run once)
USE YourDatabase;
GO
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'transactions',
    @role_name = NULL,
    @supports_net_changes = 1;
GO

-- Step 3: Create CDC extraction procedure
CREATE PROCEDURE usp_ExtractTransactions_CDC
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @from_lsn BINARY(10);
    DECLARE @to_lsn BINARY(10);
    DECLARE @StartTime DATETIME = GETDATE();
    
    -- Get LSN range
    SELECT @from_lsn = last_lsn
    FROM etl_incremental_control
    WHERE source_table = 'transactions';
    
    IF @from_lsn IS NULL
        SET @from_lsn = sys.fn_cdc_get_min_lsn('dbo_transactions');
    
    SET @to_lsn = sys.fn_cdc_get_max_lsn();
    
    -- Extract changes from CDC
    INSERT INTO staging.stg_transactions (
        transaction_code, account_number, amount,
        transaction_date, change_type,
        source_key, batch_id
    )
    SELECT
        c.transaction_code,
        a.account_number,
        c.amount,
        c.transaction_date,
        CASE c.__$operation
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 3 THEN 'UPDATE_BEFORE'
            WHEN 4 THEN 'UPDATE_AFTER'
        END,
        CAST(c.transaction_id AS VARCHAR(50)),
        @BatchID
    FROM cdc.dbo_transactions_CT c
    JOIN source.accounts a ON c.account_id = a.account_id
    WHERE c.__$start_lsn > @from_lsn
    AND c.__$start_lsn <= @to_lsn
    AND c.__$operation IN (2, 4);  -- Only inserts and updates (after image)
    
    -- Update control table
    UPDATE etl_incremental_control
    SET 
        last_lsn = @to_lsn,
        row_count = @@ROWCOUNT,
        status = 'EXTRACTED',
        last_run = GETDATE()
    WHERE source_table = 'transactions';
    
    PRINT 'CDC extraction completed. Rows: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
END;
```

---

## 7. Hands-On Exercise

### Exercise: Compare Incremental Load and CDC

#### Scenario
You're building an ETL pipeline for **Sathapana Bank's transaction data**. You need to decide between Incremental Load and CDC.

#### Part A: Incremental Load Approach

```sql
-- Step 1: Create source table
CREATE TABLE source_db.dbo.transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY,
    account_number VARCHAR(20),
    amount DECIMAL(18,2),
    transaction_date DATETIME,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE()
);

-- Step 2: Create staging table
CREATE TABLE staging_db.dbo.stg_transactions (
    transaction_id INT,
    account_number VARCHAR(20),
    amount DECIMAL(18,2),
    transaction_date DATETIME,
    change_type VARCHAR(10),
    batch_id UNIQUEIDENTIFIER
);

-- Step 3: Create control table
CREATE TABLE etl_db.dbo.etl_control (
    source_table VARCHAR(100) PRIMARY KEY,
    last_extract_date DATETIME,
    last_extract_key BIGINT
);

-- Step 4: Implement incremental load
CREATE PROCEDURE etl_db.dbo.usp_Extract_Incremental
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @LastDate DATETIME;
    
    SELECT @LastDate = last_extract_date
    FROM etl_db.dbo.etl_control
    WHERE source_table = 'transactions';
    
    IF @LastDate IS NULL
        SET @LastDate = '1900-01-01';
    
    INSERT INTO staging_db.dbo.stg_transactions
    SELECT transaction_id, account_number, amount, transaction_date,
           'NEW', @BatchID
    FROM source_db.dbo.transactions
    WHERE created_date > @LastDate
       OR modified_date > @LastDate;
    
    UPDATE etl_db.dbo.etl_control
    SET last_extract_date = GETDATE(),
        last_extract_key = (SELECT MAX(transaction_id) FROM source_db.dbo.transactions)
    WHERE source_table = 'transactions';
END;
```

#### Part B: Test Incremental Load

```sql
-- Insert initial data
INSERT INTO source_db.dbo.transactions (account_number, amount, transaction_date)
VALUES 
    ('ACC001', 1000.00, GETDATE()),
    ('ACC002', 2000.00, GETDATE());

-- Run extraction
DECLARE @Batch1 UNIQUEIDENTIFIER = NEWID();
EXEC etl_db.dbo.usp_Extract_Incremental @Batch1;

-- Check staging
SELECT * FROM staging_db.dbo.stg_transactions;

-- Add new transactions
INSERT INTO source_db.dbo.transactions (account_number, amount, transaction_date)
VALUES ('ACC003', 3000.00, GETDATE());

-- Update existing transaction
UPDATE source_db.dbo.transactions
SET amount = 1500.00, modified_date = GETDATE()
WHERE transaction_id = 1;

-- Run extraction again
DECLARE @Batch2 UNIQUEIDENTIFIER = NEWID();
EXEC etl_db.dbo.usp_Extract_Incremental @Batch2;

-- Check staging - will see the new and updated records
SELECT * FROM staging_db.dbo.stg_transactions;

-- DELETE a transaction (this will be missed by incremental load!)
DELETE FROM source_db.dbo.transactions WHERE transaction_id = 2;

-- Run extraction again
DECLARE @Batch3 UNIQUEIDENTIFIER = NEWID();
EXEC etl_db.dbo.usp_Extract_Incremental @Batch3;

-- The delete was NOT captured!
SELECT * FROM staging_db.dbo.stg_transactions;
```

#### Part C: CDC Approach

```sql
-- Step 1: Enable CDC (requires sysadmin)
USE master;
EXEC sys.sp_cdc_enable_db;

USE source_db;
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name = 'transactions',
    @role_name = NULL;

-- Step 2: Implement CDC extraction
CREATE PROCEDURE etl_db.dbo.usp_Extract_CDC
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @from_lsn BINARY(10), @to_lsn BINARY(10);
    
    SELECT @from_lsn = ISNULL(
        (SELECT last_lsn FROM etl_db.dbo.etl_control WHERE source_table = 'transactions_cdc'),
        sys.fn_cdc_get_min_lsn('dbo_transactions')
    );
    
    SET @to_lsn = sys.fn_cdc_get_max_lsn();
    
    INSERT INTO staging_db.dbo.stg_transactions
    SELECT 
        c.transaction_id,
        c.account_number,
        c.amount,
        c.transaction_date,
        CASE c.__$operation
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 4 THEN 'UPDATE'
        END,
        @BatchID
    FROM cdc.dbo_transactions_CT c
    WHERE c.__$start_lsn > @from_lsn
    AND c.__$start_lsn <= @to_lsn;
    
    UPDATE etl_db.dbo.etl_control
    SET last_lsn = @to_lsn
    WHERE source_table = 'transactions_cdc';
END;
```

#### Part D: Test CDC

```sql
-- Insert data
INSERT INTO source_db.dbo.transactions (account_number, amount, transaction_date)
VALUES ('ACC010', 5000.00, GETDATE());

-- Run CDC extraction
DECLARE @Batch1 UNIQUEIDENTIFIER = NEWID();
EXEC etl_db.dbo.usp_Extract_CDC @Batch1;

-- Check staging - should see INSERT
SELECT * FROM staging_db.dbo.stg_transactions;

-- Update
UPDATE source_db.dbo.transactions
SET amount = 5500.00 WHERE transaction_id = 5;

-- Run CDC extraction
DECLARE @Batch2 UNIQUEIDENTIFIER = NEWID();
EXEC etl_db.dbo.usp_Extract_CDC @Batch2;

-- Check staging - should see UPDATE
SELECT * FROM staging_db.dbo.stg_transactions;

-- Delete
DELETE FROM source_db.dbo.transactions WHERE transaction_id = 5;

-- Run CDC extraction
DECLARE @Batch3 UNIQUEIDENTIFIER = NEWID();
EXEC etl_db.dbo.usp_Extract_CDC @Batch3;

-- Check staging - should see DELETE!
SELECT * FROM staging_db.dbo.stg_transactions;
```

---

## Summary

| Aspect | Incremental Load | CDC |
|--------|------------------|-----|
| **Best For** | Batch processing, simple needs | Real-time, complete accuracy |
| **Complexity** | Low | Medium-High |
| **Captures Deletes** | ❌ No | ✅ Yes |
| **Latency** | Hours | Seconds-Minutes |
| **Source Impact** | Medium | Low |
| **Cost** | Free | May need licenses |

### Quick Decision Guide

```
Do you need real-time data?
├─ YES → Use CDC
└─ NO → Do you need to capture deletes?
         ├─ YES → Use CDC
         └─ NO → Is the source system sensitive to load?
                  ├─ YES → Use CDC
                  └─ NO → Use Incremental Load (simpler)
```

---

*Last Updated: September 2024*
*Based on Sathapana Bank Data Engineering Project*
