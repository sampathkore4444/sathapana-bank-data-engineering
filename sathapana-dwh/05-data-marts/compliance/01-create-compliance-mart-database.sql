-- ============================================================================
-- SATHAPANA BANK - LAYER 3: COMPLIANCE/AML DATA MART
-- ============================================================================
-- Database: sathapana_dm_compliance
-- Author: DWH Development Team
-- ============================================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'sathapana_dm_compliance')
BEGIN
    ALTER DATABASE sathapana_dm_compliance SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE sathapana_dm_compliance;
END
GO

CREATE DATABASE sathapana_dm_compliance
ON PRIMARY (
    NAME = 'sathapana_dm_compliance_dat',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_compliance_dat.mdf',
    SIZE = 100MB, MAXSIZE = 10GB, FILEGROWTH = 50MB
)
LOG ON (
    NAME = 'sathapana_dm_compliance_log',
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Data\sathapana_dm_compliance_log.ldf',
    SIZE = 50MB, MAXSIZE = 2GB, FILEGROWTH = 25MB
);
GO

USE sathapana_dm_compliance;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dm')
    EXEC('CREATE SCHEMA dm');
GO

-- ============================================================================
-- 1. AML ALERT SUMMARY VIEW
-- ============================================================================
CREATE VIEW dm.vw_aml_alert_summary AS
SELECT 
    COUNT(*) AS total_alerts,
    SUM(CASE WHEN a.status = 'NEW' THEN 1 ELSE 0 END) AS new_alerts,
    SUM(CASE WHEN a.status = 'UNDER_REVIEW' THEN 1 ELSE 0 END) AS under_review,
    SUM(CASE WHEN a.status = 'ESCALATED' THEN 1 ELSE 0 END) AS escalated,
    SUM(CASE WHEN a.status = 'CLOSED_FALSE_POSITIVE' THEN 1 ELSE 0 END) AS false_positives,
    SUM(CASE WHEN a.status = 'SAR_FILED' THEN 1 ELSE 0 END) AS sar_filed,
    AVG(a.risk_score) AS avg_risk_score,
    MAX(a.risk_score) AS max_risk_score,
    SUM(CASE WHEN a.risk_score >= 70 THEN 1 ELSE 0 END) AS high_risk_alerts,
    -- By alert type
    SUM(CASE WHEN a.alert_type = 'STRUCTURING' THEN 1 ELSE 0 END) AS structuring_alerts,
    SUM(CASE WHEN a.alert_type = 'UNUSUAL_PATTERN' THEN 1 ELSE 0 END) AS unusual_pattern_alerts,
    SUM(CASE WHEN a.alert_type = 'HIGH_VALUE' THEN 1 ELSE 0 END) AS high_value_alerts,
    SUM(CASE WHEN a.alert_type = 'SANCTIONS_MATCH' THEN 1 ELSE 0 END) AS sanctions_alerts,
    SUM(CASE WHEN a.alert_type = 'PEP_TRANSACTION' THEN 1 ELSE 0 END) AS pep_alerts
FROM sathapana_raw.raw.aml_alerts a;

-- ============================================================================
-- 2. TRANSACTION MONITORING VIEW
-- ============================================================================
CREATE VIEW dm.vw_transaction_monitoring AS
SELECT 
    c.customer_code,
    c.full_name,
    c.customer_segment,
    c.risk_rating,
    c.is_pep,
    c.is_sanctioned,
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
    -- Cash activity
    SUM(CASE WHEN t.transaction_channel IN ('COUNTER', 'ATM') THEN t.amount ELSE 0 END) AS cash_volume,
    SUM(CASE WHEN t.transaction_channel IN ('COUNTER', 'ATM') THEN 1 ELSE 0 END) AS cash_transactions,
    -- Digital activity
    SUM(CASE WHEN t.transaction_channel IN ('MOBILE', 'INTERNET') THEN t.amount ELSE 0 END) AS digital_volume
FROM sathapana_dwh.dw.dim_customer c
JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key
JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY c.customer_code, c.full_name, c.customer_segment, c.risk_rating, c.is_pep, c.is_sanctioned;

