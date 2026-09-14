# Data Lineage — Sathapana Bank DWH

## Overview

This document provides end-to-end data lineage for the Sathapana Bank Data Warehouse — tracing how data flows from source systems through each layer to the final reporting views.

---

## Lineage Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 0: SOURCE SYSTEMS                          │
│  sathapana_source.oltp.*                                            │
│  (15 tables — exact business data)                                  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  EXTRACT (no transformation)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 1: RAW ZONE                                │
│  sathapana_raw.raw.*                                                │
│  (15 tables — exact copy of source)                                 │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  STAGE (cleansing, validation)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    STAGING AREA                                      │
│  sathapana_staging.staging.stg_*                                    │
│  (staging tables — cleansed, conformed)                             │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  TRANSFORM (SCD, surrogate keys)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 2: CURATED ZONE                            │
│  sathapana_dwh.dw.dim_* / dw.fact_*                                 │
│  (8 dimensions + 6 facts — single version of truth)                 │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  SERVE (business views)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 3: SERVING ZONE                            │
│  sathapana_dm_*.dm.vw_*                                             │
│  (6 data marts — department-specific views)                         │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  PRESENT
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 4: PRESENTATION                            │
│  Power BI, Excel, SSRS, Custom Apps                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Table-Level Lineage

### Dimension Tables

| Target Table | Source Layer | Source Table(s) | SCD | Transformation |
|-------------|--------------|-----------------|-----|----------------|
| `dw.dim_date` | Static | — | — | Pre-populated (2020-2030) |
| `dw.dim_branch` | Staging | `stg_branches` | Type 1 | Surrogate key generation |
| `dw.dim_customer` | Staging | `stg_customers` | **Type 2** | Surrogate key + history tracking |
| `dw.dim_account` | Staging | `stg_accounts` | **Type 2** | Surrogate key + history tracking |
| `dw.dim_product` | Staging | `stg_products` | Type 1 | Surrogate key generation |
| `dw.dim_employee` | Staging | `stg_employees` | **Type 2** | Surrogate key + history tracking |
| `dw.dim_currency` | Staging | `stg_exchange_rates` | Type 1 | Distinct currency extraction |
| `dw.dim_channel` | Static | — | — | Pre-populated reference |
| `dw.dim_gl_account` | Staging | `stg_gl_entries` | Type 1 | Distinct GL account extraction |

### Fact Tables

| Target Table | Source Layer | Source Table(s) | Grain | Transformation |
|-------------|--------------|-----------------|-------|----------------|
| `dw.fact_transactions` | Staging | `stg_transactions` | Per transaction | FK resolution, currency conversion |
| `dw.fact_account_daily_snapshot` | Staging | `stg_accounts` + `stg_transactions` | Per account per day | Daily balance calculation |
| `dw.fact_loan_portfolio` | Staging | `stg_loans` | Per loan per month | Monthly snapshot, provision calc |
| `dw.fact_deposit_snapshot` | Staging | `stg_deposits` | Per deposit per month | Monthly balance snapshot |
| `dw.fact_fx_transactions` | Staging | `stg_fx_transactions` | Per FX deal | Spread/profit calculation |
| `dw.fact_gl_daily_balance` | Staging | `stg_gl_entries` | Per GL per day | Daily aggregation |

---

## Column-Level Lineage: Key Fields

### Customer Dimension (`dw.dim_customer`)

| Target Column | Source Table | Source Column | Transformation |
|--------------|-------------|---------------|----------------|
| `customer_key` | — | — | IDENTITY surrogate key |
| `customer_code` | `oltp.customers` | `customer_code` | Direct copy |
| `customer_id` | `oltp.customers` | `customer_id` | Business key preserved |
| `full_name` | `oltp.customers` | `first_name` + `last_name` | CONCAT(first_name, ' ', last_name) |
| `customer_type` | `oltp.customers` | `customer_type` | Direct copy |
| `customer_segment` | `oltp.customers` | `customer_segment` | Direct copy |
| `risk_rating` | `oltp.customers` | `risk_rating` | Direct copy |
| `kyc_status` | `oltp.customers` | `kyc_status` | Direct copy |
| `kyc_verified_date` | `oltp.customers` | `kyc_verified_date` | Direct copy |
| `opening_branch_key` | `oltp.customers` | `opening_branch_id` | FK → `dim_branch.branch_key` |
| `age` | `oltp.customers` | `date_of_birth` | DATEDIFF(YEAR, dob, GETDATE()) |
| `valid_from` | — | — | ETL timestamp |
| `valid_to` | — | — | NULL (current) or ETL timestamp |
| `is_current` | — | — | 1 = current version |

### Transaction Fact (`dw.fact_transactions`)

