-- ============================================================================
-- SATHAPANA BANK - LAYERED ARCHITECTURE: MASTER ORCHESTRATION
-- ============================================================================
-- Purpose: Run complete ETL pipeline for all layers
-- Architecture: Enterprise Layered Pattern (7 databases, 1 instance)
-- Author: DWH Development Team
-- ============================================================================

/*
LAYERED ARCHITECTURE OVERVIEW:
═══════════════════════════════════════════════════════════════════

Layer 0: Source Systems
  └── sathapana_source (OLTP simulation)

Layer 1: Raw Zone (Source Copy)
  └── sathapana_raw (exact copy, no transformations)

Layer 2: Curated Zone (Enterprise DW)
  └── sathapana_dwh (dimensions, facts, business rules)

Layer 3: Serving Zone (Data Marts)
  ├── sathapana_dm_credit (Credit Risk)
  ├── sathapana_dm_customer (Customer Analytics)
  ├── sathapana_dm_treasury (Treasury)
  └── sathapana_dm_compliance (AML/Compliance)

═══════════════════════════════════════════════════════════════════
*/

-- ============================================================================
-- EXECUTION ORDER
-- ============================================================================
PRINT '================================================';
PRINT 'SATHAPANA BANK - LAYERED ARCHITECTURE PIPELINE';
PRINT '================================================';
PRINT '';
PRINT 'EXECUTION ORDER:';
PRINT '1. Create all databases (run setup scripts first)';
PRINT '2. Run this orchestration script';
PRINT '';

DECLARE @PipelineStart DATETIME = GETDATE();
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();

PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
PRINT 'Start Time: ' + CONVERT(VARCHAR, @PipelineStart, 120);
PRINT '';

-- ============================================================================
-- PHASE 1: EXTRACT TO RAW ZONE (Layer 0 → Layer 1)
-- ============================================================================
PRINT '═══════════════════════════════════════════════════════════════';
PRINT 'PHASE 1: EXTRACT TO RAW ZONE (Layer 0 → Layer 1)';
PRINT '═══════════════════════════════════════════════════════════════';

