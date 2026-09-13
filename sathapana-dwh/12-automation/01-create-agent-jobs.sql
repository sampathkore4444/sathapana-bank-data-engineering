-- ============================================================================
-- SATHAPANA BANK - SQL SERVER AGENT JOBS
-- ============================================================================
-- Purpose: Create automated jobs for daily ETL pipeline execution
-- Author: DWH Development Team
-- Schedule: Daily at 2:00 AM (Source Time)
-- ============================================================================

USE msdb;
GO

-- ============================================================================
-- 1. CREATE OPERATOR (for notifications)
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sysoperators WHERE name = 'DWH_Operator')
BEGIN
    EXEC sp_add_operator 
        @name = N'DWH_Operator',
        @enabled = 1,
        @email_address = N'dwh-admin@sathapana.com.kh',
        @category_name = N'[Uncategorized]';
    PRINT '✓ Operator DWH_Operator created';
END
GO

-- ============================================================================
-- 2. CREATE ALERT (for job failures)
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sysalerts WHERE name = 'DWH_Job_Failure_Alert')
BEGIN
    EXEC sp_add_alert 
        @name = N'DWH_Job_Failure_Alert',
        @message_id = 0,
        @severity = 2,
        @enabled = 1,
        @delay_between_responses = 60,
        @include_event_description_in = 1,
        @job_name = N'DWH_00_Master_Pipeline';
    PRINT '✓ Alert DWH_Job_Failure_Alert created';
END
GO

-- ============================================================================
-- 3. MASTER PIPELINE JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_00_Master_Pipeline')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_00_Master_Pipeline';
END

EXEC sp_add_job 
    @job_name = N'DWH_00_Master_Pipeline',
    @enabled = 1,
    @description = N'Master job that orchestrates the complete DWH ETL pipeline',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator',
    @owner_login_name = N'sa';

-- Add job step: Call master stored procedure
EXEC sp_add_jobstep 
    @job_name = N'DWH_00_Master_Pipeline',
    @step_name = N'Execute_Master_Pipeline',
    @subsystem = N'TSQL',
    @command = N'
-- Log job start
INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, status, start_time)
VALUES (NEWID(), ''Master_Pipeline'', ''STARTED'', GETDATE());

-- Execute master pipeline
EXEC sathapana_dwh.dbo.usp_Master_ETL_Pipeline;

-- Log job completion
UPDATE sathapana_dwh.audit.etl_log
SET status = ''COMPLETED'', end_time = GETDATE()
WHERE step_name = ''Master_Pipeline''
AND status = ''STARTED''
AND batch_id = (SELECT MAX(batch_id) FROM sathapana_dwh.audit.etl_log WHERE step_name = ''Master_Pipeline'');
',
    @database_name = N'sathapana_dwh',
    @retry_attempts = 3,
    @retry_interval = 5;

-- Add schedule: Daily at 2:00 AM
EXEC sp_add_jobschedule 
    @job_name = N'DWH_00_Master_Pipeline',
    @name = N'Daily_2AM',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @active_start_time = 020000;  -- 2:00 AM

PRINT '✓ Master Pipeline job created';
GO

-- ============================================================================
-- 4. EXTRACT TO RAW ZONE JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_01_Extract_to_Raw')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_01_Extract_to_Raw';
END

EXEC sp_add_job 
    @job_name = N'DWH_01_Extract_to_Raw',
    @enabled = 1,
    @description = N'Extract data from source systems to Raw Zone (Layer 0 → Layer 1)',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator',
    @owner_login_name = N'sa';

EXEC sp_add_jobstep 
    @job_name = N'DWH_01_Extract_to_Raw',
    @step_name = N'Extract_Source_to_Raw',
    @subsystem = N'TSQL',
    @command = N'
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @RecordCount BIGINT;

-- Log extraction start
INSERT INTO sathapana_dwh.audit.etl_log (batch_id, step_name, table_name, operation, status, start_time)
VALUES (@BatchID, ''Extract_to_Raw'', ''ALL'', ''EXTRACT'', ''STARTED'', @StartTime);

