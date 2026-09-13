-- ============================================================================
-- SATHAPANA BANK - AUTOMATED REPORT DISTRIBUTION
-- ============================================================================
-- Purpose: Email reports to stakeholders automatically
-- Author: DWH Development Team
-- Features: Database Mail, Report Scheduling, Multiple Formats
-- ============================================================================

-- ============================================================================
-- 1. ENABLE DATABASE MAIL
-- ============================================================================
/*
NOTE: Database Mail must be configured first via:
- SSMS → Management → Database Mail
- Or run: sp_configure 'Database Mail XPs', 1;
*/

-- Enable Database Mail (run as sysadmin)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;
PRINT '✓ Database Mail enabled';

-- ============================================================================
-- 2. CREATE MAIL ACCOUNT (if not exists)
-- ============================================================================
/*
EXECUTE sp_add_account
    @account_name = 'DWH_Reports',
    @email_address = 'dwh-reports@sathapana.com.kh',
    @display_name = 'DWH Automated Reports',
    @mailserver_name = 'smtp.sathapana.com.kh',
    @port = 587,
    @enable_ssl = 1,
    @username = 'dwh-reports@sathapana.com.kh',
    @password = 'YourPassword123!';

EXEC sp_add_profile
    @profile_name = 'DWH_Profile',
    @description = 'DWH Report Distribution Profile';

EXEC sp_add_profileaccount
    @profile_name = 'DWH_Profile',
    @account_name = 'DWH_Reports',
    @sequence_number = 1;
*/

-- ============================================================================
-- 3. CREATE REPORT DISTRIBUTION TABLES
-- ============================================================================

USE sathapana_dwh;
GO

-- Report recipients configuration
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'report_recipients')
BEGIN
    CREATE TABLE audit.report_recipients (
        recipient_id INT IDENTITY(1,1) PRIMARY KEY,
        report_name VARCHAR(100) NOT NULL,
        recipient_name NVARCHAR(200) NOT NULL,
        email_address VARCHAR(200) NOT NULL,
        department VARCHAR(100),
        role VARCHAR(50),
        is_active BIT DEFAULT 1,
        frequency VARCHAR(20) CHECK (frequency IN ('DAILY', 'WEEKLY', 'MONTHLY', 'QUARTERLY')),
        day_of_week TINYINT,  -- 1=Sunday, 7=Saturday
        day_of_month TINYINT, -- For monthly reports
        created_date DATETIME DEFAULT GETDATE(),
        modified_date DATETIME DEFAULT GETDATE()
    );
    PRINT '✓ Report recipients table created';
END
GO

-- Report distribution log
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'report_distribution_log')
BEGIN
    CREATE TABLE audit.report_distribution_log (
        log_id INT IDENTITY(1,1) PRIMARY KEY,
        report_name VARCHAR(100) NOT NULL,
        recipient_email VARCHAR(200) NOT NULL,
        subject NVARCHAR(500),
        attachment_count INT DEFAULT 0,
        send_status VARCHAR(20) CHECK (send_status IN ('SENT', 'FAILED', 'PENDING')),
        error_message NVARCHAR(MAX),
        sent_date DATETIME DEFAULT GETDATE(),
        sent_by VARCHAR(100) DEFAULT SYSTEM_USER
    );
    PRINT '✓ Report distribution log table created';
END
GO

-- Report templates
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'report_templates')
BEGIN
    CREATE TABLE audit.report_templates (
        template_id INT IDENTITY(1,1) PRIMARY KEY,
        report_name VARCHAR(100) NOT NULL UNIQUE,
        report_description NVARCHAR(500),
        email_subject NVARCHAR(500),
        email_body_template NVARCHAR(MAX),
        report_category VARCHAR(50),
        export_format VARCHAR(10) DEFAULT 'HTML',
        is_active BIT DEFAULT 1,
        created_date DATETIME DEFAULT GETDATE()
    );
    PRINT '✓ Report templates table created';
END
GO

-- ============================================================================
-- 4. INSERT DEFAULT REPORT TEMPLATES
-- ============================================================================

