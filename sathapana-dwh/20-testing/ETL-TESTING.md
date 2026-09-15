# 🧪 ETL Testing Guide

## Table of Contents
1. [Overview](#1-overview)
2. [Testing Types](#2-testing-types)
3. [Unit Testing](#3-unit-testing)
4. [Integration Testing](#4-integration-testing)
5. [Data Quality Testing](#5-data-quality-testing)
6. [Performance Testing](#6-performance-testing)
7. [Test Automation](#7-test-automation)
8. [Hands-On Exercise](#8-hands-on-exercise)

---

## 1. Overview

ETL Testing ensures the pipeline correctly extracts, transforms, and loads data without errors or data loss.

```
┌─────────────────────────────────────────────────────────────────┐
│                    ETL TESTING PYRAMID                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                         ╱╲                                       │
│                        ╱  ╲      E2E Tests                       │
│                       ╱    ╲     (Full pipeline)                 │
│                      ╱──────╲                                    │
│                     ╱        ╲   Integration Tests                │
│                    ╱          ╲  (Procedure interactions)         │
│                   ╱────────────╲                                 │
│                  ╱              ╲ Unit Tests                     │
│                 ╱                ╲(Individual procedures)         │
│                ╱──────────────────╲                              │
│               ╱                    ╲ Data Tests                   │
│              ╱                      ╲(Quality, completeness)     │
│             ╱────────────────────────╲                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Testing Types

| Type | Scope | When to Run |
|------|-------|-------------|
| **Unit Testing** | Individual procedures | During development |
| **Integration Testing** | Multiple procedures together | After unit tests pass |
| **Regression Testing** | Full pipeline | Before production deploy |
| **Data Quality Testing** | Data accuracy & completeness | Every ETL run |
| **Performance Testing** | Execution time & resource usage | Periodically |

---

## 3. Unit Testing

### Test Framework Setup

```sql
-- ============================================================
-- ETL TEST FRAMEWORK
-- ============================================================

-- Test results table
CREATE TABLE etl_testing.test_results (
    test_id INT IDENTITY(1,1) PRIMARY KEY,
    test_suite VARCHAR(100),
    test_name VARCHAR(200),
    test_description NVARCHAR(500),
    status VARCHAR(20),  -- PASS, FAIL, SKIP
    expected_result NVARCHAR(500),
    actual_result NVARCHAR(500),
    error_message NVARCHAR(MAX),
    execution_time_ms INT,
    executed_by VARCHAR(100),
    executed_date DATETIME DEFAULT GETDATE()
);

-- Test cases table
CREATE TABLE etl_testing.test_cases (
    test_case_id INT IDENTITY(1,1) PRIMARY KEY,
    test_suite VARCHAR(100),
    test_name VARCHAR(200),
    test_type VARCHAR(50),  -- UNIT, INTEGRATION, DATA_QUALITY
    procedure_name VARCHAR(200),
    test_sql NVARCHAR(MAX),
    expected_sql NVARCHAR(MAX),
    cleanup_sql NVARCHAR(MAX),
    is_enabled BIT DEFAULT 1,
    priority INT DEFAULT 1
);
```

### Unit Test Helper Procedures

```sql
-- ============================================================
-- TEST HELPER PROCEDURES
-- ============================================================

-- Assert equal
CREATE PROCEDURE etl_testing.usp_AssertEqual
    @TestName VARCHAR(200),
    @Expected SQL_VARIANT,
    @Actual SQL_VARIANT
AS
BEGIN
    DECLARE @Status VARCHAR(20);
    
    IF @Expected = @Actual
        SET @Status = 'PASS';
    ELSE
        SET @Status = 'FAIL';
    
    INSERT INTO etl_testing.test_results (
        test_name, status, expected_result, actual_result
    )
    VALUES (
        @TestName, @Status,
        CAST(@Expected AS NVARCHAR(500)),
        CAST(@Actual AS NVARCHAR(500))
    );
    
    IF @Status = 'FAIL'
        PRINT '❌ FAILED: ' + @TestName;
    ELSE
        PRINT '✅ PASSED: ' + @TestName;
END;

-- Assert row count
CREATE PROCEDURE etl_testing.usp_AssertRowCount
    @TestName VARCHAR(200),
    @TableName VARCHAR(200),
    @ExpectedCount INT,
    @WhereClause NVARCHAR(500) = ''
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @ActualCount INT;
    
    SET @SQL = 'SELECT @cnt = COUNT(*) FROM ' + @TableName;
    IF @WhereClause != ''
        SET @SQL = @SQL + ' WHERE ' + @WhereClause;
    
    EXEC sp_executesql @SQL, N'@cnt INT OUTPUT', @ActualCount OUTPUT;
    
    EXEC etl_testing.usp_AssertEqual @TestName, @ExpectedCount, @ActualCount;
END;

-- Assert no NULLs in column
CREATE PROCEDURE etl_testing.usp_AssertNoNulls
    @TestName VARCHAR(200),
    @TableName VARCHAR(200),
    @ColumnName VARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @NullCount INT;
    
    SET @SQL = 'SELECT @cnt = SUM(CASE WHEN ' + @ColumnName + ' IS NULL THEN 1 ELSE 0 END) FROM ' + @TableName;
    EXEC sp_executesql @SQL, N'@cnt INT OUTPUT', @NullCount OUTPUT;
    
    EXEC etl_testing.usp_AssertEqual @TestName, 0, @NullCount;
END;

-- Assert unique values
CREATE PROCEDURE etl_testing.usp_AssertUnique
    @TestName VARCHAR(200),
    @TableName VARCHAR(200),
    @ColumnName VARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @DuplicateCount INT;
    
    SET @SQL = 'SELECT @cnt = COUNT(*) - COUNT(DISTINCT ' + @ColumnName + ') FROM ' + @TableName;
    EXEC sp_executesql @SQL, N'@cnt INT OUTPUT', @DuplicateCount OUTPUT;
    
    EXEC etl_testing.usp_AssertEqual @TestName, 0, @DuplicateCount;
END;
```

### Unit Test Examples

```sql
-- ============================================================
-- UNIT TESTS FOR EXTRACT PROCEDURES
-- ============================================================

CREATE PROCEDURE etl_testing.usp_Test_ExtractCustomers
AS
BEGIN
    PRINT '=== Testing usp_ExtractCustomers ===';
    
    -- Setup: Clear staging
    TRUNCATE TABLE staging.stg_customers;
    
    -- Execute procedure
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
    EXEC staging.usp_ExtractCustomers @BatchID;
    
    -- Assertions
    EXEC etl_testing.usp_AssertRowCount 
        'Customers extracted', 
        'staging.stg_customers', 
        (SELECT COUNT(*) FROM etl_pipeline_source.dbo.customers);
    
    EXEC etl_testing.usp_AssertNoNulls 
        'customer_code not null', 
        'staging.stg_customers', 
        'customer_code';
    
    EXEC etl_testing.usp_AssertUnique 
        'customer_code unique', 
        'staging.stg_customers', 
        'customer_code';
    
    -- Cleanup
    TRUNCATE TABLE staging.stg_customers;
END;

-- ============================================================
-- UNIT TESTS FOR LOAD PROCEDURES
-- ============================================================

CREATE PROCEDURE etl_testing.usp_Test_LoadDimCustomer
AS
BEGIN
    PRINT '=== Testing usp_LoadDimCustomer ===';
    
    -- Setup: Clear dimension
    DELETE FROM dw.dim_customer;
    
    -- First load (initial)
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
    EXEC dw.usp_LoadDimCustomer @BatchID;
    
    -- Assert initial load
    EXEC etl_testing.usp_AssertRowCount 
        'Initial load count', 
        'dw.dim_customer', 
        (SELECT COUNT(*) FROM staging.stg_customers);
    
    EXEC etl_testing.usp_AssertEqual 
        'All records current after initial load',
        (SELECT COUNT(*) FROM dw.dim_customer WHERE is_current = 1),
        (SELECT COUNT(*) FROM dw.dim_customer);
    
    -- Make a change and re-load
    UPDATE staging.stg_customers
    SET first_name = 'Updated Name'
    WHERE customer_code = 'CUST001';
    
    EXEC dw.usp_LoadDimCustomer @BatchID;
    
    -- Assert SCD Type 2 behavior
    EXEC etl_testing.usp_AssertEqual 
        'Historical record created for changed customer',
        (SELECT COUNT(*) FROM dw.dim_customer WHERE customer_code = 'CUST001'),
        2;
    
    EXEC etl_testing.usp_AssertEqual 
        'Only one current version per customer',
        (SELECT COUNT(*) FROM dw.dim_customer WHERE customer_code = 'CUST001' AND is_current = 1),
        1;
    
    -- Cleanup
    DELETE FROM dw.dim_customer;
END;
```

---

## 4. Integration Testing

```sql
-- ============================================================
-- INTEGRATION TESTS
-- ============================================================

CREATE PROCEDURE etl_testing.usp_Test_FullETLPipeline
AS
BEGIN
    PRINT '=== Integration Test: Full ETL Pipeline ===';
    
    -- Setup
    EXEC etl_testing.usp_SetupTestData;
    
    -- Execute full pipeline
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
    EXEC staging.usp_ExtractAll @BatchID;
    EXEC dw.usp_LoadAll @BatchID;
    
    -- Assertions
    EXEC etl_testing.usp_AssertRowCount 
        'Dim customer count matches source', 
        'dw.dim_customer WHERE is_current = 1', 
        (SELECT COUNT(*) FROM etl_pipeline_source.dbo.customers);
    
    EXEC etl_testing.usp_AssertRowCount 
        'Fact transaction count matches source', 
        'dw.fact_transactions', 
        (SELECT COUNT(*) FROM etl_pipeline_source.dbo.transactions);
    
    -- Check referential integrity
    EXEC etl_testing.usp_AssertEqual 
        'All facts reference valid customers',
        (SELECT COUNT(*) FROM dw.fact_transactions f 
         WHERE NOT EXISTS (SELECT 1 FROM dw.dim_customer c WHERE c.customer_key = f.customer_key AND c.is_current = 1)),
        0;
    
    -- Cleanup
    EXEC etl_testing.usp_CleanupTestData;
END;

-- Setup test data
CREATE PROCEDURE etl_testing.usp_SetupTestData
AS
BEGIN
    -- Insert test data into source
    INSERT INTO etl_pipeline_source.dbo.customers (customer_code, first_name, last_name, email)
    VALUES ('TEST001', 'Test', 'User', 'test@email.com');
    
    -- Add more test data as needed
END;

-- Cleanup test data
CREATE PROCEDURE etl_testing.usp_CleanupTestData
AS
BEGIN
    -- Remove test data
    DELETE FROM etl_pipeline_source.dbo.customers WHERE customer_code LIKE 'TEST%';
    DELETE FROM dw.dim_customer WHERE customer_code LIKE 'TEST%';
    DELETE FROM dw.fact_transactions WHERE source_key IN (
        SELECT source_key FROM staging.stg_transactions WHERE source_key LIKE 'TEST%'
    );
END;
```

---

## 5. Data Quality Testing

```sql
-- ============================================================
-- DATA QUALITY TESTS
-- ============================================================

CREATE PROCEDURE etl_testing.usp_Test_DataQuality
AS
BEGIN
    PRINT '=== Data Quality Tests ===';
    
    -- Test 1: No orphaned records
    EXEC etl_testing.usp_AssertEqual 
        'No orphaned accounts (account without customer)',
        (SELECT COUNT(*) FROM dw.dim_account a 
         WHERE NOT EXISTS (SELECT 1 FROM dw.dim_customer c WHERE c.customer_key = a.customer_key AND c.is_current = 1)),
        0;
    
    -- Test 2: All amounts positive
    EXEC etl_testing.usp_AssertEqual 
        'All transaction amounts positive',
        (SELECT COUNT(*) FROM dw.fact_transactions WHERE amount <= 0),
        0;
    
    -- Test 3: Date keys valid
    EXEC etl_testing.usp_AssertEqual 
        'All date keys exist in dim_date',
        (SELECT COUNT(*) FROM dw.fact_transactions f 
         WHERE NOT EXISTS (SELECT 1 FROM dw.dim_date d WHERE d.date_key = f.date_key)),
        0;
    
    -- Test 4: SCD Type 2 integrity
    EXEC etl_testing.usp_AssertEqual 
        'Each customer has exactly one current version',
        (SELECT COUNT(*) FROM (
            SELECT customer_code, COUNT(*) AS cnt
            FROM dw.dim_customer
            WHERE is_current = 1
            GROUP BY customer_code
            HAVING COUNT(*) != 1
        ) x),
        0;
    
    -- Test 5: No overlapping date ranges
    EXEC etl_testing.usp_AssertEqual 
        'No overlapping date ranges in SCD Type 2',
        (SELECT COUNT(*) FROM dw.dim_customer d1
         JOIN dw.dim_customer d2 ON d1.customer_code = d2.customer_code 
         AND d1.effective_date < d2.effective_date
         AND d1.expiry_date >= d2.effective_date),
        0;
END;
```

---

## 6. Performance Testing

```sql
-- ============================================================
-- PERFORMANCE TESTS
-- ============================================================

CREATE PROCEDURE etl_testing.usp_Test_Performance
    @MaxDurationSeconds INT = 300  -- 5 minutes default
AS
BEGIN
    PRINT '=== Performance Tests ===';
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
    
    -- Run ETL and measure time
    EXEC staging.usp_ExtractAll @BatchID;
    EXEC dw.usp_LoadAll @BatchID;
    
    DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
    
    -- Assert duration within threshold
    EXEC etl_testing.usp_AssertEqual 
        'ETL completes within ' + CAST(@MaxDurationSeconds AS VARCHAR(10)) + ' seconds',
        CASE WHEN @Duration <= @MaxDurationSeconds THEN 1 ELSE 0 END,
        1;
    
    PRINT 'Total duration: ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
END;
```

---

## 7. Test Automation

### Run All Tests

```sql
CREATE PROCEDURE etl_testing.usp_RunAllTests
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @TotalTests INT = 0;
    DECLARE @PassedTests INT = 0;
    DECLARE @FailedTests INT = 0;
    
    PRINT '╔═══════════════════════════════════════════════════════════╗';
    PRINT '║           ETL TEST SUITE                                 ║';
    PRINT '╚═══════════════════════════════════════════════════════════╝';
    PRINT '';
    
    -- Clear previous results
    TRUNCATE TABLE etl_testing.test_results;
    
    -- Run Unit Tests
    PRINT '▶ Running Unit Tests...';
    BEGIN TRY
        EXEC etl_testing.usp_Test_ExtractCustomers;
        EXEC etl_testing.usp_Test_LoadDimCustomer;
    END TRY
    BEGIN CATCH
        PRINT 'Error in unit tests: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Run Integration Tests
    PRINT '';
    PRINT '▶ Running Integration Tests...';
    BEGIN TRY
        EXEC etl_testing.usp_Test_FullETLPipeline;
    END TRY
    BEGIN CATCH
        PRINT 'Error in integration tests: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Run Data Quality Tests
    PRINT '';
    PRINT '▶ Running Data Quality Tests...';
    BEGIN TRY
        EXEC etl_testing.usp_Test_DataQuality;
    END TRY
    BEGIN CATCH
        PRINT 'Error in data quality tests: ' + ERROR_MESSAGE();
    END CATCH
    
    -- Calculate results
    SELECT 
        @TotalTests = COUNT(*),
        @PassedTests = SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END),
        @FailedTests = SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END)
    FROM etl_testing.test_results;
    
    -- Display summary
    PRINT '';
    PRINT '╔═══════════════════════════════════════════════════════════╗';
    PRINT '║           TEST RESULTS SUMMARY                           ║';
    PRINT '╠═══════════════════════════════════════════════════════════╣';
    PRINT '║ Total Tests:  ' + CAST(@TotalTests AS VARCHAR(10));
    PRINT '║ Passed:       ' + CAST(@PassedTests AS VARCHAR(10)) + ' ✅';
    PRINT '║ Failed:       ' + CAST(@FailedTests AS VARCHAR(10)) + ' ❌';
    PRINT '║ Pass Rate:    ' + CAST(CAST(@PassedTests * 100.0 / NULLIF(@TotalTests, 0) AS DECIMAL(5,1)) AS VARCHAR(10)) + '%';
    PRINT '║ Duration:     ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR(10)) + ' seconds';
    PRINT '╚═══════════════════════════════════════════════════════════╝';
    
    -- Show failed tests
    IF @FailedTests > 0
    BEGIN
        PRINT '';
        PRINT 'Failed Tests:';
        SELECT 
            test_name,
            expected_result,
            actual_result
        FROM etl_testing.test_results
        WHERE status = 'FAIL';
    END
    
    -- Return status
    IF @FailedTests > 0
        RETURN 1;  -- Tests failed
    RETURN 0;  -- All tests passed
END;
```

### View Test Results

```sql
-- View all test results
SELECT 
    test_name,
    CASE WHEN status = 'PASS' THEN '✅' ELSE '❌' END AS status,
    expected_result,
    actual_result,
    executed_date
FROM etl_testing.test_results
ORDER BY 
    CASE WHEN status = 'FAIL' THEN 0 ELSE 1 END,
    test_name;

-- View test summary by suite
SELECT 
    CASE 
        WHEN test_name LIKE '%Extract%' THEN 'Extract'
        WHEN test_name LIKE '%Load%' THEN 'Load'
        WHEN test_name LIKE '%Data%' THEN 'Data Quality'
        ELSE 'Other'
    END AS test_suite,
    COUNT(*) AS total,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed
FROM etl_testing.test_results
GROUP BY 
    CASE 
        WHEN test_name LIKE '%Extract%' THEN 'Extract'
        WHEN test_name LIKE '%Load%' THEN 'Load'
        WHEN test_name LIKE '%Data%' THEN 'Data Quality'
        ELSE 'Other'
    END;
```

---

## 8. Hands-On Exercise

### Exercise: Write ETL Tests

```sql
-- Step 1: Create test framework tables
-- Step 2: Write unit test for usp_ExtractAccounts
-- Step 3: Write integration test for full pipeline
-- Step 4: Run all tests
-- Step 5: Fix any failures

-- Solution:
EXEC etl_testing.usp_RunAllTests;
```

---

*Created: September 2024*