| Target Column | Source Table | Source Column | Transformation |
|--------------|-------------|---------------|----------------|
| `transaction_key` | — | — | IDENTITY surrogate key |
| `transaction_code` | `oltp.transactions` | `transaction_code` | Direct copy |
| `account_key` | `oltp.transactions` | `account_id` | FK → `dim_account.account_key` |
| `customer_key` | `oltp.transactions` | `account_id` → `customer_id` | FK via `dim_account` → `dim_customer` |
| `product_key` | `oltp.transactions` | `account_id` → `product_id` | FK via `dim_account` → `dim_product` |
| `branch_key` | `oltp.transactions` | `branch_id` | FK → `dim_branch.branch_key` |
| `channel_key` | `oltp.transactions` | `transaction_channel` | FK → `dim_channel.channel_key` |
| `transaction_date_key` | `oltp.transactions` | `transaction_date` | FK → `dim_date.date_key` (yyyyMMdd) |
| `amount` | `oltp.transactions` | `amount` | Direct copy |
| `amount_usd` | `oltp.transactions` | `amount` + `exchange_rate` | amount × exchange_rate |
| `currency` | `oltp.transactions` | `currency` | Direct copy |
| `fee_amount` | `oltp.transactions` | `fee_amount` | Direct copy |
| `tax_amount` | `oltp.transactions` | `tax_amount` | Direct copy |
| `etl_load_date` | — | — | GETDATE() at load time |

### Loan Portfolio Fact (`dw.fact_loan_portfolio`)

| Target Column | Source Table | Source Column | Transformation |
|--------------|-------------|---------------|----------------|
| `loan_key` | — | — | IDENTITY surrogate key |
| `loan_number` | `oltp.loans` | `loan_number` | Direct copy |
| `customer_key` | `oltp.loans` | `customer_id` | FK → `dim_customer.customer_key` |
| `product_key` | `oltp.loans` | `product_id` | FK → `dim_product.product_key` |
| `branch_key` | `oltp.loans` | `branch_id` | FK → `dim_branch.branch_key` |
| `snapshot_date_key` | — | — | Monthly snapshot date (yyyyMMdd) |
| `outstanding_principal` | `oltp.loans` | `outstanding_principal` | Direct copy |
| `accrued_interest` | `oltp.loans` | `interest_rate` × `outstanding_principal` | Calculated |
| `provision_amount` | `oltp.loans` | `provision_amount` | Direct copy |
| `days_past_due` | `oltp.loans` | `days_past_due` | Direct copy |
| `risk_classification` | `oltp.loans` | `risk_classification` | Direct copy |
| `npl_flag` | `oltp.loans` | `days_past_due` | CASE WHEN > 90 THEN 1 ELSE 0 END |

---

## Transformation Rules by Layer

### Layer 0 → Layer 1 (Extract)

| Rule | Description |
|------|-------------|
| **No transformation** | Exact column-for-column copy |
| **Truncate + Reload** | Raw tables truncated before each extract |
| **Row count capture** | Source vs raw counts logged for reconciliation |

### Layer 1 → Staging (Stage)

| Rule | Description |
|------|-------------|
| **Data type normalization** | VARCHAR lengths standardized |
| **NULL handling** | Empty strings → NULL where appropriate |
| **Date validation** | Invalid dates flagged and logged |
| **Duplicate detection** | Business key uniqueness enforced |
| **Referential check** | FK values validated against source |

### Staging → Layer 2 (Transform)

| Rule | Description |
|------|-------------|
| **Surrogate key generation** | IDENTITY keys for all dimensions |
| **SCD Type 1** | Product, Branch, Currency — overwrite |
| **SCD Type 2** | Customer, Account, Employee — historical |
| **FK resolution** | Business keys → surrogate keys |
| **Date key generation** | datetime → yyyyMMdd integer key |
| **Currency conversion** | Local amount × exchange rate → USD |
| **Business rules** | NPL flag, age calculation, segment mapping |

### Layer 2 → Layer 3 (Serve)

| Rule | Description |
|------|-------------|
| **View-based** | No physical data movement |
| **Pre-aggregation** | Common metrics computed in views |
| **Business naming** | Technical columns → business-friendly names |
| **Security filtering** | Row-level security applied per mart |

---

## Cross-Database Reference Map

