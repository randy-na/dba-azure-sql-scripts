-- ============================================================
-- Daily | 05 - Error Log Check (last 24 hours)
-- !! IMPORTANT: Connect to the MASTER database before running !!
-- sys.event_log is only accessible from master context on Azure SQL.
-- ============================================================
SELECT
    session_id,
    event_time,
    event_type,
    event_description
FROM sys.event_log
WHERE event_time >= DATEADD(HOUR, -24, GETUTCDATE())
  AND event_type NOT IN ('connection_successful')
ORDER BY event_time DESC;
