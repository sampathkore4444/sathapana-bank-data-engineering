-- ============================================================================
-- SATHAPANA BANK - DATA QUALITY FRAMEWORK
-- ============================================================================
-- Purpose: Create comprehensive data quality validation framework
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. DATA QUALITY CHECK PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_RunDataQualityChecks
    @BatchID UNIQUEIDENTIFIER = NULL,
    @CheckCategory VARCHAR(50) = 'ALL'
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    PRINT 'Running Data Quality Checks...';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    
    -- Run all checks
    EXEC audit.usp_CheckCompleteness @BatchID;
    EXEC audit.usp_CheckReferentialIntegrity @BatchID;
    EXEC audit.usp_CheckUniqueness @BatchID;
    EXEC audit.usp_CheckValidity @BatchID;
    EXEC audit.usp_CheckTimeliness @BatchID;
    EXEC audit.usp_CheckAccuracy @BatchID;
    
    -- Generate summary
    EXEC audit.usp_GenerateQualityReport @BatchID;
    
    PRINT 'Data Quality Checks Completed.';
END;
GO

-- ============================================================================
-- 2. COMPLETENESS CHECKS
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_CheckCompleteness
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalRows BIGINT;
    DECLARE @NullRows BIGINT;
    DECLARE @PassRate DECIMAL(5,2);
    
    PRINT 'Checking Completeness...';
    
    -- Customer completeness
    SELECT @TotalRows = COUNT(*) FROM dw.dim_customer WHERE is_current = 1;
    
    SELECT @NullRows = COUNT(*) FROM dw.dim_customer 
    WHERE is_current = 1 AND (first_name IS NULL OR customer_code IS NULL);
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @NullRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, column_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Customer_Completeness', 'Customer required fields not null', 'dim_customer', 'first_name, customer_code', @TotalRows, @TotalRows - @NullRows, @NullRows, @PassRate, 
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Account completeness
    SELECT @TotalRows = COUNT(*) FROM dw.dim_account WHERE is_current = 1;
    
    SELECT @NullRows = COUNT(*) FROM dw.dim_account 
    WHERE is_current = 1 AND (account_number IS NULL OR customer_key IS NULL);
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @NullRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, column_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Account_Completeness', 'Account required fields not null', 'dim_account', 'account_number, customer_key', @TotalRows, @TotalRows - @NullRows, @NullRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Transaction completeness
    SELECT @TotalRows = COUNT(*) FROM dw.fact_transactions;
    
    SELECT @NullRows = COUNT(*) FROM dw.fact_transactions 
    WHERE transaction_code IS NULL OR amount IS NULL;
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @NullRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, column_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_Completeness', 'Transaction required fields not null', 'fact_transactions', 'transaction_code, amount', @TotalRows, @TotalRows - @NullRows, @NullRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    PRINT 'Completeness checks completed.';
END;
GO

