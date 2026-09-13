-- ============================================================================
-- SATHAPANA BANK - CHANGE DATA CAPTURE (CDC) SETUP
-- ============================================================================
-- Purpose: Enable real-time/near-real-time data replication from source
-- Author: DWH Development Team
-- Reference: SQL Server CDC Best Practices
-- ============================================================================

-- ============================================================================
-- OVERVIEW
-- ============================================================================
/*
Change Data Capture (CDC) captures insert, update, and delete activities 
applied to SQL Server tables, making the details of the changes available 
in an easily consumed relational format.

BENEFITS:
- Near real-time data replication
- Minimal impact on source system
- Automatic capture of DML changes
- Queryable change history
- Integration with ETL processes

REQUIREMENTS:
- SQL Server Enterprise Edition (or Standard with limitations)
- Sufficient log space for change tracking
- Agent job for log reader
*/

-- ============================================================================
-- 1. ENABLE CDC ON DATABASE
-- ============================================================================
USE master;
GO

PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'ENABLEING CHANGE DATA CAPTURE';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT '';

-- Enable CDC on source database
IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = 'sathapana_source') = 0
BEGIN
    EXEC sys.sp_cdc_enable_db;
    PRINT '✓ CDC enabled on sathapana_source database';
END
ELSE
BEGIN
    PRINT '✓ CDC already enabled on sathapana_source';
END
GO

-- ============================================================================
-- 2. CREATE CDC SCHEMA FOR TRACKING
-- ============================================================================
USE sathapana_source;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'cdc')
    EXEC('CREATE SCHEMA cdc');
GO

-- ============================================================================
-- 3. ENABLE CDC ON SOURCE TABLES
-- ============================================================================

-- 3.1 Enable CDC on Customers table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'customers' AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = 'oltp',
        @source_name = 'customers',
        @role_name = NULL,
        @supports_net_changes = 1;
    PRINT '✓ CDC enabled on oltp.customers';
END
GO

-- 3.2 Enable CDC on Accounts table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'accounts' AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = 'oltp',
        @source_name = 'accounts',
        @role_name = NULL,
        @supports_net_changes = 1;
    PRINT '✓ CDC enabled on oltp.accounts';
END
GO

-- 3.3 Enable CDC on Transactions table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'transactions' AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = 'oltp',
        @source_name = 'transactions',
        @role_name = NULL,
        @supports_net_changes = 1;
    PRINT '✓ CDC enabled on oltp.transactions';
END
GO

-- 3.4 Enable CDC on Loans table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'loans' AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = 'oltp',
        @source_name = 'loans',
        @role_name = NULL,
        @supports_net_changes = 1;
    PRINT '✓ CDC enabled on oltp.loans';
END
GO

-- 3.5 Enable CDC on Branches table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'branches' AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = 'oltp',
        @source_name = 'branches',
        @role_name = NULL,
        @supports_net_changes = 1;
    PRINT '✓ CDC enabled on oltp.branches';
END
GO

-- 3.6 Enable CDC on Products table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'products' AND is_tracked_by_cdc = 1)
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = 'oltp',
        @source_name = 'products',
        @role_name = NULL,
        @supports_net_changes = 1;
    PRINT '✓ CDC enabled on oltp.products';
END
GO

-- ============================================================================
-- 4. VERIFY CDC ENABLED TABLES
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'CDC ENABLED TABLES';
PRINT '═══════════════════════════════════════════════════════════════════════';

SELECT 
    s.name AS source_schema,
    t.name AS source_table,
    tc.capture_instance,
    tc.is_tracked_by_cdc,
    tc.create_date
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN cdc.change_tables tc ON t.object_id = tc.source_object_id
WHERE t.is_tracked_by_cdc = 1
ORDER BY s.name, t.name;

-- ============================================================================
-- 5. CDC HELPER PROCEDURES
-- ============================================================================