-- ============================================================================
-- 3. PEP MONITORING VIEW
-- ============================================================================
CREATE VIEW dm.vw_pep_monitoring AS
SELECT 
    c.customer_code,
    c.full_name,
    c.customer_type,
    c.customer_segment,
    c.occupation,
    c.employer_name,
    COUNT(DISTINCT a.account_key) AS total_accounts,
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_volume,
    AVG(t.amount) AS avg_transaction,
    MAX(t.amount) AS max_transaction,
    MAX(t.transaction_datetime) AS last_transaction_date,
    DATEDIFF(DAY, MAX(t.transaction_datetime), GETDATE()) AS days_since_last_transaction,
    SUM(CASE WHEN t.amount > 50000 THEN 1 ELSE 0 END) AS very_high_value_count,
    SUM(CASE WHEN t.transaction_channel = 'SWIFT' THEN 1 ELSE 0 END) AS swift_count
FROM sathapana_dwh.dw.dim_customer c
JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key
JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1 AND c.is_pep = 1
GROUP BY c.customer_code, c.full_name, c.customer_type, c.customer_segment, c.occupation, c.employer_name;

-- ============================================================================
-- 4. SANCTIONS SCREENING VIEW
-- ============================================================================
CREATE VIEW dm.vw_sanctions_screening AS
SELECT 
    c.customer_code,
    c.full_name,
    c.national_id,
    c.passport_number,
    c.customer_type,
    c.customer_segment,
    c.is_sanctioned,
    c.risk_rating,
    -- Transaction activity
    COUNT(DISTINCT t.transaction_key) AS total_transactions,
    SUM(t.amount) AS total_volume,
    MAX(t.transaction_datetime) AS last_transaction_date,
    -- Alert history
    (SELECT COUNT(*) FROM sathapana_raw.raw.aml_alerts a 
     WHERE a.customer_id = c.source_key AND a.alert_type = 'SANCTIONS_MATCH') AS sanctions_alert_count
FROM sathapana_dwh.dw.dim_customer c
LEFT JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key
LEFT JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY c.customer_code, c.full_name, c.national_id, c.passport_number, c.customer_type, c.customer_segment, c.is_sanctioned, c.risk_rating, c.source_key;

-- ============================================================================
-- 5. SUSPICIOUS PATTERN DETECTION VIEW
-- ============================================================================
CREATE VIEW dm.vw_suspicious_patterns AS
SELECT 
    c.customer_code,
    c.full_name,
    c.customer_segment,
    -- Pattern indicators
    COUNT(*) AS total_transactions,
    -- Structuring pattern (multiple transactions just below threshold)
    SUM(CASE WHEN t.amount BETWEEN 9000 AND 10000 THEN 1 ELSE 0 END) AS near_threshold_count,
    -- High frequency pattern
    COUNT(DISTINCT CAST(t.transaction_datetime AS DATE)) AS active_days,
    COUNT(*) / NULLIF(COUNT(DISTINCT CAST(t.transaction_datetime AS DATE)), 0) AS avg_daily_transactions,
    -- Round number pattern (suspicious)
    SUM(CASE WHEN t.amount % 1000 = 0 AND t.amount >= 5000 THEN 1 ELSE 0 END) AS round_number_count,
    -- Rapid movement pattern
    SUM(CASE WHEN t.transaction_channel = 'COUNTER' THEN t.amount ELSE 0 END) AS counter_volume,
    SUM(CASE WHEN t.transaction_channel = 'ATM' THEN t.amount ELSE 0 END) AS atm_volume,
    -- Risk score calculation
    (SUM(CASE WHEN t.amount BETWEEN 9000 AND 10000 THEN 1 ELSE 0 END) * 10) +
    (CASE WHEN COUNT(DISTINCT CAST(t.transaction_datetime AS DATE)) > 0 
          THEN COUNT(*) / COUNT(DISTINCT CAST(t.transaction_datetime AS DATE)) * 5 ELSE 0 END) +
    (SUM(CASE WHEN t.amount % 1000 = 0 AND t.amount >= 5000 THEN 1 ELSE 0 END) * 8) AS pattern_risk_score
FROM sathapana_dwh.dw.dim_customer c
JOIN sathapana_dwh.dw.dim_account a ON c.customer_key = a.customer_key
JOIN sathapana_dwh.dw.fact_transactions t ON a.account_key = t.account_key
WHERE c.is_current = 1
GROUP BY c.customer_code, c.full_name, c.customer_segment
HAVING 
    SUM(CASE WHEN t.amount BETWEEN 9000 AND 10000 THEN 1 ELSE 0 END) > 0
    OR (COUNT(*) / NULLIF(COUNT(DISTINCT CAST(t.transaction_datetime AS DATE)), 0) > 5);

