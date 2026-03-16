-- ============================================================
-- Monthly | 03 - DTU Consumption Trend (daily max, last 30 days)
-- Run on: Primary (UK South)
-- NOTE: sys.dm_db_resource_stats only retains ~1 hour of data.
-- This query will return limited rows without a dbo.dtu_history
-- snapshot table in place. See README for recommendation.
-- sys.dm_db_resource_stats is NOT replicated to the secondary.
-- ============================================================
SELECT
    CAST(end_time AS DATE)                                                      AS day,
    MAX(avg_cpu_percent)                                                        AS max_cpu_pct,
    MAX(avg_data_io_percent)                                                    AS max_io_pct,
    MAX(avg_log_write_percent)                                                  AS max_log_pct,
    MAX(GREATEST(avg_cpu_percent, avg_data_io_percent, avg_log_write_percent))  AS max_dtu_pct,
    AVG(GREATEST(avg_cpu_percent, avg_data_io_percent, avg_log_write_percent))  AS avg_dtu_pct
FROM sys.dm_db_resource_stats
WHERE end_time >= DATEADD(DAY, -30, GETUTCDATE())
GROUP BY CAST(end_time AS DATE)
ORDER BY day DESC;
