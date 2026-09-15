# 🎯 SCD Type 2 Hands-On Exercise

## Overview

In this exercise, you will implement a complete **Slowly Changing Dimension Type 2** pattern for a customer dimension table. You'll learn how to:

1. Create the dimension table with SCD columns
2. Implement initial load
3. Handle new customers
4. Detect and process changes
5. Query historical data

---

## Scenario

**Sathapana Bank** needs to track customer changes over time for regulatory compliance. When a customer's:
- Address changes
- Risk rating changes  
- Customer segment changes
- Phone number changes

...the bank needs to preserve the **full history** of these changes.

---

## Prerequisites

- SQL Server (or Azure SQL Database)
- Basic SQL knowledge
- Understanding of INSERT, UPDATE, JOIN

---

## Exercise Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    EXERCISE STEPS                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: Create Database Objects                                 │
│  Step 2: Initial Data Load (Day 1)                              │
│  Step 3: Add New Customer (Day 2)                               │
│  Step 4: Update Existing Customer (Day 2)                       │
│  Step 5: Query Historical Data                                  │
│  Step 6: Verify SCD Type 2 Results                              │
│  Step 7: Advanced - Full ETL Procedure                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Create Database Objects

### 1.1 Create Source Table (Simulating OLTP System)

```sql
-- This represents the source system (core banking)
CREATE DATABASE SCD_Exercise;
GO

USE SCD_Exercise;
GO

-- Source table (OLTP - what we're extracting FROM)
CREATE TABLE dbo.customers_source (
    customer_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_code VARCHAR(20) NOT NULL,
    first_name NVARCHAR(100) NOT NULL,
    last_name NVARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20),
    address VARCHAR(255),
    city VARCHAR(100),
    province VARCHAR(100),
    risk_rating VARCHAR(20),        -- Low, Medium, High
    customer_segment VARCHAR(50),   -- Standard, Gold, Platinum
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE()
);

-- Add unique constraint
ALTER TABLE dbo.customers_source 
ADD CONSTRAINT UQ_customers_source_code UNIQUE (customer_code);

-- Add check constraint for risk rating
ALTER TABLE dbo.customers_source 
ADD CONSTRAINT CK_risk_rating 
CHECK (risk_rating IN ('Low', 'Medium', 'High', 'Very High'));

-- Add check constraint for customer segment
ALTER TABLE dbo.customers_source 
ADD CONSTRAINT CK_customer_segment 
CHECK (customer_segment IN ('Standard', 'Gold', 'Platinum', 'Diamond'));
```

### 1.2 Create Dimension Table (DW - with SCD Type 2 columns)

```sql
-- Dimension table (Data Warehouse - what we're loading INTO)
CREATE TABLE dbo.dim_customer (
    -- Surrogate Key (auto-generated, never changes)
    customer_key INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Natural Key (from source system, business identifier)
    customer_code VARCHAR(20) NOT NULL,
    
    -- Descriptive Attributes (tracked for changes)
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
    
    -- SCD Type 2 Columns (THE KEY PART!)
    effective_date DATE NOT NULL,        -- When this version became valid
    expiry_date DATE NOT NULL,           -- When this version expired
    is_current BIT NOT NULL,             -- 1 = current, 0 = historical
    
    -- Audit Columns
    source_key VARCHAR(50),              -- Original source ID
    batch_id UNIQUEIDENTIFIER,          -- ETL batch tracking
    created_date DATETIME DEFAULT GETDATE(),
    modified_date DATETIME DEFAULT GETDATE(),
    
    -- Constraints
    CONSTRAINT UQ_dim_customer_code_current 
        UNIQUE (customer_code, is_current)
);

-- Indexes for performance
CREATE NONCLUSTERED INDEX IX_dim_customer_code 
ON dbo.dim_customer(customer_code);

CREATE NONCLUSTERED INDEX IX_dim_customer_current 
ON dbo.dim_customer(is_current);

CREATE NONCLUSTERED INDEX IX_dim_customer_effective 
ON dbo.dim_customer(effective_date, expiry_date);
```

### 1.3 Create Audit Table

