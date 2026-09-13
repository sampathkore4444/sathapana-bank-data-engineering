-- ============================================================================
-- SATHAPANA BANK - LAYER 3: ALM (ASSET LIABILITY MANAGEMENT) DATA MART
-- ============================================================================
-- Database: sathapana_dm_alm
-- Purpose: ALM analytics, liquidity risk, interest rate risk
-- Author: DWH Development Team
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_dm_alm')
BEGIN
    ALTER DATABASE sathapana_dm_alm SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_dm_alm;
END
GO

CREATE DATABASE sathapana_dm_alm
ON PRIMARY (
    NAME = 'sathapana_dm_alm_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_alm_dat.mdf',
    SIZE = 100MB, MAXSIZE = 5GB, FILEGROWTH = 50MB
)
LOG ON (
    NAME = 'sathapana_dm_alm_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_alm_log.ldf',
    SIZE = 50MB, MAXSIZE = 2GB, FILEGROWTH = 25MB
);
GO

USE sathapana_dm_alm;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm')
    EXEC('CREATE SCHEMA dm');
GO

-- ============================================================================
-- 1. LIQUIDITY GAP ANALYSIS VIEW
-- ============================================================================
CREATE VIEW dm.vw_liquidity_gap_analysis AS
SELECT 
    b.branch_code,
    b.branch_name,
    -- Asset buckets
    SUM(CASE WHEN a.account_type = 'SAVINGS' THEN s.balance ELSE 0 END) AS savings_balance,
    SUM(CASE WHEN a.account_type = 'CURRENT' THEN s.balance ELSE 0 END) AS current_balance,
    SUM(CASE WHEN a.account_type = 'TERM_DEPOSIT' AND a.maturity_date <= DATEADD(MONTH, 3, GETDATE()) THEN s.balance ELSE 0 END) AS td_0_3m,
    SUM(CASE WHEN a.account_type = 'TERM_DEPOSIT' AND a.maturity_date BETWEEN DATEADD(MONTH, 3, GETDATE()) AND DATEADD(MONTH, 6, GETDATE()) THEN s.balance ELSE 0 END) AS td_3_6m,
    SUM(CASE WHEN a.account_type = 'TERM_DEPOSIT' AND a.maturity_date BETWEEN DATEADD(MONTH, 6, GETDATE()) AND DATEADD(MONTH, 12, GETDATE()) THEN s.balance ELSE 0 END) AS td_6_12m,
    SUM(CASE WHEN a.account_type = 'TERM_DEPOSIT' AND a.maturity_date > DATEADD(MONTH, 12, GETDATE()) THEN s.balance ELSE 0 END) AS td_12m_plus,
    -- Total deposits
    SUM(s.balance) AS total_deposits,
    -- Liquidity position
    (SUM(CASE WHEN a.account_type = 'SAVINGS' THEN s.balance ELSE 0 END) + 
     SUM(CASE WHEN a.account_type = 'CURRENT' THEN s.balance ELSE 0 END)) AS liquid_deposits,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_account a ON s.account_key = a.account_key
JOIN sathapana_dwh.dw.dim_branch b ON s.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY b.branch_code, b.branch_name, d.full_date;

-- ============================================================================
-- 2. INTEREST RATE RISK VIEW
-- ============================================================================
CREATE VIEW dm.vw_interest_rate_risk AS
SELECT 
    p.product_category,
    p.product_name,
    -- Balance by rate bucket
    SUM(CASE WHEN p.interest_rate < 3 THEN s.balance ELSE 0 END) AS balance_rate_0_3,
    SUM(CASE WHEN p.interest_rate BETWEEN 3 AND 5 THEN s.balance ELSE 0 END) AS balance_rate_3_5,
    SUM(CASE WHEN p.interest_rate BETWEEN 5 AND 8 THEN s.balance ELSE 0 END) AS balance_rate_5_8,
    SUM(CASE WHEN p.interest_rate BETWEEN 8 AND 12 THEN s.balance ELSE 0 END) AS balance_rate_8_12,
    SUM(CASE WHEN p.interest_rate > 12 THEN s.balance ELSE 0 END) AS balance_rate_12_plus,
    -- Weighted average rate
    SUM(p.interest_rate * s.balance) / NULLIF(SUM(s.balance), 0) AS weighted_avg_rate,
    -- Total
    SUM(s.balance) AS total_balance,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_product p ON s.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY p.product_category, p.product_name, d.full_date;

-- ============================================================================
-- 3. DEPOSIT STABILITY VIEW
-- ============================================================================
CREATE VIEW dm.vw_deposit_stability AS
SELECT 
    a.account_number,
    c.customer_code,
    c.full_name,
    c.customer_segment,
    -- Stability metrics
    s.balance AS current_balance,
    s.average_monthly_balance,
    CASE 
        WHEN s.average_monthly_balance = 0 THEN 0
        ELSE (s.balance - s.average_monthly_balance) / s.average_monthly_balance * 100
    END AS balance_volatility,
    -- Tenure
    DATEDIFF(MONTH, a.open_date, GETDATE()) AS account_tenure_months,
    -- Stability classification
    CASE 
        WHEN DATEDIFF(MONTH, a.open_date, GETDATE()) > 24 AND s.balance > 1000 THEN 'STABLE'
        WHEN DATEDIFF(MONTH, a.open_date, GETDATE()) > 12 THEN 'MODERATE'
        ELSE 'VOLATILE'
    END AS stability_class,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_account a ON s.account_key = a.account_key
