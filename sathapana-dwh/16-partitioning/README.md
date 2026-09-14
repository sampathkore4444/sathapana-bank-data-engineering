# 16 - Table Partitioning

## Overview

This directory contains the partitioning strategy for large fact tables — improving query performance and enabling efficient data archiving.

## Files

| File | Purpose |
|------|---------|
| `01-table-partitioning.sql` | Partition functions, schemes, and management procedures |

## Partitioning Strategy

### Partition Function: `PF_Monthly`

**Type**: RANGE RIGHT  
**Key**: `INT` (DateKey in `yyyyMMdd` format)  
**Granularity**: Monthly  

```
Partition 1:  < 20230101
Partition 2:  20230101 - 20230201
Partition 3:  20230201 - 20230301
...
Partition 48: 20261201 - 20270101
Partition 49: >= 20270101
```

### Partition Scheme: `PS_Monthly`

All partitions on `[PRIMARY]` filegroup (single-server setup).  
For multi-filegroup deployment, map partitions to separate filegroups.

## Target Tables

| Table | Partition Key | Rationale |
|-------|---------------|-----------|
| `dw.fact_transactions` | `transaction_date_key` | Highest volume, date-range queries |
| `dw.fact_account_daily_snapshot` | `snapshot_date_key` | Daily snapshots, date-range queries |
| `dw.fact_loan_portfolio` | `snapshot_date_key` | Monthly snapshots |
| `dw.fact_deposit_snapshot` | `snapshot_date_key` | Monthly snapshots |

## Management Procedures

| Procedure | Purpose |
|-----------|---------|
| `dw.usp_AddPartition` | Add partition for a future month |
| `dw.usp_MergePartition` | Merge (remove) a partition |
| `dw.usp_SwitchPartitionToArchive` | Move partition data to archive table |
| `dw.usp_PartitionMaintenance` | Automated maintenance (add next 12 months) |

### Add Partition

```sql
-- Add partition for next month
EXEC dw.usp_AddPartition @PartitionDate = '2026-10-01';
```

### Merge Partition

```sql
-- Merge old partition (data will be in adjacent partition)
EXEC dw.usp_MergePartition @PartitionDate = '2025-01-01';
```

### Switch to Archive

```sql
-- Move old data to archive table
EXEC dw.usp_SwitchPartitionToArchive
    @SourceTable = 'dw.fact_transactions',
    @ArchiveTable = 'dw.fact_transactions_archive',
    @PartitionValue = 20250101;
```

### Automated Maintenance

```sql
-- Add partitions for next 12 months + show current info
EXEC dw.usp_PartitionMaintenance;
```

## Monitoring

### Partition Info View

```sql
SELECT * FROM dw.vw_PartitionInfo;
```

**Columns**: Partition function, scheme, partition number, row count, boundary value

### Check Partition Distribution

```sql
-- Row counts per partition
SELECT p.partition_number, p.rows,
       rv.value AS boundary_value
FROM sys.partitions p
JOIN sys.partition_schemes ps ON p.data_space_id = ps.data_space_id
JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
LEFT JOIN sys.partition_range_values rv ON pf.function_id = rv.function_id
WHERE p.object_id = OBJECT_ID('dw.fact_transactions')
ORDER BY p.partition_number;
```

## Partition Maintenance Schedule

| Task | Frequency | Procedure |
|------|-----------|-----------|
| Add future partitions | Monthly | `usp_PartitionMaintenance` |
| Archive old partitions | Quarterly | `usp_SwitchPartitionToArchive` |
| Merge empty partitions | Annually | `usp_MergePartition` |
| Monitor partition sizes | Weekly | `vw_PartitionInfo` |

## Archiving Strategy

```
Active Data (Current + 2 years)     → Partitioned fact tables
Historical Data (3+ years)          → Archive tables (same schema)
Very Old Data (7+ years)            → Compressed backup / cold storage
```

## Execution

```sql
-- Apply partitioning
:16-partitioning/01-table-partitioning.sql

-- Note: Existing tables must be recreated with partition scheme
-- Apply during a maintenance window
```

## Performance Benefits

| Without Partitioning | With Partitioning |
|---------------------|-------------------|
| Full table scan for date ranges | Partition elimination (only scan relevant months) |
| Slow archive operations | Instant partition switch (no data movement) |
| Large indexes to maintain | Smaller per-partition indexes |
| Long backup/restore | Partition-level backup possible |

## Notes

- Partitioning requires SQL Server Enterprise Edition (or Standard with limited support)
- The partition key must be included in the primary key / clustered index
- Apply partitioning during a maintenance window (table recreation required)
- The `PF_Monthly` function covers 2023-2026; extend as needed
- All partition management procedures include error handling for existing partitions
