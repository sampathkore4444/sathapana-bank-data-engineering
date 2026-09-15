# 📜 Data Governance Guide - Banking DWH

## Table of Contents
1. [Overview](#1-overview)
2. [Data Governance Framework](#2-data-governance-framework)
3. [Roles & Responsibilities](#3-roles--responsibilities)
4. [Data Quality Standards](#4-data-quality-standards)
5. [Data Lineage](#5-data-lineage)
6. [Data Retention](#6-data-retention)
7. [Data Catalog](#7-data-catalog)

---

## 1. Overview

Data Governance ensures data is managed as a strategic asset with proper oversight, quality, and compliance.

```
┌─────────────────────────────────────────────────────────────────┐
│                    DATA GOVERNANCE FRAMEWORK                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    GOVERNANCE COUNCIL                     │    │
│  │  CIO, CRO, Compliance Officer, Data Architect            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                    │
│         ┌──────────────────┼──────────────────┐                │
│         │                  │                  │                │
│         ▼                  ▼                  ▼                │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐         │
│  │   DATA      │   │   DATA      │   │   DATA      │         │
│  │   QUALITY   │   │   SECURITY  │   │   STEWARDS  │         │
│  │             │   │             │   │             │         │
│  │ • Standards │   │ • Access    │   │ • Owners    │         │
│  │ • Metrics   │   │ • Privacy   │   │ • Custodians│         │
│  │ • Monitoring│   │ • Compliance│   │ • Users     │         │
│  └─────────────┘   └─────────────┘   └─────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Governance Framework

### Governance Principles

| Principle | Description |
|-----------|-------------|
| **Accountability** | Clear ownership for all data assets |
| **Quality** | Data must be accurate, complete, and timely |
| **Security** | Data protected based on classification |
| **Compliance** | Meet all regulatory requirements |
| **Transparency** | Data lineage and metadata documented |
| **Accessibility** | Data available to authorized users |

---

## 3. Roles & Responsibilities

| Role | Responsibility | Assigned To |
|------|---------------|-------------|
| **Data Owner** | Accountable for data quality | Business Unit Head |
| **Data Steward** | Day-to-day data management | Business Analyst |
| **Data Custodian** | Technical implementation | DBA/Developer |
| **Data Architect** | Design and standards | Data Architect |
| **Data Consumer** | Uses data for analysis | BI Analyst |

### RACI Matrix

| Activity | Owner | Steward | Custodian | Architect |
|----------|-------|---------|-----------|-----------|
| Define business rules | A | R | C | C |
| Implement ETL | C | C | R | A |
| Monitor quality | A | R | C | I |
| Grant access | A | R | R | I |
| Resolve issues | A | R | R | C |

---

## 4. Data Quality Standards

### Quality Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Completeness | ≥ 99.5% | NULL count / Total count |
| Accuracy | ≥ 99.9% | Validation rule pass rate |
| Timeliness | < 6 hours | Time from source to DW |
| Uniqueness | 100% | Duplicate count = 0 |

### Quality Rules

```sql
-- Data Quality Rules Registry
CREATE TABLE governance.quality_rules (
    rule_id INT IDENTITY(1,1) PRIMARY KEY,
    rule_name VARCHAR(100),
    table_name VARCHAR(200),
    column_name VARCHAR(100),
    rule_type VARCHAR(50), -- NOT_NULL, UNIQUE, FORMAT, RANGE
    rule_expression NVARCHAR(500),
    severity VARCHAR(20), -- CRITICAL, HIGH, MEDIUM, LOW
    owner VARCHAR(100),
    is_active BIT DEFAULT 1,
    created_date DATETIME DEFAULT GETDATE()
);
```

---

## 5. Data Lineage

### Lineage Tracking

```sql
-- Data Lineage Table
CREATE TABLE governance.data_lineage (
    lineage_id INT IDENTITY(1,1) PRIMARY KEY,
    source_system VARCHAR(100),
    source_table VARCHAR(200),
    source_column VARCHAR(100),
    target_table VARCHAR(200),
    target_column VARCHAR(100),
    transformation NVARCHAR(500),
    etl_procedure VARCHAR(200),
    last_updated DATETIME DEFAULT GETDATE()
);

-- Sample lineage entries
INSERT INTO governance.data_lineage 
(source_system, source_table, source_column, target_table, target_column, transformation, etl_procedure)
VALUES
('Core Banking', 'oltp.customers', 'first_name', 'dw.dim_customer', 'first_name', 'Direct copy', 'usp_ExtractCustomers'),
('Core Banking', 'oltp.transactions', 'amount', 'dw.fact_transactions', 'amount_usd', 'Currency conversion', 'usp_ExtractTransactions');
```

### Lineage Query

```sql
-- Trace data from source to report
SELECT 
    l.source_system,
    l.source_table + '.' + l.source_column AS source,
    l.target_table + '.' + l.target_column AS target,
    l.transformation,
    l.etl_procedure
FROM governance.data_lineage l
WHERE l.target_table = 'fact_transactions'
ORDER BY l.source_table;
```

---

## 6. Data Retention

### Retention Policy

| Data Type | Retention Period | Disposal Method |
|-----------|------------------|-----------------|
| Transaction Data | 7 years | Archive then delete |
| Customer Data | 5 years after closure | Anonymize |
| Audit Logs | 2 years | Delete |
| ETL Logs | 1 year | Delete |
| Reports | 3 years | Archive |

### Retention Implementation

```sql
-- Archive old transactions (older than 5 years)
CREATE PROCEDURE governance.usp_ArchiveOldData
AS
BEGIN
    DECLARE @CutoffDate DATE = DATEADD(YEAR, -5, GETDATE());
    
    -- Archive to separate table
    INSERT INTO archive.fact_transactions_archive
    SELECT * FROM dw.fact_transactions
    WHERE date_key < CAST(FORMAT(@CutoffDate, 'yyyyMMdd') AS INT);
    
    -- Delete from main table
    DELETE FROM dw.fact_transactions
    WHERE date_key < CAST(FORMAT(@CutoffDate, 'yyyyMMdd') AS INT);
    
    PRINT 'Archived transactions older than ' + CONVERT(VARCHAR(10), @CutoffDate, 120);
END;
GO
```

---

## 7. Data Catalog

### Metadata Table

```sql
CREATE TABLE governance.data_catalog (
    catalog_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name VARCHAR(200),
    column_name VARCHAR(100),
    data_type VARCHAR(50),
    description NVARCHAR(500),
    business_definition NVARCHAR(500),
    owner VARCHAR(100),
    classification VARCHAR(20), -- PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
    source_system VARCHAR(100),
    update_frequency VARCHAR(50),
    last_updated DATETIME DEFAULT GETDATE()
);

-- Populate catalog
INSERT INTO governance.data_catalog 
(table_name, column_name, data_type, description, classification)
VALUES
('dim_customer', 'customer_code', 'VARCHAR(20)', 'Unique customer identifier', 'INTERNAL'),
('dim_customer', 'first_name', 'NVARCHAR(100)', 'Customer first name', 'CONFIDENTIAL'),
('fact_transactions', 'amount', 'DECIMAL(18,2)', 'Transaction amount in original currency', 'INTERNAL');
```

---

## Quick Reference

### Governance Contacts

| Role | Name | Email |
|------|------|-------|
| Data Owner | [Business Head] | [email] |
| Data Steward | [Business Analyst] | [email] |
| Data Custodian | [DBA] | [email] |
| Data Architect | [Architect] | [email] |

---

*Created: September 2024*
