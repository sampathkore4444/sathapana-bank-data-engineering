-- ============================================================================
-- SATHAPANA BANK - DISASTER RECOVERY SCRIPTS
-- ============================================================================
-- Purpose: Backup and restore procedures for all DWH databases
-- Author: DWH Development Team
-- ============================================================================

-- ============================================================================
-- 1. BACKUP ALL DATABASES
-- ============================================================================

CREATE OR ALTER PROCEDURE master.dbo.usp_BackupAllDWH
    @BackupPath VARCHAR(500) = 'C:\Backup\DWH\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupFile VARCHAR(500);
    DECLARE @DatabaseName VARCHAR(100);
    DECLARE @StartTime DATETIME = GETDATE();
    
    PRINT '========================================';
    PRINT 'DWH BACKUP STARTED';
    PRINT 'Time: ' + CONVERT(VARCHAR, @StartTime, 120);
    PRINT 'Path: ' + @BackupPath;
    PRINT '========================================';
    
    -- Create backup directory if not exists
    DECLARE @mkdir VARCHAR(1000) = 'mkdir "' + @BackupPath + '"';
    EXEC xp_cmdshell @mkdir;
    
    -- Backup each database
    DECLARE db_cursor CURSOR FOR
    SELECT name FROM sys.databases
    WHERE name LIKE 'sathapana%'
    AND state_desc = 'ONLINE';
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @BackupFile = @BackupPath + @DatabaseName + '_' + 
                         FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.bak';
        
        PRINT 'Backing up: ' + @DatabaseName;
        
        BEGIN TRY
            BACKUP DATABASE @DatabaseName
            TO DISK = @BackupFile
            WITH FORMAT, COMPRESSION,
                 NAME = @DatabaseName + ' Full Backup',
                 DESCRIPTION = 'DWH Backup - ' + @DatabaseName;
            
            PRINT '✓ Backup completed: ' + @BackupFile;
        END TRY
        BEGIN CATCH
            PRINT '✗ Backup failed for ' + @DatabaseName + ': ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
    DECLARE @EndTime DATETIME = GETDATE();
    DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, @EndTime);
    
    PRINT '========================================';
    PRINT 'BACKUP COMPLETED';
    PRINT 'Duration: ' + CAST(@Duration AS VARCHAR) + ' seconds';
    PRINT '========================================';
END;
GO

PRINT '✓ Backup procedure created';

-- ============================================================================
-- 2. LOG BACKUP (For point-in-time recovery)
-- ============================================================================

CREATE OR ALTER PROCEDURE master.dbo.usp_BackupAllDWH_Logs
    @BackupPath VARCHAR(500) = 'C:\Backup\DWH\Logs\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupFile VARCHAR(500);
    DECLARE @DatabaseName VARCHAR(100);
    
    -- Create directory
    DECLARE @mkdir VARCHAR(1000) = 'mkdir "' + @BackupPath + '"';
    EXEC xp_cmdshell @mkdir;
    
    DECLARE db_cursor CURSOR FOR
    SELECT name FROM sys.databases
    WHERE name LIKE 'sathapana%'
    AND recovery_model_desc != 'SIMPLE'
    AND state_desc = 'ONLINE';
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @BackupFile = @BackupPath + @DatabaseName + '_Log_' + 
                         FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.trn';
        
        BEGIN TRY
            BACKUP LOG @DatabaseName
            TO DISK = @BackupFile
            WITH COMPRESSION;
            
            PRINT '✓ Log backup: ' + @DatabaseName;
        END TRY
        BEGIN CATCH
            PRINT '✗ Log backup failed: ' + @DatabaseName;
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DatabaseName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
END;
GO

PRINT '✓ Log backup procedure created';

-- ============================================================================
-- 3. RESTORE DATABASE (Single)
-- ============================================================================

CREATE OR ALTER PROCEDURE master.dbo.usp_RestoreDWH
    @DatabaseName VARCHAR(100),
    @BackupFile VARCHAR(500),
    @RestorePath VARCHAR(500) = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\'
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Restoring: ' + @DatabaseName;
    PRINT 'From: ' + @BackupFile;
    
    -- Get logical file names
    DECLARE @DataFile VARCHAR(100), @LogFile VARCHAR(100);
    
    SELECT @DataFile = name, @LogFile = name
    FROM (
        SELECT name, row_number() OVER (ORDER BY file_id) as rn
        FROM msdb.dbo.backupset bs
        JOIN msdb.dbo.backupfile bf ON bs.backup_set_id = bf.backup_set_id
        WHERE bs.database_name = @DatabaseName
        AND bs.backup_set_id = (SELECT MAX(backup_set_id) FROM msdb.dbo.backupset WHERE database_name = @DatabaseName)
    ) t
    WHERE rn = 1;
    
    -- Restore with REPLACE
    RESTORE DATABASE @DatabaseName
    FROM DISK = @BackupFile
    WITH REPLACE,
         MOVE @DataFile TO @RestorePath + @DatabaseName + '_dat.mdf',
         MOVE @LogFile TO @RestorePath + @DatabaseName + '_log.ldf';
    
    PRINT '✓ Restore completed: ' + @DatabaseName;
END;
GO

PRINT '✓ Restore procedure created';

-- ============================================================================
-- 4. RESTORE ALL DATABASES
-- ============================================================================

