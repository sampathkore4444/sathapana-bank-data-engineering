# ⚙️ Operations Mart Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Operations Metrics](#2-operations-metrics)
3. [Mart Schema](#3-mart-schema)
4. [ETL Procedures](#4-etl-procedures)
5. [Reports & Dashboards](#5-reports--dashboards)

---

## 1. Overview

The Operations Mart provides analytics for branch operations, channel performance, and operational efficiency.

```
┌─────────────────────────────────────────────────────────────────┐
│                    OPERATIONS MART ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 OPERATIONS MART                           │    │
│  │                                                           │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │   BRANCH    │  │   CHANNEL   │  │ OPERATIONAL │     │    │
│  │  │ PERFORMANCE │  │ PERFORMANCE │  │ EFFICIENCY  │     │    │
│  │  │             │  │             │  │             │     │    │
│  │  │ • Teller    │  │ • ATM       │  │ • Staff     │     │    │
│  │  │   activity  │  │ • Mobile    │  │   productivity│   │    │
│  │  │ • Wait time │  │ • Internet  │  │ • Cost per  │     │    │
│  │  │ • Errors    │  │ • Agent     │  │   transaction│   │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │    │
│  │                                                           │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Operations Metrics

| Category | Metric | Description |
|----------|--------|-------------|
| **Branch** | Transaction Volume | Daily transactions per branch |
| **Branch** | Avg Wait Time | Customer wait time |
| **Channel** | Channel Mix | % by channel type |
| **Channel** | Digital Adoption | Digital vs branch usage |
| **Staff** | Transactions per Staff | Staff productivity |
| **Cost** | Cost per Transaction | Operational efficiency |

---

## 3. Mart Schema

```sql
-- ============================================================
-- OPERATIONS DATA MART
-- ============================================================

CREATE SCHEMA mart_operations;
GO

-- Branch Performance Daily
CREATE TABLE mart_operations.branch_performance (
    report_date DATE,
    branch_code VARCHAR(20),
    branch_name NVARCHAR(200),
    region VARCHAR(100),
    total_transactions BIGINT,
    total_value_usd DECIMAL(18,2),
    avg_transaction_value DECIMAL(18,2),
    unique_customers BIGINT,
    new_accounts INT,
    teller_transactions INT,
    atm_transactions INT,
    mobile_transactions INT,
    internet_transactions INT,
    created_date DATETIME DEFAULT GETDATE()
);

-- Channel Performance
CREATE TABLE mart_operations.channel_performance (
    report_date DATE,
    channel_code VARCHAR(20),
    channel_name VARCHAR(100),
    transaction_count BIGINT,
    transaction_value_usd DECIMAL(18,2),
    unique_users BIGINT,
    success_rate DECIMAL(5,2),
    avg_response_time_ms INT,
    created_date DATETIME DEFAULT GETDATE()
);

-- Operational Efficiency
CREATE TABLE mart_operations.operational_efficiency (
    report_date DATE,
    branch_code VARCHAR(20),
    total_staff INT,
    transactions_per_staff DECIMAL(10,2),
    cost_per_transaction DECIMAL(10,2),
    revenue_per_transaction DECIMAL(10,2),
    created_date DATETIME DEFAULT GETDATE()
);
```

---

## 4. ETL Procedures

```sql
-- ============================================================
-- OPERATIONS MART ETL
-- ============================================================

CREATE PROCEDURE mart_operations.usp_RefreshBranchPerformance
    @ReportDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DateKey INT = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT);
    
    PRINT 'Refreshing Branch Performance for ' + CONVERT(VARCHAR(10), @ReportDate, 120);
    
    INSERT INTO mart_operations.branch_performance (
        report_date, branch_code, branch_name, region,
        total_transactions, total_value_usd, avg_transaction_value,
        unique_customers, teller_transactions, atm_transactions,
        mobile_transactions, internet_transactions
    )
    SELECT
        @ReportDate,
        b.branch_code,
        b.branch_name,
        b.region,
        COUNT(*) AS total_transactions,
        SUM(t.amount_usd) AS total_value_usd,
        AVG(t.amount_usd) AS avg_transaction_value,
        COUNT(DISTINCT t.customer_key) AS unique_customers,
        SUM(CASE WHEN ch.channel_code = 'TELLER' THEN 1 ELSE 0 END),
        SUM(CASE WHEN ch.channel_code = 'ATM' THEN 1 ELSE 0 END),
        SUM(CASE WHEN ch.channel_code = 'MOBILE' THEN 1 ELSE 0 END),
        SUM(CASE WHEN ch.channel_code = 'INTERNET' THEN 1 ELSE 0 END)
    FROM dw.fact_transactions t
    JOIN dw.dim_branch b ON t.branch_key = b.branch_key
    JOIN dw.dim_channel ch ON t.channel_key = ch.channel_key
    WHERE t.date_key = @DateKey
    GROUP BY b.branch_code, b.branch_name, b.region;
    
    PRINT 'Branch performance refreshed.';
END;
GO

CREATE PROCEDURE mart_operations.usp_RefreshChannelPerformance
    @ReportDate DATE
AS
BEGIN
    DECLARE @DateKey INT = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT);
    
    INSERT INTO mart_operations.channel_performance (
        report_date, channel_code, channel_name,
        transaction_count, transaction_value_usd,
        unique_users, success_rate
    )
    SELECT
        @ReportDate,
        ch.channel_code,
        ch.channel_name,
        COUNT(*) AS transaction_count,
        SUM(t.amount_usd) AS transaction_value_usd,
        COUNT(DISTINCT t.customer_key) AS unique_users,
        CAST(SUM(CASE WHEN t.status = 'SUCCESS' THEN 1 ELSE 0 END) * 100.0 / 
            NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS success_rate
    FROM dw.fact_transactions t
    JOIN dw.dim_channel ch ON t.channel_key = ch.channel_key
    WHERE t.date_key = @DateKey
    GROUP BY ch.channel_code, ch.channel_name;
    
    PRINT 'Channel performance refreshed.';
END;
GO
```

---

## 5. Reports & Dashboards

### Operations Dashboard Queries

```sql
-- Branch Performance Ranking
SELECT TOP 10
    branch_name,
    region,
    total_transactions,
    total_value_usd,
    unique_customers
FROM mart_operations.branch_performance
WHERE report_date = (SELECT MAX(report_date) FROM mart_operations.branch_performance)
ORDER BY total_value_usd DESC;

-- Channel Mix Analysis
SELECT 
    channel_name,
    SUM(transaction_count) AS total_transactions,
    CAST(SUM(transaction_count) * 100.0 / 
        (SELECT SUM(transaction_count) FROM mart_operations.channel_performance 
         WHERE report_date = (SELECT MAX(report_date) FROM mart_operations.channel_performance)) 
        AS DECIMAL(5,1)) AS pct_of_total
FROM mart_operations.channel_performance
WHERE report_date = (SELECT MAX(report_date) FROM mart_operations.channel_performance)
GROUP BY channel_name
ORDER BY total_transactions DESC;

-- Digital Adoption Trend
SELECT 
    report_date,
    SUM(CASE WHEN channel_code IN ('MOBILE', 'INTERNET') THEN transaction_count ELSE 0 END) AS digital_txns,
    SUM(transaction_count) AS total_txns,
    CAST(SUM(CASE WHEN channel_code IN ('MOBILE', 'INTERNET') THEN transaction_count ELSE 0 END) * 100.0 / 
        NULLIF(SUM(transaction_count), 0) AS DECIMAL(5,1)) AS digital_pct
FROM mart_operations.channel_performance
WHERE report_date >= DATEADD(MONTH, -6, GETDATE())
GROUP BY report_date
ORDER BY report_date;

-- Branch Efficiency Comparison
SELECT 
    branch_code,
    transactions_per_staff,
    cost_per_transaction,
    revenue_per_transaction,
    revenue_per_transaction - cost_per_transaction AS profit_per_transaction
FROM mart_operations.operational_efficiency
WHERE report_date = (SELECT MAX(report_date) FROM mart_operations.operational_efficiency)
ORDER BY profit_per_transaction DESC;
```

---

*Created: September 2024*
