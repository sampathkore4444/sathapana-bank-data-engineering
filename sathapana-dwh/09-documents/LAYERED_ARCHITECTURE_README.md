# Sathapana Bank - Enterprise Layered Architecture

## 🏦 Complete Data Warehouse Solution

This is a **production-grade** Data Warehouse implementation using the **Enterprise Layered Architecture** pattern, designed specifically for banking environments.

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 4: PRESENTATION                        │
│  (Power BI, Excel, SSRS, Custom Apps)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 3: SERVING ZONE                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │ sathapana│ │ sathapana│ │ sathapana│ │ sathapana        │  │
│  │ dm_credit│ │dm_customer│ │dm_treasury│ │ dm_compliance    │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 2: CURATED ZONE                        │
│  sathapana_dwh (Conformed Dimensions & Facts)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 1: RAW ZONE                            │
│  sathapana_raw (Exact Source Copy)                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 0: SOURCE SYSTEMS                      │
│  sathapana_source (OLTP Simulation)                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Database Inventory

| # | Database | Layer | Purpose | Schema |
|---|----------|-------|---------|--------|
| 1 | `sathapana_source` | 0 | Source system simulation | oltp |
| 2 | `sathapana_raw` | 1 | Exact source copy | raw, meta |
| 3 | `sathapana_staging` | - | Staging/landing zone | staging |
| 4 | `sathapana_dwh` | 2 | Enterprise DW | dw, audit |
| 5 | `sathapana_dm_credit` | 3 | Credit risk mart | dm |
| 6 | `sathapana_dm_customer` | 3 | Customer analytics mart | dm |
| 7 | `sathapana_dm_treasury` | 3 | Treasury mart | dm |
| 8 | `sathapana_dm_compliance` | 3 | Compliance/AML mart | dm |

**Total: 8 Databases on 1 SQL Server Instance**

---

## 📁 Project Structure

```
sathapana-dwh/
├── 00-layered-architecture/
│   └── ARCHITECTURE.md           # Architecture documentation
├── 01-architecture/
│   └── ARCHITECTURE.md           # Technical architecture
├── 02-source-systems/
│   ├── 01-create-source-database.sql
│   └── 02-create-raw-zone-database.sql
├── 03-staging/
│   └── 01-create-staging-database.sql
├── 04-data-warehouse/
│   └── 01-create-dwh-database.sql
├── 05-data-marts/
│   ├── credit/
│   │   └── 01-create-credit-mart-database.sql
│   ├── customer/
│   │   └── 01-create-customer-mart-database.sql
│   ├── treasury/
│   │   └── 01-create-treasury-mart-database.sql
│   └── compliance/
│       └── 01-create-compliance-mart-database.sql
├── 06-etl/
│   ├── 01-extract-procedures.sql
│   └── 02-transform-load-procedures.sql
├── 07-data-quality/
│   └── 01-data-quality-framework.sql
├── 08-monitoring/
│   └── 01-monitoring-framework.sql
├── 09-documents/
│   ├── README.md
│   ├── QUICK_REFERENCE.md
│   ├── LAYERED_ARCHITECTURE_README.md
│   └── DATABASE_ARCHITECTURE_OPTIONS.md
└── 10-samples/
    ├── 01-run-full-pipeline.sql
    └── 02-run-layered-pipeline.sql
```

---

## 🚀 Quick Start

### Prerequisites
- SQL Server 2019 or later
- 1GB free disk space
- Sysadmin or dbcreator permissions

### Step-by-Step Installation

#### 1️⃣ Create Source Database (Layer 0)
```sql
-- Execute: 02-source-systems/01-create-source-database.sql
```

#### 2️⃣ Create Raw Zone (Layer 1)
```sql
-- Execute: 02-source-systems/02-create-raw-zone-database.sql
```

#### 3️⃣ Create Staging Database
```sql
-- Execute: 03-staging/01-create-staging-database.sql
```

#### 4️⃣ Create Curated Zone (Layer 2)
```sql
-- Execute: 04-data-warehouse/01-create-dwh-database.sql
```

#### 5️⃣ Create Data Marts (Layer 3)
```sql
-- Execute each:
-- 05-data-marts/credit/01-create-credit-mart-database.sql
-- 05-data-marts/customer/01-create-customer-mart-database.sql
-- 05-data-marts/treasury/01-create-treasury-mart-database.sql
-- 05-data-marts/compliance/01-create-compliance-mart-database.sql
```

