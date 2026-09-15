# ✅ Data Quality Checks for ETL

## Table of Contents
1. [Overview](#1-overview)
2. [Data Quality Dimensions](#2-data-quality-dimensions)
3. [Quality Check Types](#3-quality-check-types)
4. [Implementation](#4-implementation)
5. [Data Profiling](#5-data-profiling)
6. [Quality Rules Engine](#6-quality-rules-engine)
7. [Hands-On Exercise](#7-hands-on-exercise)

---

## 1. Overview

Data Quality Checks ensure that data moving through the ETL pipeline is **accurate, complete, consistent, and valid** before it reaches the data warehouse.

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA QUALITY FLOW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │ SOURCE      │  Raw data from systems                        │
│  │ DATA        │  (may have quality issues)                    │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ QUALITY     │  Check: Completeness, Accuracy,               │
│  │ CHECKS      │  Validity, Consistency, Uniqueness             │
│  └──────┬──────┘                                                │
│         │                                                        │
│    ┌────┴────┐                                                  │
│    │         │                                                  │
│    ▼         ▼                                                  │
│  ┌─────┐  ┌─────┐                                              │
│  │ PASS│  │FAIL │                                              │
│  └──┬──┘  └──┬──┘                                              │
│     │        │                                                  │
│     ▼        ▼                                                  │
│  ┌─────┐  ┌─────────┐                                          │
│  │LOAD │  │REJECT & │                                          │
│  │     │  │LOG      │                                          │
│  └─────┘  └─────────┘                                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Quality Dimensions

| Dimension | Description | Example |
|-----------|-------------|---------|
| **Completeness** | Required fields are not NULL | Customer must have email |
| **Accuracy** | Data matches real-world values | Age must be 0-150 |
| **Validity** | Data follows defined format | Phone format: 0XX-XXX-XXXX |
| **Consistency** | Data matches across systems | Customer name same in all tables |
| **Uniqueness** | No duplicate records | One record per customer_code |
| **Timeliness** | Data is up-to-date | Transaction date not in future |

---

## 3. Quality Check Types

### 3.1 Completeness Checks

```sql
-- Check for NULL values in required fields
CREATE PROCEDURE dq.usp_CheckCompleteness
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @Results TABLE (
        table_name VARCHAR(100),
        column_name VARCHAR(100),
        total_rows BIGINT,
        null_count BIGINT,
        completeness_pct DECIMAL(5,2)
    );
    
    -- Check customers
    INSERT INTO @Results
    SELECT 
        'stg_customers',
        'customer_code',
        COUNT(*),
        SUM(CASE WHEN customer_code IS NULL THEN 1 ELSE 0 END),
        CAST(100.0 - (SUM(CASE WHEN customer_code IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS DECIMAL(5,2))
    FROM staging.stg_customers;
    
    INSERT INTO @Results
    SELECT 
        'stg_customers',
        'email',
        COUNT(*),
        SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END),
        CAST(100.0 - (SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS DECIMAL(5,2))
    FROM staging.stg_customers;
    
    -- Check accounts
    INSERT INTO @Results
    SELECT 
        'stg_accounts',
        'account_number',
        COUNT(*),
        SUM(CASE WHEN account_number IS NULL THEN 1 ELSE 0 END),
        CAST(100.0 - (SUM(CASE WHEN account_number IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)) AS DECIMAL(5,2))
    FROM staging.stg_accounts;
    
    SELECT * FROM @Results;
    
    -- Flag failures
    IF EXISTS (SELECT 1 FROM @Results WHERE completeness_pct < 95)
    BEGIN
        PRINT 'WARNING: Completeness check failed for some columns!';
    END
END;
```

### 3.2 Uniqueness Checks

```sql
-- Check for duplicate records
CREATE PROCEDURE dq.usp_CheckUniqueness
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @Results TABLE (
        table_name VARCHAR(100),
        column_name VARCHAR(100),
        duplicate_count BIGINT,
        status VARCHAR(20)
    );
    
    -- Check customer_code uniqueness
    INSERT INTO @Results
    SELECT 
        'stg_customers',
        'customer_code',
        COUNT(*) - COUNT(DISTINCT customer_code),
        CASE 
            WHEN COUNT(*) - COUNT(DISTINCT customer_code) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_customers;
    
    -- Check account_number uniqueness
    INSERT INTO @Results
    SELECT 
        'stg_accounts',
        'account_number',
        COUNT(*) - COUNT(DISTINCT account_number),
        CASE 
            WHEN COUNT(*) - COUNT(DISTINCT account_number) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_accounts;
    
    -- Check transaction_code uniqueness
    INSERT INTO @Results
    SELECT 
        'stg_transactions',
        'transaction_code',
        COUNT(*) - COUNT(DISTINCT transaction_code),
        CASE 
            WHEN COUNT(*) - COUNT(DISTINCT transaction_code) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_transactions;
    
    SELECT * FROM @Results;
    
    -- Show duplicate details if any
    IF EXISTS (SELECT 1 FROM @Results WHERE status = 'FAIL')
    BEGIN
        PRINT 'Duplicate records found:';
        
        SELECT customer_code, COUNT(*) AS cnt
        FROM staging.stg_customers
        GROUP BY customer_code
        HAVING COUNT(*) > 1;
    END
END;
```

### 3.3 Validity Checks

```sql
-- Check data format and value validity
CREATE PROCEDURE dq.usp_CheckValidity
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @Results TABLE (
        table_name VARCHAR(100),
        column_name VARCHAR(100),
        invalid_count BIGINT,
        invalid_examples NVARCHAR(500),
        status VARCHAR(20)
    );
    
    -- Check email format
    INSERT INTO @Results
    SELECT 
        'stg_customers',
        'email',
        COUNT(*),
        STRING_AGG(email, ', '),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_customers
    WHERE email IS NOT NULL
    AND email NOT LIKE '%_@_%.__%';
    
    -- Check phone format (Cambodian format)
    INSERT INTO @Results
    SELECT 
        'stg_customers',
        'phone',
        COUNT(*),
        STRING_AGG(phone, ', '),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_customers
    WHERE phone IS NOT NULL
    AND phone NOT LIKE '0__-___-____';
    
    -- Check risk_rating valid values
    INSERT INTO @Results
    SELECT 
        'stg_customers',
        'risk_rating',
        COUNT(*),
        STRING_AGG(DISTINCT risk_rating, ', '),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_customers
    WHERE risk_rating NOT IN ('Low', 'Medium', 'High', 'Very High');
    
    -- Check amount is positive
    INSERT INTO @Results
    SELECT 
        'stg_transactions',
        'amount',
        COUNT(*),
        CAST(MIN(amount) AS VARCHAR(20)) + ' to ' + CAST(MAX(amount) AS VARCHAR(20)),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_transactions
    WHERE amount <= 0;
    
    SELECT * FROM @Results;
END;
```

### 3.4 Consistency Checks

```sql
-- Check referential integrity
CREATE PROCEDURE dq.usp_CheckConsistency
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @Results TABLE (
        check_name VARCHAR(100),
        invalid_count BIGINT,
        status VARCHAR(20)
    );
    
    -- Check accounts reference valid customers
    INSERT INTO @Results
    SELECT 
        'Account references valid customer',
        COUNT(*),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_accounts a
    WHERE NOT EXISTS (
        SELECT 1 FROM staging.stg_customers c
        WHERE c.customer_code = a.customer_code
    );
    
    -- Check transactions reference valid accounts
    INSERT INTO @Results
    SELECT 
        'Transaction references valid account',
        COUNT(*),
        CASE 
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_transactions t
    WHERE NOT EXISTS (
        SELECT 1 FROM staging.stg_accounts a
        WHERE a.account_number = t.account_number
    );
    
    SELECT * FROM @Results;
END;
```

### 3.5 Timeliness Checks

```sql
-- Check data freshness
CREATE PROCEDURE dq.usp_CheckTimeliness
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @Results TABLE (
        table_name VARCHAR(100),
        max_date DATETIME,
        hours_old DECIMAL(10,2),
        status VARCHAR(20)
    );
    
    -- Check transaction freshness
    INSERT INTO @Results
    SELECT 
        'stg_transactions',
        MAX(transaction_date),
        DATEDIFF(HOUR, MAX(transaction_date), GETDATE()),
        CASE 
            WHEN DATEDIFF(HOUR, MAX(transaction_date), GETDATE()) <= 24 THEN 'PASS'
            ELSE 'FAIL'
        END
    FROM staging.stg_transactions;
    
    SELECT * FROM @Results;
END;
```

---

## 4. Implementation

### 4.1 Quality Check Master Procedure

```sql
CREATE PROCEDURE dq.usp_RunAllQualityChecks
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @TotalChecks INT = 0;
    DECLARE @PassedChecks INT = 0;
    DECLARE @FailedChecks INT = 0;
    
    PRINT '================================================';
    PRINT 'DATA QUALITY CHECKS';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT '================================================';
    
    -- Create quality results table
    CREATE TABLE #QualityResults (
        check_id INT IDENTITY(1,1),
        check_category VARCHAR(50),
        table_name VARCHAR(100),
        column_name VARCHAR(100),
        check_type VARCHAR(50),
        total_rows BIGINT,
        issue_count BIGINT,
        status VARCHAR(20),
        details NVARCHAR(MAX)
    );
    
    -- Run completeness checks
    INSERT INTO #QualityResults (check_category, table_name, column_name, check_type, total_rows, issue_count, status)
    SELECT 'Completeness', 'stg_customers', 'customer_code', 'NOT_NULL',
        COUNT(*), SUM(CASE WHEN customer_code IS NULL THEN 1 ELSE 0 END),
        CASE WHEN SUM(CASE WHEN customer_code IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM staging.stg_customers;
    
    -- Run uniqueness checks
    INSERT INTO #QualityResults (check_category, table_name, column_name, check_type, total_rows, issue_count, status)
    SELECT 'Uniqueness', 'stg_customers', 'customer_code', 'UNIQUE',
        COUNT(*), COUNT(*) - COUNT(DISTINCT customer_code),
        CASE WHEN COUNT(*) = COUNT(DISTINCT customer_code) THEN 'PASS' ELSE 'FAIL' END
    FROM staging.stg_customers;
    
    -- Run validity checks
    INSERT INTO #QualityResults (check_category, table_name, column_name, check_type, total_rows, issue_count, status)
    SELECT 'Validity', 'stg_transactions', 'amount', 'POSITIVE',
        COUNT(*), SUM(CASE WHEN amount <= 0 THEN 1 ELSE 0 END),
        CASE WHEN SUM(CASE WHEN amount <= 0 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM staging.stg_transactions;
    
    -- Calculate summary
    SET @TotalChecks = (SELECT COUNT(*) FROM #QualityResults);
    SET @PassedChecks = (SELECT COUNT(*) FROM #QualityResults WHERE status = 'PASS');
    SET @FailedChecks = (SELECT COUNT(*) FROM #QualityResults WHERE status = 'FAIL');
    
    -- Display results
    SELECT 
        check_category,
        table_name,
        column_name,
        check_type,
        total_rows,
        issue_count,
        status
    FROM #QualityResults
    ORDER BY status DESC, check_category;
    
    -- Display summary
    PRINT '';
    PRINT '================================================';
    PRINT 'QUALITY CHECK SUMMARY';
    PRINT '================================================';
    PRINT 'Total Checks:  ' + CAST(@TotalChecks AS VARCHAR(10));
    PRINT 'Passed:        ' + CAST(@PassedChecks AS VARCHAR(10));
    PRINT 'Failed:        ' + CAST(@FailedChecks AS VARCHAR(10));
    PRINT 'Pass Rate:     ' + CAST(CAST(@PassedChecks * 100.0 / @TotalChecks AS DECIMAL(5,1)) AS VARCHAR(10)) + '%';
    
    -- Log results
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time, notes
    )
    VALUES (
        @BatchID, 'Data_Quality_Checks', 'ALL', 'VALIDATE',
        @TotalChecks, 
        CASE WHEN @FailedChecks = 0 THEN 'COMPLETED' ELSE 'WARNING' END,
        @StartTime, GETDATE(),
        'Passed: ' + CAST(@PassedChecks AS VARCHAR(10)) + 
        ', Failed: ' + CAST(@FailedChecks AS VARCHAR(10))
    );
    
    DROP TABLE #QualityResults;
    
    -- Return failure status
    IF @FailedChecks > 0
        RETURN 1;  -- Indicate quality issues found
    
    RETURN 0;  -- All checks passed
END;
```

---

## 5. Data Profiling

```sql
-- Data profiling queries for understanding your data
CREATE PROCEDURE dq.usp_ProfileCustomers
AS
BEGIN
    PRINT '=== CUSTOMER DATA PROFILE ===';
    
    -- Row count
    SELECT COUNT(*) AS total_customers FROM staging.stg_customers;
    
    -- NULL analysis
    SELECT 
        'customer_code' AS column_name,
        COUNT(*) AS total_rows,
        SUM(CASE WHEN customer_code IS NULL THEN 1 ELSE 0 END) AS null_count,
        CAST(SUM(CASE WHEN customer_code IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS null_pct
    FROM staging.stg_customers
    UNION ALL
    SELECT 
        'email',
        COUNT(*),
        SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END),
        CAST(SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2))
    FROM staging.stg_customers;
    
    -- Value distribution
    SELECT 
        risk_rating,
        COUNT(*) AS cnt,
        CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM staging.stg_customers) AS DECIMAL(5,1)) AS pct
    FROM staging.stg_customers
    GROUP BY risk_rating
    ORDER BY cnt DESC;
    
    -- City distribution
    SELECT TOP 10
        city,
        COUNT(*) AS cnt
    FROM staging.stg_customers
    GROUP BY city
    ORDER BY cnt DESC;
END;
```

---

## 6. Quality Rules Engine

```sql
-- Quality rules configuration table
CREATE TABLE dq.quality_rules (
    rule_id INT IDENTITY(1,1) PRIMARY KEY,
    rule_name VARCHAR(100),
    table_name VARCHAR(100),
    column_name VARCHAR(100),
    rule_type VARCHAR(50),  -- NOT_NULL, UNIQUE, FORMAT, RANGE, LOOKUP
    rule_expression NVARCHAR(500),
    severity VARCHAR(20),   -- CRITICAL, HIGH, MEDIUM, LOW
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE()
);

-- Insert sample rules
INSERT INTO dq.quality_rules (rule_name, table_name, column_name, rule_type, rule_expression, severity)
VALUES
    ('Customer code required', 'stg_customers', 'customer_code', 'NOT_NULL', 'customer_code IS NOT NULL', 'CRITICAL'),
    ('Customer code unique', 'stg_customers', 'customer_code', 'UNIQUE', 'COUNT(*) = COUNT(DISTINCT customer_code)', 'CRITICAL'),
    ('Email format valid', 'stg_customers', 'email', 'FORMAT', 'email LIKE ''%_@_%.__%''', 'HIGH'),
    ('Phone format valid', 'stg_customers', 'phone', 'FORMAT', 'phone LIKE ''0__-___-____''', 'MEDIUM'),
    ('Amount positive', 'stg_transactions', 'amount', 'RANGE', 'amount > 0', 'CRITICAL'),
    ('Valid risk rating', 'stg_customers', 'risk_rating', 'LOOKUP', 'risk_rating IN (''Low'',''Medium'',''High'',''Very High'')', 'HIGH');

-- Dynamic quality check execution
CREATE PROCEDURE dq.usp_ExecuteQualityRules
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @RuleName VARCHAR(100);
    DECLARE @TableName VARCHAR(100);
    DECLARE @ColumnName VARCHAR(100);
    DECLARE @RuleType VARCHAR(50);
    DECLARE @RuleExpression NVARCHAR(500);
    DECLARE @Severity VARCHAR(20);
    DECLARE @IssueCount BIGINT;
    
    DECLARE rule_cursor CURSOR FOR
        SELECT rule_name, table_name, column_name, rule_type, rule_expression, severity
        FROM dq.quality_rules
        WHERE is_active = 1;
    
    OPEN rule_cursor;
    FETCH NEXT FROM rule_cursor INTO @RuleName, @TableName, @ColumnName, @RuleType, @RuleExpression, @Severity;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            IF @RuleType = 'NOT_NULL'
            BEGIN
                SET @SQL = N'SELECT @cnt = SUM(CASE WHEN ' + @ColumnName + ' IS NULL THEN 1 ELSE 0 END) FROM staging.' + @TableName;
            END
            ELSE IF @RuleType = 'UNIQUE'
            BEGIN
                SET @SQL = N'SELECT @cnt = COUNT(*) - COUNT(DISTINCT ' + @ColumnName + ') FROM staging.' + @TableName;
            END
            ELSE IF @RuleType = 'FORMAT'
            BEGIN
                SET @SQL = N'SELECT @cnt = COUNT(*) FROM staging.' + @TableName + ' WHERE ' + @ColumnName + ' IS NOT NULL AND NOT (' + @RuleExpression + ')';
            END
            ELSE IF @RuleType = 'RANGE'
            BEGIN
                SET @SQL = N'SELECT @cnt = COUNT(*) FROM staging.' + @TableName + ' WHERE NOT (' + @RuleExpression + ')';
            END
            ELSE IF @RuleType = 'LOOKUP'
            BEGIN
                SET @SQL = N'SELECT @cnt = COUNT(*) FROM staging.' + @TableName + ' WHERE ' + @ColumnName + ' IS NOT NULL AND NOT (' + @RuleExpression + ')';
            END
            
            EXEC sp_executesql @SQL, N'@cnt BIGINT OUTPUT', @IssueCount OUTPUT;
            
            PRINT @RuleName + ': ' + CAST(@IssueCount AS VARCHAR(10)) + ' issues (' + @Severity + ')';
            
        END TRY
        BEGIN CATCH
            PRINT @RuleName + ': ERROR - ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM rule_cursor INTO @RuleName, @TableName, @ColumnName, @RuleType, @RuleExpression, @Severity;
    END
    
    CLOSE rule_cursor;
    DEALLOCATE rule_cursor;
END;
```

---

## 7. Hands-On Exercise

### Exercise: Implement Data Quality Checks

```sql
-- Step 1: Create quality check tables
CREATE SCHEMA dq;
GO

-- Step 2: Implement completeness check for customers
-- Step 3: Implement uniqueness check for accounts
-- Step 4: Implement validity check for transactions (amount > 0)
-- Step 5: Run all checks and view results

-- Solution:
EXEC dq.usp_RunAllQualityChecks @BatchID = NEWID();
```

---

*Created: September 2024*