BEGIN TRY
    PRINT 'Extracting source data to Raw Zone...';
    
    -- Truncate raw tables
    TRUNCATE TABLE sathapana_raw.raw.branches;
    TRUNCATE TABLE sathapana_raw.raw.employees;
    TRUNCATE TABLE sathapana_raw.raw.customers;
    TRUNCATE TABLE sathapana_raw.raw.products;
    TRUNCATE TABLE sathapana_raw.raw.accounts;
    TRUNCATE TABLE sathapana_raw.raw.transactions;
    TRUNCATE TABLE sathapana_raw.raw.loans;
    TRUNCATE TABLE sathapana_raw.raw.cards;
    TRUNCATE TABLE sathapana_raw.raw.fx_transactions;
    TRUNCATE TABLE sathapana_raw.raw.exchange_rates;
    TRUNCATE TABLE sathapana_raw.raw.aml_alerts;
    
    -- Copy branches
    INSERT INTO sathapana_raw.raw.branches (branch_id, branch_code, branch_name, branch_name_kh, branch_type, region, province, district, commune, village, address, phone, email, manager_id, is_active, created_date, modified_date)
    SELECT branch_id, branch_code, branch_name, branch_name_kh, branch_type, region, province, district, commune, village, address, phone, email, manager_id, is_active, created_date, modified_date
    FROM sathapana_source.oltp.branches;
    PRINT '✓ Branches extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy employees
    INSERT INTO sathapana_raw.raw.employees (employee_id, employee_code, national_id, first_name, last_name, date_of_birth, gender, email, phone, hire_date, termination_date, job_title, department, branch_id, reports_to, salary_grade, is_active, created_date, modified_date)
    SELECT employee_id, employee_code, national_id, first_name, last_name, date_of_birth, gender, email, phone, hire_date, termination_date, job_title, department, branch_id, reports_to, salary_grade, is_active, created_date, modified_date
    FROM sathapana_source.oltp.employees;
    PRINT '✓ Employees extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy customers
    INSERT INTO sathapana_raw.raw.customers (customer_id, customer_code, customer_type, title, first_name, last_name, company_name, national_id_type, national_id, passport_number, date_of_birth, gender, nationality, email, phone_primary, phone_secondary, address_line1, address_line2, province, district, commune, village, postal_code, customer_segment, risk_rating, kyc_status, kyc_verified_date, kyc_expiry_date, tax_id, employer_name, occupation, annual_income, marital_status, referrer_code, acquisition_channel, opening_branch_id, is_active, is_pep, is_sanctioned, created_date, modified_date)
    SELECT customer_id, customer_code, customer_type, title, first_name, last_name, company_name, national_id_type, national_id, passport_number, date_of_birth, gender, nationality, email, phone_primary, phone_secondary, address_line1, address_line2, province, district, commune, village, postal_code, customer_segment, risk_rating, kyc_status, kyc_verified_date, kyc_expiry_date, tax_id, employer_name, occupation, annual_income, marital_status, referrer_code, acquisition_channel, opening_branch_id, is_active, is_pep, is_sanctioned, created_date, modified_date
    FROM sathapana_source.oltp.customers;
    PRINT '✓ Customers extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy products
    INSERT INTO sathapana_raw.raw.products (product_id, product_code, product_name, product_name_kh, product_category, product_subcategory, gl_account_code, currency, interest_rate, min_balance, max_balance, min_amount, max_amount, term_months, is_active, effective_date, expiry_date, created_date, modified_date)
    SELECT product_id, product_code, product_name, product_name_kh, product_category, product_subcategory, gl_account_code, currency, interest_rate, min_balance, max_balance, min_amount, max_amount, term_months, is_active, effective_date, expiry_date, created_date, modified_date
    FROM sathapana_source.oltp.products;
    PRINT '✓ Products extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy accounts
    INSERT INTO sathapana_raw.raw.accounts (account_id, account_number, customer_id, product_id, branch_id, currency, account_type, account_status, open_date, close_date, maturity_date, balance, available_balance, hold_amount, credit_limit, interest_rate, last_transaction_date, dormant_date, created_date, modified_date)
    SELECT account_id, account_number, customer_id, product_id, branch_id, currency, account_type, account_status, open_date, close_date, maturity_date, balance, available_balance, hold_amount, credit_limit, interest_rate, last_transaction_date, dormant_date, created_date, modified_date
    FROM sathapana_source.oltp.accounts;
    PRINT '✓ Accounts extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy transactions
    INSERT INTO sathapana_raw.raw.transactions (transaction_id, transaction_code, account_id, transaction_type, transaction_channel, transaction_date, value_date, amount, currency, exchange_rate, balance_before, balance_after, fee_amount, tax_amount, description, reference_number, counterparty_account, counterparty_bank, status, posted_by, authorized_by, branch_id, created_date)
    SELECT transaction_id, transaction_code, account_id, transaction_type, transaction_channel, transaction_date, value_date, amount, currency, exchange_rate, balance_before, balance_after, fee_amount, tax_amount, description, reference_number, counterparty_account, counterparty_bank, status, posted_by, authorized_by, branch_id, created_date
    FROM sathapana_source.oltp.transactions;
    PRINT '✓ Transactions extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy loans
    INSERT INTO sathapana_raw.raw.loans (loan_id, loan_number, application_number, customer_id, product_id, branch_id, loan_amount, approved_amount, disbursed_amount, outstanding_principal, interest_rate, interest_type, term_months, emi_amount, disbursement_date, maturity_date, first_payment_date, loan_status, collateral_type, collateral_value, guarantee_amount, provision_amount, days_past_due, risk_classification, relationship_officer_id, approval_date, approval_authority, created_date, modified_date)
    SELECT loan_id, loan_number, application_number, customer_id, product_id, branch_id, loan_amount, approved_amount, disbursed_amount, outstanding_principal, interest_rate, interest_type, term_months, emi_amount, disbursement_date, maturity_date, first_payment_date, loan_status, collateral_type, collateral_value, guarantee_amount, provision_amount, days_past_due, risk_classification, relationship_officer_id, approval_date, approval_authority, created_date, modified_date
    FROM sathapana_source.oltp.loans;
    PRINT '✓ Loans extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy exchange rates
    INSERT INTO sathapana_raw.raw.exchange_rates (rate_id, source_currency, target_currency, rate, bid_rate, ask_rate, rate_date, created_date)
    SELECT rate_id, source_currency, target_currency, rate, bid_rate, ask_rate, rate_date, created_date
    FROM sathapana_source.oltp.exchange_rates;
    PRINT '✓ Exchange rates extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    -- Copy AML alerts
    INSERT INTO sathapana_raw.raw.aml_alerts (alert_id, alert_code, customer_id, transaction_id, alert_type, alert_description, risk_score, status, assigned_to, review_date, resolution_notes, sar_reference, created_date, modified_date)
    SELECT alert_id, alert_code, customer_id, transaction_id, alert_type, alert_description, risk_score, status, assigned_to, review_date, resolution_notes, sar_reference, created_date, modified_date
    FROM sathapana_source.oltp.aml_alerts;
    PRINT '✓ AML alerts extracted: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' rows';
    
    PRINT '';
    PRINT '✓ PHASE 1 COMPLETED: Raw Zone loaded successfully';
