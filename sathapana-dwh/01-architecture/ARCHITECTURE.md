# Sathapana Bank Data Warehouse Architecture

## Executive Summary

This document outlines the complete Data Warehouse architecture for Sathapana Bank, designed to support enterprise-wide analytics, regulatory reporting, and business intelligence needs.

## 1. Business Context

### About Sathapana Bank
- **Type**: Commercial Bank operating in Cambodia
- **Services**: Retail banking, corporate banking, treasury, microfinance
- **Regulatory Requirements**: National Bank of Cambodia (NBC) reporting, AML/CFT compliance
- **Key Stakeholders**: Treasury, Risk Management, Compliance, Retail Banking, Corporate Banking, Executive Management

### Business Requirements
1. **Regulatory Reporting**: Daily, weekly, monthly, quarterly, and annual reports to NBC
2. **Risk Management**: Credit risk, market risk, liquidity risk analytics
3. **Customer Analytics**: 360-degree customer view, segmentation, profitability
4. **Operational Analytics**: Transaction monitoring, branch performance
5. **Financial Analytics**: P&L, balance sheet, cost allocation
6. **AML/CFT**: Suspicious transaction reporting, watchlist screening

## 2. Architecture Overview

### 2.1 Layered Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │  Power BI │ │  Excel   │ │  Custom  │ │  Regulatory      │  │
│  │  Reports  │ │  Reports │ │  Apps    │ │  Reports (NBC)   │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    DATA MARTS LAYER                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │ Credit   │ │ Customer │ │ Treasury │ │  Compliance/     │  │
│  │ Risk DM  │ │ Analytics│ │   DM     │ │  AML DM          │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    ENTERPRISE DATA WAREHOUSE                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Dimension Tables  │  Fact Tables  │  Bridge Tables      │  │
│  └──────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    STAGING AREA                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Cleansing  │  Conforming  │  Integration  │  History    │  │
│  └──────────────────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    ETL / ELT LAYER                              │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │  Extract │ │ Transform│ │  Load    │ │  Orchestration   │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    SOURCE SYSTEMS                               │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │  Core    │ │  Treasury│ │  Credit  │ │  External        │  │
│  │  Banking │ │  System  │ │  System  │ │  (NBC, SWIFT)    │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Database Architecture

| Database | Purpose | Schema | Retention |
|----------|---------|--------|-----------|
| `sathapana_source` | OLTP source system simulation | dbo | N/A (source) |
| `sathapana_staging` | Staging/landing zone | staging | 90 days |
| `sathapana_dwh` | Enterprise data warehouse | dw | 7 years |
| `sathapana_dm_credit` | Credit risk data mart | dm | 5 years |
| `sathapana_dm_customer` | Customer analytics data mart | dm | 5 years |
| `sathapana_dm_treasury` | Treasury data mart | dm | 5 years |
| `sathapana_dm_compliance` | Compliance/AML data mart | dm | 7 years |
| `sathapana_metadata` | ETL metadata and logging | meta | 2 years |

## 3. Data Model Design

### 3.1 Conformed Dimensions

| Dimension | Grain | Key Attributes |
|-----------|-------|----------------|
| DimCustomer | One row per customer | CustomerKey, CustomerID, Name, Type, Segment, Branch, Status, KYC_date |
| DimAccount | One row per account | AccountKey, AccountID, CustomerKey, ProductKey, BranchKey, Type, Currency, OpenDate, Status |
| DimProduct | One row per product | ProductKey, ProductCode, ProductName, Category, SubCategory, GL_Account |
| DimBranch | One row per branch | BranchKey, BranchCode, BranchName, Region, Province, District, Type |
| DimDate | One row per date | DateKey, FullDate, Day, Month, Quarter, Year, FiscalYear, IsBusinessDay |
| DimCurrency | One row per currency | CurrencyKey, CurrencyCode, CurrencyName, ExchangeRate, RateDate |
| DimEmployee | One row per employee | EmployeeKey, EmployeeID, Name, Title, BranchKey, Department |
| DimGLAccount | One row per GL account | GLAccountKey, GLAccountCode, AccountName, AccountType, AccountLevel |

### 3.2 Fact Tables

