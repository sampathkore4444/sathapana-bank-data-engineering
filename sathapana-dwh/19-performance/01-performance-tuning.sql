-- ============================================================================
-- SATHAPANA BANK - PERFORMANCE TUNING
-- ============================================================================
-- Purpose: Optimize query performance with indexes and statistics
-- Author: DWH Development Team
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. RECOMMENDED INDEXES FOR FACT TABLES
-- ============================================================================

-- Fact Transactions indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_txn_date_account')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_txn_date_account 
    ON dw.fact_transactions (transaction_date_key, account_key)
    INCLUDE (amount, amount_usd, transaction_type_key);
    PRINT '✓ Index IX_fact_txn_date_account created';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_txn_customer')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_txn_customer 
    ON dw.fact_transactions (customer_key, transaction_date_key)
    INCLUDE (amount, channel_key);
    PRINT '✓ Index IX_fact_txn_customer created';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_txn_branch')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_txn_branch 
    ON dw.fact_transactions (branch_key, transaction_date_key)
    INCLUDE (amount, transaction_type_key);
    PRINT '✓ Index IX_fact_txn_branch created';
END

-- Fact Loan Portfolio indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_loan_date_branch')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_loan_date_branch 
    ON dw.fact_loan_portfolio (snapshot_date_key, branch_key)
    INCLUDE (outstanding_principal, provision_amount, days_past_due, risk_classification);
    PRINT '✓ Index IX_fact_loan_date_branch created';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_loan_customer')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_loan_customer 
    ON dw.fact_loan_portfolio (customer_key, snapshot_date_key)
    INCLUDE (outstanding_principal, loan_status);
    PRINT '✓ Index IX_fact_loan_customer created';
END

-- Fact Deposit Snapshot indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_deposit_date_branch')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_deposit_date_branch 
    ON dw.fact_deposit_snapshot (snapshot_date_key, branch_key)
    INCLUDE (balance, interest_earned);
    PRINT '✓ Index IX_fact_deposit_date_branch created';
END

-- Fact Account Daily Snapshot indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_fact_snapshot_date_account')
BEGIN
    CREATE NONCLUSTERED INDEX IX_fact_snapshot_date_account 
    ON dw.fact_account_daily_snapshot (snapshot_date_key, account_key)
    INCLUDE (closing_balance, total_debits, total_credits);
    PRINT '✓ Index IX_fact_snapshot_date_account created';
END

-- ============================================================================
-- 2. RECOMMENDED INDEXES FOR DIMENSION TABLES
-- ============================================================================

-- Dim Customer indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_dim_customer_segment')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_customer_segment 
    ON dw.dim_customer (customer_segment, is_current)
    INCLUDE (customer_code, full_name, province);
    PRINT '✓ Index IX_dim_customer_segment created';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_dim_customer_province')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_customer_province 
    ON dw.dim_customer (province, is_current)
    INCLUDE (customer_segment, risk_rating);
    PRINT '✓ Index IX_dim_customer_province created';
END

-- Dim Account indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_dim_account_type')
BEGIN
    CREATE NONCLUSTERED INDEX IX_dim_account_type 
    ON dw.dim_account (account_type, is_current)
    INCLUDE (account_number, customer_key, branch_key);
    PRINT '✓ Index IX_dim_account_type created';
END

-- ============================================================================
-- 3. STATISTICS UPDATE PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE dw.usp_UpdateStatistics
    @SampleRate DECIMAL(5,2) = 100.0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TableName VARCHAR(200);
    DECLARE @SQL NVARCHAR(MAX);
    
    PRINT 'Updating statistics...';
    PRINT 'Sample rate: ' + CAST(@SampleRate AS VARCHAR) + '%';
    
    -- Update statistics for all tables
    DECLARE table_cursor CURSOR FOR
    SELECT TABLE_SCHEMA + '.' + TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_TYPE = 'BASE TABLE'
    AND TABLE_SCHEMA IN ('dw', 'audit');
    
    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @TableName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = 'UPDATE STATISTICS ' + @TableName + ' WITH SAMPLE ' + CAST(@SampleRate AS VARCHAR) + ' PERCENT';
        
        BEGIN TRY
            EXEC sp_executesql @SQL;
            PRINT '✓ Updated: ' + @TableName;
        END TRY
        BEGIN CATCH
            PRINT '✗ Failed: ' + @TableName + ' - ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM table_cursor INTO @TableName;
    END
    
    CLOSE table_cursor;
    DEALLOCATE table_cursor;
    
    PRINT 'Statistics update completed';
END;
GO

-- ============================================================================
-- 4. INDEX MAINTENANCE PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE dw.usp_MaintainIndexes
    @FragmentationThreshold DECIMAL(5,2) = 30.0
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Running index maintenance...';
    PRINT 'Rebuild threshold: ' + CAST(@FragmentationThreshold AS VARCHAR) + '%';
    
    -- Rebuild fragmented indexes
    DECLARE @SQL NVARCHAR(MAX) = '';
    
    SELECT @SQL = @SQL + 
        'ALTER INDEX ' + i.name + ' ON ' + SCHEMA_NAME(t.schema_id) + '.' + t.name + ' REBUILD;' + CHAR(13)
    FROM sys.indexes i
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    INNER JOIN sys.dm_db_index_physical_stats(DB_ID(), i.object_id, i.index_id, NULL, 'LIMITED') ps
        ON i.object_id = ps.object_id AND i.index_id = ps.index_id
    WHERE i.index_id > 0
    AND i.is_disabled = 0
    AND ps.avg_fragmentation_in_percent > @FragmentationThreshold;
    
    IF @SQL != ''
    BEGIN
        EXEC sp_executesql @SQL;
        PRINT '✓ Rebuilt fragmented indexes';
    END
    ELSE
    BEGIN
        PRINT 'No indexes need rebuilding';
    END
    
    -- Update statistics after index maintenance
    EXEC dw.usp_UpdateStatistics;
    
    PRINT 'Index maintenance completed';