END TRY
BEGIN CATCH
    PRINT '✗ PHASE 1 FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH

-- ============================================================================
-- PHASE 2: TRANSFORM & LOAD TO CURATED ZONE (Layer 1 → Layer 2)
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════';
PRINT 'PHASE 2: TRANSFORM & LOAD TO CURATED ZONE (Layer 1 → Layer 2)';
PRINT '═══════════════════════════════════════════════════════════════';

BEGIN TRY
    -- Run extraction to staging
    PRINT 'Running staging extraction...';
    EXEC sathapana_staging.staging.usp_ExtractAll @BatchID;
    
    -- Run transformation and loading to DW
    PRINT 'Running transformation and loading to DW...';
    EXEC sathapana_dwh.dw.usp_LoadAll @BatchID;
    
    PRINT '';
    PRINT '✓ PHASE 2 COMPLETED: Curated Zone loaded successfully';
END TRY
BEGIN CATCH
    PRINT '✗ PHASE 2 FAILED: ' + ERROR_MESSAGE();
    THROW;
END CATCH

-- ============================================================================
-- PHASE 3: DATA QUALITY CHECKS
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════';
PRINT 'PHASE 3: DATA QUALITY CHECKS';
PRINT '═══════════════════════════════════════════════════════════════';

BEGIN TRY
    EXEC sathapana_dwh.audit.usp_RunDataQualityChecks @BatchID;
    PRINT '✓ PHASE 3 COMPLETED: Data quality checks passed';
END TRY
BEGIN CATCH
    PRINT '⚠ PHASE 3 WARNING: ' + ERROR_MESSAGE();
END CATCH

-- ============================================================================
-- PHASE 4: VERIFY DATA MARTS (Layer 3)
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════';
PRINT 'PHASE 4: VERIFY DATA MARTS (Layer 3)';
PRINT '═══════════════════════════════════════════════════════════════';

-- Verify Credit Mart
PRINT '';
PRINT '--- Credit Risk Mart (sathapana_dm_credit) ---';
BEGIN TRY
    SELECT COUNT(*) AS credit_mart_views FROM sathapana_dm_credit.dm.sys.views;
    SELECT TOP 3 * FROM sathapana_dm_credit.dm.vw_credit_risk_summary;
    PRINT '✓ Credit Mart verified';
END TRY
BEGIN CATCH
    PRINT '⚠ Credit Mart: ' + ERROR_MESSAGE();
END CATCH

-- Verify Customer Mart
PRINT '';
PRINT '--- Customer Analytics Mart (sathapana_dm_customer) ---';
BEGIN TRY
    SELECT COUNT(*) AS customer_mart_views FROM sathapana_dm_customer.dm.sys.views;
    SELECT TOP 3 * FROM sathapana_dm_customer.dm.vw_customer_segmentation;
    PRINT '✓ Customer Mart verified';
END TRY
BEGIN CATCH
    PRINT '⚠ Customer Mart: ' + ERROR_MESSAGE();
END CATCH

-- Verify Treasury Mart
PRINT '';
PRINT '--- Treasury Mart (sathapana_dm_treasury) ---';
BEGIN TRY
    SELECT COUNT(*) AS treasury_mart_views FROM sathapana_dm_treasury.dm.sys.views;
    SELECT TOP 3 * FROM sathapana_dm_treasury.dm.vw_deposit_mobilization;
    PRINT '✓ Treasury Mart verified';
END TRY
BEGIN CATCH
    PRINT '⚠ Treasury Mart: ' + ERROR_MESSAGE();
END CATCH