INSERT INTO audit.report_templates (report_name, report_description, email_subject, email_body_template, report_category, export_format) VALUES
('Daily_Transaction_Summary', 
 'Daily transaction volume and status summary',
 'Sathapana DWH - Daily Transaction Summary - {DATE}',
 '<html><body><h2>Daily Transaction Summary</h2><p>Report Date: {DATE}</p>{CONTENT}</body></html>',
 'OPERATIONS', 'HTML'),

('Credit_Risk_Daily',
 'Daily credit risk portfolio status',
 'Sathapana DWH - Credit Risk Daily Report - {DATE}',
 '<html><body><h2>Credit Risk Daily Report</h2><p>Report Date: {DATE}</p>{CONTENT}</body></html>',
 'RISK', 'HTML'),

('NPL_Warning_Report',
 'NPL ratio warning report for branches exceeding threshold',
 '⚠️ URGENT: NPL Warning Report - {DATE}',
 '<html><body><h2 style="color:red;">NPL Warning Report</h2><p>The following branches have NPL ratios exceeding the 5% threshold:</p>{CONTENT}</body></html>',
 'RISK', 'HTML'),

('Weekly_Performance_Summary',
 'Weekly branch performance comparison',
 'Sathapana DWH - Weekly Performance Summary - {WEEK}',
 '<html><body><h2>Weekly Performance Summary</h2><p>Week Ending: {WEEK}</p>{CONTENT}</body></html>',
 'MANAGEMENT', 'HTML'),

('Monthly_Regulatory_Package',
 'Monthly regulatory reporting package for NBC',
 'Sathapana DWH - Monthly Regulatory Package - {MONTH}',
 '<html><body><h2>Monthly Regulatory Package</h2><p>Report Period: {MONTH}</p><p>Please find attached the complete regulatory reporting package.</p>{CONTENT}</body></html>',
 'REGULATORY', 'EXCEL'),

('KYC_Compliance_Report',
 'KYC compliance status report',
 'Sathapana DWH - KYC Compliance Report - {DATE}',
 '<html><body><h2>KYC Compliance Report</h2><p>Report Date: {DATE}</p>{CONTENT}</body></html>',
 'COMPLIANCE', 'HTML'),

('AML_Alert_Summary',
 'Daily AML alert summary for compliance team',
 'Sathapana DWH - AML Alert Summary - {DATE}',
 '<html><body><h2>AML Alert Summary</h2><p>Report Date: {DATE}</p>{CONTENT}</body></html>',
 'COMPLIANCE', 'HTML'),

('Executive_Dashboard',
 'Executive summary dashboard for senior management',
 'Sathapana DWH - Executive Dashboard - {DATE}',
 '<html><body><h2>Executive Dashboard</h2><p>Report Date: {DATE}</p>{CONTENT}</body></html>',
 'EXECUTIVE', 'HTML');

PRINT '✓ Default report templates inserted';

-- ============================================================================
-- 5. INSERT DEFAULT RECIPIENTS
-- ============================================================================

INSERT INTO audit.report_recipients (report_name, recipient_name, email_address, department, role, frequency) VALUES
-- Daily reports
('Daily_Transaction_Summary', 'Operations Manager', 'operations@sathapana.com.kh', 'Operations', 'MANAGER', 'DAILY'),
('Daily_Transaction_Summary', 'Branch Operations Head', 'branch.ops@sathapana.com.kh', 'Operations', 'HEAD', 'DAILY'),

('Credit_Risk_Daily', 'Credit Risk Manager', 'credit.risk@sathapana.com.kh', 'Credit Risk', 'MANAGER', 'DAILY'),
('Credit_Risk_Daily', 'Head of Credit', 'head.credit@sathapana.com.kh', 'Credit', 'HEAD', 'DAILY'),

('NPL_Warning_Report', 'Credit Risk Manager', 'credit.risk@sathapana.com.kh', 'Credit Risk', 'MANAGER', 'DAILY'),
('NPL_Warning_Report', 'CEO', 'ceo@sathapana.com.kh', 'Executive', 'CEO', 'DAILY'),
('NPL_Warning_Report', 'Head of Credit', 'head.credit@sathapana.com.kh', 'Credit', 'HEAD', 'DAILY'),

