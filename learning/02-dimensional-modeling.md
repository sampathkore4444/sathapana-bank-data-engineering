# Dimensional Modeling — Star Schema, Snowflake, Facts & Dimensions

## Table of Contents

1. [What is Dimensional Modeling?](#1-what-is-dimensional-modeling)
2. [Star Schema](#2-star-schema)
3. [Snowflake Schema](#3-snowflake-schema)
4. [Fact Tables — Types and Design](#4-fact-tables)
5. [Dimension Tables — Types and Design](#5-dimension-tables)
6. [Grain — The Most Important Concept](#6-grain)
7. [Banking Data Warehouse — Full Example](#7-banking-data-warehouse-full-example)
8. [Kimball Methodology — Step by Step](#8-kimball-methodology)

---

## 1. What is Dimensional Modeling?

Dimensional modeling is a technique designed for **query performance and business usability** in data warehouses. It was pioneered by Ralph Kimball.

**Key idea:** Organize data into **facts** (numbers you measure) and **dimensions** (context around those numbers).

### The Analogy — A Banking Report

When a branch manager asks:

> "Show me total deposits for Phnom Penh region in Q3 2025, broken down by account type."

They're really asking:
- **MEASURE (Fact):** Total deposits (SUM of balance)
- **CONTEXT (Dimensions):**
  - WHERE: Phnom Penh region
  - WHEN: Q3 2025
  - WHAT: By account type (Savings, Current, Fixed Deposit)

This maps directly to:
- **Fact Table:** `fact_account_balances` (contains the deposit amounts)
- **Dimension Tables:** `dim_branch` (Phnom Penh), `dim_date` (Q3 2025), `dim_account` (account types)

---

## 2. Star Schema

The **Star Schema** is the most common data warehouse design. It has:
- One central **fact table**
- Multiple **dimension tables** surrounding it
- Each dimension connects directly to the fact table
- Dimensions are **denormalized** (flat, no sub-tables)

### Visual Structure

```
                         dim_date
                           │
                           │
dim_customer ──── fact_transactions ──── dim_account
                           │
                           │
                       dim_branch
```

### Why "Star"?

```
                          dim_date
                            │
                            │
                    ┌───────┼───────┐
                    │       │       │
              dim_customer  │  dim_account
                    │       │       │
                    └───────┼───────┘
                            │
                            │
                       fact_transactions
                            │
                            │
                    ┌───────┼───────┐
                    │       │       │
              dim_branch   ...     ...
```

Looks like a star! ⭐

### Star Schema Example — Banking

```sql
-- DIMENSION: Date (covers 10 years)
CREATE TABLE dim_date (
    date_key        INT PRIMARY KEY,        -- 20250912 format
    full_date       DATE,
    day_of_week     VARCHAR(10),            -- Monday, Tuesday...
    day_of_month    INT,
    month_number    INT,
    month_name      VARCHAR(20),            -- September
    quarter         INT,                     -- Q3
    year            INT,
    is_holiday      BIT,                    -- Khmer holidays!
    holiday_name    VARCHAR(100),
    fiscal_year     INT                     -- Bank's fiscal year
);

-- DIMENSION: Branch (denormalized!)
CREATE TABLE dim_branch (
    branch_key      INT IDENTITY(1,1) PRIMARY KEY,
    branch_code     VARCHAR(10),
    branch_name     NVARCHAR(200),
    branch_type     VARCHAR(50),            -- HEAD_OFFICE, PROVINCIAL, SUB_BRANCH
    province        NVARCHAR(100),
    region          NVARCHAR(100),          -- Phnom Penh, Siem Reap, etc.
    branch_manager  NVARCHAR(200),
    is_active       BIT
);

-- DIMENSION: Customer (with SCD Type 2)
CREATE TABLE dim_customer (
    customer_key    INT IDENTITY(1,1) PRIMARY KEY,
    customer_id     VARCHAR(20),            -- Natural key from CBS
    full_name       NVARCHAR(200),
    customer_type   VARCHAR(20),            -- RETAIL, SME, CORPORATE
    risk_rating     VARCHAR(10),            -- LOW, MEDIUM, HIGH
    open_date       DATE,
    -- SCD Type 2 columns
    effective_date  DATE,
    expiry_date     DATE DEFAULT '9999-12-31',
    is_current      BIT DEFAULT 1
);

-- DIMENSION: Account
CREATE TABLE dim_account (
    account_key     INT IDENTITY(1,1) PRIMARY KEY,
    account_number  VARCHAR(20),
    account_type    VARCHAR(30),            -- SAVINGS, CURRENT, FIXED_DEPOSIT, LOAN
    product_name    NVARCHAR(200),          -- "Sathapana Savings Plus"
    currency        CHAR(3),                -- USD, KHR
    open_date       DATE,
    maturity_date   DATE,                   -- For fixed deposits
    interest_rate   DECIMAL(5,2),
    status          VARCHAR(10),            -- ACTIVE, CLOSED, DORMANT
    branch_key      INT FOREIGN KEY REFERENCES dim_branch(branch_key),
    customer_key    INT FOREIGN KEY REFERENCES dim_customer(customer_key)
);

-- FACT TABLE: Transactions (grain = one row per transaction)
CREATE TABLE fact_transactions (
    transaction_key     BIGINT IDENTITY(1,1) PRIMARY KEY,
    -- Foreign Keys to Dimensions
    account_key         INT FOREIGN KEY REFERENCES dim_account(account_key),
    date_key            INT FOREIGN KEY REFERENCES dim_date(date_key),
    branch_key          INT FOREIGN KEY REFERENCES dim_branch(branch_key),
    customer_key        INT FOREIGN KEY REFERENCES dim_customer(customer_key),
    -- Measures
    credit_amount       DECIMAL(18,2) DEFAULT 0,
    debit_amount        DECIMAL(18,2) DEFAULT 0,
    transaction_count   INT DEFAULT 1,
    balance_after       DECIMAL(18,2),
    -- Degenerate Dimension (dimension embedded in fact)
    transaction_type    VARCHAR(10),        -- DEBIT, CREDIT
    channel             VARCHAR(20),        -- TELLER, ATM, MOBILE, INTERNET, POS
    source_system       VARCHAR(20),        -- CBS, CMS, MOBILE_BANKING
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

### Benefits of Star Schema

| Benefit | Explanation |
|---|---|
| **Simple queries** | Business users can write simple SQL |
| **Fast performance** | Fewer joins, pre-denormalized dimensions |
| **Easy to understand** | Looks like a spreadsheet to business users |
| **Easy to maintain** | Clear structure, easy to modify |

---

## 3. Snowflake Schema

A **Snowflake Schema** normalizes dimensions into sub-dimensions.

### Star vs Snowflake

```
STAR SCHEMA:                          SNOWFLAKE SCHEMA:
                                      
dim_branch                            dim_branch
   │                                    │
   │                                    ├── dim_region
   │                                    │      │
fact_transactions                      │      └── dim_country
                                       │
                                       ├── dim_province
                                              │
                                              └── dim_district
```

### Snowflake Example

```sql
-- Normalized Branch Dimension
CREATE TABLE dim_branch (
    branch_key      INT IDENTITY(1,1) PRIMARY KEY,
    branch_code     VARCHAR(10),
    branch_name     NVARCHAR(200),
    branch_type     VARCHAR(50),
    province_key    INT FOREIGN KEY REFERENCES dim_province(province_key),
    manager_name    NVARCHAR(200)
);

-- Sub-dimension: Province
CREATE TABLE dim_province (
    province_key    INT IDENTITY(1,1) PRIMARY KEY,
    province_name   NVARCHAR(100),
    region_key      INT FOREIGN KEY REFERENCES dim_region(region_key)
);

-- Sub-dimension: Region
CREATE TABLE dim_region (
    region_key      INT IDENTITY(1,1) PRIMARY KEY,
    region_name     NVARCHAR(100),
    country_key     INT FOREIGN KEY REFERENCES dim_country(country_key)
);

-- Sub-dimension: Country
CREATE TABLE dim_country (
    country_key     INT IDENTITY(1,1) PRIMARY KEY,
    country_name    NVARCHAR(100),
    country_code    CHAR(2)
);
```

### When to Use Snowflake vs Star

| Factor | Star Schema | Snowflake Schema |
|---|---|---|
| **Query simplicity** | ✅ Simple, fewer joins | ❌ More joins needed |
| **Storage efficiency** | ❌ Redundant data | ✅ No redundancy |
| **Query performance** | ✅ Faster (fewer joins) | ❌ Slower (more joins) |
| **Maintenance** | ❌ Update multiple copies | ✅ Update one place |
| **Best for** | Most data warehouses | When dimensions are huge |

**Recommendation:** Start with **Star Schema**. Only use Snowflake if you have a specific reason (huge dimensions, strict storage limits). For Sathapana Bank, Star Schema is the way to go.

---

## 4. Fact Tables — Types and Design

### What is a Fact Table?

A fact table contains **measurements** (numeric values) and **foreign keys** to dimension tables.

### Grain: The Most Important Concept

**Grain** = What does **one row** in the fact table represent?

```
┌─────────────────────────────────────────────────────────┐
│                    GRAIN EXAMPLES                        │
├─────────────────────────────────────────────────────────┤
│ Grain: One row = one transaction                        │
│   → fact_daily_transactions                             │
│   → "Each row is one credit/debit transaction"          │
│                                                         │
│ Grain: One row = one account per day                    │
│   → fact_account_daily_balance                          │
│   → "Each row is an account's balance at end of day"    │
│                                                         │
│ Grain: One row = one account per month                  │
│   → fact_account_monthly_summary                        │
│   → "Each row is monthly summary for one account"       │
│                                                         │
│ Grain: One row = one branch per day per product         │
│   → fact_branch_daily_product_summary                   │
│   → "Each row is daily product summary for a branch"    │
└─────────────────────────────────────────────────────────┘
```

**Rule:** You can always aggregate from a finer grain to a coarser grain, but NEVER the other way!

```
✅ Daily → Monthly (SUM the daily values)
❌ Monthly → Daily (IMPOSSIBLE! You lost the detail)
```

### Types of Fact Tables

#### 1. Transaction Fact Table (Most Common)

One row per business event/transaction.

```sql
-- Banking Example: Every transaction is a row
CREATE TABLE fact_transactions (
    transaction_key     BIGINT IDENTITY(1,1) PRIMARY KEY,
    account_key         INT,
    date_key            INT,
    branch_key          INT,
    customer_key        INT,
    -- Measures
    amount              DECIMAL(18,2),
    balance_after       DECIMAL(18,2),
    -- Dimensions (degenerate)
    transaction_type    VARCHAR(10),
    channel             VARCHAR(20),
    source_system       VARCHAR(20),
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);

-- One row example:
-- transaction_key=1, account_key=501, date_key=20250912,
-- branch_key=15, customer_key=3001,
-- amount=500.00, balance_after=2500.00,
-- transaction_type='CREDIT', channel='MOBILE', source_system='CBS'
```

#### 2. Periodic Snapshot Fact Table

One row per entity per time period (daily, monthly, etc.).

```sql
-- Banking Example: End-of-day account balance
CREATE TABLE fact_account_daily_balance (
    balance_key         BIGINT IDENTITY(1,1) PRIMARY KEY,
    account_key         INT,
    date_key            INT,
    branch_key          INT,
    customer_key        INT,
    -- Measures (point-in-time snapshots)
    opening_balance     DECIMAL(18,2),
    closing_balance     DECIMAL(18,2),
    total_credits       DECIMAL(18,2),
    total_debits        DECIMAL(18,2),
    transaction_count   INT,
    -- SCD tracking
    account_status      VARCHAR(10)  -- ACTIVE, DORMANT, CLOSED
);

-- One row: account 501 on 2025-09-12:
-- opening_balance=2000, closing_balance=2500,
-- total_credits=1000, total_debits=500, transaction_count=3
```

#### 3. Accumulating Snapshot Fact Table

Tracks the **lifecycle** of a process (e.g., loan application).

```sql
-- Banking Example: Loan application lifecycle
CREATE TABLE fact_loan_application (
    loan_key            INT IDENTITY(1,1) PRIMARY KEY,
    application_key     INT,
    customer_key        INT,
    branch_key          INT,
    -- Lifecycle dates (each is a FK to dim_date)
    application_date_key    INT,
    approval_date_key       INT,
    disbursement_date_key   INT,
    maturity_date_key       INT,
    closure_date_key        INT,
    -- Measures
    approved_amount     DECIMAL(18,2),
    disbursed_amount    DECIMAL(18,2),
    outstanding_balance DECIMAL(18,2),
    interest_rate       DECIMAL(5,2),
    -- Status tracking
    current_status      VARCHAR(20)  -- PENDING, APPROVED, DISBURSED, CLOSED
);
```

#### 4. Factless Fact Table

Contains **no measures** — only keys to dimensions. Used for tracking events.

```sql
-- Banking Example: Customer visits / interactions
CREATE TABLE fact_customer_interaction (
    interaction_key     INT IDENTITY(1,1) PRIMARY KEY,
    customer_key        INT,
    branch_key          INT,
    date_key            INT,
    interaction_type    VARCHAR(50),  -- BRANCH_VISIT, CALL_CENTER, ATM_USAGE
    product_key         INT
    -- No numeric measures! Just "this happened"
);
```

### Fact Table Best Practices

```
✅ DO:
  - Always define the grain FIRST
  - Use surrogate keys (not natural keys)
  - Keep fact tables narrow (few columns)
  - Store measures as the most atomic value
  - Include foreign keys to ALL dimensions

❌ DON'T:
  - Mix grains in one fact table
  - Store text/descriptions in fact tables (use dimensions)
  - Include business keys directly (use surrogate keys)
  - Leave null values in key columns
```

---

## 5. Dimension Tables — Types and Design

### What is a Dimension Table?

A dimension table provides **context** for the facts. It answers the WHO, WHAT, WHERE, WHEN questions.

### Dimension Design Principles

```sql
-- Good Dimension Design
CREATE TABLE dim_customer (
    -- Surrogate Key (your own ID)
    customer_key        INT IDENTITY(1,1) PRIMARY KEY,
    
    -- Natural Key (from source system)
    customer_id         VARCHAR(20),
    
    -- Descriptive Attributes
    full_name           NVARCHAR(200),
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    gender              VARCHAR(10),
    date_of_birth       DATE,
    age_group           VARCHAR(20),  -- Pre-calculated: '18-25', '26-35', etc.
    
    -- Categorical Attributes
    customer_type       VARCHAR(20),   -- RETAIL, SME, CORPORATE
    customer_segment    VARCHAR(50),   -- GOLD, SILVER, PLATINUM
    risk_rating         VARCHAR(10),   -- LOW, MEDIUM, HIGH
    
    -- Geographic Attributes
    national_id         NVARCHAR(50),
    province            NVARCHAR(100),
    city                NVARCHAR(100),
    
    -- Source System Tracking
    cbs_customer_id     VARCHAR(20),
    cms_customer_id     VARCHAR(20),
    
    -- SCD Type 2 Columns
    effective_date      DATE,
    expiry_date         DATE DEFAULT '9999-12-31',
    is_current          BIT DEFAULT 1,
    
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE()
);
```

### Types of Dimension Tables

#### 1. Conformed Dimension (Shared Across Fact Tables)

A dimension used by **multiple** fact tables, ensuring consistency.

```sql
-- dim_date is used by fact_transactions AND fact_account_daily_balance
-- dim_branch is used by both as well
-- dim_customer is used by both as well

-- This allows cross-fact analysis:
-- "Show me total transactions (fact_transactions) 
--  AND total daily balances (fact_account_daily_balance)
--  for Phnom Penh branch in Q3 2025"
-- Both fact tables share dim_branch and dim_date → can join together!
```

#### 2. Junk Dimension

Combines many low-cardinality flags and indicators into one dimension.

```sql
-- Instead of having separate columns in the fact table:
-- is_international, is_high_value, is_recurring, is_suspicious, etc.

CREATE TABLE dim_transaction_flags (
    flag_key            INT PRIMARY KEY,
    is_international    VARCHAR(3),  -- YES, NO, N/A
    is_high_value       VARCHAR(3),
    is_recurring        VARCHAR(3),
    is_suspicious       VARCHAR(3),
    is_first_transaction VARCHAR(3)
);

-- Fact table references this dimension
-- Reduces columns in fact table, makes it cleaner
```

#### 3. Degenerate Dimension

A dimension that lives **inside** the fact table (no separate table).

```sql
CREATE TABLE fact_transactions (
    transaction_key     BIGINT PRIMARY KEY,
    account_key         INT,
    date_key            INT,
    -- Degenerate dimensions (no separate dimension table needed)
    transaction_ref     VARCHAR(50),   -- Transaction reference number
    transaction_type    VARCHAR(10),   -- DEBIT, CREDIT
    channel             VARCHAR(20),   -- TELLER, ATM, MOBILE
    source_system       VARCHAR(20)    -- CBS, CMS
);
```

#### 4. Role-Playing Dimension

The **same** dimension used multiple times for different roles.

```sql
-- A transaction has TWO dates:
-- 1. Transaction Date (when the transaction happened)
-- 2. Value Date (when it was posted/settled)

-- Solution: Use dim_date twice with different aliases
SELECT 
    t.transaction_key,
    td.full_date AS transaction_date,
    vd.full_date AS value_date,
    t.amount
FROM fact_transactions t
JOIN dim_date td ON t.transaction_date_key = td.date_key
JOIN dim_date vd ON t.value_date_key = vd.date_key;
```

#### 5. outrigger Dimension

A dimension that references **another** dimension (like a mini雪花).

```sql
-- dim_account references dim_branch
-- dim_branch references dim_region
-- This creates a "chain" of dimensions

SELECT 
    t.amount,
    a.account_type,
    b.branch_name,
    r.region_name
FROM fact_transactions t
JOIN dim_account a ON t.account_key = a.account_key
JOIN dim_branch b ON a.branch_key = b.branch_key
JOIN dim_region r ON b.region_key = r.region_key;
```

---

## 6. Grain — The Most Important Concept

### Why Grain Matters

**If you get the grain wrong, everything else fails.**

### Grain Decision Matrix for Banking

```
┌────────────────────────────────────────────────────────────┐
│  Business Question              │  Required Grain           │
├────────────────────────────────────────────────────────────┤
│ "Total transactions per day"    │ 1 row per transaction     │
│ "Daily balance per account"     │ 1 row per account per day │
│ "Monthly loan portfolio"        │ 1 row per loan per month  │
│ "Quarterly branch performance"  │ 1 row per branch per quarter│
│ "Daily card spend by customer"  │ 1 row per card per day    │
└────────────────────────────────────────────────────────────┘
```

### Grain Rule of Thumb

**Start with the finest grain you'll ever need.** You can always aggregate up.

```
Transaction grain (finest)
  ↓ SUM by day
Daily grain
  ↓ SUM by month  
Monthly grain
  ↓ SUM by quarter
Quarterly grain (coarsest)
```

**NEVER start coarse and try to break it down!**

---

## 7. Banking Data Warehouse — Full Example

### Complete Schema for Sathapana Bank

```
┌──────────────────────────────────────────────────────────────┐
│                    DIMENSION TABLES                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  dim_date          dim_branch         dim_customer           │
│  ──────────        ──────────         ──────────             │
│  date_key (PK)     branch_key (PK)    customer_key (PK)     │
│  full_date         branch_code        customer_id           │
│  day_of_week       branch_name        full_name             │
│  month_name        branch_type        customer_type         │
│  quarter           province           risk_rating           │
│  year              region             segment               │
│  fiscal_year       is_active          province              │
│  is_holiday                                 effective_date  │
│                                              expiry_date   │
│                                              is_current    │
│                                                              │
│  dim_account         dim_product       dim_channel          │
│  ──────────          ──────────        ──────────           │
│  account_key (PK)    product_key (PK)  channel_key (PK)     │
│  account_number      product_name      channel_name         │
│  account_type        product_category  channel_type         │
│  currency            product_group     is_digital           │
│  open_date           risk_weight       is_active            │
│  status                                      is_interbranch│
│  branch_key (FK)                                            │
│  customer_key (FK)                                          │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                      FACT TABLES                              │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  fact_transactions          fact_account_daily_balance       │
│  ─────────────────          ──────────────────────────       │
│  transaction_key (PK)       balance_key (PK)                │
│  account_key (FK)           account_key (FK)                │
│  date_key (FK)              date_key (FK)                   │
│  branch_key (FK)            branch_key (FK)                 │
│  customer_key (FK)          customer_key (FK)               │
│  channel_key (FK)           product_key (FK)                │
│  product_key (FK)                                             │
│  amount                     opening_balance                 │
│  balance_after              closing_balance                 │
│  transaction_type           total_credits                   │
│  source_system              total_debits                    │
│                             transaction_count               │
│                                                              │
│  fact_loan_portfolio        fact_card_transactions           │
│  ───────────────────        ────────────────────────         │
│  loan_key (PK)              card_txn_key (PK)               │
│  account_key (FK)           card_key (FK)                   │
│  date_key (FK)              date_key (FK)                   │
│  customer_key (FK)          customer_key (FK)               │
│  branch_key (FK)            merchant_key (FK)               │
│  approved_amount            transaction_amount              │
│  disbursed_amount           merchant_category               │
│  outstanding_balance        transaction_type                │
│  interest_rate              currency                        │
│  days_past_due              source_system                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. Kimball Methodology — Step by Step

Ralph Kimball's approach is the industry standard for building data warehouses:

### Step 1: Choose the Business Process

What are we measuring?

```
Banking Business Processes:
├── Customer Deposits (saving, current accounts)
├── Loan Disbursements and Repayments
├── Card Transactions (credit/debit cards)
├── Mobile/Internet Banking Usage
├── ATM Withdrawals
├── Customer Onboarding
└── Fraud/AML Events
```

### Step 2: Declare the Grain

What does one row represent?

```
Business Process: Customer Deposits
Grain: One row = one account per day (end-of-day balance snapshot)

Business Process: Card Transactions  
Grain: One row = one card transaction

Business Process: Loan Portfolio
Grain: One row = one loan per month
```

### Step 3: Identify the Dimensions

Who/what/where/when?

```
For "Customer Deposits" (daily balance grain):
├── WHEN:    dim_date
├── WHO:     dim_customer
├── WHAT:    dim_account, dim_product
├── WHERE:   dim_branch
└── HOW:     dim_channel
```

### Step 4: Identify the Facts

What are we measuring?

```
For "Customer Deposits" (daily balance grain):
├── opening_balance    (DECIMAL)
├── closing_balance    (DECIMAL)
├── total_credits      (DECIMAL)
├── total_debits       (DECIMAL)
└── transaction_count  (INT)
```

### Step 5: Build the Schema

```sql
-- Final Star Schema for Daily Account Balances
CREATE TABLE fact_account_daily_balance (
    balance_key         BIGINT IDENTITY(1,1) PRIMARY KEY,
    account_key         INT NOT NULL,
    date_key            INT NOT NULL,
    branch_key          INT NOT NULL,
    customer_key        INT NOT NULL,
    product_key         INT NOT NULL,
    channel_key         INT NOT NULL,
    -- Measures
    opening_balance     DECIMAL(18,2),
    closing_balance     DECIMAL(18,2),
    total_credits       DECIMAL(18,2),
    total_debits        DECIMAL(18,2),
    transaction_count   INT,
    -- Metadata
    etl_load_date       DATETIME DEFAULT GETDATE(),
    source_system       VARCHAR(20)
);
```

---

## Quick Reference — Star vs Snowflake

| Aspect | Star Schema | Snowflake Schema |
|---|---|---|
| **Structure** | Dimensions are flat | Dimensions are normalized |
| **Number of tables** | Fewer | More |
| **Query complexity** | Simple (fewer joins) | Complex (more joins) |
| **Performance** | Faster | Slower |
| **Storage** | More (redundant) | Less (normalized) |
| **Maintenance** | Harder (update copies) | Easier (update one place) |
| **Best for** | Most DW projects | When dimensions are huge |
| **Recommendation** | ✅ Use this | ⚠️ Only if needed |

---

## Next Steps

Continue to: **[03-scd-slowly-changing-dimensions.md](./03-scd-slowly-changing-dimensions.md)** to learn how to handle changing data over time.

---

*Last Updated: September 2026*
*Author: Buffy (Codebuff)*
