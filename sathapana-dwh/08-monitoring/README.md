# 08 - Monitoring & Logging

## Overview

This directory contains the operational monitoring framework — tracking ETL job status, data freshness, system health, and performance metrics.

## Files

| File | Purpose |
|------|---------|
| `01-monitoring-framework.sql` | Monitoring views, alerting procedures, and dashboard objects |

## Monitoring Objects

### Tables

| Table | Purpose |
|-------|---------|
| `audit.etl_log` | ETL step execution history |
| `audit.etl_batch_log` | Batch-level execution tracking |
| `audit.error_log` | Application error capture |
| `audit.system_metrics` | Periodic system health snapshots |

### Views

| View | Purpose |
|------|---------|
| `audit.vw_monitoring_dashboard` | Real-time operational dashboard |
| `audit.vw_etl_job_history` | ETL job execution history |
| `audit.vw_data_freshness` | Data age per table |
| `audit.vw_table_sizes` | Table size and row count tracking |
| `audit.vw_error_summary` | Error trends and counts |
| `audit.vw_performance_metrics` | Query performance statistics |

### Procedures

| Procedure | Purpose |
|-----------|---------|
| `audit.usp_RunDataQualityChecks` | Execute all quality checks |
| `audit.usp_PerformMaintenance` | Index rebuild, stats update |
| `audit.usp_SendAlert` | Send alert notification |
| `audit.usp_CaptureMetrics` | Snapshot current system metrics |

## Dashboard Views

### ETL Job Status

```sql
SELECT * FROM audit.vw_etl_job_history
WHERE run_date = CAST(GETDATE() AS DATE)
ORDER BY start_time DESC;
```

**Columns**: Job name, step, status (RUNNING/COMPLETED/FAILED), start/end time, duration, rows affected, error message

### Data Freshness

```sql
SELECT * FROM audit.vw_data_freshness;
```

**Columns**: Table name, last load time, hours since load, freshness status (FRESH/STALE/CRITICAL)

### Table Sizes

```sql
SELECT * FROM audit.vw_table_sizes ORDER BY row_count DESC;
```

**Columns**: Schema, table name, row count, reserved MB, data MB, index MB

### Error Summary

```sql
SELECT * FROM audit.vw_error_summary;
```

**Columns**: Error type, count, last occurrence, affected tables

## Alerting

### Alert Types

| Alert | Trigger | Action |
|-------|---------|--------|
| ETL Failure | Job step fails | Email to DWH operator |
| Data Quality Failure | Critical rule fails | Email + SMS |
| Stale Data | Table not loaded in 24h | Email warning |
| Disk Space | Log file > 80% | Email warning |
| Performance | Query > 30 seconds | Log for review |

### Alert Procedure

```sql
EXEC audit.usp_SendAlert
    @AlertType = 'ETL_FAILURE',
    @Message = 'Step Transform_Dimensions failed',
    @Severity = 'HIGH';
```

## Maintenance Procedures

### Daily (Automated)

- ETL logging
- Quality check execution
- Freshness monitoring

### Weekly (Automated via Agent Job)

- Statistics update on all tables
- Index rebuild (fragmentation > 30%)
- Old log cleanup (retention: 90 days)

### Monthly (Manual Review)

- Performance trending report
- Capacity planning review
- Quality score trending

## Key Metrics to Monitor

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| ETL Completion | 100% daily | Any failure |
| Data Quality Score | ≥ 99.5% | < 99.0% |
| Data Freshness | < 6 hours | > 12 hours |
| Average Query Time | < 5 seconds | > 30 seconds |
| Database Size Growth | < 5% monthly | > 10% |
| Index Fragmentation | < 10% | > 30% |

## Execution

```sql
-- Run monitoring checks
EXEC audit.usp_CaptureMetrics;

-- View current status
SELECT * FROM audit.vw_monitoring_dashboard;
```

## Notes

- All monitoring data is stored in the `audit` schema
- Metrics are captured at the end of each ETL run
- Dashboard views can be connected to Power BI for visual monitoring
- Alert email configuration is in `12-automation/01-create-agent-jobs.sql`