BEGIN TRY
    -- Truncate raw tables
    TRUNCATE TABLE sathapana_raw.raw.branches;
    TRUNCATE TABLE sathapana_raw.raw.employees;
    TRUNCATE TABLE sathapana_raw.raw.customers;
    TRUNCATE TABLE sathapana_raw.raw.products;
    TRUNCATE TABLE sathapana_raw.raw.accounts;
    TRUNCATE TABLE sathapana_raw.raw.transactions;
    TRUNCATE TABLE sathapana_raw.raw.loans;
    TRUNCATE TABLE sathapana_raw.raw.exchange_rates;
    TRUNCATE TABLE sathapana_raw.raw.aml_alerts;
    
    -- Extract branches
    INSERT INTO sathapana_raw.raw.branches (branch_id, branch_code, branch_name, branch_name_kh, branch_type, region, province, district, commune, village, address, phone, email, manager_id, is_active, created_date, modified_date)
    SELECT branch_id, branch_code, branch_name, branch_name_kh, branch_type, region, province, district, commune, village, address, phone, email, manager_id, is_active, created_date, modified_date
    FROM sathapana_source.oltp.branches;
    
    -- Extract employees
    INSERT INTO sathapana_raw.raw.employees (employee_id, employee_code, national_id, first_name, last_name, date_of_birth, gender, email, phone, hire_date, termination_date, job_title, department, branch_id, reports_to, salary_grade, is_active, created_date, modified_date)
    SELECT employee_id, employee_code, national_id, first_name, last_name, date_of_birth, gender, email, phone, hire_date, termination_date, job_title, department, branch_id, reports_to, salary_grade, is_active, created_date, modified_date
    FROM sathapana_source.oltp.employees;
    
    -- Extract customers
    INSERT INTO sathapana_raw.raw.customers (customer_id, customer_code, customer_type, title, first_name, last_name, company_name, national_id_type, national_id, passport_number, date_of_birth, gender, nationality, email, phone_primary, phone_secondary, address_line1, address_line2, province, district, commune, village, postal_code, customer_segment, risk_rating, kyc_status, kyc_verified_date, kyc_expiry_date, tax_id, employer_name, occupation, annual_income, marital_status, referrer_code, acquisition_channel, opening_branch_id, is_active, is_pep, is_sanctioned, created_date, modified_date)
    SELECT customer_id, customer_code, customer_type, title, first_name, last_name, company_name, national_id_type, national_id, passport_number, date_of_birth, gender, nationality, email, phone_primary, phone_secondary, address_line1, address_line2, province, district, commune, village, postal_code, customer_segment, risk_rating, kyc_status, kyc_verified_date, kyc_expiry_date, tax_id, employer_name, occupation, annual_income, marital_status, referrer_code, acquisition_channel, opening_branch_id, is_active, is_pep, is_sanctioned, created_date, modified_date
    FROM sathapana_source.oltp.customers;
    
    -- Extract products
    INSERT INTO sathapana_raw.raw.products (product_id, product_code, product_name, product_name_kh, product_category, product_subcategory, gl_account_code, currency, interest_rate, min_balance, max_balance, min_amount, max_amount, term_months, is_active, effective_date, expiry_date, created_date, modified_date)
    SELECT product_id, product_code, product_name, product_name_kh, product_category, product_subcategory, gl_account_code, currency, interest_rate, min_balance, max_balance, min_amount, max_amount, term_months, is_active, effective_date, expiry_date, created_date, modified_date
    FROM sathapana_source.oltp.products;
    
    -- Extract accounts
    INSERT INTO sathapana_raw.raw.accounts (account_id, account_number, customer_id, product_id, branch_id, currency, account_type, account_status, open_date, close_date, maturity_date, balance, available_balance, hold_amount, credit_limit, interest_rate, last_transaction_date, dormant_date, created_date, modified_date)
    SELECT account_id, account_number, customer_id, product_id, branch_id, currency, account_type, account_status, open_date, close_date, maturity_date, balance, available_balance, hold_amount, credit_limit, interest_rate, last_transaction_date, dormant_date, created_date, modified_date
    FROM sathapana_source.oltp.accounts;
    
    -- Extract transactions
    INSERT INTO sathapana_raw.raw.transactions (transaction_id, transaction_code, account_id, transaction_type, transaction_channel, transaction_date, value_date, amount, currency, exchange_rate, balance_before, balance_after, fee_amount, tax_amount, description, reference_number, counterparty_account, counterparty_bank, status, posted_by, authorized_by, branch_id, created_date)
    SELECT transaction_id, transaction_code, account_id, transaction_type, transaction_channel, transaction_date, value_date, amount, currency, exchange_rate, balance_before, balance_after, fee_amount, tax_amount, description, reference_number, counterparty_account, counterparty_bank, status, posted_by, authorized_by, branch_id, created_date
    FROM sathapana_source.oltp.transactions;
    
    -- Extract loans
    INSERT INTO sathapana_raw.raw.loans (loan_id, loan_number, application_number, customer_id, product_id, branch_id, loan_amount, approved_amount, disbursed_amount, outstanding_principal, interest_rate, interest_type, term_months, emi_amount, disbursement_date, maturity_date, first_payment_date, loan_status, collateral_type, collateral_value, guarantee_amount, provision_amount, days_past_due, risk_classification, relationship_officer_id, approval_date, approval_authority, created_date, modified_date)
    SELECT loan_id, loan_number, application_number, customer_id, product_id, branch_id, loan_amount, approved_amount, disbursed_amount, outstanding_principal, interest_rate, interest_type, term_months, emi_amount, disbursement_date, maturity_date, first_payment_date, loan_status, collateral_type, collateral_value, guarantee_amount, provision_amount, days_past_due, risk_classification, relationship_officer_id, approval_date, approval_authority, created_date, modified_date
    FROM sathapana_source.oltp.loans;
    
    -- Extract exchange rates
    INSERT INTO sathapana_raw.raw.exchange_rates (rate_id, source_currency, target_currency, rate, bid_rate, ask_rate, rate_date, created_date)
    SELECT rate_id, source_currency, target_currency, rate, bid_rate, ask_rate, rate_date, created_date
    FROM sathapana_source.oltp.exchange_rates;
    
    -- Extract AML alerts
    INSERT INTO sathapana_raw.raw.aml_alerts (alert_id, alert_code, customer_id, transaction_id, alert_type, alert_description, risk_score, status, assigned_to, review_date, resolution_notes, sar_reference, created_date, modified_date)
    SELECT alert_id, alert_code, customer_id, transaction_id, alert_type, alert_description, risk_score, status, assigned_to, review_date, resolution_notes, sar_reference, created_date, modified_date
    FROM sathapana_source.oltp.aml_alerts;
    
    -- Log success
    UPDATE sathapana_dwh.audit.etl_log
    SET status = ''COMPLETED'', end_time = GETDATE(),
        records_affected = (SELECT COUNT(*) FROM sathapana_raw.raw.transactions)
    WHERE batch_id = @BatchID AND step_name = ''Extract_to_Raw'';
    