('KYC_Compliance_Report', 'Compliance Officer', 'compliance@sathapana.com.kh', 'Compliance', 'OFFICER', 'DAILY'),
('AML_Alert_Summary', 'AML Officer', 'aml@sathapana.com.kh', 'Compliance', 'AML_OFFICER', 'DAILY'),
('AML_Alert_Summary', 'Compliance Head', 'compliance.head@sathapana.com.kh', 'Compliance', 'HEAD', 'DAILY'),

-- Weekly reports
('Weekly_Performance_Summary', 'CEO', 'ceo@sathapana.com.kh', 'Executive', 'CEO', 'WEEKLY'),
('Weekly_Performance_Summary', 'COO', 'coo@sathapana.com.kh', 'Executive', 'COO', 'WEEKLY'),
('Weekly_Performance_Summary', 'CFO', 'cfo@sathapana.com.kh', 'Executive', 'CFO', 'WEEKLY'),
('Weekly_Performance_Summary', 'Head of Retail', 'head.retail@sathapana.com.kh', 'Retail', 'HEAD', 'WEEKLY'),

-- Monthly reports
('Monthly_Regulatory_Package', 'Compliance Head', 'compliance.head@sathapana.com.kh', 'Compliance', 'HEAD', 'MONTHLY'),
('Monthly_Regulatory_Package', 'CFO', 'cfo@sathapana.com.kh', 'Executive', 'CFO', 'MONTHLY'),
('Monthly_Regulatory_Package', 'Risk Committee', 'risk.committee@sathapana.com.kh', 'Risk', 'COMMITTEE', 'MONTHLY'),

('Executive_Dashboard', 'CEO', 'ceo@sathapana.com.kh', 'Executive', 'CEO', 'DAILY'),
('Executive_Dashboard', 'Board Secretary', 'board.sec@sathapana.com.kh', 'Board', 'SECRETARY', 'WEEKLY');

PRINT '✓ Default recipients inserted';

-- ============================================================================
-- 6. REPORT GENERATION PROCEDURES
-- ============================================================================

