-- ============================================================================
-- SATHAPANA BANK - MONITORING & LOGGING FRAMEWORK
-- ============================================================================
-- Purpose: Create monitoring and logging framework for DWH operations
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. MONITORING DASHBOARD VIEW
-- ============================================================================
CREATE OR ALTER VIEW audit.vw_monitoring_dashboard AS
SELECT 
    -- ETL Job Status
    (SELECT COUNT(*) FROM audit.etl_log WHERE CAST(start_time AS DATE) = CAST(GETDATE() AS DATE)) AS jobs_run_today,
    (SELECT COUNT(*) FROM audit.etl_log WHERE CAST(start_time AS DATE) = CAST(GETDATE() AS DATE) AND status = 'COMPLETED') AS jobs_completed,
    (SELECT COUNT(*) FROM audit.etl_log WHERE CAST(start_time AS DATE) = CAST(GETDATE() AS DATE) AND status = 'FAILED') AS jobs_failed,
    (SELECT COUNT(*) FROM audit.etl_log WHERE CAST(start_time AS DATE) = CAST(GETDATE() AS DATE) AND status = 'RUNNING') AS jobs_running,
    
    -- Data Quality Status
    (SELECT COUNT(*) FROM audit.data_quality WHERE CAST(check_date AS DATE) = CAST(GETDATE() AS DATE)) AS quality_checks_run,
    (SELECT COUNT(*) FROM audit.data_quality WHERE CAST(check_date AS DATE) = CAST(GETDATE() AS DATE) AND status = 'PASS') AS quality_passed,
    (SELECT COUNT(*) FROM audit.data_quality WHERE CAST(check_date AS DATE) = CAST(GETDATE() AS DATE) AND status = 'FAIL') AS quality_failed,
    
    -- Data Volume
    (SELECT COUNT(*) FROM dw.dim_customer WHERE is_current = 1) AS total_customers,
    (SELECT COUNT(*) FROM dw.dim_account WHERE is_current = 1) AS total_accounts,
    (SELECT COUNT(*) FROM dw.fact_transactions) AS total_transactions,
    (SELECT COUNT(*) FROM dw.fact_loan_portfolio) AS total_loans,
    
    -- Latest ETL Run
    (SELECT MAX(end_time) FROM audit.etl_log WHERE status = 'COMPLETED') AS last_successful_run,
    (SELECT MAX(end_time) FROM audit.etl_log WHERE status = 'FAILED') AS last_failed_run,
    
    -- Current Time
    GETDATE() AS dashboard_time;

-- ============================================================================
-- 2. ETL JOB HISTORY VIEW
-- ============================================================================
CREATE OR ALTER VIEW audit.vw_etl_job_history AS
SELECT 
    l.batch_id,
    l.step_name,
    l.table_name,
    l.operation,
    l.records_affected,
    l.status,
    l.error_message,
    l.start_time,
    l.end_time,
    l.duration_seconds,
    l.executed_by,
    -- Calculate performance metrics
    CASE 
        WHEN l.duration_seconds > 300 THEN 'SLOW'
        WHEN l.duration_seconds > 60 THEN 'MODERATE'
        ELSE 'FAST'
    END AS performance_rating,
    -- Calculate records per second
    CASE 
        WHEN l.duration_seconds > 0 THEN l.records_affected / l.duration_seconds
        ELSE 0
    END AS records_per_second
FROM audit.etl_log l
ORDER BY l.start_time DESC;

-- ============================================================================
-- 3. DATA FRESHNESS MONITOR
-- ============================================================================
CREATE OR ALTER VIEW audit.vw_data_freshness AS
SELECT 
    'dim_customer' AS table_name,
    MAX(modified_date) AS last_modified,
    DATEDIFF(HOUR, MAX(modified_date), GETDATE()) AS hours_since_update,
    CASE 
        WHEN DATEDIFF(HOUR, MAX(modified_date), GETDATE()) < 24 THEN 'FRESH'
        WHEN DATEDIFF(HOUR, MAX(modified_date), GETDATE()) < 72 THEN 'STALE'
        ELSE 'OUTDATED'
    END AS freshness_status
FROM dw.dim_customer
UNION ALL
SELECT 
    'dim_account',
    MAX(modified_date),
    DATEDIFF(HOUR, MAX(modified_date), GETDATE()),
    CASE 
        WHEN DATEDIFF(HOUR, MAX(modified_date), GETDATE()) < 24 THEN 'FRESH'
        WHEN DATEDIFF(HOUR, MAX(modified_date), GETDATE()) < 72 THEN 'STALE'
        ELSE 'OUTDATED'
    END
