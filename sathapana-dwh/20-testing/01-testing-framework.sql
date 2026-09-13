-- ============================================================================
-- SATHAPANA BANK - TESTING FRAMEWORK
-- ============================================================================
-- Purpose: Automated testing for data warehouse validation
-- Author: DWH Development Team
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. TEST RESULT TRACKING TABLE
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'test_results')
BEGIN
    CREATE TABLE audit.test_results (
        test_id             INT IDENTITY(1,1) PRIMARY KEY,
        test_suite          VARCHAR(100) NOT NULL,
        test_name           VARCHAR(200) NOT NULL,
        test_description    NVARCHAR(500),
        test_status         VARCHAR(20) CHECK (test_status IN ('PASS', 'FAIL', 'SKIP', 'ERROR')),
        expected_result     NVARCHAR(MAX),
        actual_result       NVARCHAR(MAX),
        error_message       NVARCHAR(MAX),
        execution_time_ms   INT,
        executed_date       DATETIME DEFAULT GETDATE(),
        executed_by         VARCHAR(100) DEFAULT SYSTEM_USER
    );
    PRINT '✓ Test results table created';
END
GO

-- ============================================================================
-- 2. TEST HELPER FUNCTIONS
-- ============================================================================

-- Assert equals
CREATE OR ALTER FUNCTION audit.fn_AssertEquals(
    @Expected NVARCHAR(MAX),
    @Actual NVARCHAR(MAX)
)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN @Expected = @Actual THEN 1 ELSE 0 END;
END
GO

-- Assert greater than
CREATE OR ALTER FUNCTION audit.fn_AssertGreaterThan(
    @Expected DECIMAL(18,2),
    @Actual DECIMAL(18,2)
)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN @Actual > @Expected THEN 1 ELSE 0 END;
END
GO

-- Assert less than
CREATE OR ALTER FUNCTION audit.fn_AssertLessThan(
    @Expected DECIMAL(18,2),
    @Actual DECIMAL(18,2)
)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN @Actual < @Expected THEN 1 ELSE 0 END;
END
GO

-- ============================================================================
-- 3. DATA INTEGRITY TESTS
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_TestDataIntegrity
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @TestResult VARCHAR(20);
    DECLARE @ActualResult NVARCHAR(500);
    
    PRINT 'Running Data Integrity Tests...';
    
    -- Test 1: All customers have valid keys
    BEGIN TRY
        SET @ActualResult = CAST((SELECT COUNT(*) FROM dw.dim_customer c
            WHERE NOT EXISTS (SELECT 1 FROM dw.dim_account a WHERE c.customer_key = a.customer_key)
            AND c.is_current = 1) AS VARCHAR);
        
        SET @TestResult = CASE 
            WHEN @ActualResult = '0' THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Data Integrity', 'Customer Key Validity', 'All customers should have at least one account', @TestResult, '0', @ActualResult, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 1: Customer Key Validity - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Data Integrity', 'Customer Key Validity', 'ERROR', ERROR_MESSAGE());
        PRINT '✗ Test 1: ERROR - ' + ERROR_MESSAGE();
    END CATCH
    
    SET @StartTime = GETDATE();
    
    -- Test 2: All transactions have valid account references
    BEGIN TRY
        SET @ActualResult = CAST((SELECT COUNT(*) FROM dw.fact_transactions t
            WHERE NOT EXISTS (SELECT 1 FROM dw.dim_account a WHERE t.account_key = a.account_key)) AS VARCHAR);
        
        SET @TestResult = CASE 
            WHEN @ActualResult = '0' THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Data Integrity', 'Transaction Account Reference', 'All transactions must reference valid accounts', @TestResult, '0', @ActualResult, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 2: Transaction Account Reference - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Data Integrity', 'Transaction Account Reference', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    SET @StartTime = GETDATE();
    
    -- Test 3: No duplicate transaction codes
    BEGIN TRY
        SET @ActualResult = CAST((SELECT COUNT(*) FROM (
            SELECT transaction_code, COUNT(*) AS cnt
            FROM dw.fact_transactions
            GROUP BY transaction_code
            HAVING COUNT(*) > 1
        ) d) AS VARCHAR);
        
        SET @TestResult = CASE 
            WHEN @ActualResult = '0' THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Data Integrity', 'Transaction Uniqueness', 'No duplicate transaction codes allowed', @TestResult, '0', @ActualResult, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 3: Transaction Uniqueness - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Data Integrity', 'Transaction Uniqueness', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    SET @StartTime = GETDATE();
    
    -- Test 4: Positive transaction amounts
    BEGIN TRY
        SET @ActualResult = CAST((SELECT COUNT(*) FROM dw.fact_transactions WHERE amount <= 0) AS VARCHAR);
        
        SET @TestResult = CASE 
            WHEN @ActualResult = '0' THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Data Integrity', 'Positive Amounts', 'All transaction amounts must be positive', @TestResult, '0', @ActualResult, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 4: Positive Amounts - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Data Integrity', 'Positive Amounts', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    SET @StartTime = GETDATE();
    
    -- Test 5: Valid date keys
    BEGIN TRY
        SET @ActualResult = CAST((SELECT COUNT(*) FROM dw.fact_transactions t
            WHERE NOT EXISTS (SELECT 1 FROM dw.dim_date d WHERE t.transaction_date_key = d.date_key)) AS VARCHAR);
        
        SET @TestResult = CASE 
            WHEN @ActualResult = '0' THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Data Integrity', 'Valid Date Keys', 'All date keys must exist in dim_date', @TestResult, '0', @ActualResult, DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 5: Valid Date Keys - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Data Integrity', 'Valid Date Keys', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