-- ============================================================================
-- 3. REFERENTIAL INTEGRITY CHECKS
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_CheckReferentialIntegrity
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalRows BIGINT;
    DECLARE @OrphanRows BIGINT;
    DECLARE @PassRate DECIMAL(5,2);
    
    PRINT 'Checking Referential Integrity...';
    
    -- Check transactions -> accounts
    SELECT @TotalRows = COUNT(*) FROM dw.fact_transactions;
    
    SELECT @OrphanRows = COUNT(*) FROM dw.fact_transactions t
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_account a WHERE t.account_key = a.account_key
    );
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @OrphanRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_Account_Integrity', 'Transaction has valid account reference', 'fact_transactions', @TotalRows, @TotalRows - @OrphanRows, @OrphanRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check transactions -> customers
    SELECT @OrphanRows = COUNT(*) FROM dw.fact_transactions t
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_customer c WHERE t.customer_key = c.customer_key
    );
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @OrphanRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_Customer_Integrity', 'Transaction has valid customer reference', 'fact_transactions', @TotalRows, @TotalRows - @OrphanRows, @OrphanRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check accounts -> customers
    SELECT @TotalRows = COUNT(*) FROM dw.dim_account WHERE is_current = 1;
    
    SELECT @OrphanRows = COUNT(*) FROM dw.dim_account a
    WHERE a.is_current = 1
    AND NOT EXISTS (
        SELECT 1 FROM dw.dim_customer c WHERE a.customer_key = c.customer_key AND c.is_current = 1
    );
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @OrphanRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Account_Customer_Integrity', 'Account has valid customer reference', 'dim_account', @TotalRows, @TotalRows - @OrphanRows, @OrphanRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check accounts -> products
    SELECT @OrphanRows = COUNT(*) FROM dw.dim_account a
    WHERE a.is_current = 1
    AND NOT EXISTS (
        SELECT 1 FROM dw.dim_product p WHERE a.product_key = p.product_key
    );
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @OrphanRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Account_Product_Integrity', 'Account has valid product reference', 'dim_account', @TotalRows, @TotalRows - @OrphanRows, @OrphanRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check accounts -> branches
    SELECT @OrphanRows = COUNT(*) FROM dw.dim_account a
    WHERE a.is_current = 1
    AND NOT EXISTS (
        SELECT 1 FROM dw.dim_branch b WHERE a.branch_key = b.branch_key AND b.is_current = 1
    );
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @OrphanRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Account_Branch_Integrity', 'Account has valid branch reference', 'dim_account', @TotalRows, @TotalRows - @OrphanRows, @OrphanRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    PRINT 'Referential Integrity checks completed.';
END;
GO

-- ============================================================================
-- 4. UNIQUENESS CHECKS
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_CheckUniqueness
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalRows BIGINT;
    DECLARE @DuplicateRows BIGINT;
    DECLARE @PassRate DECIMAL(5,2);
    
    PRINT 'Checking Uniqueness...';
    
    -- Check customer uniqueness
    SELECT @TotalRows = COUNT(*) FROM dw.dim_customer WHERE is_current = 1;
    
    SELECT @DuplicateRows = COUNT(*) FROM (
        SELECT customer_code, COUNT(*) AS cnt
        FROM dw.dim_customer WHERE is_current = 1
        GROUP BY customer_code
        HAVING COUNT(*) > 1
    ) d;
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @DuplicateRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Customer_Uniqueness', 'No duplicate customer codes', 'dim_customer', @TotalRows, @TotalRows - @DuplicateRows, @DuplicateRows, @PassRate,
            CASE WHEN @DuplicateRows = 0 THEN 'PASS' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check account uniqueness
    SELECT @TotalRows = COUNT(*) FROM dw.dim_account WHERE is_current = 1;
    
    SELECT @DuplicateRows = COUNT(*) FROM (
        SELECT account_number, COUNT(*) AS cnt
        FROM dw.dim_account WHERE is_current = 1
        GROUP BY account_number
        HAVING COUNT(*) > 1
    ) d;
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @DuplicateRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Account_Uniqueness', 'No duplicate account numbers', 'dim_account', @TotalRows, @TotalRows - @DuplicateRows, @DuplicateRows, @PassRate,
            CASE WHEN @DuplicateRows = 0 THEN 'PASS' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check transaction uniqueness
    SELECT @TotalRows = COUNT(*) FROM dw.fact_transactions;
    
    SELECT @DuplicateRows = COUNT(*) FROM (
        SELECT transaction_code, COUNT(*) AS cnt
        FROM dw.fact_transactions
        GROUP BY transaction_code
        HAVING COUNT(*) > 1
    ) d;
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @DuplicateRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_Uniqueness', 'No duplicate transaction codes', 'fact_transactions', @TotalRows, @TotalRows - @DuplicateRows, @DuplicateRows, @PassRate,
            CASE WHEN @DuplicateRows = 0 THEN 'PASS' ELSE 'FAIL' END,
            'ERROR');
    
    PRINT 'Uniqueness checks completed.';
END;
GO

