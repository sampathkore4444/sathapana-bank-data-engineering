# 🏗️ Build a Complete ETL Pipeline from Scratch

## Table of Contents
1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Architecture Design](#3-architecture-design)
4. [Step 1: Create Database Structure](#4-step-1-create-database-structure)
5. [Step 2: Create Source Tables](#5-step-2-create-source-tables)
6. [Step 3: Create Staging Tables](#6-step-3-create-staging-tables)
7. [Step 4: Create Dimension Tables](#7-step-4-create-dimension-tables)
8. [Step 5: Create Fact Tables](#8-step-5-create-fact-tables)
9. [Step 6: Create ETL Control Tables](#9-step-6-create-etl-control-tables)
10. [Step 7: Build Extract Procedures](#10-step-7-build-extract-procedures)
11. [Step 8: Build Transform & Load Procedures](#11-step-8-build-transform--load-procedures)
12. [Step 9: Build Audit & Logging](#12-step-9-build-audit--logging)
13. [Step 10: Create Master Orchestrator](#13-step-10-create-master-orchestrator)
14. [Step 11: Test the Complete Pipeline](#14-step-11-test-the-complete-pipeline)
15. [Step 12: Schedule with SQL Agent](#15-step-12-schedule-with-sql-agent)

---

## 1. Overview

In this hands-on guide, you'll build a **complete ETL pipeline** from scratch for a simplified banking scenario. By the end, you'll have:

```
┌─────────────────────────────────────────────────────────────────┐
│                    WHAT YOU'LL BUILD                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │ Source DB   │  3 tables (accounts, transactions, customers)  │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Staging DB  │  3 staging tables + control tables             │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ DW          │  3 dimensions + 1 fact table                   │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │ Audit Log   │  Full ETL execution tracking                   │
│  └─────────────┘                                                │
│                                                                  │
│  + 10+ stored procedures                                        │
│  + Error handling                                                │
│  + Batch tracking                                                │
│  + Row count reconciliation                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites

### Software Requirements
- SQL Server 2016+ (or Azure SQL Database)
- SQL Server Management Studio (SSMS)
- Basic SQL knowledge

### Time Estimate
- **Setup:** 30 minutes
- **Build:** 2-3 hours
- **Test:** 1 hour
- **Total:** 4-5 hours

---

## 3. Architecture Design

### Database Schema

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATABASE LAYOUT                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  etl_pipeline_source        (Source/OLTP system)                │
│  ├── dbo.accounts                                                │
│  ├── dbo.customers                                               │
│  └── dbo.transactions                                           │
│                                                                  │
│  etl_pipeline_staging       (Staging area)                       │
│  ├── staging.stg_accounts                                        │
│  ├── staging.stg_customers                                       │
│  ├── staging.stg_transactions                                    │
│  ├── staging.etl_control                                         │
│  └── staging.batch_log                                           │
│                                                                  │
│  etl_pipeline_dwh           (Data Warehouse)                    │
│  ├── dw.dim_customer                                             │
│  ├── dw.dim_account                                              │
│  ├── dw.dim_date                                                 │
│  ├── dw.fact_transactions                                        │
│  └── audit.etl_log                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### ETL Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    ETL PIPELINE FLOW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. EXTRACT                                                      │
│     Source → Staging (full or incremental)                      │
│                                                                  │
│  2. VALIDATE                                                     │
│     Check row counts, data types, nulls                         │
│                                                                  │
│  3. TRANSFORM                                                    │
│     Cleanse, derive, lookup surrogate keys                      │
│                                                                  │
│  4. LOAD                                                         │
│     Staging → Dimensions → Facts                                │
│                                                                  │
│  5. AUDIT                                                        │
│     Log everything: success, failures, row counts               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Step 1: Create Database Structure

```sql
-- ============================================================
-- STEP 1: CREATE DATABASES
-- ============================================================

-- Create source database (simulates OLTP system)
CREATE DATABASE etl_pipeline_source;
GO

-- Create staging database
CREATE DATABASE etl_pipeline_staging;
GO

-- Create data warehouse database
CREATE DATABASE etl_pipeline_dwh;
GO

PRINT 'Databases created successfully.';
```

### Create Schemas

```sql
-- ============================================================
-- CREATE SCHEMAS IN STAGING DATABASE
-- ============================================================
USE etl_pipeline_staging;
GO

CREATE SCHEMA staging;
GO

CREATE SCHEMA audit;
GO

-- ============================================================
-- CREATE SCHEMAS IN DWH DATABASE
-- ============================================================
USE etl_pipeline_dwh;
GO

CREATE SCHEMA dw;
GO

CREATE SCHEMA audit;
GO

PRINT 'Schemas created successfully.';
```

---

## 5. Step 2: Create Source Tables

```sql
-- ============================================================
-- STEP 2: CREATE SOURCE TABLES (OLTP Simulation)
-- ============================================================
USE etl_pipeline_source;
GO

-- Customers table
CREATE TABLE dbo.customers (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL,
    first_name NVARCHAR(100) NOT NULL,
    last_name NVARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    risk_rating VARCHAR(20) DEFAULT 'Low',
    customer_segment VARCHAR(50) DEFAULT 'Standard',
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE()
);

ALTER TABLE dbo.customers
ADD CONSTRAINT UQ_customers_code UNIQUE (customer_code);

-- Accounts table
CREATE TABLE dbo.accounts (
    account_id INT IDENTITY(1,1) PRIMARY KEY,
    account_number VARCHAR(20) NOT NULL,
    customer_id INT NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    balance DECIMAL(18,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    open_date DATE DEFAULT GETDATE(),
    status VARCHAR(20) DEFAULT 'Active',
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_accounts_customers 
        FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id)
);

ALTER TABLE dbo.accounts
ADD CONSTRAINT UQ_accounts_number UNIQUE (account_number);

-- Transactions table
CREATE TABLE dbo.transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY,
    transaction_code VARCHAR(30) NOT NULL,
    account_id INT NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(18,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    transaction_date DATETIME DEFAULT GETDATE(),
    description NVARCHAR(500),
    created_date DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT FK_transactions_accounts 
        FOREIGN KEY (account_id) REFERENCES dbo.accounts(account_id)
);

ALTER TABLE dbo.transactions
ADD CONSTRAINT UQ_transactions_code UNIQUE (transaction_code);

PRINT 'Source tables created successfully.';
```

### Insert Sample Data

```sql
-- ============================================================
-- INSERT SAMPLE SOURCE DATA
-- ============================================================
USE etl_pipeline_source;
GO

-- Insert customers
INSERT INTO dbo.customers (customer_code, first_name, last_name, email, phone, city, province, risk_rating, customer_segment)
VALUES
    ('CUST001', 'Sok', 'Vannak', 'vannak@email.com', '012-345-678', 'Phnom Penh', 'Phnom Penh', 'Low', 'Standard'),
    ('CUST002', 'Chan', 'Dara', 'dara@email.com', '012-987-654', 'Siem Reap', 'Siem Reap', 'Medium', 'Gold'),
    ('CUST003', 'Keo', 'Channary', 'channary@email.com', '012-555-123', 'Battambang', 'Battambang', 'Low', 'Standard'),
    ('CUST004', 'Bopha', 'Nhem', 'bopha@email.com', '012-777-888', 'Kampong Cham', 'Kampong Cham', 'Low', 'Standard'),
    ('CUST005', 'Dy', 'Vicheka', 'vicheka@email.com', '012-111-222', 'Prey Veng', 'Prey Veng', 'Low', 'Standard');

-- Insert accounts
INSERT INTO dbo.accounts (account_number, customer_id, account_type, balance, currency, open_date, status)
VALUES
    ('ACC1001', 1, 'SAVINGS', 5000.00, 'USD', '2024-01-15', 'Active'),
    ('ACC1002', 1, 'CHECKING', 2500.00, 'USD', '2024-01-15', 'Active'),
    ('ACC1003', 2, 'SAVINGS', 15000.00, 'USD', '2024-02-01', 'Active'),
    ('ACC1004', 3, 'SAVINGS', 3000.00, 'USD', '2024-02-15', 'Active'),
    ('ACC1005', 4, 'CHECKING', 8000.00, 'USD', '2024-03-01', 'Active'),
    ('ACC1006', 5, 'SAVINGS', 12000.00, 'USD', '2024-03-15', 'Active');

-- Insert transactions
INSERT INTO dbo.transactions (transaction_code, account_id, transaction_type, amount, transaction_date, description)
VALUES
    ('TXN20240601001', 1, 'DEPOSIT', 1000.00, '2024-06-01 10:00:00', 'Salary deposit'),
    ('TXN20240601002', 1, 'WITHDRAWAL', 200.00, '2024-06-01 14:00:00', 'ATM withdrawal'),
    ('TXN20240602001', 2, 'TRANSFER_IN', 500.00, '2024-06-02 09:00:00', 'Transfer from savings'),
    ('TXN20240602002', 3, 'DEPOSIT', 2000.00, '2024-06-02 11:00:00', 'Cash deposit'),
    ('TXN20240603001', 4, 'WITHDRAWAL', 500.00, '2024-06-03 15:00:00', 'ATM withdrawal'),
    ('TXN20240603002', 5, 'DEPOSIT', 1500.00, '2024-06-03 10:30:00', 'Business deposit'),
    ('TXN20240604001', 6, 'TRANSFER_OUT', 800.00, '2024-06-04 09:00:00', 'Transfer to another account'),
    ('TXN20240604002', 1, 'DEPOSIT', 3000.00, '2024-06-04 14:00:00', 'Investment return');

PRINT 'Sample data inserted successfully.';
```

---

## 6. Step 3: Create Staging Tables

```sql
-- ============================================================
-- STEP 3: CREATE STAGING TABLES
-- ============================================================
USE etl_pipeline_staging;
GO

-- Staging customers
CREATE TABLE staging.stg_customers (
    customer_code VARCHAR(20) NOT NULL,
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    risk_rating VARCHAR(20),
    customer_segment VARCHAR(50),
    is_active BIT,
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER,
    load_date DATETIME DEFAULT GETDATE()
);

-- Staging accounts
CREATE TABLE staging.stg_accounts (
    account_number VARCHAR(20) NOT NULL,
    customer_code VARCHAR(20),
    account_type VARCHAR(20),
    balance DECIMAL(18,2),
    currency VARCHAR(3),
    open_date DATE,
    status VARCHAR(20),
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER,
    load_date DATETIME DEFAULT GETDATE()
);

-- Staging transactions
CREATE TABLE staging.stg_transactions (
    transaction_code VARCHAR(30) NOT NULL,
    account_number VARCHAR(20),
    transaction_type VARCHAR(20),
    amount DECIMAL(18,2),
    currency VARCHAR(3),
    transaction_date DATETIME,
    description NVARCHAR(500),
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER,
    load_date DATETIME DEFAULT GETDATE()
);

PRINT 'Staging tables created successfully.';
```

---

## 7. Step 4: Create Dimension Tables

```sql
-- ============================================================
-- STEP 4: CREATE DIMENSION TABLES
-- ============================================================
USE etl_pipeline_dwh;
GO

-- DimCustomer (SCD Type 2)
CREATE TABLE dw.dim_customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL,
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    email VARCHAR(255),
    phone VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    risk_rating VARCHAR(20),
    customer_segment VARCHAR(50),
    is_active BIT,
    
    -- SCD Type 2 columns
    effective_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    is_current BIT NOT NULL,
    
    -- Audit columns
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT UQ_dim_customer_current 
        UNIQUE (customer_code, is_current)
);

CREATE NONCLUSTERED INDEX IX_dim_customer_code 
ON dw.dim_customer(customer_code);

-- DimAccount (SCD Type 2)
CREATE TABLE dw.dim_account (
    account_key INT IDENTITY(1,1) PRIMARY KEY,
    account_number VARCHAR(20) NOT NULL,
    customer_key INT,
    account_type VARCHAR(20),
    currency VARCHAR(3),
    open_date DATE,
    status VARCHAR(20),
    
    -- SCD Type 2 columns
    effective_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    is_current BIT NOT NULL,
    
    -- Audit columns
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT UQ_dim_account_current 
        UNIQUE (account_number, is_current)
);

-- DimDate (Date Dimension)
CREATE TABLE dw.dim_date (
    date_key INT PRIMARY KEY,  -- YYYYMMDD format
    full_date DATE NOT NULL,
    day_of_week TINYINT,
    day_name VARCHAR(10),
    day_of_month TINYINT,
    month_number TINYINT,
    month_name VARCHAR(10),
    quarter_number TINYINT,
    year_number SMALLINT,
    is_weekend BIT,
    is_business_day BIT
);

PRINT 'Dimension tables created successfully.';
```

---

## 8. Step 5: Create Fact Tables

```sql
-- ============================================================
-- STEP 5: CREATE FACT TABLES
-- ============================================================
USE etl_pipeline_dwh;
GO

-- FactTransactions
CREATE TABLE dw.fact_transactions (
    transaction_key INT IDENTITY(1,1) PRIMARY KEY,
    transaction_code VARCHAR(30) NOT NULL,
    account_key INT NOT NULL,
    customer_key INT NOT NULL,
    date_key INT NOT NULL,
    transaction_type VARCHAR(20),
    amount DECIMAL(18,2),
    amount_usd DECIMAL(18,2),
    currency VARCHAR(3),
    description NVARCHAR(500),
    
    -- Audit columns
    source_key VARCHAR(50),
    batch_id UNIQUEIDENTIFIER,
    created_date DATETIME DEFAULT GETDATE(),
    
    CONSTRAINT UQ_fact_transactions_code UNIQUE (transaction_code)
);

CREATE NONCLUSTERED INDEX IX_fact_transactions_date 
ON dw.fact_transactions(date_key);

CREATE NONCLUSTERED INDEX IX_fact_transactions_account 
ON dw.fact_transactions(account_key);

PRINT 'Fact tables created successfully.';
```

---

## 9. Step 6: Create ETL Control Tables

```sql
-- ============================================================
-- STEP 6: CREATE ETL CONTROL & AUDIT TABLES
-- ============================================================
USE etl_pipeline_staging;
GO

-- ETL Control table (tracks incremental load state)
CREATE TABLE staging.etl_control (
    source_table VARCHAR(100) PRIMARY KEY,
    last_extract_date DATETIME,
    last_extract_key BIGINT,
    row_count BIGINT,
    status VARCHAR(20),
    last_run DATETIME
);

-- Initialize control records
INSERT INTO staging.etl_control (source_table, status)
VALUES 
    ('customers', 'PENDING'),
    ('accounts', 'PENDING'),
    ('transactions', 'PENDING');

-- Batch log table
CREATE TABLE staging.batch_log (
    batch_id UNIQUEIDENTIFIER PRIMARY KEY,
    batch_name VARCHAR(100),
    source_system VARCHAR(50),
    status VARCHAR(20),
    start_time DATETIME DEFAULT GETDATE(),
    end_time DATETIME,
    records_extracted BIGINT DEFAULT 0,
    error_message NVARCHAR(MAX)
);

-- Error log table
CREATE TABLE staging.error_log (
    error_id INT IDENTITY(1,1) PRIMARY KEY,
    batch_id UNIQUEIDENTIFIER,
    source_table VARCHAR(100),
    error_type VARCHAR(50),
    error_message NVARCHAR(MAX),
    severity VARCHAR(20),
    created_date DATETIME DEFAULT GETDATE()
);

-- DWH Audit log
USE etl_pipeline_dwh;
GO

CREATE TABLE audit.etl_log (
    log_id BIGINT IDENTITY(1,1) PRIMARY KEY,
    batch_id UNIQUEIDENTIFIER,
    step_name VARCHAR(100),
    table_name VARCHAR(100),
    operation VARCHAR(50),
    records_affected BIGINT,
    status VARCHAR(20),
    start_time DATETIME,
    end_time DATETIME,
    duration_seconds AS DATEDIFF(SECOND, start_time, end_time),
    created_date DATETIME DEFAULT GETDATE()
);

PRINT 'Control and audit tables created successfully.';
```

---

## 10. Step 7: Build Extract Procedures

```sql
-- ============================================================
-- STEP 7: BUILD EXTRACT PROCEDURES
-- ============================================================
USE etl_pipeline_staging;
GO

-- ============================================================
-- 7.1 MASTER EXTRACT PROCEDURE
-- ============================================================
CREATE PROCEDURE staging.usp_ExtractAll
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    -- Log batch start
    INSERT INTO staging.batch_log (batch_id, batch_name, source_system, status)
    VALUES (@BatchID, 'Full Extraction', 'ALL', 'RUNNING');
    
    PRINT '================================================';
    PRINT 'STARTING EXTRACTION';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT '================================================';
    
    BEGIN TRY
        -- Extract each table
        EXEC staging.usp_ExtractCustomers @BatchID;
        EXEC staging.usp_ExtractAccounts @BatchID;
        EXEC staging.usp_ExtractTransactions @BatchID;
        
        -- Update batch status
        UPDATE staging.batch_log
        SET status = 'COMPLETED',
            end_time = GETDATE()
        WHERE batch_id = @BatchID;
        
        PRINT '================================================';
        PRINT 'EXTRACTION COMPLETED SUCCESSFULLY';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        UPDATE staging.batch_log
        SET status = 'FAILED',
            error_message = ERROR_MESSAGE(),
            end_time = GETDATE()
        WHERE batch_id = @BatchID;
        
        INSERT INTO staging.error_log (batch_id, source_table, error_type, error_message, severity)
        VALUES (@BatchID, 'ALL', 'SYSTEM_ERROR', ERROR_MESSAGE(), 'CRITICAL');
        
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 7.2 EXTRACT CUSTOMERS
-- ============================================================
CREATE PROCEDURE staging.usp_ExtractCustomers
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting customers...';
    
    -- Truncate staging
    TRUNCATE TABLE staging.stg_customers;
    
    -- Extract from source
    INSERT INTO staging.stg_customers (
        customer_code, first_name, last_name, email, phone,
        address, city, province, risk_rating, customer_segment,
        is_active, source_key, batch_id
    )
    SELECT
        c.customer_code,
        c.first_name,
        c.last_name,
        c.email,
        c.phone,
        c.address,
        c.city,
        c.province,
        c.risk_rating,
        c.customer_segment,
        c.is_active,
        CAST(c.customer_id AS VARCHAR(50)),
        @BatchID
    FROM etl_pipeline_source.dbo.customers c;
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Log
    INSERT INTO etl_pipeline_dwh.audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Extract_Customers', 'stg_customers', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT '  Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' customers.';
END;
GO

-- ============================================================
-- 7.3 EXTRACT ACCOUNTS
-- ============================================================
CREATE PROCEDURE staging.usp_ExtractAccounts
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting accounts...';
    
    TRUNCATE TABLE staging.stg_accounts;
    
    INSERT INTO staging.stg_accounts (
        account_number, customer_code, account_type, balance,
        currency, open_date, status, source_key, batch_id
    )
    SELECT
        a.account_number,
        c.customer_code,
        a.account_type,
        a.balance,
        a.currency,
        a.open_date,
        a.status,
        CAST(a.account_id AS VARCHAR(50)),
        @BatchID
    FROM etl_pipeline_source.dbo.accounts a
    JOIN etl_pipeline_source.dbo.customers c ON a.customer_id = c.customer_id;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO etl_pipeline_dwh.audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Extract_Accounts', 'stg_accounts', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT '  Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' accounts.';
END;
GO

-- ============================================================
-- 7.4 EXTRACT TRANSACTIONS
-- ============================================================
CREATE PROCEDURE staging.usp_ExtractTransactions
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT;
    
    PRINT 'Extracting transactions...';
    
    TRUNCATE TABLE staging.stg_transactions;
    
    INSERT INTO staging.stg_transactions (
        transaction_code, account_number, transaction_type,
        amount, currency, transaction_date, description,
        source_key, batch_id
    )
    SELECT
        t.transaction_code,
        a.account_number,
        t.transaction_type,
        t.amount,
        t.currency,
        t.transaction_date,
        t.description,
        CAST(t.transaction_id AS VARCHAR(50)),
        @BatchID
    FROM etl_pipeline_source.dbo.transactions t
    JOIN etl_pipeline_source.dbo.accounts a ON t.account_id = a.account_id;
    
    SET @RecordCount = @@ROWCOUNT;
    
    INSERT INTO etl_pipeline_dwh.audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Extract_Transactions', 'stg_transactions', 'EXTRACT',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE()
    );
    
    PRINT '  Extracted ' + CAST(@RecordCount AS VARCHAR(10)) + ' transactions.';
END;
GO

PRINT 'Extract procedures created successfully.';
```

---

## 11. Step 8: Build Transform & Load Procedures

```sql
-- ============================================================
-- STEP 8: BUILD TRANSFORM & LOAD PROCEDURES
-- ============================================================
USE etl_pipeline_dwh;
GO

-- ============================================================
-- 8.1 MASTER LOAD PROCEDURE
-- ============================================================
CREATE PROCEDURE dw.usp_LoadAll
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    PRINT '================================================';
    PRINT 'STARTING DATA WAREHOUSE LOAD';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT '================================================';
    
    BEGIN TRY
        -- Load dimensions first (order matters!)
        EXEC dw.usp_LoadDimDate @BatchID;
        EXEC dw.usp_LoadDimCustomer @BatchID;
        EXEC dw.usp_LoadDimAccount @BatchID;
        
        -- Load facts (after dimensions)
        EXEC dw.usp_LoadFactTransactions @BatchID;
        
        PRINT '================================================';
        PRINT 'DATA WAREHOUSE LOAD COMPLETED SUCCESSFULLY';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- 8.2 LOAD DIM_DATE
-- ============================================================
CREATE PROCEDURE dw.usp_LoadDimDate
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @CurrentDate DATE = '2020-01-01';
    DECLARE @EndDate DATE = '2030-12-31';
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Loading Date Dimension...';
    
    -- Only populate if empty
    IF NOT EXISTS (SELECT 1 FROM dw.dim_date)
    BEGIN
        WHILE @CurrentDate <= @EndDate
        BEGIN
            INSERT INTO dw.dim_date (
                date_key, full_date, day_of_week, day_name,
                day_of_month, month_number, month_name,
                quarter_number, year_number, is_weekend, is_business_day
            )
            VALUES (
                CAST(FORMAT(@CurrentDate, 'yyyyMMdd') AS INT),
                @CurrentDate,
                DATEPART(WEEKDAY, @CurrentDate),
                DATENAME(WEEKDAY, @CurrentDate),
                DAY(@CurrentDate),
                MONTH(@CurrentDate),
                DATENAME(MONTH, @CurrentDate),
                DATEPART(QUARTER, @CurrentDate),
                YEAR(@CurrentDate),
                CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 1 ELSE 0 END,
                CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 0 ELSE 1 END
            );
            
            SET @RecordCount += 1;
            SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
        END
        
        PRINT '  Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' date records.';
    END
    ELSE
        PRINT '  Date dimension already populated. Skipping.';
END;
GO

-- ============================================================
-- 8.3 LOAD DIM_CUSTOMER (SCD Type 2)
-- ============================================================
CREATE PROCEDURE dw.usp_LoadDimCustomer
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @NewCount BIGINT = 0;
    DECLARE @ExpiredCount BIGINT = 0;
    DECLARE @InsertedCount BIGINT = 0;
    
    PRINT 'Loading Customer Dimension (SCD Type 2)...';
    
    -- Phase 1: Insert new customers
    INSERT INTO dw.dim_customer (
        customer_code, first_name, last_name, email, phone,
        address, city, province, risk_rating, customer_segment,
        is_active, effective_date, expiry_date, is_current,
        source_key, batch_id
    )
    SELECT
        s.customer_code,
        s.first_name,
        s.last_name,
        s.email,
        s.phone,
        s.address,
        s.city,
        s.province,
        s.risk_rating,
        s.customer_segment,
        s.is_active,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        s.source_key,
        s.batch_id
    FROM etl_pipeline_staging.staging.stg_customers s
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_customer d
        WHERE d.customer_code = s.customer_code
    );
    
    SET @NewCount = @@ROWCOUNT;
    PRINT '  New customers: ' + CAST(@NewCount AS VARCHAR(10));
    
    -- Phase 2: Expire changed customers
    UPDATE d
    SET
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
        d.is_current = 0,
        d.modified_date = GETDATE()
    FROM dw.dim_customer d
    JOIN etl_pipeline_staging.staging.stg_customers s
        ON d.customer_code = s.customer_code
    WHERE d.is_current = 1
    AND (
        ISNULL(d.first_name, '') != ISNULL(s.first_name, '')
        OR ISNULL(d.last_name, '') != ISNULL(s.last_name, '')
        OR ISNULL(d.email, '') != ISNULL(s.email, '')
        OR ISNULL(d.phone, '') != ISNULL(s.phone, '')
        OR ISNULL(d.city, '') != ISNULL(s.city, '')
        OR ISNULL(d.province, '') != ISNULL(s.province, '')
        OR ISNULL(d.risk_rating, '') != ISNULL(s.risk_rating, '')
        OR ISNULL(d.customer_segment, '') != ISNULL(s.customer_segment, '')
        OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
    );
    
    SET @ExpiredCount = @@ROWCOUNT;
    PRINT '  Expired customers: ' + CAST(@ExpiredCount AS VARCHAR(10));
    
    -- Phase 3: Insert new versions
    INSERT INTO dw.dim_customer (
        customer_code, first_name, last_name, email, phone,
        address, city, province, risk_rating, customer_segment,
        is_active, effective_date, expiry_date, is_current,
        source_key, batch_id
    )
    SELECT
        s.customer_code,
        s.first_name,
        s.last_name,
        s.email,
        s.phone,
        s.address,
        s.city,
        s.province,
        s.risk_rating,
        s.customer_segment,
        s.is_active,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        s.source_key,
        s.batch_id
    FROM etl_pipeline_staging.staging.stg_customers s
    WHERE EXISTS (
        SELECT 1 FROM dw.dim_customer d
        WHERE d.customer_code = s.customer_code
        AND d.is_current = 0
        AND d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    );
    
    SET @InsertedCount = @@ROWCOUNT;
    PRINT '  New versions: ' + CAST(@InsertedCount AS VARCHAR(10));
    
    -- Log
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Load_DimCustomer', 'dim_customer', 'LOAD',
        @NewCount + @ExpiredCount + @InsertedCount, 'COMPLETED',
        @StartTime, GETDATE()
    );
END;
GO

-- ============================================================
-- 8.4 LOAD DIM_ACCOUNT (SCD Type 2)
-- ============================================================
CREATE PROCEDURE dw.usp_LoadDimAccount
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @NewCount BIGINT = 0;
    
    PRINT 'Loading Account Dimension (SCD Type 2)...';
    
    -- Insert new accounts
    INSERT INTO dw.dim_account (
        account_number, customer_key, account_type, currency,
        open_date, status, effective_date, expiry_date, is_current,
        source_key, batch_id
    )
    SELECT
        s.account_number,
        c.customer_key,
        s.account_type,
        s.currency,
        s.open_date,
        s.status,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        s.source_key,
        s.batch_id
    FROM etl_pipeline_staging.staging.stg_accounts s
    JOIN dw.dim_customer c 
        ON s.customer_code = c.customer_code 
        AND c.is_current = 1
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.dim_account d
        WHERE d.account_number = s.account_number
    );
    
    SET @NewCount = @@ROWCOUNT;
    
    -- Expire changed accounts
    UPDATE d
    SET
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
        d.is_current = 0,
        d.modified_date = GETDATE()
    FROM dw.dim_account d
    JOIN etl_pipeline_staging.staging.stg_accounts s
        ON d.account_number = s.account_number
    WHERE d.is_current = 1
    AND (
        ISNULL(d.status, '') != ISNULL(s.status, '')
        OR ISNULL(d.balance, 0) != ISNULL(s.balance, 0)
    );
    
    -- Insert updated versions
    INSERT INTO dw.dim_account (
        account_number, customer_key, account_type, currency,
        open_date, status, effective_date, expiry_date, is_current,
        source_key, batch_id
    )
    SELECT
        s.account_number,
        c.customer_key,
        s.account_type,
        s.currency,
        s.open_date,
        s.status,
        CAST(GETDATE() AS DATE),
        '9999-12-31',
        1,
        s.source_key,
        s.batch_id
    FROM etl_pipeline_staging.staging.stg_accounts s
    JOIN dw.dim_customer c 
        ON s.customer_code = c.customer_code 
        AND c.is_current = 1
    WHERE EXISTS (
        SELECT 1 FROM dw.dim_account d
        WHERE d.account_number = s.account_number
        AND d.is_current = 0
        AND d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    );
    
    PRINT '  Loaded ' + CAST(@NewCount AS VARCHAR(10)) + ' new accounts.';
    
    -- Log
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Load_DimAccount', 'dim_account', 'LOAD',
        @NewCount, 'COMPLETED', @StartTime, GETDATE()
    );
END;
GO

-- ============================================================
-- 8.5 LOAD FACT_TRANSACTIONS
-- ============================================================
CREATE PROCEDURE dw.usp_LoadFactTransactions
    @BatchID UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Loading Transaction Fact Table...';
    
    INSERT INTO dw.fact_transactions (
        transaction_code, account_key, customer_key, date_key,
        transaction_type, amount, amount_usd, currency,
        description, source_key, batch_id
    )
    SELECT
        s.transaction_code,
        a.account_key,
        c.customer_key,
        CAST(FORMAT(s.transaction_date, 'yyyyMMdd') AS INT),
        s.transaction_type,
        s.amount,
        CASE 
            WHEN s.currency = 'KHR' THEN s.amount / 4100.00
            ELSE s.amount
        END,
        s.currency,
        s.description,
        s.source_key,
        s.batch_id
    FROM etl_pipeline_staging.staging.stg_transactions s
    JOIN dw.dim_account a 
        ON s.account_number = a.account_number 
        AND a.is_current = 1
    JOIN dw.dim_customer c 
        ON a.customer_key = c.customer_key 
        AND c.is_current = 1
    WHERE NOT EXISTS (
        SELECT 1 FROM dw.fact_transactions f
        WHERE f.transaction_code = s.transaction_code
    );
    
    SET @RecordCount = @@ROWCOUNT;
    
    PRINT '  Loaded ' + CAST(@RecordCount AS VARCHAR(10)) + ' transactions.';
    
    -- Log
    INSERT INTO audit.etl_log (
        batch_id, step_name, table_name, operation,
        records_affected, status, start_time, end_time
    )
    VALUES (
        @BatchID, 'Load_FactTransactions', 'fact_transactions', 'LOAD',
        @RecordCount, 'COMPLETED', @StartTime, GETDATE()
    );
END;
GO

PRINT 'Transform & Load procedures created successfully.';
```

---

## 12. Step 9: Build Audit & Logging

```sql
-- ============================================================
-- STEP 9: BUILD AUDIT QUERIES
-- ============================================================
USE etl_pipeline_dwh;
GO

-- ============================================================
-- 9.1 VIEW ETL EXECUTION HISTORY
-- ============================================================
CREATE PROCEDURE audit.usp_GetETLHistory
    @BatchID UNIQUEIDENTIFIER = NULL,
    @DaysBack INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        batch_id,
        step_name,
        table_name,
        operation,
        records_affected,
        status,
        start_time,
        end_time,
        duration_seconds,
        created_date
    FROM audit.etl_log
    WHERE (@BatchID IS NULL OR batch_id = @BatchID)
    AND created_date >= DATEADD(DAY, -@DaysBack, GETDATE())
    ORDER BY start_time DESC;
END;
GO

-- ============================================================
-- 9.2 VIEW ETL PERFORMANCE
-- ============================================================
CREATE PROCEDURE audit.usp_GetETLPerformance
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        step_name,
        COUNT(*) AS execution_count,
        AVG(duration_seconds) AS avg_duration_seconds,
        MIN(duration_seconds) AS min_duration_seconds,
        MAX(duration_seconds) AS max_duration_seconds,
        SUM(records_affected) AS total_records,
        AVG(records_affected) AS avg_records
    FROM audit.etl_log
    WHERE operation = 'LOAD'
    AND created_date >= DATEADD(DAY, -@DaysBack, GETDATE())
    GROUP BY step_name
    ORDER BY avg_duration_seconds DESC;
END;
GO

-- ============================================================
-- 9.3 VIEW ETL ERRORS
-- ============================================================
CREATE PROCEDURE audit.usp_GetETLErrors
    @DaysBack INT = 7
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        batch_id,
        step_name,
        table_name,
        status,
        start_time,
        end_time,
        duration_seconds
    FROM audit.etl_log
    WHERE status = 'FAILED'
    AND created_date >= DATEADD(DAY, -@DaysBack, GETDATE())
    ORDER BY start_time DESC;
END;
GO

PRINT 'Audit procedures created successfully.';
```

---

## 13. Step 10: Create Master Orchestrator

```sql
-- ============================================================
-- STEP 10: CREATE MASTER ORCHESTRATOR
-- ============================================================
USE etl_pipeline_staging;
GO

CREATE PROCEDURE staging.usp_RunFullETL
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @Step VARCHAR(50);
    
    PRINT '╔═══════════════════════════════════════════════════════════╗';
    PRINT '║           SATHAPANA BANK - ETL PIPELINE                  ║';
    PRINT '╠═══════════════════════════════════════════════════════════╣';
    PRINT '║ Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT '║ Start Time: ' + CONVERT(VARCHAR(20), @StartTime, 120);
    PRINT '╚═══════════════════════════════════════════════════════════╝';
    PRINT '';
    
    BEGIN TRY
        --------------------------------------------------------
        -- PHASE 1: EXTRACT
        --------------------------------------------------------
        SET @Step = 'EXTRACT';
        PRINT '▶ PHASE 1: EXTRACT';
        PRINT '─────────────────────────────────────────────────────────────';
        
        EXEC staging.usp_ExtractAll @BatchID;
        
        PRINT '';
        
        --------------------------------------------------------
        -- PHASE 2: TRANSFORM & LOAD
        --------------------------------------------------------
        SET @Step = 'TRANSFORM & LOAD';
        PRINT '▶ PHASE 2: TRANSFORM & LOAD';
        PRINT '─────────────────────────────────────────────────────────────';
        
        EXEC etl_pipeline_dwh.dw.usp_LoadAll @BatchID;
        
        PRINT '';
        
        --------------------------------------------------------
        -- PHASE 3: SUMMARY
        --------------------------------------------------------
        SET @Step = 'SUMMARY';
        PRINT '▶ PHASE 3: SUMMARY';
        PRINT '─────────────────────────────────────────────────────────────';
        
        -- Get extraction counts
        DECLARE @ExtractCount BIGINT;
        SELECT @ExtractCount = SUM(records_affected)
        FROM etl_pipeline_dwh.audit.etl_log
        WHERE batch_id = @BatchID
        AND operation = 'EXTRACT';
        
        -- Get load counts
        DECLARE @LoadCount BIGINT;
        SELECT @LoadCount = SUM(records_affected)
        FROM etl_pipeline_dwh.audit.etl_log
        WHERE batch_id = @BatchID
        AND operation = 'LOAD';
        
        DECLARE @Duration INT = DATEDIFF(SECOND, @StartTime, GETDATE());
        
        PRINT 'Records Extracted: ' + CAST(ISNULL(@ExtractCount, 0) AS VARCHAR(10));
        PRINT 'Records Loaded:    ' + CAST(ISNULL(@LoadCount, 0) AS VARCHAR(10));
        PRINT 'Duration:          ' + CAST(@Duration AS VARCHAR(10)) + ' seconds';
        PRINT '';
        PRINT '╔═══════════════════════════════════════════════════════════╗';
        PRINT '║           ETL PIPELINE COMPLETED SUCCESSFULLY            ║';
        PRINT '╚═══════════════════════════════════════════════════════════╝';
        
    END TRY
    BEGIN CATCH
        PRINT '';
        PRINT '╔═══════════════════════════════════════════════════════════╗';
        PRINT '║           ETL PIPELINE FAILED                            ║';
        PRINT '╚═══════════════════════════════════════════════════════════╝';
        PRINT 'Failed at step: ' + @Step;
        PRINT 'Error: ' + ERROR_MESSAGE();
        
        -- Update batch log
        UPDATE staging.batch_log
        SET status = 'FAILED',
            error_message = ERROR_MESSAGE(),
            end_time = GETDATE()
        WHERE batch_id = @BatchID;
        
        THROW;
    END CATCH
END;
GO

PRINT 'Master orchestrator created successfully.';
```

---

## 14. Step 11: Test the Complete Pipeline

```sql
-- ============================================================
-- STEP 11: TEST THE COMPLETE ETL PIPELINE
-- ============================================================

-- Run the full ETL
EXEC staging.usp_RunFullETL;

-- View ETL history
EXEC etl_pipeline_dwh.audit.usp_GetETLHistory;

-- View ETL performance
EXEC etl_pipeline_dwh.audit.usp_GetETLPerformance;

-- Verify data in warehouse
SELECT COUNT(*) AS customer_count FROM etl_pipeline_dwh.dw.dim_customer WHERE is_current = 1;
SELECT COUNT(*) AS account_count FROM etl_pipeline_dwh.dw.dim_account WHERE is_current = 1;
SELECT COUNT(*) AS transaction_count FROM etl_pipeline_dwh.dw.fact_transactions;

-- View sample data
SELECT 
    t.transaction_code,
    c.first_name + ' ' + c.last_name AS customer_name,
    a.account_number,
    t.amount,
    t.transaction_type,
    d.full_date AS transaction_date
FROM etl_pipeline_dwh.dw.fact_transactions t
JOIN etl_pipeline_dwh.dw.dim_customer c ON t.customer_key = c.customer_key
JOIN etl_pipeline_dwh.dw.dim_account a ON t.account_key = a.account_key
JOIN etl_pipeline_dwh.dw.dim_date d ON t.date_key = d.date_key;
```

### Test SCD Type 2

```sql
-- ============================================================
-- TEST SCD TYPE 2: Make a change and re-run ETL
-- ============================================================

-- Change customer CUST002's segment
UPDATE etl_pipeline_source.dbo.customers
SET customer_segment = 'Platinum',
    risk_rating = 'Low',
    modified_date = GETDATE()
WHERE customer_code = 'CUST002';

-- Add a new customer
INSERT INTO etl_pipeline_source.dbo.customers (
    customer_code, first_name, last_name, email, phone,
    city, province, risk_rating, customer_segment
)
VALUES ('CUST006', 'Mao', 'Sophea', 'sophea@email.com', '012-333-444',
        'Kandal', 'Kandal', 'Low', 'Standard');

-- Re-run ETL
EXEC staging.usp_RunFullETL;

-- Verify SCD Type 2: CUST002 should have 2 versions
SELECT 
    customer_key,
    customer_code,
    customer_segment,
    risk_rating,
    effective_date,
    expiry_date,
    is_current
FROM etl_pipeline_dwh.dw.dim_customer
WHERE customer_code = 'CUST002'
ORDER BY effective_date;

-- Verify new customer
SELECT 
    customer_key,
    customer_code,
    first_name,
    effective_date,
    is_current
FROM etl_pipeline_dwh.dw.dim_customer
WHERE customer_code = 'CUST006';
```

---

## 15. Step 12: Schedule with SQL Agent

```sql
-- ============================================================
-- STEP 12: CREATE SQL AGENT JOB (Optional)
-- ============================================================

-- Note: This requires SQL Server Agent service to be running

USE msdb;
GO

-- Create the job
EXEC dbo.sp_add_job
    @job_name = N'ETL_Pipeline_Daily',
    @enabled = 1,
    @description = N'Daily ETL pipeline for Sathapana Bank data warehouse',
    @category_name = N'[Uncategorized (Local)]',
    @notify_level_eventlog = 2,
    @notify_level_email = 2,
    @notify_email_operator_name = N'DWH_Operator';

-- Add job step
EXEC dbo.sp_add_jobstep
    @job_name = N'ETL_Pipeline_Daily',
    @step_name = N'Run ETL Pipeline',
    @subsystem = N'TSQL',
    @command = N'EXEC etl_pipeline_staging.staging.usp_RunFullETL',
    @database_name = N'etl_pipeline_staging',
    @retry_attempts = 3,
    @retry_interval = 5;

-- Create schedule (runs daily at 2:00 AM)
EXEC dbo.sp_add_jobschedule
    @job_name = N'ETL_Pipeline_Daily',
    @name = N'Daily_2AM',
    @freq_type = 4,          -- Daily
    @freq_interval = 1,      -- Every 1 day
    @active_start_time = 020000;  -- 2:00 AM

-- Assign job to local server
EXEC dbo.sp_add_jobserver
    @job_name = N'ETL_Pipeline_Daily',
    @server_name = N'(LOCAL)';

PRINT 'SQL Agent job created successfully.';
```

---

## Summary

### What You Built

| Component | Description |
|-----------|-------------|
| **3 Databases** | Source, Staging, Data Warehouse |
| **3 Source Tables** | customers, accounts, transactions |
| **3 Staging Tables** | Staging area for extracted data |
| **3 Dimension Tables** | dim_customer, dim_account, dim_date |
| **1 Fact Table** | fact_transactions |
| **3 Extract Procedures** | One per source table |
| **5 Load Procedures** | Dimensions + facts |
| **1 Master Orchestrator** | Coordinates the entire ETL |
| **3 Audit Procedures** | History, performance, errors |
| **1 SQL Agent Job** | Scheduled daily execution |

### ETL Best Practices Demonstrated

```
✅ Batch tracking with unique BatchID
✅ TRY/CATCH error handling
✅ Audit logging for every step
✅ SCD Type 2 for historical tracking
✅ Dimension-first load order
✅ Row count reconciliation
✅ Incremental load support
✅ Master orchestrator pattern
✅ Performance monitoring
✅ SQL Agent scheduling
```

### Next Steps

1. **Add more source tables** (products, employees, loans)
2. **Implement incremental loads** for large tables
3. **Add data quality checks** before loading
4. **Create data marts** for specific business areas
5. **Add email notifications** for failures
6. **Implement CDC** for real-time requirements

---

*Guide Created: September 2024*
*Based on Sathapana Bank Data Engineering Project*