END;
GO

-- ============================================================================
-- 4. BUSINESS RULE TESTS
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_TestBusinessRules
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @TestResult VARCHAR(20);
    DECLARE @ActualResult NVARCHAR(500);
    
    PRINT 'Running Business Rule Tests...';
    
    -- Test 1: NPL ratio should be less than 10%
    BEGIN TRY
        DECLARE @NPLRatio DECIMAL(10,2);
        
        SELECT @NPLRatio = CASE 
            WHEN SUM(outstanding_principal) = 0 THEN 0
            ELSE SUM(CASE WHEN days_past_due > 90 THEN outstanding_principal ELSE 0 END) / SUM(outstanding_principal) * 100
        END
        FROM dw.fact_loan_portfolio;
        
        SET @TestResult = CASE 
            WHEN @NPLRatio < 10 THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Business Rules', 'NPL Ratio Check', 'NPL ratio should be less than 10%', @TestResult, '< 10%', CAST(@NPLRatio AS VARCHAR) + '%', DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 1: NPL Ratio Check - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Business Rules', 'NPL Ratio Check', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    SET @StartTime = GETDATE();
    
    -- Test 2: LDR ratio should be between 50-100%
    BEGIN TRY
        DECLARE @LDRRatio DECIMAL(10,2);
        
        SELECT @LDRRatio = CASE 
            WHEN SUM(balance) = 0 THEN 0
            ELSE (SELECT SUM(outstanding_principal) FROM dw.fact_loan_portfolio) / SUM(balance) * 100
        END
        FROM dw.fact_deposit_snapshot;
        
        SET @TestResult = CASE 
            WHEN @LDRRatio BETWEEN 50 AND 100 THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Business Rules', 'LDR Ratio Check', 'LDR ratio should be between 50-100%', @TestResult, '50-100%', CAST(@LDRRatio AS VARCHAR) + '%', DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 2: LDR Ratio Check - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Business Rules', 'LDR Ratio Check', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    SET @StartTime = GETDATE();
    
    -- Test 3: KYC completion rate should be > 90%
    BEGIN TRY
        DECLARE @KYCRate DECIMAL(10,2);
        
        SELECT @KYCRate = CAST(SUM(CASE WHEN kyc_status = 'VERIFIED' THEN 1 ELSE 0 END) AS DECIMAL(10,2)) / COUNT(*) * 100
        FROM dw.dim_customer WHERE is_current = 1;
        
        SET @TestResult = CASE 
            WHEN @KYCRate > 90 THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Business Rules', 'KYC Completion Rate', 'KYC completion rate should be > 90%', @TestResult, '> 90%', CAST(@KYCRate AS VARCHAR) + '%', DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 3: KYC Completion Rate - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Business Rules', 'KYC Completion Rate', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
END;
GO

-- ============================================================================
-- 5. DATA FRESHNESS TESTS
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_TestDataFreshness
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @TestResult VARCHAR(20);
    DECLARE @ActualResult NVARCHAR(500);
    
    PRINT 'Running Data Freshness Tests...';
    
    -- Test 1: Transactions should be less than 24 hours old
    BEGIN TRY
        DECLARE @MaxAge INT;
        
        SELECT @MaxAge = DATEDIFF(HOUR, MAX(etl_load_date), GETDATE())
        FROM dw.fact_transactions;
        
        SET @TestResult = CASE 
            WHEN @MaxAge < 24 THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Data Freshness', 'Transaction Freshness', 'Transactions should be less than 24 hours old', @TestResult, '< 24 hours', CAST(@MaxAge AS VARCHAR) + ' hours', DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 1: Transaction Freshness - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Data Freshness', 'Transaction Freshness', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
    SET @StartTime = GETDATE();
    
    -- Test 2: Loan portfolio should be current month
    BEGIN TRY
        DECLARE @LoanMonth INT;
        
        SELECT @LoanMonth = MAX(d.month_number)
        FROM dw.fact_loan_portfolio l
        JOIN dw.dim_date d ON l.snapshot_date_key = d.date_key;
        
        SET @TestResult = CASE 
            WHEN @LoanMonth = MONTH(GETDATE()) THEN 'PASS'
            ELSE 'FAIL'
        END;
        
        INSERT INTO audit.test_results (test_suite, test_name, test_description, test_status, expected_result, actual_result, execution_time_ms)
        VALUES ('Data Freshness', 'Loan Portfolio Freshness', 'Loan portfolio should be current month', @TestResult, CAST(MONTH(GETDATE()) AS VARCHAR), CAST(@LoanMonth AS VARCHAR), DATEDIFF(MILLISECOND, @StartTime, GETDATE()));
        
        PRINT '✓ Test 2: Loan Portfolio Freshness - ' + @TestResult;
    END TRY
    BEGIN CATCH
        INSERT INTO audit.test_results (test_suite, test_name, test_status, error_message)
        VALUES ('Data Freshness', 'Loan Portfolio Freshness', 'ERROR', ERROR_MESSAGE());
    END CATCH
    
