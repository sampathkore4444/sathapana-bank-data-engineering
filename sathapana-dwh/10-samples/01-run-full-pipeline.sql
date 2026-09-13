-- ============================================================================
-- SATHAPANA BANK - MAIN ORCHESTRATION SCRIPT
-- ============================================================================
-- Purpose: Main script to run the complete ETL pipeline
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

-- ============================================================================
-- IMPORTANT: Run this script in order
-- ============================================================================

/*
PREREQUISITES:
1. SQL Server 2019 or later installed
2. Adjust file paths in database creation scripts if needed
3. Ensure sufficient disk space (at least 1GB free)
4. Run as sysadmin or dbcreator role

EXECUTION ORDER:
1. 02-source-systems/01-create-source-database.sql
2. 03-staging/01-create-staging-database.sql
3. 04-data-warehouse/01-create-dwh-database.sql
4. 05-data-marts/01-create-data-marts.sql
5. 06-etl/01-extract-procedures.sql
6. 06-etl/02-transform-load-procedures.sql
7. 07-data-quality/01-data-quality-framework.sql
8. 08-monitoring/01-monitoring-framework.sql
9. This script (run-full-pipeline.sql)
*/

-- ============================================================================
-- STEP 1: CREATE ALL DATABASES AND SCHEMAS
-- ============================================================================
PRINT '================================================';
PRINT 'STEP 1: Creating databases and schemas...';
PRINT '================================================';

-- Note: Execute the following scripts in order:
-- 1. 02-source-systems/01-create-source-database.sql
-- 2. 03-staging/01-create-staging-database.sql  
-- 3. 04-data-warehouse/01-create-dwh-database.sql
-- 4. 05-data-marts/01-create-data-marts.sql

-- ============================================================================
-- STEP 2: CREATE ETL PROCEDURES
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'STEP 2: Creating ETL procedures...';
PRINT '================================================';

-- Note: Execute the following scripts:
-- 1. 06-etl/01-extract-procedures.sql
-- 2. 06-etl/02-transform-load-procedures.sql
-- 3. 07-data-quality/01-data-quality-framework.sql
-- 4. 08-monitoring/01-monitoring-framework.sql

-- ============================================================================
-- STEP 3: RUN THE FULL ETL PIPELINE
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'STEP 3: Running Full ETL Pipeline...';
PRINT '================================================';

DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
DECLARE @StartTime DATETIME = GETDATE();

PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
PRINT 'Start Time: ' + CONVERT(VARCHAR, @StartTime, 120);
PRINT '';

-- ============================================================================
-- 3.1 EXTRACTION PHASE
-- ============================================================================
PRINT '--- Phase 1: Extraction ---';
BEGIN TRY
    -- Run extraction from source systems
    EXEC sathapana_staging.staging.usp_ExtractAll @BatchID;
    PRINT '✓ Extraction completed successfully.';
END TRY
BEGIN CATCH
    PRINT '✗ Extraction failed: ' + ERROR_MESSAGE();
    -- Log error
    EXEC sathapana_dwh.audit.usp_TrackError 
        @BatchID, 'EXTRACTION', 'PIPELINE_ERROR', ERROR_MESSAGE();
    THROW;
END CATCH

-- ============================================================================
-- 3.2 TRANSFORMATION & LOADING PHASE
-- ============================================================================
PRINT '';
PRINT '--- Phase 2: Transformation & Loading ---';
BEGIN TRY
    -- Run transformation and loading to DW
    EXEC sathapana_dwh.dw.usp_LoadAll @BatchID;
    PRINT '✓ Transformation & Loading completed successfully.';
END TRY
BEGIN CATCH
    PRINT '✗ Transformation & Loading failed: ' + ERROR_MESSAGE();
    EXEC sathapana_dwh.audit.usp_TrackError 
        @BatchID, 'LOADING', 'PIPELINE_ERROR', ERROR_MESSAGE();
    THROW;
END CATCH

-- ============================================================================
-- 3.3 DATA QUALITY CHECKS
-- ============================================================================
PRINT '';
PRINT '--- Phase 3: Data Quality Checks ---';
BEGIN TRY
    -- Run data quality checks
    EXEC sathapana_dwh.audit.usp_RunDataQualityChecks @BatchID;
    PRINT '✓ Data Quality checks completed.';
END TRY
BEGIN CATCH
    PRINT '✗ Data Quality checks failed: ' + ERROR_MESSAGE();
    EXEC sathapana_dwh.audit.usp_TrackError 
        @BatchID, 'DATA_QUALITY', 'PIPELINE_ERROR', ERROR_MESSAGE();
    -- Don't throw - DQ checks are informational
