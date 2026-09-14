# 07 - Data Quality Framework

## Overview

This directory contains the automated data quality framework that validates data across all layers of the warehouse — from source extraction through to data mart delivery.

## Files

| File | Purpose |
|------|---------|
| `01-data-quality-framework.sql` | Quality rules, check procedures, and reporting views |

## Quality Dimensions

| Dimension | Description | How It's Measured |
|-----------|-------------|-------------------|
| **Completeness** | All required data present | NULL% per column, missing record count |
| **Accuracy** | Data matches real-world values | Validation rule pass rate |
| **Consistency** | Data agrees across systems | Cross-database reconciliation |
| **Timeliness** | Data available when needed | ETL latency, data freshness |
| **Uniqueness** | No unintended duplicates | Duplicate detection queries |
| **Validity** | Data conforms to business rules | Business rule pass rate |

## Automated Quality Checks

### 1. Referential Integrity

```sql
-- Orphaned fact records (no matching dimension)
SELECT COUNT(*) AS orphan_count
FROM dw.fact_transactions f
LEFT JOIN dw.dim_customer c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
```

### 2. Balance Equation Verification

```sql
-- GL Debits must equal Credits
SELECT transaction_date_key,
       SUM(debit_amount) AS total_debits,
       SUM(credit_amount) AS total_credits,
       SUM(debit_amount) - SUM(credit_amount) AS difference
FROM dw.fact_gl_daily_balance
GROUP BY transaction_date_key
HAVING ABS(SUM(debit_amount) - SUM(credit_amount)) > 0.01;
```

### 3. Amount Validation

```sql
-- Transactions with unreasonable amounts
SELECT * FROM dw.fact_transactions
WHERE amount <= 0 OR amount > 10000000;
```

### 4. Date Validation

```sql
-- Facts with invalid date keys
SELECT * FROM dw.fact_transactions
WHERE transaction_date_key NOT IN (SELECT date_key FROM dw.dim_date);
```

### 5. Duplicate Detection

```sql
-- Duplicate transactions
SELECT transaction_code, COUNT(*) AS cnt
FROM dw.fact_transactions
GROUP BY transaction_code
HAVING COUNT(*) > 1;
```

### 6. Freshness Check

```sql
-- Stale data detection
SELECT table_name,
       MAX(etl_load_date) AS last_load,
       DATEDIFF(HOUR, MAX(etl_load_date), GETDATE()) AS hours_since_load
FROM audit.etl_log
GROUP BY table_name;
```

## Quality Rules Configuration

| Rule ID | Rule Name | Table | Severity | Description |
|---------|-----------|-------|----------|-------------|
| DQ001 | Not Null Check | dim_customer | Critical | Customer code must not be NULL |
| DQ002 | Referential Integrity | fact_transactions | Critical | All FKs must match dimensions |
| DQ003 | Balance Equation | fact_gl_daily_balance | High | Debits = Credits |
| DQ004 | Amount Range | fact_transactions | Medium | Amount between 0.01 and 10M |
| DQ005 | Date Validity | All facts | High | Date key must exist in dim_date |
| DQ006 | Duplicate Check | All tables | High | No duplicate business keys |
| DQ007 | Freshness | All tables | Medium | Data loaded within 24 hours |
| DQ008 | Currency Code | All monetary | Low | Valid ISO currency code |

## Severity Levels

| Level | Action |
|-------|--------|
| **Critical** | Stop ETL pipeline, send immediate alert |
| **High** | Log error, send alert, continue with warning |
| **Medium** | Log warning, include in daily report |
| **Low** | Log for reference, no alert |

## Quality Report

```sql
-- Generate quality report for a batch
EXEC audit.usp_GenerateQualityReport @BatchID = 'your-batch-id';

-- View quality trends
SELECT * FROM audit.vw_quality_trends ORDER BY check_date DESC;

-- Dashboard view
SELECT * FROM audit.vw_quality_dashboard;
```

## Execution

```sql
-- Run all quality checks
EXEC audit.usp_RunDataQualityChecks;

-- Run specific check
EXEC audit.usp_RunQualityCheck @RuleID = 'DQ001';
```

## Quality Score Calculation

```
Quality Score = (Passed Checks / Total Checks) × 100

Target: ≥ 99.5% for Critical rules
        ≥ 98.0% for High rules
        ≥ 95.0% for Medium rules
```

## Notes

- Quality checks run **after** each ETL batch completes
- Results are stored in `audit.data_quality_log` for trending
- Critical failures trigger immediate alerts to the DWH operator
- Monthly quality reports are generated for management review
