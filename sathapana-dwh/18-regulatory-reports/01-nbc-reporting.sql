-- ============================================================================
-- SATHAPANA BANK - REGULATORY REPORTING (NBC)
-- ============================================================================
-- Purpose: Create views for National Bank of Cambodia reporting
-- Author: DWH Development Team
-- Reference: NBC Prudential Regulations
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. CAPITAL ADEQUACY REPORT (Basel III)
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_capital_adequacy AS
SELECT 
    -- Risk-Weighted Assets
    SUM(CASE WHEN l.risk_classification = 'STANDARD' THEN l.outstanding_principal * 1.0 ELSE 0 END) AS rwa_standard,
    SUM(CASE WHEN l.risk_classification = 'SPECIAL_MENTION' THEN l.outstanding_principal * 1.5 ELSE 0 END) AS rwa_special_mention,
    SUM(CASE WHEN l.risk_classification = 'SUBSTANDARD' THEN l.outstanding_principal * 2.0 ELSE 0 END) AS rwa_substandard,
    SUM(CASE WHEN l.risk_classification = 'DOUBTFUL' THEN l.outstanding_principal * 2.5 ELSE 0 END) AS rwa_doubtful,
    SUM(CASE WHEN l.risk_classification = 'LOSS' THEN l.outstanding_principal * 4.0 ELSE 0 END) AS rwa_loss,
    -- Total RWA
    SUM(l.outstanding_principal * 
        CASE l.risk_classification
            WHEN 'STANDARD' THEN 1.0
            WHEN 'SPECIAL_MENTION' THEN 1.5
            WHEN 'SUBSTANDARD' THEN 2.0
            WHEN 'DOUBTFUL' THEN 2.5
            WHEN 'LOSS' THEN 4.0
            ELSE 1.0
        END
    ) AS total_rwa,
    -- Total Assets
    (SELECT SUM(balance) FROM sathapana_raw.raw.accounts WHERE account_status = 'ACTIVE') AS total_assets,
    d.full_date AS report_date
FROM dw.fact_loan_portfolio l
JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY d.full_date;

-- ============================================================================
-- 2. LOAN CLASSIFICATION REPORT
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_loan_classification AS
SELECT 
    b.branch_code,
    b.branch_name,
    -- Classification buckets
    SUM(CASE WHEN l.days_past_due = 0 THEN l.outstanding_principal ELSE 0 END) AS current_portfolio,
    SUM(CASE WHEN l.days_past_due BETWEEN 1 AND 30 THEN l.outstanding_principal ELSE 0 END) AS pass_portfolio,
    SUM(CASE WHEN l.days_past_due BETWEEN 31 AND 60 THEN l.outstanding_principal ELSE 0 END) AS watchlist_portfolio,
    SUM(CASE WHEN l.days_past_due BETWEEN 61 AND 90 THEN l.outstanding_principal ELSE 0 END) AS substandard_portfolio,
    SUM(CASE WHEN l.days_past_due BETWEEN 91 AND 180 THEN l.outstanding_principal ELSE 0 END) AS doubtful_portfolio,
    SUM(CASE WHEN l.days_past_due > 180 THEN l.outstanding_principal ELSE 0 END) AS loss_portfolio,
    -- Total
    SUM(l.outstanding_principal) AS total_portfolio,
    -- Ratios
    CASE 
        WHEN SUM(l.outstanding_principal) = 0 THEN 0
        ELSE SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) / SUM(l.outstanding_principal) * 100
    END AS npl_ratio,
    -- Provision coverage
    SUM(l.provision_amount) AS total_provisions,
    d.full_date AS report_date
FROM dw.fact_loan_portfolio l
JOIN dw.dim_branch b ON l.branch_key = b.branch_key
JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY b.branch_code, b.branch_name, d.full_date;

-- ============================================================================
-- 3. DEPOSIT REPORT (NBC Format)
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_deposit_report AS
SELECT 
    d.year_number,
    d.month_number,
    -- Deposit types
    SUM(CASE WHEN p.product_subcategory = 'SAVINGS' THEN s.balance ELSE 0 END) AS savings_deposits,
    SUM(CASE WHEN p.product_subcategory = 'CURRENT' THEN s.balance ELSE 0 END) AS current_deposits,
    SUM(CASE WHEN p.product_subcategory = 'TERM_DEPOSIT' THEN s.balance ELSE 0 END) AS term_deposits,
    -- Total
    SUM(s.balance) AS total_deposits,
    -- Interest
    SUM(s.interest_earned) AS total_interest,
    -- By currency
    SUM(CASE WHEN a.currency = 'USD' THEN s.balance ELSE 0 END) AS usd_deposits,
    SUM(CASE WHEN a.currency = 'KHR' THEN s.balance ELSE 0 END) AS khr_deposits,
    -- Count
    COUNT(DISTINCT s.account_key) AS total_accounts
FROM dw.fact_deposit_snapshot s
JOIN dw.dim_product p ON s.product_key = p.product_key
JOIN dw.dim_account a ON s.account_key = a.account_key
JOIN dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY d.year_number, d.month_number;

