# 🏪 Data Marts Guide

## Table of Contents
1. [Overview](#1-overview)
2. [Data Mart Types](#2-data-mart-types)
3. [Credit Risk Mart](#3-credit-risk-mart)
4. [Customer Analytics Mart](#4-customer-analytics-mart)
5. [Treasury Mart](#5-treasury-mart)
6. [Implementation](#6-implementation)
7. [Hands-On Exercise](#7-hands-on-exercise)

---

## 1. Overview

A **Data Mart** is a subset of the data warehouse focused on a specific business area or department. It provides **pre-aggregated, business-ready data** for reporting and analysis.

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA MART ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              ENTERPRISE DATA WAREHOUSE                   │    │
│  │  dim_customer, dim_account, dim_product, fact_*          │    │
│  └─────────────────────────┬───────────────────────────────┘    │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │ CREDIT RISK │   │ CUSTOMER    │   │ TREASURY    │         │
│  │ MART        │   │ ANALYTICS   │   │ MART        │         │
│  │             │   │ MART        │   │             │         │
│  │ • NPL Ratio │   │ • Segments  │   │ • FX Rates  │         │
│  │ • Provisions│   │ • Behavior  │   │ • Liquidity │         │
│  │ • Collateral│   │ • CLV       │   │ • Positions │         │
│  └─────────────┘   └─────────────┘   └─────────────┘         │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │ Risk Mgmt   │   │ Marketing   │   │ Treasury    │         │
│  │ Reports     │   │ Reports     │   │ Reports     │         │
│  └─────────────┘   └─────────────┘   └─────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Mart Types

| Type | Description | Example |
|------|-------------|---------|
| **Dependent** | Built from central DW | Uses dim/fact from EDW |
| **Independent** | Standalone, direct from source | Departmental shadow IT |
| **Logical** | Virtual views, no physical tables | View-based marts |

---

## 3. Credit Risk Mart

### Purpose
Provide pre-calculated risk metrics for the Risk Management department.

### Schema

```sql
-- Credit Risk Data Mart
CREATE SCHEMA mart_credit_risk;
GO

-- Loan Portfolio Summary
CREATE TABLE mart_credit_risk.loan_portfolio_summary (
    summary_date DATE,
    branch_code VARCHAR(20),
    product_code VARCHAR(20),
    risk_classification VARCHAR(20),
    loan_count INT,
    total_disbursed DECIMAL(18,2),
    total_outstanding DECIMAL(18,2),
    total_provision DECIMAL(18,2),
    npl_ratio DECIMAL(5,2),  -- Non-Performing Loan ratio
    avg_days_past_due INT
);

-- Monthly Risk Snapshot
CREATE TABLE mart_credit_risk.monthly_risk_snapshot (
    snapshot_month VARCHAR(7),  -- YYYY-MM
    total_loans INT,
    performing_loans INT,
    non_performing_loans INT,
    total_portfolio DECIMAL(18,2),
    npl_ratio DECIMAL(5,2),
    provision_coverage DECIMAL(5,2),
    created_date DATETIME DEFAULT GETDATE()
);
```

### ETL for Credit Risk Mart

```sql
CREATE PROCEDURE mart_credit_risk.usp_RefreshLoanPortfolio
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @SnapshotDate DATE = GETDATE();
    
    PRINT 'Refreshing Credit Risk Mart - Loan Portfolio...';
    
    -- Clear previous data for this snapshot
    DELETE FROM mart_credit_risk.loan_portfolio_summary
    WHERE summary_date = @SnapshotDate;
    
    -- Calculate loan portfolio by branch, product, and risk
    INSERT INTO mart_credit_risk.loan_portfolio_summary (
        summary_date, branch_code, product_code, risk_classification,
        loan_count, total_disbursed, total_outstanding, total_provision,
        npl_ratio, avg_days_past_due
    )
    SELECT
        @SnapshotDate,
        b.branch_code,
        p.product_code,
        l.risk_classification,
        COUNT(*) AS loan_count,
        SUM(l.disbursed_amount) AS total_disbursed,
        SUM(l.outstanding_principal) AS total_outstanding,
        SUM(l.provision_amount) AS total_provision,
        CAST(
            SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) * 100.0 /
            NULLIF(SUM(l.outstanding_principal), 0) AS DECIMAL(5,2)
        ) AS npl_ratio,
        AVG(l.days_past_due) AS avg_days_past_due
    FROM dw.fact_loan_portfolio l
    JOIN dw.dim_branch b ON l.branch_key = b.branch_key
    JOIN dw.dim_product p ON l.product_key = p.product_key
    WHERE l.snapshot_date_key = CAST(FORMAT(@SnapshotDate, 'yyyyMMdd') AS INT)
    GROUP BY b.branch_code, p.product_code, l.risk_classification;
    
    -- Log completion
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Refresh_CreditRisk_Mart', 'loan_portfolio_summary', 'LOAD',
        @@ROWCOUNT, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT 'Credit Risk Mart refreshed successfully.';
END;
```

---

## 4. Customer Analytics Mart

### Purpose
Provide customer behavior and segmentation data for Marketing department.

### Schema

```sql
-- Customer Analytics Data Mart
CREATE SCHEMA mart_customer_analytics;
GO

-- Customer Segmentation
CREATE TABLE mart_customer_analytics.customer_segmentation (
    customer_key INT,
    customer_code VARCHAR(20),
    customer_name NVARCHAR(200),
    segment VARCHAR(50),
    risk_rating VARCHAR(20),
    total_accounts INT,
    total_balance DECIMAL(18,2),
    total_transactions INT,
    avg_monthly_transactions DECIMAL(10,2),
    avg_transaction_amount DECIMAL(18,2),
    last_transaction_date DATE,
    customer_tenure_days INT,
    clv_score DECIMAL(10,2),  -- Customer Lifetime Value
    segment_date DATE
);

-- Customer Behavior Monthly
CREATE TABLE mart_customer_analytics.customer_behavior_monthly (
    month_key VARCHAR(7),  -- YYYY-MM
    customer_code VARCHAR(20),
    transaction_count INT,
    total_deposits DECIMAL(18,2),
    total_withdrawals DECIMAL(18,2),
    net_flow DECIMAL(18,2),
    unique_channels_used INT,
    primary_channel VARCHAR(50),
    avg_balance DECIMAL(18,2)
);
```

### ETL for Customer Analytics Mart

```sql
CREATE PROCEDURE mart_customer_analytics.usp_RefreshCustomerSegmentation
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @SnapshotDate DATE = GETDATE();
    
    PRINT 'Refreshing Customer Analytics Mart - Segmentation...';
    
    -- Calculate customer segmentation
    INSERT INTO mart_customer_analytics.customer_segmentation (
        customer_key, customer_code, customer_name, segment, risk_rating,
        total_accounts, total_balance, total_transactions,
        avg_monthly_transactions, avg_transaction_amount,
        last_transaction_date, customer_tenure_days, clv_score, segment_date
    )
    SELECT
        c.customer_key,
        c.customer_code,
        c.first_name + ' ' + c.last_name AS customer_name,
        c.customer_segment,
        c.risk_rating,
        COUNT(DISTINCT a.account_key) AS total_accounts,
        ISNULL(SUM(a.balance), 0) AS total_balance,
        COUNT(t.transaction_key) AS total_transactions,
        CAST(COUNT(t.transaction_key) * 1.0 / 
            NULLIF(DATEDIFF(MONTH, c.effective_date, @SnapshotDate), 0) AS DECIMAL(10,2)) AS avg_monthly_transactions,
        ISNULL(AVG(t.amount), 0) AS avg_transaction_amount,
        MAX(t.transaction_date) AS last_transaction_date,
        DATEDIFF(DAY, c.effective_date, @SnapshotDate) AS customer_tenure_days,
        -- Simple CLV calculation
        ISNULL(SUM(t.amount), 0) * 0.01 AS clv_score,
        @SnapshotDate
    FROM dw.dim_customer c
    LEFT JOIN dw.dim_account a ON c.customer_key = a.customer_key AND a.is_current = 1
    LEFT JOIN dw.fact_transactions t ON a.account_key = t.account_key
    WHERE c.is_current = 1
    GROUP BY 
        c.customer_key, c.customer_code, c.first_name, c.last_name,
        c.customer_segment, c.risk_rating, c.effective_date;
    
    -- Log completion
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Refresh_CustomerAnalytics_Mart', 'customer_segmentation', 'LOAD',
        @@ROWCOUNT, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT 'Customer Analytics Mart refreshed successfully.';
END;
```

---

## 5. Treasury Mart

### Purpose
Provide liquidity and FX position data for Treasury department.

### Schema

```sql
-- Treasury Data Mart
CREATE SCHEMA mart_treasury;
GO

-- Daily Liquidity Position
CREATE TABLE mart_treasury.daily_liquidity (
    position_date DATE,
    branch_code VARCHAR(20),
    currency VARCHAR(3),
    total_deposits DECIMAL(18,2),
    total_withdrawals DECIMAL(18,2),
    net_position DECIMAL(18,2),
    liquidity_ratio DECIMAL(10,4),
    created_date DATETIME DEFAULT GETDATE()
);

-- FX Position Summary
CREATE TABLE mart_treasury.fx_position_summary (
    position_date DATE,
    source_currency VARCHAR(3),
    target_currency VARCHAR(3),
    total_bought DECIMAL(18,2),
    total_sold DECIMAL(18,2),
    net_position DECIMAL(18,2),
    avg_rate DECIMAL(10,6),
    spread DECIMAL(10,6)
);
```

### ETL for Treasury Mart

```sql
CREATE PROCEDURE mart_treasury.usp_RefreshDailyLiquidity
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @PositionDate DATE = GETDATE();
    
    PRINT 'Refreshing Treasury Mart - Daily Liquidity...';
    
    INSERT INTO mart_treasury.daily_liquidity (
        position_date, branch_code, currency,
        total_deposits, total_withdrawals, net_position, liquidity_ratio
    )
    SELECT
        @PositionDate,
        b.branch_code,
        t.currency,
        SUM(CASE WHEN t.transaction_type = 'DEPOSIT' THEN t.amount ELSE 0 END) AS total_deposits,
        SUM(CASE WHEN t.transaction_type = 'WITHDRAWAL' THEN t.amount ELSE 0 END) AS total_withdrawals,
        SUM(CASE WHEN t.transaction_type = 'DEPOSIT' THEN t.amount ELSE -t.amount END) AS net_position,
        CAST(
            SUM(CASE WHEN t.transaction_type = 'DEPOSIT' THEN t.amount ELSE 0 END) * 1.0 /
            NULLIF(SUM(CASE WHEN t.transaction_type = 'WITHDRAWAL' THEN t.amount ELSE 0 END), 0) AS DECIMAL(10,4)
        ) AS liquidity_ratio
    FROM dw.fact_transactions t
    JOIN dw.dim_branch b ON t.branch_key = b.branch_key
    JOIN dw.dim_date d ON t.date_key = d.date_key
    WHERE d.full_date = @PositionDate
    GROUP BY b.branch_code, t.currency;
    
    -- Log completion
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Refresh_Treasury_Mart', 'daily_liquidity', 'LOAD',
        @@ROWCOUNT, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT 'Treasury Mart refreshed successfully.';
END;
```

---

## 6. Implementation

### Master Mart Refresh Procedure

```sql
CREATE PROCEDURE mart.usp_RefreshAllMarts
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    DECLARE @StartTime DATETIME = GETDATE();
    
    PRINT '================================================';
    PRINT 'REFRESHING ALL DATA MARTS';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT '================================================';
    
    BEGIN TRY
        -- Refresh Credit Risk Mart
        EXEC mart_credit_risk.usp_RefreshLoanPortfolio @BatchID;
        
        -- Refresh Customer Analytics Mart
        EXEC mart_customer_analytics.usp_RefreshCustomerSegmentation @BatchID;
        
        -- Refresh Treasury Mart
        EXEC mart_treasury.usp_RefreshDailyLiquidity @BatchID;
        
        PRINT '================================================';
        PRINT 'ALL DATA MARTS REFRESHED SUCCESSFULLY';
        PRINT 'Duration: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR(10)) + ' seconds';
        PRINT '================================================';
        
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
```

---

## 7. Hands-On Exercise

### Exercise: Build a Data Mart

```sql
-- Step 1: Create schema
CREATE SCHEMA mart_compliance;
GO

-- Step 2: Create AML monitoring mart table
CREATE TABLE mart_compliance.aml_daily_summary (
    summary_date DATE,
    branch_code VARCHAR(20),
    total_alerts INT,
    high_risk_alerts INT,
    alerts_investigated INT,
    alerts_escalated INT,
    avg_resolution_time_hours DECIMAL(10,2)
);

-- Step 3: Create ETL procedure
-- Step 4: Test by running the procedure
```

---

*Created: September 2024*
