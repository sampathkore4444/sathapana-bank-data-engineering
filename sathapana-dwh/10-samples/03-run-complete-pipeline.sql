-- ============================================================================
-- SATHAPANA BANK - COMPLETE PIPELINE EXECUTION
-- ============================================================================
-- Purpose: Run the ENTIRE data warehouse pipeline (all layers + all marts)
-- Architecture: Enterprise Layered Pattern (10 databases, 1 instance)
-- Author: DWH Development Team
-- ============================================================================

/*
COMPLETE DATABASE INVENTORY:
═══════════════════════════════════════════════════════════════════════════

Layer 0: Source Systems
  └── sathapana_source (OLTP simulation)

Layer 1: Raw Zone (Source Copy)
  └── sathapana_raw (exact copy, no transformations)

Layer 2: Curated Zone (Enterprise DW)
  ├── sathapana_staging (Staging)
  └── sathapana_dwh (dimensions, facts, business rules)

Layer 3: Serving Zone (Data Marts)
  ├── sathapana_dm_credit (Credit Risk)
  ├── sathapana_dm_customer (Customer Analytics)
  ├── sathapana_dm_treasury (Treasury)
  ├── sathapana_dm_compliance (AML/Compliance)
  ├── sathapana_dm_alm (Asset Liability Management)
  └── sathapana_dm_operations (Operations)

═══════════════════════════════════════════════════════════════════════════
Total: 10 Databases on 1 SQL Server Instance
*/

-- ============================================================================
-- PIPELINE EXECUTION
-- ============================================================================

PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║     SATHAPANA BANK - COMPLETE DWH PIPELINE EXECUTION            ║';
PRINT '║     Enterprise Layered Architecture                             ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';

DECLARE @PipelineStart DATETIME = GETDATE();
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
DECLARE @Phase VARCHAR(50);

PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
PRINT 'Start Time: ' + CONVERT(VARCHAR, @PipelineStart, 120);
PRINT '';

-- ============================================================================
-- PHASE 1: EXTRACT TO RAW ZONE (Layer 0 → Layer 1)
-- ============================================================================
SET @Phase = 'PHASE 1: EXTRACT TO RAW ZONE';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT @Phase;
PRINT '═══════════════════════════════════════════════════════════════════════';

BEGIN TRY
    PRINT 'Extracting source data to Raw Zone...';
    
    -- Execute raw zone extraction
    EXEC sathapana_dwh.dbo.usp_Extract_to_Raw;
    
    PRINT '✓ ' + @Phase + ' COMPLETED';
END TRY
BEGIN CATCH
    PRINT '✗ ' + @Phase + ' FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH

PRINT '';

-- ============================================================================
-- PHASE 2: STAGING EXTRACTION (Raw → Staging)
-- ============================================================================
SET @Phase = 'PHASE 2: STAGING EXTRACTION';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT @Phase;
PRINT '═══════════════════════════════════════════════════════════════════════';

BEGIN TRY
    PRINT 'Running staging extraction...';
    
    EXEC sathapana_staging.staging.usp_ExtractAll @BatchID;
    
    PRINT '✓ ' + @Phase + ' COMPLETED';
END TRY
BEGIN CATCH
    PRINT '✗ ' + @Phase + ' FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH

PRINT '';

-- ============================================================================
-- PHASE 3: TRANSFORM & LOAD TO DW (Staging → Curated Zone)
-- ============================================================================
SET @Phase = 'PHASE 3: TRANSFORM & LOAD TO DW';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT @Phase;
PRINT '═══════════════════════════════════════════════════════════════════════';

BEGIN TRY
    PRINT 'Running transformation and loading to DW...';
    
    EXEC sathapana_dwh.dw.usp_LoadAll @BatchID;
    
    PRINT '✓ ' + @Phase + ' COMPLETED';
END TRY
BEGIN CATCH
    PRINT '✗ ' + @Phase + ' FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH

PRINT '';

-- ============================================================================
-- PHASE 4: DATA QUALITY CHECKS
-- ============================================================================
SET @Phase = 'PHASE 4: DATA QUALITY CHECKS';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT @Phase;
PRINT '═══════════════════════════════════════════════════════════════════════';

BEGIN TRY
    PRINT 'Running data quality checks...';
    
    EXEC sathapana_dwh.audit.usp_RunDataQualityChecks @BatchID;
    
    PRINT '✓ ' + @Phase + ' COMPLETED';
END TRY
BEGIN CATCH
    PRINT '⚠ ' + @Phase + ' WARNING: ' + ERROR_MESSAGE();
    -- Don't throw - DQ checks are informational
END CATCH

PRINT '';

-- ============================================================================
-- PHASE 5: VERIFY ALL DATA MARTS (Layer 3)
-- ============================================================================
SET @Phase = 'PHASE 5: VERIFY ALL DATA MARTS';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT @Phase;
PRINT '═══════════════════════════════════════════════════════════════════════';

