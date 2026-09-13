# Sathapana Bank - Enterprise Layered Architecture

## Overview

This document describes the **Enterprise Layered Architecture** pattern implemented for Sathapana Bank's Data Warehouse. This is the industry-standard approach for production banking environments.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           LAYER 4: PRESENTATION                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐   │
│  │   Power BI   │ │    Excel     │ │    SSRS      │ │   Custom Applications│   │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 3: SERVING ZONE (Data Marts)                          │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐   │
│  │ sathapana_     │ │ sathapana_     │ │ sathapana_     │ │ sathapana_     │   │
│  │ dm_credit      │ │ dm_customer    │ │ dm_treasury    │ │ dm_compliance  │   │
│  │                │ │                │ │                │ │                │   │
│  │ Credit Risk    │ │ Customer       │ │ Treasury       │ │ AML/Compliance │   │
│  │ Analytics      │ │ Analytics      │ │ Analytics      │ │ Analytics      │   │
│  └────────────────┘ └────────────────┘ └────────────────┘ └────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 2: CURATED ZONE (Enterprise DW)                       │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        sathapana_dwh                                    │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │  dw schema (Conformed Dimensions & Facts)                       │   │   │
│  │  │  • DimDate      • DimCustomer      • FactTransactions          │   │   │
│  │  │  • DimBranch    • DimAccount        • FactLoanPortfolio         │   │   │
│  │  │  • DimProduct   • DimEmployee       • FactDepositSnapshot       │   │   │
│  │  │  • DimCurrency  • DimChannel        • FactAccountDailySnapshot  │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │  audit schema (Metadata & Monitoring)                           │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 1: RAW ZONE (Source Copy)                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        sathapana_raw                                    │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐   │   │
│  │  │  Exact copy of source system data (no transformations)          │   │   │
│  │  │  • oltp schema (all source tables)                              │   │   │
│  │  │  • Extract metadata (batch tracking)                            │   │   │
│  │  └─────────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    LAYER 0: SOURCE SYSTEMS                                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐   │
│  │ Core Banking │ │   Treasury   │ │    Credit    │ │ External (NBC, SWIFT)│   │
│  │   System     │ │   System     │ │   System     │ │                      │   │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Database Inventory

| Layer | Database | Schema | Purpose | Tables |
|-------|----------|--------|---------|--------|
| **Layer 0** | sathapana_source | oltp | Source system simulation | 15+ tables |
| **Layer 1** | sathapana_raw | raw | Exact source copy | 15+ tables |
| **Layer 2** | sathapana_dwh | dw, audit | Enterprise DW | 8 dimensions, 6 facts |
| **Layer 3** | sathapana_dm_credit | dm | Credit risk mart | Views |
| **Layer 3** | sathapana_dm_customer | dm | Customer analytics mart | Views |
| **Layer 3** | sathapana_dm_treasury | dm | Treasury mart | Views |
| **Layer 3** | sathapana_dm_compliance | dm | Compliance mart | Views |

**Total: 7 Databases on 1 SQL Server Instance**

---

## Layer Descriptions

### Layer 0: Source Systems
**Database**: `sathapana_source`

Purpose: Operational systems that generate business data
- Core Banking System
- Treasury Management System
- Credit origination system
- External feeds (NBC reporting, SWIFT)

### Layer 1: Raw Zone
**Database**: `sathapana_raw`

Purpose: **Exact copy** of source data with no transformations
- Preserves source data as-is for audit trail
- Historical reference point
- Source system recovery capability
- Data lineage starting point

Key Characteristics:
- No business rules applied
- No data cleansing
- No surrogate keys
- Full history retention
- Batch extract metadata

### Layer 2: Curated Zone (Enterprise DW)
**Database**: `sathapana_dwh`

Purpose: **Conformed, integrated enterprise data**
- Single version of truth
- Surrogate keys
- SCD processing (Type 1 & 2)
- Business rule application
- Data quality enforcement

Key Characteristics:
- Dimensional model (Star Schema)
- Conformed dimensions
- Integrated facts
- Historical tracking (SCD)
- Audit metadata

### Layer 3: Serving Zone (Data Marts)
**Databases**: `sathapana_dm_credit`, `sathapana_dm_customer`, `sathapana_dm_treasury`, `sathapana_dm_compliance`

Purpose: **Department-specific analytical views**
- Optimized for specific business functions
- Simplified data models
- Pre-calculated metrics
- Security boundaries

