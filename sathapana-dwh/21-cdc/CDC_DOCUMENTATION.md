# Change Data Capture (CDC) Documentation

## Overview

Change Data Capture (CDC) is a SQL Server feature that captures changes (INSERT, UPDATE, DELETE) made to source tables and makes them available for data warehouse replication.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CDC REAL-TIME REPLICATION FLOW                        │
└─────────────────────────────────────────────────────────────────────────┘

    SOURCE DATABASE                    CDC INFRASTRUCTURE
    ────────────────                   ──────────────────
    ┌──────────────────┐
    │  oltp.customers  │ ──┐
    │  oltp.accounts   │   │
    │  oltp.transactions│   │     ┌─────────────────────────────┐
    │  oltp.loans      │   ├────►│  Transaction Log             │
    │  oltp.branches   │   │     │  (Captures all DML changes)  │
    │  oltp.products   │ ──┘     └──────────────┬──────────────┘
    └──────────────────┘                        │
                                                │ Every 15 min
                                    ┌───────────▼───────────┐
                                    │  CDC Log Reader Agent  │
                                    │  (sys.sp_cdc_scan)     │
                                    └───────────┬───────────┘
                                                │
                                    ┌───────────▼───────────┐
                                    │  cdc.change_tables     │
                                    │  (Change tracking)     │
                                    └───────────┬───────────┘
                                                │ Every 30 min
                                    ┌───────────▼───────────┐
                                    │  CDC Replication Job   │
                                    │  (usp_ReplicateToRaw)  │
                                    └───────────┬───────────┘
                                                │
    RAW ZONE                                  │
    ────────                                  ▼
    ┌─────────────────────────────────────────────────────┐
    │  sathapana_raw.raw.customers (with CDC metadata)   │
    │  sathapana_raw.raw.accounts                        │
    │  sathapana_raw.raw.transactions                    │
    └─────────────────────┬───────────────────────────────┘
                          │ ETL Pipeline (Daily)
                          ▼
    ┌─────────────────────────────────────────────────────┐
    │  sathapana_dwh (Enterprise Data Warehouse)         │
    └─────────────────────────────────────────────────────┘
```

---

## Key Concepts

### LSN (Log Sequence Number)
- Unique identifier for each transaction in the log
- Used to track change order
- Functions: `sys.fn_cdc_get_max_lsn()`, `sys.fn_cdc_get_min_lsn()`

### Change Operations
| Operation | Value | Description |
|-----------|-------|-------------|
| DELETE | 1 | Row was deleted |
| INSERT | 2 | Row was inserted |
| UPDATE (Before) | 3 | Row before update |
| UPDATE (After) | 4 | Row after update |

### Capture Instance
- Named tracking configuration for each source table
- Example: `oltp_customers` for `oltp.customers`

---

## CDC Tables Created

When CDC is enabled, these system tables are created:

| Table | Purpose |
|-------|---------|
| `cdc.change_tables` | Lists all CDC-enabled tables |
| `cdc.lsn_time_mapping` | Maps LSN to datetime |
| `cdc.[capture_instance]_CT` | Change data for each table |

---

## Querying CDC Changes

### Get All Changes Since Last Run
```sql
-- Get current maximum LSN
DECLARE @max_lsn BINARY(10) = sys.fn_cdc_get_max_lsn();

-- Get changes from last hour
DECLARE @from_time DATETIME = DATEADD(HOUR, -1, GETDATE());
DECLARE @from_lsn BINARY(10) = sys.fn_cdc_map_time_to_lsn('smallest greater than or equal to', @from_time);

-- Query changes
SELECT * FROM cdc.fn_cdc_get_all_changes_oltp_customers(@from_lsn, @max_lsn, 'all');
```

### Get Net Changes (Consolidated)
```sql
-- Get net changes (only final state)
SELECT * FROM cdc.fn_cdc_get_net_changes_oltp_customers(
    @from_lsn, @max_lsn, 'all'
);
```

### Check CDC Status
```sql
-- View CDC enabled tables
SELECT * FROM cdc.change_tables;

-- View LSN mapping
SELECT * FROM cdc.lsn_time_mapping ORDER BY tran_end_time DESC;
```

---

## Job Schedule

| Job | Frequency | Purpose |
|-----|-----------|---------|
| CDC_Log_Reader_Agent | Every 15 min | Captures changes from log |
| CDC_Replicate_to_Raw | Every 30 min | Copies to Raw Zone |
| CDC_Cleanup | Daily 3 AM | Removes old CDC data |

---

## Monitoring

### Check CDC Status View
```sql
SELECT * FROM sathapana_source.cdc.vw_CDC_Status;
```

### Check Replication Status
```sql
SELECT * FROM sathapana_raw.meta.cdc_replication_status;
```

### Monitor Log Reader
```sql
-- Check agent history
SELECT * FROM msdb.dbo.sysjobhistory 
WHERE job_id = (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'CDC_Log_Reader_Agent')
ORDER BY run_date DESC, run_time DESC;
```

---

## Maintenance

### Cleanup Old CDC Data
```sql
-- Keep 7 days of changes
EXEC sathapana_source.cdc.usp_CleanupCDC @RetentionHours = 168;
```

### Disable CDC (if needed)
```sql
-- Disable on specific table
EXEC sys.sp_cdc_disable_table
    @source_schema = 'oltp',
    @source_name = 'customers',
    @capture_instance = 'oltp_customers';

-- Disable on database
EXEC sys.sp_cdc_disable_db;
```

### Re-enable CDC
```sql
-- Re-enable on database
EXEC sys.sp_cdc_enable_db;

-- Re-enable on table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'oltp',
    @source_name = 'customers',
    @role_name = NULL,
    @supports_net_changes = 1;
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| CDC not capturing changes | Check Log Reader Agent is running |
| High log usage | Run cleanup more frequently |
| Replication lag | Check network, increase frequency |
| Missing changes | Verify LSN tracking, check for gaps |

### Check Log Reader Status
```sql
-- Check if log reader is running
EXEC msdb.dbo.sp_help_jobactivity 
    @job_name = 'CDC_Log_Reader_Agent';
```

### Check CDC Scan Status
```sql
-- Check CDC scan status
SELECT * FROM sys.dm_cdc_scan_sessions;
```

---

## Performance Considerations

1. **Log Space**: CDC increases log usage by ~20-30%
2. **Capture Overhead**: Minimal impact on source DML
3. **Query Performance**: Use net changes for better performance
4. **Retention**: Balance between history needs and storage

---

## Integration with ETL

### Near Real-Time ETL Pattern
```
Every 30 minutes:
1. CDC captures changes → cdc.change_tables
2. Replication job → sathapana_raw
3. Micro-batch ETL → sathapana_dwh
4. Refresh data marts → sathapana_dm_*
```

### Full Refresh vs CDC
| Aspect | Full Refresh | CDC |
|--------|--------------|-----|
| Data Latency | 24 hours | 30 minutes |
| Source Load | High | Low |
| Complexity | Low | Medium |
| History | Current only | Full history |

---

## Best Practices

1. **Monitor regularly** - Check CDC status daily
2. **Set retention** - Don't keep CDC data too long
3. **Index CDC tables** - Improve query performance
4. **Test recovery** - Know how to re-initialize CDC
5. **Document LSN** - Track replication checkpoints

---

## Requirements

- SQL Server Enterprise Edition (recommended)
- SQL Server 2016+ Standard Edition (limited CDC)
- Sufficient transaction log space
- SQL Server Agent enabled
- sysadmin or db_owner permissions

---

**Created for Sathapana Bank DWH**
**Architecture: Real-Time CDC Replication**
