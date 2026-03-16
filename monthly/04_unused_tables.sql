-- ============================================================
-- Monthly | 04 - Unused Tables (no user reads in stats cache)
-- Run on: Primary
-- REVIEW before action - stats reset on restart and failover.
-- Allow at least 1 week of workload post-failover before acting.
-- ============================================================
SELECT
    SCHEMA_NAME(t.schema_id)  AS schema_name,
    t.name                    AS table_name,
    SUM(p.rows)               AS row_count,
    MAX(u.last_user_seek)     AS last_seek,
    MAX(u.last_user_scan)     AS last_scan,
    MAX(u.last_user_lookup)   AS last_lookup,
    MAX(u.last_user_update)   AS last_update
FROM sys.tables t
JOIN sys.indexes    i ON t.object_id = i.object_id AND i.index_id <= 1
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
LEFT JOIN sys.dm_db_index_usage_stats u
       ON t.object_id = u.object_id AND u.database_id = DB_ID()
GROUP BY t.schema_id, t.name
HAVING MAX(u.last_user_seek)   IS NULL
   AND MAX(u.last_user_scan)   IS NULL
   AND MAX(u.last_user_lookup) IS NULL
ORDER BY row_count DESC;