JOIN sathapana_dwh.dw.dim_customer c ON a.customer_key = c.customer_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1 AND a.account_type = 'SAVINGS';

-- ============================================================================
-- 4. FUND TRANSFER PRICING VIEW
-- ============================================================================
CREATE VIEW dm.vw_fund_transfer_pricing AS
SELECT 
    p.product_category,
    p.product_name,
    -- FTP metrics
    SUM(s.balance) AS total_balance,
    AVG(p.interest_rate) AS avg_cost_rate,
    SUM(s.balance * p.interest_rate) / NULLIF(SUM(s.balance), 0) AS weighted_cost_rate,
    -- Spread analysis
    AVG(p.interest_rate) - 2.0 AS estimated_spread,  -- Assuming 2% base rate
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_product p ON s.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY p.product_category, p.product_name, d.full_date;

-- ============================================================================
-- 5. CONCENTRATION RISK VIEW
-- ============================================================================
CREATE VIEW dm.vw_concentration_risk AS
SELECT 
    -- By segment
    c.customer_segment,
    COUNT(DISTINCT c.customer_key) AS customer_count,
    SUM(s.balance) AS total_deposits,
    SUM(s.balance) / NULLIF((SELECT SUM(balance) FROM sathapana_dwh.dw.fact_deposit_snapshot WHERE snapshot_date_key = (SELECT MAX(snapshot_date_key) FROM sathapana_dwh.dw.fact_deposit_snapshot)), 0) * 100 AS deposit_share_pct,
    -- Concentration metrics
    SUM(s.balance) / NULLIF(COUNT(DISTINCT c.customer_key), 0) AS avg_deposit_per_customer,
    -- Top depositor concentration
    SUM(CASE WHEN s.balance > 100000 THEN s.balance ELSE 0 END) AS large_deposits,
    SUM(CASE WHEN s.balance > 100000 THEN s.balance ELSE 0 END) / NULLIF(SUM(s.balance), 0) * 100 AS large_deposit_concentration,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_customer c ON s.customer_key = c.customer_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY c.customer_segment, d.full_date;

-- ============================================================================
-- 6. MATURITY MISMATCH VIEW
-- ============================================================================
CREATE VIEW dm.vw_maturity_mismatch AS
SELECT 
    -- Asset side (Loans)
    'LOANS' AS side,
    '0-3M' AS maturity_bucket,
    SUM(CASE WHEN l.maturity_date <= DATEADD(MONTH, 3, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS amount
FROM sathapana_dwh.dw.fact_loan_portfolio l
UNION ALL
SELECT 'LOANS', '3-6M', SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 3, GETDATE()) AND DATEADD(MONTH, 6, GETDATE()) THEN l.outstanding_principal ELSE 0 END)
FROM sathapana_dwh.dw.fact_loan_portfolio l
UNION ALL
SELECT 'LOANS', '6-12M', SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 6, GETDATE()) AND DATEADD(MONTH, 12, GETDATE()) THEN l.outstanding_principal ELSE 0 END)
FROM sathapana_dwh.dw.fact_loan_portfolio l
UNION ALL
SELECT 'LOANS', '12M+', SUM(CASE WHEN l.maturity_date > DATEADD(MONTH, 12, GETDATE()) THEN l.outstanding_principal ELSE 0 END)
FROM sathapana_dwh.dw.fact_loan_portfolio l
UNION ALL
-- Liability side (Deposits)
SELECT 'DEPOSITS', '0-3M', SUM(CASE WHEN a.maturity_date <= DATEADD(MONTH, 3, GETDATE()) THEN s.balance ELSE 0 END)
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_account a ON s.account_key = a.account_key
UNION ALL
SELECT 'DEPOSITS', '3-6M', SUM(CASE WHEN a.maturity_date BETWEEN DATEADD(MONTH, 3, GETDATE()) AND DATEADD(MONTH, 6, GETDATE()) THEN s.balance ELSE 0 END)
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_account a ON s.account_key = a.account_key
UNION ALL
SELECT 'DEPOSITS', '6-12M', SUM(CASE WHEN a.maturity_date BETWEEN DATEADD(MONTH, 6, GETDATE()) AND DATEADD(MONTH, 12, GETDATE()) THEN s.balance ELSE 0 END)
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_account a ON s.account_key = a.account_key
UNION ALL
SELECT 'DEPOSITS', '12M+', SUM(CASE WHEN a.maturity_date > DATEADD(MONTH, 12, GETDATE()) THEN s.balance ELSE 0 END)
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_account a ON s.account_key = a.account_key;

-- ============================================================================
-- VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'ALM DATA MART CREATED';
PRINT 'Database: sathapana_dm_alm';
PRINT '================================================';
PRINT 'Views Created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm');
PRINT '================================================';
GO
