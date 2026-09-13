-- ============================================================================
-- SATHAPANA BANK - REPORT DISTRIBUTION AGENT JOBS
-- ============================================================================
-- Purpose: Schedule automated report generation and distribution
-- Author: DWH Development Team
-- ============================================================================

USE msdb;
GO

-- ============================================================================
-- 1. DAILY REPORTS JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_Daily_Reports')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_Daily_Reports';
END

EXEC sp_add_job
    @job_name = N'DWH_Daily_Reports',
    @enabled = 1,
    @description = N'Generate and distribute daily reports via email',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator';

-- Step 1: Generate Transaction Report
EXEC sp_add_jobstep
    @job_name = N'DWH_Daily_Reports',
    @step_name = N'Generate_Transaction_Report',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'EXEC audit.usp_GenerateTransactionReport;',
    @database_name = N'sathapana_dwh',
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2;     -- Quit with failure

-- Step 2: Generate Credit Risk Report
EXEC sp_add_jobstep
    @job_name = N'DWH_Daily_Reports',
    @step_name = N'Generate_Credit_Risk_Report',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'EXEC audit.usp_GenerateCreditRiskReport;',
    @database_name = N'sathapana_dwh',
    @on_success_action = 3,
    @on_fail_action = 2;

-- Step 3: Check NPL Warnings
EXEC sp_add_jobstep
    @job_name = N'DWH_Daily_Reports',
    @step_name = N'Check_NPL_Warnings',
    @step_id = 3,
    @subsystem = N'TSQL',
    @command = N'EXEC audit.usp_GenerateNPLWarningReport;',
    @database_name = N'sathapana_dwh',
    @on_success_action = 3,
    @on_fail_action = 2;

-- Step 4: Distribute Reports
EXEC sp_add_jobstep
    @job_name = N'DWH_Daily_Reports',
    @step_name = N'Distribute_Reports',
    @step_id = 4,
    @subsystem = N'TSQL',
    @command = N'EXEC audit.usp_DistributeReports @ReportType = ''DAILY'';',
    @database_name = N'sathapana_dwh',
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;

-- Schedule: Daily at 7:00 AM (after ETL completes)
EXEC sp_add_jobschedule
    @job_name = N'DWH_Daily_Reports',
    @name = N'Daily_7AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 070000;

PRINT '✓ Daily Reports job created';

-- ============================================================================
-- 2. WEEKLY REPORTS JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_Weekly_Reports')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_Weekly_Reports';
END

EXEC sp_add_job
    @job_name = N'DWH_Weekly_Reports',
    @enabled = 1,
    @description = N'Generate and distribute weekly reports',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator';

EXEC sp_add_jobstep
    @job_name = N'DWH_Weekly_Reports',
    @step_name = N'Generate_Weekly_Summary',
    @subsystem = N'TSQL',
    @command = N'EXEC audit.usp_DistributeReports @ReportType = ''WEEKLY'';',
    @database_name = N'sathapana_dwh',
    @on_success_action = 1,
    @on_fail_action = 2;

-- Schedule: Weekly on Monday at 7:30 AM
EXEC sp_add_jobschedule
    @job_name = N'DWH_Weekly_Reports',
    @name = N'Weekly_Monday_7AM',
    @freq_type = 8,  -- Weekly
    @freq_interval = 2,  -- Monday
    @active_start_time = 073000;

PRINT '✓ Weekly Reports job created';

-- ============================================================================
-- 3. MONTHLY REPORTS JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = N'DWH_Monthly_Reports')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_Monthly_Reports';
END

EXEC sp_add_job
    @job_name = N'DWH_Monthly_Reports',
    @enabled = 1,
    @description = N'Generate and distribute monthly regulatory reports',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator';

EXEC sp_add_jobstep
    @job_name = N'DWH_Monthly_Reports',
    @step_name = N'Generate_Monthly_Package',
    @subsystem = N'TSQL',
    @command = N'EXEC dw.usp_GenerateRegulatoryPackage;',
    @database_name = N'sathapana_dwh',
    @on_success_action = 3,
    @on_fail_action = 2;

EXEC sp_add_jobstep
    @job_name = N'DWH_Monthly_Reports',
    @step_name = N'Distribute_Monthly_Reports',
    @subsystem = N'TSQL',
    @command = N'EXEC audit.usp_DistributeReports @ReportType = ''MONTHLY'';',
    @database_name = N'sathapana_dwh',
    @on_success_action = 1,
    @on_fail_action = 2;

-- Schedule: Monthly on 1st at 8:00 AM
EXEC sp_add_jobschedule
    @job_name = N'DWH_Monthly_Reports',
    @name = N'Monthly_1st_8AM',
    @freq_type = 1,  -- One time (run monthly via script)
    @freq_interval = 1,
    @active_start_time = 080000;

PRINT '✓ Monthly Reports job created';

-- ============================================================================
-- 4. VERIFY JOBS
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'REPORT DISTRIBUTION JOBS CREATED';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT '';

SELECT 
    name AS job_name,
    CASE WHEN enabled = 1 THEN '✓ ENABLED' ELSE '✗ DISABLED' END AS status,
    description,
    CASE 
        WHEN js.freq_type = 4 THEN 'Daily at ' + RIGHT('0' + CAST(js.active_start_time / 10000 AS VARCHAR), 2) + ':' + RIGHT('0' + CAST((js.active_start_time % 10000) / 100 AS VARCHAR), 2)
        WHEN js.freq_type = 8 THEN 'Weekly on ' + 
            CASE js.freq_interval 
                WHEN 1 THEN 'Sunday' WHEN 2 THEN 'Monday' WHEN 3 THEN 'Tuesday'
                WHEN 4 THEN 'Wednesday' WHEN 5 THEN 'Thursday' WHEN 6 THEN 'Friday' WHEN 7 THEN 'Saturday'
            END
        ELSE 'Monthly'
    END AS schedule
FROM sysjobs j
LEFT JOIN sysjobschedules js ON j.job_id = js.job_id
WHERE j.name LIKE 'DWH_%Report%'
ORDER BY j.name;

PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'SCHEDULE SUMMARY:';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT '  Daily Reports:   Every day at 7:00 AM';
PRINT '  Weekly Reports:  Every Monday at 7:30 AM';
PRINT '  Monthly Reports: 1st of month at 8:00 AM';
PRINT '';
PRINT 'Reports Distributed:';
PRINT '  - Daily Transaction Summary';
PRINT '  - Credit Risk Daily Report';
PRINT '  - NPL Warning Report (if triggered)';
PRINT '  - Weekly Performance Summary';
PRINT '  - Monthly Regulatory Package';
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
GO
