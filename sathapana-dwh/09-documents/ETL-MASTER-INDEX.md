# 📚 ETL Master Index - Sathapana Bank Data Engineering

## Overview

This is the **master index** for all ETL-related documentation in the Sathapana Bank Data Engineering project. Use this guide to navigate through the complete ETL learning path and reference materials.

---

## 🗺️ Documentation Map

```
┌─────────────────────────────────────────────────────────────────┐
│                    ETL DOCUMENTATION ARCHITECTURE                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  📖 LEARNING PATH (Start Here)                                  │
│  ├── 06-etl/03-ETL-LEARNING-GUIDE.md                           │
│  │   └── Complete ETL overview, concepts, and architecture      │
│  │                                                               │
│  ├── 06-etl/04-SCD-TYPE2-HANDS-ON-EXERCISE.md                  │
│  │   └── Step-by-step SCD Type 2 implementation                 │
│  │                                                               │
│  ├── 06-etl/06-BUILD-ETL-PIPELINE-FROM-SCRATCH.md              │
│  │   └── Complete guide to building an ETL pipeline             │
│  │                                                               │
│  📊 SPECIALIZED TOPICS                                          │
│  ├── 21-cdc/05-CDC-VS-INCREMENTAL-LOADS.md                     │
│  │   └── Change Data Capture vs Incremental Loads               │
│  │                                                               │
│  ├── 07-data-quality/07-DATA-QUALITY-CHECKS.md                  │
│  │   └── Data quality validation and profiling                  │
│  │                                                               │
│  ├── 05-data-marts/08-DATA-MARTS.md                             │
│  │   └── Building business-specific data marts                  │
│  │                                                               │
│  🏗️ OPERATIONS                                                  │
│  ├── 08-monitoring/09-ETL-MONITORING-AND-ALERTING.md            │
│  │   └── Monitoring, alerting, and email notifications          │
│  │                                                               │
│  ├── 20-testing/10-ETL-TESTING.md                               │
│  │   └── Unit testing, integration testing, automation          │
│  │                                                               │
│  ├── 09-documents/11-DOCUMENTATION-TEMPLATES.md                 │
│  │   └── Standardized documentation templates                   │
│  │                                                               │
│  🏦 REAL-WORLD APPLICATIONS                                      │
│  └── 06-etl/12-REAL-WORLD-BANKING-SCENARIOS.md                  │
│      └── Banking-specific ETL scenarios                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 Quick Reference by Topic

### 1. ETL Fundamentals

| Document | Location | Description |
|----------|----------|-------------|
| ETL Learning Guide | `06-etl/03-ETL-LEARNING-GUIDE.md` | Complete ETL overview, pipeline architecture, extract/transform/load concepts |
| Build ETL Pipeline | `06-etl/06-BUILD-ETL-PIPELINE-FROM-SCRATCH.md` | Step-by-step guide to building a complete ETL pipeline |

**Start here if:** You're new to ETL or need a refresher on concepts.

---

### 2. Slowly Changing Dimensions (SCD)

| Document | Location | Description |
|----------|----------|-------------|
| SCD Type 2 Exercise | `06-etl/04-SCD-TYPE2-HANDS-ON-EXERCISE.md` | Hands-on exercise with sample data and verification queries |

**Start here if:** You need to implement historical tracking for dimension tables.

---

### 3. Change Data Capture (CDC)

| Document | Location | Description |
|----------|----------|-------------|
| CDC vs Incremental Loads | `21-cdc/05-CDC-VS-INCREMENTAL-LOADS.md` | Comparison of CDC and incremental load approaches |
| CDC Setup | `21-cdc/01-change-data-capture-setup.sql` | SQL Server CDC configuration scripts |
| CDC Documentation | `21-cdc/CDC_DOCUMENTATION.md` | Complete CDC documentation |

**Start here if:** You need real-time data capture or need to capture deletes.

---

### 4. Data Quality

| Document | Location | Description |
|----------|----------|-------------|
| Data Quality Checks | `07-data-quality/07-DATA-QUALITY-CHECKS.md` | Quality validation, profiling, and rules engine |
| Quality Framework | `07-data-quality/01-data-quality-framework.sql` | Quality rules and check procedures |

**Start here if:** You need to ensure data accuracy and completeness.

---

### 5. Data Marts

| Document | Location | Description |
|----------|----------|-------------|
| Data Marts Guide | `05-data-marts/08-DATA-MARTS.md` | Building Credit Risk, Customer Analytics, and Treasury marts |
| Create Data Marts | `05-data-marts/01-create-data-marts.sql` | SQL scripts for mart creation |

**Start here if:** You need business-specific views of the data warehouse.

---

### 6. Monitoring & Alerting

| Document | Location | Description |
|----------|----------|-------------|
| Monitoring Guide | `08-monitoring/09-ETL-MONITORING-AND-ALERTING.md` | Dashboard, alerts, email notifications |
| Monitoring Framework | `08-monitoring/01-monitoring-framework.sql` | Monitoring views and procedures |

**Start here if:** You need to monitor ETL health and get notified of issues.

---

### 7. Testing

| Document | Location | Description |
|----------|----------|-------------|
| ETL Testing Guide | `20-testing/10-ETL-TESTING.md` | Unit tests, integration tests, test automation |
| Testing Framework | `20-testing/01-testing-framework.sql` | Test infrastructure setup |

**Start here if:** You need to validate ETL procedures work correctly.

---

### 8. Documentation

| Document | Location | Description |
|----------|----------|-------------|
| Documentation Templates | `09-documents/11-DOCUMENTATION-TEMPLATES.md` | Standardized templates for ETL documentation |
| Data Lineage | `09-documents/DATA_LINEAGE.md` | Data flow documentation |
| Glossary | `09-documents/GLOSSARY.md` | Business terminology definitions |

**Start here if:** You need to document your ETL processes.

---

### 9. Real-World Scenarios

| Document | Location | Description |
|----------|----------|-------------|
| Banking Scenarios | `06-etl/12-REAL-WORLD-BANKING-SCENARIOS.md` | Daily transactions, loan portfolio, KYC, AML, regulatory reporting |

**Start here if:** You want banking-specific ETL examples.

---

### 10. Security & Compliance

| Document | Location | Description |
|----------|----------|-------------|
| Security Framework | `15-security/SECURITY-FRAMEWORK-GUIDE.md` | RBAC, encryption, data masking, audit logging |
| Data Governance | `09-documents/DATA-GOVERNANCE-GUIDE.md` | Data ownership, quality standards, lineage, retention |
| Regulatory Reports | `18-regulatory-reports/REGULATORY-REPORTING-GUIDE.md` | NBC compliance, CAR, large exposures, liquidity |

**Start here if:** You need to implement security or compliance features.

---

### 11. Operations & Performance

| Document | Location | Description |
|----------|----------|-------------|
| Performance Tuning | `19-performance/PERFORMANCE-TUNING-GUIDE.md` | Indexes, queries, partitioning, maintenance |
| Partitioning Strategy | `16-partitioning/PARTITIONING-STRATEGY-GUIDE.md` | Table partitioning for large fact tables |
| Disaster Recovery | `17-disaster-recovery/DISASTER-RECOVERY-GUIDE.md` | Backup, restore, HA strategies |

**Start here if:** You need to optimize performance or ensure DR.

---

### 12. Reporting & Visualization

| Document | Location | Description |
|----------|----------|-------------|
| Power BI Integration | `13-powerbi/POWERBI-INTEGRATION-GUIDE.md` | Connection, data model, DAX measures, RLS |
| Report Distribution | `22-report-distribution/REPORT-DISTRIBUTION-GUIDE.md` | Email distribution, scheduling, archiving |

**Start here if:** You need to create reports or distribute them.

---

### 13. Additional Data Marts

| Document | Location | Description |
|----------|----------|-------------|
| ALM Mart | `14-additional-marts/alm/ALM-MART-GUIDE.md` | Liquidity, interest rate risk, funding analysis |
| Operations Mart | `14-additional-marts/operations/OPERATIONS-MART-GUIDE.md` | Branch performance, channel analytics |

**Start here if:** You need specialized analytics beyond core banking.

---

## 🎓 Recommended Learning Path

### Beginner Path (New to ETL)
1. `06-etl/03-ETL-LEARNING-GUIDE.md` - Learn ETL fundamentals
2. `06-etl/04-SCD-TYPE2-HANDS-ON-EXERCISE.md` - Practice SCD Type 2
3. `06-etl/06-BUILD-ETL-PIPELINE-FROM-SCRATCH.md` - Build your first pipeline

### Intermediate Path (Building Features)
1. `07-data-quality/07-DATA-QUALITY-CHECKS.md` - Add data quality
2. `05-data-marts/08-DATA-MARTS.md` - Create data marts
3. `08-monitoring/09-ETL-MONITORING-AND-ALERTING.md` - Add monitoring

### Advanced Path (Production Readiness)
1. `21-cdc/05-CDC-VS-INCREMENTAL-LOADS.md` - Implement CDC
2. `20-testing/10-ETL-TESTING.md` - Add testing
3. `06-etl/12-REAL-WORLD-BANKING-SCENARIOS.md` - Apply to real scenarios

---

## 📁 Complete File Listing

### 06-etl/ (ETL Core)
| File | Type | Description |
|------|------|-------------|
| `01-extract-procedures.sql` | SQL | Extract stored procedures |
| `02-transform-load-procedures.sql` | SQL | Transform and load procedures |
| `03-ETL-LEARNING-GUIDE.md` | MD | Complete ETL learning guide |
| `04-SCD-TYPE2-HANDS-ON-EXERCISE.md` | MD | SCD Type 2 hands-on exercise |
| `06-BUILD-ETL-PIPELINE-FROM-SCRATCH.md` | MD | Build ETL pipeline guide |
| `12-REAL-WORLD-BANKING-SCENARIOS.md` | MD | Banking ETL scenarios |
| `README.md` | MD | ETL directory overview |

### 21-cdc/ (Change Data Capture)
| File | Type | Description |
|------|------|-------------|
| `01-change-data-capture-setup.sql` | SQL | CDC configuration scripts |
| `05-CDC-VS-INCREMENTAL-LOADS.md` | MD | CDC vs incremental loads comparison |
| `CDC_DOCUMENTATION.md` | MD | Complete CDC documentation |

### 07-data-quality/ (Data Quality)
| File | Type | Description |
|------|------|-------------|
| `01-data-quality-framework.sql` | SQL | Quality rules and procedures |
| `07-DATA-QUALITY-CHECKS.md` | MD | Data quality checks guide |
| `README.md` | MD | Data quality overview |

### 05-data-marts/ (Data Marts)
| File | Type | Description |
|------|------|-------------|
| `01-create-data-marts.sql` | SQL | Create all data marts |
| `08-DATA-MARTS.md` | MD | Data marts implementation guide |
| `README.md` | MD | Data marts overview |

### 08-monitoring/ (Monitoring)
| File | Type | Description |
|------|------|-------------|
| `01-monitoring-framework.sql` | SQL | Monitoring views and procedures |
| `09-ETL-MONITORING-AND-ALERTING.md` | MD | Monitoring and alerting guide |
| `README.md` | MD | Monitoring overview |

### 20-testing/ (Testing)
| File | Type | Description |
|------|------|-------------|
| `01-testing-framework.sql` | SQL | Test infrastructure |
| `10-ETL-TESTING.md` | MD | ETL testing guide |

### 09-documents/ (Documentation)
| File | Type | Description |
|------|------|-------------|
| `11-DOCUMENTATION-TEMPLATES.md` | MD | Documentation templates |
| `ETL-MASTER-INDEX.md` | MD | This master index |
| `README.md` | MD | Project overview |

---

## 🔗 Cross-References

| Topic | Primary Guide | SQL Scripts | Supporting Docs |
|-------|---------------|-------------|-----------------|
| ETL Basics | `03-ETL-LEARNING-GUIDE.md` | `01-extract-procedures.sql`, `02-transform-load-procedures.sql` | `06-BUILD-ETL-PIPELINE-FROM-SCRATCH.md` |
| SCD Type 2 | `04-SCD-TYPE2-HANDS-ON-EXERCISE.md` | `02-transform-load-procedures.sql` | `03-ETL-LEARNING-GUIDE.md` |
| CDC | `05-CDC-VS-INCREMENTAL-LOADS.md` | `01-change-data-capture-setup.sql` | `CDC_DOCUMENTATION.md` |
| Data Quality | `07-DATA-QUALITY-CHECKS.md` | `01-data-quality-framework.sql` | `07-data-quality/README.md` |
| Data Marts | `08-DATA-MARTS.md` | `01-create-data-marts.sql` | `05-data-marts/README.md` |
| Monitoring | `09-ETL-MONITORING-AND-ALERTING.md` | `01-monitoring-framework.sql` | `08-monitoring/README.md` |
| Testing | `10-ETL-TESTING.md` | `01-testing-framework.sql` | - |
| Banking Scenarios | `12-REAL-WORLD-BANKING-SCENARIOS.md` | Various | `03-ETL-LEARNING-GUIDE.md` |

---

## 📞 Support

For questions about specific topics:
- **ETL Basics:** Start with `03-ETL-LEARNING-GUIDE.md`
- **Implementation:** Use `06-BUILD-ETL-PIPELINE-FROM-SCRATCH.md`
- **Banking Examples:** See `12-REAL-WORLD-BANKING-SCENARIOS.md`
- **Troubleshooting:** Check `09-documents/TROUBLESHOOTING.md`

---

*Last Updated: September 2024*
*Sathapana Bank Data Engineering Project*
