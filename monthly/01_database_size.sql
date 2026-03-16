-- ============================================================
-- Monthly | 01 - Database Size and Space Usage
-- Run on: Primary
-- ============================================================
SELECT
    SUM(CASE WHEN type_desc = 'ROWS' THEN size END) * 8 / 1024.0  AS data_size_mb,
    SUM(CASE WHEN type_desc = 'LOG'  THEN size END) * 8 / 1024.0  AS log_size_mb,
    SUM(size) * 8 / 1024.0                                         AS total_size_mb
FROM sys.database_files;
