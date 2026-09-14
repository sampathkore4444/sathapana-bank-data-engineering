# Glossary — Sathapana Bank DWH

## Overview

This glossary defines business, technical, and domain-specific terms used throughout the Sathapana Bank Data Warehouse project. Khmer (Cambodian) translations are provided for banking terms.

---

## Banking Terms

| Term | Khmer | Definition |
|------|-------|------------|
| **Branch** | សាខា | A physical location where banking services are offered |
| **Head Office** | ការិយាល័យកណ្តាល | The main office of the bank, typically in Phnom Penh |
| **Sub-Branch** | សាខារង | A smaller branch operating under a parent branch |
| **Agent** | ភ្នាក់ងារ | A third-party location authorized to offer basic banking services |
| **Teller** | មន្ត្រីបម្រើ | A bank employee who handles customer transactions at the counter |
| **Relationship Officer** | មន្ត្រីទំនាក់ទំនង | An employee assigned to manage specific customer relationships |

### Products

| Term | Khmer | Definition |
|------|-------|------------|
| **Savings Account** | គណនីសន្សំ | An interest-bearing deposit account with no fixed term |
| **Current Account** | គណនីសាច់ប្រាក់ | A checking account for daily transactions |
| **Fixed Deposit** | បញ្ញើរការកំណត់ | A deposit with a fixed term and higher interest rate |
| **Term Deposit** | បញ្ញើរការកំណត់ | Same as Fixed Deposit |
| **Personal Loan** | កម្ចីផ្ទាល់ខ្លួន | Unsecured loan for individual purposes |
| **Home Loan** | កម្ចីផ្ទះ | Mortgage loan for property purchase |
| **Auto Loan** | កម្ចីរថយន្ត | Loan for vehicle purchase |
| **Business Loan** | កម្ចីអាជីវកម្ម | Loan for business purposes |
| **Micro Loan** | កម្ចីតូច | Small loan for micro-enterprises |
| **Debit Card** | ប័ណ្ណដកប្រាក់ | Card linked to a deposit account |
| **Credit Card** | ប័ណ្ណឥណទាន | Card with a revolving credit facility |

### Transactions

| Term | Khmer | Definition |
|------|-------|------------|
| **Deposit** | ការដាក់ប្រាក់ | Adding funds to an account |
| **Withdrawal** | ការដកប្រាក់ | Removing funds from an account |
| **Transfer** | ការផ្ទេរប្រាក់ | Moving funds between accounts |
| **Counter** | តុបម្រើ | In-branch teller transaction |
| **ATM** | ម៉ាស៊ីនដកប្រាក់ | Automated Teller Machine transaction |
| **Mobile** | ទូរស័ព្ទ | Mobile banking transaction |
| **Internet** | អ៊ីនធឺណិត | Online/internet banking transaction |
| **SWIFT** | ស្វ៊ីប | International wire transfer network |
| **ACH** | ការដោះស្រាយសមាធិ | Automated Clearing House (local transfers) |
| **POS** | ចំណុចលក់ | Point of Sale transaction |
| **Cheque** | សន្លឹកប័ណ្ណ | A written order to pay a specific amount |
| **FX Transaction** | ប្រតិបត្តិការប្តូរប្រាក់ | Foreign exchange transaction |

### Risk & Compliance