```sql
-- Audit log for tracking ETL execution
CREATE TABLE dbo.etl_audit (
    audit_id INT IDENTITY(1,1) PRIMARY KEY,
    batch_id UNIQUEIDENTIFIER,
    step_name VARCHAR(100),
    operation VARCHAR(50),           -- INSERT, UPDATE, EXPIRE
    table_name VARCHAR(100),
    records_affected BIGINT,
    status VARCHAR(20),             -- SUCCESS, FAILED
    start_time DATETIME,
    end_time DATETIME,
    notes NVARCHAR(500),
    created_date DATETIME DEFAULT GETDATE()
);
```

---

## Step 2: Initial Data Load (Day 1)

### 2.1 Insert Sample Source Data

```sql
-- Insert initial customers into source system
INSERT INTO dbo.customers_source (
    customer_code, first_name, last_name, email, phone,
    address, city, province, risk_rating, customer_segment
)
VALUES
    ('CUST001', 'Sok', 'Vannak', 'vannak@email.com', '012-345-678',
     '123 Street 100', 'Phnom Penh', 'Phnom Penh', 'Low', 'Standard'),
     
    ('CUST002', 'Chan', 'Dara', 'dara@email.com', '012-987-654',
     '456 Street 200', 'Siem Reap', 'Siem Reap', 'Medium', 'Gold'),
     
    ('CUST003', 'Keo', 'Channary', 'channary@email.com', '012-555-123',
     '789 Street 300', 'Battambang', 'Battambang', 'Low', 'Standard');

-- Verify source data
SELECT * FROM dbo.customers_source;
```

### 2.2 Create Initial Load Procedure

```sql
CREATE PROCEDURE dbo.usp_LoadDimCustomer_Initial
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @RecordCount BIGINT = 0;
    
    PRINT 'Starting Initial Load for Customer Dimension...';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    
    -- Log start
    INSERT INTO dbo.etl_audit (batch_id, step_name, operation, table_name, status, start_time)
    VALUES (@BatchID, 'Initial_Load', 'INSERT', 'dim_customer', 'RUNNING', @StartTime);
    
    -- Insert ALL customers from source
    INSERT INTO dbo.dim_customer (
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
        CAST(GETDATE() AS DATE),        -- effective_date = today
        '9999-12-31',                    -- expiry_date = far future (never expires for current)
        1,                               -- is_current = yes
        CAST(s.customer_id AS VARCHAR(50)),
        @BatchID
    FROM dbo.customers_source s
    WHERE s.is_active = 1;
    
    SET @RecordCount = @@ROWCOUNT;
    
    -- Log completion
    UPDATE dbo.etl_audit
    SET 
        records_affected = @RecordCount,
        status = 'COMPLETED',
        end_time = GETDATE(),
        notes = 'Initial load completed'
    WHERE batch_id = @BatchID
    AND step_name = 'Initial_Load'
    AND status = 'RUNNING';
    
    PRINT 'Initial load completed. Records loaded: ' + CAST(@RecordCount AS VARCHAR(10));
END;
GO
```

### 2.3 Execute Initial Load

```sql
-- Run the initial load
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC dbo.usp_LoadDimCustomer_Initial @BatchID;

-- Verify results
SELECT 
    customer_key,
    customer_code,
    first_name,
    last_name,
    risk_rating,
    customer_segment,
    effective_date,
    expiry_date,
    is_current
FROM dbo.dim_customer
ORDER BY customer_code;
```

### Expected Result (Day 1)

```
┌─────────────┬──────────────┬────────────┬───────────┬─────────────┬─────────────────┬───────────────┬──────────────┬──────────┐
│ customer_key│ customer_code│ first_name │ last_name │ risk_rating │ customer_segment│ effective_date│ expiry_date  │is_current│
├─────────────┼──────────────┼────────────┼───────────┼─────────────┼─────────────────┼───────────────┼──────────────┼──────────┤
│           1 │ CUST001      │ Sok        │ Vannak    │ Low         │ Standard        │ 2024-06-15    │ 9999-12-31   │ 1        │
│           2 │ CUST002      │ Chan       │ Dara      │ Medium      │ Gold            │ 2024-06-15    │ 9999-12-31   │ 1        │
│           3 │ CUST003      │ Keo        │ Channary  │ Low         │ Standard        │ 2024-06-15    │ 9999-12-31   │ 1        │
└─────────────┴──────────────┴────────────┴───────────┴─────────────┴─────────────────┴───────────────┴──────────────┴──────────┘
```

---

## Step 3: Add New Customer (Day 2)

### 3.1 Insert New Customer in Source