```
sathapana_source.oltp.branches
    └──► sathapana_raw.raw.branches
            └──► sathapana_staging.staging.stg_branches
                    └──► sathapana_dwh.dw.dim_branch

sathapana_source.oltp.customers
    └──► sathapana_raw.raw.customers
            └──► sathapana_staging.staging.stg_customers
                    └──► sathapana_dwh.dw.dim_customer

sathapana_source.oltp.accounts
    └──► sathapana_raw.raw.accounts
            └──► sathapana_staging.staging.stg_accounts
                    └──► sathapana_dwh.dw.dim_account
                            └──► sathapana_dwh.dw.fact_transactions
                                    └──► sathapana_dm_customer.dm.vw_customer_360
                                    └──► sathapana_dm_credit.dm.vw_credit_risk_summary

sathapana_source.oltp.transactions
    └──► sathapana_raw.raw.transactions
            └──► sathapana_staging.staging.stg_transactions
                    └──► sathapana_dwh.dw.fact_transactions
                            └──► sathapana_dm_compliance.dm.vw_aml_alert_summary
                            └──► sathapana_dm_treasury.dm.vw_fx_performance

sathapana_source.oltp.loans
    └──► sathapana_raw.raw.loans
            └──► sathapana_staging.staging.stg_loans
                    └──► sathapana_dwh.dw.fact_loan_portfolio
                            └──► sathapana_dm_credit.dm.vw_credit_risk_summary
                            └──► sathapana_dm_credit.dm.vw_npl_trend
```

---

## Data Freshness by Layer

| Layer | Expected Latency | Max Acceptable | Check Method |
|-------|-----------------|----------------|--------------|
| Layer 0 (Source) | Real-time | — | Source system availability |
| Layer 1 (Raw) | +5 min after source | +30 min | `audit.vw_data_freshness` |
| Staging | +10 min after raw | +45 min | `staging.etl_batch_log` |
| Layer 2 (DW) | +30 min after staging | +2 hours | `audit.vw_data_freshness` |
| Layer 3 (Marts) | +5 min after DW | +30 min | View refresh (instant — views) |

---

## Audit & Lineage Queries

### Trace a Record Back to Source

```sql
-- Find the source of a fact record
SELECT
    f.transaction_code,
    f.amount,
    c.customer_code AS source_customer,
    b.branch_code AS source_branch,
    a.account_number AS source_account,
    d.full_date AS transaction_date
FROM dw.fact_transactions f
JOIN dw.dim_customer c ON f.customer_key = c.customer_key AND c.is_current = 1
JOIN dw.dim_branch b ON f.branch_key = b.branch_key
JOIN dw.dim_account a ON f.account_key = a.account_key AND a.is_current = 1
JOIN dw.dim_date d ON f.transaction_date_key = d.date_key
WHERE f.transaction_code = 'TXN000001';
```

### Check Row Count Reconciliation

```sql
-- Source vs Raw vs Staging vs DW counts
SELECT 'Source' AS layer, COUNT(*) AS row_count FROM sathapana_source.oltp.transactions
UNION ALL
SELECT 'Raw', COUNT(*) FROM sathapana_raw.raw.transactions
UNION ALL
SELECT 'Staging', COUNT(*) FROM sathapana_staging.staging.stg_transactions
UNION ALL
SELECT 'DW', COUNT(*) FROM sathapana_dwh.dw.fact_transactions;
```

### View ETL Lineage Log

```sql
-- Full lineage for a batch
SELECT
    batch_id,
    step_name,
    table_name,
    operation,
    status,
    records_affected,
    start_time,
    end_time,
    DATEDIFF(SECOND, start_time, end_time) AS duration_seconds
FROM audit.etl_log
WHERE batch_id = 'your-batch-id'
ORDER BY start_time;
```

---

## Lineage for Regulatory Reports

| NBC Report | Data Mart View | DW Tables | Source Tables |
|------------|---------------|-----------|---------------|
| Capital Adequacy | `dm.vw_capital_adequacy` | `fact_loan_portfolio`, `dim_branch` | `oltp.loans`, `oltp.accounts` |
| Loan Classification | `dm.vw_loan_classification` | `fact_loan_portfolio`, `dim_branch` | `oltp.loans` |
| Deposit Report | `dm.vw_deposit_report` | `fact_deposit_snapshot`, `dim_product` | `oltp.deposits`, `oltp.accounts` |
| Liquidity Report | `dm.vw_liquidity_report` | `fact_deposit_snapshot`, `fact_loan_portfolio` | `oltp.accounts`, `oltp.loans` |
| Large Exposure | `dm.vw_large_exposure` | `fact_loan_portfolio`, `dim_customer` | `oltp.loans`, `oltp.customers` |
| AML/CFT Report | `dm.vw_aml_cft_report` | `fact_transactions`, `dim_date` | `oltp.transactions`, `oltp.aml_alerts` |

---

## Notes

- All lineage is **table and column level** — no implicit transformations
- Surrogate keys are generated via IDENTITY — not derived from source data
- SCD Type 2 history is maintained via `valid_from`, `valid_to`, `is_current`
- The Raw Zone preserves the **exact source state** for audit and recovery
- Data marts are **views only** — no physical data duplication
- Row counts are captured at each layer for reconciliation
- ETL batch IDs enable end-to-end traceability
