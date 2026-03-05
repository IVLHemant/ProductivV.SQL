USE [InfoVision_IVLDubai]
GO

/****** Object:  StoredProcedure [dbo].[usp_IndexHealthReport]    Script Date: 05-03-2026 14:25:54 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE [dbo].[usp_IndexHealthReport]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DBName SYSNAME = DB_NAME();

    -------------------------------------------------------------
    -- UNUSED INDEXES (Exclude PK & Unique)
    -------------------------------------------------------------
    INSERT INTO dbo.IndexHealthReport
    (
        DatabaseName, SchemaName, TableName, IndexName,
        IndexType, IndexSizeMB,
        UserSeeks, UserScans, UserLookups, UserUpdates,
        LastUserSeek, LastUserScan, LastUserLookup,
        ReportType
    )
    SELECT
        @DBName,
        SCHEMA_NAME(o.schema_id),
        OBJECT_NAME(i.object_id),
        i.name,
        i.type_desc,
        CAST(SUM(a.total_pages) * 8.0 / 1024 AS DECIMAL(18,2)) AS IndexSizeMB,
        ISNULL(s.user_seeks,0),
        ISNULL(s.user_scans,0),
        ISNULL(s.user_lookups,0),
        ISNULL(s.user_updates,0),
        s.last_user_seek,
        s.last_user_scan,
        s.last_user_lookup,
        'Unused Index'
    FROM sys.indexes i
    JOIN sys.objects o
        ON i.object_id = o.object_id
    JOIN sys.partitions p
        ON i.object_id = p.object_id AND i.index_id = p.index_id
    JOIN sys.allocation_units a
        ON p.partition_id = a.container_id
    LEFT JOIN sys.dm_db_index_usage_stats s
        ON i.object_id = s.object_id
        AND i.index_id = s.index_id
        AND s.database_id = DB_ID()
    WHERE o.type = 'U'
        AND i.index_id > 0
        AND i.is_primary_key = 0
        AND i.is_unique = 0
        AND ISNULL(s.user_seeks,0) = 0
        AND ISNULL(s.user_scans,0) = 0
        AND ISNULL(s.user_lookups,0) = 0
    GROUP BY 
        o.schema_id, i.object_id, i.name, i.type_desc,
        s.user_seeks, s.user_scans, s.user_lookups, 
        s.user_updates, s.last_user_seek,
        s.last_user_scan, s.last_user_lookup;

    -------------------------------------------------------------
    -- MISSING INDEXES (Ranked by Impact)
    -------------------------------------------------------------
    INSERT INTO dbo.IndexHealthReport
    (
        DatabaseName, SchemaName, TableName,
        ReportType, MissingIndexImpact,
        MissingIndexScript
    )
    SELECT
        @DBName,
        SCHEMA_NAME(o.schema_id),
        OBJECT_NAME(d.object_id),
        'Missing Index',
        migs.avg_user_impact,
        'CREATE INDEX IX_' + OBJECT_NAME(d.object_id) + '_Auto ON ' +
        QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' +
        QUOTENAME(OBJECT_NAME(d.object_id)) +
        ' (' + ISNULL(d.equality_columns,'') +
        CASE WHEN d.inequality_columns IS NOT NULL 
            THEN ',' + d.inequality_columns ELSE '' END + ')' +
        CASE WHEN d.included_columns IS NOT NULL
            THEN ' INCLUDE (' + d.included_columns + ')'
            ELSE '' END
    FROM sys.dm_db_missing_index_details d
    JOIN sys.dm_db_missing_index_groups g
        ON d.index_handle = g.index_handle
    JOIN sys.dm_db_missing_index_group_stats migs
        ON g.index_group_handle = migs.group_handle
    JOIN sys.objects o
        ON d.object_id = o.object_id
    WHERE d.database_id = DB_ID()
    ORDER BY migs.avg_user_impact DESC;

END;
GO


