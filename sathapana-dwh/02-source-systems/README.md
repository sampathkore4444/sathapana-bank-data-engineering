# 02 - Source Systems

## Overview

This directory contains the **Layer 0** setup for Sathapana Bank's Data Warehouse — the OLTP source database that simulates the core banking system.

## Files

| File | Purpose |
|------|---------|
| `01-create-source-database.sql` | Creates `sathapana_source` database with all OLTP tables and sample data |
| `02-create-raw-zone-database.sql` | Creates `sathapana_raw` database (Layer 1) for exact source data copy |

## Source Database: `sathapana_source`

**Schema**: `oltp`

### Tables

| Table | Description | Key Relationships |
|-------|-------------|-------------------|
| `branches` | Bank branches (10 branches across Cambodia) | Self-referencing (manager_id) |
| `employees` | Staff records (10 employees) | FK → branches |
| `customers` | Customer profiles (10 customers) | FK → branches |
| `products` | Banking products (16 products) | — |
| `accounts` | Customer accounts (13 accounts) | FK → customers, products, branches |
| `transactions` | Daily transactions (200 generated) | FK → accounts, employees, branches |
| `loans` | Loan portfolio (8 loans) | FK → customers, products, branches |
| `loan_schedules` | Repayment schedules | FK → loans |
| `deposits` | Fixed/recurring deposits | FK → accounts, customers, products |
| `cards` | Debit/credit cards | FK → customers, accounts |
| `fx_transactions` | Foreign exchange deals | FK → customers, accounts, branches |
| `cheques` | Cheque processing | FK → accounts, branches |
| `gl_entries` | General ledger entries | FK → branches |
| `aml_alerts` | AML/CFT alerts | FK → customers, transactions, employees |
| `audit_log` | Source system audit trail | — |
| `exchange_rates` | Daily exchange rates | — |

### Sample Data

- **10 branches** across 6 provinces (Phnom Penh, Siem Reap, Battambang, Sihanoukville, Kampong Cham, Kampong Chhnang)
- **10 employees** with hierarchical reporting structure
- **10 customers** (mix of Individual, Corporate, SME, Private Banking, Micro)
- **16 products** (Savings, Fixed Deposits, Loans, Cards, Transfers, FX)
- **13 accounts** with realistic balances
- **200 transactions** (randomly generated across channels)
- **8 loans** with various statuses and risk classifications
- **5 exchange rate pairs** (USD/KHR, EUR/USD, GBP/USD, THB/USD, JPY/USD)
- **3 AML alerts** (structuring, high value, unusual pattern)

## Raw Zone: `sathapana_raw`

**Schema**: `raw`

Mirrors all source tables exactly — no transformations applied. Used as:
- Historical reference point
- Source system recovery capability
- Data lineage starting point
- Audit trail for regulatory compliance

## Execution Order

```sql
-- Step 1: Create source database
:02-source-systems/01-create-source-database.sql

-- Step 2: Create raw zone (depends on source being created first)
:02-source-systems/02-create-raw-zone-database.sql
```

## Source System Mapping

```
Core Banking System ──┐
                      ├──► sathapana_source.oltp.*
Treasury System ──────┤
                      │
Credit System ────────┤
                      │
External Feeds ───────┘
  (NBC, SWIFT)
```

## Notes

- The source database is a **simulation** of real OLTP systems
- In production, these would be replaced by actual source system connections
- Data files are configured for SQL Server default paths
- All tables use `IDENTITY` for auto-incrementing primary keys
