-- ============================================================
-- Weekly | 07 - Geo-Replication Health
-- Run on: Primary
-- Informational only. Use to review lag and replication state.
-- ============================================================
SELECT
    partner_server,
    partner_database,
    role_desc,
    replication_state_desc,
    replication_lag_sec,
    secondary_allow_connections_desc
FROM sys.dm_geo_replication_link_status
ORDER BY replication_lag_sec DESC;
