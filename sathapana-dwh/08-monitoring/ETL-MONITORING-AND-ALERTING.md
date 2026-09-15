# 📊 ETL Monitoring & Alerting Guide

## Table of Contents
1. [Overview](#1-overview)
2. [Monitoring Dashboard](#2-monitoring-dashboard)
3. [Alert Configuration](#3-alert-configuration)
4. [Email Notifications](#4-email-notifications)
5. [Performance Monitoring](#5-performance-monitoring)
6. [Health Checks](#6-health-checks)
7. [Hands-On Exercise](#7-hands-on-exercise)

---

## 1. Overview

ETL Monitoring ensures the pipeline runs correctly and alerts operators when issues occur.

```
┌─────────────────────────────────────────────────────────────────┐
│                    ETL MONITORING ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │ ETL Process │  Execute ETL pipeline                          │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Audit Log   │  Log every step, row count, duration           │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Monitoring  │  Check: Status, Performance, Errors            │
│  │ Engine      │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│    ┌────┴────┐                                                  │
│    │         │                                                  │
│    ▼         ▼                                                  │
│  ┌─────┐  ┌─────────┐                                          │
│  │ OK  │  │ALERT    │                                          │
│  └─────┘  └────┬────┘                                          │
│                │                                                │
│                ▼                                                │
│  ┌─────────────────────┐                                        │
│  │ Email / SMS / Slack │                                        │
│  │ Notification        │                                        │
│  └─────────────────────┘                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Monitoring Dashboard

### Create Monitoring Views

```sql
-- ============================================================
-- ETL MONITORING VIEWS
-- ============================================================

-- View 1: Current ETL Status
CREATE VIEW audit.vw_etl_current_status
AS
SELECT 
    batch_id,
    step_name,
    table_name,
    operation,
    records_affected,
    status,
    start_time,
    end_time,
    duration_seconds,
    CASE 
        WHEN status = 'COMPLETED' THEN '✅'
        WHEN status = 'RUNNING' THEN '⏳'
        WHEN status = 'FAILED' THEN '❌'
        ELSE '❓'
    END AS status_icon
FROM audit.etl_log
WHERE start_time >= DATEADD(HOUR, -24, GETDATE())
ORDER BY start_time DESC;
GO

-- View 2: ETL Performance Summary
CREATE VIEW audit.vw_etl_performance_summary
AS
SELECT 
    CAST(start_time AS DATE) AS execution_date,
    step_name,
    COUNT(*) AS execution_count,
    AVG(duration_seconds) AS avg_duration_sec,
    MAX(duration_seconds) AS max_duration_sec,
    SUM(records_affected) AS total_records,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failure_count
FROM audit.etl_log
WHERE start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(start_time AS DATE), step_name;
GO

-- View 3: Failed ETL Steps
CREATE VIEW audit.vw_etl_failures
AS
SELECT 
    batch_id,
    step_name,
    table_name,
    start_time,
    duration_seconds,
    created_date
FROM audit.etl_log
WHERE status = 'FAILED'
AND start_time >= DATEADD(DAY, -7, GETDATE());
GO

-- View 4: ETL Trend Analysis
CREATE VIEW audit.vw_etl_trend
AS
SELECT 
    CAST(start_time AS DATE) AS execution_date,
    SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failure_count,
    CAST(SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(*), 0) AS DECIMAL(5,1)) AS success_rate_pct
FROM audit.etl_log
WHERE start_time >= DATEADD(DAY, -30, GETDATE())
GROUP BY CAST(start_time AS DATE);
GO
```

### Query Monitoring Views

```sql
-- Check current ETL status
SELECT * FROM audit.vw_etl_current_status;

-- Check performance summary
SELECT * FROM audit.vw_etl_performance_summary;

-- Check recent failures
SELECT * FROM audit.vw_etl_failures;

-- Check success rate trend
SELECT * FROM audit.vw_etl_trend ORDER BY execution_date DESC;
```

---

## 3. Alert Configuration

### Alert Rules Table

```sql
-- Alert configuration table
CREATE TABLE audit.alert_rules (
    alert_id INT IDENTITY(1,1) PRIMARY KEY,
    alert_name VARCHAR(100),
    alert_type VARCHAR(50),     -- FAILURE, PERFORMANCE, DATA_QUALITY
    threshold_value DECIMAL(10,2),
    threshold_unit VARCHAR(20), -- MINUTES, PERCENT, COUNT
    severity VARCHAR(20),       -- CRITICAL, HIGH, MEDIUM, LOW
    is_enabled BIT DEFAULT 1,
    notification_email VARCHAR(255),
    notification_sms VARCHAR(20),
    created_date DATETIME DEFAULT GETDATE()
);

-- Insert default alert rules
INSERT INTO audit.alert_rules (alert_name, alert_type, threshold_value, threshold_unit, severity, notification_email)
VALUES
    ('ETL Step Failure', 'FAILURE', 1, 'COUNT', 'CRITICAL', 'dwh-ops@bank.com'),
    ('ETL Duration Warning', 'PERFORMANCE', 60, 'MINUTES', 'HIGH', 'dwh-ops@bank.com'),
    ('ETL Duration Critical', 'PERFORMANCE', 120, 'MINUTES', 'CRITICAL', 'dwh-manager@bank.com'),
    ('Data Quality Check Failed', 'DATA_QUALITY', 1, 'COUNT', 'HIGH', 'data-quality@bank.com'),
    ('Row Count Mismatch', 'DATA_QUALITY', 10, 'PERCENT', 'MEDIUM', 'dwh-ops@bank.com');
```

### Alert Evaluation Procedure

```sql
CREATE PROCEDURE audit.usp_EvaluateAlerts
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Alerts TABLE (
        alert_name VARCHAR(100),
        severity VARCHAR(20),
        message NVARCHAR(500),
        notification_email VARCHAR(255)
    );
    
    -- Check 1: Failed ETL steps
    INSERT INTO @Alerts
    SELECT 
        'ETL Step Failure',
        'CRITICAL',
        'ETL step failed: ' + step_name + ' at ' + CONVERT(VARCHAR(20), start_time, 120),
        r.notification_email
    FROM audit.etl_log l
    CROSS JOIN audit.alert_rules r
    WHERE l.status = 'FAILED'
    AND r.alert_type = 'FAILURE'
    AND r.is_enabled = 1
    AND l.start_time >= DATEADD(MINUTE, -5, GETDATE());
    
    -- Check 2: Long running steps
    INSERT INTO @Alerts
    SELECT 
        'ETL Duration Warning',
        'HIGH',
        'ETL step ' + step_name + ' took ' + CAST(duration_seconds/60 AS VARCHAR(10)) + ' minutes',
        r.notification_email
    FROM audit.etl_log l
    CROSS JOIN audit.alert_rules r
    WHERE r.alert_type = 'PERFORMANCE'
    AND r.threshold_unit = 'MINUTES'
    AND l.duration_seconds > r.threshold_value * 60
    AND l.start_time >= DATEADD(MINUTE, -5, GETDATE());
    
    -- Display alerts
    IF EXISTS (SELECT 1 FROM @Alerts)
    BEGIN
        PRINT '⚠️  ALERTS TRIGGERED:';
        SELECT * FROM @Alerts;
        
        -- TODO: Send email notifications here
    END
    ELSE
    BEGIN
        PRINT '✅ No alerts triggered.';
    END
END;
```

---

## 4. Email Notifications

### Email Configuration Table

```sql
-- Email configuration
CREATE TABLE audit.email_config (
    config_id INT IDENTITY(1,1) PRIMARY KEY,
    config_name VARCHAR(100),
    smtp_server VARCHAR(100),
    smtp_port INT,
    use_ssl BIT,
    sender_email VARCHAR(255),
    sender_password NVARCHAR(255),  -- Should be encrypted in production
    is_enabled BIT DEFAULT 1
);

-- Insert email config (placeholder - use Database Mail in production)
INSERT INTO audit.email_config (config_name, smtp_server, smtp_port, use_ssl, sender_email)
VALUES ('ETL_Notifications', 'smtp.bank.com', 587, 1, 'etl-alerts@bank.com');
```

### Email Notification Procedure (Database Mail)

```sql
-- ============================================================
-- EMAIL NOTIFICATION USING DATABASE MAIL
-- ============================================================

-- Note: Requires Database Mail to be configured on SQL Server
-- Run this first to enable Database Mail:
-- EXEC sys.sp_configure 'show advanced options', 1;
-- RECONFIGURE;
-- EXEC sys.sp_configure 'Database Mail XPs', 1;
-- RECONFIGURE;

CREATE PROCEDURE audit.usp_SendETLAlertEmail
    @Subject NVARCHAR(255),
    @Body NVARCHAR(MAX),
    @Recipients NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Send email using Database Mail
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'ETL_Notifications',
        @recipients = @Recipients,
        @subject = @Subject,
        @body = @Body,
        @body_format = 'HTML';
    
    PRINT 'Email sent to: ' + @Recipients;
END;
```

### Alert Email Templates

```sql
-- ============================================================
-- ETL FAILURE ALERT EMAIL
-- ============================================================
CREATE PROCEDURE audit.usp_SendFailureAlert
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @Subject NVARCHAR(255);
    DECLARE @Body NVARCHAR(MAX);
    DECLARE @Recipients NVARCHAR(500);
    
    -- Get alert recipients
    SELECT @Recipients = notification_email
    FROM audit.alert_rules
    WHERE alert_type = 'FAILURE'
    AND severity = 'CRITICAL'
    AND is_enabled = 1;
    
    -- Build subject
    SET @Subject = '🚨 ETL FAILURE ALERT - Batch: ' + CAST(@BatchID AS VARCHAR(50));
    
    -- Build HTML body
    SET @Body = '
    <html>
    <head>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #d9534f; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .failed { color: #d9534f; font-weight: bold; }
    </style>
    </head>
    <body>
        <h1>🚨 ETL Pipeline Failure Alert</h1>
        <p><strong>Batch ID:</strong> ' + CAST(@BatchID AS VARCHAR(50)) + '</p>
        <p><strong>Time:</strong> ' + CONVERT(VARCHAR(20), GETDATE(), 120) + '</p>
        
        <h2>Failed Steps:</h2>
        <table>
            <tr>
                <th>Step Name</th>
                <th>Table</th>
                <th>Start Time</th>
                <th>Duration (sec)</th>
            </tr>';
    
    -- Add failed steps
    SELECT @Body = @Body + '
            <tr>
                <td>' + step_name + '</td>
                <td>' + ISNULL(table_name, 'N/A') + '</td>
                <td>' + CONVERT(VARCHAR(20), start_time, 120) + '</td>
                <td class="failed">' + CAST(duration_seconds AS VARCHAR(10)) + '</td>
            </tr>'
    FROM audit.etl_log
    WHERE batch_id = @BatchID
    AND status = 'FAILED';
    
    SET @Body = @Body + '
        </table>
        
        <p>Please investigate and take corrective action.</p>
        
        <p><em>This is an automated message from the ETL Monitoring System.</em></p>
    </body>
    </html>';
    
    -- Send email
    EXEC audit.usp_SendETLAlertEmail
        @Subject = @Subject,
        @Body = @Body,
        @Recipients = @Recipients;
END;
```

### ETL Completion Email

```sql
CREATE PROCEDURE audit.usp_SendCompletionReport
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @Subject NVARCHAR(255);
    DECLARE @Body NVARCHAR(MAX);
    DECLARE @Recipients NVARCHAR(500);
    DECLARE @TotalSteps INT;
    DECLARE @SuccessSteps INT;
    DECLARE @FailedSteps INT;
    DECLARE @TotalDuration INT;
    
    -- Get recipients (daily report recipients)
    SELECT @Recipients = STRING_AGG(notification_email, ';')
    FROM audit.alert_rules
    WHERE is_enabled = 1;
    
    -- Calculate statistics
    SELECT 
        @TotalSteps = COUNT(*),
        @SuccessSteps = SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END),
        @FailedSteps = SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END),
        @TotalDuration = SUM(duration_seconds)
    FROM audit.etl_log
    WHERE batch_id = @BatchID;
    
    -- Build subject
    SET @Subject = CASE 
        WHEN @FailedSteps = 0 THEN '✅ ETL Completed Successfully'
        ELSE '⚠️ ETL Completed with ' + CAST(@FailedSteps AS VARCHAR(10)) + ' Failures'
    END;
    SET @Subject = @Subject + ' - ' + CONVERT(VARCHAR(10), GETDATE(), 120);
    
    -- Build HTML body
    SET @Body = '
    <html>
    <head>
    <style>
        body { font-family: Arial, sans-serif; }
        h1 { color: #5cb85c; }
        h1.failure { color: #d9534f; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .success { color: #5cb85c; }
        .failed { color: #d9534f; }
    </style>
    </head>
    <body>
        <h1 class="' + CASE WHEN @FailedSteps > 0 THEN 'failure' ELSE '' END + '">
            ETL Pipeline Execution Report
        </h1>
        
        <h2>Summary</h2>
        <table>
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Batch ID</td><td>' + CAST(@BatchID AS VARCHAR(50)) + '</td></tr>
            <tr><td>Execution Date</td><td>' + CONVERT(VARCHAR(20), GETDATE(), 120) + '</td></tr>
            <tr><td>Total Steps</td><td>' + CAST(@TotalSteps AS VARCHAR(10)) + '</td></tr>
            <tr><td>Successful</td><td class="success">' + CAST(@SuccessSteps AS VARCHAR(10)) + '</td></tr>
            <tr><td>Failed</td><td class="' + CASE WHEN @FailedSteps > 0 THEN 'failed' ELSE 'success' END + '">' + CAST(@FailedSteps AS VARCHAR(10)) + '</td></tr>
            <tr><td>Duration</td><td>' + CAST(@TotalDuration AS VARCHAR(10)) + ' seconds</td></tr>
        </table>
        
        <h2>Step Details</h2>
        <table>
            <tr>
                <th>Step</th>
                <th>Table</th>
                <th>Status</th>
                <th>Duration (sec)</th>
                <th>Records</th>
            </tr>';
    
    -- Add step details
    SELECT @Body = @Body + '
            <tr>
                <td>' + step_name + '</td>
                <td>' + ISNULL(table_name, 'N/A') + '</td>
                <td class="' + CASE WHEN status = 'COMPLETED' THEN 'success' ELSE 'failed' END + '">' + status + '</td>
                <td>' + ISNULL(CAST(duration_seconds AS VARCHAR(10)), 'N/A') + '</td>
                <td>' + ISNULL(CAST(records_affected AS VARCHAR(10)), 'N/A') + '</td>
            </tr>'
    FROM audit.etl_log
    WHERE batch_id = @BatchID
    ORDER BY start_time;
    
    SET @Body = @Body + '
        </table>
        
        <p><em>This is an automated message from the ETL Monitoring System.</em></p>
    </body>
    </html>';
    
    -- Send email
    EXEC audit.usp_SendETLAlertEmail
        @Subject = @Subject,
        @Body = @Body,
        @Recipients = @Recipients;
END;
```

---

## 5. Performance Monitoring

### Performance Tracking Queries

```sql
-- ============================================================
-- ETL PERFORMANCE MONITORING
-- ============================================================

-- Find slowest ETL steps
CREATE PROCEDURE audit.usp_GetSlowestSteps
    @TopN INT = 10,
    @DaysBack INT = 30
AS
BEGIN
    SELECT TOP (@TopN)
        step_name,
        COUNT(*) AS execution_count,
        AVG(duration_seconds) AS avg_duration_sec,
        MAX(duration_seconds) AS max_duration_sec,
        SUM(records_affected) AS total_records,
        AVG(CAST(records_affected AS FLOAT) / NULLIF(duration_seconds, 0)) AS avg_records_per_sec
    FROM audit.etl_log
    WHERE operation = 'LOAD'
    AND start_time >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY step_name
    ORDER BY avg_duration_sec DESC;
END;

-- Find performance trends
CREATE PROCEDURE audit.usp_GetPerformanceTrends
    @DaysBack INT = 30
AS
BEGIN
    SELECT 
        CAST(start_time AS DATE) AS execution_date,
        SUM(duration_seconds) AS total_duration_sec,
        SUM(records_affected) AS total_records,
        COUNT(*) AS total_steps,
        SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS failures
    FROM audit.etl_log
    WHERE start_time >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY CAST(start_time AS DATE)
    ORDER BY execution_date DESC;
END;

-- Compare current vs average performance
CREATE PROCEDURE audit.usp_ComparePerformance
AS
BEGIN
    SELECT 
        step_name,
        (SELECT duration_seconds FROM audit.etl_log WHERE step_name = l.step_name ORDER BY start_time DESC LIMIT 1) AS current_duration,
        AVG(duration_seconds) AS avg_duration,
        CASE 
            WHEN (SELECT duration_seconds FROM audit.etl_log WHERE step_name = l.step_name ORDER BY start_time DESC LIMIT 1) > AVG(duration_seconds) * 1.5
            THEN 'SLOWER'
            WHEN (SELECT duration_seconds FROM audit.etl_log WHERE step_name = l.step_name ORDER BY start_time DESC LIMIT 1) < AVG(duration_seconds) * 0.5
            THEN 'FASTER'
            ELSE 'NORMAL'
        END AS performance_status
    FROM audit.etl_log l
    WHERE operation = 'LOAD'
    AND start_time >= DATEADD(DAY, -30, GETDATE())
    GROUP BY step_name;
END;
```

---

## 6. Health Checks

### ETL Health Check Procedure

```sql
CREATE PROCEDURE audit.usp_HealthCheck
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @HealthStatus TABLE (
        check_name VARCHAR(100),
        status VARCHAR(20),
        details NVARCHAR(500)
    );
    
    -- Check 1: Recent ETL runs
    INSERT INTO @HealthStatus
    SELECT 
        'Recent ETL Runs',
        CASE 
            WHEN COUNT(*) > 0 THEN 'OK'
            ELSE 'WARNING'
        END,
        CAST(COUNT(*) AS VARCHAR(10)) + ' runs in last 24 hours'
    FROM audit.etl_log
    WHERE start_time >= DATEADD(HOUR, -24, GETDATE());
    
    -- Check 2: Failed runs
    INSERT INTO @HealthStatus
    SELECT 
        'Failed Runs (24h)',
        CASE 
            WHEN COUNT(*) = 0 THEN 'OK'
            WHEN COUNT(*) <= 2 THEN 'WARNING'
            ELSE 'CRITICAL'
        END,
        CAST(COUNT(*) AS VARCHAR(10)) + ' failures in last 24 hours'
    FROM audit.etl_log
    WHERE status = 'FAILED'
    AND start_time >= DATEADD(HOUR, -24, GETDATE());
    
    -- Check 3: Average duration
    INSERT INTO @HealthStatus
    SELECT 
        'Avg ETL Duration',
        CASE 
            WHEN AVG(duration_seconds) <= 3600 THEN 'OK'  -- Under 1 hour
            WHEN AVG(duration_seconds) <= 7200 THEN 'WARNING'  -- Under 2 hours
            ELSE 'CRITICAL'
        END,
        'Average: ' + CAST(CAST(AVG(duration_seconds)/60 AS INT) AS VARCHAR(10)) + ' minutes'
    FROM audit.etl_log
    WHERE operation = 'LOAD'
    AND start_time >= DATEADD(DAY, -7, GETDATE());
    
    -- Check 4: Data freshness
    INSERT INTO @HealthStatus
    SELECT 
        'Data Freshness',
        CASE 
            WHEN DATEDIFF(HOUR, MAX(end_time), GETDATE()) <= 24 THEN 'OK'
            WHEN DATEDIFF(HOUR, MAX(end_time), GETDATE()) <= 48 THEN 'WARNING'
            ELSE 'CRITICAL'
        END,
        'Last successful load: ' + CONVERT(VARCHAR(20), MAX(end_time), 120)
    FROM audit.etl_log
    WHERE status = 'COMPLETED'
    AND operation = 'LOAD';
    
    -- Check 5: Audit log size
    INSERT INTO @HealthStatus
    SELECT 
        'Audit Log Size',
        CASE 
            WHEN COUNT(*) < 100000 THEN 'OK'
            WHEN COUNT(*) < 500000 THEN 'WARNING'
            ELSE 'CRITICAL'
        END,
        CAST(COUNT(*) AS VARCHAR(10)) + ' total log records'
    FROM audit.etl_log;
    
    -- Display results
    SELECT 
        check_name,
        CASE 
            WHEN status = 'OK' THEN '✅ ' + status
            WHEN status = 'WARNING' THEN '⚠️ ' + status
            WHEN status = 'CRITICAL' THEN '❌ ' + status
        END AS status,
        details
    FROM @HealthStatus;
    
    -- Overall health
    IF EXISTS (SELECT 1 FROM @HealthStatus WHERE status = 'CRITICAL')
        PRINT '';
        PRINT '❌ OVERALL HEALTH: CRITICAL - Immediate attention required!';
    ELSE IF EXISTS (SELECT 1 FROM @HealthStatus WHERE status = 'WARNING')
        PRINT '';
        PRINT '⚠️  OVERALL HEALTH: WARNING - Monitor closely';
    ELSE
        PRINT '';
        PRINT '✅ OVERALL HEALTH: GOOD - All systems operational';
END;
```

---

## 7. Hands-On Exercise

### Exercise: Build ETL Monitoring

```sql
-- Step 1: Create monitoring views
-- Step 2: Create alert rules table
-- Step 3: Implement health check procedure
-- Step 4: Test by running health check
-- Step 5: Simulate failure and verify alerts

-- Solution:
EXEC audit.usp_HealthCheck;
EXEC audit.usp_EvaluateAlerts;
```

---

*Created: September 2024*