```sql
-- A new customer opens an account
INSERT INTO dbo.customers_source (
    customer_code, first_name, last_name, email, phone,
    address, city, province, risk_rating, customer_segment
)
VALUES
    ('CUST004', 'Bopha', 'Nhem', 'bopha@email.com', '012-777-888',
     '321 Street 400', 'Kampong Cham', 'Kampong Cham', 'Low', 'Standard');

-- Verify new customer exists
SELECT * FROM dbo.customers_source WHERE customer_code = 'CUST004';
```

### 3.2 Create Incremental Load Procedure

```sql
CREATE PROCEDURE dbo.usp_LoadDimCustomer_Incremental
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @NewCount BIGINT = 0;
    DECLARE @ExpiredCount BIGINT = 0;
    DECLARE @InsertedCount BIGINT = 0;
    
    PRINT 'Starting Incremental Load for Customer Dimension...';
    
    --------------------------------------------------------
    -- PHASE 1: INSERT NEW CUSTOMERS (Never seen before)
    --------------------------------------------------------
    INSERT INTO dbo.dim_customer (
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
        CAST(s.customer_id AS VARCHAR(50)),
        @BatchID
    FROM dbo.customers_source s
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.dim_customer d
        WHERE d.customer_code = s.customer_code
    );
    
    SET @NewCount = @@ROWCOUNT;
    PRINT 'New customers inserted: ' + CAST(@NewCount AS VARCHAR(10));
    
    --------------------------------------------------------
    -- PHASE 2: EXPIRE CHANGED CUSTOMERS
    --------------------------------------------------------
    UPDATE d
    SET
        d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
        d.is_current = 0,
        d.modified_date = GETDATE()
    FROM dbo.dim_customer d
    JOIN dbo.customers_source s
        ON d.customer_code = s.customer_code
    WHERE d.is_current = 1
    AND (
        -- Check if any tracked attribute has changed
        ISNULL(d.first_name, '') != ISNULL(s.first_name, '')
        OR ISNULL(d.last_name, '') != ISNULL(s.last_name, '')
        OR ISNULL(d.email, '') != ISNULL(s.email, '')
        OR ISNULL(d.phone, '') != ISNULL(s.phone, '')
        OR ISNULL(d.address, '') != ISNULL(s.address, '')
        OR ISNULL(d.city, '') != ISNULL(s.city, '')
        OR ISNULL(d.province, '') != ISNULL(s.province, '')
        OR ISNULL(d.risk_rating, '') != ISNULL(s.risk_rating, '')
        OR ISNULL(d.customer_segment, '') != ISNULL(s.customer_segment, '')
        OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
    );
    
    SET @ExpiredCount = @@ROWCOUNT;
    PRINT 'Customers expired: ' + CAST(@ExpiredCount AS VARCHAR(10));
    
    --------------------------------------------------------
    -- PHASE 3: INSERT NEW VERSIONS OF CHANGED CUSTOMERS
    --------------------------------------------------------
    INSERT INTO dbo.dim_customer (
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
        CAST(s.customer_id AS VARCHAR(50)),
        @BatchID
    FROM dbo.customers_source s
    WHERE EXISTS (
        SELECT 1 FROM dbo.dim_customer d
        WHERE d.customer_code = s.customer_code
        AND d.is_current = 0
        AND d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
    );
    
    SET @InsertedCount = @@ROWCOUNT;
    PRINT 'New versions inserted: ' + CAST(@InsertedCount AS VARCHAR(10));
    
    -- Log completion
    INSERT INTO dbo.etl_audit (
        batch_id, step_name, operation, table_name,
        records_affected, status, start_time, end_time, notes
    )
    VALUES (
        @BatchID, 'Incremental_Load', 'MERGE', 'dim_customer',
        @NewCount + @ExpiredCount + @InsertedCount, 'COMPLETED',
        @StartTime, GETDATE(),
        'New: ' + CAST(@NewCount AS VARCHAR(10)) +
        ', Expired: ' + CAST(@ExpiredCount AS VARCHAR(10)) +
        ', Updated: ' + CAST(@InsertedCount AS VARCHAR(10))
    );
    
    PRINT 'Incremental load completed.';
END;
GO
```

### 3.3 Execute Incremental Load

```sql
-- Run incremental load (should insert 1 new customer)
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC dbo.usp_LoadDimCustomer_Incremental @BatchID;

-- Verify results
SELECT 
    customer_key,
    customer_code,
    first_name,
    last_name,
    effective_date,
    expiry_date,
    is_current
FROM dbo.dim_customer
ORDER BY customer_code, effective_date;
```

