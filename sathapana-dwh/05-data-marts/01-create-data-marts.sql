-- ============================================================================
-- SATHAPANA BANK - DATA MARTS CREATION
-- ============================================================================
-- Purpose: Create specialized data marts for different business areas
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

-- ============================================================================
-- 1. CREDIT RISK DATA MART
-- ============================================================================
USE sathapana_dwh;
GO

-- Create schema for credit risk data mart
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm_credit')
    EXEC('CREATE SCHEMA dm_credit');
GO

-- ============================================================================
-- 1.1 CREDIT RISK SUMMARY VIEW
-- ============================================================================
CREATE VIEW dm_credit.vw_credit_risk_summary AS
SELECT 
    b.branch_code,
    b.branch_name,
    b.region,
    p.product_category,
    p.product_name,
    -- Portfolio metrics
    COUNT(*) AS total_loans,
    SUM(l.loan_amount) AS total_disbursed,
    SUM(l.outstanding_principal) AS total_outstanding,
    AVG(l.interest_rate) AS avg_interest_rate,
    AVG(l.term_months) AS avg_term_months,
    -- Risk metrics
    SUM(CASE WHEN l.days_past_due = 0 THEN 1 ELSE 0 END) AS performing_loans,
    SUM(CASE WHEN l.days_past_due BETWEEN 1 AND 30 THEN 1 ELSE 0 END) AS dpd_1_30,
    SUM(CASE WHEN l.days_past_due BETWEEN 31 AND 60 THEN 1 ELSE 0 END) AS dpd_31_60,
    SUM(CASE WHEN l.days_past_due BETWEEN 61 AND 90 THEN 1 ELSE 0 END) AS dpd_61_90,
    SUM(CASE WHEN l.days_past_due > 90 THEN 1 ELSE 0 END) AS npl_count,
    -- Risk classification
    SUM(CASE WHEN l.risk_classification = 'STANDARD' THEN 1 ELSE 0 END) AS standard_count,
    SUM(CASE WHEN l.risk_classification = 'SPECIAL_MENTION' THEN 1 ELSE 0 END) AS special_mention_count,
    SUM(CASE WHEN l.risk_classification = 'SUBSTANDARD' THEN 1 ELSE 0 END) AS substandard_count,
    SUM(CASE WHEN l.risk_classification = 'DOUBTFUL' THEN 1 ELSE 0 END) AS doubtful_count,
    SUM(CASE WHEN l.risk_classification = 'LOSS' THEN 1 ELSE 0 END) AS loss_count,
    -- Amounts by risk classification
    SUM(CASE WHEN l.risk_classification = 'STANDARD' THEN l.outstanding_principal ELSE 0 END) AS standard_amount,
    SUM(CASE WHEN l.risk_classification = 'SPECIAL_MENTION' THEN l.outstanding_principal ELSE 0 END) AS special_mention_amount,
    SUM(CASE WHEN l.risk_classification = 'SUBSTANDARD' THEN l.outstanding_principal ELSE 0 END) AS substandard_amount,
    SUM(CASE WHEN l.risk_classification = 'DOUBTFUL' THEN l.outstanding_principal ELSE 0 END) AS doubtful_amount,
    SUM(CASE WHEN l.risk_classification = 'LOSS' THEN l.outstanding_principal ELSE 0 END) AS loss_amount,
    -- Provisioning
    SUM(l.provision_amount) AS total_provisions,
    AVG(l.provision_amount / NULLIF(l.outstanding_principal, 0) * 100) AS avg_provision_rate,
    -- NPL Ratio
    CASE 
        WHEN SUM(l.outstanding_principal) = 0 THEN 0
        ELSE SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) / SUM(l.outstanding_principal) * 100
    END AS npl_ratio,
    -- Date
    d.full_date AS snapshot_date
FROM dw.fact_loan_portfolio l
JOIN dw.dim_branch b ON l.branch_key = b.branch_key
JOIN dw.dim_product p ON l.product_key = p.product_key
JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE b.is_active = 1
GROUP BY 
    b.branch_code, b.branch_name, b.region,
    p.product_category, p.product_name,
    d.full_date;