-- ============================================================================
-- 4. LIQUIDITY REPORT
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_liquidity_report AS
SELECT 
    d.full_date,
    -- Liquid Assets
    (SELECT SUM(balance) FROM sathapana_raw.raw.accounts 
     WHERE account_type IN ('SAVINGS', 'CURRENT') AND account_status = 'ACTIVE') AS liquid_assets,
    -- Total Deposits
    SUM(s.balance) AS total_deposits,
    -- Loans
    (SELECT SUM(outstanding_principal) FROM dw.fact_loan_portfolio 
     WHERE snapshot_date_key = d.date_key) AS total_loans,
    -- LDR Ratio
    CASE 
        WHEN SUM(s.balance) = 0 THEN 0
        ELSE (SELECT SUM(outstanding_principal) FROM dw.fact_loan_portfolio 
              WHERE snapshot_date_key = d.date_key) / SUM(s.balance) * 100
    END AS ldr_ratio,
    -- Liquidity Ratio
    CASE 
        WHEN SUM(s.balance) = 0 THEN 0
        ELSE (SELECT SUM(balance) FROM sathapana_raw.raw.accounts 
              WHERE account_type IN ('SAVINGS', 'CURRENT') AND account_status = 'ACTIVE') / SUM(s.balance) * 100
    END AS liquidity_ratio
FROM dw.fact_deposit_snapshot s
JOIN dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY d.full_date, d.date_key;

-- ============================================================================
-- 5. LARGE EXPOSURE REPORT
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_large_exposure AS
SELECT 
    c.customer_code,
    c.full_name,
    c.customer_type,
    c.customer_segment,
    -- Exposure
    SUM(l.outstanding_principal) AS total_exposure,
    -- By product
    SUM(CASE WHEN p.product_category = 'LOAN' THEN l.outstanding_principal ELSE 0 END) AS loan_exposure,
    -- Limit check (15% of capital - simplified)
    SUM(l.outstanding_principal) / NULLIF(
        (SELECT SUM(balance) FROM sathapana_raw.raw.accounts WHERE account_type = 'CURRENT'), 0
    ) * 100 AS exposure_ratio,
    -- Risk rating
    c.risk_rating,
    -- Classification
    CASE 
        WHEN SUM(l.outstanding_principal) / NULLIF(
            (SELECT SUM(balance) FROM sathapana_raw.raw.accounts WHERE account_type = 'CURRENT'), 0
        ) * 100 > 15 THEN 'EXCEEDS_LIMIT'
        WHEN SUM(l.outstanding_principal) / NULLIF(
            (SELECT SUM(balance) FROM sathapana_raw.raw.accounts WHERE account_type = 'CURRENT'), 0
        ) * 100 > 10 THEN 'NEAR_LIMIT'
        ELSE 'WITHIN_LIMIT'
    END AS limit_status,
    d.full_date AS report_date
FROM dw.fact_loan_portfolio l
JOIN dw.dim_customer c ON l.customer_key = c.customer_key
JOIN dw.dim_product p ON l.product_key = p.product_key
JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY c.customer_code, c.full_name, c.customer_type, c.customer_segment, c.risk_rating, d.full_date
HAVING SUM(l.outstanding_principal) > 10000;  -- Only show significant exposures

-- ============================================================================
-- 6. INTEREST RATE RISK REPORT
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_interest_rate_risk AS
SELECT 
    -- Fixed rate assets
    SUM(CASE WHEN a.interest_rate > 0 THEN s.balance ELSE 0 END) AS fixed_rate_assets,
    -- Variable rate assets
    SUM(CASE WHEN a.interest_rate = 0 THEN s.balance ELSE 0 END) AS variable_rate_assets,
    -- Total
    SUM(s.balance) AS total_assets,
    -- Average rate
    SUM(a.interest_rate * s.balance) / NULLIF(SUM(s.balance), 0) AS weighted_avg_rate,
    -- Gap
    SUM(CASE WHEN a.interest_rate > 0 THEN s.balance ELSE 0 END) - 
    SUM(CASE WHEN a.interest_rate = 0 THEN s.balance ELSE 0 END) AS rate_gap,
    d.full_date AS report_date
FROM dw.fact_deposit_snapshot s
JOIN dw.dim_account a ON s.account_key = a.account_key
JOIN dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY d.full_date;

-- ============================================================================
-- 7. AML/CFT REPORT
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_aml_cft_report AS
SELECT 
    d.year_number,
    d.month_number,
    -- Transaction monitoring
    COUNT(t.transaction_key) AS total_transactions,
    SUM(CASE WHEN t.amount > 10000 THEN 1 ELSE 0 END) AS high_value_transactions,
    SUM(CASE WHEN t.amount BETWEEN 9000 AND 10000 THEN 1 ELSE 0 END) AS structuring_suspects,
    -- Alerts
    (SELECT COUNT(*) FROM sathapana_raw.raw.aml_alerts 
     WHERE created_date BETWEEN d.full_date AND DATEADD(DAY, 1, d.full_date)) AS alerts_generated,
    -- SARs
    (SELECT COUNT(*) FROM sathapana_raw.raw.aml_alerts 
     WHERE status = 'SAR_FILED' 
     AND created_date BETWEEN d.full_date AND DATEADD(DAY, 1, d.full_date)) AS sars_filed,
    -- CTR (Currency Transaction Report - transactions > $10,000)
    SUM(CASE WHEN t.amount > 10000 THEN 1 ELSE 0 END) AS ctr_required,
    d.full_date AS report_date
