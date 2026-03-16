-- ============================================================
-- Daily | 06 - Long-Running Requests and Transactions
-- Run on: Primary
-- Use to spot open transactions, blockers, and long-running work.
-- ============================================================
SELECT
    r.session_id,
    s.login_name,
    s.host_name,
    s.program_name,
    r.status,
    r.command,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time / 1000.0 AS wait_sec,
    r.total_elapsed_time / 1000.0 AS elapsed_sec,
    at.transaction_begin_time,
    DATEDIFF(MINUTE, at.transaction_begin_time, SYSUTCDATETIME()) AS transaction_age_min,
    DB_NAME(r.database_id) AS database_name,
    SUBSTRING(
        txt.text,
        (r.statement_start_offset / 2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(txt.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset) / 2) + 1
    ) AS statement_text
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s
  ON r.session_id = s.session_id
LEFT JOIN sys.dm_tran_session_transactions st
  ON r.session_id = st.session_id
LEFT JOIN sys.dm_tran_active_transactions at
  ON st.transaction_id = at.transaction_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) txt
WHERE r.session_id <> @@SPID
ORDER BY
    transaction_age_min DESC,
    elapsed_sec DESC;
