-- ============================================================
-- Monthly | 04 - Unused Tables (no user reads in stats cache)
-- Run on: Primary
-- REVIEW before action - stats reset on restart and failover.
-- Allow at least 1 week of workload post-failover before acting.
-- ============================================================
WITH table_rows AS (
    SELECT
        ps.object_id,
        row_count = SUM(ps.row_count)
    FROM sys.dm_db_partition_stats ps
    WHERE ps.index_id <= 1
    GROUP BY ps.object_id
),
table_usage AS (
    SELECT
        u.object_id,
        last_seek = MAX(u.last_user_seek),
        last_scan = MAX(u.last_user_scan),
        last_lookup = MAX(u.last_user_lookup),
        last_update = MAX(u.last_user_update)
    FROM sys.dm_db_index_usage_stats u
    WHERE u.database_id = DB_ID()
    GROUP BY u.object_id
)
SELECT
    SCHEMA_NAME(t.schema_id) AS schema_name,
    t.name AS table_name,
    tr.row_count,
    tu.last_seek,
    tu.last_scan,
    tu.last_lookup,
    tu.last_update
FROM sys.tables t
JOIN table_rows tr
  ON t.object_id = tr.object_id
LEFT JOIN table_usage tu
  ON t.object_id = tu.object_id
WHERE tu.last_seek IS NULL
  AND tu.last_scan IS NULL
  AND tu.last_lookup IS NULL
ORDER BY row_count DESC;
