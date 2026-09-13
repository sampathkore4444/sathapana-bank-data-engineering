SSIS vs Apache Hop vs Apache Airflow

If you're comparing them for a **banking Data & Analytics / DWH environment**, they serve somewhat different purposes.

### Quick comparison

| Area                       | **SSIS**               | **Apache Hop**         | **Apache Airflow**              |
| -------------------------- | ---------------------- | ---------------------- | ------------------------------- |
| Main purpose               | ETL                    | ETL / Data Integration | Workflow orchestration          |
| Type                       | Microsoft ETL platform | Visual ETL platform    | Workflow scheduler/orchestrator |
| GUI                        | ⭐⭐⭐⭐⭐                  | ⭐⭐⭐⭐⭐                  | ⭐⭐⭐                             |
| Code required              | Low                    | Low–Medium             | Medium–High                     |
| SQL Server integration     | ⭐⭐⭐⭐⭐                  | ⭐⭐⭐                    | ⭐⭐⭐                             |
| Oracle                     | ⭐⭐⭐⭐                   | ⭐⭐⭐⭐                   | ⭐⭐⭐⭐                            |
| PostgreSQL/MySQL           | ⭐⭐⭐⭐                   | ⭐⭐⭐⭐                   | ⭐⭐⭐⭐                            |
| Complex transformations    | ⭐⭐⭐⭐⭐                  | ⭐⭐⭐⭐                   | ⭐⭐                              |
| Scheduling                 | ⭐⭐⭐⭐                   | ⭐⭐⭐                    | ⭐⭐⭐⭐⭐                           |
| Dependency management      | ⭐⭐⭐                    | ⭐⭐⭐                    | ⭐⭐⭐⭐⭐                           |
| Python integration         | ⭐⭐                     | ⭐⭐⭐                    | ⭐⭐⭐⭐⭐                           |
| Spark integration          | ⭐⭐⭐                    | ⭐⭐⭐                    | ⭐⭐⭐⭐⭐                           |
| Kubernetes/cloud           | ⭐⭐                     | ⭐⭐⭐                    | ⭐⭐⭐⭐⭐                           |
| Data engineering ecosystem | ⭐⭐⭐                    | ⭐⭐⭐                    | ⭐⭐⭐⭐⭐                           |
| Open source                | ❌                      | ✅                      | ✅                               |
| Best for                   | Microsoft-centric ETL  | Visual open-source ETL | Enterprise pipelines/workflows  |

### The key difference

Think of a bank's nightly customer/transaction pipeline:

```text
Core Banking
     │
     ▼
Extract
     │
     ▼
Transform / Clean / Validate
     │
     ▼
DWH
     │
     ▼
Data Marts
     │
     ▼
Reports / Analytics / AI
```

**SSIS / Hop** are primarily concerned with:

> "How do I move and transform the data?"

**Airflow** is primarily concerned with:

> "When should these jobs run, in what order, and what happens if something fails?"

So Airflow can orchestrate SSIS or Hop jobs rather than necessarily replacing them.

---

## 1. SSIS