| Term | Khmer | Definition |
|------|-------|------------|
| **NPL** | បំណុលមិនដំណើរការ | Non-Performing Loan — loan past due > 90 days |
| **Provision** | បម្រុងទុក | Amount set aside to cover potential loan losses |
| **Risk Classification** | ថ្នាក់ហានិភ័យ | Rating of loan quality (Standard → Loss) |
| **Collateral** | ទ្រព្យធានា | Asset pledged as security for a loan |
| **KYC** | ស្គាល់អតិថិជន | Know Your Customer — identity verification process |
| **AML** | ប្រឆាំងការសម្អាតប្រាក់ | Anti-Money Laundering |
| **CFT** | ប្រឆាំងហិរញ្ញប្បទានភេរវកម្ម | Combating Financing of Terrorism |
| **SAR** | របាយការណ៍សង្ស័យ | Suspicious Activity Report |
| **CTR** | របាយការណ៍ប្រតិបត្តិការប្រាក់ | Currency Transaction Report (transactions > $10,000) |
| **PEP** | មន្ត្រីសាធារណៈដែលមានឥទ្ធិពល | Politically Exposed Person |
| **Sanctions** | ទណ្ឌកម្ម | Restrictions against specific individuals/entities |
| **Basel III** | បាសែល III | International banking regulation framework |
| **NBC** | ធនាគារជាតិនៃកម្ពុជា | National Bank of Cambodia |

### Financial Terms

| Term | Khmer | Definition |
|------|-------|------------|
| **GL** | សៀវភៅទូទៅ | General Ledger — master accounting record |
| **Debit** | ឥណទាន | An entry on the left side of an account |
| **Credit** | ឥណពន្ធ | An entry on the right side of an account |
| **Balance** | សមតុល្យ | Amount of money in an account |
| **Interest Rate** | អត្រាការប្រាក់ | Percentage charged on loans or paid on deposits |
| **Exchange Rate** | អត្រាប្តូរប្រាក់ | Rate at which one currency is exchanged for another |
| **Spread** | ការខុសគ្នា | Difference between buy and sell rates |
| **LDR** | អត្រាកម្ចីទៅបញ្ញើ | Loan-to-Deposit Ratio |
| **RWA** | ទ្រព្យសកម្មមានហានិភ័យ | Risk-Weighted Assets |
| **Capital Adequacy** | សមត្ថភាពទុន | Bank's capital relative to its risk exposure |
| **Liquidity** | សមត្ថភាពសាច់ប្រាក់ | Ability to meet short-term obligations |

---

## Data Warehouse Terms

| Term | Definition |
|------|------------|
| **DWH** | Data Warehouse — centralized repository for analytical data |
| **ETL** | Extract, Transform, Load — data movement process |
| **ELT** | Extract, Load, Transform — alternative data movement pattern |
| **OLTP** | Online Transaction Processing — source system databases |
| **OLAP** | Online Analytical Processing — analytical databases |
| **Star Schema** | Dimensional model with fact tables surrounded by dimension tables |
| **Fact Table** | Table containing measurable business events (transactions, balances) |
| **Dimension Table** | Table containing descriptive attributes (customers, products, branches) |
| **Surrogate Key** | System-generated unique identifier (not from source system) |
| **Business Key** | Natural key from the source system (e.g., customer_code) |
| **Conformed Dimension** | Dimension shared consistently across multiple fact tables |
| **Grain** | The level of detail in a fact table (one row = what?) |
| **Aggregate Table** | Pre-calculated summary table for performance |
| **Staging Area** | Intermediate area for data cleansing before loading |
| **Data Mart** | Subset of DW focused on a specific business area |
| **Data Lineage** | Traceability of data from source to report |

### SCD (Slowly Changing Dimension)

| Term | Definition |
|------|------------|
| **SCD Type 1** | Overwrite — no history retained (latest value only) |
| **SCD Type 2** | Historical — full history with valid_from/valid_to dates |
| **SCD Type 3** | Limited history — stores previous value in a separate column |
| **is_current** | Flag indicating the current/active version of a Type 2 record |
| **valid_from** | Timestamp when a Type 2 record became active |
| **valid_to** | Timestamp when a Type 2 record was superseded |

### Data Quality

| Term | Definition |
|------|------------|
| **Completeness** | All required data is present (no NULLs in required fields) |
| **Accuracy** | Data correctly represents the real-world entity |
| **Consistency** | Data agrees across different systems and tables |
| **Timeliness** | Data is available within expected timeframes |
| **Uniqueness** | No unintended duplicate records |
| **Validity** | Data conforms to defined business rules and formats |

---

## Technical Terms