### Expected Result (After Step 3)

```
┌─────────────┬──────────────┬────────────┬───────────┬───────────────┬──────────────┬──────────┐
│ customer_key│ customer_code│ first_name │ last_name │ effective_date│ expiry_date  │is_current│
├─────────────┼──────────────┼────────────┼───────────┼───────────────┼──────────────┼──────────┤
│           1 │ CUST001      │ Sok        │ Vannak    │ 2024-06-15    │ 9999-12-31   │ 1        │
│           2 │ CUST002      │ Chan       │ Dara      │ 2024-06-15    │ 9999-12-31   │ 1        │
│           3 │ CUST003      │ Keo        │ Channary  │ 2024-06-15    │ 9999-12-31   │ 1        │
│           4 │ CUST004      │ Bopha      │ Nhem      │ 2024-06-15    │ 9999-12-31   │ 1        │  ← NEW
└─────────────┴──────────────┴────────────┴───────────┴───────────────┴──────────────┴──────────┘
```

---

## Step 4: Update Existing Customer (Day 2 - Later)

### 4.1 Update Customer in Source System

```sql
-- CUST002 (Chan Dara) moves to a new address and gets promoted
UPDATE dbo.customers_source
SET 
    address = '999 Boulevard 51',
    city = 'Phnom Penh',
    province = 'Phnom Penh',
    risk_rating = 'Low',           -- Risk improved
    customer_segment = 'Platinum', -- Upgraded from Gold
    modified_date = GETDATE()
WHERE customer_code = 'CUST002';

-- Verify the update
SELECT * FROM dbo.customers_source WHERE customer_code = 'CUST002';
```

### 4.2 Run Incremental Load Again

```sql
-- Run incremental load (should detect change and create new version)
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC dbo.usp_LoadDimCustomer_Incremental @BatchID;

-- Verify results - you should see TWO versions for CUST002
SELECT 
    customer_key,
    customer_code,
    first_name,
    address,
    city,
    risk_rating,
    customer_segment,
    effective_date,
    expiry_date,
    is_current
FROM dbo.dim_customer
WHERE customer_code = 'CUST002'
ORDER BY effective_date;
```

### Expected Result (After Step 4)

```
┌─────────────┬──────────────┬────────────┬──────────────────────┬───────────┬─────────────┬─────────────────┬───────────────┬──────────────┬──────────┐
│ customer_key│ customer_code│ first_name │ address              │ city      │ risk_rating │ customer_segment│ effective_date│ expiry_date  │is_current│
├─────────────┼──────────────┼────────────┼──────────────────────┼───────────┼─────────────┼─────────────────┼───────────────┼──────────────┼──────────┤
│           2 │ CUST002      │ Chan       │ 456 Street 200       │ Siem Reap │ Medium      │ Gold            │ 2024-06-15    │ 2024-06-15   │ 0        │  ← OLD (expired)
│           5 │ CUST002      │ Chan       │ 999 Boulevard 51     │ Phnom Penh│ Low         │ Platinum        │ 2024-06-15    │ 9999-12-31   │ 1        │  ← NEW (current)
└─────────────┴──────────────┴────────────┴──────────────────────┴───────────┴─────────────┴─────────────────┴───────────────┴──────────────┴──────────┘
```

**Key Observation:** 
- The old record (customer_key=2) is NOT deleted
- It's marked as `is_current = 0` with an `expiry_date`
- A new record (customer_key=5) is created with the updated values
- The old address, risk rating, and segment are preserved in history!

---

## Step 5: Query Historical Data

### 5.1 Query Current Version

```sql
-- Get current version of all customers
SELECT 
    customer_code,
    first_name,
    last_name,
    address,
    city,
    risk_rating,
    customer_segment,
    effective_date,
    expiry_date
FROM dbo.dim_customer
WHERE is_current = 1
ORDER BY customer_code;
```

### 5.2 Query Historical Version at Specific Date