FROM dw.fact_transactions t
JOIN dw.dim_date d ON t.transaction_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY d.year_number, d.month_number, d.full_date;

-- ============================================================================
-- 8. BRANCH REPORTING SUMMARY
-- ============================================================================
CREATE OR ALTER VIEW dw.vw_branch_regulatory_summary AS
SELECT 
    b.branch_code,
    b.branch_name,
    b.province,
    -- Customer metrics
    COUNT(DISTINCT c.customer_key) AS total_customers,
    SUM(CASE WHEN c.kyc_status = 'VERIFIED' THEN 1 ELSE 0 END) AS kyc_verified,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    -- Deposit metrics
    SUM(CASE WHEN a.account_type IN ('SAVINGS', 'CURRENT', 'TERM_DEPOSIT') THEN s.balance ELSE 0 END) AS total_deposits,
    -- Loan metrics
    SUM(l.outstanding_principal) AS total_loans,
    SUM(l.provision_amount) AS total_provisions,
    -- Risk metrics
    CASE 
        WHEN SUM(l.outstanding_principal) = 0 THEN 0
        ELSE SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) / SUM(l.outstanding_principal) * 100
    END AS npl_ratio,
    d.full_date AS report_date
FROM dw.dim_branch b
LEFT JOIN dw.dim_customer c ON b.branch_key = c.opening_branch_key AND c.is_current = 1
LEFT JOIN dw.dim_account a ON b.branch_key = a.branch_key AND a.is_current = 1
LEFT JOIN dw.fact_deposit_snapshot s ON a.account_key = s.account_key
LEFT JOIN dw.fact_loan_portfolio l ON b.branch_key = l.branch_key
LEFT JOIN dw.dim_date d ON s.snapshot_date_key = d.date_key OR l.snapshot_date_key = d.date_key
WHERE b.is_active = 1 AND d.is_current_month = 1
GROUP BY b.branch_code, b.branch_name, b.province, d.full_date;

-- ============================================================================
-- 9. MONTHLY REGULATORY PACKAGE
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_GenerateRegulatoryPackage
    @ReportMonth INT = NULL,
    @ReportYear INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to previous month
    IF @ReportMonth IS NULL SET @ReportMonth = MONTH(DATEADD(MONTH, -1, GETDATE()));
    IF @ReportYear IS NULL SET @ReportYear = YEAR(DATEADD(MONTH, -1, GETDATE()));
    
    PRINT '========================================';
    PRINT 'NBC REGULATORY PACKAGE';
    PRINT 'Period: ' + CAST(@ReportMonth AS VARCHAR) + '/' + CAST(@ReportYear AS VARCHAR);
    PRINT '========================================';
    
    PRINT '';
    PRINT '1. CAPITAL ADEQUACY';
    SELECT * FROM dw.vw_capital_adequacy;
    
    PRINT '';
    PRINT '2. LOAN CLASSIFICATION';
    SELECT * FROM dw.vw_loan_classification;
    
    PRINT '';
    PRINT '3. DEPOSIT REPORT';
    SELECT * FROM dw.vw_deposit_report 
    WHERE year_number = @ReportYear AND month_number = @ReportMonth;
    
    PRINT '';
    PRINT '4. LIQUIDITY REPORT';
    SELECT * FROM dw.vw_liquidity_report;
    
    PRINT '';
    PRINT '5. LARGE EXPOSURE';
    SELECT TOP 20 * FROM dw.vw_large_exposure;
    
    PRINT '';
    PRINT '6. AML/CFT REPORT';
    SELECT * FROM dw.vw_aml_cft_report 
    WHERE year_number = @ReportYear AND month_number = @ReportMonth;
    
    PRINT '';
    PRINT '========================================';
    PRINT 'END OF REGULATORY PACKAGE';
    PRINT '========================================';
END;
GO

-- ============================================================================
-- 10. VERIFY SETUP
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'REGULATORY REPORTING VIEWS CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Views:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE name LIKE 'vw_%';
PRINT '';
PRINT 'NBC Reports Available:';
PRINT '  1. vw_capital_adequacy - Basel III capital requirements';
PRINT '  2. vw_loan_classification - Loan quality classification';
PRINT '  3. vw_deposit_report - Deposit composition';
PRINT '  4. vw_liquidity_report - Liquidity ratios';
PRINT '  5. vw_large_exposure - Concentration risk';
PRINT '  6. vw_interest_rate_risk - IRR analysis';
PRINT '  7. vw_aml_cft_report - AML/CFT compliance';
PRINT '  8. vw_branch_regulatory_summary - Branch-level summary';
PRINT '';
PRINT 'To generate monthly package:';
PRINT '  EXEC dw.usp_GenerateRegulatoryPackage;';
PRINT '';
PRINT '================================================';
GO
