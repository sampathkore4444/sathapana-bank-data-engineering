-- ============================================================================
-- SATHAPANA BANK - ETL TRANSFORMATION & LOADING PROCEDURES
-- ============================================================================
-- Purpose: Create stored procedures for data transformation and loading
-- Author: DWH Development Team
-- Created: 2024-01-15
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. MASTER LOAD PROCEDURE
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadAll
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Generate batch ID if not provided
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    PRINT 'Starting DW load for Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    
    BEGIN TRY
        -- Load dimensions first
        EXEC dw.usp_LoadDimDate @BatchID;
        EXEC dw.usp_LoadDimBranch @BatchID;
        EXEC dw.usp_LoadDimProduct @BatchID;
        EXEC dw.usp_LoadDimCustomer @BatchID;
        EXEC dw.usp_LoadDimAccount @BatchID;
        EXEC dw.usp_LoadDimEmployee @BatchID;
        
        -- Load facts
        EXEC dw.usp_LoadFactTransactions @BatchID;
        EXEC dw.usp_LoadFactLoanPortfolio @BatchID;
        EXEC dw.usp_LoadFactDepositSnapshot @BatchID;
        EXEC dw.usp_LoadFactAccountDailySnapshot @BatchID;
        
        PRINT 'DW load completed successfully.';
    END TRY
    BEGIN CATCH
        PRINT 'Error during DW load: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 2. LOAD DIM_DATE - Date Dimension
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadDimDate
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartDate DATE = '2020-01-01';
    DECLARE @EndDate DATE = '2030-12-31';
    DECLARE @CurrentDate DATE = @StartDate;
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Loading Date Dimension...';
    
    -- Only populate if empty
    IF NOT EXISTS (SELECT 1 FROM dw.dim_date)
    BEGIN
        WHILE @CurrentDate <= @EndDate
        BEGIN
            DECLARE @DateKey INT = CAST(FORMAT(@CurrentDate, 'yyyyMMdd') AS INT);
            DECLARE @DayOfWeek TINYINT = DATEPART(WEEKDAY, @CurrentDate);
            DECLARE @DayOfMonth TINYINT = DAY(@CurrentDate);
            DECLARE @DayOfYear SMALLINT = DATEPART(DAYOFYEAR, @CurrentDate);
            DECLARE @WeekOfYear TINYINT = DATEPART(WEEK, @CurrentDate);
            DECLARE @ISOWeek TINYINT = DATEPART(ISO_WEEK, @CurrentDate);
            DECLARE @MonthNumber TINYINT = MONTH(@CurrentDate);
            DECLARE @QuarterNumber TINYINT = DATEPART(QUARTER, @CurrentDate);
            DECLARE @YearNumber SMALLINT = YEAR(@CurrentDate);
            
            -- Cambodian fiscal year (ends Dec 31)
            DECLARE @FiscalYear SMALLINT = @YearNumber;
            DECLARE @FiscalQuarter TINYINT = @QuarterNumber;
            DECLARE @FiscalMonth TINYINT = @MonthNumber;
            
            INSERT INTO dw.dim_date (
                date_key, full_date, day_of_week, day_name, day_name_short,
                day_of_month, day_of_year, week_of_year, iso_week,
                month_number, month_name, month_name_short,
                quarter_number, quarter_name, year_number,
                year_month, year_quarter, fiscal_year, fiscal_quarter, fiscal_month,
                is_weekday, is_weekend, is_business_day, is_holiday,
                is_month_start, is_month_end, is_quarter_start, is_quarter_end,
                is_year_start, is_year_end
            )
            VALUES (
                @DateKey,
                @CurrentDate,
                @DayOfWeek,
                DATENAME(WEEKDAY, @CurrentDate),
                LEFT(DATENAME(WEEKDAY, @CurrentDate), 3),
                @DayOfMonth,
                @DayOfYear,
                @WeekOfYear,
                @ISOWeek,
                @MonthNumber,
                DATENAME(MONTH, @CurrentDate),
                LEFT(DATENAME(MONTH, @CurrentDate), 3),
                @QuarterNumber,
                'Q' + CAST(@QuarterNumber AS VARCHAR(1)),
                @YearNumber,
                FORMAT(@CurrentDate, 'yyyy-MM'),
                CAST(@YearNumber AS VARCHAR(4)) + 'Q' + CAST(@QuarterNumber AS VARCHAR(1)),
                @FiscalYear,
                @FiscalQuarter,
                @FiscalMonth,
                CASE WHEN @DayOfWeek IN (1, 7) THEN 0 ELSE 1 END,
                CASE WHEN @DayOfWeek IN (1, 7) THEN 1 ELSE 0 END,
                CASE WHEN @DayOfWeek IN (1, 7) THEN 0 ELSE 1 END,  -- is_business_day
                0,  -- is_holiday (will be updated for Cambodian holidays)
                CASE WHEN @DayOfMonth = 1 THEN 1 ELSE 0 END,
                CASE WHEN @CurrentDate = EOMONTH(@CurrentDate) THEN 1 ELSE 0 END,
                CASE WHEN @DayOfMonth = 1 AND @QuarterNumber IN (1, 2, 3, 4) THEN 1 ELSE 0 END,
                CASE WHEN @CurrentDate = EOMONTH(@CurrentDate) AND @MonthNumber IN (3, 6, 9, 12) THEN 1 ELSE 0 END,
                CASE WHEN @MonthNumber = 1 AND @DayOfMonth = 1 THEN 1 ELSE 0 END,
                CASE WHEN @MonthNumber = 12 AND @DayOfMonth = 31 THEN 1 ELSE 0 END
            );
            
            SET @RecordCount += 1;
            SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
        END
        
        -- Update previous day keys
        UPDATE d1
        SET prev_day_key = d2.date_key
        FROM dw.dim_date d1
        JOIN dw.dim_date d2 ON d1.full_date = DATEADD(DAY, -1, d2.full_date)
        WHERE d2.date_key IS NOT NULL;
        
        -- Update previous month keys
        UPDATE d1
        SET prev_month_key = d2.date_key
        FROM dw.dim_date d1
        JOIN dw.dim_date d2 ON YEAR(d1.full_date) = YEAR(d2.full_date) 
            AND MONTH(d1.full_date) = MONTH(d2.full_date) + 1
        WHERE d2.date_key IS NOT NULL;
        
        PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' date records.';
    END
    ELSE
    BEGIN
        PRINT 'Date dimension already populated. Skipping.';
    END
