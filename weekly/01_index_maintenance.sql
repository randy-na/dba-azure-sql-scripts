-- ============================================================
-- Weekly | 01 - Index Maintenance (REORGANIZE > 10%, REBUILD > 30%)
-- Run on: Primary ONLY
-- ONLINE = ON is supported on Premium tier.
-- After a failover, re-run this on the new primary —
-- sys.dm_db_index_usage_stats resets on failover.
-- ============================================================

-- Guard: abort if running on the read-only secondary
IF DATABASEPROPERTYEX(DB_NAME(), 'Updateability') = 'READ_ONLY'
BEGIN
    RAISERROR('This script must be run on the primary (UK South). Secondary is read-only.', 16, 1);
    RETURN;
END;

DECLARE @object_id   INT,
        @index_id    INT,
        @schema_name NVARCHAR(128),
        @table_name  NVARCHAR(128),
        @index_name  NVARCHAR(128),
        @frag        FLOAT,
        @sql         NVARCHAR(MAX);

DECLARE idx_cursor CURSOR FOR
    SELECT
        s.object_id,
        s.index_id,
        SCHEMA_NAME(t.schema_id),
        t.name,
        i.name,
        s.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') s
    JOIN sys.tables  t ON s.object_id = t.object_id
    JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
    WHERE s.avg_fragmentation_in_percent > 10
      AND s.page_count > 100
      AND i.index_id > 0  -- exclude heaps
    ORDER BY s.avg_fragmentation_in_percent DESC;

OPEN idx_cursor;
FETCH NEXT FROM idx_cursor INTO @object_id, @index_id, @schema_name, @table_name, @index_name, @frag;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @frag > 30
        SET @sql = N'ALTER INDEX ' + QUOTENAME(@index_name)
                 + N' ON ' + QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name)
                 + N' REBUILD WITH (ONLINE = ON);';
    ELSE
        SET @sql = N'ALTER INDEX ' + QUOTENAME(@index_name)
                 + N' ON ' + QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name)
                 + N' REORGANIZE;';

    EXEC sp_executesql @sql;
    FETCH NEXT FROM idx_cursor INTO @object_id, @index_id, @schema_name, @table_name, @index_name, @frag;
END;

CLOSE idx_cursor;
DEALLOCATE idx_cursor;