FROM dw.dim_account
UNION ALL
SELECT 
    'fact_transactions',
    MAX(etl_load_date),
    DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()),
    CASE 
        WHEN DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()) < 24 THEN 'FRESH'
        WHEN DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()) < 72 THEN 'STALE'
        ELSE 'OUTDATED'
    END
FROM dw.fact_transactions
UNION ALL
SELECT 
    'fact_loan_portfolio',
    MAX(etl_load_date),
    DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()),
    CASE 
        WHEN DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()) < 24 THEN 'FRESH'
        WHEN DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()) < 72 THEN 'STALE'
        ELSE 'OUTDATED'
    END
FROM dw.fact_loan_portfolio;

-- ============================================================================
-- 4. TABLE SIZE MONITOR
-- ============================================================================
CREATE OR ALTER VIEW audit.vw_table_sizes AS
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

-- ============================================================================
-- 5. ERROR TRACKING PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_TrackError
    @BatchID UNIQUEIDENTIFIER,
    @SourceTable VARCHAR(100),
    @ErrorType VARCHAR(50),
    @ErrorMessage NVARCHAR(MAX),
    @ErrorRow NVARCHAR(MAX) = NULL,
    @Severity VARCHAR(20) = 'ERROR'
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO sathapana_staging.staging.error_log (
        batch_id, source_table, error_type, error_message, error_row, severity
    )
    VALUES (
        @BatchID, @SourceTable, @ErrorType, @ErrorMessage, @ErrorRow, @Severity
    );
    
    -- Also log to audit table
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation, status, error_message
    )
    VALUES (
        @BatchID, 'Error_Tracked', @SourceTable, @ErrorType, 'FAILED', @ErrorMessage
    );
    
    PRINT 'Error tracked: ' + @ErrorType + ' on ' + @SourceTable;
END;
GO

