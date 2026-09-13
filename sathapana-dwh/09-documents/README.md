# Sathapana Bank Data Warehouse

## Overview

This is a complete Data Warehouse solution for Sathapana Bank, designed to support enterprise-wide analytics, regulatory reporting, and business intelligence needs.

## Project Structure

```
sathapana-dwh/
├── 01-architecture/          # Architecture documentation
│   └── ARCHITECTURE.md       # Complete architecture document
├── 02-source-systems/        # Source database (OLTP simulation)
│   └── 01-create-source-database.sql
├── 03-staging/               # Staging database
│   └── 01-create-staging-database.sql
├── 04-data-warehouse/        # Enterprise data warehouse
│   └── 01-create-dwh-database.sql
├── 05-data-marts/            # Specialized data marts
│   └── 01-create-data-marts.sql
├── 06-etl/                   # ETL procedures
│   ├── 01-extract-procedures.sql
│   └── 02-transform-load-procedures.sql
├── 07-data-quality/          # Data quality framework
│   └── 01-data-quality-framework.sql
├── 08-monitoring/            # Monitoring & logging
│   └── 01-monitoring-framework.sql
├── 09-documents/             # Documentation
│   └── README.md
├── 10-samples/               # Sample scripts
│   └── 01-run-full-pipeline.sql
└── 11-tests/                 # Test scripts (future)
```

## Database Architecture

### 1. Source Database (`sathapana_source`)
- **Purpose**: Simulates the core banking OLTP system
- **Schema**: `oltp`
- **Tables**: Branches, Employees, Customers, Products, Accounts, Transactions, Loans, Cards, FX Transactions, AML Alerts

### 2. Staging Database (`sathapana_staging`)
- **Purpose**: Data cleansing and transformation area
- **Schema**: `staging`
- **Tables**: Staging tables for all source entities, ETL control, error logging, batch tracking

### 3. Data Warehouse (`sathapana_dwh`)
- **Purpose**: Enterprise data warehouse with dimensional model
- **Schema**: `dw` (dimensions and facts), `audit` (monitoring)
- **Dimensions**: DimDate, DimBranch, DimCustomer, DimProduct, DimAccount, DimEmployee, DimCurrency, DimGLAccount, DimChannel
- **Facts**: FactTransactions, FactAccountDailySnapshot, FactGLDailyBalance, FactLoanPortfolio, FactDepositSnapshot, FactFXTransactions, FactCardTransactions

### 4. Data Marts
- **Credit Risk** (`dm_credit`): Loan portfolio analysis, risk classification, provisioning
- **Customer Analytics** (`dm_customer`): Customer segmentation, profitability, lifecycle
- **Treasury** (`dm_treasury`): FX performance, deposit mobilization, interest rate sensitivity
- **Compliance** (`dm_compliance`): AML alerts, transaction monitoring, PEP monitoring

## ETL Pipeline

### Extraction (Daily 02:00 AM)
1. Extract data from source systems
2. Load into staging tables
3. Log extraction metadata

### Transformation (Daily 03:00 AM)
1. Data cleansing and validation
2. Business rule application
3. Surrogate key generation
4. SCD processing (Type 1 & 2)

### Loading (Daily 04:00 AM)
1. Load dimension tables
2. Load fact tables
3. Update aggregates
4. Log load metadata

### Post-Load (Daily 05:00 AM)
1. Data quality checks
2. Data reconciliation
3. Monitoring alerts
4. Report distribution

## Data Quality Framework

### Quality Dimensions
- **Completeness**: All required data present
- **Accuracy**: Data matches real-world
- **Consistency**: Data agrees across systems
- **Timeliness**: Data available when needed
- **Uniqueness**: No unintended duplicates
- **Validity**: Data conforms to rules

### Automated Checks
- Referential integrity validation
- Balance equation verification
- Date validity checks
- Currency validation
- Duplicate detection
- Freshness monitoring

## Monitoring & Alerting

### Dashboards
- ETL job status and history
- Data quality metrics
- Data freshness indicators
- Table size monitoring
- Performance metrics

### Alerts
- Failed ETL jobs
- Data quality failures
- Stale data warnings
- Performance degradation

## Implementation Guide

### Prerequisites
1. SQL Server 2019 or later
2. Sufficient disk space (1GB minimum)
3. Sysadmin or dbcreator permissions

### Step-by-Step Installation

#### Step 1: Create Source Database
```sql
-- Execute: 02-source-systems/01-create-source-database.sql
```

#### Step 2: Create Staging Database
```sql
-- Execute: 03-staging/01-create-staging-database.sql
```

#### Step 3: Create Data Warehouse
```sql
-- Execute: 04-data-warehouse/01-create-dwh-database.sql
```

#### Step 4: Create Data Marts
```sql
-- Execute: 05-data-marts/01-create-data-marts.sql
```

#### Step 5: Create ETL Procedures
```sql
-- Execute: 06-etl/01-extract-procedures.sql
-- Execute: 06-etl/02-transform-load-procedures.sql
```

#### Step 6: Create Data Quality Framework
```sql
-- Execute: 07-data-quality/01-data-quality-framework.sql
```

#### Step 7: Create Monitoring Framework
```sql
-- Execute: 08-monitoring/01-monitoring-framework.sql
```

#### Step 8: Run Full Pipeline
```sql
-- Execute: 10-samples/01-run-full-pipeline.sql
```