-- ============================================================================
-- 1.2 LOAN MATURITY VIEW
-- ============================================================================
CREATE VIEW dm_credit.vw_loan_maturity_profile AS
SELECT 
    b.branch_code,
    b.branch_name,
    p.product_category,
    -- Maturity buckets
    SUM(CASE WHEN l.maturity_date <= DATEADD(MONTH, 3, GETDATE()) THEN 1 ELSE 0 END) AS mat_0_3m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 3, GETDATE()) AND DATEADD(MONTH, 6, GETDATE()) THEN 1 ELSE 0 END) AS mat_3_6m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 6, GETDATE()) AND DATEADD(MONTH, 12, GETDATE()) THEN 1 ELSE 0 END) AS mat_6_12m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 12, GETDATE()) AND DATEADD(MONTH, 24, GETDATE()) THEN 1 ELSE 0 END) AS mat_12_24m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 24, GETDATE()) AND DATEADD(MONTH, 60, GETDATE()) THEN 1 ELSE 0 END) AS mat_24_60m,
    SUM(CASE WHEN l.maturity_date > DATEADD(MONTH, 60, GETDATE()) THEN 1 ELSE 0 END) AS mat_60m_plus,
    -- Amounts
    SUM(CASE WHEN l.maturity_date <= DATEADD(MONTH, 3, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_amt_0_3m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 3, GETDATE()) AND DATEADD(MONTH, 6, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_amt_3_6m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 6, GETDATE()) AND DATEADD(MONTH, 12, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_amt_6_12m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 12, GETDATE()) AND DATEADD(MONTH, 24, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_amt_12_24m,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 24, GETDATE()) AND DATEADD(MONTH, 60, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_amt_24_60m,
    SUM(CASE WHEN l.maturity_date > DATEADD(MONTH, 60, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_amt_60m_plus,
    d.full_date AS snapshot_date
FROM dw.fact_loan_portfolio l
JOIN dw.dim_branch b ON l.branch_key = b.branch_key
JOIN dw.dim_product p ON l.product_key = p.product_key
JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, p.product_category, d.full_date;

-- ============================================================================
-- 1.3 PROVISIONING SUMMARY VIEW
-- ============================================================================
CREATE VIEW dm_credit.vw_provisioning_summary AS
SELECT 
    b.branch_code,
    b.branch_name,
    l.risk_classification,
    COUNT(*) AS loan_count,
    SUM(l.outstanding_principal) AS outstanding_amount,
    SUM(l.provision_amount) AS provision_amount,
    AVG(l.provision_amount / NULLIF(l.outstanding_principal, 0) * 100) AS avg_provision_rate,
    -- Required provisioning rates (Basel III)
    CASE l.risk_classification
        WHEN 'STANDARD' THEN 1.0
        WHEN 'SPECIAL_MENTION' THEN 3.0
        WHEN 'SUBSTANDARD' THEN 20.0
        WHEN 'DOUBTFUL' THEN 50.0
        WHEN 'LOSS' THEN 100.0
    END AS required_provision_rate,
    -- Provision gap
    SUM(l.provision_amount) - SUM(l.outstanding_principal) * 
        CASE l.risk_classification
            WHEN 'STANDARD' THEN 0.01
            WHEN 'SPECIAL_MENTION' THEN 0.03
            WHEN 'SUBSTANDARD' THEN 0.20
            WHEN 'DOUBTFUL' THEN 0.50
            WHEN 'LOSS' THEN 1.00
        END AS provision_gap,
    d.full_date AS snapshot_date
FROM dw.fact_loan_portfolio l
JOIN dw.dim_branch b ON l.branch_key = b.branch_key
JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, l.risk_classification, d.full_date;

-- ============================================================================
-- 2. CUSTOMER ANALYTICS DATA MART
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm_customer')
    EXEC('CREATE SCHEMA dm_customer');
GO

-- ============================================================================
-- 2.1 CUSTOMER SEGMENTATION VIEW
-- ============================================================================
CREATE VIEW dm_customer.vw_customer_segmentation AS
SELECT 
    c.customer_segment,
    c.risk_rating,
    c.province,
    c.gender,
    -- Customer counts
    COUNT(DISTINCT c.customer_key) AS customer_count,
    SUM(CASE WHEN c.is_active = 1 THEN 1 ELSE 0 END) AS active_customers,
    -- Demographics
    AVG(c.age) AS avg_age,
    AVG(c.annual_income) AS avg_income,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    AVG(CASE WHEN a.is_current = 1 THEN 1.0 ELSE 0 END) AS avg_accounts_per_customer,
    -- Product penetration
    COUNT(DISTINCT CASE WHEN p.product_category = 'DEPOSIT' THEN a.account_key END) AS deposit_accounts,
    COUNT(DISTINCT CASE WHEN p.product_category = 'LOAN' THEN a.account_key END) AS loan_accounts,
    COUNT(DISTINCT CASE WHEN p.product_category = 'CARD' THEN a.account_key END) AS card_accounts,
    -- KYC status
    SUM(CASE WHEN c.kyc_status = 'VERIFIED' THEN 1 ELSE 0 END) AS kyc_verified,
    SUM(CASE WHEN c.kyc_status = 'PENDING' THEN 1 ELSE 0 END) AS kyc_pending,
    SUM(CASE WHEN c.kyc_status = 'EXPIRED' THEN 1 ELSE 0 END) AS kyc_expired,
    -- Risk flags
    SUM(CASE WHEN c.is_pep = 1 THEN 1 ELSE 0 END) AS pep_count,
    SUM(CASE WHEN c.is_sanctioned = 1 THEN 1 ELSE 0 END) AS sanctioned_count
FROM dw.dim_customer c
LEFT JOIN dw.dim_account a ON c.customer_key = a.customer_key
LEFT JOIN dw.dim_product p ON a.product_key = p.product_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_segment, c.risk_rating, c.province, c.gender;

-- ============================================================================
-- 2.2 CUSTOMER PROFITABILITY VIEW
-- ============================================================================
CREATE VIEW dm_customer.vw_customer_profitability AS
SELECT 
    c.customer_key,
    c.customer_code,
    c.full_name,
    c.customer_segment,
    c.province,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    SUM(CASE WHEN a.is_current = 1 THEN 1 ELSE 0 END) AS active_accounts,
    -- Balance metrics (from daily snapshots)
    AVG(s.closing_balance) AS avg_balance,
    MAX(s.closing_balance) AS max_balance,
    MIN(s.closing_balance) AS min_balance,
    -- Transaction metrics
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_transaction_volume,
    SUM(t.fee_amount) AS total_fees_collected,
    SUM(t.tax_amount) AS total_tax_collected,
    -- Revenue metrics
    SUM(t.fee_amount) + SUM(t.tax_amount) AS total_revenue,
    -- Profitability ratio
    CASE 
        WHEN AVG(s.closing_balance) = 0 THEN 0
        ELSE (SUM(t.fee_amount) + SUM(t.tax_amount)) / AVG(s.closing_balance) * 100
    END AS revenue_to_balance_ratio
FROM dw.dim_customer c
LEFT JOIN dw.dim_account a ON c.customer_key = a.customer_key AND a.is_current = 1
LEFT JOIN dw.fact_account_daily_snapshot s ON a.account_key = s.account_key
LEFT JOIN dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_key, c.customer_code, c.full_name, c.customer_segment, c.province;

-- ============================================================================
-- 2.3 CUSTOMER LIFECYCLE VIEW
-- ============================================================================
CREATE VIEW dm_customer.vw_customer_lifecycle AS
SELECT 
    c.customer_key,
    c.customer_code,
    c.full_name,
    c.customer_type,
    c.customer_segment,
    c.acquisition_channel,
    c.created_date AS acquisition_date,
    DATEDIFF(MONTH, c.created_date, GETDATE()) AS customer_tenure_months,
    -- Lifecycle stages
    CASE 
        WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) <= 3 THEN 'NEW'
        WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) <= 12 THEN 'GROWING'
        WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) <= 36 THEN 'MATURE'
        ELSE 'VETERAN'
    END AS lifecycle_stage,
    -- Activity metrics
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    MAX(t.transaction_datetime) AS last_transaction_date,
    DATEDIFF(DAY, MAX(t.transaction_datetime), GETDATE()) AS days_since_last_transaction,
    -- Product holding
    COUNT(DISTINCT a.account_key) AS total_accounts,
    -- Tenure bucket
    CASE 
        WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) <= 6 THEN '0-6 Months'
        WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) <= 12 THEN '6-12 Months'
        WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) <= 24 THEN '1-2 Years'
        WHEN DATEDIFF(MONTH, c.created_date, GETDATE()) <= 60 THEN '2-5 Years'
        ELSE '5+ Years'
    END AS tenure_bucket
