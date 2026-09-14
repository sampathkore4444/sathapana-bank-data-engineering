# 15 - Security Framework

## Overview

This directory contains the role-based access control (RBAC), data masking, and audit trail implementation for the data warehouse.

## Files

| File | Purpose |
|------|---------|
| `01-security-framework.sql` | Database roles, permissions, row-level security, and audit logging |

## Security Architecture

### Role-Based Access Control (RBAC)

| Role | Databases | Permissions | Typical Users |
|------|-----------|-------------|---------------|
| `DWH_Admin` | All | Full control | DBA Team |
| `ETL_Service` | All | Read/Write (ETL schemas) | ETL Service Account |
| `BI_Analyst` | DW, Marts | Read only | BI Developers, Analysts |
| `Data_Steward` | Source, Staging | Read/Write (dimensions) | Data Quality Team |
| `Compliance_Officer` | DW, Compliance Mart | Read + Export | AML Officers |
| `Auditor` | All | Read only + Audit logs | Internal Auditors |

### Permission Matrix

| Object | DWH_Admin | ETL_Service | BI_Analyst | Data_Steward | Compliance | Auditor |
|--------|-----------|-------------|------------|--------------|------------|---------|
| `dw.*` (dimensions) | Full | Read/Write | Read | Read/Update | Read | Read |
| `dw.*` (facts) | Full | Read/Write | Read | Read | Read | Read |
| `audit.*` | Full | Read | Read | — | Read | Read |
| `staging.*` | Full | Read/Write | — | Read/Write | — | — |

## Row-Level Security

### Branch-Based Filtering

Users see only data from their assigned branches:

```sql
-- Security predicate function
CREATE FUNCTION dw.fn_SecurityPredicateBranch(@branch_key INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS has_access
    WHERE IS_MEMBER('DWH_Admin') = 1
       OR @branch_key IN (
           SELECT branch_key
           FROM dw.vw_user_branch_access
           WHERE user_name = SYSTEM_USER
       )
);
```

### Affected Tables

| Table | Filter Column |
|-------|---------------|
| `dw.fact_transactions` | `branch_key` |
| `dw.fact_loan_portfolio` | `branch_key` |
| `dw.fact_deposit_snapshot` | `branch_key` |

### Enable/Disable

```sql
-- Enable row-level security
ALTER SECURITY POLICY BranchFilterPolicy WITH (STATE = ON);

-- Disable row-level security
ALTER SECURITY POLICY BranchFilterPolicy WITH (STATE = OFF);
```

## Column-Level Security (Data Masking)

### Masked View: `dw.vw_customer_masked`

For non-privileged users, sensitive columns are masked:

| Column | Masking Rule | Example |
|--------|-------------|---------|
| `first_name` | First char + `****` | `C****` |
| `last_name` | First char + `****` | `P****` |
| `national_id` | Hidden | Not returned |
| `phone` | Hidden | Not returned |
| `email` | Hidden | Not returned |

### Access Pattern

```sql
-- Privileged users (DWH_Admin, Compliance)
SELECT * FROM dw.dim_customer;          -- Full access

-- Non-privileged users (BI_Analyst)
SELECT * FROM dw.vw_customer_masked;    -- Masked access
```

## Data Classification

| Classification | Description | Examples | Protection |
|----------------|-------------|----------|------------|
| **Public** | Non-sensitive | Branch names, product names | None |
| **Internal** | Business sensitive | Transaction amounts, balances | RBAC |
| **Confidential** | Personal data | Customer PII, account details | Masking + RBAC |
| **Restricted** | Regulatory data | AML alerts, suspicious transactions | RBAC + Audit |

## Audit Trail

### Sensitive Access Log

```sql
-- Table: audit.sensitive_access_log
-- Captures: User, table, access type, timestamp, IP address

-- Query recent access
SELECT * FROM audit.sensitive_access_log
ORDER BY access_time DESC;
```

### Trigger-Based Logging

A trigger on `dw.dim_customer` logs all SELECT access for audit purposes.

## Transparent Data Encryption (TDE)

TDE setup is documented but disabled by default (requires Enterprise Edition):

```sql
-- Steps (when ready):
-- 1. Create master key
-- 2. Create certificate
-- 3. Create database encryption key
-- 4. Enable TDE
```

## Execution

```sql
-- Apply security framework
:15-security/01-security-framework.sql
```

## Security Checklist

- [ ] Create database roles
- [ ] Grant permissions per role
- [ ] Create row-level security predicates
- [ ] Create masked views for PII
- [ ] Enable audit logging
- [ ] Configure TDE (if Enterprise Edition)
- [ ] Test access with each role
- [ ] Document exceptions

## Notes

- Row-level security is **disabled by default** — enable when ready
- The `ETL_Service` role is used by SQL Server Agent jobs
- Audit logs are retained for 2 years
- TDE requires SQL Server Enterprise Edition
- Password policy should be enforced for SQL logins
