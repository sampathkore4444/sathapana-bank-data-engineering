# ⚡ Performance Tuning Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Index Optimization](#2-index-optimization)
3. [Query Optimization](#3-query-optimization)
4. [Partitioning](#4-partitioning)
5. [Statistics & Maintenance](#5-statistics--maintenance)
6. [ETL Performance](#6-etl-performance)
7. [Monitoring Performance](#7-monitoring-performance)

---

## 1. Overview

Performance tuning ensures the data warehouse runs efficiently for both ETL loads and analytical queries.

```
┌─────────────────────────────────────────────────────────────────┐
│                    PERFORMANCE OPTIMIZATION AREAS                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │   INDEXES   │  │   QUERIES   │  │PARTITIONING │            │
│  │             │  │             │  │             │            │
│  │ • Design    │  │ • Rewrite   │  │ • Date-based│            │
│  │ • Maintain  │  │ • Avoid     │  │ • Archive   │            │
│  │ • Monitor   │  │   cursors   │  │   old data  │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │STATISTICS   │  │   ETL       │  │  MONITORING │            │
│  │             │  │             │  │             │            │
│  │ • Update    │  │ • Batch     │  │ • DMVs      │            │
│  │ • Auto      │  │ • Parallel  │  │ • Wait stats│            │
│  │   create    │  │ • Incremental│ │ • Profiler  │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Index Optimization

### Index Design for Data Warehouse

```sql
-- ============================================================
-- DIMENSION TABLE INDEXES
-- ============================================================

-- Primary lookup index (business key)
CREATE NONCLUSTERED INDEX IX_dim_customer_code 
ON dw.dim_customer(customer_code)
INCLUDE (customer_key, is_current);

-- SCD query index
CREATE NONCLUSTERED INDEX IX_dim_customer_scd 
ON dw.dim_customer(customer_code, is_current)
INCLUDE (first_name, last_name, effective_date, expiry_date);

-- ============================================================
-- FACT TABLE INDEXES
-- ============================================================

-- Date-based queries (most common)
CREATE NONCLUSTERED INDEX IX_fact_transactions_date 
ON dw.fact_transactions(date_key)
INCLUDE (account_key, customer_key, amount, transaction_type);

-- Customer analysis
CREATE NONCLUSTERED INDEX IX_fact_transactions_customer 
ON dw.fact_transactions(customer_key)
INCLUDE (date_key, amount, transaction_type);

-- Account analysis
CREATE NONCLUSTERED INDEX IX_fact_transactions_account 
ON dw.fact_transactions(account_key)
INCLUDE (date_key, amount);

-- Covering index for common report
CREATE NONCLUSTERED INDEX IX_fact_transactions_covering
ON dw.fact_transactions(date_key, transaction_type)
INCLUDE (customer_key, account_key, amount, amount_usd, currency);
```

### Index Maintenance

```sql
-- ============================================================
-- INDEX MAINTENANCE PROCEDURE
-- ============================================================

CREATE PROCEDURE perf.usp_MaintainIndexes
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TableName NVARCHAR(200);
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Find fragmented indexes
    DECLARE index_cursor CURSOR FOR
        SELECT 
            QUOTENAME(s.name) + '.' + QUOTENAME(t.name) AS TableName
        FROM sys.indexes i
        JOIN sys.tables t ON i.object_id = t.object_id
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE i.index_id > 0
        AND i.avg_fragmentation_in_percent > 30
        AND t.is_ms_shipped = 0;
    
    OPEN index_cursor;
    FETCH NEXT FROM index_cursor INTO @TableName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = 'ALTER INDEX ALL ON ' + @TableName + ' REBUILD WITH (FILLFACTOR = 80)';
        EXEC sp_executesql @SQL;
        
        PRINT 'Rebuilt indexes on ' + @TableName;
        
        FETCH NEXT FROM index_cursor INTO @TableName;
    END
    
    CLOSE index_cursor;
    DEALLOCATE index_cursor;
    
    -- Update statistics
    EXEC sp_updatestats;
    
    PRINT 'Index maintenance completed.';
END;
GO
```

---

## 3. Query Optimization

### Common Query Patterns

```sql
-- ============================================================
-- OPTIMIZED QUERIES
-- ============================================================

-- BAD: Using functions on indexed columns
SELECT * FROM dw.fact_transactions
WHERE YEAR(transaction_date) = 2024;

-- GOOD: Using date range
SELECT * FROM dw.fact_transactions
WHERE transaction_date >= '2024-01-01'
AND transaction_date < '2025-01-01';

-- BAD: Using NOT IN
SELECT * FROM dw.dim_customer
WHERE customer_key NOT IN (SELECT customer_key FROM dw.fact_transactions);

-- GOOD: Using NOT EXISTS
SELECT * FROM dw.dim_customer c
WHERE NOT EXISTS (
    SELECT 1 FROM dw.fact_transactions t
    WHERE t.customer_key = c.customer_key
);

-- BAD: Using SELECT *
SELECT * FROM dw.fact_transactions;

-- GOOD: Selecting only needed columns
SELECT transaction_code, amount, transaction_type
FROM dw.fact_transactions;
```

### Execution Plan Analysis

```sql
-- View execution plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Your query here
SELECT c.customer_code, c.first_name, SUM(t.amount)
FROM dw.dim_customer c
JOIN dw.fact_transactions t ON c.customer_key = t.customer_key
WHERE c.is_current = 1
GROUP BY c.customer_code, c.first_name;

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
```

---

## 4. Partitioning

### Date-Based Partitioning

```sql
-- ============================================================
-- PARTITION FUNCTION AND SCHEME
-- ============================================================

-- Create partition function (yearly)
CREATE PARTITION FUNCTION pf_Yearly (INT)
AS RANGE RIGHT FOR VALUES (
    20220101, 20230101, 20240101, 20250101, 20260101
);

-- Create partition scheme
CREATE PARTITION SCHEME ps_Yearly
AS PARTITION pf_Yearly
ALL TO ([PRIMARY]);

-- Apply to fact table
CREATE TABLE dw.fact_transactions_partitioned (
    transaction_key BIGINT IDENTITY(1,1),
    transaction_code VARCHAR(30),
    date_key INT,
    account_key INT,
    customer_key INT,
    amount DECIMAL(18,2),
    ...
) ON ps_Yearly(date_key);
```

### Partition Management

```sql
-- ============================================================
-- PARTITION MAINTENANCE
-- ============================================================

-- Add new partition for next year
ALTER PARTITION FUNCTION pf_Yearly()
SPLIT RANGE (20270101);

-- Archive old partition
ALTER TABLE dw.fact_transactions
SWITCH PARTITION 1 TO dw.fact_transactions_archive;

-- View partition info
SELECT 
    p.partition_number,
    p.rows,
    rv.value AS partition_value
FROM sys.partitions p
JOIN sys.partition_range_values rv 
    ON p.partition_id = rv.partition_id
WHERE p.object_id = OBJECT_ID('dw.fact_transactions');
```

---

## 5. Statistics & Maintenance

### Update Statistics

```sql
-- ============================================================
-- STATISTICS MAINTENANCE
-- ============================================================

-- Update all statistics
EXEC sp_updatestats;

-- Update specific table statistics
UPDATE STATISTICS dw.dim_customer;
UPDATE STATISTICS dw.fact_transactions;

-- View statistics info
SELECT 
    OBJECT_NAME(object_id) AS table_name,
    name AS stats_name,
    STATS_DATE(object_id, stats_id) AS last_updated
FROM sys.stats
WHERE object_id = OBJECT_ID('dw.dim_customer');
```

### Database Maintenance Plan

```sql
-- ============================================================
-- COMPREHENSIVE MAINTENANCE PROCEDURE
-- ============================================================

CREATE PROCEDURE perf.usp_DatabaseMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    
    PRINT 'Starting database maintenance...';
    
    -- 1. Update statistics
    PRINT '1. Updating statistics...';
    EXEC sp_updatestats;
    
    -- 2. Rebuild fragmented indexes
    PRINT '2. Rebuilding fragmented indexes...';
    EXEC perf.usp_MaintainIndexes;
    
    -- 3. Check database integrity
    PRINT '3. Checking database integrity...';
    DBCC CHECKDB ('sathapana_dwh') WITH NO_INFOMSGS;
    
    -- 4. Update table sizes
    PRINT '4. Updating table size tracking...';
    INSERT INTO audit.table_sizes (table_name, row_count, size_mb)
    SELECT 
        t.name,
        p.rows,
        CAST(ROUND(SUM(a.total_pages) * 8 / 1024.0, 2) AS DECIMAL(10,2))
    FROM sys.tables t
    JOIN sys.indexes i ON t.object_id = i.object_id
    JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    JOIN sys.allocation_units a ON p.partition_id = a.container_id
    WHERE t.is_ms_shipped = 0
    GROUP BY t.name, p.rows;
    
    DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
    PRINT 'Maintenance completed in ' + CAST(@Duration AS VARCHAR(10)) + ' seconds.';
END;
GO
```

---

## 6. ETL Performance

### Batch Processing

```sql
-- ============================================================
-- BATCH PROCESSING FOR LARGE TABLES
-- ============================================================

CREATE PROCEDURE perf.usp_BatchInsert
    @BatchSize INT = 50000
AS
BEGIN
    DECLARE @RowsInserted INT = 1;
    DECLARE @TotalRows BIGINT = 0;
    
    WHILE @RowsInserted > 0
    BEGIN
        INSERT INTO dw.fact_transactions (...)
        SELECT TOP (@BatchSize) ...
        FROM staging.stg_transactions s
        WHERE NOT EXISTS (
            SELECT 1 FROM dw.fact_transactions d
            WHERE d.transaction_code = s.transaction_code
        );
        
        SET @RowsInserted = @@ROWCOUNT;
        SET @TotalRows += @RowsInserted;
        
        PRINT 'Batch: ' + CAST(@RowsInserted AS VARCHAR(10)) + ' rows';
    END
    
    PRINT 'Total rows inserted: ' + CAST(@TotalRows AS VARCHAR(10));
END;
GO
```

---

## 7. Monitoring Performance

### Performance Views

```sql
-- ============================================================
-- PERFORMANCE MONITORING VIEWS
-- ============================================================

-- Slowest queries
CREATE VIEW perf.vw_SlowestQueries
AS
SELECT TOP 100
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
GO

-- Missing indexes
CREATE VIEW perf.vw_MissingIndexes
AS
SELECT
    CONVERT(DECIMAL(18,2), migs.avg_total_user_cost * 
        migs.avg_user_impact * (migs.user_seeks + migs.user_scans)) AS improvement_measure,
    'CREATE INDEX IX_' + OBJECT_NAME(mid.object_id) + '_' 
        + CAST(mid.index_handle AS VARCHAR) AS create_index_statement,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;
GO
```

---

## Quick Reference

### Performance Commands
```sql
-- Check index fragmentation
SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED');

-- Check wait stats
SELECT * FROM sys.dm_os_wait_stats ORDER BY wait_time_ms DESC;

-- Check blocking
SELECT * FROM sys.dm_tran_locks;

-- Kill blocking session
KILL <spid>;
```

---

*Created: September 2024*
