# 03 - Staging Area

## Overview

This directory contains the **Staging Database** setup — the intermediate layer between the Raw Zone (Layer 1) and the Enterprise Data Warehouse (Layer 2).

## Files

| File | Purpose |
|------|---------|
| `01-create-staging-database.sql` | Creates `sathapana_staging` database with staging tables and ETL control objects |

## Staging Database: `sathapana_staging`

**Schema**: `staging`

### Purpose

The staging area serves as a **landing zone** where data is:
1. **Cleansed** — Remove invalid records, fix data types
2. **Conformed** — Standardize formats (dates, currencies, codes)
3. **Validated** — Apply business rules before loading to DW
4. **Deduplicated** — Remove duplicate records from source extracts

### Staging Tables

| Table | Source | Purpose |
|-------|--------|---------|
| `stg_branches` | oltp.branches | Branch data staging |
| `stg_employees` | oltp.employees | Employee data staging |
| `stg_customers` | oltp.customers | Customer data staging |
| `stg_products` | oltp.products | Product data staging |
| `stg_accounts` | oltp.accounts | Account data staging |
| `stg_transactions` | oltp.transactions | Transaction data staging |
| `stg_loans` | oltp.loans | Loan data staging |
| `stg_exchange_rates` | oltp.exchange_rates | Exchange rate staging |
| `stg_aml_alerts` | oltp.aml_alerts | AML alert staging |

### ETL Control Tables

| Table | Purpose |
|-------|---------|
| `etl_batch_log` | Tracks ETL batch execution |
| `etl_error_log` | Captures transformation errors |
| `etl_source_counts` | Row counts for reconciliation |

### Key Stored Procedures

| Procedure | Purpose |
|-----------|---------|
| `staging.usp_ExtractAll` | Extract all source tables to staging |
| `staging.usp_ValidateStaging` | Run validation rules on staged data |
| `staging.usp_CleanseData` | Apply data cleansing rules |

## Data Flow

```
sathapana_source.oltp.*  ──►  sathapana_staging.staging.stg_*  ──►  sathapana_dwh.dw.*
     (Layer 0)                      (Staging)                          (Layer 2)
```

## Staging vs Raw Zone

| Aspect | Raw Zone (`sathapana_raw`) | Staging (`sathapana_staging`) |
|--------|---------------------------|-------------------------------|
| Transformations | None | Cleansing, validation |
| Data Types | Matches source | Standardized |
| History | Full copy | Truncated per batch |
| Purpose | Audit trail | ETL processing |
| Retention | 90 days | Truncated after load |

## Validation Rules Applied

1. **Not Null** — Required fields must be populated
2. **Referential Integrity** — Foreign keys must match
3. **Range Checks** — Amounts within reasonable bounds
4. **Date Validation** — Dates must be valid and within range
5. **Duplicate Detection** — No duplicate business keys
6. **Format Standardization** — Phone numbers, IDs normalized

## Execution

```sql
-- Create staging database
:03-staging/01-create-staging-database.sql

-- Extraction is triggered by ETL pipeline
EXEC sathapana_staging.staging.usp_ExtractAll;
```

## Notes

- Staging tables are **truncated** before each batch load
- Failed records are logged to `etl_error_log` for investigation
- The staging layer is ephemeral — it holds data only during ETL processing
- Row counts are captured for source-to-target reconciliation