-- ============================================================================
-- 6. ETL PERFORMANCE REPORT
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_ETLPerformanceReport
    @DaysBack INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '================================================';
    PRINT 'ETL PERFORMANCE REPORT';
    PRINT '================================================';
    PRINT 'Period: Last ' + CAST(@DaysBack AS VARCHAR(10)) + ' days';
    PRINT 'Generated: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '';
    
    -- Overall statistics
    SELECT 
        COUNT(*) AS total_jobs,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed_jobs,
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed_jobs,
        CAST(SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS success_rate,
        AVG(duration_seconds) AS avg_duration_seconds,
        SUM(records_affected) AS total_records_processed
    FROM audit.etl_log
    WHERE start_time >= DATEADD(DAY, -@DaysBack, GETDATE());
    
    PRINT '';
    PRINT '--- Performance by Table ---';
    SELECT 
        table_name,
        COUNT(*) AS execution_count,
        AVG(duration_seconds) AS avg_duration,
        MAX(duration_seconds) AS max_duration,
        SUM(records_affected) AS total_records,
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failure_count
    FROM audit.etl_log
    WHERE start_time >= DATEADD(DAY, -@DaysBack, GETDATE())
    AND table_name IS NOT NULL
    GROUP BY table_name
    ORDER BY avg_duration DESC;
    
    PRINT '';
    PRINT '--- Daily Job Counts ---';
    SELECT 
        CAST(start_time AS DATE) AS job_date,
        COUNT(*) AS total_jobs,
        SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS completed,
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failed
    FROM audit.etl_log
    WHERE start_time >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY CAST(start_time AS DATE)
    ORDER BY job_date DESC;
    
    PRINT '';
    PRINT '--- Recent Failures ---';
    SELECT TOP 10
        step_name,
        table_name,
        error_message,
        start_time,
        duration_seconds
    FROM audit.etl_log
    WHERE status = 'FAILED'
    AND start_time >= DATEADD(DAY, -@DaysBack, GETDATE())
    ORDER BY start_time DESC;
    
    PRINT '';
    PRINT '================================================';
    PRINT 'END OF ETL PERFORMANCE REPORT';
    PRINT '================================================';
END;
GO

-- ============================================================================
-- 7. DATA GROWTH TRACKING
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_TrackDataGrowth
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Tracking Data Growth...';
    
    -- Capture current row counts
    INSERT INTO audit.row_counts (table_name, row_count)
    SELECT 'dim_customer', COUNT(*) FROM dw.dim_customer WHERE is_current = 1
    UNION ALL
    SELECT 'dim_account', COUNT(*) FROM dw.dim_account WHERE is_current = 1
    UNION ALL
    SELECT 'dim_branch', COUNT(*) FROM dw.dim_branch WHERE is_current = 1
    UNION ALL
    SELECT 'dim_product', COUNT(*) FROM dw.dim_product
    UNION ALL
    SELECT 'fact_transactions', COUNT(*) FROM dw.fact_transactions
    UNION ALL
    SELECT 'fact_loan_portfolio', COUNT(*) FROM dw.fact_loan_portfolio
    UNION ALL
    SELECT 'fact_deposit_snapshot', COUNT(*) FROM dw.fact_deposit_snapshot
    UNION ALL
    SELECT 'fact_account_daily_snapshot', COUNT(*) FROM dw.fact_account_daily_snapshot;
    
    PRINT 'Data growth tracking completed.';
END;
GO

-- ============================================================================
-- 8. ALERTING PROCEDURE (Simulated)
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_CheckAlerts
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Checking for alerts...';
    
    -- Check for failed ETL jobs
    IF EXISTS (SELECT 1 FROM audit.etl_log WHERE status = 'FAILED' AND start_time >= DATEADD(HOUR, -1, GETDATE()))
    BEGIN
        PRINT '⚠️ ALERT: ETL job failed in the last hour!';
        SELECT 
            step_name,
            table_name,
            error_message,
            start_time
        FROM audit.etl_log
        WHERE status = 'FAILED'
        AND start_time >= DATEADD(HOUR, -1, GETDATE());
    END
    
    -- Check for data quality failures
    IF EXISTS (SELECT 1 FROM audit.data_quality WHERE status = 'FAIL' AND check_date >= DATEADD(HOUR, -1, GETDATE()))
    BEGIN
        PRINT '⚠️ ALERT: Data quality check failed in the last hour!';
        SELECT 
            check_name,
            table_name,
            failing_rows,
            pass_rate
        FROM audit.data_quality
        WHERE status = 'FAIL'
        AND check_date >= DATEADD(HOUR, -1, GETDATE());
    END
    
    -- Check for stale data
    IF EXISTS (
        SELECT 1 FROM audit.vw_data_freshness 
        WHERE freshness_status = 'OUTDATED'
    )
    BEGIN
        PRINT '⚠️ ALERT: Data is outdated!';
        SELECT * FROM audit.vw_data_freshness WHERE freshness_status = 'OUTDATED';
    END
    
    PRINT 'Alert check completed.';
END;
GO

-- ============================================================================
-- 9. MAINTENANCE PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_PerformMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Performing DWH Maintenance...';
    
    -- Update statistics on all tables
    PRINT 'Updating statistics...';
    EXEC sp_updatestats;
    
    -- Rebuild fragmented indexes
    PRINT 'Rebuilding fragmented indexes...';
    DECLARE @sql NVARCHAR(MAX) = '';
    
    SELECT @sql = @sql + 
        'ALTER INDEX ' + i.name + ' ON ' + SCHEMA_NAME(t.schema_id) + '.' + t.name + ' REBUILD;' + CHAR(13)
    FROM sys.indexes i
    INNER JOIN sys.tables t ON i.object_id = t.object_id
    WHERE i.index_id > 0
    AND i.is_disabled = 0
    AND EXISTS (
        SELECT 1 FROM sys.dm_db_index_physical_stats(DB_ID(), i.object_id, i.index_id, NULL, 'LIMITED') ps
        WHERE ps.avg_fragmentation_in_percent > 30
    );
    
    IF @sql != ''
    BEGIN
        EXEC sp_executesql @sql;
        PRINT 'Indexes rebuilt.';
    END
    ELSE
    BEGIN
        PRINT 'No indexes need rebuilding.';
    END
    
    -- Clean up old audit records (keep 90 days)
    PRINT 'Cleaning up old audit records...';
    DELETE FROM audit.etl_log WHERE start_time < DATEADD(DAY, -90, GETDATE());
    DELETE FROM audit.data_quality WHERE check_date < DATEADD(DAY, -90, GETDATE());
    DELETE FROM audit.row_counts WHERE count_date < DATEADD(DAY, -90, GETDATE());
    
    -- Track current data growth
    EXEC audit.usp_TrackDataGrowth;
    
    PRINT 'Maintenance completed.';
END;
GO

-- ============================================================================
-- 10. VERIFY MONITORING FRAMEWORK
-- ============================================================================
PRINT '================================================';
PRINT 'MONITORING & LOGGING FRAMEWORK CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Views created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('audit');
PRINT '';
PRINT 'Procedures created:';
SELECT COUNT(*) AS procedure_count FROM sys.procedures WHERE schema_id = SCHEMA_ID('audit');
PRINT '';
PRINT '================================================';
GO