| Fact Table | Grain | Measures |
|------------|-------|----------|
| FactTransactions | One row per transaction | Amount, RunningBalance, Fee, Tax, ExchangeAmount |
| FactAccountDailySnapshot | One row per account per day | OpeningBalance, ClosingBalance, TotalDebits, TotalCredits, TransactionCount |
| FactGLDailyBalance | One row per GL account per day | DebitAmount, CreditAmount, Balance |
| FactLoanApplications | One row per application | ApplicationAmount, ApprovedAmount, ProcessingFee |
| FactLoanPortfolio | One row per loan per month | OutstandingPrincipal, AccruedInterest, ProvisionAmount, DaysPastDue |
| FactDeposits | One row per deposit per month | Balance, InterestEarned, AverageBalance |
| FactFXTransactions | One row per FX deal | BuyAmount, SellAmount, Spread, Profit |
| FactChequeProcessing | One row per cheque | FaceValue, Status, ProcessingTime |
| FactATMTransactions | One row per ATM transaction | Amount, Fee, Channel |
| FactMobileTransactions | One row per mobile transaction | Amount, Fee, Channel |

### 3.3 Slowly Changing Dimensions (SCD)

| Dimension | SCD Type | Tracked Changes |
|-----------|----------|-----------------|
| DimCustomer | Type 2 | Name, Address, Phone, Email, Segment, Status |
| DimAccount | Type 2 | Status, Product, Branch, Limit |
| DimEmployee | Type 2 | Title, Branch, Department, Status |
| DimProduct | Type 1 | Name, Category (overwrite) |
| DimBranch | Type 1 | Name, Contact (overwrite) |

## 4. ETL Architecture

### 4.1 ETL Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ETL PIPELINE                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. EXTRACT (Daily 02:00 AM)                                        │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐                  │
│  │ Core    │ │ Treasury│ │ Credit  │ │ External│                   │
│  │ Banking │ │ System  │ │ System  │ │ Data    │                   │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘                  │
│       │           │           │           │                         │
│       ▼           ▼           ▼           ▼                         │
│  2. STAGE (Daily 03:00 AM)                                          │
│  ┌─────────────────────────────────────────────────┐               │
│  │              STAGING DATABASE                    │               │
│  │  - Data validation                              │               │
│  │  - Data cleansing                               │               │
│  │  - Data type conversions                        │               │
│  │  - Duplicate detection                          │               │
│  └────────────────────┬────────────────────────────┘               │
│                       │                                             │
│                       ▼                                             │
│  3. TRANSFORM (Daily 04:00 AM)                                      │
│  ┌─────────────────────────────────────────────────┐               │
│  │              TRANSFORMATION                      │               │
│  │  - Surrogate key generation                     │               │
│  │  - SCD processing (Type 1 & 2)                  │               │
│  │  - Business rule application                    │               │
│  │  - Data aggregation                             │               │
│  │  - Currency conversion                          │               │
│  └────────────────────┬────────────────────────────┘               │
│                       │                                             │
│                       ▼                                             │
│  4. LOAD (Daily 05:00 AM)                                           │
│  ┌─────────────────────────────────────────────────┐               │
│  │              DATA WAREHOUSE                      │               │
│  │  - Dimension loads (SCD)                        │               │
│  │  - Fact loads (incremental)                     │               │
│  │  - Index maintenance                            │               │
│  │  - Statistics update                            │               │
│  └────────────────────┬────────────────────────────┘               │
│                       │                                             │
│                       ▼                                             │
│  5. POST-LOAD (Daily 06:00 AM)                                      │
│  ┌─────────────────────────────────────────────────┐               │
│  │              DATA MARTS & REPORTS                │               │
│  │  - Data mart refresh                            │               │
│  │  - Materialized view refresh                    │               │
│  │  - Report distribution                          │               │
│  │  - Data quality checks                          │               │
│  └─────────────────────────────────────────────────┘               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 ETL Schedule

| Job | Frequency | Start Time | Duration (Est.) | Priority |
|-----|-----------|------------|-----------------|----------|
| Extract_Dimensions | Daily | 02:00 AM | 15 min | High |
| Extract_Facts | Daily | 02:15 AM | 45 min | High |
| Stage_Dimensions | Daily | 03:00 AM | 20 min | High |
| Stage_Facts | Daily | 03:20 AM | 40 min | High |
| Transform_Dimensions | Daily | 04:00 AM | 30 min | High |
| Transform_Facts | Daily | 04:30 AM | 60 min | High |
| Load_Dimensions | Daily | 05:00 AM | 20 min | High |
| Load_Facts | Daily | 05:20 AM | 40 min | High |
| Load_DataMarts | Daily | 06:00 AM | 30 min | Medium |
| DataQuality_Checks | Daily | 06:30 AM | 15 min | High |
| Regulatory_Reports | Daily | 07:00 AM | 30 min | Critical |
| Weekly_Aggregations | Weekly (Sun) | 02:00 AM | 60 min | Medium |
| Monthly_Closings | Monthly (1st) | 02:00 AM | 120 min | Critical |

