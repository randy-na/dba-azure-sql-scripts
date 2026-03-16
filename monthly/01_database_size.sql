-- ============================================================
-- Monthly | 01 - Database Size and Space Usage
-- Run on: Primary
-- ============================================================
SELECT
    SUM(CASE WHEN type_desc = 'ROWS' THEN CAST(size AS BIGINT) END) * 8 / 1024 / 1024  AS data_size_Gb,
    SUM(CASE WHEN type_desc = 'LOG'  THEN CAST(size AS BIGINT) END) * 8 / 1024 / 1024 AS log_size_Gb,
    SUM(CAST(size AS BIGINT)) * 8 / 1024 / 1024                                        AS total_size_Gb
FROM sys.database_files;

SELECT
    SUM(CASE WHEN type_desc = 'ROWS' THEN CAST(max_size AS BIGINT) END) * 8 / 1024 / 1024  AS max_data_size_Gb,
    SUM(CASE WHEN type_desc = 'LOG'  THEN CAST(max_size AS BIGINT) END) * 8 / 1024 / 1024 AS max_log_size_Gb,
    SUM(CAST(max_size AS BIGINT)) * 8 / 1024 / 1024                                        AS max_total_size_Gb
FROM sys.database_files;