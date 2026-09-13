-- ============================================================================
-- SATHAPANA BANK - LAYER 3: CREDIT RISK DATA MART
-- ============================================================================
-- Purpose: Create Credit Risk Data Mart database (Serving Zone)
-- Database: sathapana_dm_credit
-- Architecture: Layer 3 (Department-specific analytical views)
-- Author: DWH Development Team
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_dm_credit')
BEGIN
    ALTER DATABASE sathapana_dm_credit SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_dm_credit;
END
GO

CREATE DATABASE sathapana_dm_credit
ON PRIMARY (
    NAME = 'sathapana_dm_credit_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_credit_dat.mdf',
    SIZE = 100MB,
    MAXSIZE = 5GB,
    FILEGROWTH = 50MB
)
LOG ON (
    NAME = 'sathapana_dm_credit_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_credit_log.ldf',
    SIZE = 50MB,
    MAXSIZE = 2GB,
    FILEGROWTH = 25MB
);
GO

USE sathapana_dm_credit;
GO

-- Create schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm')
    EXEC('CREATE SCHEMA dm');
GO

-- ============================================================================
-- CREDIT RISK DATA MART VIEWS
-- These views reference sathapana_dwh (Layer 2 - Curated Zone)
-- ============================================================================

-- ============================================================================
-- 1. CREDIT RISK SUMMARY VIEW
-- ============================================================================
CREATE VIEW dm.vw_credit_risk_summary AS
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
FROM sathapana_dwh.dw.fact_loan_portfolio l
JOIN sathapana_dwh.dw.dim_branch b ON l.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_product p ON l.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE b.is_active = 1
GROUP BY 
    b.branch_code, b.branch_name, b.region,
    p.product_category, p.product_name,
    d.full_date;

-- ============================================================================
-- 2. LOAN MATURITY PROFILE VIEW
-- ============================================================================
CREATE VIEW dm.vw_loan_maturity_profile AS
SELECT 
    b.branch_code,
    b.branch_name,
    p.product_category,
    -- Maturity buckets (count)
    SUM(CASE WHEN l.maturity_date <= DATEADD(MONTH, 3, GETDATE()) THEN 1 ELSE 0 END) AS mat_0_3m_count,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 3, GETDATE()) AND DATEADD(MONTH, 6, GETDATE()) THEN 1 ELSE 0 END) AS mat_3_6m_count,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 6, GETDATE()) AND DATEADD(MONTH, 12, GETDATE()) THEN 1 ELSE 0 END) AS mat_6_12m_count,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 12, GETDATE()) AND DATEADD(MONTH, 24, GETDATE()) THEN 1 ELSE 0 END) AS mat_12_24m_count,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 24, GETDATE()) AND DATEADD(MONTH, 60, GETDATE()) THEN 1 ELSE 0 END) AS mat_24_60m_count,
    SUM(CASE WHEN l.maturity_date > DATEADD(MONTH, 60, GETDATE()) THEN 1 ELSE 0 END) AS mat_60m_plus_count,
    -- Amounts
    SUM(CASE WHEN l.maturity_date <= DATEADD(MONTH, 3, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_0_3m_amount,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 3, GETDATE()) AND DATEADD(MONTH, 6, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_3_6m_amount,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 6, GETDATE()) AND DATEADD(MONTH, 12, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_6_12m_amount,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 12, GETDATE()) AND DATEADD(MONTH, 24, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_12_24m_amount,
    SUM(CASE WHEN l.maturity_date BETWEEN DATEADD(MONTH, 24, GETDATE()) AND DATEADD(MONTH, 60, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_24_60m_amount,
    SUM(CASE WHEN l.maturity_date > DATEADD(MONTH, 60, GETDATE()) THEN l.outstanding_principal ELSE 0 END) AS mat_60m_plus_amount,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_loan_portfolio l
JOIN sathapana_dwh.dw.dim_branch b ON l.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_product p ON l.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, p.product_category, d.full_date;

-- ============================================================================
-- 3. PROVISIONING SUMMARY VIEW
-- ============================================================================
CREATE VIEW dm.vw_provisioning_summary AS
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
FROM sathapana_dwh.dw.fact_loan_portfolio l
JOIN sathapana_dwh.dw.dim_branch b ON l.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, l.risk_classification, d.full_date;

-- ============================================================================
-- 4. NPL TREND VIEW
-- ============================================================================
CREATE VIEW dm.vw_npl_trend AS
SELECT 
    d.year_number,
    d.month_number,
    d.month_name,
    -- Portfolio metrics
    COUNT(*) AS total_loans,
    SUM(l.outstanding_principal) AS total_outstanding,
    -- NPL metrics
    SUM(CASE WHEN l.days_past_due > 90 THEN 1 ELSE 0 END) AS npl_count,
    SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) AS npl_amount,
    CASE 
        WHEN SUM(l.outstanding_principal) = 0 THEN 0
        ELSE SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) / SUM(l.outstanding_principal) * 100
    END AS npl_ratio,
    -- Provision coverage
    SUM(l.provision_amount) AS total_provisions,
    CASE 
        WHEN SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) = 0 THEN 0
        ELSE SUM(l.provision_amount) / SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) * 100
    END AS provision_coverage_ratio
