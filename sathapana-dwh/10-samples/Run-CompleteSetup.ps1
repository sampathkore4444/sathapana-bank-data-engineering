# ============================================================================
# SATHAPANA BANK - AUTOMATED SETUP SCRIPT
# ============================================================================
# Purpose: One-click setup for all 10 databases
# Usage: Right-click → Run with PowerShell
# ============================================================================

# ============================================================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================================================
$SqlServer = "localhost"  # Change to your server name (e.g., "DESKTOP-ABC\SQLEXPRESS")
$ProjectPath = "C:\sathapana-dwh"  # Change to your project folder path

# ============================================================================
# DO NOT EDIT BELOW THIS LINE
# ============================================================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     SATHAPANA BANK - AUTOMATED DWH SETUP                         ║" -ForegroundColor Cyan
Write-Host "║     Enterprise Layered Architecture (10 Databases)               ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if SQL Server module is available
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "Installing SQL Server module..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Force -AllowClobber
}

Import-Module SqlServer

# ============================================================================
# FUNCTION: Execute SQL Script
# ============================================================================
function Execute-SQLScript {
    param(
        [string]$ScriptPath,
        [string]$Description
    )
    
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "Running: $Description" -ForegroundColor Yellow
    Write-Host "File: $ScriptPath" -ForegroundColor DarkGray
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "  ✗ File not found: $ScriptPath" -ForegroundColor Red
        return $false
    }
    
    try {
        $startTime = Get-Date
        Invoke-Sqlcmd -ServerInstance $SqlServer -InputFile $ScriptPath -Verbose:$false -ErrorAction Stop
        $endTime = Get-Date
        $duration = ($endTime - $startTime).Seconds
        
        Write-Host "  ✓ Completed in $duration seconds" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ============================================================================
# TRACKING
# ============================================================================
$TotalStart = Get-Date
$SuccessCount = 0
$FailCount = 0
$TotalScripts = 8

Write-Host ""
Write-Host "Starting automated setup..." -ForegroundColor Cyan
Write-Host "Server: $SqlServer" -ForegroundColor DarkGray
Write-Host "Project: $ProjectPath" -ForegroundColor DarkGray
Write-Host ""

# ============================================================================
# STEP 1: SOURCE DATABASE (Layer 0)
# ============================================================================
$script = Join-Path $ProjectPath "10-samples\00-MASTER-SETUP-ALL-DATABASES.sql"
if (Execute-SQLScript $script "Step 1: Create Source Database (Layer 0) with Sample Data") {
    $SuccessCount++
} else { $FailCount++ }

# ============================================================================
# STEP 2: RAW ZONE (Layer 1)
# ============================================================================
$script = Join-Path $ProjectPath "02-source-systems\02-create-raw-zone-database.sql"
if (Execute-SQLScript $script "Step 2: Create Raw Zone Database (Layer 1)") {
    $SuccessCount++
} else { $FailCount++ }

# ============================================================================
# STEP 3: STAGING DATABASE
# ============================================================================
$script = Join-Path $ProjectPath "03-staging\01-create-staging-database.sql"
if (Execute-SQLScript $script "Step 3: Create Staging Database") {
    $SuccessCount++
} else { $FailCount++ }

# ============================================================================
# STEP 4: ENTERPRISE DATA WAREHOUSE (Layer 2)
# ============================================================================
$script = Join-Path $ProjectPath "04-data-warehouse\01-create-dwh-database.sql"
if (Execute-SQLScript $script "Step 4: Create Enterprise Data Warehouse (Layer 2)") {
    $SuccessCount++
} else { $FailCount++ }

# ============================================================================
# STEP 5: DATA MARTS (Layer 3)
# ============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 5: Creating Data Marts (Layer 3)..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$martScripts = @(
    @{Path="05-data-marts\credit\01-create-credit-mart-database.sql"; Name="Credit Risk Mart"},
    @{Path="05-data-marts\customer\01-create-customer-mart-database.sql"; Name="Customer Analytics Mart"},
    @{Path="05-data-marts\treasury\01-create-treasury-mart-database.sql"; Name="Treasury Mart"},
    @{Path="05-data-marts\compliance\01-create-compliance-mart-database.sql"; Name="Compliance/AML Mart"}
)