Key Characteristics:
- Business-area focused
- Simplified queries
- Role-based access
- Performance optimized
- Independent scaling

### Layer 4: Presentation
**Tools**: Power BI, Excel, SSRS, Custom Apps

Purpose: **Data consumption and visualization**
- Interactive dashboards
- Ad-hoc reporting
- Regulatory reports
- Mobile access

---

## Data Flow

```
Daily ETL Pipeline (2:00 AM - 6:00 AM)
═══════════════════════════════════════════════════════════════════

2:00 AM │ EXTRACT
        │ Source → Raw Zone
        │ (Full/incremental copy)
        ▼
3:00 AM │ STAGE
        │ Raw → Staging (in sathapana_dwh)
        │ (Cleansing, validation)
        ▼
4:00 AM │ TRANSFORM
        │ Staging → Curated Zone (DW)
        │ (SCD, surrogate keys, business rules)
        ▼
5:00 AM │ SERVE
        │ Curated Zone → Serving Zone (Data Marts)
        │ (Department-specific views)
        ▼
6:00 AM │ VALIDATE
        │ Quality checks, reconciliation
        │ Monitoring, alerts
        ════════════════════════════════════════════════════════════
```

---

## Security Architecture

### Database-Level Security

| Database | Owner | Access |
|----------|-------|--------|
| sathapana_raw | DBA Team | ETL Service, DBA |
| sathapana_dwh | DBA Team | ETL Service, BI Team, Compliance |
| sathapana_dm_credit | Credit Risk Team | Credit Analysts, Risk Managers |
| sathapana_dm_customer | Marketing Team | BI Analysts, Marketing |
| sathapana_dm_treasury | Treasury Team | Treasury Analysts, ALM |
| sathapana_dm_compliance | Compliance Team | AML Officers, Auditors |

### Row-Level Security (Optional)
```sql
-- Example: Branch-level security in credit mart
CREATE FUNCTION dbo.fn_branch_security(@branch_key INT)
RETURNS TABLE
AS
RETURN (
    SELECT 1 AS has_access
    WHERE @branch_key IN (SELECT branch_key FROM user_branch_access WHERE user_name = SYSTEM_USER)
);
```

---

## Backup Strategy

| Database | Backup Type | Frequency | Retention |
|----------|-------------|-----------|-----------|
| sathapana_raw | Full + Log | Daily + 15min | 30 days |
| sathapana_dwh | Full + Log | Daily + 15min | 90 days |
| sathapana_dm_* | Full + Log | Daily + 15min | 60 days |

---

## Scaling Considerations

### Vertical Scaling (Same Server)
- Add more CPU/RAM to handle larger data volumes
- Works up to ~2TB total data

### Horizontal Scaling (Separate Servers)
For banks with > 2TB data:
```
Server 1: sathapana_raw, sathapana_staging
Server 2: sathapana_dwh (core DW)
Server 3: sathapana_dm_* (all data marts)
```

### Cloud Scaling (Azure/AWS)
```
Azure SQL Database (Serverless):
- sathapana_dwh → Business Critical tier
- sathapana_dm_* → General Purpose tier
```

---

## Benefits of This Architecture

| Benefit | Description |
|---------|-------------|
| **Data Lineage** | Complete traceability from source to report |
| **Audit Trail** | Raw zone preserves exact source data |
| **Security** | Department-level database isolation |
| **Performance** | Each mart optimized for its use case |
| **Maintainability** | Clear separation of concerns |
| **Scalability** | Can split across servers if needed |
| **Disaster Recovery** | Independent backup/restore per layer |
| **Regulatory Compliance** | Meets NBC and Basel III requirements |

---

## Implementation Checklist

- [x] Layer 0: Source system setup
- [x] Layer 1: Raw zone database
- [x] Layer 2: Curated zone (enterprise DW)
- [x] Layer 3: Credit risk mart
- [x] Layer 3: Customer analytics mart
- [x] Layer 3: Treasury mart
- [x] Layer 3: Compliance mart
- [x] ETL procedures (cross-database)
- [x] Data quality framework
- [x] Monitoring framework
- [x] Documentation

---

## Related Documents

- `01-architecture/ARCHITECTURE.md` - Detailed technical architecture
- `09-documents/README.md` - Project overview
- `09-documents/QUICK_REFERENCE.md` - Quick reference card