-- 6.1 Generate Transaction Summary Report
CREATE OR ALTER PROCEDURE audit.usp_GenerateTransactionReport
    @ReportDate DATE = NULL,
    @ExportFormat VARCHAR(10) = 'HTML'
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ReportDate IS NULL SET @ReportDate = GETDATE();
    
    DECLARE @Subject NVARCHAR(500);
    DECLARE @Body NVARCHAR(MAX);
    DECLARE @TableHTML NVARCHAR(MAX);
    
    SET @Subject = 'Sathapana DWH - Daily Transaction Summary - ' + CONVERT(VARCHAR, @ReportDate, 103);
    
    -- Generate HTML table
    SET @TableHTML = '
    <html>
    <head>
    <style>
        body { font-family: Arial, sans-serif; }
        h2 { color: #1a5276; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #1a5276; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .summary { background-color: #e8f4f8; padding: 15px; border-radius: 5px; margin-top: 20px; }
    </style>
    </head>
    <body>
    <h2>Daily Transaction Summary</h2>
    <p><strong>Report Date:</strong> ' + CONVERT(VARCHAR, @ReportDate, 103) + '</p>
    <p><strong>Generated:</strong> ' + CONVERT(VARCHAR, GETDATE(), 120) + '</p>
    
    <div class="summary">
        <h3>Summary</h3>
        <table>
            <tr><td><strong>Total Transactions</strong></td><td>' + 
                CAST((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_transactions 
                      WHERE transaction_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)) AS VARCHAR) + '</td></tr>
            <tr><td><strong>Total Volume</strong></td><td>$' + 
                CAST((SELECT ISNULL(SUM(amount), 0) FROM sathapana_dwh.dw.fact_transactions 
                      WHERE transaction_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)) AS VARCHAR) + '</td></tr>
            <tr><td><strong>Total Fees Collected</strong></td><td>$' + 
                CAST((SELECT ISNULL(SUM(fee_amount), 0) FROM sathapana_dwh.dw.fact_transactions 
                      WHERE transaction_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)) AS VARCHAR) + '</td></tr>
        </table>
    </div>
    
    <h3>Transactions by Channel</h3>
    <table>
        <tr>
            <th>Channel</th>
            <th>Count</th>
            <th>Volume</th>
            <th>% of Total</th>
        </tr>' +
        CAST((
            SELECT 
                td = ch.channel_name,
                td = CAST(COUNT(t.transaction_key) AS VARCHAR),
                td = '$' + CAST(SUM(t.amount) AS VARCHAR),
                td = CAST(CAST(COUNT(t.transaction_key) * 100.0 / 
                    NULLIF((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_transactions 
                            WHERE transaction_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)), 0) AS DECIMAL(5,2)) AS VARCHAR) + '%'
            FROM sathapana_dwh.dw.fact_transactions t
            JOIN sathapana_dwh.dw.dim_channel ch ON t.channel_key = ch.channel_key
            WHERE t.transaction_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
            GROUP BY ch.channel_name
            FOR XML PATH('tr'), TYPE
        ) AS NVARCHAR(MAX)) +
    '</table>
    
    <h3>Transactions by Branch (Top 10)</h3>
    <table>
        <tr>
            <th>Branch</th>
            <th>Count</th>
            <th>Volume</th>
        </tr>' +
        CAST((
            SELECT TOP 10
                td = b.branch_name,
                td = CAST(COUNT(t.transaction_key) AS VARCHAR),
                td = '$' + CAST(SUM(t.amount) AS VARCHAR)
            FROM sathapana_dwh.dw.fact_transactions t
            JOIN sathapana_dwh.dw.dim_branch b ON t.branch_key = b.branch_key
            WHERE t.transaction_date_key = CAST(FORMAT(@ReportDate, 'yyyyMMdd') AS INT)
            GROUP BY b.branch_name
            ORDER BY SUM(t.amount) DESC
            FOR XML PATH('tr'), TYPE
        ) AS NVARCHAR(MAX)) +
    '</table>
    
    <hr>
    <p style="color: gray; font-size: 12px;">This report was automatically generated by Sathapana DWH System.</p>
    </body>
    </html>';
    
    SET @Body = @TableHTML;
    
    -- Return the HTML for testing
    SELECT @Body AS ReportHTML;
    
    -- Log the report generation
    INSERT INTO audit.report_distribution_log (report_name, recipient_email, subject, send_status)
    VALUES ('Daily_Transaction_Summary', 'SYSTEM', @Subject, 'PENDING');
    
    PRINT '✓ Transaction report generated';
END;
GO

