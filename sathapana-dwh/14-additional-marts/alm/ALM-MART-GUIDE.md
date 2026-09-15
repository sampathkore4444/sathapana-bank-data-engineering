# 🏦 ALM (Asset-Liability Management) Mart Guide

## Table of Contents
1. [Overview](#1-overview)
2. [ALM Metrics](#2-alm-metrics)
3. [Mart Schema](#3-mart-schema)
4. [ETL Procedures](#4-etl-procedures)
5. [Reports & Dashboards](#5-reports--dashboards)

---

## 1. Overview

The ALM Mart provides analytics for managing the bank's balance sheet risks including liquidity, interest rate, and funding risks.

```
┌─────────────────────────────────────────────────────────────────┐
│                    ALM MART ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    ALM MART                               │    │
│  │                                                           │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │  LIQUIDITY  │  │  INTEREST   │  │   FUNDING   │     │    │
│  │  │  ANALYSIS   │  │   RATE      │  │   ANALYSIS  │     │    │
│  │  │             │  │   RISK      │  │             │     │    │
│  │  │ • LCR       │  │             │  │ • Deposit   │     │    │
│  │  │ • NSFR      │  │ • GAP       │  │   stability │     │    │
│  │  │ • Cash Flow │  │ • Duration  │  │ • Term      │     │    │
│  │  │   mismatch  │  │ • NII       │  │   matching  │     │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. ALM Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| **LCR** (Liquidity Coverage Ratio) | HQLA / Net Cash Outflows | ≥ 100% |
| **NSFR** (Net Stable Funding Ratio) | Available Stable Funding / Required Stable Funding | ≥ 100% |
| **LDR** (Loan-to-Deposit Ratio) | Total Loans / Total Deposits | ≤ 90% |
| **NII** (Net Interest Income) | Interest Income - Interest Expense | Maximize |
| **EVE** (Economic Value of Equity) | PV(Assets) - PV(Liabilities) | Stable |

---

## 3. Mart Schema

```sql
-- ============================================================
-- ALM DATA MART
-- ============================================================

CREATE SCHEMA mart_alm;
GO

-- Liquidity Position Daily
CREATE TABLE mart_alm.liquidity_position (
    position_date DATE,
    currency VARCHAR(3),
    hqla_level1 DECIMAL(18,2),  -- Cash, central bank deposits
    hqla_level2a DECIMAL(18,2), -- Government bonds
    hqla_level2b DECIMAL(18,2), -- Corporate bonds
    total_hqla DECIMAL(18,2),
    net_cash_outflows DECIMAL(18,2),
    lcr_ratio DECIMAL(10,4),
    created_date DATETIME DEFAULT GETDATE()
);

-- Interest Rate Gap Analysis
CREATE TABLE mart_alm.interest_rate_gap (
    analysis_date DATE,
    time_bucket VARCHAR(20),  -- ON, 1-7D, 8-30D, 1-3M, 3-6M, 6-12M, >1Y
    rsa DECIMAL(18,2),  -- Rate Sensitive Assets
    rsl DECIMAL(18,2),  -- Rate Sensitive Liabilities
    gap DECIMAL(18,2),
    cumulative_gap DECIMAL(18,2),
    created_date DATETIME DEFAULT GETDATE()
);

-- Funding Analysis
CREATE TABLE mart_alm.funding_analysis (
    analysis_date DATE,
    funding_type VARCHAR(50),  -- RETAIL_DEPOSIT, WHOLESALE, BORROWING
    currency VARCHAR(3),
    balance DECIMAL(18,2),
    interest_rate DECIMAL(10,6),
    weighted_avg_maturity INT,  -- Days
    created_date DATETIME DEFAULT GETDATE()
);
```

---

## 4. ETL Procedures

```sql
-- ============================================================
-- ALM MART ETL
-- ============================================================

CREATE PROCEDURE mart_alm.usp_RefreshLiquidityPosition
    @PositionDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Calculate HQLA levels
    INSERT INTO mart_alm.liquidity_position (
        position_date, currency,
        hqla_level1, hqla_level2a, hqla_level2b,
        total_hqla, net_cash_outflows, lcr_ratio
    )
    SELECT
        @PositionDate,
        a.currency,
        -- Level 1 HQLA
        SUM(CASE WHEN a.account_type IN ('CASH', 'CENTRAL_BANK') THEN a.balance ELSE 0 END),
        -- Level 2A HQLA
        SUM(CASE WHEN a.account_type = 'GOVERNMENT_BOND' THEN a.balance ELSE 0 END),
        -- Level 2B HQLA
        SUM(CASE WHEN a.account_type = 'CORPORATE_BOND' THEN a.balance ELSE 0 END),
        -- Total HQLA
        SUM(CASE WHEN a.account_type IN ('CASH', 'CENTRAL_BANK', 'GOVERNMENT_BOND', 'CORPORATE_BOND') 
            THEN a.balance ELSE 0 END),
        -- Net Cash Outflows (simplified: 10% of deposits)
        SUM(CASE WHEN a.account_type IN ('SAVINGS', 'CURRENT', 'TERM_DEPOSIT') 
            THEN a.balance * 0.10 ELSE 0 END),
        -- LCR
        0  -- Calculated below
    FROM dw.fact_account_daily_snapshot a
    WHERE a.snapshot_date_key = CAST(FORMAT(@PositionDate, 'yyyyMMdd') AS INT)
    GROUP BY a.currency;
    
    -- Update LCR
    UPDATE mart_alm.liquidity_position
    SET lcr_ratio = total_hqla / NULLIF(net_cash_outflows, 0) * 100
    WHERE position_date = @PositionDate;
END;
GO
```

---

## 5. Reports & Dashboards

### ALM Dashboard Queries

```sql
-- LCR Trend
SELECT 
    position_date,
    lcr_ratio,
    total_hqla,
    net_cash_outflows
FROM mart_alm.liquidity_position
WHERE position_date >= DATEADD(MONTH, -3, GETDATE())
ORDER BY position_date;

-- Interest Rate Gap by Time Bucket
SELECT 
    time_bucket,
    rsa,
    rsl,
    gap,
    cumulative_gap
FROM mart_alm.interest_rate_gap
WHERE analysis_date = (SELECT MAX(analysis_date) FROM mart_alm.interest_rate_gap)
ORDER BY 
    CASE time_bucket
        WHEN 'ON' THEN 1
        WHEN '1-7D' THEN 2
        WHEN '8-30D' THEN 3
        WHEN '1-3M' THEN 4
        WHEN '3-6M' THEN 5
        WHEN '6-12M' THEN 6
        WHEN '>1Y' THEN 7
    END;

-- Funding Composition
SELECT 
    funding_type,
    SUM(balance) AS total_balance,
    AVG(interest_rate) AS avg_rate,
    AVG(weighted_avg_maturity) AS avg_maturity_days
FROM mart_alm.funding_analysis
WHERE analysis_date = (SELECT MAX(analysis_date) FROM mart_alm.funding_analysis)
GROUP BY funding_type
ORDER BY total_balance DESC;
```

---

*Created: September 2024*
