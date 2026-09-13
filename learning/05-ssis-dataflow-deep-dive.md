# SSIS Data Flow Deep Dive — Advanced Techniques

## Table of Contents

1. [Data Flow Architecture](#1-data-flow-architecture)
2. [Advanced Source Configurations](#2-advanced-source-configurations)
3. [Key Transformations Explained](#3-key-transformations)
4. [Loading Dimension Tables with SCD](#4-loading-dimension-tables)
5. [Loading Fact Tables](#5-loading-fact-tables)
6. [Merging Multiple Data Sources](#6-merging-multiple-sources)
7. [Performance Optimization](#7-performance-optimization)
8. [Real-World Banking ETL Patterns](#8-banking-etl-patterns)

---

## 1. Data Flow Architecture

### How Data Flows Internally

```
┌─────────────────────────────────────────────────────────────┐
│                    DATA FLOW PIPELINE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Source ──▶ Buffer Memory ──▶ Transformations ──▶ Destination│
│            (in-memory)                                   │
│                                                             │
│  SSIS loads data into memory buffers (default 10,000 rows) │
│  Transformations process buffer data                       │
│  Destination writes from buffer to target                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Buffer Tuning

```sql
-- Default buffer size: 10,000 rows
-- Increase for better performance:

-- In Data Flow Task Properties:
-- DefaultBufferMaxRows = 50000
-- DefaultBufferSize = 10485760  (10 MB)

-- For large datasets (millions of rows):
-- DefaultBufferMaxRows = 100000
-- DefaultBufferSize = 52428800  (50 MB)
```

---

## 2. Advanced Source Configurations

### OLE DB Source — SQL Command vs Table

```
Option 1: Full Table (reads entire table)
┌────────────────────────────┐
│ OLE DB Source              │
│ Table: cbs.dbo.customers   │
└────────────────────────────┘

Option 2: SQL Command (filtered/complex query)
┌────────────────────────────┐
│ OLE DB Source              │
│ SQL Command:               │
│ SELECT * FROM customers    │
│ WHERE modified_date > ?    │
│ (use parameter from variable)│
└────────────────────────────┘
```

### Parameterized Query (Incremental Load)

```sql
-- SQL Command in OLE DB Source:
SELECT 
    customer_id,
    full_name,
    risk_rating,
    phone,
    modified_date
FROM cbs.dbo.customers
WHERE modified_date > ?
  AND modified_date <= ?

-- Parameters:
-- Parameter 0: @LastLoadDate (from variable: var_LastLoadDate)
-- Parameter 1: @CurrentLoadDate (from variable: var_CurrentLoadDate)
```

### Reading Multiple Files

```sql
-- Use Foreach Loop Container in Control Flow:
-- 1. Foreach Loop: Iterate over C:\ETL\source\transactions_*.csv
-- 2. Data Flow Task: Read each file

-- In Data Flow, use variable for file path:
-- Flat File Connection Manager → Properties → Expressions → ConnectionString
-- Expression: @[User::var_CurrentFilePath]
```

---

## 3. Key Transformations Explained

### 3.1 Derived Column Transformation

Creates new columns or modifies existing ones.

```
Input Columns:
├── customer_id
├── full_name
├── date_of_birth
└── phone

Derived Columns:
├── age = DATEDIFF("year", date_of_birth, GETDATE())
├── age_group = age < 25 ? "Youth" : age < 45 ? "Adult" : "Senior"
├── clean_phone = REPLACE(REPLACE(phone, "-", ""), " ", "")
└── full_name_upper = UPPER(full_name)
```

### 3.2 Lookup Transformation

Finds matching rows from a reference table. Critical for finding surrogate keys!

```
Scenario: Find customer_key for each transaction

Input (fact_transactions_staging):
├── transaction_id: 5001
├── account_number: "001-001-123456"
└── transaction_date: 2025-09-12

Lookup (dim_account):
├── Input: account_number
├── Output: account_key (surrogate key)
└── Result: account_key = 301

Configuration:
┌─────────────────────────────────────────────────────┐
│ Lookup Transformation                                │
│                                                     │
│ Connection: Sathapana_DW                             │
│ Mode: Full cache (default, fastest)                 │
│                                                     │
│ Query:                                               │
│ SELECT account_key, account_number                   │
│ FROM dim_account                                     │
│ WHERE is_current = 1                                │
│                                                     │
│ Join: account_number = account_number                │
│ Output: account_key                                 │
│                                                     │
│ No Match: Redirect to error output                  │
└─────────────────────────────────────────────────────┘
```

### 3.3 Conditional Split

Routes data to different outputs based on conditions.

```
Scenario: Separate different transaction types

Input:
├── transaction_type: "DEPOSIT" or "WITHDRAWAL"
├── channel: "ATL" or "BTL"
└── amount

Conditional Split Outputs:
├── Output 1: "Deposits" → WHERE transaction_type == "DEPOSIT"
├── Output 2: "Withdrawals" → WHERE transaction_type == "WITHDRAWAL"
├── Output 3: "ATL Transactions" → WHERE channel == "ATL"
└── Default Output: Everything else
```

### 3.4 Merge Join

Combines two data sources (like SQL JOIN).

```
Scenario: Join accounts with customer data

Source 1: CBS Accounts           Source 2: CBS Customers
├── account_number               ├── customer_id
├── customer_id (FK)             ├── full_name
├── account_type                 └── risk_rating
└── balance

Merge Join (Inner Join on customer_id):
├── account_number
├── customer_id
├── account_type
├── balance
├── full_name (from customers)
└── risk_rating (from customers)
```

### 3.5 Merge Transformation

Combines two sorted data streams (like UNION ALL, but sorted).

```
Scenario: Combine transactions from CBS and CMS

Source 1: CBS Transactions       Source 2: CMS Transactions
├── transaction_date             ├── transaction_date
├── amount                       ├── amount
└── source_system = 'CBS'        └── source_system = 'CMS'

Merge Output (sorted by transaction_date):
├── transaction_date (sorted)
├── amount
├── source_system
└── [combined, sorted data]
```

### 3.6 Aggregate Transformation

Summarizes data.

```
Scenario: Daily transaction summary per branch

Input:
├── branch_code, transaction_date, amount

Aggregate:
├── Group By: branch_code, transaction_date
├── Total_Amount: SUM(amount)
├── Transaction_Count: COUNT(*)
├── Avg_Amount: AVG(amount)
├── Max_Amount: MAX(amount)
└── Min_Amount: MIN(amount)
```

### 3.7 Sort Transformation

Sorts data (required before Merge and some other operations).

```
Sort Configuration:
├── Sort Key: transaction_date (Ascending)
├── Sort Key: account_number (Ascending)
└── Output IsSorted: True
```

### 3.8 OLE DB Command

Executes a SQL statement for each row.

```
Scenario: Update staging table with surrogate key

OLE DB Command:
├── Connection: Sathapana_DW
├── SQL Statement:
│   UPDATE staging_transactions
│   SET account_key = ?
│   WHERE transaction_id = ?
│
├── Parameter 0: account_key (from input column)
└── Parameter 1: transaction_id (from input column)

⚠️ WARNING: OLE DB Command is SLOW (row-by-row execution)
   Use Set-Based operations in Execute SQL Tasks instead when possible
```

---

## 4. Loading Dimension Tables with SCD

### SCD Type 1 — Simple Overwrite

```
Data Flow:
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ OLE DB Source│───▶│ Lookup       │───▶│ Conditional  │
│ (CBS Query)  │    │ (Find Key)   │    │ Split        │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                               │
                              ┌─────────────────┴─────────────────┐
                              │                                   │
                              ▼                                   ▼
                    ┌─────────────────┐                 ┌─────────────────┐
                    │ OLE DB Command  │                 │ OLE DB          │
                    │ (UPDATE existing)│                │ Destination     │
                    └─────────────────┘                 │ (INSERT new)    │
                                                        └─────────────────┘
```

### SCD Type 2 — Full History

SSIS has a **built-in SCD Wizard**:

1. Drag **Slowly Changing Dimension** transformation to Data Flow
2. Configure:
   - Dimension Table: `dim_customer`
   - Business Key: `customer_id`
   - Fixed columns: `full_name`, `national_id` (Type 1)
   - Changing attributes: `risk_rating`, `phone` (Type 2)
   - Historical attributes: `province` (Type 2 with history)

```
SCD Wizard generates:
├── Lookup (find existing key)
├── Conditional Split (new vs changed vs unchanged)
├── Derived Column (set effective_date, expiry_date)
├── OLE DB Command (expire old records)
└── OLE DB Destination (insert new versions)
```

### Manual SCD Type 2 (More Control)

```
Data Flow:
┌──────────────┐
│ OLE DB Source│  ← CBS customers
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Lookup       │  ← Find customer_key in dim_customer (is_current=1)
│ (dim_customer)│
└──────┬───────┘
       │
  ┌────┴────────────┐
  │                  │
  ▼                  ▼
┌────────────┐  ┌────────────┐
│ New Record │  │ Existing   │
│ (no match) │  │ (matched)  │
└─────┬──────┘  └─────┬──────┘
      │               │
      ▼               ▼
┌────────────┐  ┌──────────────┐
│ INSERT new │  │ Conditional  │
│ dim_customer│ │ Split        │
│            │  ├──────────────┤
└────────────┘  │ Changed?     │
                │  YES → Expire│
                │  old record  │
                │  INSERT new  │
                │  NO → Skip   │
                └──────────────┘
```

---

## 5. Loading Fact Tables

### Fact Table Loading Pattern

```
Data Flow:
┌──────────────┐
│ OLE DB Source│  ← From staging table or source system
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Derived Col  │  ← Add computed columns (date_key, etc.)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Lookup       │  ← Find dim_account.account_key
│ (dim_account)│
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Lookup       │  ← Find dim_date.date_key
│ (dim_date)   │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Lookup       │  ← Find dim_branch.branch_key
│ (dim_branch) │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Lookup       │  ← Find dim_customer.customer_key
│ (dim_customer)│
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ OLE DB       │  ← Insert into fact_transactions
│ Destination  │
└──────────────┘
```

### Deriving Date Key

```sql
-- In Derived Column transformation:
-- date_key = (DT_I4)(YEAR(transaction_date) * 10000 + MONTH(transaction_date) * 100 + DAY(transaction_date))

-- Example: 2025-09-12 → 20250912
```

### Lookup Configuration for Fact Loading

```
Lookup: dim_account
├── Mode: Full cache (default)
├── Connection: Sathapana_DW
├── Query: SELECT account_key, account_number FROM dim_account WHERE is_current = 1
├── Join: account_number (input) = account_number (lookup)
├── Output: account_key
└── No Match: Redirect to error output

Lookup: dim_date
├── Mode: Full cache
├── Query: SELECT date_key, full_date FROM dim_date
├── Join: transaction_date (input) = full_date (lookup)
├── Output: date_key
└── No Match: FAIL (all dates must exist in dim_date)
```

---

## 6. Merging Multiple Data Sources

### Scenario: Combine CBS, CMS, and Mobile Banking Transactions

```
Control Flow:
┌─────────────────────────┐
│ Load CBS Transactions   │──┐
└─────────────────────────┘  │
┌─────────────────────────┐  │    ┌─────────────────────────┐
│ Load CMS Transactions   │──┼───▶│ Merge All Sources       │
└─────────────────────────┘  │    │ (Data Flow Task)        │
┌─────────────────────────┐  │    └─────────────────────────┘
│ Load Mobile Transactions│──┘
└─────────────────────────┘

Data Flow (Merge All Sources):
┌──────────────┐
│ OLE DB Source│ ← CBS transactions
│ (SQL Server) │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Derived Col  │ ← Add source_system = 'CBS'
└──────┬───────┘
       │
       ├───▶ ┌──────────────┐
       │     │ Union All    │
       │     │ (combine)    │
       │     └──────┬───────┘
       │            │
       │   ┌────────┴────────┐
       │   │                 │
       ▼   ▼                 ▼
┌──────────────┐      ┌──────────────┐
│ OLE DB Source│      │ OLE DB Source│
│ (CMS DB)     │      │ (Mobile DB)  │
└──────┬───────┘      └──────┬───────┘
       │                     │
       ▼                     ▼
┌──────────────┐      ┌──────────────┐
│ Derived Col  │      │ Derived Col  │
│ source='CMS' │      │ source='MOB' │
└──────┬───────┘      └──────┬───────┘
       │                     │
       └─────────┬───────────┘
                 │
                 ▼
           ┌──────────────┐
           │ Union All    │
           └──────┬───────┘
                  │
                  ▼
           ┌──────────────┐
           │ Lookups      │
           │ (dim tables) │
           └──────┬───────┘
                  │
                  ▼
           ┌──────────────┐
           │ Destination  │
           │ fact_txn     │
           └──────────────┘
```

### Union All vs Merge vs Merge Join

| Component | Purpose | Requirement |
|---|---|---|
| **Union All** | Stack rows vertically (UNION) | Same column structure |
| **Merge** | Combine two sorted streams | Both inputs must be sorted |
| **Merge Join** | Join two data sources (JOIN) | Join condition required |

---

## 7. Performance Optimization

### 7.1 Use Set-Based Operations

❌ **Slow (Row-by-row):**
```
OLE DB Command for each row:
UPDATE dim_customer SET risk_rating = ? WHERE customer_id = ?
```

✅ **Fast (Set-based):**
```
Execute SQL Task:
UPDATE dim_customer
SET risk_rating = src.risk_rating
FROM dim_customer tgt
INNER JOIN staging_customers src
ON tgt.customer_id = src.customer_id
WHERE tgt.risk_rating <> src.risk_rating;
```

### 7.2 Increase Buffer Size

```
Data Flow Task Properties:
├── DefaultBufferMaxRows = 100000    (was 10000)
├── DefaultBufferSize = 52428800     (was 10485760 = 10MB, now 50MB)
└── EngineThreads = 10               (parallelism)
```

### 7.3 Use Full Cache for Lookups

```
Lookup Properties:
├── Cache Mode: Full Cache (default, loads all lookup data once)
├── vs Partial Cache (loads on-demand)
└── vs No Cache (hits database for every row) ← SLOWEST!

✅ Use Full Cache when lookup table fits in memory
⚠️ Use Partial Cache when lookup table is too large
❌ Avoid No Cache (row-by-row database hits)
```

### 7.4 Disable Checkpoints Temporarily

```sql
-- Checkpoints slow down development/testing
-- Disable in Package Properties:
-- CheckpointUsage = Never
-- SaveCheckpoints = False
```

### 7.5 Use Raw Files for Large Datasets

```
-- Save intermediate results to raw files (SSIS native binary format)
-- Much faster than re-reading from source

Data Flow 1: Source → Transformations → RAW FILE Destination
Data Flow 2: RAW FILE Source → More transformations → Destination
```

### 7.6 Parallel Execution

```
Control Flow:
┌─────────────────────────┐
│ Load dim_branch         │──┐
└─────────────────────────┘  │
┌─────────────────────────┐  │  Run in parallel!
│ Load dim_customer       │──┼──▶ ┌─────────────┐
└─────────────────────────┘  │    │ Wait for    │
┌─────────────────────────┐  │    │ All         │
│ Load dim_account        │──┤    │ (Success)   │
└─────────────────────────┘  │    └──────┬──────┘
┌─────────────────────────┐  │           │
│ Load dim_product        │──┘           ▼
└─────────────────────────┘     ┌─────────────┐
                                │ Load Facts  │
                                └─────────────┘

⚠️ Don't parallelize if tables have foreign key dependencies!
   dim_branch must load BEFORE dim_account (dim_account references dim_branch)
```

### 7.7 Performance Checklist

```
┌────────────────────────────────────────────────────────────┐
│              PERFORMANCE OPTIMIZATION CHECKLIST              │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  □ Use set-based operations instead of row-by-row          │
│  □ Increase DefaultBufferMaxRows for large datasets        │
│  □ Use Full Cache for Lookup transformations               │
│  □ Minimize number of Lookup transformations               │
│  □ Sort data once, use for multiple operations             │
│  □ Use UNION ALL instead of Merge when possible            │
│  □ Avoid OLE DB Command when possible                      │
│  □ Use staging tables for complex transformations          │
│  □ Index destination tables properly                       │
│  □ Drop indexes before bulk load, rebuild after            │
│  □ Use minimal logging for large inserts                   │
│  □ Monitor row counts at each step                         │
│  □ Use SQL Server Profiler to identify bottlenecks         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 8. Real-World Banking ETL Patterns

### Pattern 1: Daily Incremental Load

```sql
-- Control Flow:
┌─────────────────────────┐
│ Get Last Load Date      │ ← Execute SQL: SELECT MAX(load_date) FROM etl_audit
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Load Changed Records    │ ← Data Flow: WHERE modified_date > @LastLoadDate
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Update Audit Log        │ ← Execute SQL: INSERT INTO etl_audit
└─────────────────────────┘
```

### Pattern 2: File-Based ETL (ATM/CMS Data)

```sql
-- Control Flow:
┌─────────────────────────┐
│ Check File Exists       │ ← Script Task: File.Exists(@FilePath)
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│ Import CSV to Staging   │ ← Data Flow: Flat File → Staging Table
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Validate Data Quality   │ ← Execute SQL: Check NULLs, duplicates
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Load to Data Warehouse  │ ← Data Flow: Staging → Fact/Dim Tables
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Archive Processed File  │ ← File System Task: Move to archive folder
└─────────────────────────┘
```

### Pattern 3: Truncate and Reload (Small Dimensions)

```sql
-- For small tables (< 100K rows), truncate and reload is faster than SCD
-- Use for: dim_date, dim_product, dim_channel

Control Flow:
┌─────────────────────────┐
│ Truncate dim_product    │ ← Execute SQL: TRUNCATE TABLE dim_product
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Load dim_product        │ ← Data Flow: Source → Destination
└─────────────────────────┘
```

### Pattern 4: Master Orchestration Package

```
Master Package: ETL_Orchestrate_Daily_Load.dtsx

Control Flow:
┌─────────────────────────┐
│ Load Dimensions         │ ← Sequence Container
│ ├── dim_branch          │
│ ├── dim_customer (SCD2) │
│ ├── dim_account         │
│ ├── dim_product         │
│ └── dim_channel         │
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│ Load Facts              │ ← Sequence Container
│ ├── fact_transactions   │
│ ├── fact_daily_balance  │
│ └── fact_card_txn       │
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│ Post-Processing         │ ← Sequence Container
│ ├── Rebuild Indexes     │
│ ├── Update Statistics   │
│ └── Send Success Email  │
└─────────────────────────┘
```

### Pattern 5: Error Recovery and Restartability

```sql
-- Use Checkpoints for restart capability:
-- Package Properties:
--   CheckpointUsage = IfExists
--   SaveCheckpoints = True
--   CheckpointFileName = C:\ETL\checkpoints\daily_load.chk

-- If package fails, it restarts from the last successful task
```

---

## Quick Reference — Data Flow Components

| Component | Purpose | When to Use |
|---|---|---|
| **OLE DB Source** | Read from database | SQL Server, Oracle |
| **Flat File Source** | Read CSV/TXT | File-based data |
| **Derived Column** | Calculate new values | Age groups, key derivation |
| **Lookup** | Find matching data | Get surrogate keys |
| **Conditional Split** | Route data | Different processing paths |
| **Merge Join** | Join two sources | Combine data |
| **Merge** | Combine sorted streams | Union sorted data |
| **Union All** | Stack rows | Combine similar data |
| **Aggregate** | Summarize | Daily/monthly summaries |
| **Sort** | Sort data | Required before Merge |
| **OLE DB Destination** | Write to database | Target tables |
| **Flat File Destination** | Write to CSV | Export/error logging |

---

## Next Steps

Continue to: **[06-banking-dw-design.md](./06-banking-dw-design.md)** for a complete banking data warehouse design.

---

*Last Updated: September 2026*
*Author: Buffy (Codebuff)*
