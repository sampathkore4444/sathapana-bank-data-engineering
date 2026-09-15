# 📋 Regulatory Reporting Guide - NBC Compliance

## Table of Contents
1. [Overview](#1-overview)
2. [NBC Reporting Requirements](#2-nbc-reporting-requirements)
3. [Capital Adequacy Ratio (CAR)](#3-capital-adequacy-ratio)
4. [Large Exposure Reporting](#4-large-exposure-reporting)
5. [Liquidity Reporting](#5-liquidity-reporting)
6. [Prudential Returns](#6-prudential-returns)
7. [Report Automation](#7-report-automation)

---

## 1. Overview

Sathapana Bank must submit regular reports to the **National Bank of Cambodia (NBC)** for regulatory compliance.

```
┌─────────────────────────────────────────────────────────────────┐
│                    NBC REGULATORY REPORTS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ CAPITAL ADEQUACY                                          │    │
│  │ • CAR Ratio (Minimum 15%)                                │    │
│  │ • Tier 1 & Tier 2 Capital                                │    │
│  │ • Risk-Weighted Assets                                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ LARGE EXPOSURES                                           │    │
│  │ • Single borrower limits (25% of capital)                │    │
│  │ • Group exposure limits                                  │    │
│  │ • Connected party exposures                              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ LIQUIDITY                                                 │    │
│  │ • Liquidity Coverage Ratio (LCR)                         │    │
│  │ • Loan-to-Deposit Ratio (LDR)                            │    │
│  │ • Cash reserve requirements                              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ PRUDENTIAL                                                │    │
│  │ • Loan classification & provisioning                     │    │
│  │ • NPL ratio                                              │    │
│  │ • Concentration risk                                     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. NBC Reporting Requirements

| Report | Frequency | Deadline | Content |
|--------|-----------|----------|---------|
| CAR Report | Monthly | 15th | Capital adequacy |
| Large Exposure | Monthly | 15th | Top exposures |
| Liquidity Report | Monthly | 15th | LCR, LDR |
| Loan Classification | Monthly | 15th | NPL, provisions |
| Financial Statements | Quarterly | 30 days | Balance sheet, P&L |
| AML Report | Quarterly | 30 days | Suspicious transactions |

---

## 3. Capital Adequacy Ratio (CAR)

```sql
-- ============================================================
-- CAR CALCULATION PROCEDURE
-- ============================================================

CREATE PROCEDURE regulatory.usp_CalculateCAR
    @ReportDate DATE
AS
BEGIN
    DECLARE @Tier1Capital DECIMAL(18,2);
    DECLARE @Tier2Capital DECIMAL(18,2);
    DECLARE @RiskWeightedAssets DECIMAL(18,2);
    DECLARE @CAR DECIMAL(10,4);
    
    -- Tier 1 Capital (Equity + Retained Earnings)
    SELECT @Tier1Capital = 
        ISNULL(SUM(CASE WHEN gl_account LIKE '31%' THEN balance ELSE 0 END), 0) -  -- Share Capital
        ISNULL(SUM(CASE WHEN gl_account LIKE '32%' THEN balance ELSE 0 END), 0);    -- Deductions
    
    -- Tier 2 Capital (Reserves + Subordinated Debt)
    SELECT @Tier2Capital = 
        ISNULL(SUM(CASE WHEN gl_account LIKE '33%' THEN balance ELSE 0 END), 0);
    
    -- Risk-Weighted Assets (Credit Risk)
    SELECT @RiskWeightedAssets = 
        ISNULL(SUM(
            CASE risk_weight
                WHEN '0%' THEN 0
                WHEN '20%' THEN outstanding_principal * 0.20
                WHEN '50%' THEN outstanding_principal * 0.50
                WHEN '100%' THEN outstanding_principal * 1.00
                WHEN '150%' THEN outstanding_principal * 1.50
                ELSE outstanding_principal
            END
        ), 0)
    FROM dw.fact_loan_portfolio f
    JOIN dw.dim_product p ON f.product_key = p.product_key
    WHERE f.snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT);
    
    -- Calculate CAR
    SET @CAR = (@Tier1Capital + @Tier2Capital) / NULLIF(@RiskWeightedAssets, 0) * 100;
    
    -- Output results
    SELECT
        @ReportDate AS report_date,
        @Tier1Capital AS tier1_capital,
        @Tier2Capital AS tier2_capital,
        @Tier1Capital + @Tier2Capital AS total_capital,
        @RiskWeightedAssets AS risk_weighted_assets,
        @CAR AS car_ratio,
        CASE WHEN @CAR >= 15 THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END AS status;
END;
GO
```

---

## 4. Large Exposure Reporting

```sql
-- ============================================================
-- LARGE EXPOSURE CALCULATION
-- ============================================================

CREATE PROCEDURE regulatory.usp_CalculateLargeExposure
    @ReportDate DATE
AS
BEGIN
    DECLARE @TotalCapital DECIMAL(18,2);
    DECLARE @ExposureLimit DECIMAL(18,2);
    
    -- Get total capital
    SELECT @TotalCapital = tier1_capital + tier2_capital
    FROM dw.fact_regulatory_car
    WHERE report_date = @ReportDate;
    
    -- Large exposure limit = 25% of total capital
    SET @ExposureLimit = @TotalCapital * 0.25;
    
    -- Find exposures exceeding threshold
    SELECT
        c.customer_code,
        c.first_name + ' ' + c.last_name AS customer_name,
        c.customer_segment,
        SUM(f.outstanding_principal) AS total_exposure,
        CAST(SUM(f.outstanding_principal) * 100.0 / @TotalCapital AS DECIMAL(5,2)) AS pct_of_capital,
        CASE 
            WHEN SUM(f.outstanding_principal) > @ExposureLimit THEN 'EXCEEDS LIMIT'
            WHEN SUM(f.outstanding_principal) > @ExposureLimit * 0.5 THEN 'WARNING'
            ELSE 'WITHIN LIMIT'
        END AS status
    FROM dw.fact_loan_portfolio f
    JOIN dw.dim_customer c ON f.customer_key = c.customer_key AND c.is_current = 1
    WHERE f.snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
    GROUP BY c.customer_code, c.first_name, c.last_name, c.customer_segment
    HAVING SUM(f.outstanding_principal) > @ExposureLimit * 0.5
    ORDER BY total_exposure DESC;
END;
GO
```

---

## 5. Liquidity Reporting

```sql
-- ============================================================
-- LIQUIDITY REPORT
-- ============================================================

CREATE PROCEDURE regulatory.usp_LiquidityReport
    @ReportDate DATE
AS
BEGIN
    DECLARE @HighQualityLiquidAssets DECIMAL(18,2);
    DECLARE @TotalCashOutflows DECIMAL(18,2);
    DECLARE @LCR DECIMAL(10,4);
    DECLARE @TotalLoans DECIMAL(18,2);
    DECLARE @TotalDeposits DECIMAL(18,2);
    DECLARE @LDR DECIMAL(10,4);
    
    -- Liquidity Coverage Ratio (LCR)
    SELECT @HighQualityLiquidAssets = SUM(balance)
    FROM dw.fact_account_daily_snapshot
    WHERE snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
    AND account_type IN ('CASH', 'CENTRAL_BANK', 'GOVERNMENT_BONDS');
    
    SELECT @TotalCashOutflows = SUM(balance) * 0.10  -- Simplified: 10% outflow assumption
    FROM dw.fact_account_daily_snapshot
    WHERE snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
    AND account_type IN ('SAVINGS', 'CURRENT', 'TERM_DEPOSIT');
    
    SET @LCR = @HighQualityLiquidAssets / NULLIF(@TotalCashOutflows, 0) * 100;
    
    -- Loan-to-Deposit Ratio (LDR)
    SELECT @TotalLoans = SUM(outstanding_principal)
    FROM dw.fact_loan_portfolio
    WHERE snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT);
    
    SELECT @TotalDeposits = SUM(balance)
    FROM dw.fact_account_daily_snapshot
    WHERE snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
    AND account_type IN ('SAVINGS', 'CURRENT', 'TERM_DEPOSIT');
    
    SET @LDR = @TotalLoans / NULLIF(@TotalDeposits, 0) * 100;
    
    -- Output results
    SELECT
        @ReportDate AS report_date,
        @HighQualityLiquidAssets AS hqla,
        @TotalCashOutflows AS cash_outflows,
        @LCR AS lcr_ratio,
        CASE WHEN @LCR >= 100 THEN 'COMPLIANT' ELSE 'NON-COMPLIANT' END AS lcr_status,
        @TotalLoans AS total_loans,
        @TotalDeposits AS total_deposits,
        @LDR AS ldr_ratio,
        CASE WHEN @LDR <= 90 THEN 'COMPLIANT' ELSE 'WARNING' END AS ldr_status;
END;
GO
```

---

## 6. Prudential Returns

```sql
-- ============================================================
-- LOAN CLASSIFICATION & PROVISIONING
-- ============================================================

CREATE PROCEDURE regulatory.usp_LoanClassification
    @ReportDate DATE
AS
BEGIN
    SELECT
        risk_classification,
        COUNT(*) AS loan_count,
        SUM(outstanding_principal) AS total_outstanding,
        SUM(provision_amount) AS total_provision,
        CAST(SUM(provision_amount) * 100.0 / NULLIF(SUM(outstanding_principal), 0) AS DECIMAL(5,2)) AS provision_coverage
    FROM dw.fact_loan_portfolio
    WHERE snapshot_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
    GROUP BY risk_classification
    ORDER BY 
        CASE risk_classification
            WHEN 'NORMAL' THEN 1
            WHEN 'SPECIAL_MENTION' THEN 2
            WHEN 'SUBSTANDARD' THEN 3
            WHEN 'DOUBTFUL' THEN 4
            WHEN 'LOSS' THEN 5
        END;
END;
GO
```

---

## 7. Report Automation

```sql
-- ============================================================
-- AUTOMATED REGULATORY REPORT GENERATION
-- ============================================================

CREATE PROCEDURE regulatory.usp_GenerateAllReports
    @ReportDate DATE
AS
BEGIN
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
    
    PRINT 'Generating regulatory reports for ' + CONVERT(VARCHAR(10), @ReportDate, 120);
    
    -- 1. CAR Report
    EXEC regulatory.usp_CalculateCAR @ReportDate;
    
    -- 2. Large Exposure Report
    EXEC regulatory.usp_CalculateLargeExposure @ReportDate;
    
    -- 3. Liquidity Report
    EXEC regulatory.usp_LiquidityReport @ReportDate;
    
    -- 4. Loan Classification Report
    EXEC regulatory.usp_LoanClassification @ReportDate;
    
    PRINT 'All regulatory reports generated.';
END;
GO
```

---

*Created: September 2024*
