# 📧 Report Distribution Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Report Types](#2-report-types)
3. [Distribution Methods](#3-distribution-methods)
4. [Email Distribution](#4-email-distribution)
5. [Scheduling](#5-scheduling)
6. [Archive & Retention](#6-archive--retention)

---

## 1. Overview

Automated report distribution ensures stakeholders receive timely business intelligence.

```
┌─────────────────────────────────────────────────────────────────┐
│                    REPORT DISTRIBUTION FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │   DW/ETL    │  Data warehouse updated                       │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │   REPORT    │  Generate reports                              │
│  │   ENGINE    │                                                │
│  └──────┬──────┘                                                │
│         │                                                        │
│    ┌────┴────┐                                                  │
│    │         │                                                  │
│    ▼         ▼                                                  │
│  ┌─────┐  ┌─────┐                                              │
│  │Email│  │ FTP │                                              │
│  └──┬──┘  └──┬──┘                                              │
│     │        │                                                  │
│     ▼        ▼                                                  │
│  ┌─────────────┐                                                │
│  │  STAKEHOLDERS│                                               │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Report Types

| Report | Frequency | Audience | Format |
|--------|-----------|----------|--------|
| Daily Transaction Summary | Daily | Management | Excel/PDF |
| NPL Report | Daily | Risk Team | Excel |
| CAR Report | Monthly | Compliance | PDF |
| Branch Performance | Weekly | Regional Managers | Excel |
| Customer Analysis | Monthly | Marketing | Power BI |
| NBC Regulatory | Monthly | Regulators | PDF |

---

## 3. Distribution Methods

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Email** | Regular reports | Simple, widely used | Attachment limits |
| **FTP/SFTP** | Large files | No size limits | Complex setup |
| **SharePoint** | Collaboration | Version control | Requires license |
| **Power BI** | Interactive | Real-time | Requires subscription |
| **File Share** | Internal | Simple | Security concerns |

---

## 4. Email Distribution

### Database Mail Setup

```sql
-- ============================================================
-- CONFIGURE DATABASE MAIL
-- ============================================================

-- Enable Database Mail
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;

-- Create mail account
EXEC msdb.dbo.sp_add_account
    @account_name = 'DWH_Reports',
    @email_address = 'dwh-reports@bank.com',
    @display_name = 'DWH Reports',
    @mailserver_name = 'smtp.bank.com',
    @port = 587,
    @enable_ssl = 1;

-- Create mail profile
EXEC msdb.dbo.sp_add_profile
    @profile_name = 'DWH_Report_Profile',
    @description = 'DWH Report Distribution';

-- Add account to profile
EXEC msdb.dbo.sp_add_profileaccount
    @profile_name = 'DWH_Report_Profile',
    @account_name = 'DWH_Reports',
    @sequence_number = 1;
```

### Report Distribution Procedure

```sql
-- ============================================================
-- EMAIL REPORT DISTRIBUTION
-- ============================================================

CREATE PROCEDURE report.usp_DistributeDailyReport
    @ReportDate DATE
AS
BEGIN
    DECLARE @Subject NVARCHAR(255);
    DECLARE @Body NVARCHAR(MAX);
    DECLARE @Recipients NVARCHAR(500);
    
    -- Build subject
    SET @Subject = 'Daily Transaction Report - ' + CONVERT(VARCHAR(10), @ReportDate, 120);
    
    -- Build HTML body
    SET @Body = '
    <html>
    <head>
    <style>
        body { font-family: Arial; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4472C4; color: white; }
        .summary { background-color: #f2f2f2; padding: 15px; margin: 10px 0; }
    </style>
    </head>
    <body>
        <h2>Daily Transaction Report</h2>
        <p>Report Date: ' + CONVERT(VARCHAR(10), @ReportDate, 120) + '</p>
        
        <div class="summary">
            <h3>Summary</h3>';
    
    -- Add summary data
    DECLARE @TotalTxn BIGINT, @TotalAmount DECIMAL(18,2);
    
    SELECT 
        @TotalTxn = COUNT(*),
        @TotalAmount = SUM(amount_usd)
    FROM dw.fact_transactions t
    JOIN dw.dim_date d ON t.date_key = d.date_key
    WHERE d.full_date = @ReportDate;
    
    SET @Body = @Body + '
            <p>Total Transactions: ' + CAST(ISNULL(@TotalTxn, 0) AS VARCHAR(20)) + '</p>
            <p>Total Amount (USD): $' + FORMAT(ISNULL(@TotalAmount, 0), 'N2') + '</p>
        </div>
        
        <h3>Top 10 Branches</h3>
        <table>
            <tr>
                <th>Branch</th>
                <th>Transactions</th>
                <th>Amount (USD)</th>
            </tr>';
    
    -- Add branch data
    SELECT @Body = @Body + '
            <tr>
                <td>' + b.branch_name + '</td>
                <td>' + CAST(COUNT(*) AS VARCHAR(10)) + '</td>
                <td>$' + FORMAT(SUM(t.amount_usd), 'N2') + '</td>
            </tr>'
    FROM dw.fact_transactions t
    JOIN dw.dim_branch b ON t.branch_key = b.branch_key
    JOIN dw.dim_date d ON t.date_key = d.date_key
    WHERE d.full_date = @ReportDate
    GROUP BY b.branch_name
    ORDER BY SUM(t.amount_usd) DESC
    OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
    
    SET @Body = @Body + '
        </table>
        
        <p><em>This is an automated report from the Data Warehouse.</em></p>
    </body>
    </html>';
    
    -- Get recipients
    SELECT @Recipients = STRING_AGG(email, ';')
    FROM report.distribution_list
    WHERE report_type = 'DAILY_TRANSACTION'
    AND is_active = 1;
    
    -- Send email
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'DWH_Report_Profile',
        @recipients = @Recipients,
        @subject = @Subject,
        @body = @Body,
        @body_format = 'HTML';
    
    PRINT 'Report distributed to: ' + @Recipients;
END;
GO
```

---

## 5. Scheduling

### Distribution Schedule

| Report | Time | Recipients |
|--------|------|------------|
| Daily Transaction | 7:00 AM | Management |
| NPL Summary | 7:30 AM | Risk Team |
| Branch Performance | Monday 8:00 AM | Regional Managers |
| Monthly CAR | 1st of month | Compliance |
| Regulatory Package | 10th of month | NBC |

### SQL Agent Job

```sql
-- Create distribution job
EXEC msdb.dbo.sp_add_job
    @job_name = N'Report_Distribution_Daily',
    @enabled = 1;

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'Report_Distribution_Daily',
    @step_name = N'Send_Daily_Reports',
    @subsystem = N'TSQL',
    @command = N'EXEC report.usp_DistributeDailyReport @ReportDate = GETDATE()',
    @database_name = N'sathapana_dwh';

EXEC msdb.dbo.sp_add_jobschedule
    @job_name = N'Report_Distribution_Daily',
    @name = N'Daily_7AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 070000;
```

---

## 6. Archive & Retention

```sql
-- ============================================================
-- REPORT ARCHIVE TABLE
-- ============================================================

CREATE TABLE report.distribution_log (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    report_name VARCHAR(100),
    report_date DATE,
    recipients NVARCHAR(500),
    file_path NVARCHAR(500),
    file_size_kb INT,
    status VARCHAR(20), -- SENT, FAILED
    sent_date DATETIME DEFAULT GETDATE()
);

-- Archive old reports (keep 90 days)
DELETE FROM report.distribution_log
WHERE sent_date < DATEADD(DAY, -90, GETDATE());
```

---

*Created: September 2024*
