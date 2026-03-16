-- ============================================================
-- Monthly | 02 - Table Space Usage (top 20 by total size)
-- Run on: Primary
-- ============================================================
SELECT TOP 20
    SCHEMA_NAME(t.schema_id)          AS schema_name,
    t.name                            AS table_name,
    p.rows                            AS row_count,
    SUM(a.total_pages) * 8 / 1024.0  AS total_mb,
    SUM(a.used_pages)  * 8 / 1024.0  AS used_mb,
    SUM(a.data_pages)  * 8 / 1024.0  AS data_mb
FROM sys.tables t
JOIN sys.indexes         i ON t.object_id = i.object_id
JOIN sys.partitions      p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE i.index_id <= 1  -- clustered or heap only
GROUP BY t.schema_id, t.name, p.rows
ORDER BY total_mb DESC;
