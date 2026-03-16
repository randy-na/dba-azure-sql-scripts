-- ============================================================
-- Monthly | 05 - Missing Index Recommendations (score > 1000)
-- Run on: Primary
-- REVIEW before creating indexes - DMVs reset on failover.
-- Allow at least 1 week of workload post-failover before acting.
-- ============================================================
SELECT TOP 20
    ROUND(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans), 0) AS improvement_score,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    OBJECT_NAME(mid.object_id) AS table_name
FROM sys.dm_db_missing_index_details        mid
JOIN sys.dm_db_missing_index_groups         mig  ON mid.index_handle       = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats    migs ON mig.index_group_handle  = migs.group_handle
WHERE mid.database_id = DB_ID()
  AND ROUND(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans), 0) > 1000
ORDER BY improvement_score DESC;