-- 5.1 Get changes since a specific LSN (Log Sequence Number)
CREATE OR ALTER PROCEDURE cdc.usp_GetChangesSinceLSN
    @LSN BINARY(10),
    @TableName VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @from_lsn BINARY(10) = @LSN;
    DECLARE @to_lsn BINARY(10) = sys.fn_cdc_get_max_lsn();
    
    -- Get all changes
    SELECT 
        __$operation,
        CASE __$operation
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 3 THEN 'UPDATE (Before)'
            WHEN 4 THEN 'UPDATE (After)'
        END AS operation_name,
        __$update_mask,
        *
    FROM cdc.fn_cdc_get_all_changes_oltp_customers(@from_lsn, @to_lsn, 'all')
    WHERE @TableName IS NULL OR @TableName = 'customers'
    
    UNION ALL
    
    SELECT 
        __$operation,
        CASE __$operation
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 3 THEN 'UPDATE (Before)'
            WHEN 4 THEN 'UPDATE (After)'
        END AS operation_name,
        __$update_mask,
        *
    FROM cdc.fn_cdc_get_all_changes_oltp_accounts(@from_lsn, @to_lsn, 'all')
    WHERE @TableName IS NULL OR @TableName = 'accounts'
    
    UNION ALL
    
    SELECT 
        __$operation,
        CASE __$operation
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 3 THEN 'UPDATE (Before)'
            WHEN 4 THEN 'UPDATE (After)'
        END AS operation_name,
        __$update_mask,
        *
    FROM cdc.fn_cdc_get_all_changes_oltp_transactions(@from_lsn, @to_lsn, 'all')
    WHERE @TableName IS NULL OR @TableName = 'transactions';
END;
GO

-- 5.2 Get net changes (consolidated view)
CREATE OR ALTER PROCEDURE cdc.usp_GetNetChanges
    @StartTime DATETIME,
    @EndTime DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @EndTime IS NULL
        SET @EndTime = GETDATE();
    
    DECLARE @from_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('smallest greater than or equal to', @StartTime);
    DECLARE @to_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('largest less than or equal to', @EndTime);
    
    -- Net changes for customers
    SELECT 
        'customers' AS table_name,
        __$operation,
        CASE __$operation
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 3 THEN 'UPDATE'
            WHEN 4 THEN 'UPDATE'
        END AS operation_name,
        customer_id,
        customer_code,
        first_name,
        last_name,
        customer_segment,
        GETDATE() AS captured_at
    FROM cdc.fn_cdc_get_net_changes_oltp_customers(@from_lsn, @to_lsn, 'all');
    
    -- Net changes for accounts
    SELECT 
        'accounts' AS table_name,
        __$operation,
        CASE __$operation
            WHEN 1 THEN 'DELETE'
            WHEN 2 THEN 'INSERT'
            WHEN 3 THEN 'UPDATE'
            WHEN 4 THEN 'UPDATE'
        END AS operation_name,
        account_id,
        account_number,
        customer_id,
        account_status,
        balance,
        GETDATE() AS captured_at
    FROM cdc.fn_cdc_get_net_changes_oltp_accounts(@from_lsn, @to_lsn, 'all');
END;
GO

-- ============================================================================
-- 6. CDC STATUS MONITORING
-- ============================================================================

CREATE OR ALTER VIEW cdc.vw_CDC_Status AS
SELECT 
    s.name AS source_schema,
    t.name AS source_table,
    tc.capture_instance,
    -- LSN information
    sys.fn_cdc_map_lsn_to_time(tr.start_lsn) AS earliest_change_time,
    sys.fn_cdc_map_lsn_to_time(tr.end_lsn) AS latest_change_time,
    -- Trimming information
    tr.start_lsn,
    tr.end_lsn,
    tr.truncated_lsn,
    -- Cleanup information
    DATEDIFF(HOUR, sys.fn_cdc_map_lsn_to_time(tr.end_lsn), GETDATE()) AS hours_since_last_change
FROM cdc.change_tables tc
JOIN sys.tables t ON tc.source_object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN cdc.lsn_time_mapping tr ON tc.create_lsn = tr.start_lsn;
GO