| Term | Definition |
|------|------------|
| **SQL Server** | Microsoft relational database management system |
| **SQL Server Agent** | Job scheduler for automated tasks |
| **T-SQL** | Transact-SQL — Microsoft's SQL dialect |
| **TDE** | Transparent Data Encryption — database-level encryption |
| **RBAC** | Role-Based Access Control |
| **Row-Level Security** | Security filtering at the row level per user |
| **Columnstore Index** | Column-oriented index for analytical queries |
| **Filtered Index** | Index with a WHERE clause (e.g., only current records) |
| **Statistics** | Metadata about data distribution used by query optimizer |
| **Fragmentation** | Index disorder that degrades query performance |
| **Partition** | Table split into smaller pieces by a key (e.g., monthly) |
| **Identity** | Auto-incrementing integer column |
| **View** | Virtual table defined by a SQL query |
| **Stored Procedure** | Precompiled SQL code stored in the database |
| **Trigger** | SQL code that executes automatically on data changes |
| **Cursor** | Row-by-row processing mechanism |
| **TRY...CATCH** | Error handling blocks in T-SQL |

---

## Abbreviations

| Abbreviation | Full Form |
|-------------|-----------|
| DWH | Data Warehouse |
| ETL | Extract, Transform, Load |
| OLTP | Online Transaction Processing |
| OLAP | Online Analytical Processing |
| SCD | Slowly Changing Dimension |
| NBC | National Bank of Cambodia |
| AML | Anti-Money Laundering |
| CFT | Combating Financing of Terrorism |
| KYC | Know Your Customer |
| SAR | Suspicious Activity Report |
| CTR | Currency Transaction Report |
| PEP | Politically Exposed Person |
| NPL | Non-Performing Loan |
| GL | General Ledger |
| FX | Foreign Exchange |
| LDR | Loan-to-Deposit Ratio |
| RWA | Risk-Weighted Assets |
| RBAC | Role-Based Access Control |
| TDE | Transparent Data Encryption |
| PII | Personally Identifiable Information |
| CLV | Customer Lifetime Value |
| ALM | Asset-Liability Management |
| FTP | Funds Transfer Pricing |
| EMI | Equated Monthly Installment |
| SWIFT | Society for Worldwide Interbank Financial Telecommunication |
| ACH | Automated Clearing House |
| POS | Point of Sale |
| ATM | Automated Teller Machine |

---

## Database Reference

| Database | Purpose | Schema |
|----------|---------|--------|
| `sathapana_source` | OLTP source simulation | `oltp` |
| `sathapana_raw` | Raw zone (source copy) | `raw` |
| `sathapana_staging` | Staging area | `staging` |
| `sathapana_dwh` | Enterprise data warehouse | `dw`, `audit` |
| `sathapana_dm_credit` | Credit risk data mart | `dm` |
| `sathapana_dm_customer` | Customer analytics mart | `dm` |
| `sathapana_dm_treasury` | Treasury data mart | `dm` |
| `sathapana_dm_compliance` | Compliance/AML mart | `dm` |
| `sathapana_dm_alm` | Asset-Liability Management mart | `dm` |
| `sathapana_dm_operations` | Operations analytics mart | `dm` |

---

## Conventions

| Convention | Example | Description |
|-----------|---------|-------------|
| `dim_*` | `dim_customer` | Dimension table |
| `fact_*` | `fact_transactions` | Fact table |
| `vw_*` | `vw_credit_risk_summary` | View |
| `usp_*` | `usp_LoadAll` | Stored procedure |
| `stg_*` | `stg_customers` | Staging table |
| `*_key` | `customer_key` | Surrogate key column |
| `*_code` | `customer_code` | Business key column |
| `is_*` | `is_current`, `is_active` | Boolean flag column |
| `*_date_key` | `transaction_date_key` | Date dimension FK (integer) |
| `DQ*` | `DQ001` | Data quality rule ID |
| `DWH_*` | `DWH_00_Master_Pipeline` | SQL Server Agent job name |

---

*Last Updated: September 2026*
