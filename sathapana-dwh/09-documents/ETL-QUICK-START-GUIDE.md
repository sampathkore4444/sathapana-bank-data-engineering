# 🚀 ETL Quick Start Guide - New Team Members

## Welcome!

This guide will help you get up and running with the Sathapana Bank Data Engineering project in **30 minutes**.

---

## 📋 Table of Contents
1. [What You'll Learn](#1-what-youll-learn)
2. [Prerequisites](#2-prerequisites)
3. [Step 1: Project Overview (5 min)](#3-step-1-project-overview)
4. [Step 2: Database Architecture (5 min)](#4-step-2-database-architecture)
5. [Step 3: Run Your First ETL (10 min)](#5-step-3-run-your-first-etl)
6. [Step 4: Query the Data (5 min)](#6-step-4-query-the-data)
7. [Step 5: Explore the Code (5 min)](#7-step-5-explore-the-code)
8. [Next Steps](#8-next-steps)
9. [Common Tasks](#9-common-tasks)
10. [Getting Help](#10-getting-help)

---

## 1. What You'll Learn

By the end of this guide, you will understand:

```
✅ The project architecture and data flow
✅ How to run the ETL pipeline
✅ How to query the data warehouse
✅ Where to find documentation
✅ Who to ask for help
```

---

## 2. Prerequisites

Before starting, ensure you have:

- [ ] SQL Server Management Studio (SSMS) installed
- [ ] Access to the SQL Server (ask your manager)
- [ ] Basic SQL knowledge
- [ ] This repository cloned

---

## 3. Step 1: Project Overview (5 min)

### What is This Project?

**Sathapana Bank Data Warehouse** collects data from the bank's core systems and prepares it for analytics and reporting.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA FLOW OVERVIEW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐                                                │
│  │   SOURCE    │  Core Banking System (OLTP)                   │
│  │   SYSTEMS   │  Where daily transactions happen              │
│  └──────┬──────┘                                                │
│         │                                                        │
│         │  DAILY at 2:00 AM                                     │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │   STAGING   │  Temporary holding area                        │
│  │             │  Data is cleaned here                         │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │     DW      │  Enterprise Data Warehouse                    │
│  │  (Data WH)  │  Dimensions + Facts (Star Schema)            │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │  DATA MARTS │  Business-specific views                      │
│  │             │  Credit Risk, Customer Analytics, etc.        │
│  └──────┬──────┘                                                │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────┐                                                │
│  │  REPORTS    │  Power BI, Excel, Ad-hoc queries              │
│  └─────────────┘                                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Databases

| Database | Purpose | Schema |
|----------|---------|--------|
| `sathapana_source` | Source system (OLTP) | `oltp` |
| `sathapana_staging` | Staging area | `staging` |
| `sathapana_dwh` | Data Warehouse | `dw`, `audit` |
| `sathapana_dm_credit` | Credit Risk Mart | `dm` |
| `sathapana_dm_customer` | Customer Analytics Mart | `dm` |

---

## 4. Step 2: Database Architecture (5 min)

### Dimension Tables (Who, What, Where, When)

```
dim_customer          dim_account           dim_branch
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ customer_key │     │ account_key  │     │ branch_key   │
│ customer_code│     │account_number│     │ branch_code  │
│ first_name   │     │ customer_key │     │ branch_name  │
│ last_name    │     │ product_key  │     │ province     │
│ email        │     │ balance      │     │ region       │
│ risk_rating  │     │ status       │     └──────────────┘
└──────────────┘     └──────────────┘

dim_product           dim_date             dim_employee
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ product_key  │     │ date_key     │     │ employee_key │
│ product_code │     │ full_date    │     │ employee_code│
│ product_name │     │ day_name     │     │ first_name   │
│ category     │     │ month_name   │     │ job_title    │
│ currency     │     │ year_number  │     │ department   │
└──────────────┘     └──────────────┘     └──────────────┘
```

### Fact Tables (Measurements)

```
fact_transactions
┌─────────────────────────────────────────────────────────────┐
│ transaction_key    │ transaction_code   │ account_key (FK)  │
│ customer_key (FK)  │ date_key (FK)      │ amount            │
│ amount_usd         │ currency           │ transaction_type  │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    References           References           References
    dim_customer         dim_date             dim_account
```

---

## 5. Step 3: Run Your First ETL (10 min)

### Option A: Run Individual Steps

```sql
-- Step 1: Connect to SQL Server in SSMS

-- Step 2: Run Extraction (pulls data from source to staging)
USE sathapana_staging;
GO
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC staging.usp_ExtractAll @BatchID;
GO

-- Step 3: Run Load (moves data from staging to DW)
USE sathapana_dwh;
GO
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC dw.usp_LoadAll @BatchID;
GO
```

### Option B: Run Full Pipeline

```sql
-- Run the complete ETL pipeline
USE sathapana_staging;
GO
EXEC staging.usp_RunFullETL;
GO
```

### What Happens During ETL?

```
EXTRACT (2:00 AM - 2:30 AM)
├── Extract branches from source
├── Extract customers from source
├── Extract accounts from source
└── Extract transactions from source

TRANSFORM (2:30 AM - 3:00 AM)
├── Cleanse data (remove spaces, fix formats)
├── Validate data (check for errors)
└── Apply business rules

LOAD (3:00 AM - 4:00 AM)
├── Load dim_date
├── Load dim_branch
├── Load dim_customer (SCD Type 2)
├── Load dim_account
├── Load fact_transactions
└── Update statistics
```

---

## 6. Step 4: Query the Data (5 min)

### Basic Queries to Try

```sql
-- Query 1: View all customers
SELECT TOP 10 *
FROM sathapana_dwh.dw.dim_customer
WHERE is_current = 1;

-- Query 2: View recent transactions
SELECT TOP 10
    t.transaction_code,
    c.first_name + ' ' + c.last_name AS customer_name,
    t.amount,
    t.transaction_type
FROM sathapana_dwh.dw.fact_transactions t
JOIN sathapana_dwh.dw.dim_customer c ON t.customer_key = c.customer_key
ORDER BY t.created_date DESC;

-- Query 3: Transactions by branch
SELECT 
    b.branch_name,
    COUNT(*) AS transaction_count,
    SUM(t.amount_usd) AS total_amount_usd
FROM sathapana_dwh.dw.fact_transactions t
JOIN sathapana_dwh.dw.dim_branch b ON t.branch_key = b.branch_key
GROUP BY b.branch_name
ORDER BY total_amount_usd DESC;

-- Query 4: Customer segmentation
SELECT 
    customer_segment,
    COUNT(*) AS customer_count
FROM sathapana_dwh.dw.dim_customer
WHERE is_current = 1
GROUP BY customer_segment;

-- Query 5: Check ETL status
SELECT TOP 10
    step_name,
    status,
    start_time,
    end_time,
    duration_seconds
FROM sathapana_dwh.audit.etl_log
ORDER BY start_time DESC;
```

---

## 7. Step 5: Explore the Code (5 min)

### Project Structure

```
sathapana-dwh/
│
├── 02-source-systems/        # Source database setup
│   └── 01-create-source-database.sql
│
├── 03-staging/               # Staging database setup
│   └── 01-create-staging-database.sql
│
├── 04-data-warehouse/        # DW setup
│   └── 01-create-dwh-database.sql
│
├── 05-data-marts/            # Data mart setup
│   ├── 01-create-data-marts.sql
│   └── 08-DATA-MARTS.md      # Data marts guide
│
├── 06-etl/                   # ⭐ ETL Procedures (Start Here!)
│   ├── 01-extract-procedures.sql
│   ├── 02-transform-load-procedures.sql
│   ├── 03-ETL-LEARNING-GUIDE.md  # ⭐ Read This First!
│   ├── 04-SCD-TYPE2-HANDS-ON-EXERCISE.md
│   ├── 06-BUILD-ETL-PIPELINE-FROM-SCRATCH.md
│   └── 12-REAL-WORLD-BANKING-SCENARIOS.md
│
├── 07-data-quality/          # Data quality checks
│   ├── 01-data-quality-framework.sql
│   └── 07-DATA-QUALITY-CHECKS.md
│
├── 08-monitoring/            # Monitoring & alerts
│   ├── 01-monitoring-framework.sql
│   └── 09-ETL-MONITORING-AND-ALERTING.md
│
├── 09-documents/             # 📚 Documentation (Read This!)
│   ├── README.md
│   ├── ETL-MASTER-INDEX.md       # ⭐ Master Index
│   ├── ETL-QUICK-START-GUIDE.md  # ⭐ This Guide
│   ├── ETL-DEPLOYMENT-GUIDE.md
│   ├── ETL-FAQ.md
│   └── 11-DOCUMENTATION-TEMPLATES.md
│
├── 20-testing/               # Testing framework
│   ├── 01-testing-framework.sql
│   └── 10-ETL-TESTING.md
│
└── 21-cdc/                   # Change Data Capture
    ├── 01-change-data-capture-setup.sql
    └── 05-CDC-VS-INCREMENTAL-LOADS.md
```

### Key Files to Read

| Priority | File | Purpose |
|----------|------|---------|
| ⭐ 1 | `06-etl/03-ETL-LEARNING-GUIDE.md` | Learn ETL concepts |
| ⭐ 2 | `09-documents/ETL-MASTER-INDEX.md` | Find any documentation |
| ⭐ 3 | `09-documents/ETL-FAQ.md` | Common questions |
| 4 | `06-etl/01-extract-procedures.sql` | See how extraction works |
| 5 | `06-etl/02-transform-load-procedures.sql` | See how loading works |

---

## 8. Next Steps

After completing this quick start:

### Week 1: Learn the Basics
- [ ] Read `06-etl/03-ETL-LEARNING-GUIDE.md`
- [ ] Complete `06-etl/04-SCD-TYPE2-HANDS-ON-EXERCISE.md`
- [ ] Run the ETL pipeline a few times
- [ ] Write some queries against the DW

### Week 2: Understand the Details
- [ ] Read `21-cdc/05-CDC-VS-INCREMENTAL-LOADS.md`
- [ ] Read `07-data-quality/07-DATA-QUALITY-CHECKS.md`
- [ ] Understand the audit logging
- [ ] Explore data mart views

### Week 3: Get Productive
- [ ] Fix a small bug or add a feature
- [ ] Write a test for an ETL procedure
- [ ] Document something you learned
- [ ] Help a teammate

---

## 9. Common Tasks

### Task: Add a New Column to dim_customer

```sql
-- Step 1: Add column to staging
ALTER TABLE sathapana_staging.staging.stg_customers
ADD new_column VARCHAR(100);

-- Step 2: Add column to dimension
ALTER TABLE sathapana_dwh.dw.dim_customer
ADD new_column VARCHAR(100);

-- Step 3: Update extraction procedure
-- In 06-etl/01-extract-procedures.sql, add new_column to SELECT

-- Step 4: Update load procedure
-- In 06-etl/02-transform-load-procedures.sql, add new_column to INSERT
```

### Task: Debug a Failed ETL

```sql
-- Step 1: Find the error
SELECT *
FROM sathapana_dwh.audit.etl_log
WHERE status = 'FAILED'
ORDER BY start_time DESC;

-- Step 2: Check the error message
SELECT error_message
FROM sathapana_dwh.audit.etl_log
WHERE log_id = (your_log_id);

-- Step 3: Test the procedure manually
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC sathapana_staging.staging.usp_ExtractCustomers @BatchID;
```

### Task: Check Data Quality

```sql
-- Run all quality checks
EXEC sathapana_dwh.audit.usp_RunDataQualityChecks;

-- View quality report
SELECT * FROM sathapana_dwh.audit.vw_quality_dashboard;
```

### Task: Monitor ETL Performance

```sql
-- View recent ETL runs
SELECT 
    step_name,
    status,
    duration_seconds,
    records_affected
FROM sathapana_dwh.audit.etl_log
WHERE start_time >= DATEADD(DAY, -7, GETDATE())
ORDER BY start_time DESC;

-- Find slowest steps
SELECT 
    step_name,
    AVG(duration_seconds) AS avg_duration
FROM sathapana_dwh.audit.etl_log
WHERE operation = 'LOAD'
GROUP BY step_name
ORDER BY avg_duration DESC;
```

---

## 10. Getting Help

### Documentation

| Need | Document |
|------|----------|
| ETL concepts | `06-etl/03-ETL-LEARNING-GUIDE.md` |
| Find any doc | `09-documents/ETL-MASTER-INDEX.md` |
| Common questions | `09-documents/ETL-FAQ.md` |
| Real examples | `06-etl/12-REAL-WORLD-BANKING-SCENARIOS.md` |

### Team Contacts

| Role | Responsibility |
|------|----------------|
| ETL Developer | Build and maintain ETL procedures |
| DBA | Database administration, performance |
| Data Architect | Design data models, schemas |
| Business Analyst | Requirements, data validation |

### Useful Commands

```sql
-- Check ETL status
SELECT * FROM audit.vw_etl_current_status;

-- Check data freshness
SELECT * FROM audit.vw_data_freshness;

-- View database sizes
EXEC sp_spaceused;

-- Check for blocking
SELECT * FROM sys.dm_tran_locks;
```

---

## 📚 Cheat Sheet

### ETL Run Commands
```sql
-- Full pipeline
EXEC staging.usp_RunFullETL;

-- Individual steps
EXEC staging.usp_ExtractAll @BatchID = NEWID();
EXEC dw.usp_LoadAll @BatchID = NEWID();
```

### Useful Queries
```sql
-- Customer count
SELECT COUNT(*) FROM dw.dim_customer WHERE is_current = 1;

-- Transaction total
SELECT SUM(amount_usd) FROM dw.fact_transactions;

-- ETL errors
SELECT * FROM audit.etl_log WHERE status = 'FAILED';
```

### Key Concepts
| Term | Meaning |
|------|---------|
| ETL | Extract, Transform, Load |
| SCD | Slowly Changing Dimension |
| CDC | Change Data Capture |
| Grain | Level of detail in fact table |
| Surrogate Key | Auto-generated DW key |

---

*Welcome to the team! 🎉*
*Sathapana Bank Data Engineering*
