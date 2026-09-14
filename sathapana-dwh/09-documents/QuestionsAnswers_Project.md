# Questions & Answers — Sathapana Bank DWH Project

This document captures common questions about the project architecture, design decisions, and how they relate to real-world production environments.

---

## Q1: Source Database & Raw Zone — Is This How We Do It in Production?

**Question**: You created two databases — `sathapana_source` and `sathapana_raw`. Is this the production approach?

### Answer

**Partially yes, but not exactly how it's set up in this project.**

### Source Database (`sathapana_source`) — You DON'T Create This in Production

In the real world, the source systems **already exist**. You don't build them — the core banking team, treasury team, etc. own those databases. Your job as a DWH engineer is to **read from them**, not create them.

```
Production reality:
├── Core Banking DB ──────── (owned by app team, you have READ access)
├── Treasury System DB ───── (owned by treasury team, you have READ access)
├── Credit System DB ─────── (owned by credit team, you have READ access)
└── External Feeds ───────── (NBC, SWIFT — file/API based)
```

The `01-create-source-database.sql` file only exists in this project for **simulation/learning purposes** — so you have sample data to work with.

### Raw Zone (`sathapana_raw`) — Yes, This Is Real

Having a separate raw zone database is **standard practice**. You create it. It's your copy of their data.

### But Here's the Nuance

In production, the raw zone can be implemented **three ways**:

| Approach | When to Use | Example |
|----------|------------|---------|
| **Separate database** | Traditional DWH, on-premises SQL Server | `sathapana_raw` as its own database |
| **Schema within DWH** | Simpler setup, smaller data volumes | `sathapana_dwh.raw.*` schema |
| **Data Lake / Cloud Storage** | Modern cloud architectures | Azure Data Lake, S3 bucket |

### What Most Production Banks Do

```
Option A: Traditional (on-prem SQL Server)
─────────────────────────────────────────
Source Systems ──► Raw DB (your copy) ──► Staging ──► DW ──► Marts

Option B: Cloud / Modern
─────────────────────────────────────────
Source Systems ──► Data Lake (raw) ──► Data Lake (processed) ──► DW ──► Marts
```

### What This Project Does (Learning/Simulation)

```
sathapana_source ──► sathapana_raw ──► sathapana_staging ──► sathapana_dwh ──► marts
  (simulated)        (your copy)       (cleansing)          (enterprise)     (serving)
```

### Key Differences

| Aspect | This Project | Production |
|--------|-------------|------------|
| Source database | We create it (simulation) | Already exists, you have READ access |
| Raw zone | Separate database | Separate DB, schema, or data lake |
| Access to source | Full control | Read-only (usually a service account) |
| Source changes | We control the sample data | Source app team makes changes |
| Extract method | Direct INSERT/SELECT | CDC, SSIS, ODBC, API, file drops |

---

## Q2: Why Use Separate Databases Instead of Schemas?

**Question**: Why create 10 separate databases instead of using schemas within one database?

### Answer

Both approaches are valid. Here's the tradeoff:

| Factor | Separate Databases | Schemas in One DB |
|--------|-------------------|-------------------|
| **Isolation** | ✅ Full isolation — one app can't crash another | ❌ Shared resources |
| **Security** | ✅ Per-database permissions | ⚠️ Schema-level permissions (less common) |
| **Backup/Restore** | ✅ Can restore one mart without affecting others | ❌ Must restore entire DB |
| **Performance** | ✅ Can place on different filegroups/disks | ❌ All on same storage |
| **Complexity** | ❌ Cross-database queries need 3-part naming | ✅ Simple schema references |
| **Cost** | ❌ More metadata overhead | ✅ Lower overhead |
| **Team Ownership** | ✅ Each team owns their mart DB | ⚠️ Harder to separate ownership |

### When to Use What

- **Learning / Small project** → Schemas are fine (simpler)
- **Production / Enterprise** → Separate databases (better isolation)
- **Cloud (Azure SQL DB)** → Separate databases per mart (natural scaling)

This project uses **separate databases** to demonstrate the production pattern, even though it's a learning project.

---

## Q3: Why Use Views for Data Marts Instead of Physical Tables?

**Question**: The data marts are views on top of the DW. Shouldn't they be physical tables for better performance?

### Answer

Views are the **correct default choice** for data marts. Here's why:

