# ❓ ETL Frequently Asked Questions (FAQ)

## Table of Contents
1. [General ETL Questions](#1-general-etl-questions)
2. [Extract Phase Questions](#2-extract-phase-questions)
3. [Transform Phase Questions](#3-transform-phase-questions)
4. [Load Phase Questions](#4-load-phase-questions)
5. [SCD (Slowly Changing Dimensions) Questions](#5-scd-slowly-changing-dimensions-questions)
6. [CDC (Change Data Capture) Questions](#6-cdc-change-data-capture-questions)
7. [Data Quality Questions](#7-data-quality-questions)
8. [Performance Questions](#8-performance-questions)
9. [Troubleshooting Questions](#9-troubleshooting-questions)
10. [Best Practices Questions](#10-best-practices-questions)

---

## 1. General ETL Questions

### Q1: What is ETL?

**A:** ETL stands for **Extract, Transform, Load** — the process of:
- **Extract**: Pulling data from source systems (OLTP databases, files, APIs)
- **Transform**: Cleaning, validating, and reshaping data
- **Loading**: Inserting data into a target system (data warehouse)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   SOURCE    │───►│  STAGING    │───►│     DW      │
│   SYSTEM    │    │  (Transform)│    │   (Load)    │
└─────────────┘    └─────────────┘    └─────────────┘
```

---

### Q2: Why do we need ETL?

**A:** ETL is needed because:
1. **Data Integration** — Combine data from multiple sources
2. **Data Quality** — Cleanse and validate data
3. **Performance** — Pre-aggregate for fast reporting
4. **Historical Tracking** — Maintain change history (SCD)
5. **Single Source of Truth** — Consistent data for the organization

---

### Q3: What is the difference between ETL and ELT?

**A:**
| Aspect | ETL | ELT |
|--------|-----|-----|
| Order | Extract → Transform → Load | Extract → Load → Transform |
| Transform Location | Staging server | Target database |
| Best For | Traditional DW | Cloud data lakes |
| Flexibility | Less flexible | More flexible |

**In this project:** We use **ETL** (transform before loading into DW).

---

### Q4: What is a Data Warehouse?

**A:** A Data Warehouse is a centralized repository that:
- Stores historical data from multiple sources
- Is optimized for analytical queries (not transactions)
- Uses dimensional modeling (star/snowflake schema)
- Supports business intelligence and reporting

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA WAREHOUSE ARCHITECTURE                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Dimensions (Who, What, Where, When)                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ Customer │  │ Product  │  │  Date    │                 │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                 │
│       │              │              │                        │
│       └──────────────┼──────────────┘                        │
│                      │                                       │
│                      ▼                                       │
│              ┌──────────────┐                               │
│              │    FACT      │  (Measurements)               │
│              │ Transactions │                               │
│              └──────────────┘                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

### Q5: What is a Data Mart?

**A:** A Data Mart is a **subset of the data warehouse** focused on a specific business area:
- **Credit Risk Mart** — Loan portfolio, NPL analysis
- **Customer Analytics Mart** — Segmentation, profitability
- **Treasury Mart** — FX positions, liquidity
- **Compliance Mart** — AML alerts, KYC status

**Benefit:** Faster queries, easier access for business users.

---

### Q6: What is the difference between OLTP and OLAP?

**A:**
| Aspect | OLTP | OLAP |
|--------|------|------|
| Purpose | Transaction processing | Analytical processing |
| Design | Normalized (3NF) | Denormalized (Star) |
| Queries | Short, simple | Complex, aggregations |
| Data | Current state | Historical |
| Example | Core Banking System | Data Warehouse |

---

## 2. Extract Phase Questions

### Q7: What is the difference between Full Load and Incremental Load?

**A:**
| Aspect | Full Load | Incremental Load |
|--------|-----------|------------------|
| Data | All records | Only new/changed records |
| Speed | Slow | Fast |
| Source Load | High | Low |
| Complexity | Simple | More complex |
| Use Case | Small tables | Large tables |

**Example:**
```sql
-- Full Load
INSERT INTO staging.stg_branches SELECT * FROM source.branches;

-- Incremental Load
INSERT INTO staging.stg_transactions
SELECT * FROM source.transactions
WHERE created_date > @LastExtractDate;
```

---

### Q8: How do we track the last extraction point?

**A:** We use an **ETL Control Table** to store the "high-water mark":

```sql
CREATE TABLE staging.etl_control (
    source_table VARCHAR(100) PRIMARY KEY,
    last_extract_date DATETIME,
    last_extract_key BIGINT,
    row_count BIGINT,
    status VARCHAR(20)
);

-- Update after extraction
UPDATE staging.etl_control
SET last_extract_date = GETDATE(),
    last_extract_key = (SELECT MAX(id) FROM source.table)
WHERE source_table = 'table_name';
```

---

### Q9: What is a Batch ID and why do we use it?

**A:** A **Batch ID** is a unique identifier (GUID) assigned to each ETL execution:

```sql
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
```

**Purpose:**
- Track all records loaded in one execution
- Debug issues by batch
- Audit trail for compliance
- Correlate logs across tables

---

### Q10: How do we handle source system downtime?

**A:** Strategies for handling source downtime:

1. **Check before extraction**
   ```sql
   IF NOT EXISTS (SELECT 1 FROM source.table WHERE ...)
   BEGIN
       PRINT 'No data available';
       RETURN;
   END
   ```

2. **Retry logic**
   ```sql
   DECLARE @RetryCount INT = 0;
   WHILE @RetryCount < 3
   BEGIN
       BEGIN TRY
           -- Try extraction
           SET @RetryCount = 3; -- Exit loop
       END TRY
       BEGIN CATCH
           SET @RetryCount += 1;
           WAITFOR DELAY '00:05:00'; -- Wait 5 minutes
       END CATCH
   END
   ```

3. **Alert and skip**
   ```sql
   EXEC audit.usp_SendAlert @AlertType = 'SOURCE_UNAVAILABLE';
   ```

---

## 3. Transform Phase Questions

### Q11: What is a Surrogate Key?

**A:** A Surrogate Key is an **artificial unique identifier** generated by the data warehouse:

| Natural Key (Source) | Surrogate Key (DW) |
|---------------------|---------------------|
| CUST001 | 12345 |
| ACC1001 | 67890 |

**Why use surrogate keys?**
- Independent of source system
- Handles SCD Type 2 (multiple versions)
- Faster joins (integer vs string)
- Protects against source key changes

---

### Q12: What is Data Cleansing?

**A:** Data Cleansing is the process of fixing or removing incorrect, corrupted, or irrelevant data:

| Issue | Solution | Example |
|-------|----------|---------|
| NULL values | Default or exclude | `ISNULL(phone, 'N/A')` |
| Extra spaces | TRIM | `TRIM(name)` |
| Invalid formats | Standardize | `UPPER(city)` |
| Duplicates | Remove or flag | `ROW_NUMBER()` |
| Outliers | Validate range | `WHERE amount > 0` |

---

### Q13: What is Currency Conversion and why is it needed?

**A:** For a bank operating in multiple currencies (USD, KHR, THB), we need to convert to a common currency for reporting:

```sql
-- Convert to USD
CASE 
    WHEN currency = 'KHR' THEN amount / 4100.00
    WHEN currency = 'USD' THEN amount
    WHEN currency = 'THB' THEN amount * 0.029
    ELSE amount * ISNULL(exchange_rate, 1.0)
END AS amount_usd
```

**Why:** Compare transactions across currencies consistently.

---

### Q14: What is Row Count Reconciliation?

**A:** Verifying that the number of records extracted matches the source:

```sql
-- Before extraction
SELECT @SourceCount = COUNT(*) FROM source.table;

-- After extraction
SELECT @StagingCount = COUNT(*) FROM staging.table;

-- Compare
IF @SourceCount != @StagingCount
    RAISERROR('Row count mismatch!', 16, 1);
```

**Purpose:** Detect data loss during extraction.

---

## 4. Load Phase Questions

### Q15: Why do we load Dimensions before Facts?

**A:** Because **Fact tables contain foreign keys to Dimension tables**:

```
Dimension (loaded first)          Fact (loaded second)
┌──────────────┐                  ┌──────────────────┐
│ dim_customer │                  │ fact_transactions│
│──────────────│                  │──────────────────│
│ customer_key │◄────────────────│ customer_key (FK)│
│ customer_code│                  │ transaction_code │
└──────────────┘                  └──────────────────┘
```

**If we load facts first:** Foreign key constraint violation!

---

### Q16: What is an Upsert (MERGE)?

**A:** An Upsert is an operation that **inserts new records and updates existing ones**:

```sql
-- Using MERGE statement
MERGE INTO dw.dim_customer AS target
USING staging.stg_customers AS source
ON target.customer_code = source.customer_code
WHEN MATCHED AND (
    target.first_name != source.first_name OR
    target.email != source.email
)
THEN UPDATE SET
    target.first_name = source.first_name,
    target.email = source.email,
    target.modified_date = GETDATE()
WHEN NOT MATCHED
THEN INSERT (customer_code, first_name, email, ...)
VALUES (source.customer_code, source.first_name, source.email, ...);
```

---

### Q17: What is Index Maintenance during ETL?

**A:** Managing indexes to improve load performance:

```sql
-- BEFORE bulk load: Drop non-clustered indexes
DROP INDEX IX_table_column ON dw.table_name;

-- Perform bulk insert
INSERT INTO dw.table_name SELECT ...;

-- AFTER load: Rebuild indexes
ALTER INDEX ALL ON dw.table_name REBUILD;

-- Update statistics
UPDATE STATISTICS dw.table_name;
```

**Why:** Indexes slow down bulk inserts but speed up queries.

---

### Q18: What is a Fact Table?

**A:** A Fact Table stores **quantitative measurements** (metrics) for business events:

| Fact Table | Grain | Metrics |
|------------|-------|---------|
| fact_transactions | One row per transaction | amount, balance |
| fact_loan_portfolio | One row per loan per month | outstanding, provision |
| fact_account_daily | One row per account per day | balance, interest |

**Characteristics:**
- Contains foreign keys to dimensions
- Contains numeric measures
- Usually the largest table

---

## 5. SCD (Slowly Changing Dimensions) Questions

### Q19: What is SCD and why do we need it?

**A:** **Slowly Changing Dimensions** is a technique to manage how data changes over time in dimension tables.

**Why needed:** Track historical changes for accurate reporting.

**Example:** Customer moves from Siem Reap to Phnom Penh:
- Without SCD: Only current address visible
- With SCD: Both old and new addresses preserved

---

### Q20: What are the different SCD Types?

**A:**
| Type | Method | History | Use Case |
|------|--------|---------|----------|
| **Type 0** | Retain original | Fixed | Rarely used |
| **Type 1** | Overwrite | None | Correcting errors |
| **Type 2** | Add new row | Full | Historical tracking |
| **Type 3** | Add new column | Limited | Previous value only |
| **Type 4** | History table | Full | Very large dimensions |
| **Type 6** | Hybrid | Full | Type 1 + 2 + 3 |

---

### Q21: How does SCD Type 2 work?

**A:** SCD Type 2 creates a **new row** for each change:

```sql
-- Step 1: Expire old record
UPDATE dim_customer
SET expiry_date = GETDATE(),
    is_current = 0
WHERE customer_code = 'CUST001' AND is_current = 1;

-- Step 2: Insert new version
INSERT INTO dim_customer (
    customer_code, first_name, phone, ...,
    effective_date, expiry_date, is_current
)
VALUES (
    'CUST001', 'Sok', '012-999-888', ...,
    GETDATE(), '9999-12-31', 1
);
```

**Result:** Two rows for same customer, different time periods.

---

### Q22: What is the difference between effective_date and expiry_date?

**A:**
- **effective_date**: When this version became valid
- **expiry_date**: When this version expired (or '9999-12-31' for current)

```
Customer CUST001 History:

Row 1: effective_date = 2024-01-01, expiry_date = 2024-06-14, is_current = 0
Row 2: effective_date = 2024-06-15, expiry_date = 9999-12-31, is_current = 1
```

**Query for "as of" date:**
```sql
SELECT * FROM dim_customer
WHERE customer_code = 'CUST001'
AND effective_date <= '2024-03-15'
AND expiry_date >= '2024-03-15';
```

---

### Q23: When should I use SCD Type 1 vs Type 2?

**A:**
| Scenario | Use Type 1 | Use Type 2 |
|----------|------------|------------|
| Product name corrected | ✅ | |
| Customer changes address | | ✅ |
| Employee promoted | | ✅ |
| Fixing typo in name | ✅ | |
| Risk rating changes | | ✅ |
| Phone number update | ✅ (usually) | |

**Rule of thumb:** If you need to analyze by this attribute over time, use Type 2.

---

## 6. CDC (Change Data Capture) Questions

### Q24: What is CDC?

**A:** **Change Data Capture** reads the database transaction log to capture all changes (INSERT, UPDATE, DELETE) in real-time.

```
Source DB ──► Transaction Log ──► CDC ──► ETL ──► DW
                    │
                    └── Captures: INSERT, UPDATE, DELETE
```

---

### Q25: What is the difference between CDC and Incremental Load?

**A:**
| Aspect | Incremental Load | CDC |
|--------|------------------|-----|
| Method | Query source table | Read transaction log |
| Captures INSERT | ✅ Yes | ✅ Yes |
| Captures UPDATE | ✅ Yes (if timestamp) | ✅ Yes |
| Captures DELETE | ❌ Usually not | ✅ Yes |
| Latency | Minutes to hours | Seconds to minutes |
| Source Load | Medium | Low |
| Complexity | Low | Medium |

---

### Q26: What is an LSN (Log Sequence Number)?

**A:** An LSN is a **unique identifier for each transaction** in the transaction log:

```sql
-- Get current max LSN
DECLARE @max_lsn BINARY(10) = sys.fn_cdc_get_max_lsn();

-- Get min LSN (oldest available)
DECLARE @min_lsn BINARY(10) = sys.fn_cdc_get_min_lsn('dbo_transactions');

-- Query changes between LSNs
SELECT * FROM cdc.fn_cdc_get_all_changes_dbo_transactions(
    @from_lsn, @to_lsn, 'all'
);
```

---

### Q27: What are CDC operation codes?

**A:**
| Code | Operation | Description |
|------|-----------|-------------|
| 1 | DELETE | Row was deleted |
| 2 | INSERT | Row was inserted |
| 3 | UPDATE (Before) | Row state before update |
| 4 | UPDATE (After) | Row state after update |

```sql
-- Get only inserts and updates (after image)
SELECT * FROM cdc.dbo_transactions_CT
WHERE __$operation IN (2, 4);

-- Get only deletes
SELECT * FROM cdc.dbo_transactions_CT
WHERE __$operation = 1;
```

---

## 7. Data Quality Questions

### Q28: What are the 6 dimensions of Data Quality?

**A:**
| Dimension | Description | How to Measure |
|-----------|-------------|----------------|
| **Completeness** | All required data present | NULL count |
| **Accuracy** | Data matches real-world | Validation rules |
| **Consistency** | Data agrees across systems | Cross-table checks |
| **Timeliness** | Data available when needed | Freshness monitoring |
| **Uniqueness** | No unintended duplicates | Duplicate detection |
| **Validity** | Data conforms to rules | Business rule checks |

---

### Q29: How do we handle data quality failures?

**A:** Based on severity level:

| Severity | Action |
|----------|--------|
| **Critical** | Stop ETL, send immediate alert |
| **High** | Log error, send alert, continue |
| **Medium** | Log warning, include in report |
| **Low** | Log for reference |

```sql
-- Check quality before loading
DECLARE @QualityResult INT;
EXEC @QualityResult = dq.usp_RunQualityChecks;

IF @QualityResult != 0
BEGIN
    EXEC audit.usp_SendAlert @AlertType = 'QUALITY_FAILURE';
    -- Option: Stop or continue based on business rules
END
```

---

### Q30: What is Referential Integrity?

**A:** Ensuring that **foreign keys match primary keys** in related tables:

```sql
-- Find orphaned records (no matching dimension)
SELECT COUNT(*) AS orphan_count
FROM fact_transactions f
LEFT JOIN dim_customer c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
```

**In ETL:** Always load dimensions before facts!

---

## 8. Performance Questions

### Q31: How can we improve ETL performance?

**A:** Key optimization techniques:

| Technique | Description | Impact |
|-----------|-------------|--------|
| **Incremental loads** | Only process changed data | High |
| **Batch processing** | Process in chunks | Medium |
| **Drop indexes** | Remove before bulk load | High |
| **Parallel execution** | Run independent steps simultaneously | High |
| **Query optimization** | Use proper JOINs, avoid cursors | Medium |
| **Partitioning** | Split large tables by date | Medium |

---

### Q32: What is Batch Processing and why use it?

**A:** Processing data in **smaller chunks** instead of all at once:

```sql
DECLARE @BatchSize INT = 50000;
DECLARE @RowsProcessed INT = 1;

WHILE @RowsProcessed > 0
BEGIN
    INSERT INTO target_table (...)
    SELECT TOP (@BatchSize) ...
    FROM source_table
    WHERE id > @LastID;
    
    SET @RowsProcessed = @@ROWCOUNT;
    SET @LastID = (SELECT MAX(id) FROM target_table);
END
```

**Benefits:**
- Prevents transaction log bloat
- Allows for progress tracking
- Enables restart capability

---

### Q33: How do we monitor ETL performance?

**A:** Use the audit log to track metrics:

```sql
-- Average duration by step
SELECT 
    step_name,
    AVG(duration_seconds) AS avg_duration,
    MAX(duration_seconds) AS max_duration,
    SUM(records_affected) AS total_records
FROM audit.etl_log
WHERE start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY step_name
ORDER BY avg_duration DESC;

-- Performance trend
SELECT 
    CAST(start_time AS DATE) AS execution_date,
    SUM(duration_seconds) AS total_duration
FROM audit.etl_log
GROUP BY CAST(start_time AS DATE)
ORDER BY execution_date;
```

---

## 9. Troubleshooting Questions

### Q34: What do I do when ETL fails?

**A:** Follow this troubleshooting process:

```
1. CHECK ERROR MESSAGE
   └── SELECT * FROM audit.etl_log WHERE status = 'FAILED'

2. IDENTIFY FAILED STEP
   └── Which procedure failed?

3. CHECK SOURCE DATA
   └── Does source table have data?

4. CHECK PERMISSIONS
   └── Does ETL account have access?

5. CHECK DISK SPACE
   └── EXEC sp_spaceused

6. CHECK BLOCKING
   └── SELECT * FROM sys.dm_tran_locks

7. FIX AND RE-RUN
   └── EXEC the failed procedure
```

---

### Q35: How do we handle NULL values in ETL?

**A:** Strategies for handling NULLs:

| Strategy | When to Use | Example |
|----------|-------------|---------|
| **ISNULL/COALESCE** | Replace with default | `ISNULL(phone, 'N/A')` |
| **Filter out** | Exclude invalid records | `WHERE email IS NOT NULL` |
| **Log and alert** | Track data quality | INSERT INTO error_log |
| **Use NULL** | Allow in warehouse | Keep as NULL |

**Best Practice:** Always use ISNULL in comparisons:
```sql
-- Wrong (misses NULL comparisons)
WHERE d.name != s.name

-- Correct
WHERE ISNULL(d.name, '') != ISNULL(s.name, '')
```

---

### Q36: How do we handle duplicate records?

**A:** Detect and handle duplicates:

```sql
-- Detect duplicates
SELECT customer_code, COUNT(*) AS cnt
FROM staging.stg_customers
GROUP BY customer_code
HAVING COUNT(*) > 1;

-- Remove duplicates (keep latest)
WITH CTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_code 
            ORDER BY modified_date DESC
        ) AS rn
    FROM staging.stg_customers
)
DELETE FROM CTE WHERE rn > 1;
```

---

## 10. Best Practices Questions

### Q37: What are ETL best practices?

**A:** Key best practices:

| Category | Best Practice |
|----------|---------------|
| **Logging** | Log every step with batch ID |
| **Error Handling** | Use TRY/CATCH blocks |
| **Idempotency** | Safe to re-run without duplicates |
| **Modularity** | Separate procedures for each table |
| **Documentation** | Document procedures and rules |
| **Testing** | Unit test all procedures |
| **Monitoring** | Set up alerts for failures |
| **Scheduling** | Use SQL Agent for automation |

---

### Q38: What is Idempotency and why is it important?

**A:** **Idempotency** means running the same ETL multiple times produces the same result:

```sql
-- NOT idempotent (duplicates on re-run)
INSERT INTO dim_customer SELECT ... FROM staging;

-- Idempotent (safe to re-run)
INSERT INTO dim_customer
SELECT ... FROM staging s
WHERE NOT EXISTS (
    SELECT 1 FROM dim_customer d
    WHERE d.customer_code = s.customer_code
);
```

**Why important:** ETL may need to be re-run due to failures.

---

### Q39: How should we name ETL procedures?

**A:** Follow consistent naming conventions:

| Object | Naming Convention | Example |
|--------|-------------------|---------|
| Stored Procedure | usp_Action_Entity | usp_ExtractCustomers |
| Staging Table | stg_Entity | stg_customers |
| Dimension Table | dim_Entity | dim_customer |
| Fact Table | fact_Entity | fact_transactions |
| View | vw_Purpose | vw_etl_dashboard |
| Audit Table | Entity_audit | etl_log |

---

### Q40: What should we include in ETL documentation?

**A:** Essential documentation:

| Document | Contents |
|----------|----------|
| **Specification** | Business rules, requirements |
| **Data Dictionary** | Table/column definitions |
| **Runbook** | How to run and troubleshoot |
| **Architecture** | System design, data flow |
| **Change Log** | What changed and when |
| **Test Cases** | Unit and integration tests |

---

## Quick Reference Card

### Common SQL Patterns

```sql
-- Incremental load pattern
WHERE created_date > @LastExtractDate

-- SCD Type 2 expire
UPDATE dim SET expiry_date = GETDATE(), is_current = 0

-- SCD Type 2 insert
INSERT dim (..., effective_date, expiry_date, is_current)
VALUES (..., GETDATE(), '9999-12-31', 1)

-- NULL-safe comparison
WHERE ISNULL(d.col, '') != ISNULL(s.col, '')

-- Duplicate detection
GROUP BY key HAVING COUNT(*) > 1

-- Row count reconciliation
IF @SourceCount != @TargetCount RAISERROR(...)

-- Batch tracking
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID()
```

---

*Created: September 2024*
*Sathapana Bank Data Engineering Project*