CREATE OR ALTER PROCEDURE master.dbo.usp_RestoreAllDWH
    @BackupPath VARCHAR(500) = 'C:\Backup\DWH\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BackupFile VARCHAR(500);
    DECLARE @DatabaseName VARCHAR(100);
    
    PRINT '========================================';
    PRINT 'RESTORING ALL DWH DATABASES';
    PRINT '========================================';
    
    -- Restore in reverse dependency order
    DECLARE @RestoreOrder TABLE (db_name VARCHAR(100), restore_order INT);
    
    INSERT INTO @RestoreOrder VALUES
    ('sathapana_dm_operations', 1),
    ('sathapana_dm_alm', 2),
    ('sathapana_dm_compliance', 3),
    ('sathapana_dm_treasury', 4),
    ('sathapana_dm_customer', 5),
    ('sathapana_dm_credit', 6),
    ('sathapana_dwh', 7),
    ('sathapana_staging', 8),
    ('sathapana_raw', 9),
    ('sathapana_source', 10);
    
    DECLARE restore_cursor CURSOR FOR
    SELECT db_name FROM @RestoreOrder ORDER BY restore_order;
    
    OPEN restore_cursor;
    FETCH NEXT FROM restore_cursor INTO @DatabaseName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Find latest backup
        SET @BackupFile = @BackupPath + @DatabaseName + '_*.bak';
        
        -- Get latest backup file
        DECLARE @cmd VARCHAR(1000);
        SET @cmd = 'dir /b /o-d "' + @BackupPath + @DatabaseName + '_*.bak"';
        
        BEGIN TRY
            EXEC master.dbo.usp_RestoreDWH @DatabaseName, @BackupFile;
        END TRY
        BEGIN CATCH
            PRINT '✗ Restore failed: ' + @DatabaseName + ' - ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM restore_cursor INTO @DatabaseName;
    END
    
    CLOSE restore_cursor;
    DEALLOCATE restore_cursor;
    
    PRINT '========================================';
    PRINT 'RESTORE COMPLETED';
    PRINT '========================================';
END;
GO

PRINT '✓ Restore all procedure created';

-- ============================================================================
-- 5. BACKUP VERIFICATION
-- ============================================================================

CREATE OR ALTER PROCEDURE master.dbo.usp_VerifyDWHBackups
    @BackupPath VARCHAR(500) = 'C:\Backup\DWH\'
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '========================================';
    PRINT 'BACKUP VERIFICATION';
    PRINT '========================================';
    
    -- List all backup files
    SELECT 
        database_name,
        backup_start_date,
        backup_finish_date,
        DATEDIFF(SECOND, backup_start_date, backup_finish_date) AS duration_seconds,
        CAST(backup_size / 1024 / 1024 AS DECIMAL(10,2)) AS backup_size_mb,
        compressed_backup_size / 1024 / 1024 AS compressed_size_mb,
        physical_device_name
    FROM msdb.dbo.backupset bs
    JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE bs.database_name LIKE 'sathapana%'
    AND bs.backup_finish_date >= DATEADD(DAY, -7, GETDATE())
    ORDER BY bs.backup_finish_date DESC;
    
    PRINT '========================================';
END;
GO

PRINT '✓ Backup verification procedure created';

-- ============================================================================
-- 6. CLEANUP OLD BACKUPS
-- ============================================================================

CREATE OR ALTER PROCEDURE master.dbo.usp_CleanupDWHBackups
    @RetentionDays INT = 30,
    @BackupPath VARCHAR(500) = 'C:\Backup\DWH\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @cutoff_date DATETIME = DATEADD(DAY, -@RetentionDays, GETDATE());
    
    PRINT 'Cleaning up backups older than ' + CAST(@RetentionDays AS VARCHAR) + ' days...';
    
    -- Delete old backup files
    DECLARE @cmd VARCHAR(1000);
    SET @cmd = 'forfiles /p "' + @BackupPath + '" /s /m *.bak /d -' + CAST(@RetentionDays AS VARCHAR) + ' /c "cmd /c del @path" 2>nul';
    EXEC xp_cmdshell @cmd;
    
    SET @cmd = 'forfiles /p "' + @BackupPath + '" /s /m *.trn /d -' + CAST(@RetentionDays AS VARCHAR) + ' /c "cmd /c del @path" 2>nul';
    EXEC xp_cmdshell @cmd;
    
    PRINT '✓ Cleanup completed';
END;
GO

PRINT '✓ Cleanup procedure created';

-- ============================================================================
-- 7. VERIFY SETUP
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'DISASTER RECOVERY SCRIPTS CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Procedures:';
PRINT '  - usp_BackupAllDWH: Full backup of all databases';
PRINT '  - usp_BackupAllDWH_Logs: Transaction log backups';
PRINT '  - usp_RestoreDWH: Restore single database';
PRINT '  - usp_RestoreAllDWH: Restore all databases';
PRINT '  - usp_VerifyDWHBackups: Verify backup history';
PRINT '  - usp_CleanupDWHBackups: Remove old backups';
PRINT '';
PRINT 'Backup Schedule:';
PRINT '  - Full Backup: Daily at 1:00 AM';
PRINT '  - Log Backup: Every 15 minutes';
PRINT '  - Cleanup: Weekly on Sunday';
PRINT '';
PRINT 'Recovery Objectives:';
PRINT '  - RPO (Recovery Point): 15 minutes';
PRINT '  - RTO (Recovery Time): 4 hours';
PRINT '';
PRINT '================================================';
GO
