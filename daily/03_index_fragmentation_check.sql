-- ============================================================
-- Daily | 03 - Index Fragmentation Check (LIMITED scan)
-- Run on: Primary (UK South)
-- Note: LIMITED mode keeps DTU impact low for a daily check.
--       Fragmented indexes here are actioned in weekly\01_index_maintenance.sql
-- ============================================================
SELECT
    OBJECT_NAME(i.object_id)       AS table_name,
    i.name                         AS index_name,
    s.avg_fragmentation_in_percent,
    s.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.avg_fragmentation_in_percent > 10
  AND s.page_count > 100
ORDER BY s.avg_fragmentation_in_percent DESC;
