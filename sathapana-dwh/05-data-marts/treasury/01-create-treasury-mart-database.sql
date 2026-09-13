-- ============================================================================
-- SATHAPANA BANK - LAYER 3: TREASURY DATA MART
-- ============================================================================
-- Database: sathapana_dm_treasury
-- Author: DWH Development Team
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_dm_treasury')
BEGIN
    ALTER DATABASE sathapana_dm_treasury SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_dm_treasury;
END
GO

CREATE DATABASE sathapana_dm_treasury
ON PRIMARY (
    NAME = 'sathapana_dm_treasury_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_treasury_dat.mdf',
    SIZE = 100MB, MAXSIZE = 5GB, FILEGROWTH = 50MB
)
LOG ON (
    NAME = 'sathapana_dm_treasury_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_treasury_log.ldf',
    SIZE = 50MB, MAXSIZE = 2GB, FILEGROWTH = 25MB
);
GO

USE sathapana_dm_treasury;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm')
    EXEC('CREATE SCHEMA dm');
GO

-- ============================================================================
-- 1. FX PERFORMANCE VIEW
-- ============================================================================
CREATE VIEW dm.vw_fx_performance AS
SELECT 
    b.branch_code,
    b.branch_name,
    sc.currency_code AS source_currency,
    tc.currency_code AS target_currency,
    COUNT(*) AS total_fx_transactions,
    SUM(CASE WHEN fx.transaction_type = 'BUY' THEN 1 ELSE 0 END) AS buy_transactions,
    SUM(CASE WHEN fx.transaction_type = 'SELL' THEN 1 ELSE 0 END) AS sell_transactions,
    SUM(fx.source_amount) AS total_source_amount,
    SUM(fx.target_amount) AS total_target_amount,
    AVG(fx.spread) AS avg_spread,
    SUM(fx.profit_amount) AS total_profit,
    AVG(fx.exchange_rate) AS avg_exchange_rate,
    d.full_date AS transaction_date
FROM sathapana_dwh.dw.fact_fx_transactions fx
JOIN sathapana_dwh.dw.dim_branch b ON fx.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_currency sc ON fx.source_currency_key = sc.currency_key
JOIN sathapana_dwh.dw.dim_currency tc ON fx.target_currency_key = tc.currency_key
JOIN sathapana_dwh.dw.dim_date d ON fx.transaction_date_key = d.date_key
GROUP BY b.branch_code, b.branch_name, sc.currency_code, tc.currency_code, d.full_date;

-- ============================================================================
-- 2. DEPOSIT MOBILIZATION VIEW
-- ============================================================================
CREATE VIEW dm.vw_deposit_mobilization AS
SELECT 
    b.branch_code,
    b.branch_name,
    p.product_category,
    p.product_name,
    d.year_number,
    d.month_number,
    d.month_name,
    SUM(s.balance) AS total_balance,
    AVG(s.balance) AS avg_balance,
    SUM(s.interest_earned) AS total_interest_earned,
    AVG(s.interest_rate) AS avg_interest_rate,
    COUNT(DISTINCT s.account_key) AS total_accounts
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_branch b ON s.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_product p ON s.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
GROUP BY b.branch_code, b.branch_name, p.product_category, p.product_name, d.year_number, d.month_number, d.month_name;