FROM dw.dim_customer c
LEFT JOIN dw.dim_account a ON c.customer_key = a.customer_key
LEFT JOIN dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_key, c.customer_code, c.full_name, c.customer_type,
    c.customer_segment, c.acquisition_channel, c.created_date;

-- ============================================================================
-- 3. TREASURY DATA MART
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm_treasury')
    EXEC('CREATE SCHEMA dm_treasury');
GO

-- ============================================================================
-- 3.1 FX PERFORMANCE VIEW
-- ============================================================================
CREATE VIEW dm_treasury.vw_fx_performance AS
SELECT 
    b.branch_code,
    b.branch_name,
    sc.currency_code AS source_currency,
    tc.currency_code AS target_currency,
    -- Transaction counts
    COUNT(*) AS total_fx_transactions,
    SUM(CASE WHEN fx.transaction_type = 'BUY' THEN 1 ELSE 0 END) AS buy_transactions,
    SUM(CASE WHEN fx.transaction_type = 'SELL' THEN 1 ELSE 0 END) AS sell_transactions,
    -- Amounts
    SUM(fx.source_amount) AS total_source_amount,
    SUM(fx.target_amount) AS total_target_amount,
    SUM(CASE WHEN fx.transaction_type = 'BUY' THEN fx.source_amount ELSE 0 END) AS total_buy_amount,
    SUM(CASE WHEN fx.transaction_type = 'SELL' THEN fx.source_amount ELSE 0 END) AS total_sell_amount,
    -- Spread and profit
    AVG(fx.spread) AS avg_spread,
    SUM(fx.profit_amount) AS total_profit,
    AVG(fx.exchange_rate) AS avg_exchange_rate,
    -- Date
    d.full_date AS transaction_date