FROM sathapana_dwh.dw.fact_loan_portfolio l
JOIN sathapana_dwh.dw.dim_date d ON l.snapshot_date_key = d.date_key
GROUP BY 
    d.year_number, d.month_number, d.month_name;

-- ============================================================================
-- 5. COLLATERAL ANALYSIS VIEW
-- ============================================================================
CREATE VIEW dm.vw_collateral_analysis AS
SELECT 
    b.branch_code,
    b.branch_name,
    p.product_name,
    -- Loan counts by collateral type
    COUNT(*) AS total_loans,
    SUM(CASE WHEN l.collateral_type IS NOT NULL THEN 1 ELSE 0 END) AS secured_loans,
    SUM(CASE WHEN l.collateral_type IS NULL THEN 1 ELSE 0 END) AS unsecured_loans,
    -- Collateral values
    SUM(ISNULL(l.collateral_value, 0)) AS total_collateral_value,
    SUM(l.outstanding_principal) AS total_outstanding,
    -- Collateral coverage ratio
    CASE 
        WHEN SUM(l.outstanding_principal) = 0 THEN 0
        ELSE SUM(ISNULL(l.collateral_value, 0)) / SUM(l.outstanding_principal) * 100
    END AS collateral_coverage_ratio,
    -- Guarantee analysis
    SUM(ISNULL(l.guarantee_amount, 0)) AS total_guarantee_amount,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_loan_portfolio l
JOIN sathapana_dwh.dw.dim_branch b ON l.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_product p ON l.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, p.product_name, d.full_date;

-- ============================================================================
-- 6. BRANCH RISK RANKING VIEW
-- ============================================================================
CREATE VIEW dm.vw_branch_risk_ranking AS
SELECT 
    b.branch_code,
    b.branch_name,
    b.region,
    -- Portfolio size
    COUNT(*) AS total_loans,
    SUM(l.outstanding_principal) AS total_outstanding,
    -- Risk metrics
    SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) AS npl_amount,
    CASE 
        WHEN SUM(l.outstanding_principal) = 0 THEN 0
        ELSE SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) / SUM(l.outstanding_principal) * 100
    END AS npl_ratio,
    -- Provision metrics
    SUM(l.provision_amount) AS total_provisions,
    -- Risk score (higher = worse)
    (CASE 
        WHEN SUM(l.outstanding_principal) = 0 THEN 0
        ELSE SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) / SUM(l.outstanding_principal) * 100
    END) * 2 AS risk_score,
    -- Rank
    RANK() OVER (ORDER BY 
        CASE 
            WHEN SUM(l.outstanding_principal) = 0 THEN 0
            ELSE SUM(CASE WHEN l.days_past_due > 90 THEN l.outstanding_principal ELSE 0 END) / SUM(l.outstanding_principal) * 100
        END DESC
    ) AS risk_rank
FROM sathapana_dwh.dw.fact_loan_portfolio l
JOIN sathapana_dwh.dw.dim_branch b ON l.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, b.region;

-- ============================================================================
-- 7. LOAN PERFORMANCE VIEW
-- ============================================================================
CREATE VIEW dm.vw_loan_performance AS
SELECT 
    b.branch_code,
    b.branch_name,
    p.product_name,
    c.customer_segment,
    -- Application metrics
    COUNT(*) AS total_applications,
    SUM(l.loan_amount) AS total_applied,
    SUM(l.approved_amount) AS total_approved,
    SUM(l.disbursed_amount) AS total_disbursed,
    -- Approval rate
    CASE 
        WHEN COUNT(*) = 0 THEN 0
        ELSE SUM(CASE WHEN l.approved_amount IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)
    END AS approval_rate,
    -- Disbursement rate
    CASE 
        WHEN SUM(l.approved_amount) = 0 THEN 0
        ELSE SUM(ISNULL(l.disbursed_amount, 0)) / SUM(l.approved_amount) * 100
    END AS disbursement_rate,
    -- Outstanding
    SUM(l.outstanding_principal) AS current_outstanding,
    d.full_date AS snapshot_date
FROM sathapana_dwh.dw.fact_loan_portfolio l
JOIN sathapana_dwh.dw.dim_branch b ON l.branch_key = b.branch_key
JOIN sathapana_dwh.dw.dim_product p ON l.product_key = p.product_key
JOIN sathapana_dwh.dw.dim_customer c ON l.customer_key = c.customer_key
JOIN sathapana_dwh.dw.dim_date d ON l.snapshot_date_key = d.date_key
WHERE d.is_current_month = 1
GROUP BY 
    b.branch_code, b.branch_name, p.product_name, c.customer_segment, d.full_date;

-- ============================================================================
-- VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'CREDIT RISK DATA MART CREATED';
PRINT 'Database: sathapana_dm_credit';
PRINT '================================================';
PRINT '';
PRINT 'Views Created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm');
PRINT '';
PRINT 'Views:';
SELECT name FROM sys.views WHERE schema_id = SCHEMA_ID('dm') ORDER BY name;
PRINT '';
PRINT '================================================';
GO