-- Verify Compliance Mart
PRINT '';
PRINT '--- Compliance Mart (sathapana_dm_compliance) ---';
BEGIN TRY
    SELECT COUNT(*) AS compliance_mart_views FROM sathapana_dm_compliance.dm.sys.views;
    SELECT TOP 3 * FROM sathapana_dm_compliance.dm.vw_aml_alert_summary;
    PRINT '✓ Compliance Mart verified';
END TRY
BEGIN CATCH
    PRINT '⚠ Compliance Mart: ' + ERROR_MESSAGE();
END CATCH

-- ============================================================================
-- PHASE 5: GENERATE SUMMARY REPORT
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════';
PRINT 'PHASE 5: PIPELINE EXECUTION SUMMARY';
PRINT '═══════════════════════════════════════════════════════════════';

DECLARE @PipelineEnd DATETIME = GETDATE();
DECLARE @Duration INT = DATEDIFF(SECOND, @PipelineStart, @PipelineEnd);

PRINT '';
PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
PRINT 'Start Time: ' + CONVERT(VARCHAR, @PipelineStart, 120);
PRINT 'End Time: ' + CONVERT(VARCHAR, @PipelineEnd, 120);
PRINT 'Duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
PRINT '';

-- Data Summary by Layer
PRINT '--- DATA SUMMARY BY LAYER ---';
PRINT '';

PRINT 'Layer 1 (Raw Zone):';
SELECT '  Branches' AS entity, COUNT(*) AS count FROM sathapana_raw.raw.branches
UNION ALL
SELECT '  Customers', COUNT(*) FROM sathapana_raw.raw.customers
UNION ALL
SELECT '  Accounts', COUNT(*) FROM sathapana_raw.raw.accounts
UNION ALL
SELECT '  Transactions', COUNT(*) FROM sathapana_raw.raw.transactions
UNION ALL
SELECT '  Loans', COUNT(*) FROM sathapana_raw.raw.loans;

PRINT '';
PRINT 'Layer 2 (Curated Zone):';
SELECT '  Dim Branches' AS entity, COUNT(*) AS count FROM sathapana_dwh.dw.dim_branch WHERE is_current = 1
UNION ALL
SELECT '  Dim Customers', COUNT(*) FROM sathapana_dwh.dw.dim_customer WHERE is_current = 1
UNION ALL
SELECT '  Dim Accounts', COUNT(*) FROM sathapana_dwh.dw.dim_account WHERE is_current = 1
UNION ALL
SELECT '  Fact Transactions', COUNT(*) FROM sathapana_dwh.dw.fact_transactions
UNION ALL
SELECT '  Fact Loan Portfolio', COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio;

PRINT '';
PRINT 'Layer 3 (Serving Zone - Data Marts):';
SELECT '  Credit Mart Views' AS entity, COUNT(*) AS count FROM sathapana_dm_credit.dm.sys.views
UNION ALL
SELECT '  Customer Mart Views', COUNT(*) FROM sathapana_dm_customer.dm.sys.views
UNION ALL
SELECT '  Treasury Mart Views', COUNT(*) FROM sathapana_dm_treasury.dm.sys.views
UNION ALL
SELECT '  Compliance Mart Views', COUNT(*) FROM sathapana_dm_compliance.dm.sys.views;

PRINT '';
PRINT '═══════════════════════════════════════════════════════════════';
PRINT '✓ LAYERED ARCHITECTURE PIPELINE COMPLETED SUCCESSFULLY';
PRINT '═══════════════════════════════════════════════════════════════';
PRINT '';
PRINT 'DATABASES CREATED:';
PRINT '  1. sathapana_source (Layer 0 - Source)';
PRINT '  2. sathapana_raw (Layer 1 - Raw Zone)';
PRINT '  3. sathapana_staging (Staging)';
PRINT '  4. sathapana_dwh (Layer 2 - Curated Zone)';
PRINT '  5. sathapana_dm_credit (Layer 3 - Credit Mart)';
PRINT '  6. sathapana_dm_customer (Layer 3 - Customer Mart)';
PRINT '  7. sathapana_dm_treasury (Layer 3 - Treasury Mart)';
PRINT '  8. sathapana_dm_compliance (Layer 3 - Compliance Mart)';
PRINT '';
PRINT 'TOTAL: 8 Databases on 1 SQL Server Instance';
PRINT '';
GO
