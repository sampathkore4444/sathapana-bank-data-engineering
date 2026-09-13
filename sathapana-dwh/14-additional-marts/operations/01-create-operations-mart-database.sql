-- ============================================================================
-- SATHAPANA BANK - LAYER 3: OPERATIONS DATA MART
-- ============================================================================
-- Database: sathapana_dm_operations
-- Purpose: Operational analytics, branch performance, channel analysis
-- Author: DWH Development Team
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_dm_operations')
BEGIN
    ALTER DATABASE sathapana_dm_operations SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_dm_operations;
END
GO

CREATE DATABASE sathapana_dm_operations
ON PRIMARY (
    NAME = 'sathapana_dm_operations_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_operations_dat.mdf',
    SIZE = 100MB, MAXSIZE = 5GB, FILEGROWTH = 50MB
)
LOG ON (
    NAME = 'sathapana_dm_operations_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_operations_log.ldf',
    SIZE = 50MB, MAXSIZE = 2GB, FILEGROWTH = 25MB
);
GO

USE sathapana_dm_operations;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm')
    EXEC('CREATE SCHEMA dm');
GO

-- ============================================================================
-- 1. BRANCH PERFORMANCE VIEW
-- ============================================================================
CREATE VIEW dm.vw_branch_performance AS
SELECT 
    b.branch_code,
    b.branch_name,
    b.branch_type,
    b.region,
    b.province,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    SUM(CASE WHEN a.account_type = 'SAVINGS' THEN 1 ELSE 0 END) AS savings_accounts,
    SUM(CASE WHEN a.account_type = 'CURRENT' THEN 1 ELSE 0 END) AS current_accounts,
    SUM(CASE WHEN a.account_type = 'LOAN' THEN 1 ELSE 0 END) AS loan_accounts,
    -- Transaction metrics (last 30 days)
    COUNT(DISTINCT t.transaction_key) AS transactions_30d,
    SUM(t.amount) AS transaction_volume_30d,
    AVG(t.amount) AS avg_transaction_amount,
    -- Revenue metrics
    SUM(t.fee_amount) AS fees_collected_30d,
    -- Employee count
    (SELECT COUNT(*) FROM sathapana_dwh.dw.dim_employee e 
     WHERE e.branch_key = b.branch_key AND e.is_current = 1 AND e.is_active = 1) AS employee_count,
    -- Productivity
    COUNT(DISTINCT t.transaction_key) / NULLIF(
        (SELECT COUNT(*) FROM sathapana_dwh.dw.dim_employee e 
         WHERE e.branch_key = b.branch_key AND e.is_current = 1 AND e.is_active = 1), 0
    ) AS transactions_per_employee,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.dim_branch b
LEFT JOIN sathapana_dwh.dw.dim_account a ON b.branch_key = a.branch_key AND a.is_current = 1
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
    AND t.transaction_date_key >= CAST(FORMAT(DATEADD(DAY, -30, GETDATE()), 'yyyyMMdd') AS INT)
LEFT JOIN sathapana_dwh.dw.dim_date d ON t.transaction_date_key = d.date_key
WHERE b.is_active = 1
GROUP BY b.branch_code, b.branch_name, b.branch_type, b.region, b.province, b.branch_key, d.full_date;

