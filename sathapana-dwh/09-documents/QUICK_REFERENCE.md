# Sathapana Bank DWH - Quick Reference Card

## 🚀 Quick Start

### Run Complete Pipeline
```sql
-- Execute in order:
-- 1. Create databases (run each script)
-- 2. Create procedures
-- 3. Run: EXEC sathapana_dwh.dw.usp_LoadAll
```

### Check Status
```sql
-- Dashboard
SELECT * FROM sathapana_dwh.audit.vw_monitoring_dashboard;

-- Data freshness
SELECT * FROM sathapana_dwh.audit.vw_data_freshness;

-- Recent ETL jobs
SELECT TOP 10 * FROM sathapana_dwh.audit.vw_etl_job_history;
```

## 📊 Common Queries

### Customer Analytics
```sql
-- Customer 360 view
SELECT * FROM sathapana_dwh.dw.vw_customer_360;

-- Customer segmentation
SELECT * FROM sathapana_dwh.dm_customer.vw_customer_segmentation;

-- Customer profitability
SELECT * FROM sathapana_dwh.dm_customer.vw_customer_profitability;
```

### Financial Analysis
```sql
-- Branch performance
SELECT * FROM sathapana_dwh.dw.vw_branch_performance;

-- Loan portfolio summary
SELECT * FROM sathapana_dwh.dm_credit.vw_loan_portfolio_summary;

-- FX performance
SELECT * FROM sathapana_dwh.dm_treasury.vw_fx_performance;
```

### Risk & Compliance
```sql
-- Credit risk summary
SELECT * FROM sathapana_dwh.dm_credit.vw_credit_risk_summary;

-- AML alerts
SELECT * FROM sathapana_dwh.dm_compliance.vw_aml_alert_summary;

-- PEP monitoring
SELECT * FROM sathapana_dwh.dm_compliance.vw_pep_monitoring;
```

## 🔧 Maintenance Commands

### Data Quality
```sql
-- Run all quality checks
EXEC sathapana_dwh.audit.usp_RunDataQualityChecks;

-- Generate quality report
EXEC sathapana_dwh.audit.usp_GenerateQualityReport @BatchID;
```

### ETL Operations
```sql
-- Run full extraction
EXEC sathapana_staging.staging.usp_ExtractAll;

-- Run full load
EXEC sathapana_dwh.dw.usp_LoadAll;

-- Run data reconciliation
EXEC sathapana_dwh.audit.usp_ReconcileData;
```

### Maintenance
```sql
-- Perform maintenance (update stats, rebuild indexes)
EXEC sathapana_dwh.audit.usp_PerformMaintenance;

-- Track data growth
EXEC sathapana_dwh.audit.usp_TrackDataGrowth;

-- Check for alerts
EXEC sathapana_dwh.audit.usp_CheckAlerts;
```

## 📈 Performance Reports

```sql
-- ETL performance report (last 7 days)
EXEC sathapana_dwh.audit.usp_ETLPerformanceReport 7;

-- Table sizes
SELECT * FROM sathapana_dwh.audit.vw_table_sizes;

-- Error log
SELECT * FROM sathapana_staging.staging.error_log 
ORDER BY error_date DESC;
```

## 🎯 Key Metrics

### Data Volume
```sql
-- Current counts
SELECT 
    (SELECT COUNT(*) FROM dw.dim_customer WHERE is_current = 1) AS Customers,
    (SELECT COUNT(*) FROM dw.dim_account WHERE is_current = 1) AS Accounts,
    (SELECT COUNT(*) FROM dw.fact_transactions) AS Transactions,
    (SELECT COUNT(*) FROM dw.fact_loan_portfolio) AS Loans;
```

### Daily Summary
```sql
-- Today's transactions
SELECT 
    COUNT(*) AS TransactionCount,
    SUM(amount) AS TotalVolume,
    AVG(amount) AS AvgAmount
FROM dw.fact_transactions
WHERE transaction_date_key = CAST(FORMAT(GETDATE(), 'yyyyMMdd') AS INT);
```

## 🚨 Troubleshooting

### ETL Failures
```sql
-- Find failed jobs
SELECT * FROM audit.etl_log 
WHERE status = 'FAILED' 
AND start_time > DATEADD(DAY, -1, GETDATE());

-- Error details
SELECT * FROM sathapana_staging.staging.error_log 
WHERE is_resolved = 0;
```

### Data Issues
```sql
-- Check data quality failures
SELECT * FROM audit.data_quality 
WHERE status = 'FAIL'
AND check_date > DATEADD(DAY, -1, GETDATE());

-- Reconcile data
EXEC audit.usp_ReconcileData;
```

## 📁 File Locations

| Script | Purpose |
|--------|---------|
| `02-source-systems/` | Source database creation |
| `03-staging/` | Staging database creation |
| `04-data-warehouse/` | DWH database creation |
| `05-data-marts/` | Data mart views |
| `06-etl/` | ETL procedures |
| `07-data-quality/` | Quality framework |
| `08-monitoring/` | Monitoring views |
| `10-samples/` | Run scripts |

## 🔐 Access Levels

| Role | Access |
|------|--------|
| DWH_Admin | Full control |
| ETL_Service | Read/Write ETL |
| BI_Analyst | Read only |
| Compliance | Read + Export |
| Auditor | Read + Audit logs |

## 📞 Support

- **Documentation**: `09-documents/README.md`
- **Architecture**: `01-architecture/ARCHITECTURE.md`
- **Logs**: `audit.etl_log`
- **Quality**: `audit.data_quality`

---
*Last Updated: 2024-01-15*