FROM dw.fact_fx_transactions fx
JOIN dw.dim_branch b ON fx.branch_key = b.branch_key
JOIN dw.dim_currency sc ON fx.source_currency_key = sc.currency_key
JOIN dw.dim_currency tc ON fx.target_currency_key = tc.currency_key
JOIN dw.dim_date d ON fx.transaction_date_key = d.date_key
GROUP BY 
    b.branch_code, b.branch_name,
    sc.currency_code, tc.currency_code,
    d.full_date;

-- ============================================================================
-- 3.2 DEPOSIT MOBILIZATION VIEW
-- ============================================================================
CREATE VIEW dm_treasury.vw_deposit_mobilization AS
SELECT 
    b.branch_code,
    b.branch_name,
    p.product_category,
    p.product_name,
    d.year_number,
    d.month_number,
    d.month_name,
    -- Balance metrics
    SUM(s.balance) AS total_balance,
    AVG(s.balance) AS avg_balance,
    MAX(s.balance) AS max_balance,
    -- Interest metrics
    SUM(s.interest_earned) AS total_interest_earned,
    SUM(s.interest_accrued) AS total_interest_accrued,
    AVG(s.interest_rate) AS avg_interest_rate,
    -- Product mix
    COUNT(DISTINCT s.account_key) AS total_accounts,
    SUM(s.balance) / NULLIF(SUM(SUM(s.balance)) OVER (PARTITION BY b.branch_code, d.year_number, d.month_number), 0) * 100 AS balance_share_pct
FROM dw.fact_deposit_snapshot s
JOIN dw.dim_branch b ON s.branch_key = b.branch_key
JOIN dw.dim_product p ON s.product_key = p.product_key
JOIN dw.dim_date d ON s.snapshot_date_key = d.date_key
GROUP BY 
    b.branch_code, b.branch_name,
    p.product_category, p.product_name,
    d.year_number, d.month_number, d.month_name;