![Image](https://images.openai.com/static-rsc-4/UhQFhnvX1ul9HvQxvgTGwqZI3Yz-xjfyG_WCWe5TZwZNl-SA9JzuwRtEwXi3uNq0oiYm-x-3HPeDKVIgG_uXW0J3eG1MA5bBxHN-1KSAjYSYgPArhMOpjLLUULg74crDL-UdsubQNKTsvhhPt9oosTUIOm2gp0IcFe6A6vV2tFf3pKTx2BQpMmeCzyh1Gqn-?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/vbfbL5UDjBPSVxzvQjzJSe90nYFYgyoL7snsRb66iAGYWvZ5Uy_fk5-XbAjV4KQSxKPLYtEq_zgvh1NXF97wTgVkxFThTK8wxwDAIYK8W9KMeegV2ZJxvTiZuOGQ8qDAq7Y3Oqasj85B6S2Cw3ClR21dx-d0N4_ms63gByovW2SK-QPr808hkpGI_NCrjPur?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/AD_7s3KDbIusG4_hOpXOB9ZnrL4OHdTR4Nkw-51YyzlLl3yFMwJD2KmmC999hRpeNUqlYpESjvW3Uqn0emkATOvCpxCymlsldlQ0DQRefao7MNjK1KWuq7ApSbICzz5gsz1v-S-aBy7TNlnNfwq4a_I22YCDC1tXnmKbawAdxM3JMCEGOYbdQ4Fqa2cH4Nuh?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/vCP6xCkutT02PqkZ39pnD62lkkZ3hieAigz7Vf_TL3vf0ktCavfAPFUzPMM8mrfd95YUFD3fo4XR4WuRUADHDVlkllLQ-pb_JkZJDhSk1YaWSvhu9ylfr9b_mqrreuWyDqkgPsmr-JV0OrBNVPcowQgOI8vCcJZWg5XQJm2KzPN1j3yjwJdw2HK9OoUnTTOz?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/IZ2sp1MlWXq9I3dvb_5C6gMhIZ0rMkmxC7X0dd4A99Ghs4yPjAjaNY4US0Xv1FdjfLHaYstvKVUWNennGF9T7P9xNo0eGLJmnA3hP-VFV22muW-LbRpCL9bLk5CniQNgLN8Tau9SNqQ6c9zs1xn17fnsM1Q4PyIlHM_JF4kwlUMahlCbLBUgSbjwhgjaesna?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/gV7vI5omvghJkS4cbvlHx8zGnHenRm9V_bKbG6D5TrusNYUJaaB3cvpviIZVY6uDEZWxj5igIxFcKZG3u7TiTdpwZrBNJGtBdcUeNQ9rss7hewOYtSexa_fuO2QJCWW_hRkQSOKIs4lTU_Mx7AMbUFXtMhiS3JCeYyqVHDITm38WjaTB5KXE820d3b1tGDET?purpose=fullsize)

SSIS = **SQL Server Integration Services**.

It's a mature Microsoft ETL technology.

Example:

```text
Oracle Core Banking
       │
       ▼
     SSIS
       │
 ┌─────┼────────┐
 ▼     ▼        ▼
Clean Transform Validate
       │
       ▼
SQL Server DWH
```

You can visually build:

```text
OLE DB Source
      ↓
Lookup
      ↓
Derived Column
      ↓
Conditional Split
      ↓
Aggregate
      ↓
OLE DB Destination
```

### Strengths

* Very mature
* Excellent GUI
* Excellent SQL Server integration
* Good performance for traditional ETL
* Large enterprise talent pool
* Easy for SQL developers to understand

### Weaknesses

* Microsoft ecosystem dependency
* Licensing/infrastructure considerations
* Less attractive for modern cloud-native data platforms
* Python/Spark/Kafka/cloud integration isn't its strongest area
* Version control and CI/CD aren't as natural as code-based pipelines

For a bank running:

```text
SQL Server
+
SSIS
+
Power BI
```

SSIS can still be an excellent choice.

---

# 2. Apache Hop

![Image](https://images.openai.com/static-rsc-4/byWkRoYmFO-QzGjXolqEc_x51Vvl7Tp4qW1FgIH5GJYXRORAwn891e4lmWyF456Jrek-tpj_OKnN1ENi-pMJ1af-F3pmVnAjU8lyF9n66KBH6AP7OvexbIKsB4-AMhB1U1MHbS2yBoYMlJY-SJ3i2KbDUNmymnBtZAFb7Er_aQwB57Zhp46obTKRnTdJnrte?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/txwez9tBy9Cfs21GjR9FJLPbRHLrWVK4eEjkOAsFrL6E40jy0xeWi6xp0U6IcGFFYnjL3i0a_Lnr6sVgmuCsLa1mxTR96b3cd8gMILCLuxl5Y-sCNprdFkS8IWmvS0HfgVlyMaUQLLlxumG4XKT0kkOctHKxOtKW7AWqzyiDGDuxRhkD9XzVvXxumJPIGmNJ?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/RMFiVFNCeWkp3Zg7BSloQkzkQ0xJkS7lyzAQyP7HizxguXFmSCZlsI4LCD-x9uGpai4WSu-_dGYI9Yzo3s3zq2zva_I7vKdL5_miezydgrHmdVczhp3Zufd_HR68ZnJ0RaTimul4PORMUlTVtFP4EswWEYY5IUTomn_cC3xoBpaeuHBGeQZF282nlBJssZWE?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/BMfwl2XUlsj9dB41fSeoUK-tMm_beA-srfTmKoogOcqeG_7SP3EWE2Omxdl2Z7eKeYXPwDMl-_dVWID3KcpPvm1yLj1rUOpPv1ekhlwiZDpK3VFgh7nmlHSx4VYWYWklnP9yM3FROEH7_JMuTSvI95x_XAGl0UE4KxwPSIx2isM2XdFUmR9RAfhkElGyOvD1?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/qjyTzbm1CfyHfhFuAh9IRUrNYbmzMcX9yKh_UFPpK8kfPSQDiZE3CwfNWpYzfn8TYa62n_7p1MaC5K-nGQUwRhvpZdJrLs0wzJBy4Bxewy4YHM3bfxVcBy-XYOh3Hk82jS-TShEf6d3l3Mj2j_FImIIcokAlAADY5RsrmDPRpdswbZqcI_f_iY5-bs-lsVHp?purpose=fullsize)

Apache Hop is probably the closest of these three to **SSIS conceptually**.

It provides visual development of:

```text
Pipeline
   │
   ├── Source
   ├── Transform
   ├── Lookup
   ├── Join
   ├── Filter
   └── Target
```

And workflows:

```text
Workflow
   │
   ├── Start
   │
   ├── Run Pipeline
   │
   ├── Check condition
   │
   ├── Send notification
   │
   └── End
```

### Why Hop is interesting

If you want:

> **Open-source SSIS-like ETL**

Apache Hop is worth considering.

For example:

```text
Oracle CBS
   ↓
Apache Hop
   ↓
Customer cleansing
   ↓
Account transformation
   ↓
Transaction transformation
   ↓
PostgreSQL DWH
```

You can develop much of this visually rather than writing everything in Python.

---

# 3. Apache Airflow

![Image](https://images.openai.com/static-rsc-4/GmgdKxbdnlXwbjKYzbvpTCaUJVm-xtY11KcfcUIOIFmYwyv2r_BswVmOnGqqlEYT8y5NaE_7NmXlHcAX-OQnHx9pkzMFA-jQJzYE2yZ_X-ZHGi6ic6Mol6fzJEMRJylVdmixbaa_T--6hUD0t0zvD2QUqx6J8tOYPj9wScjI7DIx_Mo81mDFDGSfLQiTnQcb?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/JLajxKtiV_T2-FZ5Kw7G2Iim6IwUxFV-pp950RfHZ101Q6TQYHdSE_o0uOyCCW9HQm5r9nHkqen6hws49WJz0y0lbMTPNYU1fSrdZud53kLntTVRRIlxFKO6Cjf_ey2f6kTYg-2FqcaeCTnk8C7HbtJ-us3zU9mqIZaNvRZWp4HcyMsI8FFbFdiVqMLg4k2u?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/aNJg4Gb_0Nw6Xz18OtwEF6201lCZKQmiuSjsJDmT5uAotl3zoruYYxj8UsnJGvEmooiWikWU4AwdsIVgfbTs4TAoG_IELfaQh79zUBH__mObNvZRFlJlfmes1jOWmkY3QC1jTKm3gwn7SHtyXuwnD4eyb8VT3iFwvpI7iA7y1aCQYY6cCbNaI5jkGz51KWra?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/HiGjmOCNgoq3P2WTemGcqI17tMFl-yIg1vxw-lY-C2uABzrEirY1bLVW1qGerLhwmD8rja98VpxfXlYxy5HS23THSFEkKEqWU-p8Oa89I2UK79XWHsRL4ljWIRDvMv6TK7aUKcTNVYxWP60eGMvtSaaWwemasQPqkPz-SAHiadM3XGabyyQHQXJ9erSPPk7L?purpose=fullsize)

![Image](https://images.openai.com/static-rsc-4/EPgkS_f0GEjs_mu6xYuMv-kzR7tFwYYZSW6FaFg8wsVyPnF6aeaNWxcKRH-83hdSX1AhjDYN-6Cue-e4z0PSoVUqduKAnLIebljZLaLvlMps9PfLOBPt1EvqEq1KZVNVoN97Z-sfxonrzrwa-SiZRhnHMyrJM8wYOyCU4ZdihisuKL4KMxjQ_P6y_k6TeavA?purpose=fullsize)

Airflow is fundamentally different.

It's an **orchestrator**.

For example:

```text
                 ┌──────────────┐
                 │ Extract CBS  │
                 └──────┬───────┘
                        ↓
                 ┌──────────────┐
                 │ Validate     │
                 └──────┬───────┘
                        ↓
             ┌──────────┴─────────┐
             ↓                    ↓
      Customer DWH          Transaction DWH
             │                    │
             └──────────┬─────────┘
                        ↓
                 Data Quality
                        ↓
                   Data Marts
                        ↓
                  ML Features
```

Airflow understands:

* dependencies
* schedules
* retries
* failures
* backfills
* task states
* SLA monitoring
* DAG execution

For example:

```text
02:00 → CDC validation
02:15 → Customer dimension
02:30 → Account dimension
03:00 → Transaction fact
04:00 → Loan fact
05:00 → Data quality
06:00 → Regulatory reports
```

This is where Airflow shines.

---

# The important distinction

You shouldn't really think:

> SSIS vs Hop vs Airflow

as if they're exactly equivalent products.

A better comparison is:

```text
             DATA PROCESSING
                   │
          ┌────────┴─────────┐
          │                  │
       SSIS                Hop
          │                  │
          └────────┬─────────┘
                   │
              ETL / ELT
                   
                   
             ORCHESTRATION
                   │
                Airflow
```

And modern architecture could be:

```text
                  Airflow
                     │
       ┌─────────────┼─────────────┐
       ↓             ↓             ↓
   Apache Hop     PySpark       dbt
       │             │             │
       └─────────────┼─────────────┘
                     ↓
                    DWH
```

---

# For Sathapana Bank

Given the type of architecture you've been discussing for Sathapana, I would **not recommend starting a new platform with SSIS** unless the bank already has a significant Microsoft/SQL Server investment.

I'd lean toward:

### Option A — Modern data platform

```text
Core Banking
     │
     ├── CDC/Debezium
     │
     ▼
   Kafka
     │
     ▼
Data Lake / DWH
     │
 ┌───┴────┐
 ▼        ▼
dbt     Spark
 │        │
 └───┬────┘
     ▼
Analytics / AI
     
        ↑
    Airflow
```

Here **Airflow orchestrates**, while Spark/dbt/etc. perform the actual transformations.

### Option B — Visual ETL-oriented bank

```text
Core Banking
     │
     ▼
Apache Hop
     │
     ▼
DWH
     │
     ▼
Data Marts
     │
     ▼
BI / AI

       ↑
    Airflow
```

This is attractive if the bank has a team that prefers **GUI-based ETL development**.

---

# My recommendation

For a **new Sathapana Bank Data & Analytics platform**, I'd rank them:

**1. Apache Airflow — definitely learn/use**
For orchestration and enterprise data pipelines.

**2. Apache Hop — consider for visual ETL**
Especially if you want an open-source SSIS-like experience.

**3. SSIS — use if the existing ecosystem is Microsoft/SQL Server-heavy**
Don't migrate away from a functioning SSIS estate just for the sake of modernization.

The architecture I would seriously consider is:

```text
                    SOURCES
                       │
       ┌───────────────┼────────────────┐
       │               │                │
   Core Banking     Cards          Merchant/KHQR
       │               │                │
       └───────────────┼────────────────┘
                       ▼
                  CDC / APIs
                       │
                     Kafka
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
          DWH/Lake            Real-time
             │                processing
             ▼
       dbt / Spark / SQL
             │
       ┌─────┼─────────┐
       ▼     ▼         ▼
     BI     AI       Regulatory
             ▲
             │
          Airflow
       (orchestration)
```

**In short: SSIS ≈ ETL, Hop ≈ open-source visual ETL, Airflow ≈ orchestration.**

For your own learning path, I'd prioritize **Airflow → dbt → Spark → Kafka/Debezium**, and learn Hop mainly to understand where a visual ETL tool fits in the architecture.

Choose the right architecture

* Compare Airflow + Hop
* Map the learning path


Explain below flow clealry

                    SOURCES
                       │
       ┌───────────────┼────────────────┐
       │               │                │
   Core Banking     Cards          Merchant/KHQR
       │               │                │
       └───────────────┼────────────────┘
                       ▼
                  CDC / APIs
                       │
                     Kafka
                       │
             ┌─────────┴─────────┐
             ▼                   ▼
          DWH/Lake            Real-time
             │                processing
             ▼
       dbt / Spark / SQL
             │
       ┌─────┼─────────┐
       ▼     ▼         ▼
     BI     AI       Regulatory
             ▲
             │
          Airflow
       (orchestration)


Absolutely. The easiest way to understand this architecture is to follow **one banking transaction from the source system all the way to BI/AI**.

Think of the architecture as:

> **Collect → Transport → Store → Transform → Consume → Orchestrate**

---

# 1. SOURCES — Where banking data originates

```text
                    SOURCES
                       │
       ┌───────────────┼────────────────┐
       │               │                │
   Core Banking     Cards          Merchant/KHQR
```

These are the systems that **generate business data**.

### A. Core Banking System

For example, the bank's CBS contains:

```text
Customer
Account
Deposit
Loan
Interest
Repayment
Transfer
Branch transaction
GL
```

Suppose a customer transfers:

```text
Customer A
Account: 001
       │
       │ $500
       ▼
Customer B
Account: 002
```

The CBS records this transaction.

---

### B. Cards

Card systems generate:

```text
ATM withdrawal
POS purchase
E-commerce transaction
Card payment
Card reversal
Card refund
Card authorization
```

Example:

```text
Customer
   │
   │ Visa card → $100 purchase
   ▼
Card Processing System
```

This data may not directly live in the CBS.

---

### C. Merchant / KHQR

This is particularly important for a Cambodian bank.

You can have:

```text
Merchant
   │
   ├── KHQR
   ├── POS
   ├── E-commerce
   └── Payment gateway
```

Suppose a Sathapana SME merchant receives:

```text
Monday       $2,000
Tuesday      $3,500
Wednesday    $1,200
Thursday     $4,000
Friday       $5,000
```

That payment activity becomes extremely useful for understanding the SME's **cash flow and repayment capacity**.

---

# 2. CDC / APIs — Getting data out of source systems

The next question is:

> How do we get this data from those systems?

That's where **CDC and APIs** come in.

```text
Core Banking ──┐
Cards ─────────┼──→ CDC / APIs
Merchant ──────┘
```

There are two major approaches.

---

## CDC = Change Data Capture

CDC means:

> "Capture only what changed."

Suppose your account table contains:

```text
ACCOUNT
--------------------------------
001   Sampath   USD   10,000
002   John      USD    5,000
003   David     USD    8,000
```

A customer withdraws $500.

Instead of copying the entire table:

```text
10,000 accounts
10,000 accounts
10,000 accounts
...
```

CDC detects:

```text
Account 001
Old balance: 10,000
New balance: 9,500
```

and sends that change downstream.

Typical technology:

**Debezium**

```text
Oracle CBS
    │
    │ CDC
    ▼
Debezium
    │
    ▼
Kafka
```

---

# 3. APIs

Not everything should be extracted through database CDC.

For example:

```text
Merchant Payment Gateway
        │
        ▼
       API
        │
        ▼
      Kafka
```

You might obtain:

```json
{
  "merchant_id": "M1001",
  "amount": 250.00,
  "currency": "USD",
  "payment_type": "KHQR",
  "timestamp": "2026-09-13T09:00:00"
}
```

So:

**CDC** is generally useful for database changes.

**API** is useful when the source system exposes business services/events rather than direct database access.

---

# 4. Kafka — The transportation layer

Now we have:

```text
Core Banking
Cards
Merchant
     │
     ▼
 CDC / APIs
     │
     ▼
   Kafka
```

Kafka acts like a **central event/data highway**.

For example:

```text
Kafka Topics

customer_changes
account_changes
transactions
card_transactions
merchant_payments
khqr_transactions
loan_transactions
```

Suppose a customer makes a $100 payment.

The event could enter:

```text
transaction_events
        │
        ▼
      Kafka
```

Kafka can then distribute that event to multiple consumers.

```text
                    Kafka
                      │
          ┌───────────┼────────────┐
          ▼           ▼            ▼
         DWH       Fraud       Real-time
                   Engine      Analytics
```

This is one of the biggest reasons Kafka is useful.

The source system doesn't have to know every downstream consumer.

---

# 5. DWH / Data Lake — Store the data

From Kafka, one major path goes toward storage:

```text
Kafka
  │
  ▼
DWH / Data Lake
```

### Data Warehouse

Good for structured analytical data:

```text
CUSTOMER_DIM
ACCOUNT_DIM
LOAN_DIM
MERCHANT_DIM
TRANSACTION_FACT
PAYMENT_FACT
CARD_TRANSACTION_FACT
```

Example:

```text
FACT_TRANSACTION

Date       Customer    Account    Amount
------------------------------------------------
Sep 13     C001        A001       500
Sep 13     C002        A002       250
Sep 13     C003        A003       100
```

---

### Data Lake

A Data Lake is useful for larger/more diverse data:

```text
Raw transactions
JSON
Logs
Documents
Images
AI datasets
Clickstream
IoT/satellite data
```

For a modern bank you could have:

```text
                  Kafka
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
       Data Lake          Data Warehouse
          │                   │
      Raw data           Curated data
```

---

# 6. Real-time processing — The second Kafka path

Notice that the architecture has another branch:

```text
                   Kafka
                     │
          ┌──────────┴──────────┐
          ▼                     ▼
       DWH/Lake             Real-time
                            processing
```

Why?

Because not every banking use case can wait for the DWH.

Imagine:

```text
Customer makes $8,000 transaction
             │
             ▼
           Kafka
             │
             ▼
      Fraud Detection
             │
             ▼
        Risk Score
             │
             ▼
       Block / Review
```

You may need the answer in **milliseconds or seconds**.

You don't want:

```text
Transaction
   ↓
DWH
   ↓
ETL
   ↓
BI
   ↓
Fraud decision
```

because that's too slow for real-time fraud prevention.

Real-time technologies could include:

```text
Kafka
Flink
Spark Streaming
Kafka Streams
Python services
ML inference services
```

---

# 7. dbt / Spark / SQL — Transform the data

Now we have data stored in the DWH/Lake.

But raw data isn't necessarily ready for business use.

Example:

```text
Raw transaction
```

might contain:

```text
ACCOUNT_ID
TXN_CODE
TXN_DATE
DR_CR
AMOUNT
BRANCH_ID
```

We need to transform it into something meaningful.

That's where:

```text
dbt
Spark
SQL
```

come in.

---

## SQL

For normal transformations:

```text
Raw transactions
       ↓
SQL
       ↓
Clean transactions
```

Example:

```sql
SELECT
    account_id,
    transaction_date,
    amount
FROM raw_transactions
WHERE status = 'SUCCESS';
```

---

## dbt

dbt is particularly useful for **SQL-based transformation inside the warehouse**.

For example:

```text
RAW_TRANSACTION
       ↓
stg_transaction
       ↓
fct_transaction
       ↓
customer_transaction_summary
```

You can create:

```text
Daily customer spending
Monthly customer income
Loan repayment ratio
Merchant revenue
Customer balance trends
```

---

## Spark

Spark becomes useful when processing becomes large/complex.

For example:

```text
10 TB transaction data
       ↓
     Spark
       ↓
Customer behavioral features
       ↓
ML dataset
```

---

# 8. BI — Business Intelligence

Once the data is transformed:

```text
                Curated Data
                     │
                     ▼
                    BI
```

Business users can see:

```text
CEO Dashboard
────────────────────────────
Total Deposits       $2.4B
Loans                $1.8B
NPL                   2.1%
Active Customers     1.2M
Merchant Volume      $340M
```

Other dashboards:

```text
Branch performance
Loan portfolio
Deposit growth
Merchant performance
Card performance
Digital banking
Collections
Risk
```

---

# 9. AI

The same curated data can feed AI/ML.

```text
                    DWH
                     │
                     ▼
                    AI
```

Examples:

### Fraud

```text
Transaction
    ↓
Features
    ↓
ML model
    ↓
Fraud probability = 97%
```

### Credit scoring

```text
Customer
   +
Transaction history
   +
Loan history
   +
Merchant cash flow
        ↓
Credit model
        ↓
Risk score
```

### Collections

```text
Customer
   ↓
Payment behavior
   ↓
Risk prediction
   ↓
"High probability of default"
   ↓
Collection action
```

This is particularly relevant to the Sathapana use cases we've discussed.

---

# 10. Regulatory reporting

Another consumer is:

```text
DWH
  │
  ▼
Regulatory
```

For example, the bank may need reports covering:

```text
Loans
Deposits
Capital
Liquidity
AML
Transactions
Customer information
Regulatory ratios
```

Instead of manually preparing Excel files, the bank can build governed regulatory datasets.

---

# 11. Where does Airflow come in?

This is the part that often confuses people.

Airflow **doesn't necessarily process the banking data itself**.

Instead, Airflow says:

> "Run these jobs in the correct order."

For example:

```text
                 AIRFLOW
                    │
       ┌────────────┼────────────┐
       ▼            ▼            ▼
   Run CDC      Run Spark      Run dbt
       │            │            │
       └────────────┼────────────┘
                    ▼
              Data Quality
                    │
                    ▼
                 Publish
```

Imagine your daily DWH process.

### 1:00 AM

```text
Airflow
   ↓
Check CDC ingestion
```

### 1:30 AM

```text
Airflow
   ↓
Load customer data
```

### 2:00 AM

```text
Airflow
   ↓
Load transactions
```

### 3:00 AM

```text
Airflow
   ↓
Run Spark transformations
```

### 4:00 AM

```text
Airflow
   ↓
Run dbt models
```

### 5:00 AM

```text
Airflow
   ↓
Run data-quality checks
```

### 6:00 AM

```text
Airflow
   ↓
Refresh BI datasets
```

So Airflow is the **conductor**, not necessarily the orchestra.

---

# Putting everything together

Let's follow a single **KHQR payment**.

### Step 1 — Customer pays merchant

```text
Customer
   │
   │ $50 KHQR payment
   ▼
Merchant/KHQR system
```

### Step 2 — Event generated

```text
KHQR system
     │
     ▼
API / Event
```

### Step 3 — Kafka

```text
API
 │
 ▼
Kafka
 │
 ├──────────────┐
 ▼              ▼
DWH/Lake     Real-time
                │
                ▼
             Fraud ML
```

### Step 4 — DWH

```text
Kafka
  ↓
Raw payment
  ↓
DWH
```

### Step 5 — Transformation

```text
DWH
 ↓
dbt / SQL
 ↓
Merchant daily revenue
```

For example:

```text
Merchant M001

Daily revenue = $8,500
30-day revenue = $245,000
Transaction count = 4,321
Average transaction = $56.70
```

### Step 6 — AI

The bank can now combine:

```text
Merchant revenue
       +
Account balance
       +
Loan repayment
       +
Business transactions
       +
Other financial behavior
       ↓
SME risk model
       ↓
Repayment risk
```

### Step 7 — BI

The relationship manager sees:

```text
SME: ABC Restaurant

Revenue trend       ↑
KHQR transactions   ↑
Account balance     ↑
Loan repayment      ✓

Risk: LOW
```

---

# The complete picture

```text
                     BANKING DATA SOURCES
                              │
             ┌────────────────┼─────────────────┐
             │                │                 │
        Core Banking        Cards          Merchant/KHQR
             │                │                 │
             └────────────────┼─────────────────┘
                              │
                       CDC / APIs / Events
                              │
                              ▼
                           KAFKA
                              │
                ┌─────────────┴─────────────┐
                │                           │
                ▼                           ▼
          DATA LAKE / DWH              REAL-TIME
                │                      PROCESSING
                │                           │
                ▼                           ▼
          dbt / SQL / Spark            Fraud / Risk
                │                       / Alerts
        ┌───────┼────────┐
        │       │        │
        ▼       ▼        ▼
       BI       AI    Regulatory
        │       │
        ▼       ▼
     Business  ML Models
     Decisions
     
              ↑
              │
           AIRFLOW
       ORCHESTRATION
```

### The simplest way to remember it

| Component                | Think of it as             |
| ------------------------ | -------------------------- |
| **CBS / Cards / KHQR**   | Data producers             |
| **CDC / APIs**           | Data collection mechanisms |
| **Kafka**                | Data highway               |
| **DWH / Lake**           | Data storage               |
| **dbt / SQL / Spark**    | Data transformation        |
| **Real-time processing** | Immediate decisions        |
| **BI**                   | Human decision-making      |
| **AI/ML**                | Machine decision-making    |
| **Regulatory**           | Compliance/reporting       |
| **Airflow**              | Conductor/orchestrator     |

And importantly, **Airflow does not replace Kafka, Spark, dbt, or the DWH**. It coordinates them.

For a **Sathapana Bank Data Architect** role, this distinction is especially important: you would be designing the **overall data platform and how these components interact**, rather than simply choosing an ETL tool.

Go one level deeper

* Show the daily Airflow workflow
* Explain batch vs real-time


Here in the above diagram, should the Data Lake/DWH contain Bronze, Silver and Gold Layers?

Yes — **if you're designing a modern Data Lakehouse/DWH architecture, Bronze/Silver/Gold is a very good way to structure the data**, but there is an important nuance:

> **Bronze/Silver/Gold primarily describes data layers in the Data Lake/Lakehouse. A traditional DWH doesn't necessarily need those exact names.**

For the Sathapana-style architecture we were discussing, I would structure it like this:

```text
                    BANKING SOURCES
                          │
          ┌───────────────┼────────────────┐
          │               │                │
      Core Banking      Cards          Merchant/KHQR
          │               │                │
          └───────────────┼────────────────┘
                          │
                    CDC / APIs
                          │
                        Kafka
                          │
                          ▼
                 ┌─────────────────┐
                 │   DATA LAKE     │
                 │                 │
                 │    BRONZE       │
                 │       ↓         │
                 │    SILVER       │
                 │       ↓         │
                 │     GOLD        │
                 └────────┬────────┘
                          │
                          ▼
                 DWH / Data Marts
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
             BI          AI      Regulatory
```

But I'd make the architecture slightly more precise.

---

# 1. Bronze = Raw data

Bronze should contain data **very close to what came from the source**.

For example:

```text
Bronze
│
├── CBS
│   ├── customer
│   ├── account
│   ├── transaction
│   └── loan
│
├── Cards
│   ├── card_transaction
│   └── authorization
│
└── Merchant/KHQR
    ├── merchant
    └── payment
```

Suppose CBS sends:

```text
ACCOUNT_ID = 100123
CUSTOMER_ID = C001
BALANCE = 5000
CURRENCY = USD
STATUS = A
LAST_UPDATE = 2026-09-13 10:15:22
```

Bronze essentially preserves the source representation.

### Why?

Because you want to be able to answer:

> "What exactly did the source system send us?"

This is extremely important in banking for **auditability, reconciliation and troubleshooting**.

---

# 2. Silver = Cleaned / standardized data

Now we clean and standardize Bronze.

```text
BRONZE
   │
   ▼
Validation
Deduplication
Data type conversion
Standardization
Business rules
   │
   ▼
SILVER
```

For example:

### Bronze

```text
customer_id = "C001 "
gender = "M"
dob = "1985/01/20"
country = "KH"
```

### Silver

```text
customer_id = C001
gender = Male
dob = 1985-01-20
country_code = KH
```

You might also resolve:

```text
duplicate customers
invalid accounts
bad dates
currency inconsistencies
duplicate transactions
missing references
```

Silver should represent **trusted, standardized data**.

---

# 3. Gold = Business-ready data

Gold is where things become useful for business users and analytics.

For example:

```text
SILVER
   │
   ▼
Business transformations
   │
   ▼
GOLD
```

You might create:

```text
gold_customer_360
gold_daily_customer_balance
gold_merchant_revenue
gold_loan_portfolio
gold_customer_transactions
gold_branch_performance
gold_card_performance
gold_digital_banking
```

For example:

```text
GOLD_MERCHANT_PERFORMANCE

merchant_id
merchant_name
daily_revenue
monthly_revenue
transaction_count
average_transaction
revenue_growth
active_days
```

Now BI can directly consume this.

---

# 4. Where does dbt fit?

This is where your previous diagram needs a small correction.

Instead of:

```text
DWH/Lake
    ↓
dbt / Spark / SQL
```

think:

```text
                 DATA LAKE
                    │
                 BRONZE
                    │
                    ▼
              Spark / SQL
                    │
                    ▼
                 SILVER
                    │
                    ▼
              dbt / SQL
                    │
                    ▼
                  GOLD
```

But it's not mandatory that Spark handles Silver and dbt handles Gold.

You could use:

```text
Bronze → Silver
   │
   └── Spark / SQL

Silver → Gold
   │
   └── dbt / SQL / Spark
```

The tool depends on the workload.

---

# 5. Where does the traditional DWH fit?

This is where architecture terminology can become confusing.

You can have:

### Architecture A — Lakehouse

```text
Kafka
  ↓
Data Lake
  │
  ├── Bronze
  ├── Silver
  └── Gold
        │
        ▼
      BI / AI
```

In this architecture, the Gold layer may be directly consumed by analytics tools.

---

### Architecture B — Data Lake + traditional DWH

For a large bank, I actually like this model:

```text
                     Kafka
                       │
                       ▼
                  DATA LAKE
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼
          Bronze    Silver     Gold
                                 │
                                 ▼
                            ENTERPRISE
                               DWH
                                 │
                  ┌──────────────┼──────────────┐
                  ▼              ▼              ▼
               BI Marts      Regulatory      Analytics
```

Here the Data Lake is the **large-scale data foundation**, while the DWH provides highly structured, governed analytical datasets.

---

# 6. Where would I put Sathapana's banking data?

I'd envision something like:

```text
                         SOURCES
                            │
       ┌────────────────────┼────────────────────┐
       │                    │                    │
     CBS                  Cards              KHQR
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                       CDC / APIs
                            │
                          Kafka
                            │
                            ▼
                  ┌───────────────────┐
                  │      BRONZE       │
                  │                   │
                  │ Raw CBS           │
                  │ Raw Cards         │
                  │ Raw KHQR          │
                  │ Raw Merchant      │
                  └─────────┬─────────┘
                            │
                         Spark/SQL
                            │
                            ▼
                  ┌───────────────────┐
                  │      SILVER       │
                  │                   │
                  │ Customer          │
                  │ Account           │
                  │ Transaction       │
                  │ Merchant          │
                  │ Loan              │
                  │ Card              │
                  └─────────┬─────────┘
                            │
                         dbt / SQL
                            │
                            ▼
                  ┌───────────────────┐
                  │       GOLD        │
                  │                   │
                  │ Customer 360      │
                  │ Loan Analytics    │
                  │ Merchant Analytics│
                  │ Payment Analytics │
                  │ Risk Analytics    │
                  └─────────┬─────────┘
                            │
             ┌──────────────┼───────────────┐
             ▼              ▼               ▼
            BI             AI          Regulatory
```

---

# 7. And Airflow sits above all of this

Airflow isn't another data layer.

It's the **orchestrator**.

For example:

```text
                       AIRFLOW
                          │
       ┌──────────────────┼─────────────────┐
       │                  │                 │
       ▼                  ▼                 ▼
 Bronze ingestion    Silver processing   Gold models
       │                  │                 │
       ▼                  ▼                 ▼
    Kafka/CDC          Spark/SQL           dbt
                          │
                          ▼
                    Data Quality
```

Airflow could say:

```text
01:00
  ↓
Check Kafka ingestion
  ↓
Load Bronze
  ↓
Validate Bronze
  ↓
Build Silver
  ↓
Run Silver data quality
  ↓
Build Gold
  ↓
Run Gold data quality
  ↓
Refresh BI
  ↓
Generate regulatory datasets
```

---

# 8. One important banking example

Imagine **a $500 KHQR payment**.

### Source

```text
Customer → KHQR → Merchant
```

### Bronze

```text
Raw KHQR event

TXN_ID = KH123
MERCHANT = M001
AMOUNT = 500
TIME = ...
STATUS = SUCCESS
```

### Silver

Standardize:

```text
transaction_id = KH123
merchant_id = M001
amount = 500
currency = USD
transaction_status = SUCCESS
transaction_datetime = ...
```

### Gold

Aggregate:

```text
Merchant M001

Today revenue       $18,500
30-day revenue      $420,000
Transactions        8,421
Avg transaction     $49.87
Revenue growth      +12%
```

### AI

Now the bank can combine that with:

```text
Merchant revenue
       +
Account balances
       +
Loan repayments
       +
Deposit behavior
       +
Other transactions
       ↓
SME risk model
       ↓
Early-warning score
```

That's the real value of the architecture.

---

# 9. One correction to the original diagram

I would therefore modify the original diagram from:

```text
Kafka
  │
  ├── DWH/Lake
  │
  └── Real-time
```

to:

```text
                           KAFKA
                             │
                ┌────────────┴─────────────┐
                │                          │
                ▼                          ▼
          DATA LAKE / LAKEHOUSE        REAL-TIME
                │                     PROCESSING
                │                          │
             BRONZE                       │
                ↓                         │
             SILVER                       │
                ↓                         │
              GOLD                        │
                │                         │
                ▼                         ▼
          DWH / DATA MARTS          Fraud / Risk /
                │                   Real-time alerts
        ┌───────┼────────┐
        ▼       ▼        ▼
       BI      AI    Regulatory
```

And **Airflow sits across the batch/data-processing side as the orchestrator**.

### The mental model I'd recommend you remember

**Bronze:** *What did we receive?*
**Silver:** *Can we trust and consistently understand it?*
**Gold:** *What does the business need from it?*
**DWH/Data Marts:** *How do we serve governed analytics efficiently?*
**Kafka:** *How do we move events/data?*
**Airflow:** *When and in what order should things happen?*
**Spark/dbt/SQL:** *How do we transform the data?*
**BI/AI:** *How do we use the data?*

This is a much stronger way to explain the architecture in a **Data Architect interview at a bank** than simply saying "we use ETL + DWH."

Gold contains business data right...what is data mart then?

Exactly. **Gold contains business-ready data**, so your question is very important:

> If Gold already contains business data, why do we need a Data Mart?

The answer is: **Gold and Data Mart can overlap, and in a modern Lakehouse architecture you may not need a separate Data Mart layer.**

### Think of it this way

**Gold = business-ready data**

**Data Mart = a curated subset of data designed for a specific business domain/use case.**

For example:

```text
                    SILVER
                       │
                       ▼
                     GOLD
                       │
       ┌───────────────┼────────────────┐
       ▼               ▼                ▼
   Customer Gold    Loan Gold      Merchant Gold
       │               │                │
       ▼               ▼                ▼
 Customer Mart     Loan Mart      Merchant Mart
       │               │                │
       ▼               ▼                ▼
      CRM             Risk          SME Analytics
```

But again, **you don't necessarily need both**.

---

# 1. What is Gold?

Gold is where you turn cleaned data into **business-oriented datasets**.

Suppose Silver contains:

```text
SILVER_TRANSACTION

transaction_id
customer_id
account_id
merchant_id
transaction_date
amount
currency
transaction_type
channel
status
```

Gold might create:

```text
GOLD_CUSTOMER_TRANSACTION

customer_id
transaction_date
total_debit
total_credit
transaction_count
average_transaction
```

Or:

```text
GOLD_MERCHANT_PERFORMANCE

merchant_id
daily_revenue
monthly_revenue
transaction_count
average_transaction
revenue_growth
```

These are already **business data**.

---

# 2. So what is a Data Mart?

A Data Mart is usually a **smaller, purpose-specific analytical dataset/store**.

Imagine Sathapana has a huge enterprise data platform:

```text
                   ENTERPRISE DATA
                         │
                         ▼
                       GOLD
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
       ▼                 ▼                 ▼
   Retail Banking     Corporate        Risk
       │              Banking           │
       ▼                 ▼              ▼
   Retail Mart       Corp Mart       Risk Mart
```

The **Risk Data Mart** might contain only the information required by Risk:

```text
RISK MART
──────────────────────────
Customer
Loan
Collateral
Repayment
Outstanding balance
Days past due
Credit score
Risk grade
NPL status
```

It doesn't need every merchant transaction, card authorization message, or marketing attribute.

---

# 3. A very simple analogy

Think of a supermarket.

### Gold

Gold is the **entire organized supermarket**:

```text
Customers
Accounts
Loans
Transactions
Cards
Merchants
Payments
Branches
```

### Data Mart

A Data Mart is like a **department**:

```text
🥩 Risk Department
💳 Cards Department
🏦 Loan Department
👥 Customer Department
🛒 Merchant Department
```

Each department gets the data it needs.

---

# 4. Why create Data Marts?

There are several reasons.

### Performance

A BI dashboard shouldn't necessarily query billions of raw/Gold transactions every time.

Instead:

```text
Gold
  ↓
Risk Mart
  ↓
Risk Dashboard
```

The mart can be optimized specifically for reporting.

---

### Security

This is particularly important in banking.

Marketing might need:

```text
Customer
Product
Balance
Transaction behavior
```

But they shouldn't necessarily see:

```text
Collateral
Credit assessment
AML investigation
Internal risk indicators
```

So you can provide:

```text
Marketing Data Mart
```

with only the required columns.

---

### Business ownership

Different departments need different datasets:

```text
                   GOLD
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
     Risk          Finance       Marketing
       │             │             │
       ▼             ▼             ▼
   Risk Mart      Finance Mart   Marketing Mart
```

This makes governance easier.

---

# 5. Gold vs Data Mart

Here's the distinction I would use in an interview:

|              | Gold                      | Data Mart                       |
| ------------ | ------------------------- | ------------------------------- |
| Purpose      | Business-ready data       | Domain/use-case-specific data   |
| Scope        | Broad                     | Narrow                          |
| Audience     | Multiple consumers        | Specific business team          |
| Example      | Customer 360              | Credit Risk Mart                |
| Contains     | Business entities/metrics | Specialized subset              |
| Security     | General governed layer    | Can have domain-specific access |
| Optimization | General analytics         | Specific reporting/use case     |

---

# 6. But here's the important modern architecture point

You **don't have to build Gold → Data Mart as two physically separate layers**.

Modern platforms often do:

```text
Bronze
   ↓
Silver
   ↓
Gold
   ├── Customer Analytics
   ├── Loan Analytics
   ├── Risk Analytics
   └── Merchant Analytics
```

Those Gold datasets **are effectively data marts** from a logical perspective.

For example:

```text
GOLD
│
├── customer_360
├── loan_portfolio
├── merchant_performance
├── card_performance
└── branch_performance
```

You could call these **Gold data products**, **marts**, or **analytical models**, depending on your architecture terminology.

---

# 7. When would you actually create a separate Data Mart?

Suppose Sathapana has:

```text
                   GOLD
                     │
                     ▼
              Loan Portfolio
                     │
                     ▼
                Risk Mart
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
       Risk BI    Regulatory    Risk AI
```

The Risk Mart could contain highly optimized and governed data specifically for Risk.

Similarly:

```text
Gold Merchant Data
       ↓
SME Lending Mart
       ↓
SME Credit Dashboard
       ↓
SME Lending Model
```

This makes sense because the **SME Lending team has a specific analytical requirement**.

---

# 8. So I would modify our previous architecture

Instead of forcing a separate DWH/Data Mart layer, I'd show it like this:

```text
                         SOURCES
                            │
                     CDC / APIs / Events
                            │
                          Kafka
                            │
                            ▼
                     ┌─────────────┐
                     │   BRONZE    │
                     │ Raw data    │
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │   SILVER    │
                     │ Cleaned     │
                     │ Standardized│
                     └──────┬──────┘
                            │
                            ▼
                     ┌─────────────┐
                     │    GOLD     │
                     │ Business    │
                     │ Ready       │
                     └──────┬──────┘
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
        Customer Gold   Loan Gold     Merchant Gold
             │              │              │
             ▼              ▼              ▼
        Customer Mart   Risk Mart     SME Mart
             │              │              │
             ▼              ▼              ▼
            BI             AI        Business Apps
```

And even the bottom layer is optional:

```text
Gold → BI
Gold → AI
```

may be perfectly sufficient.

### The key thing to remember

**Gold answers:**

> "What business-ready information do we have?"

**Data Mart answers:**

> "What specific subset of that business-ready information does this department/use case need?"

So, **Gold is a layer; a Data Mart is a purpose-oriented dataset/model**. They aren't necessarily competing concepts, and a well-designed modern lakehouse may make Gold datasets serve directly as the marts.

Clarify the architecture boundary

* Show a bank example

Bronze Silver and Gold all reside in the SQL server database right? 

**Not necessarily.** This is one of the most important distinctions in modern data architecture.

Bronze, Silver, and Gold are **logical data layers**, not necessarily three schemas/databases inside SQL Server.

### Traditional SQL Server DWH

You *could* implement them all inside SQL Server:

```text
SQL Server
│
├── Bronze schema
│     └── raw_customer
│
├── Silver schema
│     └── customer
│
└── Gold schema
      └── customer_360
```

For example:

```text
SQL Server
   │
   ├── bronze
   │    ├── customer_raw
   │    ├── account_raw
   │    └── transaction_raw
   │
   ├── silver
   │    ├── customer
   │    ├── account
   │    └── transaction
   │
   └── gold
        ├── customer_360
        ├── loan_portfolio
        └── merchant_performance
```

**Yes, this is possible.**

---

# But modern Lakehouse architecture is different

You could instead have:

```text
                  Data Lake / Lakehouse
                         │
             ┌───────────┼───────────┐
             ▼           ▼           ▼
          Bronze       Silver       Gold
             │           │           │
          Parquet      Parquet     Tables
          /Delta       /Delta      /Delta
```

The physical storage might be:

```text
Object Storage
│
├── bronze/
├── silver/
└── gold/
```

For example:

```text
S3 / Azure Data Lake / MinIO
│
├── bronze/
│    └── transactions/
│
├── silver/
│    └── transactions/
│
└── gold/
     └── merchant_performance/
```

Then tools such as Spark, Trino, DuckDB, etc. can work with those datasets.

---

# What about a DWH?

A common architecture is:

```text
                    Kafka
                      │
                      ▼
                Object Storage
                      │
              ┌───────┴───────┐
              ▼               ▼
           Bronze           Silver
                              │
                              ▼
                            Gold
                              │
                              ▼
                       Data Warehouse
                              │
                        ┌─────┼─────┐
                        ▼     ▼     ▼
                       BI     AI   Reports
```

Here:

**Data Lake/Lakehouse** → Bronze/Silver/Gold

**Data Warehouse** → highly structured analytical serving layer

But even this isn't a strict rule. Modern lakehouse platforms can make Gold directly available to BI, so a separate DWH may not be necessary.

---

# For your Sathapana architecture

I'd avoid saying:

> "Bronze, Silver and Gold are SQL Server databases."

Instead, say:

> **"Bronze, Silver and Gold are logical data layers. Their physical implementation can be SQL Server schemas/tables, object storage files, lakehouse tables, or a combination depending on the platform."**

For example, if Sathapana has an existing SQL Server environment:

```text
                    SOURCES
                       │
                  CDC / APIs
                       │
                     Kafka
                       │
                       ▼
                ┌─────────────┐
                │   BRONZE    │
                │ SQL Server  │
                │ or Lake     │
                └──────┬──────┘
                       ▼
                ┌─────────────┐
                │   SILVER    │
                │ SQL Server  │
                │ or Lakehouse│
                └──────┬──────┘
                       ▼
                ┌─────────────┐
                │    GOLD     │
                │ DWH/Lakehouse│
                └──────┬──────┘
                       │
             ┌─────────┼─────────┐
             ▼         ▼         ▼
            BI        AI     Regulatory
```

### One more important point

If you're designing a **new modern bank data platform**, I wouldn't automatically choose SQL Server for all three layers.

I'd first decide:

**Do we want a traditional DWH, a Lakehouse, or a hybrid?**

For the kind of **CDC + Kafka + AI + analytics architecture** we've been discussing, a **Lakehouse + analytical warehouse/serving layer** can be more flexible than putting everything into SQL Server.

Clarify the physical layout

* Show a hybrid SQL Server + lakehouse design

Show a hybrid architecture where SQL Server stores operational and serving data, while Bronze, Silver, and Gold use a lakehouse.

Yes. For a bank, a **hybrid architecture** can be a very practical design:

* **Operational SQL Server** → runs transactional/operational applications.
* **Lakehouse** → keeps large-scale Bronze/Silver/Gold analytical data.
* **Serving SQL Server** → exposes selected, optimized business datasets to applications/BI that need SQL access.
* **Kafka** → transports changes/events.
* **Airflow** → orchestrates batch workflows.
* **Spark/dbt/SQL** → transforms data.

## Recommended architecture

```text
                         OPERATIONAL SYSTEMS
                                │
             ┌──────────────────┼──────────────────┐
             │                  │                  │
        Core Banking          Cards           Merchant/KHQR
             │                  │                  │
             └──────────────────┼──────────────────┘
                                │
                         CDC / APIs / Events
                                │
                                ▼
                             KAFKA
                                │
               ┌────────────────┼─────────────────┐
               │                                  │
               ▼                                  ▼
       ┌─────────────────┐                 Real-Time Layer
       │   LAKEHOUSE     │                 ┌──────────────┐
       │                 │                 │ Fraud/Risk   │
       │     BRONZE      │                 │ Alerts       │
       │       ↓         │                 └──────────────┘
       │     SILVER      │
       │       ↓         │
       │      GOLD       │
       └────────┬────────┘
                │
                │
        ┌───────┴────────┐
        │                │
        ▼                ▼
   Data Products     Serving Layer
        │                │
        │                ▼
        │        ┌──────────────────┐
        │        │ SQL SERVER      │
        │        │ SERVING         │
        │        │                  │
        │        │ Customer 360    │
        │        │ Loan Analytics  │
        │        │ Merchant Data   │
        │        │ BI datasets     │
        │        └────────┬─────────┘
        │                 │
        └────────┬────────┘
                 ▼
       ┌─────────┼──────────┐
       ▼         ▼          ▼
      BI        AI      Applications
```

---

# 1. First: Operational SQL Server

Don't confuse this SQL Server with the analytical serving SQL Server.

Your bank may have operational applications using SQL Server:

```text
                  OPERATIONAL SQL SERVER
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
        Customer        Account          Loan
        Service         Service         Service
```

For example:

```text
CUSTOMER
ACCOUNT
LOAN
PAYMENT
MERCHANT
```

These databases support **day-to-day banking operations**.

A customer opening an account, making a payment, updating their profile, etc. happens here.

You don't want your heavy analytics queries competing with these workloads.

---

# 2. CDC captures changes

Suppose this happens:

```text
Customer pays $500
        │
        ▼
Operational database
        │
        │ INSERT / UPDATE
        ▼
       CDC
```

CDC captures the database change.

For example:

```text
Account A001
Old balance: 10,000
New balance: 9,500
```

Debezium is one possible CDC technology.

---

# 3. Kafka becomes the central event backbone

```text
Operational DB
      │
     CDC
      │
      ▼
    Kafka
```

You might have topics such as:

```text
customer_changes
account_changes
loan_changes
transaction_events
card_transactions
merchant_payments
khqr_transactions
```

Now multiple downstream systems can consume those events.

---

# 4. Bronze — raw lakehouse data

Kafka feeds the lakehouse.

```text
Kafka
  │
  ▼
┌────────────────────┐
│      BRONZE        │
│                    │
│ Raw source data    │
│ Raw CDC events     │
│ Raw API events     │
└────────────────────┘
```

The important idea is:

> **Don't destroy the original information unnecessarily.**

For example:

```text
bronze/
   cbs/
      customer/
      account/
      transaction/

   cards/
      authorization/
      transaction/

   khqr/
      payment/

   merchant/
      payment/
```

This gives you a historical/raw foundation.

---

# 5. Silver — trusted standardized data

Next:

```text
Bronze
   │
   ▼
Spark / SQL
   │
   ▼
Silver
```

Silver handles things such as:

* data type standardization
* deduplication
* validation
* schema normalization
* reference-data mapping
* handling bad records
* common business definitions

For example:

```text
BRONZE
"USD"
"KHR"
"USD "

       ↓

SILVER

currency_code
-------------
USD
KHR
```

You now have **trusted, standardized data**.

---

# 6. Gold — business-ready data

Then:

```text
Silver
   │
   ▼
dbt / Spark / SQL
   │
   ▼
Gold
```

Gold could contain:

```text
customer_360
customer_profitability
loan_portfolio
merchant_performance
card_performance
branch_performance
deposit_analytics
payment_analytics
```

For example:

```text
GOLD_MERCHANT_PERFORMANCE

merchant_id
daily_revenue
monthly_revenue
transaction_count
average_transaction
revenue_growth
active_days
```

This is now directly meaningful to business users.

---

# 7. Why send Gold into SQL Server?

This is the interesting part of the hybrid architecture.

Suppose the bank has existing applications and BI tools that work very well with SQL Server.

Instead of making every application query the lakehouse directly:

```text
Application
     │
     ▼
Lakehouse
```

you can create a **serving layer**:

```text
Gold
 │
 ▼
SQL Server Serving
 │
 ├── Customer 360
 ├── Loan Analytics
 ├── Merchant Analytics
 └── Reporting datasets
```

The SQL Server here is optimized for **consumption**, not operational transactions.

---

# 8. Operational SQL Server vs Serving SQL Server

This distinction is extremely important.

### Operational SQL Server

```text
Purpose:
Run banking applications

Workload:
OLTP

Examples:
Customer updates
Account transactions
Loan payments
Merchant operations
```

### Serving SQL Server

```text
Purpose:
Serve analytical/business datasets

Workload:
Read-heavy

Examples:
Customer 360
Management dashboards
Business APIs
Reporting
Analytics applications
```

Don't put both workloads on the same database if you can avoid it.

---

# 9. The complete physical flow

I'd draw the architecture like this for a Data Architect interview:

```text
                         ┌──────────────────────┐
                         │   OPERATIONAL DBs    │
                         │                      │
                         │ Core Banking         │
                         │ Cards                │
                         │ Merchant/KHQR        │
                         └──────────┬───────────┘
                                    │
                              CDC / APIs
                                    │
                                    ▼
                              ┌───────────┐
                              │   KAFKA   │
                              └─────┬─────┘
                                    │
             ┌──────────────────────┼─────────────────────┐
             │                      │                     │
             ▼                      ▼                     ▼
       ┌───────────┐        Real-Time Processing    Other Consumers
       │  BRONZE   │
       └─────┬─────┘
             │
             ▼
       ┌───────────┐
       │  SILVER   │
       └─────┬─────┘
             │
             ▼
       ┌───────────┐
       │   GOLD    │
       └─────┬─────┘
             │
       ┌─────┴─────────────┐
       │                   │
       ▼                   ▼
 Data Products       SQL Server Serving
       │                   │
       │             ┌─────┼──────┐
       │             ▼     ▼      ▼
       │           BI   APIs   Reports
       │
       ├──────────────► AI / ML
       │
       └──────────────► Analytics
```

And **Airflow sits above the batch processing pipeline**:

```text
                    AIRFLOW
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
    Bronze jobs    Silver jobs     Gold jobs
        │              │              │
        ▼              ▼              ▼
      Spark          Spark/dbt      dbt/SQL
                       │              │
                       └──────┬───────┘
                              ▼
                       Data Quality
                              │
                              ▼
                       SQL Serving
```

---

# 10. Where does the Data Warehouse fit?

This is where you have an architectural choice.

### Option 1 — Lakehouse is your analytical platform

```text
Bronze
  ↓
Silver
  ↓
Gold
  ↓
BI / AI
```

No traditional DWH is necessary.

### Option 2 — Lakehouse + SQL Server DWH/Serving

```text
Bronze
  ↓
Silver
  ↓
Gold
  ↓
SQL Server Analytical/Serving
  ↓
BI / Applications
```

This is the **hybrid architecture you're asking about**.

### Option 3 — Lakehouse + dedicated cloud/MPP warehouse

For example:

```text
Bronze
  ↓
Silver
  ↓
Gold
  ↓
Analytical Warehouse
  ↓
BI / AI
```

The warehouse doesn't have to be SQL Server.

---

# For Sathapana, why I like the hybrid approach

If the bank already has significant SQL Server investment, you don't need to throw it away.

You can modernize around it:

```text
                    EXISTING BANK
                         │
                  Operational DB
                         │
                         ▼
                       CDC
                         │
                         ▼
                       Kafka
                         │
                         ▼
                    LAKEHOUSE
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
           Bronze      Silver      Gold
                                   │
                         ┌─────────┴─────────┐
                         ▼                   ▼
                 SQL Server Serving      Data Science
                         │                   │
                    ┌────┼────┐             ▼
                    ▼    ▼    ▼             AI/ML
                   BI   APIs Reports
```

This gives you a nice separation:

**Operational DB**
→ *Run the bank*

**Kafka**
→ *Move events/data*

**Lakehouse Bronze**
→ *Preserve raw data*

**Lakehouse Silver**
→ *Create trusted data*

**Lakehouse Gold**
→ *Create business-ready data*

**SQL Server Serving**
→ *Serve frequently accessed datasets to BI/apps*

**AI/ML**
→ *Build models from the analytical data*

**Airflow**
→ *Coordinate the whole batch pipeline*

That is a very defensible **modern-but-pragmatic bank data architecture**.

Clarify the serving boundary

* Show the SQL Server schemas

Someone said like

We have layers of db that have different purpose! like SQL Server for Data Stagging and Facts! then PostgreSQL for Datamart

Yes — what that person said is **a valid architecture pattern**, but it is different from the Bronze/Silver/Gold lakehouse architecture we were discussing.

They are basically saying:

> **Use different database technologies for different workloads.**

For example:

```text
                 SOURCE SYSTEMS
        Core Banking / Cards / KHQR
                     │
                     ▼
              SQL Server
          ┌───────────────────┐
          │ Staging           │
          │ Fact Tables       │
          │ Dimension Tables  │
          └───────────────────┘
                     │
                     ▼
                PostgreSQL
          ┌───────────────────┐
          │ Data Marts        │
          │ Risk Mart         │
          │ Loan Mart         │
          │ Customer Mart     │
          │ SME Mart          │
          └───────────────────┘
                     │
                     ▼
              BI / Analytics
```

### Why use SQL Server first?

SQL Server might be used as the **enterprise DWH / integration layer**.

For example:

```text
SQL Server

staging.customer
staging.account
staging.transaction

dim_customer
dim_account
dim_branch

fact_transaction
fact_loan_payment
fact_card_transaction
fact_merchant_payment
```

The **fact tables** contain measurable business events:

```text
fact_transaction
----------------------------
customer_id
account_id
transaction_date
amount
transaction_type
channel
branch_id
merchant_id
```

This layer is relatively broad and reusable.

### Then why PostgreSQL for Data Marts?

PostgreSQL could be used as a **serving/data-mart database**.

For example:

```text
PostgreSQL

loan_mart
----------------
customer_id
outstanding_balance
days_past_due
monthly_income
monthly_payment
risk_score

merchant_mart
----------------
merchant_id
monthly_sales
transaction_count
avg_ticket
growth_rate
loan_balance

customer_360
----------------
customer_id
deposit_balance
loan_balance
card_spend
merchant_spend
risk_score
```

The idea is that different teams don't have to query huge enterprise fact tables every time.

---

## Think of it this way

| Layer                | Technology                      | Purpose                                |
| -------------------- | ------------------------------- | -------------------------------------- |
| Source/OLTP          | SQL Server/Core Banking DB etc. | Run banking applications               |
| Staging              | SQL Server                      | Temporary/raw ingestion                |
| DWH Facts/Dimensions | SQL Server                      | Enterprise analytical data             |
| Data Mart            | PostgreSQL                      | Department/use-case-specific analytics |
| BI                   | Power BI/Tableau/etc.           | Visualization                          |
| AI/ML                | Python/Spark/etc.               | Models and predictions                 |

So the statement:

> "SQL Server for Data Staging and Facts, PostgreSQL for Data Mart"

**makes architectural sense.**

But there is an important question:

### Why PostgreSQL?

PostgreSQL isn't inherently a "Data Mart database."

You could implement the data mart in:

* SQL Server
* PostgreSQL
* Snowflake
* Databricks
* BigQuery
* Oracle
* ClickHouse
* etc.

The choice depends on **workload, cost, performance, existing skills, governance, and infrastructure**.

---

# How this relates to our Lakehouse architecture

This is where the terminology can become confusing.

The architecture we discussed earlier was:

```text
Sources
   │
   ▼
Kafka / CDC
   │
   ▼
Lakehouse
   │
   ├── Bronze
   ├── Silver
   └── Gold
          │
          ▼
      SQL Server
       Serving
          │
          ▼
        BI/AI
```

The architecture your colleague described is more like:

```text
Sources
   │
   ▼
SQL Server
   │
   ├── Staging
   ├── Facts
   └── Dimensions
          │
          ▼
     PostgreSQL
       Data Marts
          │
          ▼
         BI
```

Both are legitimate.

---

## One important distinction

Don't think:

> Bronze = SQL Server
> Silver = SQL Server
> Gold = PostgreSQL

That's **not necessarily correct**.

Bronze/Silver/Gold describe **logical data layers**.

Staging/Fact/Dimension/Data Mart describe **data architecture/modeling concepts**.

They can overlap, but they aren't exactly the same thing.

For example:

```text
                LOGICAL
              DATA LAYERS

                 Bronze
                    │
                 Silver
                    │
                  Gold
                    │
                    ▼

              PHYSICAL
              TECHNOLOGY

        SQL Server / PostgreSQL /
        Iceberg / Delta / etc.
```

---

# For Sathapana, I would consider a hybrid like this

Given a bank environment, a very practical architecture could be:

```text
                   BANKING SOURCES
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    Core Banking       Cards        Merchant/KHQR
        │                │                │
        └────────────────┼────────────────┘
                         ▼
                    CDC / APIs
                         │
                         ▼
                       Kafka
                         │
                         ▼
                 ┌───────────────┐
                 │   Lakehouse   │
                 │               │
                 │   Bronze      │
                 │      ↓        │
                 │   Silver      │
                 │      ↓        │
                 │    Gold       │
                 └───────┬───────┘
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
       SQL Server                PostgreSQL
      Enterprise DWH             Data Marts
             │                       │
       Facts/Dimensions       Loan Mart
             │                Risk Mart
             │                SME Mart
             │                Customer 360
             │                       │
             └───────────┬───────────┘
                         ▼
                    BI / Analytics
```

This gives you **two different ideas together**:

### Lakehouse

Good for:

* historical raw data
* large volumes
* AI/ML
* data science
* reprocessing
* unstructured/semi-structured data
* long-term data retention

### SQL Server DWH

Good for:

* enterprise facts/dimensions
* existing SQL Server ecosystem
* standardized reporting
* regulatory reporting
* structured analytical workloads

### PostgreSQL Data Mart

Good for:

* application-facing analytics
* departmental marts
* customer 360 APIs
* SME analytics
* loan analytics
* lightweight/highly customized analytical serving

---

### The key question I would ask the person

If someone tells you:

> "SQL Server is for staging and facts, PostgreSQL is for data marts."

Ask:

**"What workload or limitation drove us to use PostgreSQL for the data marts instead of SQL Server?"**

That's the architect-level question.

If the answer is **performance, cost, application integration, workload isolation, team expertise, or a specific PostgreSQL capability**, then the design may be justified.

If the answer is simply **"because PostgreSQL is for data marts"**, that's not really an architectural reason.

Clarify the physical boundaries

* Show the PostgreSQL data marts

SQL Server does not work well with Analytical query?

Not at all. **SQL Server works very well for analytical queries.** In fact, SQL Server is widely used as a data warehouse and analytical platform.

The important point is that **SQL Server is not automatically bad at analytics**. Performance depends heavily on **how the data is modeled, indexed, partitioned, stored, and queried**.

### Simple example

Suppose Sathapana has:

* 5 million customers
* 50 million accounts
* 1 billion transactions

You might have:

```text
fact_transaction
-----------------------------
transaction_id
customer_id
account_id
transaction_date
amount
channel
merchant_id
```

A query such as:

```sql
SELECT
    customer_id,
    SUM(amount) AS total_spend
FROM fact_transaction
WHERE transaction_date >= '2026-01-01'
GROUP BY customer_id;
```

is an analytical query, and **SQL Server can handle this very well** when the warehouse is designed properly.

---

## So why would someone use PostgreSQL for Data Mart?

Usually **not because SQL Server cannot do analytics**.

There might be other reasons:

```text
SQL Server
     ↓
Enterprise DWH
     ↓
PostgreSQL
     ↓
Specific Data Mart
```

For example, PostgreSQL could isolate workloads:

| SQL Server DWH       | PostgreSQL Data Mart           |
| -------------------- | ------------------------------ |
| Enterprise-wide data | Department/use-case specific   |
| Huge fact tables     | Smaller curated datasets       |
| ETL/DWH processing   | BI/application serving         |
| Historical data      | Frequently accessed aggregates |
| Regulatory reporting | Customer 360 API               |
| Central governance   | Flexible domain-specific model |

So PostgreSQL can act as a **serving layer**, rather than being chosen because it is inherently better at analytics.

---

## But there is another important consideration: columnstore

This is where SQL Server becomes particularly interesting for banking analytics.

SQL Server supports **columnstore indexes**, which are specifically designed to accelerate analytical workloads involving large tables and aggregations.

Conceptually:

```text
Traditional row storage

Transaction 1 → customer | date | amount | merchant | channel
Transaction 2 → customer | date | amount | merchant | channel
Transaction 3 → customer | date | amount | merchant | channel


Columnstore

customer → [C1,C2,C3,C4...]
date     → [D1,D2,D3,D4...]
amount   → [A1,A2,A3,A4...]
merchant → [M1,M2,M3,M4...]
```

If your query only needs:

```sql
SUM(amount)
GROUP BY merchant_id
```

a column-oriented structure can avoid reading unnecessary columns.

That's extremely useful for large banking fact tables.

---

# The bigger architectural question

I would **not** recommend:

> "SQL Server = bad for analytics → PostgreSQL = good for analytics."

That's an oversimplification.

Instead:

> **SQL Server can absolutely be an analytical/DWH platform. PostgreSQL can also be used for analytical serving. The decision should be based on workload and architecture, not simply on which database is 'better for analytics.'**

For your Sathapana Data Architect discussion, I'd actually ask:

**"Why do we need PostgreSQL Data Mart if SQL Server already contains the enterprise facts and dimensions? Is PostgreSQL being used for workload isolation, application serving, performance, cost, or a specific technical requirement?"**

That question will tell you **why their architecture has two databases**, rather than just accepting that "Data Mart = PostgreSQL."

Clarify the database roles

* Compare SQL Server and PostgreSQL for data marts

                   BANKING SOURCES
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    Core Banking       Cards        Merchant/KHQR
        │                │                │
        └────────────────┼────────────────┘
                         ▼
                    CDC / APIs
                         │
                         ▼
                       Kafka
                         │
                         ▼
                 ┌───────────────┐
                 │   Lakehouse   │
                 │               │
                 │   Bronze      │
                 │      ↓        │
                 │   Silver      │
                 │      ↓        │
                 │    Gold       │
                 └───────┬───────┘
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
       SQL Server                PostgreSQL
      Enterprise DWH             Data Marts
             │                       │
       Facts/Dimensions       Loan Mart
             │                Risk Mart
             │                SME Mart
             │                Customer 360
             │                       │
             └───────────┬───────────┘
                         ▼
                    BI / Analytics

Pls tell me an example for lake house bronze Silver Gold and SQL server DWH facts dimensions

Absolutely. Let's use **one concrete Sathapana banking example: a KHQR merchant transaction**, and follow that same transaction through **Bronze → Silver → Gold → SQL Server DWH Facts/Dimensions**.

## 1. Start with the source transaction

Imagine a customer pays a merchant **KHR 50,000 through KHQR**.

The source systems may produce something like:

```text
Core Banking
-------------
Customer ID: C10025
Account: 001-123456
Balance: 2,000,000 KHR

Merchant/KHQR
-------------
Merchant ID: M5008
Transaction ID: TX90001
Amount: 50,000 KHR
Date: 2026-09-13
Time: 10:15:32
Channel: KHQR
Status: SUCCESS
```

The data comes through CDC/API/events → Kafka.

Now let's see what happens.

---

# 2. Bronze — Raw data

**Bronze means: "Keep what came from the source."**

We don't try to make the data beautiful yet.

For example, the Kafka event might be stored in the lakehouse as:

```text
bronze/merchant_transactions/
```

And the record could look like:

```json
{
  "transactionId": "TX90001",
  "merchantId": "M5008",
  "customerId": "C10025",
  "amount": "50000",
  "currency": "KHR",
  "transactionDate": "2026-09-13",
  "transactionTime": "10:15:32",
  "channel": "KHQR",
  "status": "SUCCESS",
  "source": "KHQR",
  "eventTime": "2026-09-13T10:15:32"
}
```

Maybe another source sends:

```json
{
  "txn_id": "TX90002",
  "merchant_id": "M5008",
  "amt": 25000,
  "ccy": "KHR",
  "status": "S"
}
```

**Bronze preserves this source structure.**

You generally don't want to immediately destroy or overwrite the original data because you may need it later for:

* reprocessing
* auditing
* troubleshooting
* historical reconstruction
* new business rules

Think:

> **Bronze = "What did the source actually send us?"**

---

# 3. Silver — Clean and standardized

Now we transform Bronze into **trusted, standardized data**.

For example:

```text
Silver: merchant_transaction
--------------------------------
transaction_id
merchant_id
customer_id
transaction_timestamp
amount
currency
channel
transaction_status
source_system
```

Our previous data becomes:

| transaction_id | merchant_id | customer_id | amount | currency | channel | status  |
| -------------- | ----------- | ----------- | -----: | -------- | ------- | ------- |
| TX90001        | M5008       | C10025      | 50,000 | KHR      | KHQR    | SUCCESS |
| TX90002        | M5008       | C10025      | 25,000 | KHR      | KHQR    | SUCCESS |

Here we might have performed:

```text
"amt" → amount
"ccy" → currency
"S" → SUCCESS
date + time → timestamp
```

We can also:

* remove duplicates
* validate data types
* standardize currencies
* handle invalid records
* standardize customer IDs
* standardize merchant IDs
* apply data-quality rules

Think:

> **Silver = "Can I trust this data?"**

---

# 4. Gold — Business-ready information

Now we apply **business logic**.

For example, Sathapana wants to understand merchant performance.

Instead of giving BI users billions of individual transactions, we create:

```text
gold.merchant_daily_summary
```

Example:

| date       | merchant_id | total_transactions | total_sales | avg_transaction |
| ---------- | ----------- | -----------------: | ----------: | --------------: |
| 2026-09-13 | M5008       |                125 |   8,750,000 |          70,000 |
| 2026-09-13 | M5010       |                 87 |   4,200,000 |          48,276 |

Now we're answering a **business question**:

> "How much did each merchant sell today?"

Another Gold dataset could be:

```text
gold.customer_360
```

```text
customer_id
----------------
C10025

deposit_balance       2,000,000
monthly_spending        850,000
monthly_income        3,500,000
loan_balance          8,500,000
credit_card_spend       450,000
khqr_spend              120,000
risk_score               0.72
```

Think:

> **Gold = "What business information do we need?"**

---

# 5. Now where does SQL Server DWH come in?

This is the important part.

You could take selected Gold data and build a traditional **enterprise data warehouse in SQL Server**.

Instead of putting everything into SQL Server, we might load the **curated, governed, structured data** needed for enterprise reporting.

The DWH usually contains:

```text
SQL SERVER DWH

        Dimensions
             │
             │
             ▼
       Fact Tables
```

---

# 6. Dimension tables

A **dimension describes something**.

For example:

### `dim_customer`

```text
customer_key
customer_id
customer_name
gender
date_of_birth
customer_segment
occupation
branch
customer_since
```

Example:

| customer_key | customer_id | segment | occupation     | branch     |
| -----------: | ----------- | ------- | -------------- | ---------- |
|         1001 | C10025      | MASS    | Engineer       | Phnom Penh |
|         1002 | C10026      | SME     | Business Owner | Kandal     |

---

### `dim_merchant`

```text
merchant_key
merchant_id
merchant_name
merchant_category
province
merchant_segment
onboarding_date
```

Example:

| merchant_key | merchant_id | merchant_category | province   |
| -----------: | ----------- | ----------------- | ---------- |
|          501 | M5008       | Restaurant        | Phnom Penh |
|          502 | M5010       | Grocery           | Kandal     |

---

### `dim_date`

This is extremely common in data warehouses.

```text
date_key
full_date
day
month
quarter
year
week
```

Example:

| date_key | full_date  | month     | quarter | year |
| -------: | ---------- | --------- | ------- | ---: |
| 20260913 | 2026-09-13 | September | Q3      | 2026 |

---

# 7. Fact table

A **fact records a business event or measurable activity**.

For our KHQR example:

```text
fact_merchant_transaction
```

could contain:

```text
transaction_key
customer_key
merchant_key
date_key
amount
transaction_count
channel_key
status_key
```

Example:

| transaction_key | customer_key | merchant_key | date_key |  amount |
| --------------: | -----------: | -----------: | -------: | ------: |
|           90001 |         1001 |          501 | 20260913 |  50,000 |
|           90002 |         1001 |          501 | 20260913 |  25,000 |
|           90003 |         1002 |          502 | 20260913 | 100,000 |

Notice something important:

**The fact table doesn't necessarily contain descriptive information like the merchant's name.**

Instead:

```text
fact_merchant_transaction
          │
          ├── customer_key ──→ dim_customer
          │
          ├── merchant_key ──→ dim_merchant
          │
          └── date_key ──────→ dim_date
```

This is the classic **star schema**.

---

# 8. So what happened to our original transaction?

Let's follow it end-to-end.

```text
KHQR Transaction
50,000 KHR
     │
     ▼
    Kafka
     │
     ▼
┌─────────────┐
│   BRONZE    │
│ Raw event   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   SILVER    │
│ Cleaned &   │
│ standardized│
└──────┬──────┘
       │
       ▼
┌─────────────┐
│    GOLD     │
│ Business-   │
│ ready data  │
└──────┬──────┘
       │
       ▼
┌──────────────────────────┐
│      SQL SERVER DWH      │
│                          │
│ dim_customer             │
│ dim_merchant             │
│ dim_date                 │
│                          │
│ fact_merchant_transaction│
└────────────┬─────────────┘
             │
             ▼
      BI / Reporting
```

---

# 9. But why have BOTH Gold and SQL Server DWH?

This is the key architectural question.

Because they have **different purposes**.

### Lakehouse Gold

Could contain:

```text
gold.customer_360
gold.merchant_daily_summary
gold.loan_risk_features
gold.customer_transaction_behavior
gold.fraud_features
```

It's useful for:

* Data Science
* ML
* AI
* advanced analytics
* experimentation
* data products
* large-scale processing

### SQL Server DWH

Could contain:

```text
dim_customer
dim_account
dim_merchant
dim_branch
dim_product
dim_date

fact_transaction
fact_loan
fact_card_transaction
fact_merchant_transaction
fact_account_balance
```

It's useful for:

* enterprise reporting
* standardized KPIs
* regulatory reporting
* financial reporting
* Power BI
* management dashboards
* controlled/centralized analytical data

---

# 10. Then PostgreSQL Data Mart

Finally, suppose the **SME lending department** only needs merchant-related information.

We could create:

```text
PostgreSQL
      │
      └── SME Lending Mart
             │
             ├── merchant_revenue
             ├── merchant_transactions
             ├── loan_balance
             ├── repayment_history
             └── cashflow_risk
```

For example:

| merchant | monthly_sales | loan_balance | repayment | risk |
| -------- | ------------: | -----------: | --------: | ---- |
| M5008    |           25M |          10M |      Good | Low  |
| M5010    |            8M |          15M |      Late | High |

Now the lending team can ask:

> "Which SME merchants are showing declining sales and increasing repayment risk?"

without querying the entire enterprise DWH.

---

## The whole architecture now makes sense

```text
                       BANKING SOURCES
                             │
                  Core / Cards / KHQR
                             │
                        CDC / APIs
                             │
                           Kafka
                             │
                             ▼
                    ┌─────────────────┐
                    │    LAKEHOUSE    │
                    │                 │
                    │    BRONZE       │
                    │       ↓         │
                    │    SILVER       │
                    │       ↓         │
                    │     GOLD        │
                    └───────┬─────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
       SQL Server DWH                Data Science
              │                       / AI / ML
       ┌──────┴───────┐
       │              │
 Dimensions         Facts
       │              │
       └──────┬───────┘
              │
              ▼
       PostgreSQL
       Data Marts
              │
       ┌──────┼───────────┐
       ▼      ▼           ▼
     Loan    Risk        SME
     Mart    Mart        Mart
              │
              ▼
         BI / Analytics
```

### The mental model I recommend you remember

**Bronze → Silver → Gold** answers:

> **How mature/trusted is the data?**

**Facts + Dimensions** answers:

> **How is enterprise analytical data modeled?**

**Data Mart** answers:

> **Which business domain/use case is this data optimized for?**

**SQL Server / PostgreSQL / Iceberg** answers:

> **Where is the data physically stored and served?**

That distinction will make the whole Data Architect discussion much easier.

Clarify the physical boundaries

* Explain what belongs in Gold vs the DWH
* Show the SQL Server star schema


As you know, sathapana bank data is on premise database servers not in files or cloud or so....we should implement DWH not lake house right?

Yes — **if Sathapana's primary banking data is currently on-premises databases and the immediate goal is enterprise reporting, analytics, regulatory reporting, and AI**, I would **start with a traditional on-premise Data Warehouse rather than introducing a full lakehouse just because it is modern**.

But I would make one important distinction:

> **On-premise does not mean "DWH instead of Lakehouse."**
> A lakehouse can also be built on-premise. The real question is whether Sathapana currently has the data volume, data types, and use cases that justify it.

### For Sathapana, I would initially recommend this

```text
                 ON-PREMISE BANKING SYSTEMS
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
    Core Banking        Cards          KHQR / Payments
        │                 │                 │
        └─────────────────┼─────────────────┘
                          │
                    CDC / ETL / APIs
                          │
                          ▼
                  ┌───────────────┐
                  │     DWH       │
                  │               │
                  │ Staging       │
                  │      ↓        │
                  │ ODS (optional)│
                  │      ↓        │
                  │ Facts         │
                  │ Dimensions    │
                  └───────┬───────┘
                          │
                 ┌────────┼────────┐
                 ▼        ▼        ▼
                BI       AI    Regulatory
```

Then, if there is a specific need for departmental serving:

```text
                         DWH
                          │
             ┌────────────┼────────────┐
             ▼            ▼            ▼
        Loan Mart      Risk Mart    SME Mart
             │            │            │
             └────────────┼────────────┘
                          ▼
                    BI / Applications
```

---

## Why I wouldn't force Bronze/Silver/Gold initially

Suppose Sathapana has:

```text
Oracle / SQL Server / other on-prem DBs
             │
             ▼
          Staging
             │
             ▼
     Enterprise DWH
             │
      ┌──────┴──────┐
      ▼             ▼
   Facts        Dimensions
      │             │
      └──────┬──────┘
             ▼
        Data Marts
             │
       ┌─────┼─────┐
       ▼     ▼     ▼
      BI     AI   Reports
```

That's a perfectly legitimate banking architecture.

You don't need:

```text
Bronze
Silver
Gold
Lakehouse
Spark
Iceberg
Delta
```

just because those are popular modern data-engineering technologies.

---

# However, there's a catch

I would **not** build the DWH directly against production databases using heavy ETL queries.

For example, avoid:

```text
Core Banking Production
          │
          │ SELECT millions of rows
          ▼
       DWH ETL
```

Instead:

```text
                CORE BANKING
                     │
                     │ CDC
                     ▼
                Kafka / CDC
                     │
                     ▼
                 STAGING
                     │
                     ▼
              DWH Transformation
                     │
              ┌──────┴──────┐
              ▼             ▼
           FACTS       DIMENSIONS
```

This protects the operational banking systems.

---

# And this brings us back to your original SSIS / Hop / Airflow question

For an on-premise Sathapana DWH, you could have:

```text
                   SOURCES
                      │
                CDC / ETL / APIs
                      │
                      ▼
                 STAGING
                      │
                      ▼
              ┌───────────────┐
              │     DWH       │
              │               │
              │ Dimensions    │
              │ Facts         │
              └───────┬───────┘
                      │
                      ▼
                 DATA MARTS
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
       Retail        Risk        SME
        Mart          Mart        Mart
          │           │           │
          └───────────┼───────────┘
                      ▼
                 BI / Analytics
```

And:

**SSIS / Apache Hop** → perform ETL/data integration.

**Airflow** → orchestrates the pipelines.

For example:

```text
Airflow
   │
   ├── Run CDC ingestion
   │
   ├── Load staging
   │
   ├── Load dimensions
   │
   ├── Load facts
   │
   ├── Run data-quality checks
   │
   ├── Refresh data marts
   │
   └── Notify success/failure
```

---

# Where would I use a Lakehouse later?

If Sathapana starts collecting things such as:

```text
Transaction data       → structured
Customer data           → structured
Loan data               → structured
KHQR data               → structured

But also:

Call-center recordings  → audio
OCR documents            → images/PDFs
KYC documents            → images
Mobile-app logs          → JSON
Clickstream              → events
Satellite imagery       → images
AI training datasets    → large files
```

Then a Lakehouse becomes much more attractive.

You could evolve to:

```text
                       ON-PREMISE SOURCES
                              │
                         CDC / APIs
                              │
                            Kafka
                              │
             ┌────────────────┴────────────────┐
             │                                 │
             ▼                                 ▼
       ENTERPRISE DWH                    DATA LAKEHOUSE
       Structured data                   Bronze/Silver/Gold
             │                                 │
             │                          Unstructured/
             │                          AI/ML datasets
             │                                 │
             └───────────────┬─────────────────┘
                             ▼
                       BI / AI / Analytics
```

So **DWH first → Lakehouse later** can be a very sensible evolution.

---

## My recommendation for Sathapana

I'd propose **not "DWH vs Lakehouse" as an ideological decision**, but a phased approach:

### Phase 1 — Enterprise DWH

```text
Core Banking
Cards
KHQR
Merchant
Loans
Deposits
        ↓
      CDC
        ↓
    Staging
        ↓
Enterprise DWH
        ↓
Facts + Dimensions
        ↓
Data Marts
        ↓
BI / Regulatory / Analytics
```

### Phase 2 — Real-time data platform

Add:

```text
Kafka
   ↓
Real-time Fraud
Real-time Risk
Real-time Notifications
```

### Phase 3 — Lakehouse, if justified

Add:

```text
Data Lakehouse
     ↓
Bronze
Silver
Gold
     ↓
AI/ML
Data Science
Unstructured Data
Advanced Analytics
```

This avoids **over-engineering the bank's first data platform**.

And one final point: **the fact that Sathapana's source databases are on-premise does not itself mean you should use SQL Server for the DWH.** You can have an on-premise Oracle, SQL Server, PostgreSQL, or another analytical platform. The DWH technology should be selected based on existing licenses/skills, data volume, concurrency, HA/DR, ETL requirements, BI tooling, security, and 5–10 year growth.

Refine the Sathapana target architecture

* Define the on-prem DWH layers

Pls tell me where should I create the staging database and DWH should contain how many databases?                    SOURCES
                      │
                CDC / ETL / APIs
                      │
                      ▼
                 STAGING
                      │
                      ▼
              ┌───────────────┐
              │     DWH       │
              │               │
              │ Dimensions    │
              │ Facts         │
              └───────┬───────┘
                      │
                      ▼
                 DATA MARTS
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
       Retail        Risk        SME
        Mart          Mart        Mart
          │           │           │
          └───────────┼───────────┘
                      ▼
                 BI / Analytics


Yes. For the architecture you are describing, I would **not create a separate database for every layer or every subject area**. Keep the physical structure relatively simple.

For Sathapana, assuming an **on-prem SQL Server-based DWH**, I'd recommend something like this:

```text
                    SOURCE SYSTEMS
                         │
                  CDC / ETL / APIs
                         │
                         ▼
              ┌─────────────────────┐
              │   STAGING DATABASE  │
              │                     │
              │ SQL Server          │
              │                     │
              │ stg_customer        │
              │ stg_account         │
              │ stg_transaction     │
              │ stg_loan            │
              │ stg_card            │
              │ stg_merchant        │
              └──────────┬──────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │    ENTERPRISE DWH   │
              │      SQL Server     │
              │                     │
              │  Dimensions         │
              │  Facts              │
              └──────────┬──────────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
           Retail      Risk        SME
            Mart        Mart        Mart
              │          │          │
              └──────────┼──────────┘
                         ▼
                    BI / Analytics
```

## 1. Where should Staging be?

I recommend a **separate SQL Server database** for staging.

For example:

```text
SQL Server Instance: DWH-SQL01

├── DWH_STAGING
│
└── DWH_ENTERPRISE
```

So:

```text
DWH_STAGING
```

contains data extracted from the source systems.

For example:

```text
DWH_STAGING
│
├── stg_customer
├── stg_account
├── stg_account_balance
├── stg_transaction
├── stg_loan
├── stg_loan_payment
├── stg_card
├── stg_card_transaction
├── stg_merchant
└── stg_khqr_transaction
```

### Why separate it?

Because staging is **temporary/intermediate ETL data**, whereas the DWH is your **controlled enterprise analytical repository**.

You don't want your staging tables mixed with your production DWH tables.

---

# 2. How many databases should the DWH contain?

Here's the important distinction:

You can have **one physical DWH database** containing many schemas.

I would start with:

```text
DWH_ENTERPRISE
```

rather than creating:

```text
DWH_CUSTOMER
DWH_LOAN
DWH_CARD
DWH_MERCHANT
DWH_RISK
...
```

as separate databases.

Inside `DWH_ENTERPRISE`, use schemas.

For example:

```text
DWH_ENTERPRISE
│
├── dim
│    ├── dim_customer
│    ├── dim_account
│    ├── dim_product
│    ├── dim_branch
│    ├── dim_merchant
│    ├── dim_date
│    └── dim_channel
│
├── fact
│    ├── fact_transaction
│    ├── fact_account_balance
│    ├── fact_loan
│    ├── fact_loan_payment
│    ├── fact_card_transaction
│    └── fact_merchant_transaction
│
└── etl
     ├── etl_batch
     └── etl_error
```

So your DWH is **one database**, but logically separated using schemas.

---

# 3. What about the Data Marts?

This is where you have a choice.

You could have:

### Option A — Schemas inside the same DWH

```text
DWH_ENTERPRISE
│
├── dim
├── fact
│
├── mart_retail
├── mart_risk
└── mart_sme
```

For example:

```text
DWH_ENTERPRISE
│
├── dim.dim_customer
├── dim.dim_account
│
├── fact.fact_transaction
├── fact.fact_loan
│
├── mart_retail.customer_360
├── mart_risk.loan_risk
└── mart_sme.merchant_lending
```

This is **simple and often sufficient**.

---

# 4. Option B — Separate databases for the Data Marts

If you have a good reason to isolate workloads, you could have:

```text
SQL Server

├── DWH_STAGING
│
├── DWH_ENTERPRISE
│
├── MART_RETAIL
│
├── MART_RISK
│
└── MART_SME
```

Then:

```text
DWH_ENTERPRISE
       │
       ├──────────────► MART_RETAIL
       │
       ├──────────────► MART_RISK
       │
       └──────────────► MART_SME
```

This gives you stronger **security, workload isolation, deployment and ownership boundaries**.

But don't create separate databases just because you have three departments.

---

# 5. What I would recommend for Sathapana

I'd start with **2 databases**, not 5–10.

```text
SQL SERVER DWH PLATFORM
│
├── 1. DWH_STAGING
│
│      Source extraction
│      CDC landing
│      Temporary ETL
│
└── 2. DWH_ENTERPRISE
       │
       ├── dim
       │     ├── customer
       │     ├── account
       │     ├── product
       │     ├── branch
       │     ├── merchant
       │     └── date
       │
       ├── fact
       │     ├── transaction
       │     ├── loan
       │     ├── loan_payment
       │     ├── card_transaction
       │     └── merchant_transaction
       │
       ├── mart_retail
       ├── mart_risk
       └── mart_sme
```

Then BI connects to the appropriate mart or DWH views.

---

# 6. But there's an important question: Should staging be SQL Server?

Not necessarily.

If your source is Oracle Core Banking, for example, you could have:

```text
Oracle CBS
    │
   CDC
    │
    ▼
DWH_STAGING SQL Server
```

But if the bank has very high-volume CDC, you might instead use:

```text
Oracle CBS
    │
   CDC
    ▼
Kafka
    │
    ▼
Staging / Landing
```

The technology decision depends on your ingestion architecture.

---

# 7. My preferred architecture for your situation

Given that you're discussing an **on-premise bank DWH**, I'd draw it this way:

```text
                         SOURCE SYSTEMS
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
     Core Banking           Cards            Merchant/KHQR
          │                   │                   │
          └───────────────────┼───────────────────┘
                              │
                       CDC / ETL / APIs
                              │
                              ▼
                  ┌─────────────────────┐
                  │    DWH_STAGING      │
                  │                     │
                  │ Raw / landing data  │
                  │ Temporary ETL data  │
                  └──────────┬──────────┘
                             │
                       ETL / ELT
                             │
                             ▼
                  ┌─────────────────────┐
                  │   DWH_ENTERPRISE    │
                  │                     │
                  │ DIMENSIONS          │
                  │ FACTS               │
                  │                     │
                  │ dim_customer        │
                  │ dim_account         │
                  │ dim_product         │
                  │ dim_branch          │
                  │                     │
                  │ fact_transaction    │
                  │ fact_loan           │
                  │ fact_card           │
                  │ fact_merchant       │
                  └──────────┬──────────┘
                             │
                 ┌───────────┼───────────┐
                 ▼           ▼           ▼
           Retail Mart   Risk Mart    SME Mart
                 │           │           │
                 └───────────┼───────────┘
                             ▼
                      BI / Analytics
```

### So the short answer is:

| Component             | Recommended starting point                         |
| --------------------- | -------------------------------------------------- |
| Source DBs            | Existing operational databases                     |
| Staging               | **Separate SQL Server database**                   |
| Enterprise DWH        | **One SQL Server database**                        |
| Dimensions            | Schema inside DWH                                  |
| Facts                 | Schema inside DWH                                  |
| Retail/Risk/SME marts | **Schemas initially**                              |
| Separate Mart DBs     | Only when workload/security/isolation justifies it |
| BI                    | Connect to marts / curated DWH views               |

**I would start with 2 databases: `DWH_STAGING` + `DWH_ENTERPRISE`.**

Then don't prematurely create `MART_RETAIL`, `MART_RISK`, `MART_SME` as separate databases. Start them as schemas inside the enterprise DWH. If later Risk has huge workloads or strict isolation requirements, you can move `Risk Mart` into its own database without redesigning the whole DWH.

For the Sathapana DWH design

* Define the database and schema naming standard

DWH_STAGING and DWH_ENTERPRISE are different instances of SQL SERVERS? 

No. **They do not have to be different SQL Server instances.**

When I said:

```text
DWH_STAGING
DWH_ENTERPRISE
```

I meant **two databases**, which can live on the **same SQL Server instance**.

### Option 1 — Same SQL Server instance ✅

This is what I would normally start with:

```text
SQL Server Instance
        │
        ├── DWH_STAGING
        │      ├── stg_customer
        │      ├── stg_account
        │      └── stg_transaction
        │
        └── DWH_ENTERPRISE
               ├── dim_customer
               ├── dim_account
               ├── dim_product
               ├── fact_transaction
               ├── fact_loan
               └── fact_card_transaction
```

For example:

```text
Server: DWH-SQL01

Databases:
    DWH_STAGING
    DWH_ENTERPRISE
```

That's **one SQL Server instance, two databases**.

---

### Option 2 — Different SQL Server instances

You could also do:

```text
DWH-SQL-STG01
       │
       └── DWH_STAGING


DWH-SQL-DWH01
       │
       └── DWH_ENTERPRISE
```

This gives stronger workload isolation:

```text
             ETL
              │
              ▼
      ┌──────────────┐
      │ SQL Server   │
      │ STAGING      │
      └──────┬───────┘
             │
             │ ETL/ELT
             ▼
      ┌──────────────┐
      │ SQL Server   │
      │ ENTERPRISE   │
      └──────────────┘
```

But it adds infrastructure, administration, networking, HA/DR, licensing considerations, etc.

---

### What I would recommend for Sathapana

For the **initial DWH implementation**, I would probably start with:

```text
              DWH-SQL01
          SQL Server Instance
                  │
       ┌──────────┴──────────┐
       │                     │
       ▼                     ▼
DWH_STAGING           DWH_ENTERPRISE
                          │
                   ┌──────┼──────┐
                   ▼      ▼      ▼
                 Retail  Risk    SME
                  Mart   Mart    Mart
```

Then, if staging/ETL starts competing with DWH workloads, you can separate them:

```text
DWH-SQL-STG01              DWH-SQL-PROD01
      │                           │
      ▼                           ▼
DWH_STAGING              DWH_ENTERPRISE
                                  │
                           Facts / Dimensions
                                  │
                           Data Marts
```

### One more distinction

Don't confuse:

**SQL Server Instance**

```text
DWH-SQL01
```

with:

**Database**

```text
DWH_STAGING
DWH_ENTERPRISE
```

with:

**Schema**

```text
DWH_ENTERPRISE
   │
   ├── dim
   ├── fact
   ├── mart_risk
   └── mart_sme
```

So you can have:

> **1 SQL Server instance → 2 databases → multiple schemas → many tables.**

That's the structure I'd recommend you start with unless Sathapana's existing infrastructure has a specific reason to isolate the workloads.