END TRY
BEGIN CATCH
    -- Log failure
    UPDATE sathapana_dwh.audit.etl_log
    SET status = ''FAILED'', end_time = GETDATE(),
        error_message = ERROR_MESSAGE()
    WHERE batch_id = @BatchID AND step_name = ''Extract_to_Raw'';
    
    THROW;
END CATCH
',
    @database_name = N'master',
    @retry_attempts = 3,
    @retry_interval = 5;

-- Add schedule: Daily at 2:05 AM (after master job starts)
EXEC sp_add_jobschedule 
    @job_name = N'DWH_01_Extract_to_Raw',
    @name = N'Daily_2AM_05',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 020500;

PRINT '✓ Extract to Raw job created';
GO

-- ============================================================================
-- 5. STAGING EXTRACTION JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_02_Extract_to_Staging')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_02_Extract_to_Staging';
END

EXEC sp_add_job 
    @job_name = N'DWH_02_Extract_to_Staging',
    @enabled = 1,
    @description = N'Extract data from Raw Zone to Staging (Layer 1 → Staging)',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator',
    @owner_login_name = N'sa';

EXEC sp_add_jobstep 
    @job_name = N'DWH_02_Extract_to_Staging',
    @step_name = N'Extract_to_Staging',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_staging.staging.usp_ExtractAll;',
    @database_name = N'sathapana_staging',
    @retry_attempts = 3,
    @retry_interval = 5;

EXEC sp_add_jobschedule 
    @job_name = N'DWH_02_Extract_to_Staging',
    @name = N'Daily_3AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 030000;

PRINT '✓ Extract to Staging job created';
GO

-- ============================================================================
-- 6. TRANSFORM & LOAD TO DW JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_03_Load_to_DW')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_03_Load_to_DW';
END

EXEC sp_add_job 
    @job_name = N'DWH_03_Load_to_DW',
    @enabled = 1,
    @description = N'Transform and load data to Data Warehouse (Staging → Layer 2)',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator',
    @owner_login_name = N'sa';

EXEC sp_add_jobstep 
    @job_name = N'DWH_03_Load_to_DW',
    @step_name = N'Transform_and_Load',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_dwh.dw.usp_LoadAll;',
    @database_name = N'sathapana_dwh',
    @retry_attempts = 3,
    @retry_interval = 5;

EXEC sp_add_jobschedule 
    @job_name = N'DWH_03_Load_to_DW',
    @name = N'Daily_4AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 040000;

PRINT '✓ Load to DW job created';
GO

-- ============================================================================
-- 7. DATA QUALITY CHECKS JOB
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_04_Data_Quality')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_04_Data_Quality';
END

EXEC sp_add_job 
    @job_name = N'DWH_04_Data_Quality',
    @enabled = 1,
    @description = N'Run data quality checks and validation',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator',
    @owner_login_name = N'sa';

EXEC sp_add_jobstep 
    @job_name = N'DWH_04_Data_Quality',
    @step_name = N'Run_Quality_Checks',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_dwh.audit.usp_RunDataQualityChecks;',
    @database_name = N'sathapana_dwh',
    @retry_attempts = 1,
    @retry_interval = 5;

