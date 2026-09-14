# 06 - ETL (Extract, Transform, Load)

## Overview

This directory contains the stored procedures that power the daily ETL pipeline — moving data from source systems through staging into the enterprise data warehouse.

## Files

| File | Purpose |
|------|---------|
| `01-extract-procedures.sql` | Stored procedures for extracting data from source to raw/staging |
| `02-transform-load-procedures.sql` | Stored procedures for transforming and loading into the DW |

## ETL Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DAILY ETL PIPELINE                            │
│                    Schedule: 2:00 AM - 6:00 AM                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  STEP 1: EXTRACT (2:00 AM - 2:30 AM)                           │
│  ┌─────────────────────────────────────────────┐               │
│  │ sathapana_source ──► sathapana_raw          │               │
│  │                       sathapana_staging      │               │
│  │  • Full/incremental copy                     │               │
│  │  • Source-to-raw validation                  │               │
│  │  • Row count reconciliation                  │               │
│  └─────────────────────┬───────────────────────┘               │
│                        │                                        │
│  STEP 2: STAGE (2:30 AM - 3:00 AM)                            │
│  ┌─────────────────────┴───────────────────────┐               │
│  │ sathapana_staging                            │               │
│  │  • Data cleansing                            │               │
│  │  • Data type conversions                     │               │
│  │  • Duplicate detection                       │               │
│  │  • Business rule validation                  │               │
│  └─────────────────────┬───────────────────────┘               │
│                        │                                        │
│  STEP 3: TRANSFORM (3:00 AM - 4:00 AM)                        │
│  ┌─────────────────────┴───────────────────────┐               │
│  │ Transformation Engine                        │               │
│  │  • Surrogate key generation                  │               │
│  │  • SCD processing (Type 1 & 2)               │               │
│  │  • Business rule application                 │               │
│  │  • Currency conversion                       │               │
│  │  • Data aggregation                          │               │
│  └─────────────────────┬───────────────────────┘               │
│                        │                                        │
│  STEP 4: LOAD (4:00 AM - 5:00 AM)                             │
│  ┌─────────────────────┴───────────────────────┐               │
│  │ sathapana_dwh                                │               │
│  │  • Dimension loads (SCD)                     │               │
│  │  • Fact loads (incremental)                  │               │
│  │  • Index maintenance                         │               │
│  │  • Statistics update                         │               │
│  └─────────────────────┬───────────────────────┘               │
│                        │                                        │
│  STEP 5: SERVE (5:00 AM - 6:00 AM)                            │
│  ┌─────────────────────┴───────────────────────┐               │
│  │ Data Marts                                   │               │
│  │  • Credit Risk mart refresh                  │               │
│  │  • Customer Analytics mart refresh           │               │
│  │  • Treasury mart refresh                     │               │
│  │  • Compliance mart refresh                   │               │
│  └─────────────────────────────────────────────┘               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Key Stored Procedures

### Extract Procedures (`01-extract-procedures.sql`)

| Procedure | Purpose |
|-----------|---------|
| `staging.usp_ExtractAll` | Master extract — pulls all source tables to staging |
| `raw.usp_ExtractToRaw` | Extract source to raw zone (Layer 0 → Layer 1) |
| `staging.usp_ExtractBranches` | Extract branch data |
| `staging.usp_ExtractCustomers` | Extract customer data |
| `staging.usp_ExtractTransactions` | Extract transaction data |

### Transform & Load Procedures (`02-transform-load-procedures.sql`)

| Procedure | Purpose |
|-----------|---------|
| `dw.usp_LoadAll` | Master load — orchestrates all dimension and fact loads |
| `dw.usp_LoadDimDate` | Populate date dimension |
| `dw.usp_LoadDimBranch` | Load branch dimension (SCD Type 1) |
| `dw.usp_LoadDimCustomer` | Load customer dimension (SCD Type 2) |
| `dw.usp_LoadDimAccount` | Load account dimension (SCD Type 2) |
| `dw.usp_LoadDimProduct` | Load product dimension (SCD Type 1) |
| `dw.usp_LoadDimEmployee` | Load employee dimension (SCD Type 2) |
| `dw.usp_LoadFactTransactions` | Load transaction facts (incremental) |
| `dw.usp_LoadFactLoanPortfolio` | Load monthly loan snapshots |
| `dw.usp_LoadFactDepositSnapshot` | Load monthly deposit snapshots |
| `dw.usp_LoadFactAccountDaily` | Load daily account snapshots |

## SCD Processing

### Type 1 (Overwrite) — DimProduct, DimBranch
```sql
-- Simple UPDATE — no history retained
UPDATE dim_product
SET product_name = src.product_name,
    category = src.category
WHERE product_code = src.product_code;
```

### Type 2 (Historical) — DimCustomer, DimAccount, DimEmployee
```sql
-- Expire old record
UPDATE dim_customer
SET valid_to = GETDATE(), is_current = 0
WHERE customer_code = @code AND is_current = 1;

-- Insert new version
INSERT INTO dim_customer (customer_code, ..., valid_from, is_current)
VALUES (@code, ..., GETDATE(), 1);
```

## Execution

```sql
-- Run individual steps
EXEC sathapana_staging.staging.usp_ExtractAll;
EXEC sathapana_dwh.dw.usp_LoadAll;

-- Or run via SQL Server Agent (see 12-automation/)
```

## Error Handling

- All procedures use `TRY...CATCH` blocks
- Failed records logged to `audit.etl_error_log`
- Batch ID tracked for end-to-end traceability
- Procedure returns error code on failure

## Performance Considerations

- **Incremental loads** — Only new/changed records processed
- **Batch processing** — Records processed in configurable batch sizes
- **Index management** — Non-clustered indexes dropped during bulk loads
- **Statistics** — Updated after each dimension/fact load

## Notes

- ETL runs on SQL Server Agent schedule (see `12-automation/`)
- Each step logs start/end times to `audit.etl_log`
- Failed steps trigger alerts to the DWH operator
- Weekly maintenance job rebuilds indexes and updates statistics