```sql
-- What did CUST002 look like on June 14, 2024?
-- (Before the address change)
SELECT 
    customer_code,
    first_name,
    address,
    city,
    risk_rating,
    customer_segment,
    effective_date,
    expiry_date
FROM dbo.dim_customer
WHERE customer_code = 'CUST002'
AND effective_date <= '2024-06-14'
AND expiry_date >= '2024-06-14';

-- What does CUST002 look like on June 16, 2024?
-- (After the address change)
SELECT 
    customer_code,
    first_name,
    address,
    city,
    risk_rating,
    customer_segment,
    effective_date,
    expiry_date
FROM dbo.dim_customer
WHERE customer_code = 'CUST002'
AND effective_date <= '2024-06-16'
AND expiry_date >= '2024-06-16';
```

### 5.3 Query Full History

```sql
-- Complete history of customer CUST002
SELECT 
    customer_key,
    first_name,
    address,
    city,
    risk_rating,
    customer_segment,
    effective_date,
    expiry_date,
    is_current,
    CASE 
        WHEN is_current = 1 THEN 'CURRENT'
        ELSE 'HISTORICAL'
    END AS version_status
FROM dbo.dim_customer
WHERE customer_code = 'CUST002'
ORDER BY effective_date;
```

### 5.4 Find All Changes Over Time

```sql
-- Find customers who have changed
SELECT 
    d.customer_code,
    d.first_name,
    d.last_name,
    COUNT(*) AS version_count,
    MIN(d.effective_date) AS first_seen,
    MAX(d.effective_date) AS last_change
FROM dbo.dim_customer d
GROUP BY d.customer_code, d.first_name, d.last_name
HAVING COUNT(*) > 1
ORDER BY version_count DESC;
```

### 5.5 Join with Fact Table (Example)

```sql
-- Create a sample fact table for transactions
CREATE TABLE dbo.fact_transactions (
    transaction_id INT IDENTITY(1,1) PRIMARY KEY,
    customer_key INT,               -- Surrogate key from dimension
    transaction_date DATE,
    amount DECIMAL(10,2),
    transaction_type VARCHAR(20)
);

-- Insert sample transactions (note: using surrogate keys!)
INSERT INTO dbo.fact_transactions (customer_key, transaction_date, amount, transaction_type)
VALUES
    (2, '2024-06-10', 500.00, 'DEPOSIT'),     -- CUST002 before change
    (2, '2024-06-12', 1000.00, 'DEPOSIT'),    -- CUST002 before change
    (5, '2024-06-16', 2000.00, 'DEPOSIT'),    -- CUST002 after change
    (5, '2024-06-17', 1500.00, 'WITHDRAWAL'); -- CUST002 after change

-- Query transactions with customer info AT TIME OF TRANSACTION
-- This is the power of SCD Type 2!
SELECT 
    t.transaction_id,
    t.transaction_date,
    t.amount,
    t.transaction_type,
    c.customer_code,
    c.first_name,
    c.address AS address_at_transaction_time,
    c.city AS city_at_transaction_time,
    c.risk_rating AS risk_at_transaction_time,
    c.customer_segment AS segment_at_transaction_time
FROM dbo.fact_transactions t
JOIN dbo.dim_customer c
    ON t.customer_key = c.customer_key
ORDER BY t.transaction_date;
```

### Expected Result (Transactions with Historical Context)

```
┌───────────────┬────────────────┬──────────┬────────────────┬──────────────┬────────────┬──────────────────────┬───────────┬─────────────────┬─────────────────┐
│ transaction_id│ transaction_date│ amount  │ transaction_type│ customer_code│ first_name │ address_at_trans...  │city_at... │ risk_at_trans.. │ segment_at_trans│
├───────────────┼────────────────┼──────────┼────────────────┼──────────────┼────────────┼──────────────────────┼───────────┼─────────────────┼─────────────────┤
│             1 │ 2024-06-10     │ 500.00   │ DEPOSIT        │ CUST002      │ Chan       │ 456 Street 200       │ Siem Reap │ Medium          │ Gold            │
│             2 │ 2024-06-12     │ 1000.00  │ DEPOSIT        │ CUST002      │ Chan       │ 456 Street 200       │ Siem Reap │ Medium          │ Gold            │
│             3 │ 2024-06-16     │ 2000.00  │ DEPOSIT        │ CUST002      │ Chan       │ 999 Boulevard 51     │ Phnom Penh│ Low             │ Platinum        │
│             4 │ 2024-06-17     │ 1500.00  │ WITHDRAWAL     │ CUST002      │ Chan       │ 999 Boulevard 51     │ Phnom Penh│ Low             │ Platinum        │
└───────────────┴────────────────┴──────────┴────────────────┴──────────────┴────────────┴──────────────────────┴───────────┴─────────────────┴─────────────────┘
```