-- ============================================================================
-- 5. VALIDITY CHECKS
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_CheckValidity
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalRows BIGINT;
    DECLARE @InvalidRows BIGINT;
    DECLARE @PassRate DECIMAL(5,2);
    
    PRINT 'Checking Validity...';
    
    -- Check valid currency codes
    SELECT @TotalRows = COUNT(*) FROM dw.fact_transactions;
    
    SELECT @InvalidRows = COUNT(*) FROM dw.fact_transactions t
    WHERE t.currency NOT IN ('USD', 'KHR', 'EUR', 'GBP', 'JPY', 'THB');
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @InvalidRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, column_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_Currency_Valid', 'Transaction currency is valid', 'fact_transactions', 'currency', @TotalRows, @TotalRows - @InvalidRows, @InvalidRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'WARNING');
    
    -- Check valid transaction amounts (positive)
    SELECT @InvalidRows = COUNT(*) FROM dw.fact_transactions t
    WHERE t.amount <= 0;
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @InvalidRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, column_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_Amount_Positive', 'Transaction amount is positive', 'fact_transactions', 'amount', @TotalRows, @TotalRows - @InvalidRows, @InvalidRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check valid date keys
    SELECT @TotalRows = COUNT(*) FROM dw.fact_transactions;
    
    SELECT @InvalidRows = COUNT(*) FROM dw.fact_transactions t
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_date d WHERE t.transaction_date_key = d.date_key
    );
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @InvalidRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, column_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_DateKey_Valid', 'Transaction date key exists in dim_date', 'fact_transactions', 'transaction_date_key', @TotalRows, @TotalRows - @InvalidRows, @InvalidRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check valid customer segment
    SELECT @TotalRows = COUNT(*) FROM dw.dim_customer WHERE is_current = 1;
    
    SELECT @InvalidRows = COUNT(*) FROM dw.dim_customer 
    WHERE is_current = 1 
    AND customer_segment NOT IN ('RETAIL', 'SME', 'CORPORATE', 'PRIVATE_BANKING', 'MICRO');
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @InvalidRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, column_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Customer_Segment_Valid', 'Customer segment is valid', 'dim_customer', 'customer_segment', @TotalRows, @TotalRows - @InvalidRows, @InvalidRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'WARNING');
    
    PRINT 'Validity checks completed.';
END;
GO

-- ============================================================================
-- 6. TIMELINESS CHECKS
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_CheckTimeliness
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalRows BIGINT;
    DECLARE @StaleRows BIGINT;
    DECLARE @PassRate DECIMAL(5,2);
    
    PRINT 'Checking Timeliness...';
    
    -- Check transaction freshness
    SELECT @TotalRows = COUNT(*) FROM dw.fact_transactions;
    
    SELECT @StaleRows = COUNT(*) FROM dw.fact_transactions t
    WHERE t.etl_load_date < DATEADD(DAY, -1, GETDATE());
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @StaleRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Transaction_Freshness', 'Transactions loaded within last 24 hours', 'fact_transactions', @TotalRows, @TotalRows - @StaleRows, @StaleRows, @PassRate,
            CASE WHEN @PassRate >= 90 THEN 'PASS' WHEN @PassRate >= 80 THEN 'WARNING' ELSE 'FAIL' END,
            'WARNING');
    
    -- Check ETL log freshness
    SELECT @StaleRows = COUNT(*) FROM audit.etl_log
    WHERE step_name LIKE 'Load_%'
    AND end_time < DATEADD(DAY, -1, GETDATE());
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'ETL_Freshness', 'ETL jobs completed within last 24 hours', 'etl_log', 1, 
            CASE WHEN @StaleRows = 0 THEN 1 ELSE 0 END, @StaleRows,
            CASE WHEN @StaleRows = 0 THEN 100 ELSE 0 END,
            CASE WHEN @StaleRows = 0 THEN 'PASS' ELSE 'WARNING' END,
            'WARNING');
    
    PRINT 'Timeliness checks completed.';
END;
GO

