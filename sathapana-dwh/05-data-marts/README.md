# 05 - Data Marts (Serving Zone)

## Overview

This directory contains **Layer 3** — department-specific data marts that provide simplified, business-focused views of the enterprise data warehouse.

## Files

| File | Purpose |
|------|---------|
| `01-create-data-marts.sql` | Master script to create all data mart databases |

### Subdirectories

| Directory | Mart | Database |
|-----------|------|----------|
| `credit/` | Credit Risk Mart | `sathapana_dm_credit` |
| `customer/` | Customer Analytics Mart | `sathapana_dm_customer` |
| `treasury/` | Treasury Mart | `sathapana_dm_treasury` |
| `compliance/` | Compliance/AML Mart | `sathapana_dm_compliance` |

## Data Mart Architecture

```
sathapana_dwh (dw schema)
       │
       ├──► sathapana_dm_credit (dm schema)
       │       Views on: fact_loan_portfolio, dim_customer, dim_branch
       │
       ├──► sathapana_dm_customer (dm schema)
       │       Views on: dim_customer, fact_transactions, fact_account_daily_snapshot
       │
       ├──► sathapana_dm_treasury (dm schema)
       │       Views on: fact_fx_transactions, fact_deposit_snapshot, dim_currency
       │
       └──► sathapana_dm_compliance (dm schema)
               Views on: fact_transactions, dim_customer, audit tables
```

## Mart Descriptions

### Credit Risk Mart (`sathapana_dm_credit`)

**Audience**: Credit Risk Team, Risk Managers, Auditors

| View | Description |
|------|-------------|
| `vw_credit_risk_summary` | Loan portfolio by branch with risk classification |
| `vw_npl_analysis` | Non-performing loan analysis by classification |
| `vw_provision_analysis` | Provision coverage by risk category |
| `vw_concentration_risk` | Exposure concentration by customer/branch/product |

**Key Metrics**:
- NPL Ratio (Non-Performing Loans / Total Portfolio)
- Provision Coverage Ratio
- Risk-Weighted Assets
- Days Past Due distribution

### Customer Analytics Mart (`sathapana_dm_customer`)

**Audience**: Marketing Team, BI Analysts, Branch Managers

| View | Description |
|------|-------------|
| `vw_customer_360` | Complete customer profile with all products |
| `vw_customer_segmentation` | Customer segments with behavioral metrics |
| `vw_customer_profitability` | Revenue and cost by customer |
| `vw_customer_lifetime` | Account age, transaction frequency, trends |

**Key Metrics**:
- Customer Lifetime Value (CLV)
- Cross-sell ratio
- Transaction frequency
- Account balances by type

### Treasury Mart (`sathapana_dm_treasury`)

**Audience**: Treasury Team, ALM, Finance

| View | Description |
|------|-------------|
| `vw_fx_performance` | FX trading volume and profit by branch/currency |
| `vw_deposit_mobilization` | Deposit growth and composition |
| `vw_interest_rate_sensitivity` | Fixed vs variable rate analysis |
| `vw_liquidity_position` | Liquidity ratios and cash position |

**Key Metrics**:
- FX Spread and Profit
- Deposit Mobilization Rate
- Loan-to-Deposit Ratio (LDR)
- Weighted Average Interest Rate

### Compliance Mart (`sathapana_dm_compliance`)

**Audience**: AML Officers, Compliance Team, Auditors

| View | Description |
|------|-------------|
| `vw_aml_dashboard` | Alert summary and resolution metrics |
| `vw_transaction_monitoring` | Suspicious transaction patterns |
| `vw_kyc_status` | KYC compliance by customer |
| `vw_pep_monitoring` | Politically Exposed Person transactions |

**Key Metrics**:
- Alert-to-SAR conversion rate
- Average resolution time
- High-value transaction count
- KYC expiry tracking

## Design Principles

1. **Views, not tables** — Marts are logical layers over the DW, not physical copies
2. **Business-friendly names** — Columns use business terminology, not technical keys
3. **Pre-calculated metrics** — Common aggregations built into views
4. **Security boundaries** — Each mart has its own database for access control
5. **Independent scaling** — Marts can be moved to separate servers if needed

## Access Control

| Mart | Owner | Typical Users |
|------|-------|---------------|
| `sathapana_dm_credit` | Credit Risk Team | Credit Analysts, Risk Managers |
| `sathapana_dm_customer` | Marketing Team | BI Analysts, Marketing |
| `sathapana_dm_treasury` | Treasury Team | Treasury Analysts, ALM |
| `sathapana_dm_compliance` | Compliance Team | AML Officers, Auditors |

## Execution

```sql
-- Create all data marts
:05-data-marts/01-create-data-marts.sql

-- Or create individually
:05-data-marts/credit/01-create-credit-mart-database.sql
:05-data-marts/customer/01-create-customer-mart-database.sql
:05-data-marts/treasury/01-create-treasury-mart-database.sql
:05-data-marts/compliance/01-create-compliance-mart-database.sql
```

## Notes

- All mart views reference `sathapana_dwh.dw.*` tables — never source directly
- Mart databases are created on the same SQL Server instance as the DW
- Row-level security can be applied per-mart for branch-based filtering
- Marts are refreshed automatically when the DW ETL pipeline completes