**Key Insight:** Even though both transactions use `customer_key = 2` or `5`, the JOIN preserves the customer's attributes **at the time of the transaction**!

---

## Step 6: Verify SCD Type 2 Results

### 6.1 Run Verification Queries

```sql
-- ============================================================
-- VERIFICATION CHECK 1: All customers have exactly one current version
-- ============================================================
SELECT 
    customer_code,
    COUNT(*) AS current_count
FROM dbo.dim_customer
WHERE is_current = 1
GROUP BY customer_code
HAVING COUNT(*) != 1;

-- Expected: 0 rows (all customers have exactly one current version)


-- ============================================================
-- VERIFICATION CHECK 2: No overlapping date ranges
-- ============================================================
SELECT 
    d1.customer_code,
    d1.customer_key AS key1,
    d2.customer_key AS key2,
    d1.effective_date AS start1,
    d1.expiry_date AS end1,
    d2.effective_date AS start2,
    d2.expiry_date AS end2
FROM dbo.dim_customer d1
JOIN dbo.dim_customer d2
    ON d1.customer_code = d2.customer_code
    AND d1.customer_key < d2.customer_key
WHERE d1.expiry_date >= d2.effective_date
AND d1.is_current = 0;

-- Expected: 0 rows (no overlapping date ranges)


-- ============================================================
-- VERIFICATION CHECK 3: Expiry date = next effective date - 1
-- ============================================================
SELECT 
    d1.customer_code,
    d1.customer_key AS current_key,
    d2.customer_key AS next_key,
    d1.expiry_date,
    d2.effective_date,
    DATEDIFF(DAY, d1.expiry_date, d2.effective_date) AS day_diff
FROM dbo.dim_customer d1
JOIN dbo.dim_customer d2
    ON d1.customer_code = d2.customer_code
    AND d1.effective_date < d2.effective_date
WHERE d1.is_current = 0
AND DATEDIFF(DAY, d1.expiry_date, d2.effective_date) != 1;

-- Expected: 0 rows (expiry date is always day before next effective date)


-- ============================================================
-- VERIFICATION CHECK 4: Current records have far-future expiry
-- ============================================================
SELECT 
    customer_code,
    expiry_date
FROM dbo.dim_customer
WHERE is_current = 1
AND expiry_date != '9999-12-31';

-- Expected: 0 rows (all current records have 9999-12-31 expiry)
```

### 6.2 Summary Statistics

```sql
-- ============================================================
-- SUMMARY STATISTICS
-- ============================================================
SELECT 
    'Total Records' AS metric,
    COUNT(*) AS value
FROM dbo.dim_customer
UNION ALL
SELECT 
    'Current Records',
    COUNT(*)
FROM dbo.dim_customer
WHERE is_current = 1
UNION ALL
SELECT 
    'Historical Records',
    COUNT(*)
FROM dbo.dim_customer
WHERE is_current = 0
UNION ALL
SELECT 
    'Customers with History',
    COUNT(DISTINCT customer_code)
FROM dbo.dim_customer
WHERE customer_code IN (
    SELECT customer_code
    FROM dbo.dim_customer
    GROUP BY customer_code
    HAVING COUNT(*) > 1
);
```

---

## Step 7: Advanced - Full ETL Procedure

### 7.1 Create Complete ETL Stored Procedure

