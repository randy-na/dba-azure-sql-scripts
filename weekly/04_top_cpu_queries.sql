-- ============================================================
-- Weekly | 04 - Top 10 Queries by Total CPU
-- Run on: Primary
-- Use results to identify candidates for query tuning.
-- If avg_cpu_us is high and DTU % consistently > 80, consider
-- query optimisation before scaling up the Premium tier.
-- ============================================================
SELECT TOP 10
    qs.total_worker_time / qs.execution_count   AS avg_cpu_us,
    qs.total_elapsed_time / qs.execution_count  AS avg_elapsed_us,
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    SUBSTRING(qt.text, (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
          ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2) + 1
    ) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY qs.total_worker_time DESC;
