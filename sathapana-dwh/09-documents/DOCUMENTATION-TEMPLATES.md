# 📝 ETL Documentation Templates

## Table of Contents
1. [Overview](#1-overview)
2. [ETL Specification Template](#2-etl-specification-template)
3. [Data Dictionary Template](#3-data-dictionary-template)
4. [Runbook Template](#4-runbook-template)
5. [Troubleshooting Guide](#5-troubleshooting-guide)
6. [Change Log](#6-change-log)
7. [Architecture Document](#7-architecture-document)

---

## 1. Overview

Good documentation ensures knowledge transfer, easier maintenance, and faster troubleshooting.

```
┌─────────────────────────────────────────────────────────────────┐
│                    ETL DOCUMENTATION STRUCTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📋 Specification    - What the ETL does                        │
│  📊 Data Dictionary  - Table/column definitions                 │
│  📖 Runbook         - How to run and monitor                    │
│  🔧 Troubleshooting - How to fix issues                         │
│  📝 Change Log      - What changed and when                     │
│  🏗️ Architecture    - How it's designed                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. ETL Specification Template

```markdown
# ETL Specification: [Process Name]

## 1. Overview
| Field | Value |
|-------|-------|
| Process Name | [Name] |
| Owner | [Team/Person] |
| Schedule | [Daily at 2:00 AM] |
| Source System | [System Name] |
| Target System | [DW Database] |
| Last Updated | [Date] |

## 2. Business Requirements
- [Requirement 1]
- [Requirement 2]

## 3. Source Tables
| Table | Database | Description |
|-------|----------|-------------|
| table_name | source_db | Description |

## 4. Target Tables
| Table | Database | Type | Description |
|-------|----------|------|-------------|
| dim_xxx | dw_db | Dimension | Description |
| fact_xxx | dw_db | Fact | Description |

## 5. Transformation Rules
| Source Column | Target Column | Rule |
|---------------|---------------|------|
| src_col | tgt_col | Transformation logic |

## 6. Business Rules
- Rule 1: Description
- Rule 2: Description

## 7. Dependencies
- Must run after: [Process X]
- Required by: [Process Y]

## 8. Error Handling
- On failure: [Action]
- Retry count: [Number]
- Alert to: [Email/Team]
```

---

## 3. Data Dictionary Template

```markdown
# Data Dictionary: [Table Name]

## Table Information
| Property | Value |
|----------|-------|
| Table Name | [table_name] |
| Schema | [schema] |
| Database | [database] |
| Type | [Dimension/Fact/Staging] |
| Description | [What this table stores] |
| Refresh Frequency | [Daily/Hourly] |
| SCD Type | [None/Type 1/Type 2] |
| Owner | [Team/Person] |

## Columns
| Column | Data Type | Nullable | Description | Business Rule |
|--------|-----------|----------|-------------|---------------|
| col1 | INT | No | Primary key | Auto-generated |
| col2 | VARCHAR(50) | No | Business code | Natural key from source |
| col3 | NVARCHAR(100) | Yes | Description | Free text |

## Indexes
| Index Name | Columns | Type | Purpose |
|------------|---------|------|---------|
| IX_table_col | col2 | Non-clustered | Fast lookup |

## Relationships
| Related Table | Join Column | Relationship |
|---------------|-------------|--------------|
| dim_customer | customer_key | Many-to-One |

## Sample Query
```sql
SELECT col1, col2, col3
FROM table_name
WHERE col2 = 'value';
```
```

---

## 4. Runbook Template

```markdown
# ETL Runbook: [Process Name]

## Daily Operations

### Normal Execution
```sql
-- Run the ETL
EXEC staging.usp_ExtractAll @BatchID = NEWID();
EXEC dw.usp_LoadAll @BatchID = NEWID();

-- Or run full pipeline
EXEC staging.usp_RunFullETL;
```

### Check Status
```sql
-- View current status
SELECT * FROM audit.vw_etl_current_status;

-- Check for failures
SELECT * FROM audit.vw_etl_failures;
```

### Monitor Performance
```sql
-- View performance summary
EXEC audit.usp_GetETLPerformance;

-- Check slowest steps
EXEC audit.usp_GetSlowestSteps;
```

## Common Operations

### Re-run Failed Step
```sql
-- Re-run specific step
DECLARE @BatchID UNIQUEIDENTIFIER = NEWID();
EXEC staging.usp_ExtractCustomers @BatchID;
```

### Full Re-load
```sql
-- Clear and reload (use with caution!)
DELETE FROM dw.dim_customer;
DELETE FROM dw.fact_transactions;

-- Then run full ETL
EXEC staging.usp_RunFullETL;
```

### Check Data Counts
```sql
-- Compare source vs target
SELECT 
    (SELECT COUNT(*) FROM source.dbo.customers) AS source_count,
    (SELECT COUNT(*) FROM dw.dim_customer WHERE is_current = 1) AS target_count;
```

## Escalation Contacts
| Role | Name | Email | Phone |
|------|------|-------|-------|
| ETL Developer | [Name] | [email] | [phone] |
| DBA | [Name] | [email] | [phone] |
| Business Owner | [Name] | [email] | [phone] |
```

---

## 5. Troubleshooting Guide

```markdown
# ETL Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: ETL Step Failed
**Symptoms:** Status = 'FAILED' in audit log

**Diagnosis:**
```sql
SELECT * FROM audit.etl_log 
WHERE status = 'FAILED' 
AND start_time >= DATEADD(HOUR, -24, GETDATE());
```

**Solutions:**
1. Check error message in audit log
2. Verify source table exists and has data
3. Check for permission issues
4. Review recent source system changes

---

### Issue 2: Row Count Mismatch
**Symptoms:** Source count ≠ Target count

**Diagnosis:**
```sql
-- Compare counts
SELECT 
    (SELECT COUNT(*) FROM source.table) AS source_count,
    (SELECT COUNT(*) FROM staging.table) AS staging_count,
    (SELECT COUNT(*) FROM dw.table) AS dw_count;
```

**Solutions:**
1. Check for filtered records in WHERE clause
2. Verify incremental load logic
3. Check for data quality rejections
4. Review ETL control table for high-water mark issues

---

### Issue 3: Slow ETL Performance
**Symptoms:** ETL taking longer than usual

**Diagnosis:**
```sql
-- Check duration trends
SELECT 
    step_name,
    AVG(duration_seconds) AS avg_duration,
    MAX(duration_seconds) AS max_duration
FROM audit.etl_log
WHERE start_time >= DATEADD(DAY, -7, GETDATE())
GROUP BY step_name;
```

**Solutions:**
1. Check for table growth (more data)
2. Review index usage
3. Check for blocking/locking issues
4. Consider partitioning large tables

---

### Issue 4: SCD Type 2 Not Working
**Symptoms:** Missing history or duplicate current records

**Diagnosis:**
```sql
-- Check for duplicate current records
SELECT customer_code, COUNT(*) 
FROM dim_customer 
WHERE is_current = 1 
GROUP BY customer_code 
HAVING COUNT(*) > 1;

-- Check date range overlaps
SELECT * FROM dim_customer d1
JOIN dim_customer d2 ON d1.customer_code = d2.customer_code
WHERE d1.effective_date < d2.expiry_date
AND d2.effective_date < d1.expiry_date;
```

**Solutions:**
1. Verify ISNULL comparisons in change detection
2. Check expiry_date calculation
3. Verify effective_date is set correctly
```

---

## 6. Change Log

```markdown
# ETL Change Log

## Format
| Date | Version | Author | Change Description | Impact | Approved By |
|------|---------|--------|-------------------|--------|-------------|

## Changes

| Date | Version | Author | Change Description | Impact | Approved By |
|------|---------|--------|-------------------|--------|-------------|
| 2024-06-15 | 1.0 | John | Initial ETL development | N/A | Jane |
| 2024-06-20 | 1.1 | John | Add error handling | Low | Jane |
| 2024-07-01 | 1.2 | Mary | Add CDC support | Medium | John |
| 2024-07-15 | 2.0 | Mary | Major refactor | High | Director |
```

---

## 7. Architecture Document

```markdown
# ETL Architecture Document

## System Overview
```
┌─────────────────────────────────────────────────────────────────┐
│                    ETL ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Source Systems                                                  │
│  ├── Core Banking System                                         │
│  ├── HR System                                                   │
│  └── Loan Management System                                      │
│                                                                  │
│  ETL Layer                                                       │
│  ├── SQL Server Agent (Scheduling)                               │
│  ├── Stored Procedures (Processing)                              │
│  └── Audit Tables (Logging)                                      │
│                                                                  │
│  Data Warehouse                                                  │
│  ├── Dimensions (SCD Type 2)                                     │
│  ├── Facts (Transactional)                                       │
│  └── Data Marts (Business-specific)                              │
│                                                                  │
│  Reporting Layer                                                 │
│  ├── Power BI                                                    │
│  ├── Excel Reports                                               │
│  └── Ad-hoc Queries                                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Database Design
| Database | Purpose | Schema |
|----------|---------|--------|
| source_db | OLTP source | dbo |
| staging_db | Staging area | staging, audit |
| dw_db | Data warehouse | dw, audit, mart_* |

## ETL Schedule
| Step | Time | Duration | Procedure |
|------|------|----------|-----------|
| Extract | 02:00 AM | 30 min | usp_ExtractAll |
| Transform | 02:30 AM | 30 min | (inline) |
| Load | 03:00 AM | 60 min | usp_LoadAll |
| Serve | 04:00 AM | 60 min | usp_RefreshMarts |

## Security
| Role | Access | Users |
|------|--------|-------|
| ETL_admin | Full access | ETL team |
| ETL_reader | Read only | Reporting |
| ETL_operator | Execute procedures | Operations |

## Disaster Recovery
- **Backup Schedule:** Full backup daily at 1:00 AM
- **Retention:** 30 days
- **Recovery Time Objective (RTO):** 4 hours
- **Recovery Point Objective (RPO):** 1 hour
```

---

*Created: September 2024*