## Sample Queries

### Customer 360 View
```sql
SELECT * FROM sathapana_dwh.dw.vw_customer_360;
```

### Branch Performance
```sql
SELECT * FROM sathapana_dwh.dw.vw_branch_performance;
```

### Credit Risk Summary
```sql
SELECT * FROM sathapana_dwh.dm_credit.vw_credit_risk_summary;
```

### Loan Portfolio by Branch
```sql
SELECT 
    branch_code,
    branch_name,
    COUNT(*) AS loan_count,
    SUM(outstanding_principal) AS total_outstanding,
    SUM(provision_amount) AS total_provisions
FROM sathapana_dwh.dm_credit.vw_credit_risk_summary
GROUP BY branch_code, branch_name;
```

### Customer Segmentation
```sql
SELECT 
    customer_segment,
    COUNT(*) AS customer_count,
    AVG(annual_income) AS avg_income
FROM sathapana_dwh.dm_customer.vw_customer_segmentation
GROUP BY customer_segment;
```

### FX Performance
```sql
SELECT 
    branch_code,
    source_currency,
    target_currency,
    SUM(total_fx_transactions) AS transaction_count,
    SUM(total_profit) AS total_profit
FROM sathapana_dwh.dm_treasury.vw_fx_performance
GROUP BY branch_code, source_currency, target_currency;
```

## Data Model

### Conformed Dimensions
- **DimDate**: Calendar and fiscal year dimensions
- **DimBranch**: Organizational hierarchy
- **DimCustomer**: Customer profile with SCD Type 2
- **DimProduct**: Product catalog
- **DimAccount**: Account details with SCD Type 2
- **DimEmployee**: Employee information with SCD Type 2
- **DimCurrency**: Currency reference
- **DimGLAccount**: Chart of accounts
- **DimChannel**: Transaction channels

### Fact Tables
- **FactTransactions**: Transaction grain (one row per transaction)
- **FactAccountDailySnapshot**: Daily balance snapshots
- **FactLoanPortfolio**: Monthly loan portfolio snapshots
- **FactDepositSnapshot**: Monthly deposit balance snapshots
- **FactFXTransactions**: Foreign exchange transactions
- **FactCardTransactions**: Card transaction facts

## SCD Strategy

### SCD Type 1 (Overwrite)
- DimProduct: Product name, category changes
- DimBranch: Branch name, contact changes

### SCD Type 2 (Historical)
- DimCustomer: Name, address, segment, status changes
- DimAccount: Status, product, branch changes
- DimEmployee: Title, department, branch changes

## Security

### Role-Based Access
- **DWH_Admin**: Full control
- **ETL_Service**: Read/Write (ETL schemas)
- **BI_Analyst**: Read only
- **Data_Steward**: Read/Write
- **Compliance**: Read + Export
- **Auditor**: Read only + Audit logs

### Data Classification
- **Public**: Branch names, product names
- **Internal**: Transaction amounts, balances
- **Confidential**: Customer PII, account details
- **Restricted**: AML alerts, suspicious transactions

## Backup Strategy

| Component | Method | Frequency | Retention |
|-----------|--------|-----------|-----------|
| Full Database | Full backup | Daily | 30 days |
| Transaction Log | Log backup | Every 15 min | 7 days |
| ETL Scripts | Git repository | Every commit | Permanent |
| Metadata | Separate backup | Daily | 90 days |

## Performance Tuning

### Indexing Strategy
- Fact tables: Composite indexes on date and dimension keys
- Dimension tables: Unique indexes on business keys
- SCD tables: Filtered indexes on is_current flag

### Partitioning
- Fact tables: Consider date-based partitioning for large volumes
- Staging tables: Truncate after successful load

### Statistics
- Regular statistics updates via maintenance procedures
- Index rebuild when fragmentation > 30%

## Troubleshooting

### Common Issues

1. **ETL Job Fails**
   - Check error log: `SELECT * FROM audit.etl_log WHERE status = 'FAILED'`
   - Verify source data availability
   - Check disk space

2. **Data Quality Failures**
   - Review quality report: `EXEC audit.usp_GenerateQualityReport @BatchID`
   - Check referential integrity
   - Validate business rules

3. **Performance Issues**
   - Run maintenance: `EXEC audit.usp_PerformMaintenance`
   - Check table sizes: `SELECT * FROM audit.vw_table_sizes`
   - Review index fragmentation

### Logs and Monitoring
```sql
-- View ETL history
SELECT * FROM audit.vw_etl_job_history ORDER BY start_time DESC;

-- Check data freshness
SELECT * FROM audit.vw_data_freshness;

-- Monitor dashboard
SELECT * FROM audit.vw_monitoring_dashboard;
```

## Future Enhancements

1. **Real-time ETL**: Implement Change Data Capture (CDC)
2. **Cloud Migration**: Move to Azure SQL Database or AWS Redshift
3. **Advanced Analytics**: Machine learning integration
4. **Self-Service BI**: Power BI integration with row-level security
5. **Data Catalog**: Implement data lineage and metadata management
6. **Automation**: SQL Server Agent jobs for scheduling

## Support

For issues or questions:
- Check documentation in `09-documents/`
- Review error logs in `audit.etl_log`
- Contact DWH Development Team

## License

Internal use only - Sathapana Bank
