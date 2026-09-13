# Data Modeling Fundamentals — A Complete Guide

## Table of Contents

1. [What is Data Modeling?](#1-what-is-data-modeling)
2. [Why Data Modeling Matters in Banking](#2-why-data-modeling-matters-in-banking)
3. [Types of Data Models](#3-types-of-data-models)
4. [ER Diagrams (Conceptual, Logical, Physical)](#4-er-diagrams)
5. [Keys and Relationships](#5-keys-and-relationships)
6. [Normalization (1NF, 2NF, 3NF, BCNF)](#6-normalization)
7. [Denormalization — When and Why](#7-denormalization)
8. [Real-World Banking Example](#8-real-world-banking-example)

---

## 1. What is Data Modeling?

**Data modeling** is the process of creating a visual representation (a "blueprint") of your data systems. Think of it like an architect's blueprint for a building — before you build, you need to know:

- What entities exist (customers, accounts, transactions)
- How they relate to each other (a customer **owns** an account)
- What rules govern them (an account must belong to at least one customer)

### The Three Levels of Data Models

```
┌─────────────────────────────────────────────────────┐
│              CONCEPTUAL MODEL                        │
│   "What are the main business entities?"             │
│   Audience: Business stakeholders, architects        │
│   Example: Customer, Account, Transaction            │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              LOGICAL MODEL                           │
│   "What attributes do they have? How do they relate?"│
│   Audience: Data architects, senior developers       │
│   Example: Customer(ID, Name, DOB, Phone)            │
│            Account(AccID, AccType, Balance)           │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              PHYSICAL MODEL                          │
│   "How do we implement this in a specific database?" │
│   Audience: DBAs, developers                         │
│   Example: CREATE TABLE Customer (                   │
│              CustomerID INT PRIMARY KEY,             │
│              FullName NVARCHAR(200),                  │
│              ...                                     │
│            )                                         │
└─────────────────────────────────────────────────────┘
```

---

## 2. Why Data Modeling Matters in Banking

At Sathapana Bank, you'll deal with **multiple source systems**:

| Source System | What It Contains |
|---|---|
| **CBS (Core Banking System)** | Accounts, customers, deposits, loans, fixed deposits |
| **CMS (Card Management System)** | Credit/debit cards, card transactions |
| **Mobile Banking** | App transactions, digital payments, transfers |
| **Internet Banking** | Online transactions, fund transfers |
| **ATM System** | Cash withdrawals, balance inquiries |
| **AML System** | Suspicious transactions, watchlists |
| **General Ledger** | Financial reporting, journal entries |

**Without proper data modeling:**
- You'll have duplicate customer records across systems
- Reporting will be inconsistent (different teams get different numbers)
- Regulatory compliance (NBRC reporting) becomes impossible
- Performance of queries will be terrible

**With proper data modeling:**
- Single source of truth for each business entity
- Fast, consistent reporting
- Easy to add new source systems
- Auditable and compliant

---

## 3. Types of Data Models

### 3.1 Operational Data Model (OLTP)

This is what your source systems (CBS, CMS) use. It's optimized for **writing** data — fast inserts, updates, and deletes for daily banking operations.

**Characteristics:**
- Highly normalized (3NF)
- Many tables with foreign keys
- Optimized for transaction speed
- Current state only (no history)
- Small data volume per query

**Example: CBS OLTP Schema (Simplified)**

```sql
-- Core Banking System - OLTP Tables
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    full_name NVARCHAR(200),
    date_of_birth DATE,
    national_id NVARCHAR(50),
    phone NVARCHAR(20),
    address NVARCHAR(500),
    created_date DATETIME
);

CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    account_number VARCHAR(20),
    customer_id INT FOREIGN KEY REFERENCES customers(customer_id),
    account_type VARCHAR(10),  -- SAV, CUR, FDL, LON
    currency CHAR(3),
    open_date DATE,
    status CHAR(1)  -- A=Active, C=Closed, D=Dormant
);

CREATE TABLE transactions (
    transaction_id BIGINT PRIMARY KEY,
    account_id INT FOREIGN KEY REFERENCES accounts(account_id),
    transaction_date DATETIME,
    amount DECIMAL(18,2),
    balance_after DECIMAL(18,2),
    transaction_type VARCHAR(10),  -- DR, CR
    description NVARCHAR(500),
    channel VARCHAR(20)  -- TELLER, ATM, MOBILE, INTERNET
);
```

**Problem for reporting:** If you want to know "total deposits per branch per month for the last 5 years," you'd need to scan **millions of transaction records** — extremely slow!

### 3.2 Analytical Data Model (OLAP / Data Warehouse)

This is what you'll **build** as a data engineer. Optimized for **reading** — fast aggregations and analytics.

**Characteristics:**
- Denormalized (Star/Snowflake schema)
- Pre-aggregated data
- Historical data (years of history)
- Large data volumes
- Optimized for complex queries

We'll cover this in detail in the next guide.

### 3.3 Other Model Types

| Model | Purpose | Banking Use Case |
|---|---|---|
| **Data Vault** | Audit trail, compliance | Regulatory reporting, full history |
| **Wide Table / ODS** | Temporary staging | Intermediate processing |
| **Graph Model** | Relationship analysis | AML, fraud detection |
| **Data Lake** | Raw data storage | Storing raw CBS/CMS extracts |

---

## 4. ER Diagrams (Entity-Relationship Diagrams)

### Entities in Banking

```
┌──────────────┐       ┌──────────────┐       ┌──────────────────┐
│   CUSTOMER   │1    N │    ACCOUNT   │1    N │   TRANSACTION    │
│──────────────│───────│──────────────│───────│──────────────────│
│ customer_id  │       │ account_id   │       │ transaction_id   │
│ full_name    │       │ account_no   │       │ account_id (FK)  │
│ national_id  │       │ customer_id  │       │ amount           │
│ phone        │       │ account_type │       │ transaction_date │
│ email        │       │ balance      │       │ balance_after    │
│ branch_id    │       │ open_date    │       │ channel          │
│ risk_rating  │       │ status       │       │ description      │
└──────────────┘       └──────────────┘       └──────────────────┘
```

### Cardinality Notation

```
One-to-One (1:1):    Customer ──── Passport
One-to-Many (1:N):   Customer ──── Accounts
Many-to-Many (M:N):  Customer ──── Products (needs junction table)
```

### Real Example: One Customer, Multiple Accounts

```
┌─────────────────────────────────────────────────────────┐
│                    CUSTOMER                              │
│  ID: 10001                                               │
│  Name: " Sokha"                                          │
│  National ID: KH-123456789                               │
└─────────────────────────────────────────────────────────┘
        │                │                │
        ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  ACC: SAV-001│  │  ACC: CUR-002│  │  ACC: FDL-003│
│  Type: SAVE  │  │  Type: CURR  │  │  Type: FIXED │
│  Bal: $5,000 │  │  Bal: $2,000 │  │  Bal: $10,000│
│  Status: A   │  │  Status: A   │  │  Status: A   │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## 5. Keys and Relationships

### Types of Keys

| Key Type | Definition | Banking Example |
|---|---|---|
| **Primary Key (PK)** | Unique identifier for each row | `customer_id` |
| **Foreign Key (FK)** | Links to another table's PK | `account.customer_id` → `customers.customer_id` |
| **Composite Key** | PK made of multiple columns | (account_id, transaction_date) |
| **Surrogate Key** | Artificial key you create | `dim_customer_key` (auto-increment) |
| **Natural Key** | Real-world identifier | `account_number` (e.g., "001-001-123456") |
| **Alternate Key** | Another unique identifier | `national_id` (unique per customer) |

### Why Surrogate Keys Matter in Data Warehousing

```sql
-- NATURAL KEY (from source system):
-- Problem: What if the same customer exists in CBS and CMS with different IDs?
-- Customer 1001 in CBS = Customer 5001 in CMS (same person!)

-- SURROGATE KEY (your own key):
-- You assign your own sequential ID, mapping all source system IDs to one
INSERT INTO dim_customer (customer_key, customer_name, national_id, cbs_id, cms_id)
VALUES (1, 'Sokha', 'KH-123456789', '1001', '5001');
```

### Relationship Types and How to Handle Them

```
CUSTOMER (1) ──────────── (N) ACCOUNT
  │ One customer can have many accounts
  │ Foreign key in ACCOUNT table

ACCOUNT (1) ──────────── (N) TRANSACTION
  │ One account can have many transactions
  │ Foreign key in TRANSACTION table

BRANCH (1) ──────────── (N) ACCOUNT
  │ One branch can have many accounts
  │ Foreign key in ACCOUNT table

CUSTOMER (M) ──────────── (N) PRODUCT
  │ Many customers, many products (needs junction table)
  │ Creates: ACCOUNT (the junction/link table itself!)
```

---

## 6. Normalization

### What is Normalization?

Normalization is the process of organizing data to **reduce redundancy** (duplicate data). It's a series of "normal forms."

### First Normal Form (1NF) — No Repeating Groups

**❌ Not in 1NF:**
```
| Customer    | Accounts           |
|-------------|-------------------|
| Sokha       | SAV-001, CUR-002  |  ← Multiple values in one cell!
| Dara        | LON-003           |
```

**✅ In 1NF:**
```
| Customer | Account    |
|----------|------------|
| Sokha    | SAV-001    |
| Sokha    | CUR-002    |  ← One value per cell
| Dara     | LON-003    |
```

### Second Normal Form (2NF) — No Partial Dependencies

All non-key columns must depend on the **entire** primary key.

**❌ Not in 2NF:**
```
| customer_id | account_id | customer_name | account_type |
|-------------|-----------|---------------|-------------|
| 1001        | SAV-001   | Sokha         | Savings     |
```
`customer_name` depends only on `customer_id`, not on `account_id`. Split into two tables!

**✅ In 2NF:**
```
Table: Customers
| customer_id | customer_name |
|-------------|--------------|
| 1001        | Sokha        |

Table: Accounts
| account_id | customer_id | account_type |
|-----------|-------------|-------------|
| SAV-001   | 1001        | Savings     |
```

### Third Normal Form (3NF) — No Transitive Dependencies

Non-key columns should not depend on **other non-key columns**.

**❌ Not in 3NF:**
```
| account_id | branch_id | branch_name | branch_city |
|-----------|-----------|-------------|------------|
| SAV-001   | B001      | Phnom Penh  | PP         |
```
`branch_name` and `branch_city` depend on `branch_id`, not on `account_id`.

**✅ In 3NF:**
```
Table: Accounts
| account_id | branch_id | account_type |
|-----------|-----------|-------------|

Table: Branches
| branch_id | branch_name | branch_city |
|-----------|-------------|------------|
| B001      | Phnom Penh  | PP         |
```

### Normalization vs Denormalization Summary

```
┌──────────────────────────────────────────────────────────┐
│  NORMALIZED (OLTP)          DENORMALIZED (OLAP/DW)       │
│  ─────────────────          ────────────────────────      │
│  Many small tables          Fewer wide tables             │
│  Fast INSERT/UPDATE         Fast SELECT/AGGREGATE         │
│  No redundancy              Some redundancy (OK!)         │
│  Complex queries (joins)    Simple queries (fewer joins)  │
│  Current state              Historical data               │
│  Used in: CBS, CMS          Used in: Data Warehouse       │
└──────────────────────────────────────────────────────────┘
```

---

## 7. Denormalization — When and Why

### Why Denormalize in a Data Warehouse?

In your data warehouse, you **want** some redundancy because:

1. **Query Performance:** Fewer joins = faster queries
   ```sql
   -- NORMALIZED: Slow (3 joins!)
   SELECT t.amount, a.account_type, c.full_name, b.branch_name
   FROM transactions t
   JOIN accounts a ON t.account_id = a.account_id
   JOIN customers c ON a.customer_id = c.customer_id
   JOIN branches b ON a.branch_id = b.branch_id;
   
   -- DENORMALIZED: Fast (1 join!)
   SELECT t.amount, t.account_type, t.customer_name, t.branch_name
   FROM fact_transactions t;  -- All data in one table!
   ```

2. **Simplicity:** Business users don't need to know complex join logic
3. **Pre-calculated Metrics:** Store aggregated values for instant access

### When NOT to Denormalize

- When data changes frequently (use SCD techniques instead)
- When storage is extremely limited
- When you need strict data integrity (use normalized OLTP for that)

---

## 8. Real-World Banking Example — Building a Simple Model

### Scenario: Sathapana Bank Data Warehouse

**Business Questions to Answer:**
1. Total deposits per branch per month?
2. Which customer segment (SME, Corporate, Retail) has the most loan growth?
3. What's the daily transaction volume by channel (ATM, Mobile, Teller)?
4. How many new accounts opened per quarter?

### Step-by-Step: Conceptual Model

```
┌────────────┐    ┌────────────┐    ┌──────────────┐    ┌────────────┐
│  CUSTOMER  │    │   ACCOUNT  │    │ TRANSACTION  │    │   BRANCH   │
│            │    │            │    │              │    │            │
│ Represents │    │ Represents │    │ Represents   │    │ Represents │
│ all bank   │    │ all deposit│    │ all money    │    │ all branch │
│ customers  │    │ and loan   │    │ movements    │    │ locations  │
│            │    │ accounts   │    │              │    │            │
└────────────┘    └────────────┘    └──────────────┘    └────────────┘
```

### Step-by-Step: Logical Model

```sql
-- Customers Table (from CBS)
CREATE TABLE dim_customer (
    customer_key INT IDENTITY(1,1) PRIMARY KEY,  -- Surrogate key
    customer_id VARCHAR(20),                       -- Natural key from CBS
    full_name NVARCHAR(200),
    customer_type VARCHAR(20),  -- RETAIL, SME, CORPORATE
    national_id NVARCHAR(50),
    risk_rating VARCHAR(10),
    created_date DATE,
    -- SCD Type 2 columns
    effective_date DATE,
    expiry_date DATE,
    is_current BIT DEFAULT 1
);

-- Accounts Table (from CBS)
CREATE TABLE dim_account (
    account_key INT IDENTITY(1,1) PRIMARY KEY,
    account_number VARCHAR(20),
    account_type VARCHAR(20),  -- SAVINGS, CURRENT, FIXED_DEPOSIT, LOAN
    currency CHAR(3),
    open_date DATE,
    close_date DATE,
    status VARCHAR(10),  -- ACTIVE, CLOSED, DORMANT, FROZEN
    branch_key INT FOREIGN KEY REFERENCES dim_branch(branch_key),
    customer_key INT FOREIGN KEY REFERENCES dim_customer(customer_key)
);

-- Branches Table
CREATE TABLE dim_branch (
    branch_key INT IDENTITY(1,1) PRIMARY KEY,
    branch_code VARCHAR(10),
    branch_name NVARCHAR(200),
    province NVARCHAR(100),
    region NVARCHAR(100)
);

-- Transactions Fact Table (from CBS + CMS + Mobile)
CREATE TABLE fact_transactions (
    transaction_key BIGINT IDENTITY(1,1) PRIMARY KEY,
    account_key INT FOREIGN KEY REFERENCES dim_account(account_key),
    transaction_date_key INT,  -- FK to dim_date
    amount DECIMAL(18,2),
    balance_after DECIMAL(18,2),
    transaction_type VARCHAR(10),  -- DEBIT, CREDIT
    channel VARCHAR(20),  -- TELLER, ATM, MOBILE, INTERNET, POS
    source_system VARCHAR(20)  -- CBS, CMS, MOBILE, INTERNET
);
```

### The Dimensional Model (Star Schema)

```
                    ┌──────────────┐
                    │  dim_branch  │
                    │──────────────│
                    │ branch_key(PK)│
                    │ branch_code  │
                    │ branch_name  │
                    │ province     │
                    └──────┬───────┘
                           │
┌──────────────┐    ┌──────┴───────┐    ┌──────────────┐
│ dim_customer │    │dim_account   │    │  dim_date    │
│──────────────│    │──────────────│    │──────────────│
│customer_key  │    │account_key(PK)│   │date_key(PK) │
│customer_name │    │account_number│   │full_date     │
│customer_type │    │account_type  │   │year          │
│national_id   │    │currency      │   │month         │
│risk_rating   │    │branch_key(FK)│   │quarter       │
└──────┬───────┘    │customer_key  │   │day_of_week   │
       │            └──────┬───────┘   └──────┬───────┘
       │                   │                  │
       │            ┌──────┴──────────────────┴──────┐
       │            │      fact_transactions         │
       │            │────────────────────────────────│
       └────────────┤ transaction_key (PK)           │
                    │ account_key (FK)               │
                    │ transaction_date_key (FK)      │
                    │ amount                         │
                    │ balance_after                  │
                    │ transaction_type               │
                    │ channel                        │
                    │ source_system                  │
                    └────────────────────────────────┘
```

---

## Quick Reference — Key Concepts

| Concept | What It Means | Banking Example |
|---|---|---|
| **Entity** | A thing you track | Customer, Account, Transaction |
| **Attribute** | A property of an entity | Customer Name, Account Balance |
| **Relationship** | How entities connect | Customer **owns** Account |
| **Primary Key** | Unique row identifier | customer_id = 1001 |
| **Foreign Key** | Links tables together | account.customer_id → customer.customer_id |
| **Surrogate Key** | Your own artificial key | customer_key = 1 (auto-increment) |
| **Fact Table** | Transaction/measurement data | Every transaction row |
| **Dimension Table** | Descriptive/context data | Customer details, Branch info |
| **Star Schema** | Facts + dimensions, flat design | Most data warehouses |
| **Snowflake Schema** | Dimensions are normalized | When dimensions are complex |
| **3NF** | No redundancy, no transitive deps | Source systems (CBS, CMS) |

---

## Next Steps

Continue to the next guide: **[02-dimensional-modeling.md](./02-dimensional-modeling.md)** to learn about Star Schema, Snowflake Schema, and how to design fact and dimension tables in depth.

---

*Last Updated: September 2026*
*Author: Buffy (Codebuff)*