-- ============================================================================
-- 6. BRANCH COMPLIANCE SCORE VIEW
-- ============================================================================
CREATE VIEW dm.vw_branch_compliance_score AS
SELECT 
    b.branch_code,
    b.branch_name,
    b.region,
    -- Alert metrics
    (SELECT COUNT(*) FROM sathapana_raw.raw.aml_alerts a 
     WHERE a.customer_id IN (SELECT customer_id FROM sathapana_raw.raw.customers WHERE opening_branch_id = b.branch_key)) AS total_alerts,
    -- Customer risk distribution
    COUNT(DISTINCT c.customer_key) AS total_customers,
    SUM(CASE WHEN c.risk_rating = 'HIGH' THEN 1 ELSE 0 END) AS high_risk_customers,
    SUM(CASE WHEN c.risk_rating = 'VERY_HIGH' THEN 1 ELSE 0 END) AS very_high_risk_customers,
    -- Compliance score (higher = better)
    100 - (
        (SUM(CASE WHEN c.risk_rating = 'HIGH' THEN 1 ELSE 0 END) * 2) +
        (SUM(CASE WHEN c.risk_rating = 'VERY_HIGH' THEN 1 ELSE 0 END) * 5) +
        (SUM(CASE WHEN c.is_pep = 1 THEN 1 ELSE 0 END) * 1) +
        (SUM(CASE WHEN c.is_sanctioned = 1 THEN 1 ELSE 0 END) * 10)
    ) AS compliance_score
FROM sathapana_dwh.dw.dim_branch b
LEFT JOIN sathapana_dwh.dw.dim_customer c ON b.branch_key = c.opening_branch_key AND c.is_current = 1
WHERE b.is_active = 1
GROUP BY b.branch_code, b.branch_name, b.region, b.branch_key;

-- ============================================================================
-- 7. KYC COMPLIANCE VIEW
-- ============================================================================
CREATE VIEW dm.vw_kyc_compliance AS
SELECT 
    b.branch_code,
    b.branch_name,
    -- KYC status distribution
    COUNT(DISTINCT c.customer_key) AS total_customers,
    SUM(CASE WHEN c.kyc_status = 'VERIFIED' THEN 1 ELSE 0 END) AS kyc_verified,
    SUM(CASE WHEN c.kyc_status = 'PENDING' THEN 1 ELSE 0 END) AS kyc_pending,
    SUM(CASE WHEN c.kyc_status = 'EXPIRED' THEN 1 ELSE 0 END) AS kyc_expired,
    SUM(CASE WHEN c.kyc_status = 'REJECTED' THEN 1 ELSE 0 END) AS kyc_rejected,
    -- KYC completion rate
    CASE 
        WHEN COUNT(DISTINCT c.customer_key) = 0 THEN 0
        ELSE SUM(CASE WHEN c.kyc_status = 'VERIFIED' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT c.customer_key)
    END AS kyc_completion_rate,
    -- Expiring KYC (next 30 days)
    SUM(CASE WHEN c.kyc_expiry_date BETWEEN GETDATE() AND DATEADD(DAY, 30, GETDATE()) THEN 1 ELSE 0 END) AS kyc_expiring_30d,
    SUM(CASE WHEN c.kyc_expiry_date < GETDATE() THEN 1 ELSE 0 END) AS kyc_already_expired
FROM sathapana_dwh.dw.dim_branch b
LEFT JOIN sathapana_dwh.dw.dim_customer c ON b.branch_key = c.opening_branch_key AND c.is_current = 1
WHERE b.is_active = 1
GROUP BY b.branch_code, b.branch_name;

-- ============================================================================
-- VERIFY CREATION
-- ============================================================================
PRINT '================================================';
PRINT 'COMPLIANCE/AML DATA MART CREATED';
PRINT 'Database: sathapana_dm_compliance';
PRINT '================================================';
PRINT 'Views Created:';
SELECT COUNT(*) AS view_count FROM sys.views WHERE schema_id = SCHEMA_ID('dm');
PRINT '================================================';
GO