-- ============================================================================
-- 3.3 INTEREST RATE SENSITIVITY VIEW
-- ============================================================================
CREATE VIEW dm_treasury.vw_interest_rate_sensitivity AS
SELECT 
    p.product_category,
    p.product_name,
    -- Rate buckets
    SUM(CASE WHEN p.interest_rate < 5 THEN 1 ELSE 0 END) AS rate_below_5,
    SUM(CASE WHEN p.interest_rate BETWEEN 5 AND 10 THEN 1 ELSE 0 END) AS rate_5_to_10,
    SUM(CASE WHEN p.interest_rate BETWEEN 10 AND 15 THEN 1 ELSE 0 END) AS rate_10_to_15,
    SUM(CASE WHEN p.interest_rate > 15 THEN 1 ELSE 0 END) AS rate_above_15,
    -- Amounts
    SUM(CASE WHEN p.interest_rate < 5 THEN s.balance ELSE 0 END) AS balance_below_5,
    SUM(CASE WHEN p.interest_rate BETWEEN 5 AND 10 THEN s.balance ELSE 0 END) AS balance_5_to_10,
    SUM(CASE WHEN p.interest_rate BETWEEN 10 AND 15 THEN s.balance ELSE 0 END) AS balance_10_to_15,
    SUM(CASE WHEN p.interest_rate > 15 THEN s.balance ELSE 0 END) AS balance_above_15,
    -- Weighted average rate
    SUM(p.interest_rate * s.balance) / NULLIF(SUM(s.balance), 0) AS weighted_avg_rate,
    d.full_date AS snapshot_date
FROM dw.fact_deposit_snapshot s
JOIN dw.dim_product p ON s.product_key = p.product_key
JOIN dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    p.product_category, p.product_name, d.full_date;

-- ============================================================================
-- 4. COMPLIANCE/AML DATA MART
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm_compliance')
    EXEC('CREATE SCHEMA dm_compliance');
GO

-- ============================================================================
-- 4.1 AML ALERT SUMMARY VIEW
-- ============================================================================
CREATE VIEW dm_compliance.vw_aml_alert_summary AS
SELECT 
    -- Alert metrics
    COUNT(*) AS total_alerts,
    SUM(CASE WHEN a.status = 'NEW' THEN 1 ELSE 0 END) AS new_alerts,
    SUM(CASE WHEN a.status = 'UNDER_REVIEW' THEN 1 ELSE 0 END) AS under_review,
    SUM(CASE WHEN a.status = 'ESCALATED' THEN 1 ELSE 0 END) AS escalated,
    SUM(CASE WHEN a.status = 'CLOSED_FALSE_POSITIVE' THEN 1 ELSE 0 END) AS false_positives,
    SUM(CASE WHEN a.status = 'SAR_FILED' THEN 1 ELSE 0 END) AS sar_filed,
    -- Risk scores
    AVG(a.risk_score) AS avg_risk_score,
    MAX(a.risk_score) AS max_risk_score,
    SUM(CASE WHEN a.risk_score >= 70 THEN 1 ELSE 0 END) AS high_risk_alerts,
    -- By alert type
    SUM(CASE WHEN a.alert_type = 'STRUCTURING' THEN 1 ELSE 0 END) AS structuring_alerts,
    SUM(CASE WHEN a.alert_type = 'UNUSUAL_PATTERN' THEN 1 ELSE 0 END) AS unusual_pattern_alerts,
    SUM(CASE WHEN a.alert_type = 'HIGH_VALUE' THEN 1 ELSE 0 END) AS high_value_alerts,
    SUM(CASE WHEN a.alert_type = 'SANCTIONS_MATCH' THEN 1 ELSE 0 END) AS sanctions_alerts,
    SUM(CASE WHEN a.alert_type = 'PEP_TRANSACTION' THEN 1 ELSE 0 END) AS pep_alerts,
    SUM(CASE WHEN a.alert_type = 'VEHICLE' THEN 1 ELSE 0 END) AS vehicle_alerts,
    -- Resolution time
    AVG(DATEDIFF(DAY, a.created_date, a.review_date)) AS avg_resolution_days,
    MAX(DATEDIFF(DAY, a.created_date, a.review_date)) AS max_resolution_days
FROM sathapana_source.oltp.aml_alerts a;

