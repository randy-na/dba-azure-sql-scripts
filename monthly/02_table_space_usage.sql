-- ============================================================
-- Monthly | 02 - Table Space Usage (top 20 by total size)
-- Run on: Primary
-- ============================================================
SELECT TOP 20
    SCHEMA_NAME(t.schema_id) AS schema_name,
    t.name AS table_name,
    SUM(ps.row_count) AS row_count,
    SUM(ps.reserved_page_count) * 8 / 1024.0 AS total_mb,
    SUM(ps.used_page_count) * 8 / 1024.0 AS used_mb,
    SUM(ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count) * 8 / 1024.0 AS data_mb
FROM sys.tables t
JOIN sys.dm_db_partition_stats ps
  ON t.object_id = ps.object_id
WHERE ps.index_id <= 1  -- clustered or heap only
GROUP BY t.schema_id, t.name
ORDER BY total_mb DESC;