EXEC sp_add_jobschedule 
    @job_name = N'DWH_04_Data_Quality',
    @name = N'Daily_5AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 050000;

PRINT '✓ Data Quality job created';
GO

-- ============================================================================
-- 8. MAINTENANCE JOB (Weekly)
-- ============================================================================
IF EXISTS (SELECT * FROM sysjobs WHERE name = 'DWH_05_Weekly_Maintenance')
BEGIN
    EXEC sp_delete_job @job_name = N'DWH_05_Weekly_Maintenance';
END

EXEC sp_add_job 
    @job_name = N'DWH_05_Weekly_Maintenance',
    @enabled = 1,
    @description = N'Weekly maintenance: update statistics, rebuild indexes, cleanup',
    @category_name = N'Data Collector',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator',
    @owner_login_name = N'sa';

EXEC sp_add_jobstep 
    @job_name = N'DWH_05_Weekly_Maintenance',
    @step_name = N'Perform_Maintenance',
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_dwh.audit.usp_PerformMaintenance;',
    @database_name = N'sathapana_dwh',
    @retry_attempts = 1,
    @retry_interval = 10;

-- Schedule: Weekly on Sunday at 3:00 AM
EXEC sp_add_jobschedule 
    @job_name = N'DWH_05_Weekly_Maintenance',
    @name = N'Weekly_Sunday_3AM',
    @freq_type = 8,  -- Weekly
    @freq_interval = 1,  -- Sunday
    @freq_subday_type = 1,
    @active_start_time = 030000;

PRINT '✓ Weekly Maintenance job created';
GO

-- ============================================================================
-- 9. CREATE JOB CHAIN (Dependencies)
-- ============================================================================
-- Note: SQL Server Agent doesn't natively support job chains.
-- We use a master job with step-level flow control.

-- Add step to master job for chaining
EXEC sp_add_jobstep 
    @job_name = N'DWH_00_Master_Pipeline',
    @step_name = N'Run_Extract_to_Raw',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_raw.raw.usp_ExtractAll;',
    @database_name = N'sathapana_raw',
    @on_success_action = 3,  -- Go to next step
    @on_fail_action = 2;     -- Quit with failure

EXEC sp_add_jobstep 
    @job_name = N'DWH_00_Master_Pipeline',
    @step_name = N'Run_Extract_to_Staging',
    @step_id = 2,
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_staging.staging.usp_ExtractAll;',
    @database_name = N'sathapana_staging',
    @on_success_action = 3,
    @on_fail_action = 2;

EXEC sp_add_jobstep 
    @job_name = N'DWH_00_Master_Pipeline',
    @step_name = N'Run_Load_to_DW',
    @step_id = 3,
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_dwh.dw.usp_LoadAll;',
    @database_name = N'sathapana_dwh',
    @on_success_action = 3,
    @on_fail_action = 2;

EXEC sp_add_jobstep 
    @job_name = N'DWH_00_Master_Pipeline',
    @step_name = N'Run_Data_Quality',
    @step_id = 4,
    @subsystem = N'TSQL',
    @command = N'EXEC sathapana_dwh.audit.usp_RunDataQualityChecks;',
    @database_name = N'sathapana_dwh',
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2;

PRINT '✓ Job chain configured';
GO

-- ============================================================================
-- 10. VERIFY JOBS CREATED
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'SQL SERVER AGENT JOBS CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Jobs:';
SELECT 
    j.name AS job_name,
    j.enabled,
    j.description,
    CASE 
        WHEN s.freq_type = 4 THEN 'Daily'
        WHEN s.freq_type = 8 THEN 'Weekly'
        ELSE 'Other'
    END AS schedule_type,
    CASE 
        WHEN s.active_start_time IS NOT NULL 
        THEN RIGHT('0' + CAST(s.active_start_time / 10000 AS VARCHAR(2)), 2) + ':' +
             RIGHT('0' + CAST((s.active_start_time % 10000) / 100 AS VARCHAR(2)), 2)
        ELSE 'N/A'
    END AS start_time
FROM sysjobs j
LEFT JOIN sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.name LIKE 'DWH_%'
ORDER BY j.name;

PRINT '';
PRINT 'Schedule Summary:';
PRINT '  02:00 AM - Master Pipeline (orchestrates all)';
PRINT '  02:05 AM - Extract to Raw Zone';
PRINT '  03:00 AM - Extract to Staging';
PRINT '  04:00 AM - Transform & Load to DW';
PRINT '  05:00 AM - Data Quality Checks';
PRINT '  Sunday 3:00 AM - Weekly Maintenance';
PRINT '';
PRINT '================================================';
GO
