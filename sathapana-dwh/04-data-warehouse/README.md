# 04 - Enterprise Data Warehouse

## Overview

This directory contains the **Layer 2** setup — the core Enterprise Data Warehouse with a dimensional model (Star Schema) following Kimball methodology.

## Files

| File | Purpose |
|------|---------|
| `01-create-dwh-database.sql` | Creates `sathapana_dwh` database with dimensions, facts, and audit schema |

## Data Warehouse: `sathapana_dwh`

### Schemas

| Schema | Purpose |
|--------|---------|
| `dw` | Conformed dimensions and fact tables |
| `audit` | ETL logging, monitoring, metadata |

## Conformed Dimensions

| Dimension | Grain | SCD Type | Key Attributes |
|-----------|-------|----------|----------------|
| `dim_date` | One row per date | Type 1 | DateKey, FullDate, Day, Month, Quarter, Year, FiscalYear, IsBusinessDay |
| `dim_branch` | One row per branch | Type 1 | BranchKey, BranchCode, BranchName, Region, Province, District, Type |
| `dim_customer` | One row per customer version | **Type 2** | CustomerKey, CustomerID, Name, Type, Segment, Status, KYC_date |
| `dim_account` | One row per account version | **Type 2** | AccountKey, AccountID, CustomerKey, ProductKey, BranchKey, Type, Currency |
| `dim_product` | One row per product | Type 1 | ProductKey, ProductCode, ProductName, Category, GL_Account |
| `dim_employee` | One row per employee version | **Type 2** | EmployeeKey, EmployeeID, Name, Title, BranchKey, Department |
| `dim_currency` | One row per currency | Type 1 | CurrencyKey, CurrencyCode, CurrencyName, ExchangeRate |
| `dim_channel` | One row per channel | Type 1 | ChannelKey, ChannelCode, ChannelName |
| `dim_gl_account` | One row per GL account | Type 1 | GLAccountKey, GLAccountCode, AccountName, AccountType |

## Fact Tables

| Fact Table | Grain | Measures |
|------------|-------|----------|
| `fact_transactions` | One row per transaction | Amount, Amount_USD, Fee, Tax |
| `fact_account_daily_snapshot` | One row per account per day | OpeningBalance, ClosingBalance, TotalDebits, TotalCredits |
| `fact_loan_portfolio` | One row per loan per month | OutstandingPrincipal, AccruedInterest, ProvisionAmount, DaysPastDue |
| `fact_deposit_snapshot` | One row per deposit per month | Balance, InterestEarned, AverageBalance |
| `fact_fx_transactions` | One row per FX deal | BuyAmount, SellAmount, Spread, Profit |
| `fact_gl_daily_balance` | One row per GL account per day | DebitAmount, CreditAmount, Balance |

## Dimensional Model Diagram

```
                    ┌──────────────┐
                    │  dim_date    │
                    └──────┬───────┘
                           │
┌──────────────┐    ┌──────┴───────┐    ┌──────────────┐
│  dim_branch  ├────┤ fact_        ├────┤ dim_account  │
└──────────────┘    │ transactions │    └──────┬───────┘
                    └──────┬───────┘           │
                           │            ┌──────┴───────┐
┌──────────────┐    ┌──────┴───────┐    │ dim_customer │
│ dim_product  ├────┤ fact_loan_   │    └──────────────┘
└──────────────┘    │ portfolio    │
                    └──────────────┘
```

## Surrogate Key Strategy

- All dimensions use **identity-based surrogate keys** (`*_key`)
- Business keys (`*_code`, `*_id`) are preserved for lookup
- SCD Type 2 dimensions include `valid_from`, `valid_to`, `is_current` columns

## Audit Schema Objects

| Object | Type | Purpose |
|--------|------|---------|
| `audit.etl_log` | Table | ETL execution history |
| `audit.etl_batch_log` | Table | Batch-level tracking |
| `audit.data_quality_log` | Table | Quality check results |
| `audit.vw_monitoring_dashboard` | View | Real-time monitoring |
| `audit.usp_RunDataQualityChecks` | Procedure | Automated quality checks |
| `audit.usp_PerformMaintenance` | Procedure | Stats update, index rebuild |

## Execution

```sql
-- Create data warehouse database
:04-data-warehouse/01-create-dwh-database.sql
```

## Key Design Decisions

1. **Star Schema** — Simple, denormalized dimensions for query performance
2. **SCD Type 2** on Customer, Account, Employee — Full historical tracking
3. **SCD Type 1** on Product, Branch, Currency — Latest value only
4. **Separate audit schema** — Isolates ETL metadata from business data
5. **Date dimension** pre-populated — Covers 2020-2030 range

## Notes

- The DW is the **single version of truth** for the enterprise
- All data mart views reference DW tables (no direct source access)
- Surrogate keys are generated during ETL, not in staging
- Statistics should be updated weekly via `audit.usp_PerformMaintenance`
