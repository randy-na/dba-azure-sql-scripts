-- ============================================================
-- Daily | 04 - Update Statistics (stale tables only)
-- Run on: Primary ONLY - will fail on read-only secondary
-- Targets tables where < 80% of rows were sampled, catching
-- stale stats between weekly sp_updatestats runs.
-- ============================================================
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += N'UPDATE STATISTICS ' + QUOTENAME(SCHEMA_NAME(t.schema_id))
             + N'.' + QUOTENAME(t.name) + N' WITH SAMPLE 30 PERCENT;' + CHAR(10)
FROM sys.tables t
JOIN sys.stats s ON t.object_id = s.object_id
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE sp.modification_counter > 0
  AND (sp.rows_sampled * 1.0 / NULLIF(sp.rows, 0)) < 0.8;

EXEC sp_executesql @sql;