-- ============================================================================
-- 7. CDC CLEANUP PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE cdc.usp_CleanupCDC
    @RetentionHours INT = 72  -- Keep 3 days of changes
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @cleanup_lsn BINARY(10);
    DECLARE @cutoff_time DATETIME = DATEADD(HOUR, -@RetentionHours, GETDATE());
    
    PRINT 'Cleaning up CDC data older than ' + CAST(@RetentionHours AS VARCHAR) + ' hours...';
    
    -- Get the LSN for cleanup
    SET @cleanup_lsn = sys.fn_cdc_map_time_to_lsn('largest less than or equal to', @cutoff_time);
    
    -- Cleanup each capture instance
    DECLARE @capture_instance VARCHAR(100);
    
    DECLARE capture_cursor CURSOR FOR
    SELECT capture_instance FROM cdc.change_tables;
    
    OPEN capture_cursor;
    FETCH NEXT FROM capture_cursor INTO @capture_instance;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC sys.sp_cdc_cleanup_change_table
                @capture_instance = @capture_instance,
                @threshold = @cleanup_lsn;
            PRINT '✓ Cleaned: ' + @capture_instance;
        END TRY
        BEGIN CATCH
            PRINT '⚠ Cleanup failed for ' + @capture_instance + ': ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM capture_cursor INTO @capture_instance;
    END
    
    CLOSE capture_cursor;
    DEALLOCATE capture_cursor;
    
    PRINT 'CDC cleanup completed';
END;
GO

-- ============================================================================
-- 8. CDC TO RAW ZONE REPLICATION
-- ============================================================================

CREATE OR ALTER PROCEDURE cdc.usp_ReplicateToRawZone
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    PRINT '═══════════════════════════════════════════════════════════════════════';
    PRINT 'CDC REPLICATION: Source → Raw Zone';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT '═══════════════════════════════════════════════════════════════════════';
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    -- Get current LSN
    DECLARE @current_lsn BINARY(10) = sys.fn_cdc_get_max_lsn();
    DECLARE @previous_lsn BINARY(10);
    
    -- Get last replicated LSN from tracking table
    SELECT @previous_lsn = last_replicated_lsn 
    FROM sathapana_raw.meta.cdc_replication_status 
    WHERE capture_instance = 'ALL';
    
    IF @previous_lsn IS NULL
        SET @previous_lsn = sys.fn_cdc_get_min_lsn('oltp_customers');
    
    PRINT 'Replicating changes since LSN: ' + CONVERT(VARCHAR(30), @previous_lsn, 1);
    
    -- Replicate Customer Changes
    BEGIN TRY
        -- INSERT new customers
        INSERT INTO sathapana_raw.raw.customers (
            customer_id, customer_code, customer_type, title, first_name, last_name,
            national_id, date_of_birth, gender, phone_primary, province, district,
            customer_segment, risk_rating, kyc_status, opening_branch_id, is_active,
            created_date, modified_date, _extract_date, _batch_id, _source_system
        )
        SELECT 
            c.customer_id, c.customer_code, c.customer_type, c.title, c.first_name, c.last_name,
            c.national_id, c.date_of_birth, c.gender, c.phone_primary, c.province, c.district,
            c.customer_segment, c.risk_rating, c.kyc_status, c.opening_branch_id, c.is_active,
            c.created_date, c.modified_date, GETDATE(), @BatchID, 'CDC_REPLICATION'
        FROM ccdc.fn_cdc_get_all_changes_oltp_customers(@previous_lsn, @current_lsn, 'all') chg
        JOIN oltp.customers c ON chg.customer_id = c.customer_id
        WHERE chg.__$operation IN (2, 4);  -- INSERT or UPDATE
        
        SET @RecordCount = @@ROWCOUNT;
        PRINT '✓ Customers replicated: ' + CAST(@RecordCount AS VARCHAR) + ' records';
    END TRY
    BEGIN CATCH
        PRINT '⚠ Customer replication error: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Replicate Account Changes
    BEGIN TRY
        INSERT INTO sathapana_raw.raw.accounts (
            account_id, account_number, customer_id, product_id, branch_id,
            currency, account_type, account_status, open_date, balance,
            available_balance, created_date, modified_date,
            _extract_date, _batch_id, _source_system
        )
        SELECT 
            a.account_id, a.account_number, a.customer_id, a.product_id, a.branch_id,
            a.currency, a.account_type, a.account_status, a.open_date, a.balance,
            a.available_balance, a.created_date, a.modified_date,
            GETDATE(), @BatchID, 'CDC_REPLICATION'
        FROM cdc.fn_cdc_get_all_changes_oltp_accounts(@previous_lsn, @current_lsn, 'all') chg
        JOIN oltp.accounts a ON chg.account_id = a.account_id
        WHERE chg.__$operation IN (2, 4);
        
        SET @RecordCount = @@ROWCOUNT;
        PRINT '✓ Accounts replicated: ' + CAST(@RecordCount AS VARCHAR) + ' records';
    END TRY
    BEGIN CATCH
        PRINT '⚠ Account replication error: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Replicate Transaction Changes (only new transactions)
    BEGIN TRY
        INSERT INTO sathapana_raw.raw.transactions (
            transaction_id, transaction_code, account_id, transaction_type,
            transaction_channel, transaction_date, value_date, amount,
            currency, balance_before, balance_after, status, branch_id,
            created_date, _extract_date, _batch_id, _source_system
        )
        SELECT 
            t.transaction_id, t.transaction_code, t.account_id, t.transaction_type,
            t.transaction_channel, t.transaction_date, t.value_date, t.amount,
            t.currency, t.balance_before, t.balance_after, t.status, t.branch_id,
            t.created_date, GETDATE(), @BatchID, 'CDC_REPLICATION'
        FROM cdc.fn_cdc_get_all_changes_oltp_transactions(@previous_lsn, @current_lsn, 'all') chg
        JOIN oltp.transactions t ON chg.transaction_id = t.transaction_id
        WHERE chg.__$operation = 2  -- Only INSERT
        AND NOT EXISTS (
            SELECT 1 FROM sathapana_raw.raw.transactions rt 
            WHERE rt.transaction_id = t.transaction_id
        );
        
        SET @RecordCount = @@ROWCOUNT;
        PRINT '✓ Transactions replicated: ' + CAST(@RecordCount AS VARCHAR) + ' records';
    END TRY
    BEGIN CATCH
        PRINT '⚠ Transaction replication error: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Update replication status
    MERGE sathapana_raw.meta.cdc_replication_status AS target
    USING (SELECT 'ALL' AS capture_instance, @current_lsn AS last_lsn) AS source
    ON target.capture_instance = source.capture_instance
    WHEN MATCHED THEN
        UPDATE SET last_replicated_lsn = source.last_lsn,
                   last_replicated_time = GETDATE(),
                   records_replicated = @RecordCount
    WHEN NOT MATCHED THEN
        INSERT (capture_instance, last_replicated_lsn, last_replicated_time, records_replicated)
        VALUES (source.capture_instance, source.last_lsn, GETDATE(), @RecordCount);
    
    DECLARE @EndTime DATETIME = GETDATE();
    DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, @EndTime);
    
    PRINT '';
    PRINT '═══════════════════════════════════════════════════════════════════════';
    PRINT 'CDC REPLICATION COMPLETED';
    PRINT 'Duration: ' + CAST(@Duration AS VARCHAR) + ' seconds';
    PRINT '═══════════════════════════════════════════════════════════════════════';