```sql
CREATE PROCEDURE dbo.usp_LoadDimCustomer_Full
    @BatchID UNIQUEIDENTIFIER = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    IF @BatchID IS NULL
        SET @BatchID = NEWID();
    
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @NewCount BIGINT = 0;
    DECLARE @ExpiredCount BIGINT = 0;
    DECLARE @InsertedCount BIGINT = 0;
    DECLARE @UnchangedCount BIGINT = 0;
    
    PRINT '================================================';
    PRINT 'SCD Type 2 Load - Customer Dimension';
    PRINT 'Batch ID: ' + CAST(@BatchID AS VARCHAR(50));
    PRINT 'Start Time: ' + CONVERT(VARCHAR(20), @StartTime, 120);
    PRINT '================================================';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        --------------------------------------------------------
        -- PHASE 1: INSERT NEW CUSTOMERS
        --------------------------------------------------------
        PRINT '';
        PRINT 'Phase 1: Inserting new customers...';
        
        INSERT INTO dbo.dim_customer (
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
            CAST(s.customer_id AS VARCHAR(50)),
            @BatchID
        FROM dbo.customers_source s
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.dim_customer d
            WHERE d.customer_code = s.customer_code
        );
        
        SET @NewCount = @@ROWCOUNT;
        PRINT '  New customers inserted: ' + CAST(@NewCount AS VARCHAR(10));
        
        --------------------------------------------------------
        -- PHASE 2: EXPIRE CHANGED CUSTOMERS
        --------------------------------------------------------
        PRINT '';
        PRINT 'Phase 2: Expiring changed customers...';
        
        UPDATE d
        SET
            d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
            d.is_current = 0,
            d.modified_date = GETDATE()
        FROM dbo.dim_customer d
        JOIN dbo.customers_source s
            ON d.customer_code = s.customer_code
        WHERE d.is_current = 1
        AND (
            ISNULL(d.first_name, '') != ISNULL(s.first_name, '')
            OR ISNULL(d.last_name, '') != ISNULL(s.last_name, '')
            OR ISNULL(d.email, '') != ISNULL(s.email, '')
            OR ISNULL(d.phone, '') != ISNULL(s.phone, '')
            OR ISNULL(d.address, '') != ISNULL(s.address, '')
            OR ISNULL(d.city, '') != ISNULL(s.city, '')
            OR ISNULL(d.province, '') != ISNULL(s.province, '')
            OR ISNULL(d.risk_rating, '') != ISNULL(s.risk_rating, '')
            OR ISNULL(d.customer_segment, '') != ISNULL(s.customer_segment, '')
            OR ISNULL(d.is_active, 0) != ISNULL(s.is_active, 0)
        );
        
        SET @ExpiredCount = @@ROWCOUNT;
        PRINT '  Customers expired: ' + CAST(@ExpiredCount AS VARCHAR(10));
        
        --------------------------------------------------------
        -- PHASE 3: INSERT NEW VERSIONS
        --------------------------------------------------------
        PRINT '';
        PRINT 'Phase 3: Inserting new versions...';
        
        INSERT INTO dbo.dim_customer (
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
            CAST(s.customer_id AS VARCHAR(50)),
            @BatchID
        FROM dbo.customers_source s
        WHERE EXISTS (
            SELECT 1 FROM dbo.dim_customer d
            WHERE d.customer_code = s.customer_code
            AND d.is_current = 0
            AND d.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
        );
        
        SET @InsertedCount = @@ROWCOUNT;
        PRINT '  New versions inserted: ' + CAST(@InsertedCount AS VARCHAR(10));
        
        --------------------------------------------------------
        -- PHASE 4: COUNT UNCHANGED
        --------------------------------------------------------
        SET @UnchangedCount = (
            SELECT COUNT(DISTINCT s.customer_code)
            FROM dbo.customers_source s
            JOIN dbo.dim_customer d
                ON s.customer_code = d.customer_code
            WHERE d.is_current = 1
            AND NOT EXISTS (
                SELECT 1 FROM dbo.dim_customer d2
                WHERE d2.customer_code = s.customer_code
                AND d2.is_current = 0
                AND d2.expiry_date = DATEADD(DAY, -1, CAST(GETDATE() AS DATE))
            )
        );
        
        PRINT '';
        PRINT 'Phase 4: Unchanged customers: ' + CAST(@UnchangedCount AS VARCHAR(10));
        
        COMMIT TRANSACTION;
        
        --------------------------------------------------------
        -- LOG COMPLETION
        --------------------------------------------------------
        INSERT INTO dbo.etl_audit (
            batch_id, step_name, operation, table_name,
            records_affected, status, start_time, end_time, notes
        )
        VALUES (
            @BatchID, 'Full_SCD2_Load', 'MERGE', 'dim_customer',
            @NewCount + @ExpiredCount + @InsertedCount, 'COMPLETED',
            @StartTime, GETDATE(),
            'New: ' + CAST(@NewCount AS VARCHAR(10)) +
            ', Expired: ' + CAST(@ExpiredCount AS VARCHAR(10)) +
            ', Updated: ' + CAST(@InsertedCount AS VARCHAR(10)) +
            ', Unchanged: ' + CAST(@UnchangedCount AS VARCHAR(10))
        );
        
        PRINT '';
        PRINT '================================================';
        PRINT 'LOAD COMPLETED SUCCESSFULLY';
        PRINT '================================================';
        PRINT 'Total records affected: ' + CAST(@NewCount + @ExpiredCount + @InsertedCount AS VARCHAR(10));
        PRINT 'Duration: ' + CAST(DATEDIFF(SECOND, @StartTime, GETDATE()) AS VARCHAR(10)) + ' seconds';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- Log error
        INSERT INTO dbo.etl_audit (
            batch_id, step_name, operation, table_name,
            status, start_time, end_time, notes
        )
        VALUES (
            @BatchID, 'Full_SCD2_Load', 'MERGE', 'dim_customer',
            'FAILED', @StartTime, GETDATE(),
            'ERROR: ' + ERROR_MESSAGE()
        );
        
        PRINT '';
        PRINT '================================================';
        PRINT 'LOAD FAILED';
        PRINT 'Error: ' + ERROR_MESSAGE();
        PRINT '================================================';
        
        THROW;
    END CATCH
END;
GO
```