-- ============================================================================
-- 3. INTEREST RATE SENSITIVITY VIEW
-- ============================================================================
CREATE VIEW dm.vw_interest_rate_sensitivity AS
SELECT 
    p.product_category,
    p.product_name,
    SUM(CASE WHEN p.interest_rate < 5 THEN 1 ELSE 0 END) AS rate_below_5,
    SUM(CASE WHEN p.interest_rate BETWEEN 5 AND 10 THEN 1 ELSE 0 END) AS rate_5_to_10,
    SUM(CASE WHEN p.interest_rate BETWEEN 10 AND 15 THEN 1 ELSE 0 END) AS rate_10_to_15,
    SUM(CASE WHEN p.interest_rate > 15 THEN 1 ELSE 0 END) AS rate_above_15,
    SUM(CASE WHEN p.interest_rate < 5 THEN s.balance ELSE 0 END) AS balance_below_5,
    SUM(CASE WHEN p.interest_rate BETWEEN 5 AND 10 THEN s.balance ELSE 0 END) AS balance_5_to_10,
    SUM(CASE WHEN p.interest_rate BETWEEN 10 AND 15 THEN s.balance ELSE 0 END) AS balance_10_to_15,
    SUM(CASE WHEN p.interest_rate > 15 THEN s.balance ELSE 0 END) AS balance_above_15,
    SUM(p.interest_rate * s.balance) / NULLIF(SUM(s.balance), 0) AS weighted_avg_rate,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_product p ON s.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY p.product_category, p.product_name, d.full_date;

-- ============================================================================
-- 4. CURRENCY EXPOSURE VIEW
-- ============================================================================
CREATE VIEW dm.vw_currency_exposure AS
SELECT 
    c.currency_code,
    c.currency_name,
    -- Transaction exposure
    COUNT(DISTINCT fx.fx_key) AS fx_transaction_count,
    SUM(fx.source_amount) AS total_fx_volume,
    SUM(fx.profit_amount) AS total_fx_profit,
    -- Balance exposure (deposits in foreign currency)
    SUM(DISTINCT ds.balance) AS deposit_balance,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.dim_currency c
LEFT JOIN sathapana_dwh.dw.fact_fx_transactions fx ON c.currency_key = fx.source_currency_key
LEFT JOIN sathapana_dwh.dw.fact_deposit_snapshot ds ON c.currency_key = ds.product_key
LEFT JOIN sathapana_dwh.dw.dim_date d ON fx.transaction_date_key = d.date_key
GROUP BY c.currency_code, c.currency_name, d.full_date;

-- ============================================================================
-- 5. LIQUIDITY MONITORING VIEW
-- ============================================================================
CREATE VIEW dm.vw_liquidity_monitoring AS
SELECT 
    b.branch_code,
    b.branch_name,
    -- Deposit metrics
    SUM(CASE WHEN p.product_category = 'DEPOSIT' THEN s.balance ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN p.product_subcategory = 'SAVINGS' THEN s.balance ELSE 0 END) AS savings_deposits,
    SUM(CASE WHEN p.product_subcategory = 'TERM_DEPOSIT' THEN s.balance ELSE 0 END) AS term_deposits,
    SUM(CASE WHEN p.product_subcategory = 'CURRENT' THEN s.balance ELSE 0 END) AS current_deposits,
    -- Loan metrics (for LDR calculation)
    (SELECT SUM(l.outstanding_principal) 
     FROM sathapana_dwh.dw.fact_loan_portfolio l 
     WHERE l.branch_key = b.branch_key) AS total_loans,
    -- Loan-to-Deposit Ratio
    CASE 
        WHEN SUM(CASE WHEN p.product_category = 'DEPOSIT' THEN s.balance ELSE 0 END) = 0 THEN 0
        ELSE (SELECT SUM(l.outstanding_principal) 
              FROM sathapana_dwh.dw.fact_loan_portfolio l 
              WHERE l.branch_key = b.branch_key) / 
             SUM(CASE WHEN p.product_category = 'DEPOSIT' THEN s.balance ELSE 0 END) * 100
    END AS ldr_ratio,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_deposit_snapshot s
JOIN sathapana_dwh.dw.dim_branch b ON s.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_product p ON s.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY b.branch_code, b.branch_name, b.branch_key, d.full_date;

-- ============================================================================
-- VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'TREASURY DATA MART CREATED';
PRINT 'Database: sathapana_dm_treasury';
PRINT '================================================';
PRINT 'Views Created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm');
PRINT '================================================';
GO