END;
GO

-- ============================================================================
-- 6. TEST REPORT GENERATION
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_GenerateTestReport
    @TestSuite VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '╔═══════════════════════════════════════════════════════════════════╗';
    PRINT '║                    TEST EXECUTION REPORT                         ║';
    PRINT '╚═══════════════════════════════════════════════════════════════════╝';
    PRINT '';
    PRINT 'Generated: ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '';
    
    -- Summary
    SELECT 
        test_suite,
        COUNT(*) AS total_tests,
        SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END) AS passed,
        SUM(CASE WHEN test_status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
        SUM(CASE WHEN test_status = 'ERROR' THEN 1 ELSE 0 END) AS errors,
        CAST(SUM(CASE WHEN test_status = 'PASS' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS pass_rate
    FROM audit.test_results
    WHERE executed_date >= DATEADD(DAY, -1, GETDATE())
    AND (@TestSuite IS NULL OR test_suite = @TestSuite)
    GROUP BY test_suite;
    
    -- Failed tests detail
    PRINT '';
    PRINT '--- Failed Tests ---';
    SELECT 
        test_name,
        test_description,
        expected_result,
        actual_result,
        error_message,
        executed_date
    FROM audit.test_results
    WHERE test_status IN ('FAIL', 'ERROR')
    AND executed_date >= DATEADD(DAY, -1, GETDATE())
    AND (@TestSuite IS NULL OR test_suite = @TestSuite)
    ORDER BY executed_date DESC;
    
    -- All tests
    PRINT '';
    PRINT '--- All Tests ---';
    SELECT 
        test_suite,
        test_name,
        test_status,
        execution_time_ms,
        executed_date
    FROM audit.test_results
    WHERE executed_date >= DATEADD(DAY, -1, GETDATE())
    AND (@TestSuite IS NULL OR test_suite = @TestSuite)
    ORDER BY test_suite, test_name;
    
END;
GO

-- ============================================================================
-- 7. RUN ALL TESTS
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_RunAllTests
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '========================================';
    PRINT 'RUNNING ALL TESTS';
    PRINT '========================================';
    DECLARE @StartTime DATETIME = GETDATE();
    
    -- Clear previous results
    DELETE FROM audit.test_results WHERE executed_date < DATEADD(DAY, -7, GETDATE());
    
    -- Run test suites
    EXEC audit.usp_TestDataIntegrity;
    EXEC audit.usp_TestBusinessRules;
    EXEC audit.usp_TestDataFreshness;
    
    DECLARE @EndTime DATETIME = GETDATE();
    DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, @EndTime);
    
    PRINT '';
    PRINT '========================================';
    PRINT 'ALL TESTS COMPLETED';
    PRINT 'Duration: ' + CAST(@Duration AS VARCHAR) + ' seconds';
    PRINT '========================================';
    
    -- Generate report
    EXEC audit.usp_GenerateTestReport;
END;
GO

-- ============================================================================
-- 8. VERIFY SETUP
-- ============================================================================
PRINT '';
PRINT '================================================';
PRINT 'TESTING FRAMEWORK CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Procedures:';
PRINT '  - usp_TestDataIntegrity: Data integrity tests';
PRINT '  - usp_TestBusinessRules: Business rule validation';
PRINT '  - usp_TestDataFreshness: Data freshness checks';
PRINT '  - usp_GenerateTestReport: Generate test report';
PRINT '  - usp_RunAllTests: Run all test suites';
PRINT '';
PRINT 'To run all tests:';
PRINT '  EXEC audit.usp_RunAllTests;';
PRINT '';
PRINT 'To view test report:';
PRINT '  EXEC audit.usp_GenerateTestReport;';
PRINT '';
PRINT '================================================';
GO
