-- ============================================================
-- Daily | 01 - Current DTU Consumption Snapshot
-- Run on: Primary (UK South)
-- ============================================================
SELECT
    end_time,
    avg_cpu_percent,
    avg_data_io_percent,
    avg_log_write_percent,
    avg_memory_usage_percent,
    GREATEST(avg_cpu_percent, avg_data_io_percent, avg_log_write_percent) AS dtu_percent_approx
FROM sys.dm_db_resource_stats
ORDER BY end_time DESC;
