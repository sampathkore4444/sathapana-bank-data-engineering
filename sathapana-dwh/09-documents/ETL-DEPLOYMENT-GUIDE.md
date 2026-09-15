# 🚀 ETL Deployment Guide - Moving to Production

## Table of Contents
1. [Overview](#1-overview)
2. [Pre-Deployment Checklist](#2-pre-deployment-checklist)
3. [Environment Setup](#3-environment-setup)
4. [Database Deployment](#4-database-deployment)
5. [ETL Procedures Deployment](#5-etl-procedures-deployment)
6. [Scheduling Configuration](#6-scheduling-configuration)
7. [Testing & Validation](#7-testing--validation)
8. [Post-Deployment Verification](#8-post-deployment-verification)
9. [Rollback Plan](#9-rollback-plan)
10. [Production Monitoring](#10-production-monitoring)

---

## 1. Overview

This guide covers the complete process of deploying the Sathapana Bank ETL pipeline from development to production.

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT PIPELINE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │ Development │  Build & test locally                          │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Staging     │  Integration testing                           │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Production  │  Live deployment                               │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Monitoring  │  Ongoing operations                            │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Pre-Deployment Checklist

### 2.1 Infrastructure Requirements

| Component | Minimum Requirement | Recommended |
|-----------|---------------------|-------------|
| SQL Server | 2019 Standard | 2019 Enterprise |
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32+ GB |
| Storage | 100 GB SSD | 500+ GB SSD |
| SQL Agent | Enabled | Enabled |

### 2.2 Prerequisites Checklist

```markdown
## Prerequisites Checklist

- [ ] SQL Server 2019+ installed
- [ ] SQL Server Agent service running
- [ ] Database Mail configured (for alerts)
- [ ] Sufficient disk space (check with: EXEC sp_spaceused)
- [ ] Backup strategy in place
- [ ] Network connectivity to source systems
- [ ] Service account created for ETL
- [ ] Required permissions granted
- [ ] Source system access verified
- [ ] Monitoring alerts configured
```

### 2.3 Security Requirements

```sql
-- Create ETL service account
CREATE LOGIN [ETL_Service] WITH PASSWORD = 'ComplexP@ssw0rd!';
GO

-- Create database users
USE sathapana_staging;
GO
CREATE USER [ETL_Service] FOR LOGIN [ETL_Service];
ALTER ROLE [db_datawriter] ADD MEMBER [ETL_Service];
ALTER ROLE [db_datareader] ADD MEMBER [ETL_Service];
GO

USE sathapana_dwh;
GO
CREATE USER [ETL_Service] FOR LOGIN [ETL_Service];
ALTER ROLE [db_datawriter] ADD MEMBER [ETL_Service];
ALTER ROLE [db_datareader] ADD MEMBER [ETL_Service];
GO
```

---

## 3. Environment Setup

### 3.1 Database Creation Order

```markdown
## Deployment Order (Critical!)

1. **Source Database** (sathapana_source)
   - Only if simulating source systems
   - Skip if using real source databases

2. **Staging Database** (sathapana_staging)
   - Create schemas: staging, audit
   - Create tables and procedures

3. **Data Warehouse** (sathapana_dwh)
   - Create schemas: dw, audit, mart_*
   - Create dimension and fact tables

4. **Data Marts**
   - sathapana_dm_credit
   - sathapana_dm_customer
   - sathapana_dm_treasury
   - sathapana_dm_compliance
```

### 3.2 Database Creation Scripts

```sql
-- ============================================================
-- PRODUCTION DATABASE SETUP
-- ============================================================

-- Step 1: Create staging database
CREATE DATABASE sathapana_staging;
GO
USE sathapana_staging;
GO
CREATE SCHEMA staging;
CREATE SCHEMA audit;
GO

-- Step 2: Create data warehouse database
CREATE DATABASE sathapana_dwh;
GO
USE sathapana_dwh;
GO
CREATE SCHEMA dw;
CREATE SCHEMA audit;
CREATE SCHEMA mart_credit_risk;
CREATE SCHEMA mart_customer_analytics;
CREATE SCHEMA mart_treasury;
CREATE SCHEMA mart_compliance;
GO

-- Step 3: Create data mart databases
CREATE DATABASE sathapana_dm_credit;
CREATE DATABASE sathapana_dm_customer;
CREATE DATABASE sathapana_dm_treasury;
CREATE DATABASE sathapana_dm_compliance;
GO

PRINT 'All databases created successfully.';
```

---

## 4. Database Deployment

### 4.1 Deployment Script Execution Order

```markdown
## Execute in Order

### Source System (if needed)
1. `02-source-systems/01-create-source-database.sql`

### Staging
2. `03-staging/01-create-staging-database.sql`

### Data Warehouse
3. `04-data-warehouse/01-create-dwh-database.sql`

### Data Marts
4. `05-data-marts/01-create-data-marts.sql`

### ETL Procedures
5. `06-etl/01-extract-procedures.sql`
6. `06-etl/02-transform-load-procedures.sql`

### Data Quality
7. `07-data-quality/01-data-quality-framework.sql`

### Monitoring
8. `08-monitoring/01-monitoring-framework.sql`

### Automation
9. `12-automation/01-create-agent-jobs.sql`
```

### 4.2 Deployment PowerShell Script

```powershell
# ============================================================
# ETL DEPLOYMENT SCRIPT (PowerShell)
# ============================================================

# Configuration
$ServerName = "YOUR_SERVER"
$SourceDB = "sathapana_source"
$StagingDB = "sathapana_staging"
$DWHDB = "sathapana_dwh"
$DeploymentPath = "C:\ETL_Deployment"

# Function to execute SQL script
function Deploy-SQLScript {
    param(
        [string]$Server,
        [string]$Database,
        [string]$ScriptPath
    )
    
    Write-Host "Deploying: $ScriptPath to $Database..." -ForegroundColor Yellow
    
    try {
        $connString = "Server=$Server;Database=$Database;Integrated Security=True"
        Invoke-Sqlcmd -ConnectionString $connString -InputFile $ScriptPath
        Write-Host "SUCCESS: $ScriptPath" -ForegroundColor Green
    }
    catch {
        Write-Host "FAILED: $ScriptPath" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        throw
    }
}

# Deploy in order
Write-Host "Starting ETL Deployment..." -ForegroundColor Cyan

# Staging database
Deploy-SQLScript -Server $ServerName -Database "master" -ScriptPath "$DeploymentPath\03-staging\01-create-staging-database.sql"

# Data Warehouse
Deploy-SQLScript -Server $ServerName -Database "master" -ScriptPath "$DeploymentPath\04-data-warehouse\01-create-dwh-database.sql"

# Data Marts
Deploy-SQLScript -Server $ServerName -Database "master" -ScriptPath "$DeploymentPath\05-data-marts\01-create-data-marts.sql"

# ETL Procedures
Deploy-SQLScript -Server $ServerName -Database $StagingDB -ScriptPath "$DeploymentPath\06-etl\01-extract-procedures.sql"
Deploy-SQLScript -Server $ServerName -Database $DWHDB -ScriptPath "$DeploymentPath\06-etl\02-transform-load-procedures.sql"

# Data Quality
Deploy-SQLScript -Server $ServerName -Database $DWHDB -ScriptPath "$DeploymentPath\07-data-quality\01-data-quality-framework.sql"

# Monitoring
Deploy-SQLScript -Server $ServerName -Database $DWHDB -ScriptPath "$DeploymentPath\08-monitoring\01-monitoring-framework.sql"

Write-Host "Deployment Complete!" -ForegroundColor Green
```

---

## 5. ETL Procedures Deployment

### 5.1 Verify Procedure Deployment

```sql
-- ============================================================
-- VERIFY DEPLOYED PROCEDURES
-- ============================================================

-- Check staging procedures
SELECT 
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name,
    create_date,
    modify_date
FROM sys.procedures
WHERE SCHEMA_NAME(schema_id) = 'staging'
ORDER BY name;

-- Check DW procedures
SELECT 
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name,
    create_date,
    modify_date
FROM sys.procedures
WHERE SCHEMA_NAME(schema_id) = 'dw'
ORDER BY name;

-- Check audit procedures
SELECT 
    SCHEMA_NAME(schema_id) AS schema_name,
    name AS procedure_name,
    create_date,
    modify_date
FROM sys.procedures
WHERE SCHEMA_NAME(schema_id) = 'audit'
ORDER BY name;
```

### 5.2 Test Procedures

```sql
-- ============================================================
-- SMOKE TEST PROCEDURES
-- ============================================================

-- Test extract procedure (with dummy batch)
DECLARE @TestBatch UNIQUEIDENTIFIER = NEWID();

BEGIN TRY
    EXEC sathapana_staging.staging.usp_ExtractAll @TestBatch;
    PRINT 'Extract procedure: OK';
END TRY
BEGIN CATCH
    PRINT 'Extract procedure: FAILED - ' + ERROR_MESSAGE();
END CATCH

-- Test load procedure
BEGIN TRY
    EXEC sathapana_dwh.dw.usp_LoadAll @TestBatch;
    PRINT 'Load procedure: OK';
END TRY
BEGIN CATCH
    PRINT 'Load procedure: FAILED - ' + ERROR_MESSAGE();
END CATCH
```

---

## 6. Scheduling Configuration

### 6.1 SQL Server Agent Jobs

```sql
-- ============================================================
-- CREATE ETL SCHEDULED JOBS
-- ============================================================

USE msdb;
GO

-- Job 1: Daily ETL Pipeline
EXEC dbo.sp_add_job
    @job_name = N'ETL_Daily_Pipeline',
    @enabled = 1,
    @description = N'Daily ETL pipeline - Extract, Transform, Load',
    @category_name = N'[Uncategorized (Local)]',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator';

-- Add job steps
EXEC dbo.sp_add_jobstep
    @job_name = N'ETL_Daily_Pipeline',
    @step_name = N'1_Extract',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_staging.staging.usp_ExtractAll',
    @database_name = N'sathapana_staging',
    @retry_attempts = 3,
    @retry_interval = 5;

EXEC dbo.sp_add_jobstep
    @job_name = N'ETL_Daily_Pipeline',
    @step_name = N'2_Load',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_dwh.dw.usp_LoadAll',
    @database_name = N'sathapana_dwh',
    @retry_attempts = 3,
    @retry_interval = 5;

EXEC dbo.sp_add_jobstep
    @job_name = N'ETL_Daily_Pipeline',
    @step_name = N'3_Quality_Checks',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_dwh.audit.usp_RunDataQualityChecks',
    @database_name = N'sathapana_dwh',
    @retry_attempts = 1;

-- Create schedule (Daily at 2:00 AM)
EXEC dbo.sp_add_jobschedule
    @job_name = N'ETL_Daily_Pipeline',
    @name = N'Daily_2AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020000;

-- Assign to server
EXEC dbo.sp_add_jobserver
    @job_name = N'ETL_Daily_Pipeline',
    @server_name = N'(LOCAL)';
GO
```

### 6.2 Job Schedule Overview

| Job | Schedule | Time | Purpose |
|-----|----------|------|---------|
| ETL_Daily_Pipeline | Daily | 02:00 AM | Main ETL execution |
| ETL_Weekly_Maintenance | Weekly (Sunday) | 03:00 AM | Index rebuild, stats update |
| ETL_Monthly_Report | Monthly (1st) | 04:00 AM | Monthly regulatory reports |
| CDC_Cleanup | Daily | 03:00 AM | Clean old CDC data |

---

## 7. Testing & Validation

### 7.1 Pre-Production Testing

```markdown
## Testing Checklist

### Unit Testing
- [ ] All extract procedures tested
- [ ] All load procedures tested
- [ ] Data quality checks validated
- [ ] Error handling verified

### Integration Testing
- [ ] Full pipeline execution tested
- [ ] SCD Type 2 behavior verified
- [ ] Row count reconciliation passed
- [ ] Data marts refresh tested

### Performance Testing
- [ ] ETL completes within time window
- [ ] No blocking/locking issues
- [ ] Memory usage acceptable
- [ ] Disk I/O within limits

### User Acceptance Testing
- [ ] Business users validated reports
- [ ] Data accuracy confirmed
- [ ] Dashboard performance acceptable
```

### 7.2 Validation Queries

```sql
-- ============================================================
-- POST-DEPLOYMENT VALIDATION
-- ============================================================

-- Check row counts
SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count FROM sathapana_dwh.dw.dim_customer
UNION ALL
SELECT 'dim_account', COUNT(*) FROM sathapana_dwh.dw.dim_account
UNION ALL
SELECT 'fact_transactions', COUNT(*) FROM sathapana_dwh.dw.fact_transactions;

-- Check data freshness
SELECT 
    table_name,
    MAX(etl_load_date) AS last_load,
    DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()) AS hours_since_load
FROM sathapana_dwh.audit.etl_log
GROUP BY table_name;

-- Check for errors
SELECT 
    step_name,
    status,
    COUNT(*) AS execution_count
FROM sathapana_dwh.audit.etl_log
WHERE start_time >= DATEADD(DAY, -7, GETDATE())
GROUP BY step_name, status
ORDER BY step_name, status;
```

---

## 8. Post-Deployment Verification

### 8.1 Monitoring Setup

```sql
-- ============================================================
-- VERIFY MONITORING IS WORKING
-- ============================================================

-- Check monitoring views exist
SELECT 
    table_name,
    view_name
FROM (
    SELECT 'audit.etl_log' AS table_name, 'audit.vw_etl_current_status' AS view_name
    UNION
    SELECT 'audit.etl_log', 'audit.vw_etl_performance_summary'
    UNION
    SELECT 'audit.etl_log', 'audit.vw_etl_failures'
) v
WHERE OBJECT_ID(v.view_name) IS NOT NULL;

-- Test alert procedure
BEGIN TRY
    EXEC sathapana_dwh.audit.usp_SendAlert
        @AlertType = 'TEST',
        @Message = 'Deployment verification test',
        @Severity = 'LOW';
    PRINT 'Alert system: OK';
END TRY
BEGIN CATCH
    PRINT 'Alert system: FAILED - ' + ERROR_MESSAGE();
END CATCH
```

### 8.2 First ETL Run Monitoring

```sql
-- ============================================================
-- MONITOR FIRST PRODUCTION RUN
-- ============================================================

-- Watch ETL progress
SELECT 
    step_name,
    status,
    start_time,
    end_time,
    duration_seconds,
    records_affected
FROM sathapana_dwh.audit.etl_log
WHERE batch_id = (
    SELECT TOP 1 batch_id 
    FROM sathapana_dwh.audit.etl_log 
    ORDER BY start_time DESC
)
ORDER BY start_time;

-- Check for any errors
SELECT *
FROM sathapana_dwh.audit.etl_log
WHERE status = 'FAILED'
AND start_time >= DATEADD(HOUR, -24, GETDATE());
```

---

## 9. Rollback Plan

### 9.1 Rollback Procedure

```sql
-- ============================================================
-- ROLLBACK PROCEDURE (Emergency Use Only)
-- ============================================================

-- STEP 1: Disable ETL jobs
EXEC msdb.dbo.sp_update_job
    @job_name = N'ETL_Daily_Pipeline',
    @enabled = 0;

-- STEP 2: Backup current databases
BACKUP DATABASE sathapana_staging TO DISK = 'C:\Backup\sathapana_staging_rollback.bak';
BACKUP DATABASE sathapana_dwh TO DISK = 'C:\Backup\sathapana_dwh_rollback.bak';

-- STEP 3: Restore from previous backup (if needed)
-- RESTORE DATABASE sathapana_staging FROM DISK = 'C:\Backup\sathapana_staging_previous.bak';
-- RESTORE DATABASE sathapana_dwh FROM DISK = 'C:\Backup\sathapana_dwh_previous.bak';

-- STEP 4: Re-enable ETL jobs (after rollback)
-- EXEC msdb.dbo.sp_update_job @job_name = N'ETL_Daily_Pipeline', @enabled = 1;

PRINT 'Rollback procedure completed.';
```

### 9.2 Rollback Checklist

```markdown
## Rollback Checklist

- [ ] Stop all ETL jobs
- [ ] Notify stakeholders
- [ ] Backup current state
- [ ] Restore previous version
- [ ] Verify data integrity
- [ ] Re-enable jobs (if needed)
- [ ] Document incident
- [ ] Schedule post-mortem
```

---

## 10. Production Monitoring

### 10.1 Daily Health Check

```sql
-- ============================================================
-- DAILY HEALTH CHECK PROCEDURE
-- ============================================================

CREATE PROCEDUREdbo.usp_ProductionHealthCheck
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '=== PRODUCTION HEALTH CHECK ===';
    PRINT 'Date: ' + CONVERT(VARCHAR(20), GETDATE(), 120);
    PRINT '';
    
    -- Check 1: ETL job status
    PRINT '1. ETL Job Status:';
    SELECT 
        step_name,
        status,
        end_time,
        duration_seconds
    FROM sathapana_dwh.audit.etl_log
    WHERE start_time >= DATEADD(HOUR, -24, GETDATE())
    ORDER BY start_time DESC;
    
    -- Check 2: Data freshness
    PRINT '2. Data Freshness:';
    SELECT 
        table_name,
        MAX(end_time) AS last_load,
        DATEDIFF(HOUR, MAX(end_time), GETDATE()) AS hours_old
    FROM sathapana_dwh.audit.etl_log
    WHERE status = 'COMPLETED'
    GROUP BY table_name;
    
    -- Check 3: Error count
    PRINT '3. Errors (last 24h):';
    SELECT COUNT(*) AS error_count
    FROM sathapana_dwh.audit.etl_log
    WHERE status = 'FAILED'
    AND start_time >= DATEADD(HOUR, -24, GETDATE());
    
    -- Check 4: Database size
    PRINT '4. Database Sizes:';
    EXEC sp_spaceused @databaseonly = 1;
END;
```

### 10.2 Monitoring Dashboard

```sql
-- ============================================================
-- PRODUCTION MONITORING VIEW
-- ============================================================

CREATE VIEW audit.vw_production_dashboard
AS
SELECT 
    CAST(start_time AS DATE) AS execution_date,
    step_name,
    status,
    COUNT(*) AS execution_count,
    AVG(duration_seconds) AS avg_duration,
    SUM(records_affected) AS total_records,
    MAX(end_time) AS last_execution
FROM sathapana_dwh.audit.etl_log
WHERE start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(start_time AS DATE), step_name, status;
```

---

## Deployment Summary

### Quick Reference

| Phase | Key Actions | Scripts |
|-------|-------------|---------|
| **Pre-Deployment** | Checklist, security setup | Manual |
| **Database Setup** | Create databases, schemas | `03-staging`, `04-data-warehouse` |
| **ETL Deployment** | Deploy procedures | `06-etl/*` |
| **Quality & Monitoring** | Deploy framework | `07-data-quality`, `08-monitoring` |
| **Scheduling** | Create Agent jobs | `12-automation` |
| **Testing** | Smoke test, validation | `20-testing` |
| **Go-Live** | Enable jobs, monitor | Manual |

### Success Criteria

- [ ] All databases created successfully
- [ ] All procedures deployed without errors
- [ ] Agent jobs created and enabled
- [ ] First ETL run completed successfully
- [ ] Data quality checks passing
- [ ] Monitoring alerts working
- [ ] Business users validated data

---

*Created: September 2024*
*Sathapana Bank Data Engineering Project*