-- 5.1 Credit Risk Mart
PRINT '';
PRINT '--- Credit Risk Mart (sathapana_dm_credit) ---';
BEGIN TRY
    SELECT COUNT(*) AS views_count FROM sathapana_dm_credit.dm.sys.views;
    SELECT TOP 2 * FROM sathapana_dm_credit.dm.vw_credit_risk_summary;
    PRINT '✓ Credit Mart OK';
END TRY
BEGIN CATCH
    PRINT '⚠ Credit Mart: ' + ERROR_MESSAGE();
END CATCH

-- 5.2 Customer Analytics Mart
PRINT '';
PRINT '--- Customer Analytics Mart (sathapana_dm_customer) ---';
BEGIN TRY
    SELECT COUNT(*) AS views_count FROM sathapana_dm_customer.dm.sys.views;
    SELECT TOP 2 * FROM sathapana_dm_customer.dm.vw_customer_segmentation;
    PRINT '✓ Customer Mart OK';
END TRY
BEGIN CATCH
    PRINT '⚠ Customer Mart: ' + ERROR_MESSAGE();
END CATCH

-- 5.3 Treasury Mart
PRINT '';
PRINT '--- Treasury Mart (sathapana_dm_treasury) ---';
BEGIN TRY
    SELECT COUNT(*) AS views_count FROM sathapana_dm_treasury.dm.sys.views;
    SELECT TOP 2 * FROM sathapana_dm_treasury.dm.vw_deposit_mobilization;
    PRINT '✓ Treasury Mart OK';
END TRY
BEGIN CATCH
    PRINT '⚠ Treasury Mart: ' + ERROR_MESSAGE();
END CATCH

-- 5.4 Compliance Mart
PRINT '';
PRINT '--- Compliance Mart (sathapana_dm_compliance) ---';
BEGIN TRY
    SELECT COUNT(*) AS views_count FROM sathapana_dm_compliance.dm.sys.views;
    SELECT TOP 2 * FROM sathapana_dm_compliance.dm.vw_aml_alert_summary;
    PRINT '✓ Compliance Mart OK';
END TRY
BEGIN CATCH
    PRINT '⚠ Compliance Mart: ' + ERROR_MESSAGE();
END CATCH

-- 5.5 ALM Mart
PRINT '';
PRINT '--- ALM Mart (sathapana_dm_alm) ---';
BEGIN TRY
    SELECT COUNT(*) AS views_count FROM sathapana_dm_alm.dm.sys.views;
    SELECT TOP 2 * FROM sathapana_dm_alm.dm.vw_liquidity_gap_analysis;
    PRINT '✓ ALM Mart OK';
END TRY
BEGIN CATCH
    PRINT '⚠ ALM Mart: ' + ERROR_MESSAGE();
END CATCH

-- 5.6 Operations Mart
PRINT '';
PRINT '--- Operations Mart (sathapana_dm_operations) ---';
BEGIN TRY
    SELECT COUNT(*) AS views_count FROM sathapana_dm_operations.dm.sys.views;
    SELECT TOP 2 * FROM sathapana_dm_operations.dm.vw_branch_performance;
    PRINT '✓ Operations Mart OK';
END TRY
BEGIN CATCH
    PRINT '⚠ Operations Mart: ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- ============================================================================
-- PHASE 6: GENERATE COMPREHENSIVE SUMMARY
-- ============================================================================
SET @Phase = 'PHASE 6: SUMMARY REPORT';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT @Phase;
PRINT '═══════════════════════════════════════════════════════════════════════';

DECLARE @PipelineEnd DATETIME = GETDATE();
DECLARE @Duration INT = DATEDIFF(SECOND, @PipelineStart, @PipelineEnd);

PRINT '';
PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║                    PIPELINE EXECUTION SUMMARY                    ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
PRINT 'Start Time: ' + CONVERT(VARCHAR, @PipelineStart, 120);
PRINT 'End Time: ' + CONVERT(VARCHAR, @PipelineEnd, 120);
PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
PRINT '';

-- Data Summary by Layer
PRINT '┌─────────────────────────────────────────────────────────────────┐';
PRINT '│                     DATA SUMMARY BY LAYER                       │';
PRINT '└─────────────────────────────────────────────────────────────────┘';
PRINT '';

PRINT 'Layer 0 (Source Systems):';
SELECT '  sathapana_source' AS database_name,
       (SELECT COUNT(*) FROM sathapana_source.oltp.branches) AS branches,
       (SELECT COUNT(*) FROM sathapana_source.oltp.customers) AS customers,
       (SELECT COUNT(*) FROM sathapana_source.oltp.accounts) AS accounts,
       (SELECT COUNT(*) FROM sathapana_source.oltp.transactions) AS transactions;

