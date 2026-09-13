-- ============================================================================
-- SATHAPANA BANK - ETL EXTRACTION PROCEDURES
-- ============================================================================
-- Purpose: Create stored procedures for data extraction from source systems
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

USE sathapana_staging;
GO

-- ============================================================================
-- 1. MASTER EXTRACTION PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractAll
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Generate batch ID if not provided
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    -- Log batch start
    INSERT INTO staging.batch_log (batch_id, batch_name, source_system, status)
    VALUES (@BatchID, 'Full Extraction', 'ALL', 'RUNNING');
    
    PRINT 'Starting extraction for Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    
    BEGIN TRY
        -- Extract each source table
        EXEC staging.usp_ExtractBranches @BatchID;
        EXEC staging.usp_ExtractEmployees @BatchID;
        EXEC staging.usp_ExtractCustomers @BatchID;
        EXEC staging.usp_ExtractProducts @BatchID;
        EXEC staging.usp_ExtractAccounts @BatchID;
        EXEC staging.usp_ExtractTransactions @BatchID;
        EXEC staging.usp_ExtractLoans @BatchID;
        EXEC staging.usp_ExtractCards @BatchID;
        EXEC staging.usp_ExtractFXTransactions @BatchID;
        EXEC staging.usp_ExtractExchangeRates @BatchID;
        EXEC staging.usp_ExtractAMELAlerts @BatchID;
        
        -- Update batch status
        UPDATE staging.batch_log
        SET status = 'COMPLETED',
            end_time = GETDATE()
        WHERE batch_id = @BatchID;
        
        PRINT 'Extraction completed successfully.';
    END TRY
    BEGIN CATCH
        -- Update batch status on error
        UPDATE staging.batch_log
        SET status = 'FAILED',
            error_message = ERROR_MESSAGE(),
            end_time = GETDATE()
        WHERE batch_id = @BatchID;
        
        -- Log error
        INSERT INTO staging.error_log (batch_id, source_table, error_type, error_message, severity)
        VALUES (@BatchID, 'EXTRACTION', 'SYSTEM_ERROR', ERROR_MESSAGE(), 'CRITICAL');
        
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 2. EXTRACT BRANCHES
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractBranches
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting branches...';
    
    -- Truncate staging table
    TRUNCATE TABLE staging.stg_branches;
    
    -- Extract from source
    INSERT INTO staging.stg_branches (
        branch_code, branch_name, branch_name_kh, branch_type,
        region, province, district, commune, village,
        address, phone, email, manager_code, is_active,
        source_key, batch_id
    )
    SELECT 
        b.branch_code,
        b.branch_name,
        b.branch_name_kh,
        b.branch_type,
        b.region,
        b.province,
        b.district,
        b.commune,
        b.village,
        b.address,
        b.phone,
        b.email,
        e.employee_code AS manager_code,
        b.is_active,
        CAST(b.branch_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.branches b
    LEFT JOIN sathapana_source.oltp.employees e ON b.manager_id = e.employee_id;
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Log ETL step
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Branches', 'stg_branches', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' branches.';
END;
GO

-- ============================================================================
-- 3. EXTRACT EMPLOYEES
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractEmployees
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting employees...';
    
    TRUNCATE TABLE staging.stg_employees;
    
    INSERT INTO staging.stg_employees (
        employee_code, national_id, first_name, last_name,
        date_of_birth, gender, email, phone, hire_date,
        termination_date, job_title, department, branch_code,
        reports_to_code, salary_grade, is_active,
        source_key, batch_id
    )
    SELECT 
        emp.employee_code,
        emp.national_id,
        emp.first_name,
        emp.last_name,
        emp.date_of_birth,
        emp.gender,
        emp.email,
        emp.phone,
        emp.hire_date,
        emp.termination_date,
        emp.job_title,
        emp.department,
        b.branch_code,
        mgr.employee_code AS reports_to_code,
        emp.salary_grade,
        emp.is_active,
        CAST(emp.employee_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.employees emp
    JOIN sathapana_source.oltp.branches b ON emp.branch_id = b.branch_id
    LEFT JOIN sathapana_source.oltp.employees mgr ON emp.reports_to = mgr.employee_id;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Employees', 'stg_employees', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' employees.';
END;
GO

-- ============================================================================
-- 4. EXTRACT CUSTOMERS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractCustomers
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting customers...';
    
    TRUNCATE TABLE staging.stg_customers;
    
    INSERT INTO staging.stg_customers (
        customer_code, customer_type, title, first_name, last_name,
        company_name, national_id_type, national_id, passport_number,
        date_of_birth, gender, nationality, email, phone_primary,
        phone_secondary, address_line1, address_line2, province,
        district, commune, village, postal_code, customer_segment,
        risk_rating, kyc_status, kyc_verified_date, kyc_expiry_date,
        tax_id, employer_name, occupation, annual_income, marital_status,
        referrer_code, acquisition_channel, opening_branch_code,
        is_active, is_pep, is_sanctioned,
        source_key, batch_id
    )
    SELECT 
        c.customer_code,
        c.customer_type,
        c.title,
        c.first_name,
        c.last_name,
        c.company_name,
        c.national_id_type,
        c.national_id,
        c.passport_number,
        c.date_of_birth,
        c.gender,
        c.nationality,
        c.email,
        c.phone_primary,
        c.phone_secondary,
        c.address_line1,
        c.address_line2,
        c.province,
        c.district,
        c.commune,
        c.village,
        c.postal_code,
        c.customer_segment,
        c.risk_rating,
        c.kyc_status,
        c.kyc_verified_date,
        c.kyc_expiry_date,
        c.tax_id,
        c.employer_name,
        c.occupation,
        c.annual_income,
        c.marital_status,
        c.referrer_code,
        c.acquisition_channel,
        c.opening_branch_code,
        c.is_active,
        c.is_pep,
        c.is_sanctioned,
        CAST(c.customer_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.v_customer_extract c;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Customers', 'stg_customers', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' customers.';
END;
GO

-- ============================================================================
-- 5. EXTRACT PRODUCTS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractProducts
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting products...';
    
    TRUNCATE TABLE staging.stg_products;
    
    INSERT INTO staging.stg_products (
        product_code, product_name, product_name_kh, product_category,
        product_subcategory, gl_account_code, currency, interest_rate,
        min_balance, max_balance, min_amount, max_amount, term_months,
        is_active, effective_date, expiry_date,
        source_key, batch_id
    )
    SELECT 
        p.product_code,
        p.product_name,
        p.product_name_kh,
        p.product_category,
        p.product_subcategory,
        p.gl_account_code,
        p.currency,
        p.interest_rate,
        p.min_balance,
        p.max_balance,
        p.min_amount,
        p.max_amount,
        p.term_months,
        p.is_active,
        p.effective_date,
        p.expiry_date,
        CAST(p.product_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.products p;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Products', 'stg_products', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' products.';
END;
GO

-- ============================================================================
-- 6. EXTRACT ACCOUNTS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractAccounts
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting accounts...';
    
    TRUNCATE TABLE staging.stg_accounts;
    
    INSERT INTO staging.stg_accounts (
        account_number, customer_code, product_code, branch_code,
        currency, account_type, account_status, open_date, close_date,
        maturity_date, balance, available_balance, hold_amount,
        credit_limit, interest_rate, last_transaction_date,
        dormant_date, is_active,
        source_key, batch_id
    )
    SELECT 
        a.account_number,
        a.customer_code,
        a.product_code,
        a.branch_code,
        a.currency,
        a.account_type,
        a.account_status,
        a.open_date,
        a.close_date,
        a.maturity_date,
        a.balance,
        a.available_balance,
        0 AS hold_amount,
        a.credit_limit,
        a.interest_rate,
        a.last_transaction_date,
        NULL AS dormant_date,
        a.is_active,
        CAST(a.account_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.v_account_extract a;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Accounts', 'stg_accounts', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' accounts.';
END;
GO

-- ============================================================================
-- 7. EXTRACT TRANSACTIONS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractTransactions
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    DECLARE @LastExtractDate DATETIME;
    
    PRINT 'Extracting transactions...';
    
    -- Get last extract date for incremental load
    SELECT @LastExtractDate = last_extract_date
    FROM staging.etl_control
    WHERE source_table = 'transactions';
    
    -- If first extract, get all data
    IF @LastExtractDate IS NULL
        SET @LastExtractDate = '1900-01-01';
    
    TRUNCATE TABLE staging.stg_transactions;
    
    INSERT INTO staging.stg_transactions (
        transaction_code, account_number, customer_code, transaction_type,
        transaction_channel, transaction_date, value_date, amount,
        currency, exchange_rate, balance_before, balance_after,
        fee_amount, tax_amount, description, reference_number,
        counterparty_account, counterparty_bank, status,
        posted_by_code, branch_code,
        source_key, batch_id
    )
    SELECT 
        t.transaction_code,
        a.account_number,
        c.customer_code,
        t.transaction_type,
        t.transaction_channel,
        t.transaction_date,
        t.value_date,
        t.amount,
        t.currency,
        t.exchange_rate,
        t.balance_before,
        t.balance_after,
        t.fee_amount,
        t.tax_amount,
        t.description,
        t.reference_number,
        t.counterparty_account,
        t.counterparty_bank,
        t.status,
        emp.employee_code AS posted_by_code,
        b.branch_code,
        CAST(t.transaction_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.transactions t
    JOIN sathapana_source.oltp.accounts a ON t.account_id = a.account_id
    JOIN sathapana_source.oltp.customers c ON a.customer_id = c.customer_id
    JOIN sathapana_source.oltp.branches b ON t.branch_id = b.branch_id
    LEFT JOIN sathapana_source.oltp.employees emp ON t.posted_by = emp.employee_id
    WHERE t.created_date > @LastExtractDate;
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Update last extract date
    UPDATE staging.etl_control
    SET last_extract_date = GETDATE(),
        last_extract_key = (SELECT MAX(transaction_id) FROM sathapana_source.oltp.transactions),
        row_count = @RecordCount,
        status = 'EXTRACTED'
    WHERE source_table = 'transactions';
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Transactions', 'stg_transactions', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' transactions.';
END;
GO

-- ============================================================================
-- 8. EXTRACT LOANS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractLoans
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting loans...';
    
    TRUNCATE TABLE staging.stg_loans;
    
    INSERT INTO staging.stg_loans (
        loan_number, application_number, customer_code, product_code,
        branch_code, loan_amount, approved_amount, disbursed_amount,
        outstanding_principal, interest_rate, interest_type, term_months,
        emi_amount, disbursement_date, maturity_date, first_payment_date,
        loan_status, collateral_type, collateral_value, guarantee_amount,
        provision_amount, days_past_due, risk_classification,
        relationship_officer_code, approval_date, approval_authority,
        source_key, batch_id
    )
    SELECT 
        l.loan_number,
        l.application_number,
        l.customer_code,
        l.product_code,
        l.branch_code,
        l.loan_amount,
        l.approved_amount,
        l.disbursed_amount,
        l.outstanding_principal,
        l.interest_rate,
        l.interest_type,
        l.term_months,
        l.emi_amount,
        l.disbursement_date,
        l.maturity_date,
        l.first_payment_date,
        l.loan_status,
        l.collateral_type,
        l.collateral_value,
        l.guarantee_amount,
        l.provision_amount,
        l.days_past_due,
        l.risk_classification,
        l.relationship_officer_code,
        l.approval_date,
        l.approval_authority,
        CAST(l.loan_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.v_loan_extract l;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Loans', 'stg_loans', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' loans.';
END;
GO

-- ============================================================================
-- 9. EXTRACT CARDS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractCards
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting cards...';
    
    TRUNCATE TABLE staging.stg_cards;
    
    INSERT INTO staging.stg_cards (
        card_number_masked, card_token, customer_code, account_number,
        card_type, card_brand, card_class, issue_date, expiry_date,
        credit_limit, current_balance, available_credit, card_status,
        daily_limit, monthly_limit,
        source_key, batch_id
    )
    SELECT 
        c.card_number,
        c.card_token,
        cust.customer_code,
        a.account_number,
        c.card_type,
        c.card_brand,
        c.card_class,
        c.issue_date,
        c.expiry_date,
        c.credit_limit,
        c.current_balance,
        c.available_credit,
        c.card_status,
        c.daily_limit,
        c.monthly_limit,
        CAST(c.card_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.cards c
    JOIN sathapana_source.oltp.customers cust ON c.customer_id = cust.customer_id
    JOIN sathapana_source.oltp.accounts a ON c.account_id = a.account_id;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_Cards', 'stg_cards', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' cards.';
END;
GO

-- ============================================================================
-- 10. EXTRACT FX TRANSACTIONS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractFXTransactions
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting FX transactions...';
    
    TRUNCATE TABLE staging.stg_fx_transactions;
    
    INSERT INTO staging.stg_fx_transactions (
        fx_code, customer_code, account_number, transaction_type,
        source_currency, target_currency, source_amount, target_amount,
        exchange_rate, spread, profit_amount, transaction_date,
        value_date, counterparty, settlement_status, branch_code,
        source_key, batch_id
    )
    SELECT 
        fx.fx_code,
        c.customer_code,
        a.account_number,
        fx.transaction_type,
        fx.source_currency,
        fx.target_currency,
        fx.source_amount,
        fx.target_amount,
        fx.exchange_rate,
        fx.spread,
        fx.profit_amount,
        fx.transaction_date,
        fx.value_date,
        fx.counterparty,
        fx.settlement_status,
        b.branch_code,
        CAST(fx.fx_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.fx_transactions fx
    LEFT JOIN sathapana_source.oltp.customers c ON fx.customer_id = c.customer_id
    LEFT JOIN sathapana_source.oltp.accounts a ON fx.account_id = a.account_id
    JOIN sathapana_source.oltp.branches b ON fx.branch_id = b.branch_id;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_FXTransactions', 'stg_fx_transactions', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' FX transactions.';
END;
GO

-- ============================================================================
-- 11. EXCHANGE RATES
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractExchangeRates
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting exchange rates...';
    
    TRUNCATE TABLE staging.stg_exchange_rates;
    
    INSERT INTO staging.stg_exchange_rates (
        source_currency, target_currency, rate, bid_rate, ask_rate,
        rate_date, source_key, batch_id
    )
    SELECT 
        er.source_currency,
        er.target_currency,
        er.rate,
        er.bid_rate,
        er.ask_rate,
        er.rate_date,
        CAST(er.rate_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.exchange_rates er;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_ExchangeRates', 'stg_exchange_rates', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' exchange rates.';
END;
GO

-- ============================================================================
-- 12. EXTRACT AML ALERTS
-- ============================================================================
CREATE OR ALTER PROCEDURE staging.usp_ExtractAMELAlerts
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting AML alerts...';
    
    TRUNCATE TABLE staging.stg_aml_alerts;
    
    INSERT INTO staging.stg_aml_alerts (
        alert_code, customer_code, transaction_code, alert_type,
        alert_description, risk_score, status, assigned_to_code,
        review_date, resolution_notes, sar_reference,
        source_key, batch_id
    )
    SELECT 
        a.alert_code,
        c.customer_code,
        t.transaction_code,
        a.alert_type,
        a.alert_description,
        a.risk_score,
        a.status,
        emp.employee_code AS assigned_to_code,
        a.review_date,
        a.resolution_notes,
        a.sar_reference,
        CAST(a.alert_id AS VARCHAR(50)),
        @BatchID
    FROM sathapana_source.oltp.aml_alerts a
    LEFT JOIN sathapana_source.oltp.customers c ON a.customer_id = c.customer_id
    LEFT JOIN sathapana_source.oltp.transactions t ON a.transaction_id = t.transaction_id
    LEFT JOIN sathapana_source.oltp.employees emp ON a.assigned_to = emp.employee_id;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Extract_AMELAlerts', 'stg_aml_alerts', 'EXTRACT', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' AML alerts.';
END;
GO

-- ============================================================================
-- 13. VERIFY EXTRACTION PROCEDURES
-- ============================================================================
PRINT '================================================';
PRINT 'EXTRACTION PROCEDURES CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Procedures created:';
SELECT COUNT(*) AS procedure_count 
FROM sys.procedures 
WHERE schema_id = SCHEMA_ID('staging') 
AND name LIKE 'usp_Extract%';
PRINT '';
PRINT '================================================';
GO