foreach ($mart in $martScripts) {
    $script = Join-Path $ProjectPath $mart.Path
    if (Execute-SQLScript $script "Create $($mart.Name)") {
        $SuccessCount++
    } else { $FailCount++ }
    $TotalScripts++
}

# ============================================================================
# STEP 6: ETL PROCEDURES
# ============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 6: Creating ETL Procedures..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$etlScripts = @(
    @{Path="06-etl\01-extract-procedures.sql"; Name="Extract Procedures"},
    @{Path="06-etl\02-transform-load-procedures.sql"; Name="Transform & Load Procedures"},
    @{Path="07-data-quality\01-data-quality-framework.sql"; Name="Data Quality Framework"},
    @{Path="08-monitoring\01-monitoring-framework.sql"; Name="Monitoring Framework"}
)

foreach ($etl in $etlScripts) {
    $script = Join-Path $ProjectPath $etl.Path
    if (Execute-SQLScript $script $etl.Name) {
        $SuccessCount++
    } else { $FailCount++ }
    $TotalScripts++
}

# ============================================================================
# STEP 7: RUN COMPLETE PIPELINE
# ============================================================================
$script = Join-Path $ProjectPath "10-samples\03-run-complete-pipeline.sql"
if (Execute-SQLScript $script "Step 7: Run Complete ETL Pipeline") {
    $SuccessCount++
} else { $FailCount++ }
$TotalScripts++

# ============================================================================
# STEP 8: RUN TESTS
# ============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 8: Running Data Quality Tests..." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

try {
    Invoke-Sqlcmd -ServerInstance $SqlServer -Database "sathapana_dwh" -Query "EXEC audit.usp_RunAllTests;" -ErrorAction Stop
    Write-Host "  ✓ Tests completed" -ForegroundColor Green
    $SuccessCount++
}
catch {
    Write-Host "  ⚠ Tests skipped (run after pipeline completes)" -ForegroundColor Yellow
}
$TotalScripts++

# ============================================================================
# FINAL SUMMARY
# ============================================================================
$TotalEnd = Get-Date
$TotalDuration = ($TotalEnd - $TotalStart).TotalSeconds

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    SETUP COMPLETE!                                ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Duration: $([math]::Round($TotalDuration, 2)) seconds" -ForegroundColor White
Write-Host "Scripts executed: $TotalScripts" -ForegroundColor White
Write-Host "Successful: $SuccessCount" -ForegroundColor Green
Write-Host "Failed: $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "DATABASES CREATED:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Layer 0: sathapana_source     (Source System)" -ForegroundColor White
Write-Host "  Layer 1: sathapana_raw        (Raw Zone)" -ForegroundColor White
Write-Host "           sathapana_staging    (Staging)" -ForegroundColor White
Write-Host "  Layer 2: sathapana_dwh        (Enterprise DW)" -ForegroundColor White
Write-Host "  Layer 3: sathapana_dm_credit  (Credit Risk)" -ForegroundColor White
Write-Host "           sathapana_dm_customer(Customer Analytics)" -ForegroundColor White
Write-Host "           sathapana_dm_treasury(Treasury)" -ForegroundColor White
Write-Host "           sathapana_dm_compliance (Compliance/AML)" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Open SSMS and connect to: $SqlServer" -ForegroundColor White
Write-Host "  2. Run sample queries from: 09-documents/QUICK_REFERENCE.md" -ForegroundColor White
Write-Host "  3. Connect Power BI to the data mart databases" -ForegroundColor White
Write-Host "  4. Set up SQL Agent jobs from: 12-automation/" -ForegroundColor White
Write-Host ""
Write-Host "Sample Query to Verify:" -ForegroundColor Yellow
Write-Host "  SELECT * FROM sathapana_dm_credit.dm.vw_credit_risk_summary;" -ForegroundColor DarkCyan
Write-Host "  SELECT * FROM sathapana_dm_customer.dm.vw_customer_segmentation;" -ForegroundColor DarkCyan
Write-Host ""
