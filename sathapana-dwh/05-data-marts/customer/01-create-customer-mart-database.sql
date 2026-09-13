-- ============================================================================
-- SATHAPANA BANK - LAYER 3: CUSTOMER ANALYTICS DATA MART
-- ============================================================================
-- Purpose: Create Customer Analytics Data Mart database (Serving Zone)
-- Database: sathapana_dm_customer
-- Author: DWH Development Team
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_dm_customer')
BEGIN
    ALTER DATABASE sathapana_dm_customer SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_dm_customer;
END
GO

CREATE DATABASE sathapana_dm_customer
ON PRIMARY (
    NAME = 'sathapana_dm_customer_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_customer_dat.mdf',
    SIZE = 100MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 50MB
)
LOG ON (
    NAME = 'sathapana_dm_customer_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_customer_log.ldf',
    SIZE = 50MB,
    MAXSIZE = 2GB,
    FILEGROWTH = 25MB
);
GO

USE sathapana_dm_customer;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm')
    EXEC('CREATE SCHEMA dm');
GO

-- ============================================================================
-- 1. CUSTOMER 360 VIEW
-- ============================================================================
CREATE VIEW dm.vw_customer_360 AS
SELECT 
    c.customer_key,
    c.customer_code,
    c.full_name,
    c.customer_type,
    c.customer_segment,
    c.gender,
    c.age,
    c.nationality,
    c.province,
    c.district,
    c.risk_rating,
    c.kyc_status,
    c.is_pep,
    c.is_sanctioned,
    c.annual_income,
    c.income_bracket,
    c.occupation,
    c.employer_name,
    c.acquisition_channel,
    c.is_active,
    c.effective_date,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    COUNT(DISTINCT CASE WHEN a.account_type = 'SAVINGS' THEN a.account_key END) AS savings_accounts,
    COUNT(DISTINCT CASE WHEN a.account_type = 'CURRENT' THEN a.account_key END) AS current_accounts,
    COUNT(DISTINCT CASE WHEN a.account_type = 'TERM_DEPOSIT' THEN a.account_key END) AS term_deposits,
    -- Balance metrics (from latest snapshot)
    SUM(DISTINCT s.closing_balance) AS total_balance
FROM sathapana_dwh.dw.dim_customer c
LEFT JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key AND a.is_current = 1
LEFT JOIN sathapana_dwh.dw.fact_account_daily_snapshot s ON a.account_key = s.account_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_key, c.customer_code, c.full_name, c.customer_type,
    c.customer_segment, c.gender, c.age, c.nationality, c.province,
    c.district, c.risk_rating, c.kyc_status, c.is_pep, c.is_sanctioned,
    c.annual_income, c.income_bracket, c.occupation, c.employer_name,
    c.acquisition_channel, c.is_active, c.effective_date;

-- ============================================================================
-- 2. CUSTOMER SEGMENTATION VIEW
-- ============================================================================
CREATE VIEW dm.vw_customer_segmentation AS
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
    -- Product penetration
    COUNT(DISTINCT CASE WHEN p.product_category = 'DEPOSIT' THEN a.account_key END) AS deposit_accounts,
    COUNT(DISTINCT CASE WHEN p.product_category = 'LOAN' THEN a.account_key END) AS loan_accounts,
    -- KYC status
    SUM(CASE WHEN c.kyc_status = 'VERIFIED' THEN 1 ELSE 0 END) AS kyc_verified,
    SUM(CASE WHEN c.kyc_status = 'PENDING' THEN 1 ELSE 0 END) AS kyc_pending,
    SUM(CASE WHEN c.kyc_status = 'EXPIRED' THEN 1 ELSE 0 END) AS kyc_expired,
    -- Risk flags
    SUM(CASE WHEN c.is_pep = 1 THEN 1 ELSE 0 END) AS pep_count,
    SUM(CASE WHEN c.is_sanctioned = 1 THEN 1 ELSE 0 END) AS sanctioned_count
FROM sathapana_dwh.dw.dim_customer c
LEFT JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key
LEFT JOIN sathapana_dwh.dw.dim_product p ON a.product_key = p.product_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_segment, c.risk_rating, c.province, c.gender;

-- ============================================================================
-- 3. CUSTOMER PROFITABILITY VIEW
-- ============================================================================
CREATE VIEW dm.vw_customer_profitability AS
SELECT 
    c.customer_key,
    c.customer_code,
    c.full_name,
    c.customer_segment,
    c.province,
    -- Account metrics
    COUNT(DISTINCT a.account_key) AS total_accounts,
    -- Balance metrics
    AVG(s.closing_balance) AS avg_balance,
    MAX(s.closing_balance) AS max_balance,
    -- Transaction metrics
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_transaction_volume,
    SUM(t.fee_amount) AS total_fees_collected,
    -- Revenue metrics
    SUM(t.fee_amount) + SUM(t.tax_amount) AS total_revenue
