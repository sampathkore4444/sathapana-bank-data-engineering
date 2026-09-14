# 12 - Automation (SQL Server Agent Jobs)

## Overview

This directory contains the SQL Server Agent job definitions that automate the daily ETL pipeline, maintenance tasks, and alerting.

## Files

| File | Purpose |
|------|---------|
| `01-create-agent-jobs.sql` | Creates all scheduled SQL Server Agent jobs |

## Job Inventory

| Job Name | Schedule | Purpose |
|----------|----------|---------|
| `DWH_00_Master_Pipeline` | Daily 2:00 AM | Orchestrates complete ETL pipeline |
| `DWH_01_Extract_to_Raw` | Daily 2:05 AM | Extract source → raw zone |
| `DWH_02_Extract_to_Staging` | Daily 3:00 AM | Extract raw → staging |
| `DWH_03_Load_to_DW` | Daily 4:00 AM | Transform & load to DW |
| `DWH_04_Data_Quality` | Daily 5:00 AM | Run quality checks |
| `DWH_05_Weekly_Maintenance` | Sunday 3:00 AM | Index rebuild, stats update |

## Job Chain (Dependencies)

```
DWH_00_Master_Pipeline (2:00 AM)
  │
  ├── Step 1: Run_Extract_to_Raw ──► (on success) ──┐
  │                                                   │
  ├── Step 2: Run_Extract_to_Staging ◄────────────────┘
  │              (on success) ──┐
  │                             │
  ├── Step 3: Run_Load_to_DW ◄──┘
  │              (on success) ──┐
  │                             │
  └── Step 4: Run_Data_Quality ◄┘
                 (on success → Quit with success)
```

## Job Details

### DWH_00_Master_Pipeline

**Purpose**: Master orchestration job that chains all ETL steps

**Steps**:
1. `Run_Extract_to_Raw` — Calls `raw.usp_ExtractAll`
2. `Run_Extract_to_Staging` — Calls `staging.usp_ExtractAll`
3. `Run_Load_to_DW` — Calls `dw.usp_LoadAll`
4. `Run_Data_Quality` — Calls `audit.usp_RunDataQualityChecks`

**Retry**: 3 attempts, 5-minute interval

### DWH_05_Weekly_Maintenance

**Purpose**: Performance maintenance (indexes, statistics)

**Steps**:
1. Update statistics on all tables
2. Rebuild fragmented indexes (> 30% fragmentation)
3. Cleanup old log records (> 90 days)

**Schedule**: Sunday at 3:00 AM

## Notifications

### Operator

| Setting | Value |
|---------|-------|
| Name | DWH_Operator |
| Email | dwh-admin@sathapana.com.kh |

### Alert

| Setting | Value |
|---------|-------|
| Alert Name | DWH_Job_Failure_Alert |
| Severity | 2 (Error) |
| Response Delay | 60 seconds |

## Job Status Query

```sql
-- View all DWH jobs
SELECT
    j.name AS job_name,
    j.enabled,
    j.description,
    CASE
        WHEN s.freq_type = 4 THEN 'Daily'
        WHEN s.freq_type = 8 THEN 'Weekly'
        ELSE 'Other'
    END AS schedule_type,
    CASE
        WHEN s.active_start_time IS NOT NULL
        THEN RIGHT('0' + CAST(s.active_start_time / 10000 AS VARCHAR(2)), 2) + ':' +
             RIGHT('0' + CAST((s.active_start_time % 10000) / 100 AS VARCHAR(2)), 2)
        ELSE 'N/A'
    END AS start_time
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name LIKE 'DWH_%'
ORDER BY j.name;
```

## Execution

```sql
-- Create all jobs
:12-automation/01-create-agent-jobs.sql

-- Manually trigger a job
EXEC msdb.dbo.sp_start_job @job_name = 'DWH_00_Master_Pipeline';

-- Check job history
SELECT * FROM msdb.dbo.sysjobhistory
WHERE job_id IN (SELECT job_id FROM msdb.dbo.sysjobs WHERE name LIKE 'DWH_%')
ORDER BY run_date DESC, run_time DESC;
```

## Troubleshooting

| Issue | Check |
|-------|-------|
| Job not running | `SELECT enabled FROM msdb.dbo.sysjobs WHERE name = 'DWH_00_Master_Pipeline'` |
| Step failed | `SELECT * FROM msdb.dbo.sysjobhistory WHERE job_name = '...' AND run_status = 0` |
| No alerts received | Verify operator email in `msdb.dbo.sysoperators` |
| Schedule wrong | Check `msdb.dbo.sysschedules` for schedule details |

## Notes

- Jobs use `sp_add_job`, `sp_add_jobstep`, `sp_add_jobschedule` (SQL Server standard)
- The master job chains steps with `on_success_action = 3` (Go to next step)
- Failed steps quit immediately with `on_fail_action = 2` (Quit with failure)
- All jobs run under the `sa` login (configurable)
