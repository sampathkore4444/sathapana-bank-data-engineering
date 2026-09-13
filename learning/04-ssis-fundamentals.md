# SSIS Fundamentals — Complete Guide for Beginners

## Table of Contents

1. [What is SSIS?](#1-what-is-ssis)
2. [SSIS Architecture](#2-ssis-architecture)
3. [SSIS Project Structure](#3-ssis-project-structure)
4. [Control Flow](#4-control-flow)
5. [Data Flow](#5-data-flow)
6. [Connection Managers](#6-connection-managers)
7. [Variables and Expressions](#7-variables-and-expressions)
8. [Error Handling](#8-error-handling)
9. [Logging](#9-logging)
10. [Deploying and Executing SSIS Packages](#10-deploying-and-executing)
11. [Hands-On: Building Your First Package](#11-hands-on)

---

## 1. What is SSIS?

**SSIS (SQL Server Integration Services)** is Microsoft's ETL (Extract, Transform, Load) tool. It's used to:

- **Extract** data from various sources (SQL Server, Oracle, Excel, CSV, APIs)
- **Transform** the data (clean, aggregate, merge, lookup)
- **Load** the data into a destination (Data Warehouse, reporting tables)

### What Can SSIS Do?

| Capability | Example |
|---|---|
| **Data Migration** | Move data from old CBS to new system |
| **ETL Processing** | Load data warehouse daily from source systems |
| **Data Cleansing** | Remove duplicates, fix formatting |
| **File Operations** | Import CSV files, export reports |
| **Workflow Automation** | Execute SQL scripts, send emails, run tasks |
| **Package Scheduling** | Run nightly via SQL Agent |

### SSIS vs Other ETL Tools

| Tool | Best For |
|---|---|
| **SSIS** | On-premise SQL Server, Windows environments |
| **Azure Data Factory** | Cloud-based ETL/ELT |
| **Informatica** | Enterprise-scale, multi-platform |
| **Talend** | Open-source, cross-platform |
| **dbt** | ELT, transformation-only, modern stack |

**For Sathapana Bank:** SSIS is the standard choice since you're using SQL Server.

---

## 2. SSIS Architecture

### SSIS Package Components

```
┌──────────────────────────────────────────────────────────────┐
│                    SSIS PACKAGE                               │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                 CONTROL FLOW                            │  │
│  │   Orchestrate the order of operations                  │  │
│  │   • Task A → Task B → Task C                           │  │
│  │   • Parallel execution                                 │  │
│  │   • Conditional branching                              │  │
│  │   • Looping                                            │  │
│  └────────────────────────────────────────────────────────┘  │
│         │                                                    │
│         ▼                                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                 DATA FLOW                               │  │
│  │   Move and transform data                              │  │
│  │   Source → Transformations → Destination               │  │
│  └────────────────────────────────────────────────────────┘  │
│         │                                                    │
│         ▼                                                    │
│  ┌────────────────────────────────────────────────────────┐  │
│  │           EVENT HANDLERS & CONNECTIONS                 │  │
│  │   Handle errors, manage connections                    │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Key Concepts

| Concept | What It Is |
|---|---|
| **Package** | The main container (`.dtsx` file) |
| **Task** | A unit of work in Control Flow |
| **Data Flow Task** | Special task that contains the Data Flow |
| **Component** | A unit in Data Flow (source, transform, destination) |
| **Connection Manager** | Defines how to connect to data sources |
| **Variable** | Stores values used by the package |
| **Precedence Constraint** | Controls the flow between tasks (arrows) |

---

## 3. SSIS Project Structure

### Creating a New SSIS Project

1. Open **SQL Server Data Tools (SSDT)** — Visual Studio with SSIS extensions
2. File → New → Project → **Integration Services Project**
3. Name your project: `SathapanaDW_ETL`

### Project Layout

```
SathapanaDW_ETL/
├── SathapanaDW_ETL.sln           -- Solution file
├── SathapanaDW_ETL/              -- Project folder
│   ├── Package.dtsx              -- Main SSIS package
│   ├── Project.params            -- Project parameters
│   ├── Connection Managers/      -- Shared connections
│   └── SSIS Package Parts/       -- Reusable components
```

### Package Naming Convention

```
# Banking ETL Package Naming:
ETL_Load_Dim_Customer.dtsx
ETL_Load_Dim_Account.dtsx
ETL_Load_Dim_Branch.dtsx
ETL_Load_Fact_Transactions.dtsx
ETL_Load_Fact_Daily_Balance.dtsx
ETL_Orchestrate_Daily_Load.dtsx  -- Master package
```

---

## 4. Control Flow

The **Control Flow** defines the **order of execution** of tasks. Think of it as a flowchart.

### Control Flow Components

| Component | Purpose | Example |
|---|---|---|
| **Execute SQL Task** | Run SQL statements | Truncate staging table |
| **Data Flow Task** | Move data (contains Data Flow) | Load customer dimension |
| **For Loop Container** | Repeat tasks in a loop | Process each file in a folder |
| **Foreach Loop Container** | Iterate over a collection | Process files, table list |
| **Script Task** | Run C# or VB.NET code | Complex logic |
| **Send Mail Task** | Send email notifications | Alert on failure |
| **File System Task** | File operations | Move/copy/delete files |
| **Execute Process Task** | Run external programs | Run PowerShell script |
| **Sequence Group** | Group related tasks | Group all dimension loads |
| **Priority Constraint** | Flow control (arrows) | Success, Failure, Completion |
| **Expression Task** | Set variables dynamically | Calculate date |

### Precedence Constraints (Arrows)

```
┌──────────────┐    Success     ┌──────────────┐
│  Task A      │───────────────▶│  Task B      │
│  (Truncate)  │                │  (Load Data) │
└──────────────┘                └──────────────┘

Three types of constraints:
├── Success (Green arrow)  → Only runs if previous task succeeds
├── Failure (Red arrow)    → Only runs if previous task fails  
└── Completion (Blue arrow)→ Runs regardless of previous task result
```

### Banking Example — Daily ETL Control Flow

```
┌─────────────────────────┐
│  Check File Exists      │  ← Script Task: Verify source files
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│  Truncate Staging       │  ← Execute SQL: TRUNCATE staging tables
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│  Load Staging Tables    │  ← Data Flow Task: CSV → Staging
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│  Validate Data          │  ← Execute SQL: Check for NULLs, duplicates
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│  Load Dimensions        │  ← Sequence Container
│  ├── Load dim_branch    │     (SCD Type 2 processing)
│  ├── Load dim_customer  │
│  ├── Load dim_account   │
│  └── Load dim_product   │
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│  Load Fact Tables       │  ← Data Flow Tasks
│  ├── Load fact_txn      │
│  └── Load fact_balance  │
└───────────┬─────────────┘
            │ Success
            ▼
┌─────────────────────────┐
│  Send Success Email     │  ← Send Mail Task
└─────────────────────────┘

On FAILURE of any task:
            │
            ▼
┌─────────────────────────┐
│  Send Failure Email     │  ← Send Mail Task
└─────────────────────────┘
```

---

## 5. Data Flow

The **Data Flow** is where data actually moves and gets transformed. It's inside a **Data Flow Task** in the Control Flow.

### Data Flow Components

| Component Type | Purpose | Example |
|---|---|---|
| **Source** | Where data comes from | SQL Server, CSV, Excel |
| **Transformation** | Modify the data | Sort, Merge, Lookup, Derived Column |
| **Destination** | Where data goes to | SQL Server table |
| **Path** | Connects components | Data flow arrows |

### Common Data Flow Components

#### Sources
| Source | Use Case |
|---|---|
| **OLE DB Source** | SQL Server, Oracle, other databases |
| **Flat File Source** | CSV, TXT files |
| **Excel Source** | Excel spreadsheets |
| **XML Source** | XML files |
| **RAW File Source** | SSIS native format |

#### Transformations
| Transformation | Purpose | Banking Example |
|---|---|---|
| **Derived Column** | Calculate new columns | age = DATEDIFF(year, dob, GETDATE()) |
| **Lookup** | Find matching data | Find branch_key from branch_code |
| **Sort** | Sort data | Sort transactions by date |
| **Merge** | Combine two sorted streams | Combine CBS and CMS transactions |
| **Merge Join** | Join two data sources | Join accounts with customers |
| **Conditional Split** | Route data to different paths | Separate deposits vs withdrawals |
| **Aggregate** | Summarize data | Total transactions per branch |
| **Union All** | Stack data vertically | Combine multiple source files |
| **Copy Column** | Duplicate a column | Copy amount before transformation |
| **Data Conversion** | Change data types | VARCHAR → INT |
| **OLE DB Command** | Execute SQL per row | Update a flag for each row |
| **Slowly Changing Dimension** | SCD processing | Handle customer changes |
| **Audit** | Add metadata | Add execution timestamp |

#### Destinations
| Destination | Use Case |
|---|---|
| **OLE DB Destination** | SQL Server tables |
| **Flat File Destination** | Export to CSV |
| **Excel Destination** | Export to Excel |
| **RAW File Destination** | SSIS native format |

### Data Flow Example — Loading Customer Dimension

```
┌──────────────────┐
│  OLE DB Source   │  ← SELECT customer_id, name, risk_rating, phone
│  (CBS Database)  │     FROM cbs.dbo.customers
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Derived Column  │  ← Calculate age_group:
│                  │     CASE WHEN age < 25 THEN 'Young'
│                  │          WHEN age < 45 THEN 'Middle'
│                  │          ELSE 'Senior' END
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Lookup          │  ← Find existing customer_key
│  (dim_customer)  │     (for SCD Type 2 processing)
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────────┐
│ New    │ │ Changed    │
│ Insert │ │ Update SCD2│
└────────┘ └────────────┘
```

---

## 6. Connection Managers

Connection managers define **how SSIS connects** to data sources.

### Types of Connection Managers

| Type | Use Case |
|---|---|
| **OLE DB** | SQL Server, Oracle databases |
| **Flat File** | CSV, TXT files |
| **Excel** | Excel files |
| **File** | General file paths |
| **FTP** | FTP server connections |
| **HTTP** | Web API connections |
| **SMTP** | Email sending |
| **Variable** | Dynamic connection strings |

### Creating Connection Managers

#### OLE DB Connection Manager (SQL Server)

1. Right-click in Connection Managers area → **New OLE DB Connection**
2. Click **New** → Enter server name and database
3. Test Connection → OK

```
# Connection String:
Server=sathapana-sql\INSTANCE01;Database=CBS_Source;Integrated Security=True;

# For production, use:
Server=sathapana-sql\INSTANCE01;Database=CBS_Source;User Id=etl_user;Password=***;
```

#### Flat File Connection Manager (CSV)

1. Right-click → **New Flat File Connection**
2. Browse to file location
3. Set format: Delimited, Fixed width, etc.
4. Set column names in first row: ✅
5. Set delimiter: Comma (,), Tab, Pipe (|)

```
# Example CSV file (customers.csv):
customer_id,name,risk_rating,phone,province
1001," Sokha",LOW,012-345-678,Phnom Penh
1002,"Dara",MEDIUM,012-999-999,Siem Reap
```

### Using Project Parameters for Connections

```sql
-- In SSIS Project Parameters:
-- Parameter: CM_CBS_ConnectionString
-- Value: "Server=sathapana-sql;Database=CBS_Source;Integrated Security=True;"

-- Use this parameter in Connection Manager:
-- Connection Manager → Properties → Expressions → ConnectionString
-- Expression: @[CM_CBS_ConnectionString]
```

---

## 7. Variables and Expressions

### Variables

Variables store values that can be used throughout the package.

```
# Creating Variables:
Right-click in Control Flow → Variables

# Common Variables for Banking ETL:
Variable Name               Data Type    Value
─────────────────────────────────────────────────
var_CutoffDate              DateTime     (calculated)
var_SourceFilePath          String       C:\ETL\source\
var_DestFilePath            String       C:\ETL\archive\
var_LoadDate                DateTime     (current date)
var_IsFirstRun              Boolean      True
var_ErrorCount              Int32        0
var_MaxTransactionDate      DateTime     (from last load)
```

### Expressions

Expressions dynamically set properties at runtime.

```sql
-- Set Variable Value with Expression:
var_LoadDate = (DT_DBTIMESTAMP)(GETDATE())

-- Set File Path with Expression:
var_SourceFilePath = "C:\\ETL\\source\\customers_" + 
    (DT_STR,4,1252) + RIGHT("0" + (DT_STR,2,1252)MONTH(GETDATE()),2) + 
    RIGHT("0" + (DT_STR,2,1252)DAY(GETDATE()),2) + ".csv"

-- Result: C:\ETL\source\customers_0912.csv (for Sept 12)
```

### Common Expressions

```sql
-- Date Calculations:
-- Yesterday's date
DATEADD("day", -1, GETDATE())

-- First day of current month
DATEADD("month", DATEDIFF("month", 0, GETDATE()), 0)

-- Last day of current month
DATEADD("day", -1, DATEADD("month", DATEDIFF("month", 0, GETDATE()) + 1, 0))

-- String Concatenation:
"ETL_Load_" + (DT_STR, 4, 1252) + (DT_STR, 2, 1252) + MONTH(GETDATE()) + ".log"

-- Conditional Logic:
-- If it's weekend, use Friday's date
IF(DATEPART("weekday", GETDATE()) == 1, 
    DATEADD("day", -2, GETDATE()), 
    IF(DATEPART("weekday", GETDATE()) == 7, 
        DATEADD("day", -1, GETDATE()), 
        GETDATE()))

-- Data Type Conversions:
(DT_DBTIMESTAMP) "2025-09-12"           -- String to DateTime
(DT_STR, 10, 1252) GETDATE()           -- DateTime to String
(DT_I4) "12345"                          -- String to Integer
```

---

## 8. Error Handling

### Error Handling in Data Flow

Every Data Flow component has **Error Output** — rows that fail can be routed to a separate path.

```
┌──────────────────┐
│  OLE DB Source   │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────────┐
│ Normal │ │ Error      │
│ Output │ │ Output     │
└────┬───┘ └─────┬──────┘
     │           │
     ▼           ▼
┌──────────┐ ┌──────────────────┐
│ dim_     │ │ error_log        │
│ customer │ │ (log the error)  │
└──────────┘ └──────────────────┘
```

### Setting Up Error Output

1. Double-click a component (e.g., OLE DB Destination)
2. Click **Configure Error Output**
3. Choose: **Redirect Row** (instead of Fail Component)
4. The error output will include an extra column: `ErrorCode` and `ErrorColumn`

### Error Handling in Control Flow

```
┌──────────────────┐
│  Load Data       │
└────────┬─────────┘
    ┌────┴────┐
    │         │
 Success    Failure
    │         │
    ▼         ▼
┌──────────┐ ┌──────────────┐
│ Log      │ │ Log Error +  │
│ Success  │ │ Send Email   │
└──────────┘ └──────────────┘
```

### Error Logging Table

```sql
CREATE TABLE etl_error_log (
    error_id        INT IDENTITY(1,1) PRIMARY KEY,
    package_name    VARCHAR(100),
    task_name       VARCHAR(100),
    error_code      INT,
    error_column    VARCHAR(100),
    error_message   NVARCHAR(MAX),
    failed_row_data NVARCHAR(MAX),
    error_datetime  DATETIME DEFAULT GETDATE(),
    load_date       DATE
);

-- In SSIS, use an Execute SQL Task to insert errors:
INSERT INTO etl_error_log (package_name, task_name, error_code, error_message)
VALUES (?, ?, ?, ?);
```

---

## 9. Logging

### SSIS Built-in Logging

1. Right-click package → **Logging**
2. Select log provider: **SQL Server** (recommended)
3. Select connection: Your logging database
4. Enable events:
   - `OnError` — Log when errors occur
   - `OnPostExecute` — Log when tasks complete
   - `OnPreExecute` — Log when tasks start
   - `OnProgress` — Log progress updates

### Custom Logging Pattern

```
┌────────────────────────────────────────────────────────────┐
│              ETL AUDIT LOG TABLE                            │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  log_id          INT PRIMARY KEY                           │
│  package_name    VARCHAR(100)                              │
│  task_name       VARCHAR(100)                              │
│  event_type      VARCHAR(50)   -- START, SUCCESS, FAILURE  │
│  start_time      DATETIME                                   │
│  end_time        DATETIME                                   │
│  duration_sec    INT                                        │
│  rows_affected   INT                                        │
│  error_message   NVARCHAR(MAX)                              │
│  executed_by     VARCHAR(100)                               │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Logging in SSIS

```sql
-- Create logging table
CREATE TABLE etl_audit_log (
    log_id          INT IDENTITY(1,1) PRIMARY KEY,
    package_name    VARCHAR(100),
    task_name       VARCHAR(100),
    event_type      VARCHAR(50),
    start_time      DATETIME,
    end_time        DATETIME,
    duration_sec    AS DATEDIFF(SECOND, start_time, end_time),
    rows_affected   INT,
    error_message   NVARCHAR(MAX),
    load_date       DATE DEFAULT CAST(GETDATE() AS DATE)
);

-- In SSIS Control Flow:
-- Use Execute SQL Tasks at start and end of each Data Flow Task

-- Start Logging (Execute SQL Task):
INSERT INTO etl_audit_log (package_name, task_name, event_type, start_time)
VALUES ('ETL_Load_Dim_Customer', 'Data Flow', 'START', GETDATE());

-- End Logging (Execute SQL Task):
UPDATE etl_audit_log
SET end_time = GETDATE(),
    event_type = 'SUCCESS',
    rows_affected = ?
WHERE log_id = (SELECT MAX(log_id) FROM etl_audit_log 
                WHERE package_name = 'ETL_Load_Dim_Customer');
```

---

## 10. Deploying and Executing SSIS Packages

### Deployment Methods

#### Method 1: SSIS Catalog (Recommended for Production)

1. Right-click project → **Deploy**
2. Select **SSIS Catalog** (SSISDB)
3. Choose folder: `SathapanaDW_ETL`
4. Deploy!

```
# SSIS Catalog Structure:
SSISDB/
└── SathapanaDW_ETL/
    ├── Projects/
    │   └── SathapanaDW_ETL/
    │       ├── ETL_Load_Dim_Customer.dtsx
    │       ├── ETL_Load_Dim_Account.dtsx
    │       └── ETL_Load_Fact_Transactions.dtsx
    ├── Environments/
    │   ├── DEV/
    │   ├── UAT/
    │   └── PROD/
    └── Packages/
        └── ETL_Orchestrate_Daily_Load.dtsx
```

#### Method 2: File System (Simple)

1. Right-click package → **Export Package**
2. Save to file system: `C:\SSIS_Packages\`
3. Execute with dtexec utility

### Executing Packages

#### From SSMS (SQL Server Management Studio)

1. Open SSIS Catalog → Navigate to package
2. Right-click → **Execute**
3. Set parameters if needed → OK

#### From SQL Agent (Scheduled)

```sql
-- Create a SQL Agent Job
USE msdb;
EXEC dbo.sp_add_job @job_name = N'ETL_Daily_Load';

EXEC dbo.sp_add_jobstep
    @job_name = N'ETL_Daily_Load',
    @step_name = N'Execute SSIS Package',
    @subsystem = N'SSIS',
    @command = N'/ISSERVER "\"\SSISDB\SathapanaDW_ETL\ETL_Orchestrate_Daily_Load.dtsx\"" /SERVER "\"sathapana-sql\INSTANCE01\"" /EnvReference PROD',
    @database_name = N'master';

-- Schedule: Run daily at 2:00 AM
EXEC dbo.sp_add_jobschedule
    @job_name = N'ETL_Daily_Load',
    @name = N'Daily_2AM',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @active_start_time = 020000;  -- 2:00 AM
```

#### From Command Line

```bash
# Using dtexec (SQL Server 2019 and earlier)
dtexec /ISServer "\SSISDB\SathapanaDW_ETL\ETL_Orchestrate_Daily_Load.dtsx" 
       /Server "sathapana-sql\INSTANCE01"

# Using dtexec with file
dtexec /F "C:\SSIS_Packages\ETL_Load_Dim_Customer.dtsx"

# With parameters
dtexec /ISServer "\SSISDB\SathapanaDW_ETL\ETL_Load_Dim_Customer.dtsx" 
       /Server "sathapana-sql\INSTANCE01" 
       /SET "\Package.Variables[User::var_LoadDate].Value;2025-09-12"
```

---

## 11. Hands-On: Building Your First Package

### Scenario: Load Customer Dimension from CBS

#### Step 1: Create the Package

1. Open SSDT → New Integration Services Project
2. Name: `SathapanaDW_ETL`
3. Rename `Package.dtsx` to `ETL_Load_Dim_Customer.dtsx`

#### Step 2: Create Connection Managers

**OLE DB Connection (CBS Source):**
1. Right-click Connection Managers → New OLE DB Connection
2. Server: `sathapana-cbs-sql\INSTANCE01`
3. Database: `CBS_Source`

**OLE DB Connection (DW Destination):**
1. New OLE DB Connection
2. Server: `sathapana-dw-sql\INSTANCE01`
3. Database: `Sathapana_DW`

**Flat File Connection (Error Log):**
1. New Flat File Connection
2. File: `C:\ETL\Logs\customer_errors.csv`

#### Step 3: Control Flow

1. Drag **Execute SQL Task** → Name: `Truncate Staging`
2. Configure: Connection → CBS_Source, SQLStatement:
   ```sql
   TRUNCATE TABLE staging.dbo.stg_customers;
   ```

3. Drag **Data Flow Task** → Name: `Load Customer Dimension`
4. Connect arrow from `Truncate Staging` → `Load Customer Dimension`

#### Step 4: Data Flow (Inside the Data Flow Task)

1. **OLE DB Source** (Extract):
   - Connection: CBS_Source
   - SQL Command:
     ```sql
     SELECT 
         customer_id,
         full_name,
         risk_rating,
         phone,
         email,
         province,
         customer_type,
         national_id,
         created_date
     FROM cbs.dbo.customers
     WHERE status = 'A'  -- Active customers only
     ```

2. **Derived Column** (Transform):
   - New column: `age_group`
   - Expression: 
     ```
     (DT_STR, 20, 1252)(DT_I4)(DATEDIFF("day", created_date, GETDATE()) / 365) < 25 ? "Young" : 
     (DT_I4)(DATEDIFF("day", created_date, GETDATE()) / 365) < 45 ? "Middle" : "Senior"
     ```

3. **OLE DB Destination** (Load):
   - Connection: Sathapana_DW
   - Table: `dbo.dim_customer`
   - Mappings: Map source columns to destination columns

#### Step 5: Error Handling

1. Click on OLE DB Destination
2. Click **Configure Error Output**
3. Set Error to: **Redirect Row**
4. Add **Flat File Destination** for error output
5. Connect error output to the Flat File Destination

#### Step 6: Test

1. Click **Start** (F5) to debug
2. Watch the data flow in real-time
3. Check the destination table for loaded data

---

## Summary — SSIS Key Concepts

| Concept | What It Does |
|---|---|
| **Package** | Container for all ETL logic |
| **Control Flow** | Orchestrates task execution order |
| **Data Flow** | Moves and transforms data |
| **Connection Manager** | Defines data source/destination connections |
| **Variable** | Stores dynamic values |
| **Expression** | Calculates values at runtime |
| **Precedence Constraint** | Controls flow between tasks (arrows) |
| **Error Output** | Handles failed rows |
| **SSIS Catalog** | Centralized package management |
| **SQL Agent** | Schedules package execution |

---

## Next Steps

Continue to: **[05-ssis-dataflow-deep-dive.md](./05-ssis-dataflow-deep-dive.md)** for advanced Data Flow techniques.

---

*Last Updated: September 2026*
*Author: Buffy (Codebuff)*
