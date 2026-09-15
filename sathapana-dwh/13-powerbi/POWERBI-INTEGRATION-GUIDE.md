# 📊 Power BI Integration Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Data Connection](#2-data-connection)
3. [Data Model Design](#3-data-model-design)
4. [DAX Measures](#4-dax-measures)
5. [Report Design](#5-report-design)
6. [Row-Level Security](#6-row-level-security)
7. [Publishing & Scheduling](#7-publishing--scheduling)

---

## 1. Overview

Power BI provides business intelligence dashboards and reports for Sathapana Bank stakeholders.

```
┌─────────────────────────────────────────────────────────────────┐
│                    POWER BI ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │    DWH      │───►│  Power BI   │───►│  Reports    │         │
│  │  (Source)   │    │  (Transform)│    │  (Visuals)  │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                           │                                      │
│                           ▼                                      │
│                    ┌─────────────┐                               │
│                    │ Power BI    │                               │
│                    │ Service     │                               │
│                    │ (Cloud)     │                               │
│                    └─────────────┘                               │
│                           │                                      │
│                           ▼                                      │
│                    ┌─────────────┐                               │
│                    │   Users     │                               │
│                    │ (Web/Mobile)│                               │
│                    └─────────────┘                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Connection

### DirectQuery Connection (Recommended)

```
1. Open Power BI Desktop
2. Get Data → SQL Server
3. Enter server: YOUR_SERVER
4. Database: sathapana_dwh
5. Select DirectQuery mode
6. Select tables/views needed
```

### Import Mode (for smaller datasets)

```sql
-- Create views optimized for Power BI
CREATE VIEW powerbi.vw_CustomerSummary AS
SELECT 
    c.customer_key,
    c.customer_code,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.customer_segment,
    c.risk_rating,
    c.city,
    c.province,
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    SUM(t.amount_usd) AS total_amount_usd
FROM dw.dim_customer c
LEFT JOIN dw.fact_transactions t ON c.customer_key = t.customer_key
WHERE c.is_current = 1
GROUP BY c.customer_key, c.customer_code, c.first_name, c.last_name,
         c.customer_segment, c.risk_rating, c.city, c.province;
GO
```

---

## 3. Data Model Design

### Star Schema for Power BI

```
                    dim_date
                       │
                       │
dim_customer ─────── fact_transactions ─────── dim_branch
                       │
                       │
                    dim_product
```

### Recommended Tables

| Table | Type | Purpose |
|-------|------|---------|
| dim_customer | Dimension | Customer attributes |
| dim_account | Dimension | Account details |
| dim_branch | Dimension | Branch hierarchy |
| dim_product | Dimension | Product catalog |
| dim_date | Dimension | Date attributes |
| fact_transactions | Fact | Transaction data |
| fact_loan_portfolio | Fact | Loan data |

---

## 4. DAX Measures

### Common Measures

```dax
// Total Transactions
Total Transactions = COUNTROWS(fact_transactions)

// Total Amount (USD)
Total Amount USD = SUM(fact_transactions[amount_usd])

// Average Transaction
Avg Transaction = AVERAGE(fact_transactions[amount_usd])

// Customer Count
Customer Count = DISTINCTCOUNT(fact_transactions[customer_key])

// Transaction Count by Type
Deposit Count = 
CALCULATE(
    COUNTROWS(fact_transactions),
    fact_transactions[transaction_type] = "DEPOSIT"
)

// YoY Growth
YoY Growth = 
VAR CurrentYear = [Total Amount USD]
VAR PreviousYear = CALCULATE([Total Amount USD], DATEADD(dim_date[full_date], -1, YEAR))
RETURN
DIVIDE(CurrentYear - PreviousYear, PreviousYear, 0)

// NPL Ratio
NPL Ratio = 
VAR NPLAmount = CALCULATE(SUM(fact_loan_portfolio[outstanding_principal]), fact_loan_portfolio[days_past_due] > 90)
VAR TotalPortfolio = SUM(fact_loan_portfolio[outstanding_principal])
RETURN
DIVIDE(NPLAmount, TotalPortfolio, 0)

// LDR Ratio
LDR Ratio = 
VAR TotalLoans = SUM(fact_loan_portfolio[outstanding_principal])
VAR TotalDeposits = SUM(fact_deposit_snapshot[balance])
RETURN
DIVIDE(TotalLoans, TotalDeposits, 0)
```

---

## 5. Report Design

### Executive Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXECUTIVE DASHBOARD                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ Total    │  │ Total    │  │ NPL      │  │ CAR      │       │
│  │ Assets   │  │ Deposits │  │ Ratio    │  │ Ratio    │       │
│  │ $500M    │  │ $400M    │  │ 2.5%     │  │ 18%      │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                  │
│  ┌─────────────────────────┐  ┌─────────────────────────┐      │
│  │ Transaction Trend       │  │ Branch Performance      │      │
│  │ (Line Chart)            │  │ (Bar Chart)             │      │
│  │                         │  │                         │      │
│  └─────────────────────────┘  └─────────────────────────┘      │
│                                                                  │
│  ┌─────────────────────────┐  ┌─────────────────────────┐      │
│  │ Customer Segmentation   │  │ Product Mix             │      │
│  │ (Pie Chart)             │  │ (Donut Chart)           │      │
│  │                         │  │                         │      │
│  └─────────────────────────┘  └─────────────────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Row-Level Security

### Configure RLS in Power BI

```dax
// Branch filter for dim_branch
[branch_code] = LOOKUPVALUE(
    security.user_branch_access[branch_code],
    security.user_branch_access[username], USERPRINCIPALNAME()
)
```

### Dynamic RLS

```dax
// Measure for dynamic filtering
Branch Filter = 
VAR CurrentUser = USERPRINCIPALNAME()
VAR UserBranch = 
    CALCULATE(
        MAX(security.user_branch_access[branch_code]),
        security.user_branch_access[username] = CurrentUser
    )
RETURN
IF(UserBranch = "ALL", TRUE(), [branch_code] = UserBranch)
```

---

## 7. Publishing & Scheduling

### Publish to Power BI Service

```
1. Save your Power BI file (.pbix)
2. Click Publish
3. Select workspace: Sathapana Bank
4. Wait for upload
5. Configure dataset settings
```

### Schedule Refresh

```
1. Go to Power BI Service
2. Select dataset: DWH Connection
3. Settings → Scheduled Refresh
4. Add schedule: Daily at 6:00 AM
5. Enter gateway credentials
6. Enable refresh
```

---

## Quick Reference

### Power BI Connection String
```
Server: YOUR_SERVER
Database: sathapana_dwh
Authentication: Windows Authentication
```

### Key Views for Power BI
| View | Purpose |
|------|---------|
| dw.dim_customer | Customer data |
| dw.fact_transactions | Transaction data |
| dw.dim_branch | Branch hierarchy |
| audit.vw_etl_status | ETL monitoring |

---

*Created: September 2024*
