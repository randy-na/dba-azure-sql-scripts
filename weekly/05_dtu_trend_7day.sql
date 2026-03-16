-- ============================================================
-- Weekly | 05 - DTU Usage Trend (past 7 days, hourly max)
-- Run on: Primary
-- NOTE: sys.dm_db_resource_stats only retains ~1 hour of data.
-- This query will return limited rows without a dbo.dtu_history
-- snapshot table in place. See README for recommendation.
-- ============================================================
SELECT
    DATEADD(HOUR, DATEDIFF(HOUR, 0, end_time), 0)                             AS hour_bucket,
    MAX(avg_cpu_percent)                                                       AS max_cpu_pct,
    MAX(avg_data_io_percent)                                                   AS max_io_pct,
    MAX(avg_log_write_percent)                                                 AS max_log_pct,
    MAX(GREATEST(avg_cpu_percent, avg_data_io_percent, avg_log_write_percent)) AS max_dtu_pct
FROM sys.dm_db_resource_stats
WHERE end_time >= DATEADD(DAY, -7, GETUTCDATE())
GROUP BY DATEADD(HOUR, DATEDIFF(HOUR, 0, end_time), 0)
ORDER BY hour_bucket DESC;