## 5. Data Quality Framework

### 5.1 Quality Dimensions

| Dimension | Description | Metrics |
|-----------|-------------|---------|
| Completeness | All required data present | NULL%, Missing records |
| Accuracy | Data matches real-world | Validation rule pass rate |
| Consistency | Data agrees across systems | Cross-system reconciliation |
| Timeliness | Data available when needed | Latency, Freshness |
| Uniqueness | No unintended duplicates | Duplicate rate |
| Validity | Data conforms to rules | Business rule pass rate |

### 5.2 Quality Rules

1. **Referential Integrity**: All foreign keys must have matching dimension records
2. **Balance Checks**: Debits must equal Credits for GL accounts
3. **Amount Validation**: Transaction amounts must be within reasonable ranges
4. **Date Validation**: Dates must be valid and within expected ranges
5. **Currency Validation**: Exchange rates must be within market ranges
6. **Duplicate Detection**: No duplicate transactions allowed
7. **Freshness Check**: Source data must be updated within expected timeframes

## 6. Security Architecture

### 6.1 Role-Based Access Control

| Role | Databases | Permissions |
|------|-----------|-------------|
| DWH_Admin | All | Full control |
| ETL_Service | All | Read/Write (ETL schemas) |
| BI_Analyst | DW, DMs | Read only |
| Data_Steward | Source, Staging | Read/Write |
| Compliance | DW, Compliance DM | Read + Export |
| Auditor | All | Read only + Audit logs |

### 6.2 Data Classification

| Classification | Description | Examples |
|----------------|-------------|----------|
| Public | Non-sensitive | Branch names, product names |
| Internal | Business sensitive | Transaction amounts, balances |
| Confidential | Personal data | Customer PII, account details |
| Restricted | Regulatory data | AML alerts, suspicious transactions |

## 7. Disaster Recovery

### 7.1 Backup Strategy

| Component | Method | Frequency | Retention |
|-----------|--------|-----------|-----------|
| Full Database | Full backup | Daily | 30 days |
| Transaction Log | Log backup | Every 15 min | 7 days |
| ETL Scripts | Git repository | Every commit | Permanent |
| Metadata | Separate backup | Daily | 90 days |

### 7.2 Recovery Objectives

- **RPO (Recovery Point Objective)**: 15 minutes
- **RTO (Recovery Time Objective)**: 4 hours

## 8. Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| Database | SQL Server / PostgreSQL | Data storage |
| ETL | SQL Scripts + Stored Procedures | Data movement |
| Scheduling | SQL Server Agent / Cron | Job orchestration |
| Monitoring | Custom logging framework | Operational monitoring |
| Reporting | Power BI / SSRS | Business intelligence |
| Version Control | Git | Code management |

## 9. Implementation Phases

### Phase 1: Foundation (Weeks 1-4)
- [x] Architecture design
- [ ] Database creation
- [ ] Source system simulation
- [ ] Basic ETL framework

### Phase 2: Core Dimensions (Weeks 5-8)
- [ ] Dimension table implementation
- [ ] SCD processing
- [ ] Surrogate key management
- [ ] Date dimension population

### Phase 3: Core Facts (Weeks 9-12)
- [ ] Transaction fact tables
- [ ] Balance snapshot facts
- [ ] Monthly snapshot facts
- [ ] ETL optimization

### Phase 4: Data Marts (Weeks 13-16)
- [ ] Credit Risk data mart
- [ ] Customer Analytics data mart
- [ ] Treasury data mart
- [ ] Compliance data mart

### Phase 5: Advanced Features (Weeks 17-20)
- [ ] Data quality framework
- [ ] Monitoring and alerting
- [ ] Performance tuning
- [ ] Documentation

### Phase 6: Go-Live (Weeks 21-24)
- [ ] User acceptance testing
- [ ] Performance benchmarking
- [ ] Training and handover
- [ ] Production deployment

## 10. Appendix

### A. Glossary

| Term | Definition |
|------|------------|
| DWH | Data Warehouse |
| ETL | Extract, Transform, Load |
| SCD | Slowly Changing Dimension |
| OLTP | Online Transaction Processing |
| OLAP | Online Analytical Processing |
| NBC | National Bank of Cambodia |
| AML | Anti-Money Laundering |
| CFT | Combating Financing of Terrorism |
| KYC | Know Your Customer |
| GL | General Ledger |

### B. References

1. Inmon, W.H. - Building the Data Warehouse
2. Kimball, R. - The Data Warehouse Toolkit
3. NBC Prudential Regulations
4. Basel III Framework
5. FATF Recommendations
