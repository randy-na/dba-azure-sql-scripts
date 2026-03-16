-- ============================================================
-- Daily | 02 - Active Sessions and Blocking
-- Run on: Primary (UK South)
-- ============================================================
SELECT
    r.session_id,
    r.status,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time / 1000.0          AS wait_sec,
    r.total_elapsed_time / 1000.0 AS elapsed_sec,
    r.cpu_time,
    r.logical_reads,
    SUBSTRING(t.text, (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(t.text)
          ELSE r.statement_end_offset END - r.statement_start_offset) / 2) + 1
    ) AS statement_text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id <> @@SPID;