END;
GO

-- ============================================================================
-- 9. CREATE CDC REPLICATION STATUS TABLE IN RAW ZONE
-- ============================================================================
USE sathapana_raw;
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'cdc_replication_status')
BEGIN
    CREATE TABLE meta.cdc_replication_status (
        capture_instance VARCHAR(100) PRIMARY KEY,
        last_replicated_lsn BINARY(10),
        last_replicated_time DATETIME,
        records_replicated BIGINT DEFAULT 0,
        status VARCHAR(20) DEFAULT 'ACTIVE',
        created_date DATETIME DEFAULT GETDATE(),
        modified_date DATETIME DEFAULT GETDATE()
    );
    PRINT '✓ CDC replication status table created';
END
GO

-- ============================================================================
-- 10. CDC LOG READER AGENT JOB
-- ============================================================================

USE msdb;
GO

-- Create CDC Log Reader Agent Job
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'CDC_Log_Reader_Agent')
BEGIN
    EXEC sp_delete_job @job_name = N'CDC_Log_Reader_Agent';
END

EXEC sp_add_job
    @job_name = N'CDC_Log_Reader_Agent',
    @enabled = 1,
    @description = N'CDC Log Reader Agent - Captures changes from transaction log',
    @category_name = N'Data Collector';

EXEC sp_add_jobstep
    @job_name = N'CDC_Log_Reader_Agent',
    @step_name = N'Run_CDC_Log_Reader',
    @subsystem = N'LogReader',
    @database_name = N'sathapana_source',
    @retry_attempts = 3,
    @retry_interval = 1;