END;
GO

-- ============================================================================
-- 3. LOAD DIM_BRANCH - Branch Dimension (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadDimBranch
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    DECLARE @NewCount BIGINT = 0;
    DECLARE @UpdateCount BIGINT = 0;
    
    PRINT 'Loading Branch Dimension...';
    
    -- Insert new branches
    INSERT INTO dw.dim_branch (
        branch_code, branch_name, branch_name_kh, branch_type,
        region, province, district, commune, village,
        address, phone, email, manager_name, is_active,
        effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT 
        s.branch_code,
        s.branch_name,
        s.branch_name_kh,
        s.branch_type,
        s.region,
        s.province,
        s.district,
        s.commune,
        s.village,
        s.address,
        s.phone,
        s.email,
        NULL,  -- manager_name will be populated separately
        s.is_active,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_branches s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_branch d
        WHERE d.branch_code = s.branch_code AND d.is_current = 1
    );
    
    SET @NewCount = @@ROWCOUNT;
    
    -- Update existing branches (SCD Type 2)
    UPDATE d
    SET 
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
        d.is_current = 0,
        d.modified_date = GETDATE()
    FROM dw.dim_branch d
    JOIN sathapana_staging.staging.stg_branches s ON d.branch_code = s.branch_code
    WHERE d.is_current = 1
    AND (
        ISNULL(d.branch_name, '') != ISNULL(s.branch_name, '')
        OR ISNULL(d.branch_type, '') != ISNULL(s.branch_type, '')
        OR ISNULL(d.region, '') != ISNULL(s.region, '')
        OR ISNULL(d.province, '') != ISNULL(s.province, '')
        OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
    );
    
    SET @UpdateCount = @@ROWCOUNT;
    
    -- Insert updated versions
    INSERT INTO dw.dim_branch (
        branch_code, branch_name, branch_name_kh, branch_type,
        region, province, district, commune, village,
        address, phone, email, manager_name, is_active,
        effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT 
        s.branch_code,
        s.branch_name,
        s.branch_name_kh,
        s.branch_type,
        s.region,
        s.province,
        s.district,
        s.commune,
        s.village,
        s.address,
        s.phone,
        s.email,
        NULL,
        s.is_active,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_branches s
    WHERE EXISTS (
        SELECT 1 FROM dw.dim_branch d
        WHERE d.branch_code = s.branch_code AND d.is_current = 0
        AND d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    );
    
    SET @RecordCount = @NewCount + @UpdateCount + @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_DimBranch', 'dim_branch', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@NewCount AS VARCHAR(10)) + ' new, ' + CAST(@UpdateCount AS VARCHAR(10)) + ' updated branch records.';
END;
GO

-- ============================================================================
-- 4. LOAD DIM_PRODUCT - Product Dimension
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadDimProduct
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Loading Product Dimension...';
    
    -- Insert new products
    INSERT INTO dw.dim_product (
        product_code, product_name, product_name_kh, product_category,
        product_subcategory, gl_account_code, currency, interest_rate,
        min_balance, max_balance, min_amount, max_amount, term_months,
        is_active, effective_date, expiry_date,
        source_system, source_key, batch_id
    )
    SELECT 
        s.product_code,
        s.product_name,
        s.product_name_kh,
        s.product_category,
        s.product_subcategory,
        s.gl_account_code,
        s.currency,
        s.interest_rate,
        s.min_balance,
        s.max_balance,
        s.min_amount,
        s.max_amount,
        s.term_months,
        s.is_active,
        ISNULL(s.effective_date, CAST(GETDATE() AS DATE)),
        s.expiry_date,
        'PRODUCT_CATALOG',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_products s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_product d
        WHERE d.product_code = s.product_code
    );
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Update existing products (SCD Type 1 - overwrite)
    UPDATE d
    SET 
        d.product_name = s.product_name,
        d.product_name_kh = s.product_name_kh,
        d.product_category = s.product_category,
        d.product_subcategory = s.product_subcategory,
        d.interest_rate = s.interest_rate,
        d.is_active = s.is_active,
        d.expiry_date = s.expiry_date,
        d.modified_date = GETDATE()
    FROM dw.dim_product d
    JOIN sathapana_staging.staging.stg_products s ON d.product_code = s.product_code;
    
    SET @RecordCount = @RecordCount + @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_DimProduct', 'dim_product', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' product records.';
END;
GO

-- ============================================================================
-- 5. LOAD DIM_CUSTOMER - Customer Dimension (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadDimCustomer
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    DECLARE @NewCount BIGINT = 0;
    DECLARE @UpdateCount BIGINT = 0;
    
    PRINT 'Loading Customer Dimension...';
    
    -- Insert new customers
    INSERT INTO dw.dim_customer (
        customer_code, customer_type, title, first_name, last_name,
        company_name, national_id_type, national_id, passport_number,
        date_of_birth, gender, nationality, email, phone_primary,
        phone_secondary, address_line1, address_line2, province,
        district, commune, village, postal_code, customer_segment,
        risk_rating, kyc_status, kyc_verified_date, kyc_expiry_date,
        tax_id, employer_name, occupation, annual_income, marital_status,
        referrer_code, acquisition_channel, is_active, is_pep, is_sanctioned,
        effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT 
        s.customer_code,
        s.customer_type,
        s.title,
        s.first_name,
        s.last_name,
        s.company_name,
        s.national_id_type,
        s.national_id,
        s.passport_number,
        s.date_of_birth,
        s.gender,
        s.nationality,
        s.email,
        s.phone_primary,
        s.phone_secondary,
        s.address_line1,
        s.address_line2,
        s.province,
        s.district,
        s.commune,
        s.village,
        s.postal_code,
        s.customer_segment,
        s.risk_rating,
        s.kyc_status,
        s.kyc_verified_date,
        s.kyc_expiry_date,
        s.tax_id,
        s.employer_name,
        s.occupation,
        s.annual_income,
        s.marital_status,
        s.referrer_code,
        s.acquisition_channel,
        s.is_active,
        ISNULL(s.is_pep, 0),
        ISNULL(s.is_sanctioned, 0),
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_customers s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_customer d
        WHERE d.customer_code = s.customer_code AND d.is_current = 1
    );
    
    SET @NewCount = @@ROWCOUNT;
    
    -- Update existing customers (SCD Type 2)
    UPDATE d
    SET 
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
        d.is_current = 0,
        d.modified_date = GETDATE()
    FROM dw.dim_customer d
    JOIN sathapana_staging.staging.stg_customers s ON d.customer_code = s.customer_code
    WHERE d.is_current = 1
    AND (
        ISNULL(d.first_name, '') != ISNULL(s.first_name, '')
        OR ISNULL(d.last_name, '') != ISNULL(s.last_name, '')
        OR ISNULL(d.phone_primary, '') != ISNULL(s.phone_primary, '')
        OR ISNULL(d.email, '') != ISNULL(s.email, '')
        OR ISNULL(d.address_line1, '') != ISNULL(s.address_line1, '')
        OR ISNULL(d.customer_segment, '') != ISNULL(s.customer_segment, '')
        OR ISNULL(d.risk_rating, '') != ISNULL(s.risk_rating, '')
        OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
    );
    
    SET @UpdateCount = @@ROWCOUNT;
    
    -- Insert updated versions
    INSERT INTO dw.dim_customer (
        customer_code, customer_type, title, first_name, last_name,
        company_name, national_id_type, national_id, passport_number,
        date_of_birth, gender, nationality, email, phone_primary,
        phone_secondary, address_line1, address_line2, province,
        district, commune, village, postal_code, customer_segment,
        risk_rating, kyc_status, kyc_verified_date, kyc_expiry_date,
        tax_id, employer_name, occupation, annual_income, marital_status,
        referrer_code, acquisition_channel, is_active, is_pep, is_sanctioned,
        effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT 
        s.customer_code,
        s.customer_type,
        s.title,
        s.first_name,
        s.last_name,
        s.company_name,
        s.national_id_type,
        s.national_id,
        s.passport_number,
        s.date_of_birth,
        s.gender,
        s.nationality,
        s.email,
        s.phone_primary,
        s.phone_secondary,
        s.address_line1,
        s.address_line2,
        s.province,
        s.district,
        s.commune,
        s.village,
        s.postal_code,
        s.customer_segment,
        s.risk_rating,
        s.kyc_status,
        s.kyc_verified_date,
        s.kyc_expiry_date,
        s.tax_id,
        s.employer_name,
        s.occupation,
        s.annual_income,
        s.marital_status,
        s.referrer_code,
        s.acquisition_channel,
        s.is_active,
        ISNULL(s.is_pep, 0),
        ISNULL(s.is_sanctioned, 0),
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_customers s
    WHERE EXISTS (
        SELECT 1 FROM dw.dim_customer d
        WHERE d.customer_code = s.customer_code AND d.is_current = 0
        AND d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    );
    
    SET @RecordCount = @NewCount + @UpdateCount + @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_DimCustomer', 'dim_customer', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@NewCount AS VARCHAR(10)) + ' new, ' + CAST(@UpdateCount AS VARCHAR(10)) + ' updated customer records.';
END;
GO

-- ============================================================================
-- 6. LOAD DIM_ACCOUNT - Account Dimension (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadDimAccount
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Loading Account Dimension...';
    
    -- Insert new accounts
    INSERT INTO dw.dim_account (
        account_number, customer_key, product_key, branch_key,
        currency, account_type, account_status, open_date, close_date,
        maturity_date, credit_limit, interest_rate, last_transaction_date,
        dormant_date, is_active,
        effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT 
        s.account_number,
        c.customer_key,
        p.product_key,
        b.branch_key,
        s.currency,
        s.account_type,
        s.account_status,
        s.open_date,
        s.close_date,
        s.maturity_date,
        s.credit_limit,
        s.interest_rate,
        s.last_transaction_date,
        s.dormant_date,
        s.is_active,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_accounts s
    JOIN dw.dim_customer c ON s.customer_code = c.customer_code AND c.is_current = 1
    JOIN dw.dim_product p ON s.product_code = p.product_code
    JOIN dw.dim_branch b ON s.branch_code = b.branch_code AND b.is_current = 1
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_account d
        WHERE d.account_number = s.account_number AND d.is_current = 1
    );
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Update existing accounts (SCD Type 2)
    UPDATE d
    SET 
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
        d.is_current = 0,
        d.modified_date = GETDATE()
    FROM dw.dim_account d
    JOIN sathapana_staging.staging.stg_accounts s ON d.account_number = s.account_number
    WHERE d.is_current = 1
    AND (
        ISNULL(d.account_status, '') != ISNULL(s.account_status, '')
        OR ISNULL(d.interest_rate, 0) != ISNULL(s.interest_rate, 0)
        OR ISNULL(d.credit_limit, 0) != ISNULL(s.credit_limit, 0)
        OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
    );
    
    SET @RecordCount = @RecordCount + @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_DimAccount', 'dim_account', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' account records.';
END;
GO

-- ============================================================================
-- 7. LOAD DIM_EMPLOYEE - Employee Dimension (SCD Type 2)
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadDimEmployee
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Loading Employee Dimension...';
    
    -- Insert new employees
    INSERT INTO dw.dim_employee (
        employee_code, national_id, first_name, last_name,
        date_of_birth, gender, email, phone, hire_date,
        termination_date, job_title, department, branch_key,
        salary_grade, is_active,
        effective_date, expiry_date, is_current,
        source_system, source_key, batch_id
    )
    SELECT 
        s.employee_code,
        s.national_id,
        s.first_name,
        s.last_name,
        s.date_of_birth,
        s.gender,
        s.email,
        s.phone,
        s.hire_date,
        s.termination_date,
        s.job_title,
        s.department,
        b.branch_key,
        s.salary_grade,
        s.is_active,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        'HR_SYSTEM',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_employees s
    JOIN dw.dim_branch b ON s.branch_code = b.branch_code AND b.is_current = 1
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_employee d
        WHERE d.employee_code = s.employee_code AND d.is_current = 1
    );
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Update existing employees (SCD Type 2)
    UPDATE d
    SET 
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
        d.is_current = 0,
        d.modified_date = GETDATE()
    FROM dw.dim_employee d
    JOIN sathapana_staging.staging.stg_employees s ON d.employee_code = s.employee_code
    WHERE d.is_current = 1
    AND (
        ISNULL(d.job_title, '') != ISNULL(s.job_title, '')
        OR ISNULL(d.department, '') != ISNULL(s.department, '')
        OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
    );
    
    SET @RecordCount = @RecordCount + @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_DimEmployee', 'dim_employee', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' employee records.';
END;
GO

-- ============================================================================
-- 8. LOAD FACT_TRANSACTIONS
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadFactTransactions
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Loading Transaction Fact Table...';
    
    INSERT INTO dw.fact_transactions (
        transaction_code, account_key, customer_key, product_key,
        branch_key, channel_key, transaction_date_key, value_date_key,
        transaction_type_key, amount, amount_usd, currency, exchange_rate,
        balance_before, balance_after, fee_amount, tax_amount,
        reference_number, counterparty_account, counterparty_bank,
        status, transaction_datetime, source_system, source_key,
        etl_batch_id
    )
    SELECT 
        s.transaction_code,
        a.account_key,
        c.customer_key,
        p.product_key,
        b.branch_key,
        ch.channel_key,
        CAST(FORMAT(s.transaction_date, 'yyyyMMdd') AS INT) AS transaction_date_key,
        CAST(FORMAT(s.value_date, 'yyyyMMdd') AS INT) AS value_date_key,
        CASE s.transaction_type
            WHEN 'DEPOSIT' THEN 1
            WHEN 'WITHDRAWAL' THEN 2
            WHEN 'TRANSFER_IN' THEN 3
            WHEN 'TRANSFER_OUT' THEN 4
            WHEN 'FEE' THEN 5
            WHEN 'INTEREST' THEN 6
            WHEN 'REVERSAL' THEN 7
            WHEN 'ADJUSTMENT' THEN 8
        END AS transaction_type_key,
        s.amount,
        CASE 
            WHEN s.currency = 'KHR' THEN s.amount / 4100.00
            WHEN s.currency = 'USD' THEN s.amount
            ELSE s.amount * er.rate
        END AS amount_usd,
        s.currency,
        s.exchange_rate,
        s.balance_before,
        s.balance_after,
        s.fee_amount,
        s.tax_amount,
        s.reference_number,
        s.counterparty_account,
        s.counterparty_bank,
        s.status,
        s.transaction_date,
        'CORE_BANKING',
        s.source_key,
        @BatchID
    FROM sathapana_staging.staging.stg_transactions s
    JOIN dw.dim_account a ON s.account_number = a.account_number AND a.is_current = 1
    JOIN dw.dim_customer c ON s.customer_code = c.customer_code AND c.is_current = 1
    JOIN dw.dim_product p ON a.product_key = p.product_key
    JOIN dw.dim_branch b ON s.branch_code = b.branch_code AND b.is_current = 1
    JOIN dw.dim_channel ch ON s.transaction_channel = ch.channel_code
    LEFT JOIN sathapana_staging.staging.stg_exchange_rates er 
        ON s.currency = er.source_currency 
        AND er.target_currency = 'USD'
        AND er.rate_date = CAST(s.transaction_date AS DATE)
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.fact_transactions d
        WHERE d.transaction_code = s.transaction_code
    );
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_FactTransactions', 'fact_transactions', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' transaction records.';
END;
GO

-- ============================================================================
-- 9. LOAD FACT_LOAN_PORTFOLIO
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadFactLoanPortfolio
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    DECLARE @SnapshotDateKey INT = CAST(FORMAT(GETDATE(), 'yyyyMMdd') AS INT);
    
    PRINT 'Loading Loan Portfolio Fact Table...';
    
    INSERT INTO dw.fact_loan_portfolio (
        loan_key, customer_key, product_key, branch_key, employee_key,
        snapshot_date_key, loan_amount, approved_amount, disbursed_amount,
        outstanding_principal, accrued_interest, provision_amount,
        days_past_due, emi_amount, risk_classification, is_restructured,
        source_system, etl_batch_id
    )
    SELECT 
        l.loan_id AS loan_key,  -- Simplified; in production, use surrogate key
        c.customer_key,
        p.product_key,
        b.branch_key,
        e.employee_key,
        @SnapshotDateKey,
        s.loan_amount,
        s.approved_amount,
        s.disbursed_amount,
        s.outstanding_principal,
        0 AS accrued_interest,
        s.provision_amount,
        s.days_past_due,
        s.emi_amount,
        s.risk_classification,
        0 AS is_restructured,
        'LOAN_SYSTEM',
        @BatchID
    FROM sathapana_staging.staging.stg_loans s
    JOIN dw.dim_customer c ON s.customer_code = c.customer_code AND c.is_current = 1
    JOIN dw.dim_product p ON s.product_code = p.product_code
    JOIN dw.dim_branch b ON s.branch_code = b.branch_code AND b.is_current = 1
    LEFT JOIN dw.dim_employee e ON s.relationship_officer_code = e.employee_code AND e.is_current = 1;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_FactLoanPortfolio', 'fact_loan_portfolio', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' loan portfolio records.';
END;
GO

-- ============================================================================
-- 10. LOAD FACT_DEPOSIT_SNAPSHOT
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadFactDepositSnapshot
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    DECLARE @SnapshotDateKey INT = CAST(FORMAT(GETDATE(), 'yyyyMMdd') AS INT);
    
    PRINT 'Loading Deposit Snapshot Fact Table...';
    
    INSERT INTO dw.fact_deposit_snapshot (
        account_key, customer_key, product_key, branch_key,
        snapshot_date_key, balance, available_balance,
        interest_earned, interest_accrued, interest_rate, maturity_date,
        source_system, etl_batch_id
    )
    SELECT 
        a.account_key,
        c.customer_key,
        p.product_key,
        b.branch_key,
        @SnapshotDateKey,
        s.balance,
        s.available_balance,
        0 AS interest_earned,
        0 AS interest_accrued,
        a.interest_rate,
        a.maturity_date,
        'CORE_BANKING',
        @BatchID
    FROM sathapana_staging.staging.stg_accounts s
    JOIN dw.dim_account a ON s.account_number = a.account_number AND a.is_current = 1
    JOIN dw.dim_customer c ON a.customer_key = c.customer_key
    JOIN dw.dim_product p ON a.product_key = p.product_key
    JOIN dw.dim_branch b ON a.branch_key = b.branch_key
    WHERE s.account_type IN ('SAVINGS', 'CURRENT', 'TERM_DEPOSIT')
    AND s.is_active = 1;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_FactDepositSnapshot', 'fact_deposit_snapshot', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' deposit snapshot records.';
END;
GO

-- ============================================================================
-- 11. LOAD FACT_ACCOUNT_DAILY_SNAPSHOT
-- ============================================================================
CREATE OR ALTER PROCEDURE dw.usp_LoadFactAccountDailySnapshot
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    DECLARE @SnapshotDateKey INT = CAST(FORMAT(GETDATE(), 'yyyyMMdd') AS INT);
    
    PRINT 'Loading Account Daily Snapshot Fact Table...';
    
    INSERT INTO dw.fact_account_daily_snapshot (
        account_key, customer_key, product_key, branch_key,
        snapshot_date_key, opening_balance, closing_balance,
        total_debits, total_credits, transaction_count,
        debit_count, credit_count, average_balance,
        min_balance, max_balance,
        source_system, etl_batch_id
    )
    SELECT 
        a.account_key,
        c.customer_key,
        p.product_key,
        b.branch_key,
        @SnapshotDateKey,
        ISNULL(s.balance, 0) AS opening_balance,
        ISNULL(s.balance, 0) AS closing_balance,
        ISNULL(t.total_debits, 0),
        ISNULL(t.total_credits, 0),
        ISNULL(t.transaction_count, 0),
        ISNULL(t.debit_count, 0),
        ISNULL(t.credit_count, 0),
        ISNULL(s.balance, 0) AS average_balance,
        ISNULL(s.balance, 0) AS min_balance,
        ISNULL(s.balance, 0) AS max_balance,
        'CORE_BANKING',
        @BatchID
    FROM sathapana_staging.staging.stg_accounts s
    JOIN dw.dim_account a ON s.account_number = a.account_number AND a.is_current = 1
    JOIN dw.dim_customer c ON a.customer_key = c.customer_key
    JOIN dw.dim_product p ON a.product_key = p.product_key
    JOIN dw.dim_branch b ON a.branch_key = b.branch_key
    LEFT JOIN (
        SELECT 
            account_number,
            SUM(CASE WHEN transaction_type IN ('WITHDRAWAL', 'TRANSFER_OUT') THEN amount ELSE 0 END) AS total_debits,
            SUM(CASE WHEN transaction_type IN ('DEPOSIT', 'TRANSFER_IN') THEN amount ELSE 0 END) AS total_credits,
            COUNT(*) AS transaction_count,
            SUM(CASE WHEN transaction_type IN ('WITHDRAWAL', 'TRANSFER_OUT') THEN 1 ELSE 0 END) AS debit_count,
            SUM(CASE WHEN transaction_type IN ('DEPOSIT', 'TRANSFER_IN') THEN 1 ELSE 0 END) AS credit_count
        FROM sathapana_staging.staging.stg_transactions
        WHERE CAST(transaction_date AS DATE) = CAST(GETDATE() AS DATE)
        GROUP BY account_number
    ) t ON s.account_number = t.account_number
    WHERE s.is_active = 1;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO audit.etl_log (batch_id, step_name, table_name, operation, records_affected, status, start_time, end_time)
    VALUES (@BatchID, 'Load_FactAccountDailySnapshot', 'fact_account_daily_snapshot', 'LOAD', @RecordCount, 'COMPLETED', @StartTime, GETDATE());
    
    PRINT 'Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' account daily snapshot records.';
END;
GO

-- ============================================================================
-- 12. VERIFY LOADING PROCEDURES
-- ============================================================================
PRINT '================================================';
PRINT 'TRANSFORMATION & LOADING PROCEDURES CREATED';
PRINT '================================================';
PRINT '';
PRINT 'Procedures created:';
SELECT COUNT(*) AS procedure_count 
FROM sys.procedures 
WHERE schema_id = SCHEMA_ID('dw') 
AND name LIKE 'usp_Load%';
PRINT '';
PRINT '================================================';
GO