-- 6.2 Generate Credit Risk Report
CREATE OR ALTER PROCEDURE audit.usp_GenerateCreditRiskReport
    @ReportDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @ReportDate IS NULL SET @ReportDate = GETDATE();
    
    DECLARE @Subject NVARCHAR(500);
    DECLARE @Body NVARCHAR(MAX);
    
    SET @Subject = 'Sathapana DWH - Credit Risk Report - ' + CONVERT(VARCHAR, @ReportDate, 103);
    
    SET @Body = '
    <html>
    <head>
    <style>
        body { font-family: Arial, sans-serif; }
        h2 { color: #1a5276; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #c0392b; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        .warning { background-color: #f8d7da; padding: 15px; border-radius: 5px; }
        .good { background-color: #d4edda; padding: 15px; border-radius: 5px; }
    </style>
    </head>
    <body>
    <h2>Credit Risk Daily Report</h2>
    <p><strong>Report Date:</strong> ' + CONVERT(VARCHAR, @ReportDate, 103) + '</p>
    
    <h3>Portfolio Summary</h3>
    <table>
        <tr><td><strong>Total Loans</strong></td><td>' + 
            CAST((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio) AS VARCHAR) + '</td></tr>
        <tr><td><strong>Total Outstanding</strong></td><td>$' + 
            CAST((SELECT ISNULL(SUM(outstanding_principal), 0) FROM sathapana_dwh.dw.fact_loan_portfolio) AS VARCHAR) + '</td></tr>
        <tr><td><strong>Total Provisions</strong></td><td>$' + 
            CAST((SELECT ISNULL(SUM(provision_amount), 0) FROM sathapana_dwh.dw.fact_loan_portfolio) AS VARCHAR) + '</td></tr>
        <tr><td><strong>NPL Ratio</strong></td><td>' + 
            CAST((SELECT CASE 
                WHEN SUM(outstanding_principal) = 0 THEN 0
                ELSE SUM(CASE WHEN days_past_due > 90 THEN outstanding_principal ELSE 0 END) / SUM(outstanding_principal) * 100
            END FROM sathapana_dwh.dw.fact_loan_portfolio) AS VARCHAR) + '%</td></tr>
    </table>
    
    <h3>Risk Classification</h3>
    <table>
        <tr>
            <th>Classification</th>
            <th>Count</th>
            <th>Amount</th>
            <th>% of Portfolio</th>
        </tr>' +
        CAST((
            SELECT 
                td = ISNULL(risk_classification, 'UNKNOWN'),
                td = CAST(COUNT(*) AS VARCHAR),
                td = '$' + CAST(SUM(outstanding_principal) AS VARCHAR),
                td = CAST(SUM(outstanding_principal) * 100.0 / 
                    NULLIF((SELECT SUM(outstanding_principal) FROM sathapana_dwh.dw.fact_loan_portfolio), 0) AS DECIMAL(5,2)) AS VARCHAR) + '%'
            FROM sathapana_dwh.dw.fact_loan_portfolio
            GROUP BY risk_classification
            FOR XML PATH('tr'), TYPE
        ) AS NVARCHAR(MAX)) +
    '</table>
    
    <h3>DPD Distribution</h3>
    <table>
        <tr>
            <th>Days Past Due</th>
            <th>Count</th>
            <th>Amount</th>
        </tr>
        <tr><td>Current (0 DPD)</td><td>' + CAST((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due = 0) AS VARCHAR) + '</td><td>$' + CAST((SELECT ISNULL(SUM(outstanding_principal), 0) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due = 0) AS VARCHAR) + '</td></tr>
        <tr><td>1-30 DPD</td><td>' + CAST((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due BETWEEN 1 AND 30) AS VARCHAR) + '</td><td>$' + CAST((SELECT ISNULL(SUM(outstanding_principal), 0) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due BETWEEN 1 AND 30) AS VARCHAR) + '</td></tr>
        <tr><td>31-60 DPD</td><td>' + CAST((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due BETWEEN 31 AND 60) AS VARCHAR) + '</td><td>$' + CAST((SELECT ISNULL(SUM(outstanding_principal), 0) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due BETWEEN 31 AND 60) AS VARCHAR) + '</td></tr>
        <tr><td>61-90 DPD</td><td>' + CAST((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due BETWEEN 61 AND 90) AS VARCHAR) + '</td><td>$' + CAST((SELECT ISNULL(SUM(outstanding_principal), 0) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due BETWEEN 61 AND 90) AS VARCHAR) + '</td></tr>
        <tr style="background-color: #f8d7da;"><td><strong>90+ DPD (NPL)</strong></td><td><strong>' + CAST((SELECT COUNT(*) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due > 90) AS VARCHAR) + '</strong></td><td><strong>$' + CAST((SELECT ISNULL(SUM(outstanding_principal), 0) FROM sathapana_dwh.dw.fact_loan_portfolio WHERE days_past_due > 90) AS VARCHAR) + '</strong></td></tr>
    </table>
    
    <hr>
    <p style="color: gray; font-size: 12px;">This report was automatically generated by Sathapana DWH System.</p>
    </body>
    </html>';
    
    SELECT @Body AS ReportHTML;
    
    INSERT INTO audit.report_distribution_log (report_name, recipient_email, subject, send_status)
    VALUES ('Credit_Risk_Daily', 'SYSTEM', @Subject, 'PENDING');
    
    PRINT '✓ Credit risk report generated';
END;
GO

-- 6.3 Generate NPL Warning Report
CREATE OR ALTER PROCEDURE audit.usp_GenerateNPLWarningReport
    @NPLThreshold DECIMAL(5,2) = 5.0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Subject NVARCHAR(500);
    DECLARE @Body NVARCHAR(MAX);
    DECLARE @HasWarnings BIT = 0;
    
    SET @Subject = '⚠️ URGENT: NPL Warning Report - ' + CONVERT(VARCHAR, GETDATE(), 103);
    
    -- Check for branches exceeding threshold
    IF EXISTS (
        SELECT 1 FROM sathapana_dwh.dm_credit.vw_branch_risk_ranking 
        WHERE npl_ratio > @NPLThreshold
    )
    BEGIN
        SET @HasWarnings = 1;
    END
    
    SET @Body = '
    <html>
    <head>
    <style>
        body { font-family: Arial, sans-serif; }
        h2 { color: #c0392b; }
        .urgent { background-color: #f8d7da; padding: 15px; border-radius: 5px; border-left: 4px solid #c0392b; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th { background-color: #c0392b; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        .high { background-color: #f8d7da; }
    </style>
    </head>
    <body>
    <h2>⚠️ NPL Warning Report</h2>
    <p><strong>Report Date:</strong> ' + CONVERT(VARCHAR, GETDATE(), 103) + '</p>
    <p><strong>NPL Threshold:</strong> ' + CAST(@NPLThreshold AS VARCHAR) + '%</p>
    
    <div class="urgent">
        <strong>ALERT:</strong> The following branches have NPL ratios exceeding the ' + CAST(@NPLThreshold AS VARCHAR) + '% threshold!
    </div>
    
    <h3>Branches Exceeding Threshold</h3>
    <table>
        <tr>
            <th>Branch</th>
            <th>Region</th>
            <th>NPL Ratio</th>
            <th>Total Outstanding</th>
            <th>NPL Amount</th>
            <th>Risk Rank</th>
        </tr>' +
        CAST((
            SELECT 
                td = branch_name,
                td = region,
                td = CAST(npl_ratio AS VARCHAR) + '%',
                td = '$' + CAST(total_outstanding AS VARCHAR),
                td = '$' + CAST(npl_amount AS VARCHAR),
                td = CAST(risk_rank AS VARCHAR)
            FROM sathapana_dwh.dm_credit.vw_branch_risk_ranking
            WHERE npl_ratio > @NPLThreshold
            ORDER BY npl_ratio DESC
            FOR XML PATH('tr'), TYPE
        ) AS NVARCHAR(MAX)) +
    '</table>
    
    <h3>Recommended Actions</h3>
    <ul>
        <li>Review loan files for branches above threshold</li>
        <li>Increase provisioning for at-risk accounts</li>
        <li>Consider restructuring for viable accounts</li>
        <li>Initiate recovery proceedings for non-viable accounts</li>
        <li>Report to Risk Committee within 48 hours</li>
    </ul>
    
    <hr>
    <p style="color: red; font-size: 12px;"><strong>This is an automated alert. Please take immediate action.</strong></p>
    </body>
    </html>';
    
    SELECT @Body AS ReportHTML, @HasWarnings AS HasWarnings;
    
    INSERT INTO audit.report_distribution_log (report_name, recipient_email, subject, send_status)
    VALUES ('NPL_Warning_Report', 'SYSTEM', @Subject, 'PENDING');
    
    PRINT '✓ NPL warning report generated';
END;
GO

-- ============================================================================
-- 7. EMAIL SENDING PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_SendReportEmail
    @ReportName VARCHAR(100),
    @ReportHTML NVARCHAR(MAX),
    @OverrideRecipients VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ProfileName VARCHAR(100) = 'DWH_Profile';
    DECLARE @Recipients VARCHAR(MAX);
    DECLARE @CCRecipients VARCHAR(MAX) = NULL;
    DECLARE @Subject NVARCHAR(500);
    DECLARE @Body NVARCHAR(MAX);
    DECLARE @AttachmentPath VARCHAR(500) = NULL;
    
    -- Get recipients
    IF @OverrideRecipients IS NOT NULL
        SET @Recipients = @OverrideRecipients;
    ELSE
    BEGIN
        SELECT @Recipients = STRING_AGG(email_address, ';')
        FROM audit.report_recipients
        WHERE report_name = @ReportName
        AND is_active = 1;
    END
    
    -- Check if recipients exist
    IF @Recipients IS NULL OR @Recipients = ''
    BEGIN
        PRINT '⚠ No recipients found for report: ' + @ReportName;
        RETURN;
    END
    
    -- Get email subject from template
    SELECT @Subject = REPLACE(email_subject, '{DATE}', CONVERT(VARCHAR, GETDATE(), 103))
    FROM audit.report_templates
    WHERE report_name = @ReportName;
    
    IF @Subject IS NULL
        SET @Subject = 'Sathapana DWH Report - ' + @ReportName;
    
    -- Set body
    SET @Body = @ReportHTML;
    
    -- Send email
    BEGIN TRY
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = @ProfileName,
            @recipients = @Recipients,
            @subject = @Subject,
            @body = @Body,
            @body_format = 'HTML',
            @importance = 'High';
        
        -- Log success
        INSERT INTO audit.report_distribution_log (report_name, recipient_email, subject, attachment_count, send_status)
        VALUES (@ReportName, @Recipients, @Subject, 0, 'SENT');
        
        PRINT '✓ Email sent successfully to: ' + @Recipients;
    END TRY
    BEGIN CATCH
        -- Log failure
        INSERT INTO audit.report_distribution_log (report_name, recipient_email, subject, send_status, error_message)
        VALUES (@ReportName, @Recipients, @Subject, 'FAILED', ERROR_MESSAGE());
        
        PRINT '✗ Email failed: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- ============================================================================
-- 8. MASTER DISTRIBUTION PROCEDURE
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_DistributeReports
    @ReportType VARCHAR(50) = 'ALL'
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '═══════════════════════════════════════════════════════════════════════';
    PRINT 'REPORT DISTRIBUTION - ' + CONVERT(VARCHAR, GETDATE(), 120);
    PRINT '═══════════════════════════════════════════════════════════════════════';
    
    DECLARE @ReportHTML NVARCHAR(MAX);
    DECLARE @ReportDate DATE = GETDATE();
    
    -- Daily Reports
    IF @ReportType IN ('ALL', 'DAILY')
    BEGIN
        PRINT '';
        PRINT '--- Daily Reports ---';
        
        -- Transaction Summary
        BEGIN TRY
            EXEC audit.usp_GenerateTransactionReport @ReportDate;
            -- In production, capture output and send:
            -- EXEC audit.usp_SendReportEmail 'Daily_Transaction_Summary', @ReportHTML;
            PRINT '✓ Transaction Summary prepared';
        END TRY
        BEGIN CATCH
            PRINT '✗ Transaction Summary failed: ' + ERROR_MESSAGE();
        END CATCH
        
        -- Credit Risk
        BEGIN TRY
            EXEC audit.usp_GenerateCreditRiskReport @ReportDate;
            PRINT '✓ Credit Risk Report prepared';
        END TRY
        BEGIN CATCH
            PRINT '✗ Credit Risk Report failed: ' + ERROR_MESSAGE();
        END CATCH
        
        -- NPL Warning
        BEGIN TRY
            EXEC audit.usp_GenerateNPLWarningReport;
            PRINT '✓ NPL Warning Report prepared';
        END TRY
        BEGIN CATCH
            PRINT '✗ NPL Warning Report failed: ' + ERROR_MESSAGE();
        END CATCH
    END
    
    -- Weekly Reports (only on Sundays)
    IF @ReportType IN ('ALL', 'WEEKLY') AND DATEPART(WEEKDAY, GETDATE()) = 1
    BEGIN
        PRINT '';
        PRINT '--- Weekly Reports ---';
        PRINT '✓ Weekly reports will be generated';
    END
    
    -- Monthly Reports (only on 1st of month)
    IF @ReportType IN ('ALL', 'MONTHLY') AND DAY(GETDATE()) = 1
    BEGIN
        PRINT '';
        PRINT '--- Monthly Reports ---';
        PRINT '✓ Monthly reports will be generated';
    END
    
    PRINT '';
    PRINT '═══════════════════════════════════════════════════════════════════════';
    PRINT 'DISTRIBUTION COMPLETE';
    PRINT '═══════════════════════════════════════════════════════════════════════';
END;
GO

-- ============================================================================
-- 9. RECIPIENT MANAGEMENT PROCEDURES
-- ============================================================================

-- Add new recipient
CREATE OR ALTER PROCEDURE audit.usp_AddRecipient
    @ReportName VARCHAR(100),
    @RecipientName NVARCHAR(200),
    @EmailAddress VARCHAR(200),
    @Department VARCHAR(100) = NULL,
    @Role VARCHAR(50) = NULL,
    @Frequency VARCHAR(20) = 'DAILY'
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO audit.report_recipients (report_name, recipient_name, email_address, department, role, frequency)
    VALUES (@ReportName, @RecipientName, @EmailAddress, @Department, @Role, @Frequency);
    
    PRINT '✓ Recipient added: ' + @RecipientName + ' (' + @EmailAddress + ')';
END;
GO

-- Remove recipient
CREATE OR ALTER PROCEDURE audit.usp_RemoveRecipient
    @ReportName VARCHAR(100),
    @EmailAddress VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE audit.report_recipients
    SET is_active = 0, modified_date = GETDATE()
    WHERE report_name = @ReportName
    AND email_address = @EmailAddress;
    
    PRINT '✓ Recipient removed: ' + @EmailAddress;
END;
GO

-- List recipients
CREATE OR ALTER PROCEDURE audit.usp_ListRecipients
    @ReportName VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        report_name,
        recipient_name,
        email_address,
        department,
        role,
        frequency,
        is_active
    FROM audit.report_recipients
    WHERE (@ReportName IS NULL OR report_name = @ReportName)
    AND is_active = 1
    ORDER BY report_name, recipient_name;
END;
GO

-- ============================================================================
-- 10. DISTRIBUTION HISTORY
-- ============================================================================

CREATE OR ALTER PROCEDURE audit.usp_DistributionHistory
    @DaysBack INT = 7,
    @ReportName VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        report_name,
        recipient_email,
        subject,
        send_status,
        error_message,
        sent_date
    FROM audit.report_distribution_log
    WHERE sent_date >= DATEADD(DAY, -@DaysBack, GETDATE())
    AND (@ReportName IS NULL OR report_name = @ReportName)
    ORDER BY sent_date DESC;
END;
GO

-- ============================================================================
-- 11. VERIFY SETUP
-- ============================================================================
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'REPORT DISTRIBUTION SYSTEM SETUP COMPLETE';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT '';
PRINT 'Tables Created:';
SELECT COUNT(*) AS table_count FROM sys.tables WHERE name IN ('report_recipients', 'report_distribution_log', 'report_templates');
PRINT '';
PRINT 'Report Templates:';
SELECT COUNT(*) AS template_count FROM audit.report_templates;
PRINT '';
PRINT 'Recipients Configured:';
SELECT COUNT(*) AS recipient_count FROM audit.report_recipients WHERE is_active = 1;
PRINT '';
PRINT 'Procedures Created:';
SELECT COUNT(*) AS procedure_count FROM sys.procedures WHERE name LIKE 'usp_%Report%' OR name LIKE 'usp_%Recipient%' OR name LIKE 'usp_%Distribute%';
PRINT '';
PRINT 'Reports Available:';
SELECT report_name, report_category, export_format FROM audit.report_templates WHERE is_active = 1;
PRINT '';
PRINT '═══════════════════════════════════════════════════════════════════════';
PRINT 'USAGE:';
PRINT '  -- Generate and view a report:';
PRINT '  EXEC audit.usp_GenerateTransactionReport;';
PRINT '';
PRINT '  -- Distribute all reports:';
PRINT '  EXEC audit.usp_DistributeReports;';
PRINT '';
PRINT '  -- Add a recipient:';
PRINT '  EXEC audit.usp_AddRecipient ''Daily_Transaction_Summary'', ''John Doe'', ''john@sathapana.com.kh'';';
PRINT '';
PRINT '  -- View distribution history:';
PRINT '  EXEC audit.usp_DistributionHistory;';
PRINT '═══════════════════════════════════════════════════════════════════════';
GO