#### 6️⃣ Create ETL Procedures
```sql
-- Execute:
-- 06-etl/01-extract-procedures.sql
-- 06-etl/02-transform-load-procedures.sql
```

#### 7️⃣ Create Quality & Monitoring
```sql
-- Execute:
-- 07-data-quality/01-data-quality-framework.sql
-- 08-monitoring/01-monitoring-framework.sql
```

#### 8️⃣ Run Complete Pipeline
```sql
-- Execute: 10-samples/02-run-layered-pipeline.sql
```

---

## 📈 Sample Queries by Data Mart

### Credit Risk Mart
```sql
-- Connect to: sathapana_dm_credit
SELECT * FROM dm.vw_credit_risk_summary;
SELECT * FROM dm.vw_npl_trend;
SELECT * FROM dm.vw_branch_risk_ranking;
```

### Customer Analytics Mart
```sql
-- Connect to: sathapana_dm_customer
SELECT * FROM dm.vw_customer_360;
SELECT * FROM dm.vw_customer_segmentation;
SELECT * FROM dm.vw_top_customers;
```

### Treasury Mart
```sql
-- Connect to: sathapana_dm_treasury
SELECT * FROM dm.vw_fx_performance;
SELECT * FROM dm.vw_deposit_mobilization;
SELECT * FROM dm.vw_liquidity_monitoring;
```

### Compliance Mart
```sql
-- Connect to: sathapana_dm_compliance
SELECT * FROM dm.vw_aml_alert_summary;
SELECT * FROM dm.vw_transaction_monitoring;
SELECT * FROM dm.vw_pep_monitoring;
```

---

## 🔐 Security Model

| Database | Owner | Access |
|----------|-------|--------|
| sathapana_raw | DBA | ETL Service, DBA |
| sathapana_dwh | DBA | ETL Service, BI Team |
| sathapana_dm_credit | Credit Risk | Credit Analysts |
| sathapana_dm_customer | Marketing | BI Analysts |
| sathapana_dm_treasury | Treasury | Treasury Analysts |
| sathapana_dm_compliance | Compliance | AML Officers |

---

## 📊 Data Flow

```
Daily Pipeline (2:00 AM - 6:00 AM)
═══════════════════════════════════════════════════════════

2:00 AM │ EXTRACT
        │ Source → Raw Zone
        ▼
3:00 AM │ STAGE
        │ Raw → Staging
        ▼
4:00 AM │ TRANSFORM
        │ Staging → Curated Zone (DW)
        ▼
5:00 AM │ SERVE
        │ Curated Zone → Data Marts
        ▼
6:00 AM │ VALIDATE
        │ Quality checks, monitoring
        ════════════════════════════════════════════════════
```

---

## 🎯 Key Benefits

| Benefit | Description |
|---------|-------------|
| **Data Lineage** | Complete traceability from source to report |
| **Audit Trail** | Raw zone preserves exact source data |
| **Security** | Department-level database isolation |
| **Performance** | Each mart optimized for its use case |
| **Maintainability** | Clear separation of concerns |
| **Scalability** | Can split across servers if needed |
| **Compliance** | Meets NBC and Basel III requirements |

---

## 📚 Documentation

- `00-layered-architecture/ARCHITECTURE.md` - Full architecture guide
- `09-documents/README.md` - Project overview
- `09-documents/QUICK_REFERENCE.md` - Quick reference card
- `09-documents/DATABASE_ARCHITECTURE_OPTIONS.md` - Architecture options

---

## 🛠️ Maintenance

### Daily
```sql
-- Check data freshness
SELECT * FROM sathapana_dwh.audit.vw_data_freshness;

-- Monitor ETL jobs
SELECT TOP 10 * FROM sathapana_dwh.audit.vw_etl_job_history;
```

### Weekly
```sql
-- Run maintenance
EXEC sathapana_dwh.audit.usp_PerformMaintenance;

-- Track data growth
EXEC sathapana_dwh.audit.usp_TrackDataGrowth;
```

---

## 📞 Support

For issues or questions:
- Check documentation in `09-documents/`
- Review error logs in `sathapana_dwh.audit.etl_log`
- Contact DWH Development Team

---

**Built for Sathapana Bank** 🏦
**Architecture Pattern: Enterprise Layered Pattern** ⭐
**Total Databases: 8 (on 1 SQL Server Instance)**