END CATCH

-- ============================================================================
-- 3.4 DATA RECONCILIATION
-- ============================================================================
PRINT '';
PRINT '--- Phase 4: Data Reconciliation ---';
BEGIN TRY
    -- Run data reconciliation
    EXEC sathapana_dwh.audit.usp_ReconcileData @BatchID;
    PRINT '✓ Data Reconciliation completed.';
END TRY
BEGIN CATCH
    PRINT '✗ Data Reconciliation failed: ' + ERROR_MESSAGE();
END CATCH

-- ============================================================================
-- 3.5 MONITORING & ALERTS
-- ============================================================================
PRINT '';
PRINT '--- Phase 5: Monitoring & Alerts ---';
BEGIN TRY
    -- Check for alerts
    EXEC sathapana_dwh.audit.usp_CheckAlerts;
    PRINT '✓ Alert check completed.';
END TRY
BEGIN CATCH
    PRINT '✗ Alert check failed: ' + ERROR_MESSAGE();
END CATCH

-- ============================================================================
-- STEP 4: GENERATE SUMMARY REPORT
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'STEP 4: Pipeline Execution Summary';
PRINT '================================================';

DECLARE @EndTime DATETIME = GETDATE();
DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, @EndTime);

PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
PRINT 'Start Time: ' + CONVERT(VARCHAR, @StartTime, 120);
PRINT 'End Time: ' + CONVERT(VARCHAR, @EndTime, 120);
PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
PRINT '';

-- Data summary
PRINT '--- Data Summary ---';
SELECT 'Branches' AS entity, COUNT(*) AS count FROM sathapana_dwh.dw.dim_branch WHERE is_current = 1
UNION ALL
SELECT 'Customers', COUNT(*) FROM sathapana_dwh.dw.dim_customer WHERE is_current = 1
UNION ALL
SELECT 'Accounts', COUNT(*) FROM sathapana_dwh.dw.dim_account WHERE is_current = 1
UNION ALL
SELECT 'Products', COUNT(*) FROM sathapana_dwh.dw.dim_product
UNION ALL
SELECT 'Employees', COUNT(*) FROM sathapana_dwh.dw.dim_employee WHERE is_current = 1
UNION ALL
SELECT 'Transactions', COUNT(*) FROM sathapana_dwh.dw.fact_transactions
UNION ALL
SELECT 'Loan Portfolio', COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio
UNION ALL
SELECT 'Deposit Snapshots', COUNT(*) FROM sathapana_dwh.dw.fact_deposit_snapshot;

PRINT '';

-- ETL log summary
PRINT '--- ETL Log Summary ---';
SELECT 
    step_name,
    table_name,
    records_affected,
    status,
    duration_seconds,
    CASE 
        WHEN duration_seconds > 300 THEN 'SLOW'
        WHEN duration_seconds > 60 THEN 'MODERATE'
        ELSE 'FAST'
    END AS performance
FROM sathapana_dwh.audit.etl_log
WHERE batch_id = @BatchID
ORDER BY start_time;

PRINT '';

-- Data quality summary
PRINT '--- Data Quality Summary ---';
SELECT 
    check_name,
    table_name,
    total_rows,
    failing_rows,
    pass_rate,
    status
FROM sathapana_dwh.audit.data_quality
WHERE batch_id = @BatchID
ORDER BY status, check_name;

PRINT '';
PRINT '================================================';
PRINT 'PIPELINE EXECUTION COMPLETED';
PRINT '================================================';

-- ============================================================================
-- STEP 5: SAMPLE QUERIES
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'STEP 5: Sample Queries';
PRINT '================================================';

PRINT '';
PRINT '--- Customer 360 View ---';
SELECT TOP 5 * FROM sathapana_dwh.dw.vw_customer_360;

PRINT '';
PRINT '--- Branch Performance ---';
SELECT * FROM sathapana_dwh.dw.vw_branch_performance;

PRINT '';
PRINT '--- Credit Risk Summary ---';
SELECT * FROM sathapana_dwh.dm_credit.vw_credit_risk_summary;

PRINT '';
PRINT '--- Monitoring Dashboard ---';
SELECT * FROM sathapana_dwh.audit.vw_monitoring_dashboard;

PRINT '';
PRINT '================================================';
PRINT 'ALL DONE!';
PRINT '================================================';
GO