| Aspect | Views (What We Use) | Physical Tables |
|--------|-------------------|-----------------|
| **Data freshness** | ✅ Always current — reflects latest DW data | ❌ Must be refreshed |
| **Storage** | ✅ No extra storage needed | ❌ Duplicates data |
| **Maintenance** | ✅ No refresh jobs needed | ❌ Additional ETL required |
| **Consistency** | ✅ Single source of truth | ❌ Risk of stale data |
| **Performance** | ⚠️ Query runs against DW tables | ✅ Pre-aggregated, indexed |
| **Complexity** | ✅ Simple to implement | ❌ Need refresh strategy |

### When to Switch to Physical Tables

- When a query is **too slow** (e.g., aggregating millions of rows)
- When Power BI needs **import mode** (caches data anyway)
- When a report needs **pre-calculated aggregates** (e.g., monthly summaries)

### What This Project Does

```
Data Marts ──► Views on DW tables (real-time, no duplication)

If performance becomes an issue:
  Option 1: Materialized views (SQL Server indexed views)
  Option 2: Summary tables with scheduled refresh
  Option 3: Power BI Import Mode (caches at refresh time)
```

---

## Q4: Why SCD Type 2 for Some Dimensions but Not Others?

**Question**: Why use SCD Type 2 for Customer, Account, and Employee but Type 1 for Product and Branch?

### Answer

It depends on **how often the data changes** and **whether you need history**.

| Dimension | SCD Type | Reason |
|-----------|----------|--------|
| **DimCustomer** | Type 2 | Customers move, change segments, update KYC — need full history for audit |
| **DimAccount** | Type 2 | Accounts change products, branches, status — need history for analysis |
| **DimEmployee** | Type 2 | Employees change branches, departments — need history for HR reporting |
| **DimProduct** | Type 1 | Product names change, but old names don't matter for analysis |
| **DimBranch** | Type 1 | Branch contact info changes, but the branch identity doesn't change |
| **DimCurrency** | Type 1 | Currency codes don't change |
| **DimDate** | Static | Pre-populated, never changes |
| **DimChannel** | Static | Reference data, never changes |

### Rule of Thumb

- **Type 2**: If the change **matters for historical analysis** (customer moved branches 3 years ago — do you care?)
- **Type 1**: If you only care about the **current state** (product was renamed — old name is irrelevant)

### Storage Impact

Type 2 dimensions grow over time. Each change creates a new row:

```
DimCustomer with Type 2:
┌─────────────┬──────────────┬─────────────┬────────────┬────────────┐
│ customer_key│ customer_code│ segment     │ valid_from │ valid_to   │
├─────────────┼──────────────┼─────────────┼────────────┼────────────┤
│ 1           │ CUST001      │ RETAIL      │ 2020-01-01 │ 2022-06-30 │  ← old version
│ 2           │ CUST001      │ SME         │ 2022-07-01 │ NULL       │  ← current
└─────────────┴──────────────┴─────────────┴────────────┴────────────┘
```

---

## Q5: How Does the ETL Handle Failures?

**Question**: What happens if the ETL job fails halfway through?

### Answer

The project uses a **multi-layered error handling** strategy:

### 1. Job-Level (SQL Server Agent)

```
DWH_00_Master_Pipeline
  ├── Step 1: Extract ──(on success)──► Step 2: Stage
  │                  ──(on failure)──► QUIT WITH FAILURE
  ├── Step 2: Stage   ──(on success)──► Step 3: Transform
  │                  ──(on failure)──► QUIT WITH FAILURE
  └── ...
```

- **Retry**: 3 attempts, 5-minute interval between retries
- **Notification**: Email sent to DWH_Operator on failure
- **Job chain stops**: No downstream steps run if a step fails

### 2. Step-Level (TRY...CATCH)

```sql
BEGIN TRY
    -- ETL logic here
    INSERT INTO dw.dim_customer ...
    
    -- Log success
    UPDATE audit.etl_log SET status = 'COMPLETED' WHERE batch_id = @BatchID;
END TRY
BEGIN CATCH
    -- Log failure with error details
    UPDATE audit.etl_log 
    SET status = 'FAILED', error_message = ERROR_MESSAGE()
    WHERE batch_id = @BatchID;
    
    THROW;  -- Re-raise error to stop the job
END CATCH
```

