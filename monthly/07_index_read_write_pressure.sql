-- ============================================================
-- Monthly | 07 - Index Read / Write Pressure
-- Run on: Primary
-- REVIEW before dropping anything.
-- Highlights indexes with high write cost and low read benefit.
-- ============================================================
WITH usage_stats AS (
    SELECT
        u.object_id,
        u.index_id,
        user_seeks = ISNULL(u.user_seeks, 0),
        user_scans = ISNULL(u.user_scans, 0),
        user_lookups = ISNULL(u.user_lookups, 0),
        user_updates = ISNULL(u.user_updates, 0)
    FROM sys.dm_db_index_usage_stats u
    WHERE u.database_id = DB_ID()
),
operational_stats AS (
    SELECT
        object_id,
        index_id,
        leaf_insert_count,
        leaf_update_count,
        leaf_delete_count,
        leaf_page_merge_count,
        page_latch_wait_count,
        page_latch_wait_in_ms,
        page_io_latch_wait_count,
        page_io_latch_wait_in_ms
    FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL)
)
SELECT TOP 50
    SCHEMA_NAME(t.schema_id) AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    i.type_desc,
    reads = ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0),
    writes = ISNULL(us.user_updates, 0),
    write_to_read_ratio = CAST(
        1.0 * ISNULL(us.user_updates, 0)
        / NULLIF(ISNULL(us.user_seeks, 0) + ISNULL(us.user_scans, 0) + ISNULL(us.user_lookups, 0), 0)
        AS DECIMAL(18,2)
    ),
    ops_leaf_inserts = ISNULL(os.leaf_insert_count, 0),
    ops_leaf_updates = ISNULL(os.leaf_update_count, 0),
    ops_leaf_deletes = ISNULL(os.leaf_delete_count, 0),
    ops_page_merges = ISNULL(os.leaf_page_merge_count, 0),
    latch_waits = ISNULL(os.page_latch_wait_count, 0),
    latch_wait_ms = ISNULL(os.page_latch_wait_in_ms, 0),
    io_latch_waits = ISNULL(os.page_io_latch_wait_count, 0),
    io_latch_wait_ms = ISNULL(os.page_io_latch_wait_in_ms, 0)
FROM sys.indexes i
JOIN sys.tables t
  ON i.object_id = t.object_id
LEFT JOIN usage_stats us
  ON i.object_id = us.object_id
 AND i.index_id = us.index_id
LEFT JOIN operational_stats os
  ON i.object_id = os.object_id
 AND i.index_id = os.index_id
WHERE i.index_id > 0
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
ORDER BY
    writes DESC,
    reads ASC,
    latch_wait_ms DESC;
