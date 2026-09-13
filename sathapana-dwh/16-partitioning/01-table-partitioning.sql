-- ============================================================================
-- SATHAPANA BANK - TABLE PARTITIONING
-- ============================================================================
-- Purpose: Create partitioning for large fact tables (performance)
-- Author: DWH Development Team
-- ============================================================================

USE sathapana_dwh;
GO

-- ============================================================================
-- 1. CREATE PARTITION FUNCTION (Monthly)
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'PF_Monthly')
BEGIN
    CREATE PARTITION FUNCTION PF_Monthly (INT)
    AS RANGE RIGHT FOR VALUES (
        20230101, 20230201, 20230301, 20230401, 20230501, 20230601,
        20230701, 20230801, 20230901, 20231001, 20231101, 20231201,
        20240101, 20240201, 20240301, 20240401, 20240501, 20240601,
        20240701, 20240801, 20240901, 20241001, 20241101, 20241201,
        20250101, 20250201, 20250301, 20250401, 20250501, 20250601,
        20250701, 20250801, 20250901, 20251001, 20251101, 20251201,
        20260101, 20260201, 20260301, 20260401, 20260501, 20260601,
        20260701, 20260801, 20260901, 20261001, 20261101, 20261201
    );
    PRINT '✓ Partition function PF_Monthly created';
END
GO

-- ============================================================================
-- 2. CREATE PARTITION SCHEME
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'PS_Monthly')
BEGIN
    CREATE PARTITION SCHEME PS_Monthly
    AS PARTITION PF_Monthly
    ALL TO ([PRIMARY]);
    PRINT '✓ Partition scheme PS_Monthly created';
END
GO

-- ============================================================================
-- 3. PARTITIONED TABLE EXAMPLES
-- ============================================================================

-- Note: To partition existing tables, you need to recreate them
-- Below is the pattern for new partitioned tables

-- Example: Partitioned Fact Transactions (for large volumes)
/*
CREATE TABLE dw.fact_transactions_partitioned (
    transaction_key     BIGINT IDENTITY(1,1),
    transaction_code    VARCHAR(30) NOT NULL,
    account_key         INT NOT NULL,
    customer_key        INT NOT NULL,
    product_key         INT NOT NULL,
    branch_key          INT NOT NULL,
    channel_key         INT NOT NULL,
    transaction_date_key INT NOT NULL,  -- Partition key
    amount              DECIMAL(18,2) NOT NULL,
    amount_usd          DECIMAL(18,2),
    currency            VARCHAR(3) NOT NULL,
    transaction_datetime DATETIME NOT NULL,
    etl_load_date       DATETIME DEFAULT GETDATE(),
    PRIMARY KEY (transaction_key, transaction_date_key)  -- Include partition key
) ON PS_Monthly(transaction_date_key);
*/

-- ============================================================================
-- 4. PARTITION MANAGEMENT PROCEDURES
-- ============================================================================

-- Add new partition for next month
CREATE OR ALTER PROCEDURE dw.usp_AddPartition
    @PartitionDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PartitionValue INT = CAST(FORMAT(@PartitionDate, 'yyyyMMdd') AS INT);
    DECLARE @NextPartitionValue INT = CAST(FORMAT(DATEADD(MONTH, 1, @PartitionDate), 'yyyyMMdd') AS INT);
    
    PRINT 'Adding partition for: ' + CONVERT(VARCHAR, @PartitionDate, 103);
    
    -- Split the last partition
    ALTER PARTITION FUNCTION PF_Monthly()
    SPLIT RANGE (@NextPartitionValue);
    
    PRINT '✓ Partition added successfully';
END;
GO

-- Merge old partitions (for archiving)
CREATE OR ALTER PROCEDURE dw.usp_MergePartition
    @PartitionDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PartitionValue INT = CAST(FORMAT(@PartitionDate, 'yyyyMMdd') AS INT);
    
    PRINT 'Merging partition for: ' + CONVERT(VARCHAR, @PartitionDate, 103);
    
    -- Merge the partition
    ALTER PARTITION FUNCTION PF_Monthly()
    MERGE RANGE (@PartitionValue);
    
    PRINT '✓ Partition merged successfully';
END;
GO

-- ============================================================================
-- 5. PARTITION SWITCHING (For data archiving)
-- ============================================================================

-- Switch out old data to archive table
CREATE OR ALTER PROCEDURE dw.usp_SwitchPartitionToArchive
    @SourceTable VARCHAR(100),
    @ArchiveTable VARCHAR(100),
    @PartitionValue INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    
    PRINT 'Switching partition ' + CAST(@PartitionValue AS VARCHAR) + ' to archive...';
    
    -- Switch partition
    SET @SQL = 'ALTER TABLE ' + @SourceTable + 
               ' SWITCH PARTITION ' + CAST(@PartitionValue AS VARCHAR) +
               ' TO ' + @ArchiveTable + ' PARTITION ' + CAST(@PartitionValue AS VARCHAR);
    
    EXEC sp_executesql @SQL;
    
    PRINT '✓ Partition switched successfully';
END;
GO

-- ============================================================================
-- 6. PARTITION INFO VIEW
-- ============================================================================

CREATE OR ALTER VIEW dw.vw_PartitionInfo AS
SELECT 
    pf.name AS partition_function,
    ps.name AS partition_scheme,
    p.partition_number,
    p.rows AS row_count,
    rv.value AS boundary_value,
    CASE 
        WHEN rv.value IS NULL THEN 'LEFT'
        ELSE 'RIGHT'
    END AS range_type
FROM sys.partition_functions pf
JOIN sys.partition_schemes ps ON pf.function_id = ps.function_id
JOIN sys.partitions p ON ps.data_space_id = p.data_space_id
LEFT JOIN sys.partition_range_values rv ON pf.function_id = rv.function_id 
    AND rv.boundary_id = p.partition_number
WHERE p.object_id = OBJECT_ID('dw.fact_transactions')
ORDER BY p.partition_number;
GO

-- ============================================================================
-- 7. MAINTENANCE PROCEDURE FOR PARTITIONS
-- ============================================================================

CREATE OR ALTER PROCEDURE dw.usp_PartitionMaintenance
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT 'Running partition maintenance...';
    
    -- Add partitions for next 12 months
    DECLARE @i INT = 0;
    WHILE @i < 12
    BEGIN
        DECLARE @FutureDate DATE = DATEADD(MONTH, @i, GETDATE());
        
        BEGIN TRY
            EXEC dw.usp_AddPartition @FutureDate;
        END TRY
        BEGIN CATCH
            -- Partition may already exist
            PRINT 'Partition already exists for ' + CONVERT(VARCHAR, @FutureDate, 103);
        END CATCH
        
        SET @i = @i + 1;
    END
    
    -- Show current partition info
    SELECT * FROM dw.vw_PartitionInfo;
    
    PRINT 'Partition maintenance completed';
END;
GO

-- ============================================================================
-- 8. VERIFY PARTITIONING
-- ============================================================================
PRINT '================================================';
PRINT 'PARTITIONING SETUP COMPLETED';
PRINT '================================================';
PRINT '';
PRINT 'Procedures created:';
SELECT COUNT(*) AS procedure_count 
FROM sys.procedures 
WHERE schema_id = SCHEMA_ID('dw') 
AND name LIKE 'usp_%Partition%';
PRINT '';
PRINT 'Note: Apply partitioning to fact tables during next maintenance window';
PRINT '================================================';
GO