-- ============================================================================
-- 4.2 TRANSACTION MONITORING VIEW
-- ============================================================================
CREATE VIEW dm_compliance.vw_transaction_monitoring AS
SELECT 
    c.customer_code,
    c.full_name,
    c.customer_segment,
    c.risk_rating,
    c.is_pep,
    c.is_sanctioned,
    -- Transaction metrics
    COUNT(*) AS total_transactions,
    SUM(t.amount) AS total_volume,
    AVG(t.amount) AS avg_transaction_amount,
    MAX(t.amount) AS max_transaction_amount,
    -- High value transactions
    SUM(CASE WHEN t.amount > 10000 THEN 1 ELSE 0 END) AS high_value_count,
    SUM(CASE WHEN t.amount > 10000 THEN t.amount ELSE 0 END) AS high_value_volume,
    -- Structuring indicators
    SUM(CASE WHEN t.amount BETWEEN 9000 AND 10000 THEN 1 ELSE 0 END) AS near_threshold_count,
    -- Daily patterns
    COUNT(DISTINCT CAST(t.transaction_datetime AS DATE)) AS active_days,
    COUNT(*) / NULLIF(COUNT(DISTINCT CAST(t.transaction_datetime AS DATE)), 0) AS avg_daily_transactions,
    -- Cash activity
    SUM(CASE WHEN t.transaction_channel IN ('COUNTER', 'ATM') THEN t.amount ELSE 0 END) AS cash_volume,
    SUM(CASE WHEN t.transaction_channel IN ('COUNTER', 'ATM') THEN 1 ELSE 0 END) AS cash_transactions,
    -- Digital activity
    SUM(CASE WHEN t.transaction_channel IN ('MOBILE', 'INTERNET') THEN t.amount ELSE 0 END) AS digital_volume,
    SUM(CASE WHEN t.transaction_channel IN ('MOBILE', 'INTERNET') THEN 1 ELSE 0 END) AS digital_transactions
FROM dw.dim_customer c
JOIN dw.dim_account a ON c.customer_key = a.customer_key
JOIN dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_code, c.full_name, c.customer_segment,
    c.risk_rating, c.is_pep, c.is_sanctioned;

-- ============================================================================
-- 4.3 PEP MONITORING VIEW
-- ============================================================================
CREATE VIEW dm_compliance.vw_pep_monitoring AS
SELECT 
    c.customer_code,
    c.full_name,
    c.customer_type,
    c.customer_segment,
    c.occupation,
    c.employer_name,
    -- Account information
    COUNT(DISTINCT a.account_key) AS total_accounts,
    -- Transaction activity
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_volume,
    AVG(t.amount) AS avg_transaction,
    MAX(t.amount) AS max_transaction,
    -- Recent activity
    MAX(t.transaction_datetime) AS last_transaction_date,
    DATEDIFF(DAY, MAX(t.transaction_datetime), GETDATE()) AS days_since_last_transaction,
    -- Risk indicators
    SUM(CASE WHEN t.amount > 50000 THEN 1 ELSE 0 END) AS very_high_value_count,
    SUM(CASE WHEN t.transaction_channel = 'SWIFT' THEN 1 ELSE 0 END) AS swift_count,
    SUM(CASE WHEN t.counterparty_bank NOT LIKE '%SATHAPANA%' THEN 1 ELSE 0 END) AS external_bank_count
FROM dw.dim_customer c
JOIN dw.dim_account a ON c.customer_key = a.customer_key
JOIN dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1 AND c.is_pep = 1
GROUP BY 
    c.customer_code, c.full_name, c.customer_type,
    c.customer_segment, c.occupation, c.employer_name;

-- ============================================================================
-- 5. VERIFY DATA MARTS CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'SATHAPANA BANK - DATA MARTS CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Credit Risk Data Mart Views:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm_credit');
PRINT '';
PRINT 'Customer Analytics Data Mart Views:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm_customer');
PRINT '';
PRINT 'Treasury Data Mart Views:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm_treasury');
PRINT '';
PRINT 'Compliance/AML Data Mart Views:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm_compliance');
PRINT '';
PRINT '================================================';
PRINT 'ALL DATA MARTS CREATED SUCCESSFULLY';
PRINT '================================================';
GO