-- ============================================================================
-- 2. CHANNEL ANALYSIS VIEW
-- ============================================================================
CREATE VIEW dm.vw_channel_analysis AS
SELECT 
    ch.channel_code,
    ch.channel_name,
    ch.channel_category,
    ch.is_digital,
    -- Transaction metrics
    COUNT(t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_volume,
    AVG(t.amount) AS avg_transaction_amount,
    -- Fee revenue
    SUM(t.fee_amount) AS total_fees,
    SUM(t.tax_amount) AS total_tax,
    -- Customer usage
    COUNT(DISTINCT a.customer_key) AS unique_customers,
    COUNT(t.transaction_key) / NULLIF(COUNT(DISTINCT a.customer_key), 0) AS transactions_per_customer,
    -- Trend (vs previous period)
    SUM(CASE WHEN t.transaction_date_key >= CAST(FORMAT(DATEADD(DAY, -30, GETDATE()), 'yyyyMMdd') AS INT) 
             AND t.transaction_date_key < CAST(FORMAT(GETDATE(), 'yyyyMMdd') AS INT)
        THEN t.amount ELSE 0 END) AS volume_last_30d,
    SUM(CASE WHEN t.transaction_date_key >= CAST(FORMAT(DATEADD(DAY, -60, GETDATE()), 'yyyyMMdd') AS INT) 
             AND t.transaction_date_key < CAST(FORMAT(DATEADD(DAY, -30, GETDATE()), 'yyyyMMdd') AS INT)
        THEN t.amount ELSE 0 END) AS volume_prev_30d,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.dim_channel ch
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON ch.channel_key = t.channel_key
LEFT JOIN sathapana_dwh.dw.dim_account a ON t.account_key = a.account_key
LEFT JOIN sathapana_dwh.dw.dim_date d ON t.transaction_date_key = d.date_key
GROUP BY ch.channel_code, ch.channel_name, ch.channel_category, ch.is_digital, d.full_date;

-- ============================================================================
-- 3. TRANSACTION MONITORING VIEW
-- ============================================================================
CREATE VIEW dm.vw_transaction_monitoring AS
SELECT 
    -- Daily aggregates
    d.full_date AS transaction_date,
    d.day_name,
    b.branch_code,
    b.branch_name,
    ch.channel_name,
    -- Volume metrics
    COUNT(t.transaction_key) AS transaction_count,
    SUM(t.amount) AS total_volume,
    AVG(t.amount) AS avg_amount,
    MAX(t.amount) AS max_amount,
    MIN(t.amount) AS min_amount,
    -- By type
    SUM(CASE WHEN t.transaction_type_key = 1 THEN t.amount ELSE 0 END) AS deposit_volume,
    SUM(CASE WHEN t.transaction_type_key = 2 THEN t.amount ELSE 0 END) AS withdrawal_volume,
    SUM(CASE WHEN t.transaction_type_key IN (3, 4) THEN t.amount ELSE 0 END) AS transfer_volume,
    -- Fee revenue
    SUM(t.fee_amount) AS fees_collected,
    -- Cash vs Digital
    SUM(CASE WHEN ch.is_digital = 0 THEN t.amount ELSE 0 END) AS branch_volume,
    SUM(CASE WHEN ch.is_digital = 1 THEN t.amount ELSE 0 END) AS digital_volume
FROM sathapana_dwh.dw.fact_transactions t
JOIN sathapana_dwh.dw.dim_date d ON t.transaction_date_key = d.date_key
JOIN sathapana_dwh.dw.dim_branch b ON t.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_channel ch ON t.channel_key = ch.channel_key
WHERE d.full_date >= DATEADD(DAY, -30, GETDATE())
GROUP BY d.full_date, d.day_name, b.branch_code, b.branch_name, ch.channel_name;

-- ============================================================================
-- 4. EMPLOYEE PRODUCTIVITY VIEW
-- ============================================================================
CREATE VIEW dm.vw_employee_productivity AS
SELECT 
    e.employee_code,
    e.full_name,
    e.job_title,
    e.department,
    b.branch_code,
    b.branch_name,
    -- Activity metrics
    COUNT(DISTINCT t.transaction_key) AS transactions_handled,
    SUM(t.amount) AS total_volume,
    -- Tenure
    DATEDIFF(MONTH, e.hire_date, GETDATE()) AS tenure_months,
    -- Productivity
    COUNT(DISTINCT t.transaction_key) / NULLIF(DATEDIFF(MONTH, e.hire_date, GETDATE()), 0) AS avg_monthly_transactions,
    -- Date
    d.full_date AS activity_date
FROM sathapana_dwh.dw.dim_employee e
JOIN sathapana_dwh.dw.dim_branch b ON e.branch_key = b.branch_key
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON e.employee_key = t.account_key  -- Simplified
LEFT JOIN sathapana_dwh.dw.dim_date d ON t.transaction_date_key = d.date_key
WHERE e.is_current = 1 AND e.is_active = 1
GROUP BY e.employee_code, e.full_name, e.job_title, e.department, b.branch_code, b.branch_name, e.hire_date, d.full_date;

-- ============================================================================
-- 5. ACCOUNT ACTIVITY VIEW
-- ============================================================================
CREATE VIEW dm.vw_account_activity AS
SELECT 
    a.account_number,
    c.customer_code,
    c.full_name,
    c.customer_segment,
    a.account_type,
    b.branch_code,
    -- Activity metrics
    COUNT(t.transaction_key) AS transaction_count,
    SUM(t.amount) AS total_volume,
    MAX(t.transaction_datetime) AS last_transaction_date,
    DATEDIFF(DAY, MAX(t.transaction_datetime), GETDATE()) AS days_since_last_txn,
    -- Activity status
    CASE 
        WHEN MAX(t.transaction_datetime) >= DATEADD(DAY, -7, GETDATE()) THEN 'HIGHLY_ACTIVE'
        WHEN MAX(t.transaction_datetime) >= DATEADD(DAY, -30, GETDATE()) THEN 'ACTIVE'
        WHEN MAX(t.transaction_datetime) >= DATEADD(DAY, -90, GETDATE()) THEN 'LOW_ACTIVITY'
        WHEN MAX(t.transaction_datetime) >= DATEADD(DAY, -180, GETDATE()) THEN 'DORMANT'
        ELSE 'INACTIVE'
    END AS activity_status,
    -- Balance
    MAX(s.closing_balance) AS current_balance
FROM sathapana_dwh.dw.dim_account a
JOIN sathapana_dwh.dw.dim_customer c ON a.customer_key = c.customer_key
JOIN sathapana_dwh.dw.dim_branch b ON a.branch_key = b.branch_key
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
LEFT JOIN sathapana_dwh.dw.fact_account_daily_snapshot s ON a.account_key = s.account_key
WHERE a.is_current = 1
GROUP BY a.account_number, c.customer_code, c.full_name, c.customer_segment, a.account_type, b.branch_code;

-- ============================================================================
-- 6. PRODUCT PERFORMANCE VIEW
-- ============================================================================
CREATE VIEW dm.vw_product_performance AS
SELECT 
    p.product_code,
    p.product_name,
    p.product_category,
    p.product_subcategory,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    COUNT(DISTINCT CASE WHEN a.is_active = 1 THEN a.account_key END) AS active_accounts,
    -- Balance metrics
    SUM(s.balance) AS total_balance,
    AVG(s.balance) AS avg_balance,
    -- Transaction metrics
    COUNT(DISTINCT t.transaction_key) AS transaction_count,
    SUM(t.amount) AS transaction_volume,
    -- Revenue
    SUM(t.fee_amount) AS fees_collected,
    -- Growth
    SUM(CASE WHEN a.open_date >= DATEADD(MONTH, -1, GETDATE()) THEN 1 ELSE 0 END) AS new_accounts_this_month,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.dim_product p
LEFT JOIN sathapana_dwh.dw.dim_account a ON p.product_key = a.product_key AND a.is_current = 1
LEFT JOIN sathapana_dwh.dw.fact_deposit_snapshot s ON a.account_key = s.account_key
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
LEFT JOIN sathapana_dwh.dw.dim_date d ON s.snapshot_date_key = d.date_key
GROUP BY p.product_code, p.product_name, p.product_category, p.product_subcategory, d.full_date;

-- ============================================================================
-- 7. DAILY OPERATIONS SUMMARY VIEW
-- ============================================================================
CREATE VIEW dm.vw_daily_operations_summary AS
SELECT 
    d.full_date,
    d.day_name,
    -- Volume metrics
    COUNT(t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_volume,
    AVG(t.amount) AS avg_transaction_size,
    -- By channel
    SUM(CASE WHEN ch.channel_code = 'COUNTER' THEN 1 ELSE 0 END) AS counter_transactions,
    SUM(CASE WHEN ch.channel_code = 'ATM' THEN 1 ELSE 0 END) AS atm_transactions,
    SUM(CASE WHEN ch.channel_code = 'MOBILE' THEN 1 ELSE 0 END) AS mobile_transactions,
    SUM(CASE WHEN ch.channel_code = 'INTERNET' THEN 1 ELSE 0 END) AS internet_transactions,
    -- Revenue
    SUM(t.fee_amount) AS total_fees,
    SUM(t.tax_amount) AS total_tax,
    -- Digital adoption
    SUM(CASE WHEN ch.is_digital = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(t.transaction_key), 0) AS digital_adoption_pct,
    -- Peak hour analysis (if time available)
    COUNT(DISTINCT a.customer_key) AS unique_customers
FROM sathapana_dwh.dw.fact_transactions t
JOIN sathapana_dwh.dw.dim_date d ON t.transaction_date_key = d.date_key
JOIN sathapana_dwh.dw.dim_channel ch ON t.channel_key = ch.channel_key
JOIN sathapana_dwh.dw.dim_account a ON t.account_key = a.account_key
WHERE d.full_date >= DATEADD(DAY, -7, GETDATE())
GROUP BY d.full_date, d.day_name;

-- ============================================================================
-- VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'OPERATIONS DATA MART CREATED';
PRINT 'Database: sathapana_dm_operations';
PRINT '================================================';
PRINT 'Views Created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm');
PRINT '================================================';
GO