END;
GO

-- ============================================================================
-- 5. QUERY PERFORMANCE MONITORING
-- ============================================================================

CREATE OR ALTER VIEW dw.vw_QueryPerformance AS
SELECT TOP 100
    qs.execution_count,
    qs.total_worker_time / 1000 AS total_cpu_ms,
    qs.total_elapsed_time / 1000 AS total_elapsed_ms,
    qs.total_logical_reads,
    qs.total_physical_reads,
    SUBSTRING(qt.text, (qs.statement_start_offset/2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(qt.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset)/2) + 1) AS query_text,
    qp.query_plan
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE qt.dbid = DB_ID()
ORDER BY qs.total_logical_reads DESC;
GO

-- ============================================================================
-- 6. TABLE SIZE MONITORING
-- ============================================================================

CREATE OR ALTER VIEW dw.vw_TableSizes AS
SELECT 
    s.name AS schema_name,
    t.name AS table_name,
    p.rows AS row_count,
    CAST(ROUND(SUM(a.total_pages) * 8 / 1024.0, 2) AS DECIMAL(18,2)) AS total_mb,
    CAST(ROUND(SUM(a.used_pages) * 8 / 1024.0, 2) AS DECIMAL(18,2)) AS used_mb,
    CAST(ROUND((SUM(a.total_pages) - SUM(a.used_pages)) * 8 / 1024.0, 2) AS DECIMAL(18,2)) AS unused_mb
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0 AND i.OBJECT_ID > 255
GROUP BY s.name, t.name, p.rows
ORDER BY SUM(a.total_pages) DESC;
GO

-- ============================================================================
-- 7. COMPREHENSIVE MAINTENANCE PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE dw.usp_ComprehensiveMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '========================================';
    PRINT 'COMPREHENSIVE DWH MAINTENANCE';
    PRINT '========================================';
    DECLARE @StartTime DATETIME = GETDATE();
    
    -- Step 1: Update statistics
    PRINT '';
    PRINT 'Step 1: Updating statistics...';
    EXEC dw.usp_UpdateStatistics 100;
    
    -- Step 2: Rebuild indexes
    PRINT '';
    PRINT 'Step 2: Rebuilding indexes...';
    EXEC dw.usp_MaintainIndexes 30;
    
    -- Step 3: Check fragmentation
    PRINT '';
    PRINT 'Step 3: Checking fragmentation...';
    SELECT 
        OBJECT_NAME(ips.object_id) AS table_name,
        i.name AS index_name,
        ips.avg_fragmentation_in_percent,
        ips.page_count
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.avg_fragmentation_in_percent > 10
    ORDER BY ips.avg_fragmentation_in_percent DESC;
    
    -- Step 4: Table sizes
    PRINT '';
    PRINT 'Step 4: Table sizes...';
    SELECT * FROM dw.vw_TableSizes;
    
    -- Step 5: Truncate audit logs (older than 90 days)
    PRINT '';
    PRINT 'Step 5: Cleaning up old audit records...';
    DELETE FROM audit.etl_log WHERE start_time < DATEADD(DAY, -90, GETDATE());
    DELETE FROM audit.data_quality WHERE check_date < DATEADD(DAY, -90, GETDATE());
    
    DECLARE @EndTime DATETIME = GETDATE();
    DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, @EndTime);
    
    PRINT '';
    PRINT '========================================';
    PRINT 'MAINTENANCE COMPLETED';
    PRINT 'Duration: ' + CAST(@Duration AS VARCHAR) + ' seconds';
    PRINT '========================================';
END;
GO

-- ============================================================================
-- 8. VERIFY SETUP
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'PERFORMANCE TUNING SETUP COMPLETED';
PRINT '================================================';
PRINT '';
PRINT 'Indexes Created:';
SELECT COUNT(*) AS index_count 
FROM sys.indexes 
WHERE name LIKE 'IX_fact_%' OR name LIKE 'IX_dim_%';
PRINT '';
PRINT 'Procedures:';
PRINT '  - usp_UpdateStatistics: Update table statistics';
PRINT '  - usp_MaintainIndexes: Rebuild fragmented indexes';
PRINT '  - usp_ComprehensiveMaintenance: Full maintenance';
PRINT '';
PRINT 'Views:';
PRINT '  - vw_QueryPerformance: Monitor slow queries';
PRINT '  - vw_TableSizes: Track table sizes';
PRINT '';
PRINT 'Recommended Schedule:';
PRINT '  - Statistics: Daily';
PRINT '  - Index maintenance: Weekly';
PRINT '  - Full maintenance: Weekly (Sunday 3 AM)';
PRINT '';
PRINT '================================================';
GO
