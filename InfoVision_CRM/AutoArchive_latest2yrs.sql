USE [InfoVision_CRM]
GO

/****** Object:  StoredProcedure [dbo].[AutoArchive_CRM_Latest2Years]    Script Date: 05-03-2026 14:54:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[AutoArchive_CRM_Latest2Years]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @SourceDB SYSNAME = 'PeP_DB_Dubai_03Feb2026',
        @TargetDB SYSNAME = 'InfoVision_CRM',
        @TableName SYSNAME,
        @SQL NVARCHAR(MAX),
        @ColumnList NVARCHAR(MAX),
        @PKJoinCondition NVARCHAR(MAX),
        @HasIdentity BIT,
        @HasDateColumn BIT,
        @InsertedCount INT;

    ------------------------------------------------------------
    -- Log table
    ------------------------------------------------------------
    IF OBJECT_ID('dbo.ArchiveLog','U') IS NULL
    BEGIN
        CREATE TABLE dbo.ArchiveLog
        (
            LogID INT IDENTITY(1,1) PRIMARY KEY,
            TableName SYSNAME,
            InsertedCount INT,
            LogTime DATETIME DEFAULT GETDATE()
        );
    END;

    ------------------------------------------------------------
    -- Table list
    ------------------------------------------------------------
    DECLARE @Tables TABLE (TableName SYSNAME);
    INSERT INTO @Tables VALUES
        ('Employee'),
        ('ProjectEmployeeServicesMapping'),
        ('Projects'),
        ('Role'),
        ('UserRoles'),
        ('LocationMaster');

    ------------------------------------------------------------
    -- Cursor
    ------------------------------------------------------------
    DECLARE c CURSOR FOR SELECT TableName FROM @Tables;
    OPEN c;
    FETCH NEXT FROM c INTO @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --------------------------------------------------------
        -- Identity check
        --------------------------------------------------------
        SELECT @HasIdentity =
        CASE WHEN EXISTS (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(@TargetDB + '.dbo.' + @TableName)
              AND is_identity = 1
        ) THEN 1 ELSE 0 END;

        --------------------------------------------------------
        -- Date column check
        --------------------------------------------------------
        SELECT @HasDateColumn =
        CASE WHEN EXISTS (
            SELECT 1 FROM sys.columns
            WHERE object_id = OBJECT_ID(@TargetDB + '.dbo.' + @TableName)
              AND name IN ('CreatedDate','LastModifiedDate')
        ) THEN 1 ELSE 0 END;

        --------------------------------------------------------
        -- Build column list (EXPLICIT!)
        --------------------------------------------------------
        SELECT @ColumnList =
        STRING_AGG(QUOTENAME(name), ', ')
        FROM sys.columns
        WHERE object_id = OBJECT_ID(@TargetDB + '.dbo.' + @TableName);

        --------------------------------------------------------
        -- Build PK join
        --------------------------------------------------------
        SELECT @PKJoinCondition =
        STRING_AGG(
            't.' + QUOTENAME(c.name) + ' = s.' + QUOTENAME(c.name),
            ' AND '
        )
        FROM sys.key_constraints kc
        JOIN sys.index_columns ic
            ON kc.parent_object_id = ic.object_id
           AND kc.unique_index_id = ic.index_id
        JOIN sys.columns c
            ON ic.object_id = c.object_id
           AND ic.column_id = c.column_id
        WHERE kc.type = 'PK'
          AND kc.parent_object_id = OBJECT_ID(@TargetDB + '.dbo.' + @TableName);

        --------------------------------------------------------
        -- Dynamic SQL
        --------------------------------------------------------
        SET @SQL = N'
        DECLARE @rc INT;

        ALTER TABLE ' + QUOTENAME(@TargetDB) + '.dbo.' + QUOTENAME(@TableName) + ' NOCHECK CONSTRAINT ALL;

        ' + CASE WHEN @HasIdentity = 1
            THEN 'SET IDENTITY_INSERT ' + QUOTENAME(@TargetDB) + '.dbo.' + QUOTENAME(@TableName) + ' ON;'
            ELSE '' END + '

        INSERT INTO ' + QUOTENAME(@TargetDB) + '.dbo.' + QUOTENAME(@TableName) + ' (' + @ColumnList + ')
        SELECT ' + @ColumnList + '
        FROM ' + QUOTENAME(@SourceDB) + '.dbo.' + QUOTENAME(@TableName) + ' s
        WHERE 1 = 1
        ' + CASE WHEN @HasDateColumn = 1
            THEN '
              AND CAST(COALESCE(s.LastModifiedDate, s.CreatedDate, ''1900-01-01'') AS DATE)
                  >= DATEADD(YEAR, -2, CAST(GETDATE() AS DATE))'
            ELSE ''
          END + '
        ' + CASE WHEN @PKJoinCondition IS NOT NULL
            THEN '
              AND NOT EXISTS (
                  SELECT 1 FROM ' + QUOTENAME(@TargetDB) + '.dbo.' + QUOTENAME(@TableName) + ' t
                  WHERE ' + @PKJoinCondition + '
              )'
            ELSE ''
          END + ';

        SET @rc = @@ROWCOUNT;

        ' + CASE WHEN @HasIdentity = 1
            THEN 'SET IDENTITY_INSERT ' + QUOTENAME(@TargetDB) + '.dbo.' + QUOTENAME(@TableName) + ' OFF;'
            ELSE '' END + '

        ALTER TABLE ' + QUOTENAME(@TargetDB) + '.dbo.' + QUOTENAME(@TableName) + ' CHECK CONSTRAINT ALL;

        SELECT @InsertedCountOUT = @rc;
        ';

        EXEC sys.sp_executesql
            @SQL,
            N'@InsertedCountOUT INT OUTPUT',
            @InsertedCountOUT = @InsertedCount OUTPUT;

        INSERT INTO dbo.ArchiveLog (TableName, InsertedCount)
        VALUES (@TableName, @InsertedCount);

        FETCH NEXT FROM c INTO @TableName;
    END;

    CLOSE c;
    DEALLOCATE c;
END;
GO