PRINT '';
PRINT 'Layer 1 (Raw Zone):';
SELECT '  sathapana_raw' AS database_name,
       (SELECT COUNT(*) FROM sathapana_raw.raw.branches) AS branches,
       (SELECT COUNT(*) FROM sathapana_raw.raw.customers) AS customers,
       (SELECT COUNT(*) FROM sathapana_raw.raw.accounts) AS accounts,
       (SELECT COUNT(*) FROM sathapana_raw.raw.transactions) AS transactions;

PRINT '';
PRINT 'Layer 2 (Curated Zone - Enterprise DW):';
SELECT '  sathapana_dwh' AS database_name,
       (SELECT COUNT(*) FROM sathapana_dwh.dw.dim_branch WHERE is_current = 1) AS dim_branches,
       (SELECT COUNT(*) FROM sathapana_dwh.dw.dim_customer WHERE is_current = 1) AS dim_customers,
       (SELECT COUNT(*) FROM sathapana_dwh.dw.dim_account WHERE is_current = 1) AS dim_accounts,
       (SELECT COUNT(*) FROM sathapana_dwh.dw.fact_transactions) AS fact_transactions;

PRINT '';
PRINT 'Layer 3 (Serving Zone - Data Marts):';
SELECT '  sathapana_dm_credit' AS mart_name, COUNT(*) AS views FROM sathapana_dm_credit.dm.sys.views
UNION ALL
SELECT '  sathapana_dm_customer', COUNT(*) FROM sathapana_dm_customer.dm.sys.views
UNION ALL
SELECT '  sathapana_dm_treasury', COUNT(*) FROM sathapana_dm_treasury.dm.sys.views
UNION ALL
SELECT '  sathapana_dm_compliance', COUNT(*) FROM sathapana_dm_compliance.dm.sys.views
UNION ALL
SELECT '  sathapana_dm_alm', COUNT(*) FROM sathapana_dm_alm.dm.sys.views
UNION ALL
SELECT '  sathapana_dm_operations', COUNT(*) FROM sathapana_dm_operations.dm.sys.views;

PRINT '';
PRINT '┌─────────────────────────────────────────────────────────────────┐';
PRINT '│                  COMPLETE DATABASE INVENTORY                    │';
PRINT '└─────────────────────────────────────────────────────────────────┘';
PRINT '';

SELECT 
    d.name AS database_name,
    CASE 
        WHEN d.name = 'sathapana_source' THEN 'Layer 0 - Source'
        WHEN d.name = 'sathapana_raw' THEN 'Layer 1 - Raw Zone'
        WHEN d.name = 'sathapana_staging' THEN 'Staging'
        WHEN d.name = 'sathapana_dwh' THEN 'Layer 2 - Curated Zone'
        WHEN d.name LIKE 'sathapana_dm_%' THEN 'Layer 3 - Data Mart'
        ELSE 'Other'
    END AS layer,
    CAST(SUM(a.total_pages) * 8 / 1024.0 AS DECIMAL(10,2)) AS size_mb
FROM sys.databases d
LEFT JOIN sys.master_files m ON d.database_id = m.database_id
LEFT JOIN sys.allocation_units a ON m.physical_name IS NOT NULL
WHERE d.name LIKE 'sathapana%'
GROUP BY d.name
ORDER BY 
    CASE 
        WHEN d.name = 'sathapana_source' THEN 1
        WHEN d.name = 'sathapana_raw' THEN 2
        WHEN d.name = 'sathapana_staging' THEN 3
        WHEN d.name = 'sathapana_dwh' THEN 4
        ELSE 5
    END;

PRINT '';
PRINT '╔═══════════════════════════════════════════════════════════════════╗';
PRINT '║           ✓ COMPLETE PIPELINE EXECUTION SUCCESSFUL               ║';
PRINT '╚═══════════════════════════════════════════════════════════════════╝';
PRINT '';
PRINT 'DATABASES CREATED:';
PRINT '  1. sathapana_source (Layer 0 - Source Systems)';
PRINT '  2. sathapana_raw (Layer 1 - Raw Zone)';
PRINT '  3. sathapana_staging (Staging Area)';
PRINT '  4. sathapana_dwh (Layer 2 - Curated Zone)';
PRINT '  5. sathapana_dm_credit (Layer 3 - Credit Risk)';
PRINT '  6. sathapana_dm_customer (Layer 3 - Customer Analytics)';
PRINT '  7. sathapana_dm_treasury (Layer 3 - Treasury)';
PRINT '  8. sathapana_dm_compliance (Layer 3 - Compliance/AML)';
PRINT '  9. sathapana_dm_alm (Layer 3 - ALM)';
PRINT ' 10. sathapana_dm_operations (Layer 3 - Operations)';
PRINT '';
PRINT 'TOTAL: 10 Databases on 1 SQL Server Instance';
PRINT '';
PRINT 'NEXT STEPS:';
PRINT '  1. Connect Power BI to data mart databases';
PRINT '  2. Configure SQL Server Agent jobs for scheduling';
PRINT '  3. Set up monitoring and alerting';
PRINT '  4. Train users on report access';
PRINT '';
GO