-- ============================================================================
-- 7. ACCURACY CHECKS
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_CheckAccuracy
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalRows BIGINT;
    DECLARE @InaccurateRows BIGINT;
    DECLARE @PassRate DECIMAL(5,2);
    
    PRINT 'Checking Accuracy...';
    
    -- Check balance consistency (balance_after should match next transaction's balance_before)
    SELECT @TotalRows = COUNT(*) FROM dw.fact_transactions;
    
    -- Check for negative balances on non-overdraft accounts
    SELECT @InaccurateRows = COUNT(*) FROM dw.fact_transactions t
    JOIN dw.dim_account a ON t.account_key = a.account_key
    WHERE a.account_type != 'OVERDRAFT'
    AND t.balance_after < 0;
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @InaccurateRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Balance_NonNegative', 'Non-overdraft accounts have non-negative balances', 'fact_transactions', @TotalRows, @TotalRows - @InaccurateRows, @InaccurateRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check GL balance equation (Debits = Credits)
    SELECT @TotalRows = COUNT(DISTINCT gl_account_code) FROM sathapana_staging.staging.stg_gl_entries;
    
    SELECT @InaccurateRows = COUNT(*) FROM (
        SELECT gl_account_code,
               SUM(debit_amount) AS total_debits,
               SUM(credit_amount) AS total_credits,
               SUM(debit_amount) - SUM(credit_amount) AS difference
        FROM sathapana_staging.staging.stg_gl_entries
        GROUP BY gl_account_code
        HAVING ABS(SUM(debit_amount) - SUM(credit_amount)) > 0.01
    ) g;
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @InaccurateRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'GL_Balance_Check', 'GL accounts have balanced debits and credits', 'gl_entries', @TotalRows, @TotalRows - @InaccurateRows, @InaccurateRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    -- Check loan outstanding doesn't exceed approved amount
    SELECT @TotalRows = COUNT(*) FROM dw.fact_loan_portfolio;
    
    SELECT @InaccurateRows = COUNT(*) FROM dw.fact_loan_portfolio l
    WHERE l.outstanding_principal > l.approved_amount * 1.1;  -- Allow 10% tolerance
    
    SET @PassRate = CASE WHEN @TotalRows = 0 THEN 100 
                         ELSE (@TotalRows - @InaccurateRows) * 100.0 / @TotalRows END;
    
    INSERT INTO audit.data_quality (batch_id, check_name, check_description, table_name, total_rows, passing_rows, failing_rows, pass_rate, status, severity)
    VALUES (@BatchID, 'Loan_Outstanding_Valid', 'Loan outstanding does not exceed approved amount', 'fact_loan_portfolio', @TotalRows, @TotalRows - @InaccurateRows, @InaccurateRows, @PassRate,
            CASE WHEN @PassRate >= 99 THEN 'PASS' WHEN @PassRate >= 95 THEN 'WARNING' ELSE 'FAIL' END,
            'ERROR');
    
    PRINT 'Accuracy checks completed.';
END;
GO

-- ============================================================================
-- 8. QUALITY REPORT GENERATION
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_GenerateQualityReport
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '';
    PRINT '================================================';
    PRINT 'DATA QUALITY REPORT';
    PRINT '================================================';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT 'Report Date: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '';
    
    -- Overall summary
    SELECT 
        COUNT(*) AS total_checks,
        SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed_checks,
        SUM(CASE WHEN status = 'WARNING' THEN 1 ELSE 0 END) AS warning_checks,
        SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed_checks,
        AVG(pass_rate) AS avg_pass_rate
    FROM audit.data_quality
    WHERE batch_id = @BatchID;
    
    PRINT '';
    PRINT '--- Failed Checks ---';
    SELECT 
        check_name,
        table_name,
        column_name,
        total_rows,
        failing_rows,
        pass_rate,
        severity,
        error_message
    FROM audit.data_quality
    WHERE batch_id = @BatchID AND status = 'FAIL'
    ORDER BY severity DESC;
    
    PRINT '';
    PRINT '--- Warning Checks ---';
    SELECT 
        check_name,
        table_name,
        column_name,
        total_rows,
        failing_rows,
        pass_rate,
        severity
    FROM audit.data_quality
    WHERE batch_id = @BatchID AND status = 'WARNING'
    ORDER BY pass_rate ASC;
    
    PRINT '';
    PRINT '--- All Checks Summary ---';
    SELECT 
        check_name,
        table_name,
        total_rows,
        passing_rows,
        failing_rows,
        pass_rate,
        status,
        severity
    FROM audit.data_quality
    WHERE batch_id = @BatchID
    ORDER BY status, check_name;
    
    PRINT '';
    PRINT '================================================';
    PRINT 'END OF DATA QUALITY REPORT';
    PRINT '================================================';
END;
GO

-- ============================================================================
-- 9. DATA RECONCILIATION PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE audit.usp_ReconcileData
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Running Data Reconciliation...';
    
    -- Reconcile source vs staging counts
    PRINT '';
    PRINT '--- Source vs Staging Reconciliation ---';
    
    SELECT 'Branches' AS entity,
           (SELECT COUNT(*) FROM sathapana_source.oltp.branches) AS source_count,
           (SELECT COUNT(*) FROM sathapana_staging.staging.stg_branches) AS staging_count,
           CASE WHEN (SELECT COUNT(*) FROM sathapana_source.oltp.branches) = 
                     (SELECT COUNT(*) FROM sathapana_staging.staging.stg_branches)
                THEN 'MATCH' ELSE 'MISMATCH' END AS status
    UNION ALL
    SELECT 'Customers',
           (SELECT COUNT(*) FROM sathapana_source.oltp.customers),
           (SELECT COUNT(*) FROM sathapana_staging.staging.stg_customers),
           CASE WHEN (SELECT COUNT(*) FROM sathapana_source.oltp.customers) = 
                     (SELECT COUNT(*) FROM sathapana_staging.staging.stg_customers)
                THEN 'MATCH' ELSE 'MISMATCH' END
    UNION ALL
    SELECT 'Accounts',
           (SELECT COUNT(*) FROM sathapana_source.oltp.accounts),
           (SELECT COUNT(*) FROM sathapana_staging.staging.stg_accounts),
           CASE WHEN (SELECT COUNT(*) FROM sathapana_source.oltp.accounts) = 
                     (SELECT COUNT(*) FROM sathapana_staging.staging.stg_accounts)
                THEN 'MATCH' ELSE 'MISMATCH' END
    UNION ALL
    SELECT 'Transactions',
           (SELECT COUNT(*) FROM sathapana_source.oltp.transactions),
           (SELECT COUNT(*) FROM sathapana_staging.staging.stg_transactions),
           CASE WHEN (SELECT COUNT(*) FROM sathapana_source.oltp.transactions) = 
                     (SELECT COUNT(*) FROM sathapana_staging.staging.stg_transactions)
                THEN 'MATCH' ELSE 'MISMATCH' END;
    
    -- Reconcile staging vs DW counts
    PRINT '';
    PRINT '--- Staging vs DW Reconciliation ---';
    
    SELECT 'Customers' AS entity,
           (SELECT COUNT(*) FROM sathapana_staging.staging.stg_customers) AS staging_count,
           (SELECT COUNT(*) FROM dw.dim_customer WHERE is_current = 1) AS dw_count
    UNION ALL
    SELECT 'Accounts',
           (SELECT COUNT(*) FROM sathapana_staging.staging.stg_accounts),
           (SELECT COUNT(*) FROM dw.dim_account WHERE is_current = 1)
    UNION ALL
    SELECT 'Transactions',
           (SELECT COUNT(*) FROM sathapana_staging.staging.stg_transactions),
           (SELECT COUNT(*) FROM dw.fact_transactions);
    
    PRINT '';
    PRINT 'Data Reconciliation Completed.';
END;
GO

-- ============================================================================
-- 10. VERIFY DATA QUALITY FRAMEWORK
-- ============================================================================
PRINT '================================================';
PRINT 'DATA QUALITY FRAMEWORK CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Procedures created:';
SELECT COUNT(*) AS procedure_count 
FROM sys.procedures 
WHERE schema_id = SCHEMA_ID('audit');
PRINT '';
PRINT '================================================';
GO
