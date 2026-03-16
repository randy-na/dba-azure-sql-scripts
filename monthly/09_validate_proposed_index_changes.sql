-- ============================================================
-- Monthly | 09 - Validate Proposed Index Changes
-- Run on: Primary
-- REVIEW output before making any drop decisions.
--
-- Use this after deploying candidate indexes from:
--   monthly/08_proposed_index_changes.sql
--
-- This script does not require any history tables. It gives a
-- point-in-time validation view using current metadata, usage, and
-- operational stats.
-- ============================================================

-- ============================================================
-- 1) Confirm proposed indexes exist and show current properties
-- ============================================================
SELECT
    schema_name = SCHEMA_NAME(t.schema_id),
    table_name = t.name,
    index_name = i.name,
    i.type_desc,
    i.is_disabled,
    i.fill_factor,
    i.has_filter,
    i.filter_definition
FROM sys.indexes i
JOIN sys.tables t
  ON i.object_id = t.object_id
WHERE i.name IN (
        N'IX_Registration_RegistrationId_LastUpdated',
        N'IX_Rmp_Mpxn_LastUpdated',
        N'IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated'
)
ORDER BY table_name, index_name;
GO

-- ============================================================
-- 2) Check usage of new indexes versus review candidates
--
-- Interpretation:
--   - Reads rising on new indexes is a good sign.
--   - Reads staying near zero on review candidates strengthens the
--     case for disable/drop review.
-- ============================================================
SELECT
    schema_name = SCHEMA_NAME(t.schema_id),
    table_name = t.name,
    i.name AS index_name,
    reads = ISNULL(u.user_seeks, 0) + ISNULL(u.user_scans, 0) + ISNULL(u.user_lookups, 0),
    user_seeks = ISNULL(u.user_seeks, 0),
    user_scans = ISNULL(u.user_scans, 0),
    user_lookups = ISNULL(u.user_lookups, 0),
    user_updates = ISNULL(u.user_updates, 0),
    u.last_user_seek,
    u.last_user_scan,
    u.last_user_lookup,
    u.last_user_update
FROM sys.indexes i
JOIN sys.tables t
  ON i.object_id = t.object_id
LEFT JOIN sys.dm_db_index_usage_stats u
  ON i.object_id = u.object_id
 AND i.index_id = u.index_id
 AND u.database_id = DB_ID()
WHERE i.name IN (
        N'IX_Registration_RegistrationId_LastUpdated',
        N'IX_Rmp_Mpxn_LastUpdated',
        N'IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated',
        N'IX_Rmp_AddressSource_UPRN',
        N'IX_Rmp_CommsHubLinkDeviceId_UPRN'
)
ORDER BY table_name, reads DESC, index_name;
GO

-- ============================================================
-- 3) Check fragmentation on new indexes
--
-- Interpretation:
--   - High fragmentation immediately after creation suggests heavy
--     churn and may influence fill-factor tuning later.
-- ============================================================
SELECT
    schema_name = SCHEMA_NAME(t.schema_id),
    table_name = t.name,
    i.name AS index_name,
    s.avg_fragmentation_in_percent,
    s.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') s
JOIN sys.indexes i
  ON s.object_id = i.object_id
 AND s.index_id = i.index_id
JOIN sys.tables t
  ON s.object_id = t.object_id
WHERE i.name IN (
        N'IX_Registration_RegistrationId_LastUpdated',
        N'IX_Rmp_Mpxn_LastUpdated',
        N'IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated'
)
ORDER BY s.avg_fragmentation_in_percent DESC, s.page_count DESC;
GO

-- ============================================================
-- 4) Check write pressure of new and review indexes
--
-- Interpretation:
--   - High writes with meaningful reads can still be acceptable.
--   - High writes with no reads is a warning sign.
-- ============================================================
WITH usage_stats AS (
    SELECT
        u.object_id,
        u.index_id,
        reads = ISNULL(u.user_seeks, 0) + ISNULL(u.user_scans, 0) + ISNULL(u.user_lookups, 0),
        writes = ISNULL(u.user_updates, 0)
    FROM sys.dm_db_index_usage_stats u
    WHERE u.database_id = DB_ID()
)
SELECT
    schema_name = SCHEMA_NAME(t.schema_id),
    table_name = t.name,
    i.name AS index_name,
    reads = ISNULL(us.reads, 0),
    writes = ISNULL(us.writes, 0),
    write_to_read_ratio = CAST(
        1.0 * ISNULL(us.writes, 0) / NULLIF(ISNULL(us.reads, 0), 0)
        AS DECIMAL(18,2)
    )
FROM sys.indexes i
JOIN sys.tables t
  ON i.object_id = t.object_id
LEFT JOIN usage_stats us
  ON i.object_id = us.object_id
 AND i.index_id = us.index_id
WHERE i.name IN (
        N'IX_Registration_RegistrationId_LastUpdated',
        N'IX_Rmp_Mpxn_LastUpdated',
        N'IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated',
        N'IX_Rmp_AddressSource_UPRN',
        N'IX_Rmp_CommsHubLinkDeviceId_UPRN'
)
ORDER BY table_name, writes DESC, reads ASC, index_name;
GO

-- ============================================================
-- 5) Suggested review summary
--
-- Interpretation guide:
--   KEEP:
--     New index shows seeks/scans/lookups and supports an expensive
--     business-critical query path.
--
--   REVIEW FILLFACTOR:
--     New index helps reads but fragments quickly under heavy writes.
--
--   REVIEW DISABLE:
--     Existing review-candidate index still has near-zero reads after
--     a reasonable observation period.
-- ============================================================
SELECT
    review_action = CASE
        WHEN i.name IN (N'IX_Rmp_AddressSource_UPRN', N'IX_Rmp_CommsHubLinkDeviceId_UPRN')
             AND ISNULL(u.user_seeks, 0) + ISNULL(u.user_scans, 0) + ISNULL(u.user_lookups, 0) = 0
            THEN N'REVIEW_DISABLE'
        WHEN i.name IN (
                N'IX_Registration_RegistrationId_LastUpdated',
                N'IX_Rmp_Mpxn_LastUpdated',
                N'IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated'
             )
             AND ISNULL(u.user_seeks, 0) + ISNULL(u.user_scans, 0) + ISNULL(u.user_lookups, 0) > 0
            THEN N'KEEP_AND_MONITOR'
        ELSE N'REVIEW'
    END,
    schema_name = SCHEMA_NAME(t.schema_id),
    table_name = t.name,
    i.name AS index_name,
    reads = ISNULL(u.user_seeks, 0) + ISNULL(u.user_scans, 0) + ISNULL(u.user_lookups, 0),
    writes = ISNULL(u.user_updates, 0),
    u.last_user_seek,
    u.last_user_scan,
    u.last_user_lookup,
    u.last_user_update
FROM sys.indexes i
JOIN sys.tables t
  ON i.object_id = t.object_id
LEFT JOIN sys.dm_db_index_usage_stats u
  ON i.object_id = u.object_id
 AND i.index_id = u.index_id
 AND u.database_id = DB_ID()
WHERE i.name IN (
        N'IX_Registration_RegistrationId_LastUpdated',
        N'IX_Rmp_Mpxn_LastUpdated',
        N'IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated',
        N'IX_Rmp_AddressSource_UPRN',
        N'IX_Rmp_CommsHubLinkDeviceId_UPRN'
)
ORDER BY table_name, review_action, index_name;
GO
