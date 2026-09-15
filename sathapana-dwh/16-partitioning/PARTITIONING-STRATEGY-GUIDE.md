# 📦 Partitioning Strategy Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Partitioning Benefits](#2-partitioning-benefits)
3. [Partition Strategy](#3-partition-strategy)
4. [Implementation](#4-implementation)
5. [Maintenance](#5-maintenance)
6. [Monitoring](#6-monitoring)

---

## 1. Overview

Partitioning splits large tables into smaller, more manageable pieces while maintaining a single logical table.

```
┌─────────────────────────────────────────────────────────────────┐
│                    TABLE PARTITIONING CONCEPT                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Before Partitioning:                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ fact_transactions (1 billion rows)                       │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  After Partitioning (by Year):                                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐  │
│  │   2022      │ │   2023      │ │   2024      │ │  2025   │  │
│  │  (100M)     │ │  (250M)     │ │  (400M)     │ │ (250M)  │  │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Partitioning Benefits

| Benefit | Description |
|---------|-------------|
| **Query Performance** | Partition elimination - only scan relevant data |
| **Maintenance** | Rebuild/reorganize individual partitions |
| **Archival** | Easy to archive old data (switch out) |
| **Loading** | Load data into specific partitions |
| **Backup** | Backup/restore individual partitions |

---

## 3. Partition Strategy

### Recommended Partitioning by Table

| Table | Partition Key | Strategy | Rationale |
|-------|---------------|----------|-----------|
| fact_transactions | date_key | Monthly | High volume, time-based queries |
| fact_loan_portfolio | snapshot_date_key | Monthly | Snapshot history |
| fact_account_daily | snapshot_date_key | Monthly | Daily snapshots |
| fact_deposit_snapshot | snapshot_date_key | Monthly | Monthly snapshots |
| dim_customer | None | N/A | Sufficient with indexes |

### Partition Function Design

```sql
-- Monthly partition function (3 years of data)
CREATE PARTITION FUNCTION pf_Monthly (INT)
AS RANGE RIGHT FOR VALUES (
    20220101, 20220201, 20220301, 20220401, 20220501, 20220601,
    20220701, 20220801, 20220901, 20221001, 20221101, 20221201,
    20230101, 20230201, 20230301, 20230401, 20230501, 20230601,
    20230701, 20230801, 20230901, 20231001, 20231101, 20231201,
    20240101, 20240201, 20240301, 20240401, 20240501, 20240601,
    20240701, 20240801, 20240901, 20241001, 20241101, 20241201,
    20250101, 20250201, 20250301, 20250401, 20250501, 20250601,
    20250701, 20250801, 20250901, 20251001, 20251101, 20251201
);

-- Partition scheme
CREATE PARTITION SCHEME ps_Monthly
AS PARTITION pf_Monthly
ALL TO ([PRIMARY]);
```

---

## 4. Implementation

### Create Partitioned Table

```sql
-- ============================================================
-- PARTITIONED FACT TABLE
-- ============================================================

CREATE TABLE dw.fact_transactions_partitioned (
    transaction_key BIGINT IDENTITY(1,1),
    transaction_code VARCHAR(30) NOT NULL,
    account_key INT NOT NULL,
    customer_key INT NOT NULL,
    date_key INT NOT NULL,  -- Partition key
    transaction_type VARCHAR(20),
    amount DECIMAL(18,2),
    amount_usd DECIMAL(18,2),
    currency VARCHAR(3),
    created_date DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT PK_fact_transactions_partitioned PRIMARY KEY CLUSTERED 
        (date_key, transaction_key)
        ON ps_Monthly(date_key)
) ON ps_Monthly(date_key);
GO
```

### Switch Data Between Partitions

```sql
-- ============================================================
-- PARTITION SWITCHING
-- ============================================================

-- Switch old data to archive table
ALTER TABLE dw.fact_transactions_partitioned
SWITCH PARTITION 1 TO dw.fact_transactions_archive;

-- Switch new data from staging
ALTER TABLE staging.stg_transactions
SWITCH TO dw.fact_transactions_partitioned PARTITION 5;
```

---

## 5. Maintenance

### Partition Maintenance Procedure

```sql
-- ============================================================
-- PARTITION MAINTENANCE
-- ============================================================

CREATE PROCEDURE partition.usp_MaintainPartitions
AS
BEGIN
    DECLARE @NextMonth DATE = DATEADD(MONTH, 1, GETDATE());
    DECLARE @PartitionValue INT = CAST(FORMAT(@NextMonth, 'yyyyMMdd') AS INT);
    
    -- Add new partition for next month
    ALTER PARTITION FUNCTION pf_Monthly()
    SPLIT RANGE (@PartitionValue);
    
    PRINT 'Added partition for ' + CONVERT(VARCHAR(10), @NextMonth, 120);
    
    -- Archive data older than 2 years
    DECLARE @ArchiveDate INT = CAST(FORMAT(DATEADD(YEAR, -2, GETDATE()), 'yyyyMMdd') AS INT);
    
    -- Find partition number for archival
    DECLARE @PartitionNumber INT;
    SELECT @PartitionNumber = partition_number
    FROM sys.partition_range_values
    WHERE value = @ArchiveDate;
    
    IF @PartitionNumber IS NOT NULL
    BEGIN
        -- Create archive table if not exists
        IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'fact_transactions_archive')
        BEGIN
            CREATE TABLE dw.fact_transactions_archive (
                transaction_key BIGINT,
                transaction_code VARCHAR(30),
                date_key INT,
                amount DECIMAL(18,2)
            );
        END
        
        -- Switch to archive
        ALTER TABLE dw.fact_transactions_partitioned
        SWITCH PARTITION @PartitionNumber TO dw.fact_transactions_archive;
        
        PRINT 'Archived partition ' + CAST(@PartitionNumber AS VARCHAR(10));
    END
END;
GO
```

---

## 6. Monitoring

### View Partition Information

```sql
-- ============================================================
-- PARTITION MONITORING QUERIES
-- ============================================================

-- View partition row counts
SELECT 
    p.partition_number,
    p.rows,
    rv.value AS partition_value
FROM sys.partitions p
JOIN sys.partition_range_values rv 
    ON p.partition_id = rv.partition_id
WHERE p.object_id = OBJECT_ID('dw.fact_transactions_partitioned')
ORDER BY p.partition_number;

-- View partition sizes
SELECT 
    p.partition_number,
    p.rows,
    CAST(ROUND(SUM(a.total_pages) * 8 / 1024.0, 2) AS DECIMAL(10,2)) AS size_mb
FROM sys.partitions p
JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE p.object_id = OBJECT_ID('dw.fact_transactions_partitioned')
GROUP BY p.partition_number, p.rows
ORDER BY p.partition_number;
```

---

*Created: September 2024*
