-- ============================================================
-- Weekly | 03 - Unused Indexes
-- Run on: Primary (UK South)
-- REVIEW before dropping — stats reset on service restart and failover.
-- Allow at least 1 week of workload post-failover before acting.
-- ============================================================
SELECT
    SCHEMA_NAME(t.schema_id)    AS schema_name,
    t.name                      AS table_name,
    i.name                      AS index_name,
    i.type_desc,
    u.user_seeks,
    u.user_scans,
    u.user_lookups,
    u.user_updates
FROM sys.indexes i
JOIN sys.tables  t ON i.object_id = t.object_id
LEFT JOIN sys.dm_db_index_usage_stats u
       ON i.object_id = u.object_id
      AND i.index_id  = u.index_id
      AND u.database_id = DB_ID()
WHERE i.index_id > 0
  AND i.is_primary_key = 0
  AND i.is_unique = 0
  AND ISNULL(u.user_seeks, 0) = 0
  AND ISNULL(u.user_scans, 0) = 0
  AND ISNULL(u.user_lookups, 0) = 0
ORDER BY u.user_updates DESC;
