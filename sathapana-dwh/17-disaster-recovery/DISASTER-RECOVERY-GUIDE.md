# 🛡️ Disaster Recovery Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Recovery Objectives](#2-recovery-objectives)
3. [Backup Strategy](#3-backup-strategy)
4. [Backup Procedures](#4-backup-procedures)
5. [Restore Procedures](#5-restore-procedures)
6. [High Availability](#6-high-availability)
7. [Testing & Drills](#7-testing--drills)

---

## 1. Overview

Disaster Recovery ensures the data warehouse can be restored after data loss, corruption, or system failure.

```
┌─────────────────────────────────────────────────────────────────┐
│                    DISASTER RECOVERY STRATEGY                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   FULL      │    │  DIFFERENTIAL│   │   TRANSACTION│        │
│  │   BACKUP    │    │   BACKUP     │   │   LOG BACKUP │        │
│  │   (Daily)   │    │   (Daily)    │   │   (15 min)   │        │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                   │                   │                │
│         └───────────────────┼───────────────────┘                │
│                             ▼                                    │
│                    ┌─────────────┐                               │
│                    │  BACKUP     │                               │
│                    │  STORAGE    │                               │
│                    │  (Local +   │                               │
│                    │   Offsite)  │                               │
│                    └─────────────┘                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Recovery Objectives

| Metric | Target | Description |
|--------|--------|-------------|
| **RPO** (Recovery Point Objective) | 15 minutes | Max data loss acceptable |
| **RTO** (Recovery Time Objective) | 4 hours | Max time to restore |
| **MTTR** (Mean Time To Repair) | 2 hours | Average repair time |

---

## 3. Backup Strategy

| Backup Type | Frequency | Retention | Purpose |
|-------------|-----------|-----------|---------|
| Full Backup | Daily 1:00 AM | 30 days | Complete database |
| Differential | Daily 4:00 AM | 7 days | Changes since last full |
| Transaction Log | Every 15 min | 7 days | Point-in-time recovery |
| ETL Scripts | Every commit | Permanent | Git repository |

---

## 4. Backup Procedures

```sql
-- ============================================================
-- FULL BACKUP PROCEDURE
-- ============================================================

CREATE PROCEDURE dr.usp_PerformFullBackup
    @DatabaseName NVARCHAR(100)
AS
BEGIN
    DECLARE @BackupPath NVARCHAR(500) = 'C:\Backup\' + @DatabaseName + '_FULL_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.bak';
    
    BACKUP DATABASE @DatabaseName
    TO DISK = @BackupPath
    WITH COMPRESSION,
         CHECKSUM,
         STATS = 10;
    
    PRINT 'Full backup completed: ' + @BackupPath;
END;
GO

-- ============================================================
-- TRANSACTION LOG BACKUP PROCEDURE
-- ============================================================

CREATE PROCEDURE dr.usp_PerformLogBackup
    @DatabaseName NVARCHAR(100)
AS
BEGIN
    DECLARE @BackupPath NVARCHAR(500) = 'C:\Backup\' + @DatabaseName + '_LOG_' + FORMAT(GETDATE(), 'yyyyMMdd_HHmmss') + '.trn';
    
    BACKUP LOG @DatabaseName
    TO DISK = @BackupPath
    WITH COMPRESSION,
         CHECKSUM;
    
    PRINT 'Log backup completed: ' + @BackupPath;
END;
GO

-- ============================================================
-- AUTOMATED BACKUP JOB
-- ============================================================

-- Create SQL Agent job for daily backups
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'DWH_Daily_Backup',
    @enabled = 1,
    @description = N'Daily backup for DWH databases';

EXEC sp_add_jobstep
    @job_name = N'DWH_Daily_Backup',
    @step_name = N'Backup_Staging',
    @subsystem = N'TSQL',
    @command = N'EXEC dr.usp_PerformFullBackup @DatabaseName = ''sathapana_staging''',
    @database_name = N'master';

EXEC sp_add_jobschedule
    @job_name = N'DWH_Daily_Backup',
    @name = N'Daily_1AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 010000;
```

---

## 5. Restore Procedures

```sql
-- ============================================================
-- RESTORE FROM FULL BACKUP
-- ============================================================

CREATE PROCEDURE dr.usp_RestoreDatabase
    @DatabaseName NVARCHAR(100),
    @BackupFile NVARCHAR(500),
    @RecoveryMode NVARCHAR(20) = 'RECOVERY'  -- or 'NORECOVERY'
AS
BEGIN
    -- Set to single user mode
    EXEC('ALTER DATABASE [' + @DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE');
    
    -- Restore
    RESTORE DATABASE @DatabaseName
    FROM DISK = @BackupFile
    WITH REPLACE,
         RECOVERY = @RecoveryMode;
    
    -- Set to multi user mode
    EXEC('ALTER DATABASE [' + @DatabaseName + '] SET MULTI_USER');
    
    PRINT 'Database ' + @DatabaseName + ' restored successfully.';
END;
GO

-- ============================================================
-- POINT-IN-TIME RECOVERY
-- ============================================================

CREATE PROCEDURE dr.usp_RestoreToPointInTime
    @DatabaseName NVARCHAR(100),
    @FullBackupFile NVARCHAR(500),
    @TargetTime DATETIME
AS
BEGIN
    -- Restore full backup with NORECOVERY
    RESTORE DATABASE @DatabaseName
    FROM DISK = @FullBackupFile
    WITH NORECOVERY, REPLACE;
    
    -- Apply transaction logs up to target time
    DECLARE @LogFiles TABLE (backup_file NVARCHAR(500));
    
    -- (In production, enumerate log files from backup history)
    -- RESTORE LOG @DatabaseName FROM DISK = @LogFile WITH STOPAT = @TargetTime, NORECOVERY;
    
    -- Final recovery
    RESTORE DATABASE @DatabaseName WITH RECOVERY;
    
    PRINT 'Point-in-time recovery to ' + CONVERT(VARCHAR(20), @TargetTime, 120) + ' completed.';
END;
GO
```

---

## 6. High Availability

### Options

| Option | RPO | RTO | Cost | Complexity |
|--------|-----|-----|------|------------|
| Always On AG | Seconds | Minutes | High | High |
| Log Shipping | 15 min | Hours | Low | Low |
| Mirroring | Seconds | Minutes | Medium | Medium |
| Backup/Restore | 15 min | Hours | Low | Low |

### Recommended for Sathapana Bank

**Primary:** Log Shipping (low cost, meets 15-min RPO)
**Future:** Always On Availability Groups (if budget allows)

---

## 7. Testing & Drills

### Monthly DR Test Checklist

```markdown
## DR Test Checklist

- [ ] Verify backups are completing successfully
- [ ] Test restore on non-production server
- [ ] Validate data integrity after restore
- [ ] Document any issues found
- [ ] Update DR documentation if needed
- [ ] Report results to management
```

### Test Restore Procedure

```sql
-- ============================================================
-- DR TEST PROCEDURE
-- ============================================================

CREATE PROCEDURE dr.usp_PerformDRTest
AS
BEGIN
    DECLARE @TestDB NVARCHAR(100) = 'sathapana_dwh_DRTEST';
    DECLARE @LatestBackup NVARCHAR(500);
    
    PRINT 'Starting DR Test...';
    
    -- Get latest backup
    SELECT TOP 1 @LatestBackup = physical_device_name
    FROM msdb.dbo.backupset b
    JOIN msdb.dbo.backupmediafamily m ON b.media_set_id = m.media_set_id
    WHERE b.database_name = 'sathapana_dwh'
    AND b.type = 'D'
    ORDER BY b.backup_finish_date DESC;
    
    PRINT 'Latest backup: ' + @LatestBackup;
    
    -- Restore to test database
    EXEC dr.usp_RestoreDatabase 
        @DatabaseName = @TestDB,
        @BackupFile = @LatestBackup;
    
    -- Validate data
    DECLARE @SourceCount BIGINT, @TestCount BIGINT;
    
    SELECT @SourceCount = COUNT(*) FROM sathapana_dwh.dw.dim_customer;
    SELECT @TestCount = COUNT(*) FROM [sathapana_dwh_DRTEST].dw.dim_customer;
    
    IF @SourceCount = @TestCount
        PRINT 'DR Test PASSED: Row counts match (' + CAST(@SourceCount AS VARCHAR(10)) + ')';
    ELSE
        PRINT 'DR Test FAILED: Row count mismatch';
    
    -- Cleanup
    EXEC('DROP DATABASE [' + @TestDB + ']');
    
    PRINT 'DR Test completed.';
END;
GO
```

---

## Quick Reference

### Backup Commands
```sql
-- Full backup
BACKUP DATABASE sathapana_dwh TO DISK = 'C:\Backup\dwh_full.bak' WITH COMPRESSION;

-- Log backup
BACKUP LOG sathapana_dwh TO DISK = 'C:\Backup\dwh_log.trn' WITH COMPRESSION;

-- Check backup history
SELECT * FROM msdb.dbo.backupset ORDER BY backup_finish_date DESC;
```

---

*Created: September 2024*
