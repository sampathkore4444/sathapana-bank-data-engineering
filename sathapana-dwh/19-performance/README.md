# 19 - Performance Tuning

## Overview

This directory contains indexing strategies, statistics management, and query optimization procedures for the data warehouse.

## Files

| File | Purpose |
|------|---------|
| `01-performance-tuning.sql` | Index creation, statistics updates, and optimization procedures |

## Indexing Strategy

### Fact Tables

| Table | Index | Columns | Purpose |
|-------|-------|---------|---------|
| `fact_transactions` | `IX_fact_txn_date_account` | `transaction_date_key, account_key` INCLUDE `amount, amount_usd` | Date range + account lookups |
| `fact_transactions` | `IX_fact_txn_branch_date` | `branch_key, transaction_date_key` INCLUDE `amount` | Branch reporting |
| `fact_account_daily_snapshot` | `IX_fact_daily_acct_date` | `account_key, snapshot_date_key` INCLUDE `closing_balance` | Account history |
| `fact_loan_portfolio` | `IX_fact_loan_branch_date` | `branch_key, snapshot_date_key` | Loan reporting by branch |
| `fact_deposit_snapshot` | `IX_fact_deposit_acct_date` | `account_key, snapshot_date_key` | Deposit history |

### Dimension Tables

| Table | Index | Columns | Purpose |
|-------|-------|---------|---------|
| `dim_customer` | `IX_dim_cust_current` | `customer_code` WHERE `is_current = 1` | Current record lookup |
| `dim_account` | `IX_dim_acct_current` | `account_code` WHERE `is_current = 1` | Current record lookup |
| `dim_employee` | `IX_dim_emp_current` | `employee_code` WHERE `is_current = 1` | Current record lookup |
| `dim_date` | `IX_dim_date_full` | `full_date` UNIQUE | Date lookups |

### Filtered Indexes (SCD Type 2)

```sql
-- Only index current records (most queries)
CREATE NONCLUSTERED INDEX IX_dim_customer_current
ON dw.dim_customer (customer_code)
WHERE is_current = 1;
```

## Statistics Management

### Auto-Create Statistics

```sql
-- Enable auto-create (recommended for DW)
ALTER DATABASE sathapana_dwh SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE sathapana_dwh SET AUTO_UPDATE_STATISTICS ON;
```

### Manual Statistics Update

```sql
-- Update statistics on all tables
EXEC sp_updatestats;

-- Update specific table
UPDATE STATISTICS dw.fact_transactions WITH FULLSCAN;
```

### Statistics Maintenance Procedure

```sql
-- Automated via audit.usp_PerformMaintenance
-- Runs weekly (Sunday 3:00 AM) via SQL Server Agent
```

## Query Optimization Tips

### 1. Use Date Key Filters

```sql
-- ✅ Good: Uses index
SELECT * FROM dw.fact_transactions
WHERE transaction_date_key BETWEEN 20260101 AND 20260131;

-- ❌ Bad: Forces conversion
SELECT * FROM dw.fact_transactions
WHERE transaction_date >= '2026-01-01';
```

### 2. Use SARGable Predicates

```sql
-- ✅ Good: Can use index
WHERE YEAR(full_date) = 2026  -- If date_key filter exists
WHERE transaction_date_key >= 20260101

-- ❌ Bad: Cannot use index
WHERE DATEPART(YEAR, full_date) = 2026
```

### 3. Avoid SELECT * in Facts

```sql
-- ✅ Good: Only needed columns
SELECT transaction_key, amount, amount_usd
FROM dw.fact_transactions;

-- ❌ Bad: Returns all columns
SELECT * FROM dw.fact_transactions;
```

### 4. Use Columnstore for Aggregations

```sql
-- For large fact tables with analytical queries
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_fact_txn
ON dw.fact_transactions (transaction_date_key, account_key, amount, amount_usd);
```

## Index Maintenance

### Check Fragmentation

```sql
SELECT
    OBJECT_NAME(ips.object_id) AS table_name,
    i.name AS index_name,
    ips.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
ORDER BY ips.avg_fragmentation_in_percent DESC;
```

### Rebuild / Reorganize

```sql
-- Rebuild (offline, full)
ALTER INDEX ALL ON dw.fact_transactions REBUILD;

-- Reorganize (online, lighter)
ALTER INDEX ALL ON dw.fact_transactions REORGANIZE;

-- Threshold: Rebuild if > 30%, Reorganize if > 10%
```

## Performance Monitoring

### Query Statistics

```sql
-- Top 10 longest running queries
SELECT TOP 10
    qs.total_elapsed_time / qs.execution_count AS avg_elapsed_time,
    qs.execution_count,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2)+1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_elapsed_time DESC;
```

### Index Usage

```sql
-- Find unused indexes
SELECT
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    ius.user_seeks, ius.user_scans, ius.user_lookups
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id AND i.index_id = ius.index_id
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
AND (ius.user_seeks IS NULL AND ius.user_scans IS NULL);
```

## Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| ETL Duration | < 4 hours | > 6 hours |
| Average Query Time | < 2 seconds | > 10 seconds |
| Index Fragmentation | < 10% | > 30% |
| Statistics Freshness | < 7 days | > 14 days |
| Table Scan Ratio | < 5% | > 20% |

## Execution

```sql
-- Apply performance tuning
:19-performance/01-performance-tuning.sql
```

## Notes

- Indexes are created with `IF NOT EXISTS` to be idempotent
- Filtered indexes on SCD Type 2 tables significantly improve current-record lookups
- Columnstore indexes benefit analytical queries but may slow down point lookups
- Monitor index usage to identify and remove unused indexes
- Statistics should be updated after large data loads