FROM sathapana_dwh.dw.dim_customer c
LEFT JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key AND a.is_current = 1
LEFT JOIN sathapana_dwh.dw.fact_account_daily_snapshot s ON a.account_key = s.account_key
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_key, c.customer_code, c.full_name, c.customer_segment, c.province;

-- ============================================================================
-- 4. CUSTOMER LIFECYCLE VIEW
-- ============================================================================
CREATE VIEW dm.vw_customer_lifecycle AS
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
FROM sathapana_dwh.dw.dim_customer c
LEFT JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_key, c.customer_code, c.full_name, c.customer_type,
    c.customer_segment, c.acquisition_channel, c.created_date;

-- ============================================================================
-- 5. CUSTOMER ACQUISITION VIEW
-- ============================================================================
CREATE VIEW dm.vw_customer_acquisition AS
SELECT 
    d.year_number,
    d.month_number,
    d.month_name,
    c.acquisition_channel,
    c.customer_segment,
    -- Acquisition metrics
    COUNT(DISTINCT c.customer_key) AS new_customers,
    -- Demographics
    AVG(c.age) AS avg_age,
    AVG(c.annual_income) AS avg_income,
    -- Channel distribution
    COUNT(DISTINCT c.customer_key) * 100.0 / SUM(COUNT(DISTINCT c.customer_key)) OVER (PARTITION BY d.year_number, d.month_number) AS channel_share_pct
FROM sathapana_dwh.dw.dim_customer c
JOIN sathapana_dwh.dw.dim_date d ON CAST(c.effective_date AS INT) = d.date_key
WHERE c.is_current = 1
GROUP BY 
    d.year_number, d.month_number, d.month_name,
    c.acquisition_channel, c.customer_segment;

-- ============================================================================
-- 6. CUSTOMER DEMOGRAPHICS VIEW
-- ============================================================================
CREATE VIEW dm.vw_customer_demographics AS
SELECT 
    -- Age distribution
    CASE 
        WHEN c.age < 25 THEN '18-24'
        WHEN c.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN c.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN c.age BETWEEN 45 AND 54 THEN '45-54'
        WHEN c.age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END AS age_group,
    c.gender,
    c.province,
    c.customer_segment,
    -- Counts
    COUNT(*) AS customer_count,
    -- Percentage
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS percentage,
    -- Income metrics
    AVG(c.annual_income) AS avg_income,
    MIN(c.annual_income) AS min_income,
    MAX(c.annual_income) AS max_income
FROM sathapana_dwh.dw.dim_customer c
WHERE c.is_current = 1 AND c.date_of_birth IS NOT NULL
GROUP BY 
    CASE 
        WHEN c.age < 25 THEN '18-24'
        WHEN c.age BETWEEN 25 AND 34 THEN '25-34'
        WHEN c.age BETWEEN 35 AND 44 THEN '35-44'
        WHEN c.age BETWEEN 45 AND 54 THEN '45-54'
        WHEN c.age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END,
    c.gender,
    c.province,
    c.customer_segment;

-- ============================================================================
-- 7. TOP CUSTOMERS VIEW
-- ============================================================================
CREATE VIEW dm.vw_top_customers AS
SELECT TOP 100
    c.customer_code,
    c.full_name,
    c.customer_segment,
    c.province,
    -- Balance metrics
    SUM(s.closing_balance) AS total_balance,
    -- Transaction metrics
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_volume,
    -- Revenue
    SUM(t.fee_amount) AS total_fees,
    -- Rank
    RANK() OVER (ORDER BY SUM(s.closing_balance) DESC) AS balance_rank,
    RANK() OVER (ORDER BY SUM(t.amount) DESC) AS volume_rank
FROM sathapana_dwh.dw.dim_customer c
LEFT JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key AND a.is_current = 1
LEFT JOIN sathapana_dwh.dw.fact_account_daily_snapshot s ON a.account_key = s.account_key
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY 
    c.customer_code, c.full_name, c.customer_segment, c.province
ORDER BY total_balance DESC;

-- ============================================================================
-- VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'CUSTOMER ANALYTICS DATA MART CREATED';
PRINT 'Database: sathapana_dm_customer';
PRINT '================================================';
PRINT '';
PRINT 'Views Created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm');
PRINT '';
PRINT '================================================';
GO