### 3. Data-Level (Quality Checks)

After ETL completes, quality checks run:

```sql
-- If critical quality check fails:
IF @FailedChecks > 0
BEGIN
    -- Send alert
    EXEC audit.usp_SendAlert @AlertType = 'QUALITY_FAILURE', ...;
    
    -- Log for investigation
    INSERT INTO audit.data_quality_log ...
END
```

### 4. What You Should Do in Production

| Layer | Production Enhancement |
|-------|----------------------|
| **Dead Letter Queue** | Failed records stored for retry, not lost |
| **Partial Load** | Load successful records, skip failures |
| **Alert Escalation** | Email → SMS → Phone call based on severity |
| **Dashboard** | Real-time monitoring of ETL health |
| **Auto-Retry** | Retry failed steps automatically (built into Agent jobs) |

---

## Q6: Why Not Use SSIS or Azure Data Factory Instead of Stored Procedures?

**Question**: The ETL is written in T-SQL stored procedures. Shouldn't we use SSIS or ADF?

### Answer

For this project, stored procedures are the **right choice**. Here's the comparison:

| Factor | Stored Procedures (What We Use) | SSIS / ADF |
|--------|-------------------------------|------------|
| **Learning curve** | ✅ Just SQL — easy to understand | ❌ Visual designer, steep curve |
| **Version control** | ✅ Plain text files, Git-friendly | ⚠️ SSIS packages are binary/XML |
| **Portability** | ✅ Works on any SQL Server | ❌ Microsoft-only |
| **Debugging** | ✅ Step through in SSMS | ⚠️ Different debugging model |
| **Performance** | ✅ Direct SQL, no overhead | ⚠️ Pipeline overhead |
| **Complexity** | ⚠️ Manual dependency management | ✅ Visual orchestration |
| **Scalability** | ⚠️ Limited to SQL Server | ✅ ADF scales to big data |

### When to Use What

| Scenario | Recommendation |
|----------|---------------|
| **Learning / Portfolio** | Stored procedures (what we use) |
| **Small-Medium bank** | Stored procedures or SSIS |
| **Large enterprise** | ADF + Synapse / SSIS |
| **Cloud-native** | Azure Data Factory / dbt |
| **Real-time** | CDC + Streaming (Kafka, Event Hubs) |

### For This Project

Stored procedures are ideal because:
1. **No extra tools** — just SQL Server
2. **Easy to understand** — pure SQL logic
3. **Git-friendly** — text files, not binary packages
4. **Interview-ready** — shows you understand the logic, not just the tool

---

## Q7: How Do You Handle Cross-Database Queries?

**Question**: The ETL queries across `sathapana_source`, `sathapana_raw`, `sathapana_staging`, and `sathapana_dwh`. How does that work?

### Answer

SQL Server supports **three-part naming** for cross-database queries:

```sql
-- Format: database.schema.table
SELECT *
FROM sathapana_source.oltp.customers    -- Source
WHERE customer_id IN (
    SELECT customer_id
    FROM sathapana_raw.raw.customers     -- Raw zone
);
```

### Requirements

| Requirement | Description |
|-------------|-------------|
| **Permissions** | ETL service account needs access to all databases |
| **Same instance** | All databases must be on the same SQL Server instance |
| **Collation** | Databases should use the same collation for joins |

### If Databases Are on Different Servers

```sql
-- Option 1: Linked Server
SELECT * FROM [SERVER2].sathapana_dwh.dw.dim_customer;

-- Option 2: ETL tool (SSIS/ADF) handles the movement
-- Option 3: Replication / log shipping
```

### In This Project

All 10 databases are on the **same SQL Server instance**, so three-part naming works directly. The ETL service account is granted cross-database access.

---

## Q8: What Happens When Source Systems Change Their Schema?

**Question**: If the core banking system adds a new column or changes a data type, what breaks?

### Answer

This is a real-world challenge. Here's how to handle it:

### What Breaks