-- Schedule: Every 15 minutes
EXEC sp_add_jobschedule
    @job_name = N'CDC_Log_Reader_Agent',
    @name = N'Every_15_Minutes',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @freq_subday_type = 4,  -- Minutes
    @freq_subday_interval = 15,
    @active_start_time = 000000;

PRINT '✓ CDC Log Reader Agent job created';

-- ============================================================================
-- 11. CDC TO RAW ZONE REPLICATION JOB
-- ============================================================================

IF EXISTS (SELECT * FROM sysjobs WHERE name = 'CDC_Replicate_to_Raw')
BEGIN
    EXEC sp_delete_job @job_name = N'CDC_Replicate_to_Raw';
END

EXEC sp_add_job
    @job_name = N'CDC_Replicate_to_Raw',
    @enabled = 1,
    @description = N'Replicate CDC changes from Source to Raw Zone',
    @category_name = N'Data Collector';

EXEC sp_add_jobstep
    @job_name = N'CDC_Replicate_to_Raw',
    @step_name = N'Replicate_CDC_Changes',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_source.cdc.usp_ReplicateToRawZone;',
    @database_name = N'sathapana_source',
    @retry_attempts = 2,
    @retry_interval = 5;

-- Schedule: Every 30 minutes (after log reader)
EXEC sp_add_jobschedule
    @job_name = N'CDC_Replicate_to_Raw',
    @name = N'Every_30_Minutes',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 30,
    @active_start_time = 000500;  -- 5 minutes after log reader

PRINT '✓ CDC Replication job created';

-- ============================================================================
-- 12. CDC CLEANUP JOB
-- ============================================================================

IF EXISTS (SELECT * FROM sysjobs WHERE name = 'CDC_Cleanup')
BEGIN
    EXEC sp_delete_job @job_name = N'CDC_Cleanup';
END

EXEC sp_add_job
    @job_name = N'CDC_Cleanup',
    @enabled = 1,
    @description = N'Clean up old CDC data (retention: 7 days)',
    @category_name = N'Data Collector';

EXEC sp_add_jobstep
    @job_name = N'CDC_Cleanup',
    @step_name = N'Cleanup_CDC_Data',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_source.cdc.usp_CleanupCDC @RetentionHours = 168;',  -- 7 days
    @database_name = N'sathapana_source';

-- Schedule: Daily at 3:00 AM
EXEC sp_add_jobschedule
    @job_name = N'CDC_Cleanup',
    @name = N'Daily_3AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 030000;

PRINT '✓ CDC Cleanup job created';

-- ============================================================================
-- 13. VERIFY CDC SETUP
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'CDC SETUP COMPLETE';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT '';

-- Show CDC enabled databases
SELECT 
    name AS database_name,
    is_cdc_enabled,
    CASE WHEN is_cdc_enabled = 1 THEN '✓ ENABLED' ELSE '✗ DISABLED' END AS status
FROM sys.databases
WHERE name = 'sathapana_source';

PRINT '';

-- Show CDC enabled tables
SELECT 
    s.name AS schema_name,
    t.name AS table_name,
    CASE WHEN t.is_tracked_by_cdc = 1 THEN '✓ TRACKING' ELSE '✗ NOT TRACKING' END AS cdc_status
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'oltp'
ORDER BY t.name;

PRINT '';

-- Show CDC jobs
SELECT 
    name AS job_name,
    CASE WHEN enabled = 1 THEN '✓ ENABLED' ELSE '✗ DISABLED' END AS status,
    description
FROM sysjobs
WHERE name LIKE 'CDC_%';

PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'CDC ARCHITECTURE:';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT '';
PRINT '  Source DB (CDC Enabled)';
PRINT '    ↓ (Every 15 min - Log Reader)';
PRINT '  Transaction Log';
PRINT '    ↓ (Every 30 min - Replication)';
PRINT '  Raw Zone (sathapana_raw)';
PRINT '    ↓ (ETL Pipeline)';
PRINT '  Data Warehouse (sathapana_dwh)';
PRINT '    ↓ (Views)';
PRINT '  Data Marts (sathapana_dm_*)';
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
GO