### 7.2 Test the Full Procedure

```sql
-- Make some changes to source data
-- CUST001 gets promoted
UPDATE dbo.customers_source
SET customer_segment = 'Gold', risk_rating = 'Low', modified_date = GETDATE()
WHERE customer_code = 'CUST001';

-- CUST003 changes phone
UPDATE dbo.customers_source
SET phone = '012-999-000', modified_date = GETDATE()
WHERE customer_code = 'CUST003';

-- Add a new customer
INSERT INTO dbo.customers_source (
    customer_code, first_name, last_name, email, phone,
    address, city, province, risk_rating, customer_segment
)
VALUES
    ('CUST005', 'Dy', 'Vicheka', 'vicheka@email.com', '012-111-222',
     '555 Street 500', 'Prey Veng', 'Prey Veng', 'Low', 'Standard');

-- Run the full SCD2 procedure
EXEC dbo.usp_LoadDimCustomer_Full;

-- View final results
SELECT 
    customer_key,
    customer_code,
    first_name,
    risk_rating,
    customer_segment,
    effective_date,
    expiry_date,
    is_current
FROM dbo.dim_customer
ORDER BY customer_code, effective_date;
```

---

## Exercise Summary

### What You Learned

| Step | Concept | What Happened |
|------|---------|---------------|
| Step 1 | Table Design | Created source, dimension, and audit tables with SCD columns |
| Step 2 | Initial Load | Loaded all customers with current version flags |
| Step 3 | New Customer | Detected and inserted a new customer |
| Step 4 | Change Detection | Detected attribute changes and created new version |
| Step 5 | Historical Queries | Queried data "as of" specific dates |
| Step 6 | Verification | Validated SCD Type 2 rules were followed |
| Step 7 | Full Procedure | Built a production-ready ETL procedure |

### Key Takeaways

1. **SCD Type 2 preserves full history** - Old records are never deleted
2. **Surrogate keys** are used for joins, natural keys for lookups
3. **effective_date/expiry_date** define the valid time period
4. **is_current flag** quickly identifies the latest version
5. **Fact tables store surrogate keys** - this is how historical context is preserved

### SCD Type 2 Decision Tree

```
Should you use SCD Type 2?
│
├─ Do you need to analyze by this attribute over time?
│  ├─ YES → Use SCD Type 2
│  └─ NO → Use SCD Type 1 (overwrite)
│
├─ Is this attribute used in regulatory reporting?
│  ├─ YES → Use SCD Type 2
│  └─ NO → Consider SCD Type 1
│
└─ Is historical accuracy important for this data?
   ├─ YES → Use SCD Type 2
   └─ NO → Use SCD Type 1
```

---

## Bonus Challenges

### Challenge 1: Add Employee Dimension with SCD Type 2

```sql
-- Create dim_employee table with SCD Type 2 columns
-- Implement load procedure for employee changes
-- Track: job_title, department, salary_grade, is_active
```

### Challenge 2: Add Date-Based Effective Dating

```sql
-- Modify the procedure to accept an @EffectiveDate parameter
-- Allow backdating of changes (e.g., change happened yesterday but loaded today)
```

### Challenge 3: Add End-of-Month Snapshot

```sql
-- Create a monthly snapshot of customer attributes
-- Useful for month-over-month analysis
```

---

*Exercise Created: September 2024*
*Based on Sathapana Bank Data Engineering Project*