| Change | Impact |
|--------|--------|
| New column added | Usually no impact (we don't SELECT *) |
| Column removed | INSERT/SELECT fails — ETL breaks |
| Data type change | May fail if types are incompatible |
| Table renamed | All references break |
| Column renamed | INSERT/SELECT fails |

### Mitigation Strategies

| Strategy | How It Helps |
|----------|-------------|
| **Source-to-Raw validation** | Catch mismatches early (row counts, column checks) |
| **Staging layer** | Absorbs changes — only staging needs updating |
| **View abstraction** | Marts use views, so only views need updating |
| **Schema documentation** | Keep source schema docs updated |
| **Change notification** | Source team notifies DWH team before changes |

### Recommended Practice

```
1. Source system announces schema change
2. DWH team reviews impact
3. Update extract procedures (Layer 0 → Layer 1)
4. Update staging tables if needed
5. Update DW dimensions/facts if needed
6. Update mart views if needed
7. Test full pipeline
8. Deploy to production
```

### In This Project

Since we control the source database, schema changes are simulated. In production, you'd have a **formal change management process** between the app team and DWH team.

---

## Q9: Should the Raw Zone Keep Historical Data or Be Truncated?

**Question**: The raw zone is truncated before each extract. Shouldn't it keep history?

### Answer

It depends on your **architecture decision**:

### Option A: Truncate + Reload (What We Use)

```sql
TRUNCATE TABLE sathapana_raw.raw.customers;
INSERT INTO sathapana_raw.raw.customers SELECT * FROM source...;
```

| Pros | Cons |
|------|------|
| ✅ Simple | ❌ No history in raw zone |
| ✅ Fast | ❌ Can't recover from ETL errors |
| ✅ Always current | ❌ No audit trail in raw |

### Option B: Full History (Production Recommended)

```sql
-- Add extract metadata
INSERT INTO sathapana_raw.raw.customers
SELECT *, GETDATE() AS extract_date, @BatchID AS batch_id
FROM source...;
```

| Pros | Cons |
|------|------|
| ✅ Full audit trail | ❌ Table grows over time |
| ✅ Can recover from errors | ❌ Need archiving strategy |
| ✅ Point-in-time analysis | ❌ More storage needed |

### What Production Banks Typically Do

| Raw Zone Strategy | Retention | Use Case |
|-------------------|-----------|----------|
| **Truncate + Reload** | Latest extract only | Small banks, limited storage |
| **Full history** | 90 days - 1 year | Most production banks |
| **Full history + archive** | Indefinite | Regulated banks, compliance |

### Recommendation

For this learning project, **truncate + reload is fine**. For production, **full history is strongly recommended** because:
1. You can re-run ETL from any point
2. You have an audit trail for regulators
3. You can debug data issues by comparing extracts

---

## Q10: Why 10 Separate Databases for a Learning Project?

**Question**: Isn't 10 databases overkill for a learning/portfolio project?

### Answer

**Yes, it's intentionally over-engineered.** Here's why:

### Purpose

| Goal | How 10 Databases Helps |
|------|----------------------|
| **Show production knowledge** | Demonstrates you understand enterprise patterns |
| **Interview conversations** | Gives you stories to tell about architecture decisions |
| **Portfolio depth** | Shows you can design complex systems |
| **Learning** | Teaches cross-database ETL, security isolation, etc. |

### What You Can Simplify for a Smaller Project

If you want a lighter version, you could use **3 databases**:

```
sathapana_source     (source simulation)
sathapana_dwh        (all data: staging, DW, marts — via schemas)
sathapana_metadata   (audit, ETL logs)
```

Or even **1 database with schemas**:

```
sathapana_dwh
├── raw.*        (Layer 1)
├── staging.*    (Staging)
├── dw.*         (Layer 2)
├── dm_credit.*  (Layer 3)
├── dm_customer.* (Layer 3)
└── audit.*      (Metadata)
```

### The Tradeoff

| Approach | Complexity | Production Realism | Learning Value |
|----------|-----------|-------------------|----------------|
| 1 DB, multiple schemas | Low | Low | Medium |
| 3 DBs | Medium | Medium | High |
| 10 DBs (what we have) | High | High | Very High |

### Verdict

The 10-database approach is **appropriate for a portfolio project** that aims to demonstrate production-level architecture knowledge. It's a conversation starter in interviews: *"Why did you use 10 databases?"* → *"Let me explain the layered architecture pattern..."*

---

## Q11: Staging vs Raw Zone — Aren't They the Same Thing?

**Question**: I read on forums that staging IS the raw data. Why does this project have both a raw zone AND a staging area?

### Answer

**Both approaches are valid.** Many projects combine them into one layer. This project separates them because it follows the enterprise banking pattern.

### What Forums Often Show (Simplified)

```
Source ──► Staging (raw + cleansed) ──► DW ──► Marts
```

In this pattern, **staging IS the raw data**. It holds the exact source copy AND does cleansing in the same place. This is **valid and common** for small projects, single-team environments, and cloud ELT patterns (e.g., dbt, Snowflake).

### What This Project Does (Enterprise Pattern)

```
Source ──► Raw Zone ──► Staging ──► DW ──► Marts
           (copy)       (cleanse)
```

This **separates** the raw copy from the cleansing area. This is the **enterprise/banking pattern** used by larger organizations.

### Why Separate Them?

| Concern | Combined (Staging = Raw) | Separated (Raw + Staging) |
|---------|------------------------|---------------------------|
| **Audit** | ⚠️ Cleansed data overwrites raw | ✅ Raw preserved exactly as source |
| **Recovery** | ❌ If ETL corrupts data, raw is lost | ✅ Raw always has source copy |
| **Debugging** | ⚠️ Hard to see what source looked like | ✅ Compare raw vs staging to find issues |
| **Regulatory** | ⚠️ Auditors may want exact source copy | ✅ Raw zone = audit evidence |
| **Flexibility** | ❌ One place does two jobs | ✅ Each layer has one job |

### Real Example: Why Separation Matters

Imagine the source system sends this:

```
Source: customer_name = "John Smith"
```

But your ETL has a bug that converts it to:

```
Staging: customer_name = "JOHN SMITH"  (wrong — you uppercased it by mistake)
```

**If staging = raw (combined):**
- ❌ You've overwritten the original
- ❌ You can't recover "John Smith"
- ❌ Auditor asks: "What was the original?" → You don't know

**If raw + staging are separate:**
- ✅ Raw still has "John Smith"
- ✅ You can see the bug by comparing raw vs staging
- ✅ You can fix and reprocess from raw

### When Each Approach Is Used

**Combined (Staging = Raw) — Common In:**

| Scenario | Example |
|----------|---------|
| **Cloud ELT** | Snowflake, BigQuery — raw data lands in staging, transformations in-place |
| **dbt projects** | Staging models are the raw+cleaned layer |
| **Small teams** | One developer, simple pipeline |
| **Real-time streaming** | Kafka → staging → DW (no separate raw) |
| **Data lakes** | Raw zone is a folder in S3/ADLS, staging is another folder |

**Separated (Raw + Staging) — Common In:**

| Scenario | Example |
|----------|---------|
| **Banking/Finance** | Regulatory requirement for audit trail |
| **Healthcare** | HIPAA compliance — must preserve original data |
| **Large enterprises** | Multiple teams, complex ETL |
| **On-premises SQL Server** | Traditional DWH pattern |
| **Regulated industries** | NBC, Basel III, SOX compliance |

### Industry Perspective

| Approach | Raw Zone | Staging | Who Recommends |
|----------|----------|---------|----------------|
| **Kimball** | Optional (depends on need) | Recommended | Ralph Kimball |
| **Inmon** | Recommended (audit trail) | Recommended | Bill Inmon |
| **Data Vault** | Required (raw vault) | Required (business vault) | Dan Linstedt |
| **Data Lake** | Required (bronze layer) | Required (silver layer) | Modern data stack |

### Why This Project Separates Them

```
This project uses the SEPARATED pattern because:

1. It's a BANKING project — regulatory compliance requires audit trail
2. It demonstrates PRODUCTION patterns — not simplified learning patterns
3. It shows you understand the WHY — not just the HOW

But in your next project, you might use the COMBINED pattern if:
1. It's a small project with no regulatory requirements
2. You're using cloud ELT (dbt, Snowflake)
3. The team is small and simplicity matters
```

### Summary

| Pattern | Is It Wrong? | When to Use |
|---------|-------------|-------------|
| **Staging = Raw** (combined) | ❌ No — it's valid | Small projects, cloud ELT, no regulatory needs |
| **Raw + Staging** (separated) | ❌ No — it's also valid | Banking, regulated industries, enterprise |

**Both are correct.** The choice depends on your requirements. This project uses the separated pattern because banking regulations demand an audit trail.

---

*Last Updated: September 2026*
