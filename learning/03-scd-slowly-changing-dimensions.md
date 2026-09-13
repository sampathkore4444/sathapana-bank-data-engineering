# Slowly Changing Dimensions (SCD) — Complete Guide

## Table of Contents

1. [What are Slowly Changing Dimensions?](#1-what-are-slowly-changing-dimensions)
2. [SCD Type 0 — Fixed](#2-scd-type-0-fixed)
3. [SCD Type 1 — Overwrite](#3-scd-type-1-overwrite)
4. [SCD Type 2 — Versioning (Most Important!)](#4-scd-type-2-versioning)
5. [SCD Type 3 — Previous Value](#5-scd-type-3-previous-value)
6. [SCD Type 4 — History Table](#6-scd-type-4-history-table)
7. [SCD Type 5 — Hybrid](#7-scd-type-5-hybrid)
8. [SCD Type 6 — Hybrid (Type 1 + Type 2)](#8-scd-type-6-hybrid)
9. [Real-World Banking Scenarios](#9-real-world-banking-scenarios)
10. [Which SCD Type to Use When?](#10-which-scd-type-to-use-when)

---

## 1. What are Slowly Changing Dimensions?

**Slowly Changing Dimensions (SCD)** is a technique to manage **how dimension data changes over time** in a data warehouse.

### The Problem

```
September 12, 2025:
┌─────────────────────────────────────────────┐
│ dim_customer                                │
│ customer_id: 1001                           │
│ name: " Sokha"                              │
│ risk_rating: LOW                            │
│ province: Phnom Penh                        │
└─────────────────────────────────────────────┘

October 5, 2025:
Sokha's risk rating changed from LOW to HIGH!

┌─────────────────────────────────────────────┐
│ dim_customer                                │
│ customer_id: 1001                           │
│ name: " Sokha"                              │
│ risk_rating: HIGH  ← Changed!               │
│ province: Phnom Penh                        │
└─────────────────────────────────────────────┘
```

**Question:** If we simply overwrite, we lose the history. If we keep both, how do we know which is current?

### Why This Matters in Banking

- **Regulatory reporting:** "What was the customer's risk rating on the date of the transaction?"
- **Audit trail:** "Show me all changes to this customer's information over the past 3 years"
- **Historical analysis:** "How did our portfolio risk profile change over time?"

---

## 2. SCD Type 0 — Fixed (No Changes Allowed)

**Rule:** The data **never changes**. If it does, reject it.

**Use Case:** Immutable historical facts.

```sql
-- Example: Customer's date of birth never changes
-- If someone tries to update it, reject the change

CREATE TABLE dim_customer_scd0 (
    customer_key    INT PRIMARY KEY,
    customer_id     VARCHAR(20),
    full_name       NVARCHAR(200),
    date_of_birth   DATE,  -- NEVER changes
    national_id     NVARCHAR(50),  -- NEVER changes
    created_date    DATE
);

-- If source system tries to change DOB, we reject it
-- This is handled in ETL logic, not in the table structure
```

**Banking Example:**
- Customer's National ID number
- Account opening date
- Loan disbursement date
- These are **facts about an entity**, not attributes that change

---

## 3. SCD Type 1 — Overwrite (No History)

**Rule:** Simply overwrite the old value with the new value. **No history is kept.**

**Use Case:** Correcting errors, or when history doesn't matter.

```sql
-- Simple table structure
CREATE TABLE dim_customer_scd1 (
    customer_key    INT PRIMARY KEY,
    customer_id     VARCHAR(20),
    full_name       NVARCHAR(200),
    phone           NVARCHAR(20),
    email           NVARCHAR(200),
    address         NVARCHAR(500),
    risk_rating     VARCHAR(10)
);
```

### ETL Process for SCD Type 1

```sql
-- Step 1: Update existing records
UPDATE dim_customer_scd1
SET 
    phone = src.phone,
    email = src.email,
    address = src.address,
    risk_rating = src.risk_rating
FROM dim_customer_scd1 tgt
INNER JOIN staging_customers src
ON tgt.customer_id = src.customer_id
WHERE tgt.phone <> src.phone
   OR tgt.email <> src.email
   OR tgt.address <> src.address
   OR tgt.risk_rating <> src.risk_rating;

-- Step 2: Insert new customers
INSERT INTO dim_customer_scd1 (customer_id, full_name, phone, email, address, risk_rating)
SELECT customer_id, full_name, phone, email, address, risk_rating
FROM staging_customers src
WHERE NOT EXISTS (
    SELECT 1 FROM dim_customer_scd1 tgt 
    WHERE tgt.customer_id = src.customer_id
);
```

### Example

```
BEFORE (September):
| customer_id | name  | risk_rating | phone       |
|-------------|-------|-------------|-------------|
| 1001        | Sokha | LOW         | 012-345-678 |

AFTER (October - SCD Type 1 Overwrite):
| customer_id | name  | risk_rating | phone       |
|-------------|-------|-------------|-------------|
| 1001        | Sokha | HIGH        | 012-999-999 |  ← Old values GONE!
```

### Pros and Cons

| ✅ Pros | ❌ Cons |
|---|---|
| Simple to implement | No history kept |
| No storage overhead | Can't analyze changes over time |
| Fastest ETL process | Regulatory audit trail lost |

**When to Use:** Phone numbers, email addresses (correcting errors only)

---

## 4. SCD Type 2 — Versioning (MOST IMPORTANT!)

**Rule:** Create a **new row** for each change. Keep all historical versions.

**This is the most commonly used SCD type in data warehouses.**

### Table Structure

```sql
CREATE TABLE dim_customer_scd2 (
    customer_key    INT IDENTITY(1,1) PRIMARY KEY,  -- Surrogate key
    customer_id     VARCHAR(20),                     -- Natural key
    full_name       NVARCHAR(200),
    risk_rating     VARCHAR(10),
    province        NVARCHAR(100),
    phone           NVARCHAR(20),
    email           NVARCHAR(200),
    -- SCD Type 2 columns
    effective_date  DATE,           -- When this version became effective
    expiry_date     DATE,           -- When this version expired (9999-12-31 = current)
    is_current      BIT DEFAULT 1   -- 1 = current version, 0 = historical
);
```

### How It Works

```
September 12, 2025 — Initial Load:
| customer_key | customer_id | name  | risk_rating | effective_date | expiry_date | is_current |
|--------------|-------------|-------|-------------|----------------|-------------|------------|
| 1            | 1001        | Sokha | LOW         | 2025-01-01     | 9999-12-31  | 1          |

October 5, 2025 — Risk rating changes to HIGH:
| customer_key | customer_id | name  | risk_rating | effective_date | expiry_date | is_current |
|--------------|-------------|-------|-------------|----------------|-------------|------------|
| 1            | 1001        | Sokha | LOW         | 2025-01-01     | 2025-10-04  | 0  ← OLD   |
| 2            | 1001        | Sokha | HIGH        | 2025-10-05     | 9999-12-31  | 1  ← NEW   |

November 15, 2025 — Risk rating back to LOW:
| customer_key | customer_id | name  | risk_rating | effective_date | expiry_date | is_current |
|--------------|-------------|-------|-------------|----------------|-------------|------------|
| 1            | 1001        | Sokha | LOW         | 2025-01-01     | 2025-10-04  | 0          |
| 2            | 1001        | Sokha | HIGH        | 2025-10-05     | 2025-11-14  | 0          |
| 3            | 1001        | Sokha | LOW         | 2025-11-15     | 9999-12-31  | 1          |
```

### ETL Process for SCD Type 2

```sql
-- STEP 1: Expire changed records
UPDATE tgt
SET 
    expiry_date = DATEADD(DAY, -1, GETDATE()),
    is_current = 0
FROM dim_customer_scd2 tgt
INNER JOIN staging_customers src
ON tgt.customer_id = src.customer_id
WHERE tgt.is_current = 1
  AND (
      tgt.risk_rating <> src.risk_rating
      OR tgt.province <> src.province
      OR tgt.phone <> src.phone
  );

-- STEP 2: Insert new versions for changed records
INSERT INTO dim_customer_scd2 (
    customer_id, full_name, risk_rating, province, phone, email,
    effective_date, expiry_date, is_current
)
SELECT 
    src.customer_id, src.full_name, src.risk_rating, src.province, 
    src.phone, src.email,
    GETDATE(),           -- effective_date = today
    '9999-12-31',        -- expiry_date = far future
    1                    -- is_current = true
FROM staging_customers src
INNER JOIN dim_customer_scd2 tgt
ON src.customer_id = tgt.customer_id
WHERE tgt.is_current = 0  -- Only expired records
  AND tgt.expiry_date = DATEADD(DAY, -1, GETDATE());  -- Just expired today

-- STEP 3: Insert completely new customers
INSERT INTO dim_customer_scd2 (
    customer_id, full_name, risk_rating, province, phone, email,
    effective_date, expiry_date, is_current
)
SELECT 
    src.customer_id, src.full_name, src.risk_rating, src.province,
    src.phone, src.email,
    GETDATE(), '9999-12-31', 1
FROM staging_customers src
WHERE NOT EXISTS (
    SELECT 1 FROM dim_customer_scd2 tgt 
    WHERE tgt.customer_id = src.customer_id
);
```

### Querying SCD Type 2 Data

```sql
-- Get current version only
SELECT * FROM dim_customer_scd2 WHERE is_current = 1;

-- Get historical version as of a specific date
SELECT * FROM dim_customer_scd2
WHERE customer_id = '1001'
  AND effective_date <= '2025-09-30'
  AND expiry_date >= '2025-09-30';

-- Get all versions ever
SELECT * FROM dim_customer_scd2
WHERE customer_id = '1001'
ORDER BY effective_date;

-- Count how many times a customer's data changed
SELECT customer_id, COUNT(*) as version_count
FROM dim_customer_scd2
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

### Using SCD Type 2 with Fact Tables

The fact table stores the **surrogate key** (customer_key), NOT the natural key.

```sql
-- Transaction on September 15, 2025 (risk was LOW)
-- fact_transactions.customer_key = 1 (the LOW version)

-- Transaction on October 20, 2025 (risk was HIGH)
-- fact_transactions.customer_key = 2 (the HIGH version)

-- To analyze transactions by risk rating:
SELECT 
    c.risk_rating,
    COUNT(*) as transaction_count,
    SUM(t.amount) as total_amount
FROM fact_transactions t
JOIN dim_customer_scd2 c ON t.customer_key = c.customer_key
WHERE c.is_current = 1  -- Or use date-based logic
GROUP BY c.risk_rating;
```

### SCD Type 2 Variants

#### Variant A: Inactive Flag
```sql
-- Instead of expiry_date, just use is_current flag
CREATE TABLE dim_customer (
    customer_key    INT PRIMARY KEY,
    customer_id     VARCHAR(20),
    risk_rating     VARCHAR(10),
    effective_date  DATE,
    is_current      BIT DEFAULT 1
    -- No expiry_date
);
```

#### Variant B: Date Range with Version Number
```sql
CREATE TABLE dim_customer (
    customer_key    INT PRIMARY KEY,
    customer_id     VARCHAR(20),
    risk_rating     VARCHAR(10),
    effective_date  DATE,
    expiry_date     DATE,
    is_current      BIT,
    version_number  INT  -- 1, 2, 3, ...
);
```

### Pros and Cons

| ✅ Pros | ❌ Cons |
|---|---|
| Full history preserved | Table grows quickly |
| Can analyze changes over time | More complex ETL |
| Regulatory audit trail | More storage needed |
| Can answer "as of" questions | Query complexity increases |

**When to Use:** Customer attributes, account status, risk ratings, branch information

---

## 5. SCD Type 3 — Previous Value

**Rule:** Keep the **current** and **previous** value in the same row.

**Use Case:** When you only need to know the previous value, not full history.

### Table Structure

```sql
CREATE TABLE dim_customer_scd3 (
    customer_key        INT PRIMARY KEY,
    customer_id         VARCHAR(20),
    full_name           NVARCHAR(200),
    -- Current value
    risk_rating         VARCHAR(10),
    risk_rating_prev    VARCHAR(10),  -- Previous value!
    risk_rating_change_date DATE,     -- When it changed
    -- Can add more historical columns as needed
    province            NVARCHAR(100),
    province_prev       NVARCHAR(100),
    province_change_date DATE
);
```

### How It Works

```
September 12, 2025:
| customer_id | name  | risk_rating | risk_rating_prev | change_date  |
|-------------|-------|-------------|------------------|--------------|
| 1001        | Sokha | LOW         | NULL             | 2025-01-01   |

October 5, 2025 — Risk changes to HIGH:
| customer_id | name  | risk_rating | risk_rating_prev | change_date  |
|-------------|-------|-------------|------------------|--------------|
| 1001        | Sokha | HIGH        | LOW              | 2025-10-05   |

November 15, 2025 — Risk changes back to LOW:
| customer_id | name  | risk_rating | risk_rating_prev | change_date  |
|-------------|-------|-------------|------------------|--------------|
| 1001        | Sokha | LOW         | HIGH             | 2025-11-15   |
                                    ↑ HIGH is lost! Only one previous is kept
```

### ETL Process for SCD Type 3

```sql
UPDATE dim_customer_scd3
SET 
    risk_rating_prev = risk_rating,  -- Move current to previous
    risk_rating = src.risk_rating,
    risk_rating_change_date = GETDATE()
FROM dim_customer_scd3 tgt
INNER JOIN staging_customers src
ON tgt.customer_id = src.customer_id
WHERE tgt.risk_rating <> src.risk_rating;
```

### Pros and Cons

| ✅ Pros | ❌ Cons |
|---|---|
| Simple to implement | Only keeps ONE previous value |
| Easy to query | Can't see full change history |
| Low storage overhead | Limited analytical value |

**When to Use:** When you only need to know "what was the previous value?" (e.g., previous branch assignment)

---

## 6. SCD Type 4 — History Table

**Rule:** Keep the main table with current values only, and store history in a **separate history table**.

### Table Structure

```sql
-- Main table: Current values only
CREATE TABLE dim_customer_scd4 (
    customer_key    INT PRIMARY KEY,
    customer_id     VARCHAR(20),
    full_name       NVARCHAR(200),
    risk_rating     VARCHAR(10),
    province        NVARCHAR(100),
    phone           NVARCHAR(20),
    last_updated    DATETIME
);

-- History table: All historical values
CREATE TABLE dim_customer_scd4_history (
    history_key     INT IDENTITY(1,1) PRIMARY KEY,
    customer_key    INT,
    risk_rating     VARCHAR(10),
    province        NVARCHAR(100),
    phone           NVARCHAR(20),
    effective_date  DATE,
    expiry_date     DATE
);
```

### How It Works

```
Main Table (dim_customer_scd4):
| customer_id | name  | risk_rating | province    | last_updated  |
|-------------|-------|-------------|-------------|---------------|
| 1001        | Sokha | HIGH        | Phnom Penh  | 2025-10-05    |

History Table (dim_customer_scd4_history):
| customer_id | risk_rating | effective_date | expiry_date  |
|-------------|-------------|----------------|--------------|
| 1001        | LOW         | 2025-01-01     | 2025-10-04   |
| 1001        | HIGH        | 2025-10-05     | 9999-12-31   |
```

### ETL Process for SCD Type 4

```sql
-- Step 1: Insert changed values into history
INSERT INTO dim_customer_scd4_history (customer_key, risk_rating, province, phone, effective_date, expiry_date)
SELECT customer_key, risk_rating, province, phone, effective_date, GETDATE()
FROM dim_customer_scd4
WHERE customer_key IN (
    SELECT tgt.customer_key
    FROM dim_customer_scd4 tgt
    INNER JOIN staging_customers src ON tgt.customer_id = src.customer_id
    WHERE tgt.risk_rating <> src.risk_rating
);

-- Step 2: Update main table
UPDATE tgt
SET 
    risk_rating = src.risk_rating,
    province = src.province,
    phone = src.phone,
    last_updated = GETDATE()
FROM dim_customer_scd4 tgt
INNER JOIN staging_customers src ON tgt.customer_id = src.customer_id
WHERE tgt.risk_rating <> src.risk_rating
   OR tgt.province <> src.province
   OR tgt.phone <> src.phone;
```

### Pros and Cons

| ✅ Pros | ❌ Cons |
|---|---|
| Main table stays small | Two tables to maintain |
| Full history preserved | History table grows fast |
| Query for current data is fast | Join needed for historical queries |

**When to Use:** When you want fast current-data queries but also need full history

---

## 7. SCD Type 5 — Hybrid

**Rule:** Combines SCD Type 4 (history table) with SCD Type 3 (previous value in main table).

### Table Structure

```sql
CREATE TABLE dim_customer_scd5 (
    customer_key        INT PRIMARY KEY,
    customer_id         VARCHAR(20),
    full_name           NVARCHAR(200),
    -- Current value
    risk_rating         VARCHAR(10),
    -- Previous value (SCD Type 3)
    risk_rating_prev    VARCHAR(10),
    -- Link to history table
    current_history_key INT,  -- FK to history table
    last_updated        DATETIME
);

-- History table
CREATE TABLE dim_customer_scd5_history (
    history_key     INT PRIMARY KEY,
    customer_key    INT,
    risk_rating     VARCHAR(10),
    effective_date  DATE,
    expiry_date     DATE
);
```

### When to Use

When you need:
- Fast access to current AND previous values (Type 3 aspect)
- Full history for audit (Type 4 aspect)

---

## 8. SCD Type 6 — Hybrid (Type 1 + Type 2)

**Rule:** Combines SCD Type 2 (versioning) with SCD Type 1 (overwrite for some attributes).

### The Problem It Solves

Some attributes should be tracked historically (Type 2), while others should just be corrected (Type 1).

**Banking Example:**
- `risk_rating`: Keep history (Type 2) — regulatory requirement
- `phone_number`: Just overwrite (Type 1) — no need for history

### Table Structure

```sql
CREATE TABLE dim_customer_scd6 (
    customer_key    INT IDENTITY(1,1) PRIMARY KEY,
    customer_id     VARCHAR(20),
    -- Type 2 attributes (versioned)
    risk_rating     VARCHAR(10),
    effective_date  DATE,
    expiry_date     DATE,
    is_current      BIT,
    -- Type 1 attributes (overwritten)
    phone           NVARCHAR(20),  -- Always current
    email           NVARCHAR(200), -- Always current
    address         NVARCHAR(500)  -- Always current
);
```

### ETL Process for SCD Type 6

```sql
-- Handle Type 2 changes (risk_rating)
-- Same as SCD Type 2 logic above

-- Handle Type 1 changes (phone, email, address)
-- Just update the current row
UPDATE dim_customer_scd6
SET 
    phone = src.phone,
    email = src.email,
    address = src.address
FROM dim_customer_scd6 tgt
INNER JOIN staging_customers src ON tgt.customer_id = src.customer_id
WHERE tgt.is_current = 1
  AND (tgt.phone <> src.phone OR tgt.email <> src.email OR tgt.address <> src.address);
```

### When to Use

When different attributes have different change-tracking requirements:
- **Regulatory attributes** (risk rating, KYC status): Type 2
- **Contact information** (phone, email): Type 1
- **Account status** (active/closed): Type 2

---

## 9. Real-World Banking Scenarios

### Scenario 1: Customer Risk Rating Changes

```
Bank Requirement: Track all risk rating changes for regulatory reporting.

SCD Type: 2 (Full history)

Timeline:
├── Jan 2025: Sokha rated LOW risk
├── Mar 2025: Large cash transaction → rated MEDIUM
├── Jul 2025: AML flag → rated HIGH
└── Sep 2025: Cleared by compliance → rated LOW again

dim_customer:
| key | customer_id | risk_rating | effective_date | expiry_date  | is_current |
|-----|-------------|-------------|----------------|--------------|------------|
| 1   | 1001        | LOW         | 2025-01-01     | 2025-03-14   | 0          |
| 2   | 1001        | MEDIUM      | 2025-03-15     | 2025-07-19   | 0          |
| 3   | 1001        | HIGH        | 2025-07-20     | 2025-09-10   | 0          |
| 4   | 1001        | LOW         | 2025-09-11     | 9999-12-31   | 1          |

-- Report: "Show me all risk rating changes for customer 1001"
SELECT customer_id, risk_rating, effective_date, expiry_date
FROM dim_customer
WHERE customer_id = '1001'
ORDER BY effective_date;

-- Report: "What was the risk rating on July 1, 2025?"
SELECT risk_rating FROM dim_customer
WHERE customer_id = '1001'
  AND effective_date <= '2025-07-01'
  AND expiry_date >= '2025-07-01';
-- Answer: MEDIUM
```

### Scenario 2: Branch Reorganization

```
Bank Requirement: Phnom Penh branch moved to a new region.

SCD Type: 2 (Full history)

Before:
| branch_id | branch_name | province    | region      |
|-----------|-------------|-------------|-------------|
| B001      | PP Main     | Phnom Penh  | Central     |

After reorganization (Oct 2025):
| branch_id | branch_name | province    | region      |
|-----------|-------------|-------------|-------------|
| B001      | PP Main     | Phnom Penh  | Southern    |

dim_branch:
| key | branch_id | branch_name | province   | region    | effective_date | expiry_date  |
|-----|-----------|-------------|------------|-----------|----------------|--------------|
| 1   | B001      | PP Main     | Phnom Penh | Central   | 2020-01-01     | 2025-09-30   |
| 2   | B001      | PP Main     | Phnom Penh | Southern  | 2025-10-01     | 9999-12-31   |

-- Report: "Show Q3 2025 transactions by region"
-- Q3 2025 = Jul-Sep 2025, PP Main was in "Central" region
SELECT b.region, SUM(t.amount)
FROM fact_transactions t
JOIN dim_branch b ON t.branch_key = b.branch_key
JOIN dim_date d ON t.date_key = d.date_key
WHERE d.year = 2025 AND d.quarter = 3
  AND b.effective_date <= '2025-09-30'
  AND b.expiry_date >= '2025-09-30'
GROUP BY b.region;
-- Result: Central = X amount (PP Main included)
```

### Scenario 3: Account Status Changes

```
Bank Requirement: Track when accounts become dormant or closed.

SCD Type: 2 (Full history)

dim_account:
| key | account_number | account_type | status   | effective_date | expiry_date  |
|-----|----------------|-------------|----------|----------------|--------------|
| 1   | 001-001-1234   | SAVINGS     | ACTIVE   | 2023-01-15     | 2025-06-14   |
| 2   | 001-001-1234   | SAVINGS     | DORMANT  | 2025-06-15     | 2025-09-10   |
| 3   | 001-001-1234   | SAVINGS     | ACTIVE   | 2025-09-11     | 9999-12-31   |

-- "Show me accounts that became dormant in 2025"
SELECT account_number, effective_date, expiry_date
FROM dim_account
WHERE status = 'DORMANT'
  AND effective_date BETWEEN '2025-01-01' AND '2025-12-31';
```

### Scenario 4: Product Interest Rate Changes

```
Bank Requirement: Track FD interest rate changes for compliance.

SCD Type: 2 (Full history)

dim_product:
| key | product_name | interest_rate | effective_date | expiry_date  |
|-----|-------------|---------------|----------------|--------------|
| 1   | FD 12M USD  | 4.50%         | 2024-01-01     | 2025-03-31   |
| 2   | FD 12M USD  | 4.75%         | 2025-04-01     | 2025-08-31   |
| 3   | FD 12M USD  | 5.00%         | 2025-09-01     | 9999-12-31   |

-- "Show FD portfolio value by interest rate over time"
SELECT 
    p.product_name,
    p.interest_rate,
    d.year,
    d.quarter,
    SUM(f.outstanding_balance) as total_portfolio
FROM fact_loan_portfolio f
JOIN dim_product p ON f.product_key = p.product_key
JOIN dim_date d ON f.date_key = d.date_key
WHERE p.product_name = 'FD 12M USD'
GROUP BY p.product_name, p.interest_rate, d.year, d.quarter
ORDER BY d.year, d.quarter;
```

---

## 10. Which SCD Type to Use When?

### Decision Matrix

| SCD Type | Use When | Storage | History | Complexity | Banking Example |
|---|---|---|---|---|---|
| **Type 0** | Data never changes | Low | None | Trivial | DOB, National ID |
| **Type 1** | No history needed | Low | None | Low | Phone, Email correction |
| **Type 2** | Full history needed | High | Full | Medium | Risk rating, Status, Branch |
| **Type 3** | Only previous value | Low | Limited | Low | Previous branch |
| **Type 4** | Fast current + full history | Medium | Full | Medium | High-volume dimensions |
| **Type 5** | Fast prev + full history | Medium | Full | High | Complex regulatory needs |
| **Type 6** | Mixed requirements | High | Full + Current | High | Mixed attribute changes |

### Banking Recommendations

```
┌────────────────────────────────────────────────────────────┐
│              SCD TYPE RECOMMENDATIONS FOR BANKING          │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ✅ ALWAYS USE TYPE 2:                                     │
│  • Customer risk rating (regulatory requirement)           │
│  • Account status (active/dormant/closed)                  │
│  • Branch information (reorganizations)                    │
│  • Product attributes (interest rates, terms)              │
│  • KYC status                                              │
│                                                            │
│  ✅ USE TYPE 1:                                            │
│  • Phone numbers (when correcting errors)                  │
│  • Email addresses                                         │
│  • Address corrections                                     │
│                                                            │
│  ⚠️ USE TYPE 3 (Only if needed):                           │
│  • Previous branch assignment                              │
│  • Previous account manager                                │
│                                                            │
│  ❌ AVOID TYPE 0 (Unless truly immutable):                  │
│  • Most banking data changes eventually!                   │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### SCD Type 2 Best Practices

```
1. ALWAYS use surrogate keys
   - customer_key (not customer_id)
   - account_key (not account_number)

2. ALWAYS set expiry_date = '9999-12-31' for current records
   - Makes queries simple: WHERE expiry_date = '9999-12-31'

3. ALWAYS use is_current flag
   - Faster than date comparisons
   - Easier to understand

4. ALWAYS track effective_date
   - Required for "as of" queries
   - Essential for regulatory reporting

5. NEVER mix grains in one SCD table
   - One row = one version of one entity
```

---

## Quick Reference — SQL Patterns

```sql
-- Get current version
SELECT * FROM dim_customer WHERE is_current = 1;

-- Get historical version
SELECT * FROM dim_customer 
WHERE customer_id = '1001'
  AND effective_date <= @target_date
  AND expiry_date > @target_date;

-- Count changes per customer
SELECT customer_id, COUNT(*) - 1 as change_count
FROM dim_customer
GROUP BY customer_id;

-- Find customers who changed in a period
SELECT DISTINCT customer_id
FROM dim_customer
WHERE effective_date BETWEEN '2025-01-01' AND '2025-12-31'
  AND effective_date <> (SELECT MIN(effective_date) 
                         FROM dim_customer d2 
                         WHERE d2.customer_id = dim_customer.customer_id);

-- Join fact table with SCD dimension
SELECT 
    c.full_name,
    c.risk_rating,  -- This is the version that was current when the transaction happened!
    t.amount
FROM fact_transactions t
JOIN dim_customer c ON t.customer_key = c.customer_key
-- No need for is_current filter here! The surrogate key already points to the correct version.
```

---

## Next Steps

Continue to: **[04-ssis-fundamentals.md](./04-ssis-fundamentals.md)** to learn how to implement these data models using SSIS.

---

*Last Updated: September 2026*
*Author: Buffy (Codebuff)*
