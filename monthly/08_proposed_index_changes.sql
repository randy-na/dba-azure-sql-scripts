-- ============================================================
-- Monthly | 08 - Proposed Index Changes for Large Tables
-- Run on: Primary
-- REVIEW before applying in production.
--
-- These proposals are based on daily maintenance monitoring
-- analysis of fragmentation, expensive query patterns, and
-- current index usage on the largest tables.
--
-- Focus tables:
--   1) dbo.Registration
--   2) dbo.Rmp
--
-- Main goal:
--   Improve "latest row as of date" query patterns that repeatedly
--   search by business key plus LastUpdated.
-- ============================================================

-- ============================================================
-- 1) CREATE CANDIDATE: Registration latest-row lookup
--
-- Supports patterns such as:
--   WHERE RegistrationId = ?
--     AND LastUpdated <= @toDateOffset
--   ORDER BY LastUpdated DESC / MAX(LastUpdated)
--
-- Expected benefit:
--   Reduce CPU and logical reads for report queries that fetch the
--   latest version of a registration record.
-- ============================================================
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Registration')
      AND name = N'IX_Registration_RegistrationId_LastUpdated'
)
BEGIN
    PRINT N'Creating IX_Registration_RegistrationId_LastUpdated';

    CREATE NONCLUSTERED INDEX IX_Registration_RegistrationId_LastUpdated
    ON dbo.Registration (
        RegistrationId ASC,
        LastUpdated DESC
    )
    INCLUDE (
        RegistrationStatus,
        SupplierMpid,
        FuelType,
        Mpxn
    )
    WITH (
        ONLINE = ON,
        SORT_IN_TEMPDB = ON,
        DATA_COMPRESSION = PAGE
    )
    ON [psPartition_LastUpdated]([LastUpdated]);
END;
ELSE
BEGIN
    PRINT N'Index IX_Registration_RegistrationId_LastUpdated already exists.';
END;
GO

-- ============================================================
-- 2) CREATE CANDIDATE: Rmp latest-row lookup
--
-- Supports patterns such as:
--   WHERE Mpxn = ?
--     AND LastUpdated <= @toDateOffset
--   ORDER BY LastUpdated DESC / MAX(LastUpdated)
--
-- Expected benefit:
--   Reduce CPU and logical reads for report queries that fetch the
--   latest version of an RMP record.
-- ============================================================
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Rmp')
      AND name = N'IX_Rmp_Mpxn_LastUpdated'
)
BEGIN
    PRINT N'Creating IX_Rmp_Mpxn_LastUpdated';

    CREATE NONCLUSTERED INDEX IX_Rmp_Mpxn_LastUpdated
    ON dbo.Rmp (
        Mpxn ASC,
        LastUpdated DESC
    )
    INCLUDE (
        RmpStatus,
        NetworkProvisionMpid,
        NetworkProvisionRole,
        ActiveRegistrationId,
        CommsHubLinkDeviceId
    )
    WITH (
        ONLINE = ON,
        SORT_IN_TEMPDB = ON,
        DATA_COMPRESSION = PAGE
    )
    ON [psPartition_LastUpdated]([LastUpdated]);
END;
ELSE
BEGIN
    PRINT N'Index IX_Rmp_Mpxn_LastUpdated already exists.';
END;
GO

-- ============================================================
-- 3) OPTIONAL CREATE CANDIDATE: Rmp terminated-report support
--
-- Use this only if terminated-RMP reporting remains expensive after
-- the latest-row indexes above are in place.
-- ============================================================
/*
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Rmp')
      AND name = N'IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated'
)
BEGIN
    PRINT N'Creating IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated';

    CREATE NONCLUSTERED INDEX IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated
    ON dbo.Rmp (
        RmpStatus ASC,
        ActiveRegistrationId ASC,
        LastUpdated DESC
    )
    INCLUDE (
        Mpxn
    )
    WITH (
        ONLINE = ON,
        SORT_IN_TEMPDB = ON,
        DATA_COMPRESSION = PAGE
    )
    ON [psPartition_LastUpdated]([LastUpdated]);
END;
ELSE
BEGIN
    PRINT N'Index IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated already exists.';
END;
GO
*/

-- ============================================================
-- 4) REVIEW-ONLY: Low-value Rmp indexes to validate for disable/drop
--
-- Do not drop immediately.
-- Review after the new latest-row indexes have been in use long
-- enough to observe workload impact.
-- ============================================================
SELECT
    review_action = N'REVIEW_FOR_DISABLE_OR_DROP',
    schema_name = SCHEMA_NAME(t.schema_id),
    table_name = t.name,
    i.name AS index_name,
    i.type_desc
FROM sys.indexes i
JOIN sys.tables t
  ON i.object_id = t.object_id
WHERE t.name = N'Rmp'
  AND i.name IN (
        N'IX_Rmp_AddressSource_UPRN',
        N'IX_Rmp_CommsHubLinkDeviceId_UPRN'
  );
GO

-- ============================================================
-- 5) REVIEW-ONLY: Disable commands for staged testing
--
-- Uncomment only after confirming the indexes are not required by
-- critical workload paths.
-- ============================================================
/*
ALTER INDEX IX_Rmp_AddressSource_UPRN ON dbo.Rmp DISABLE;
ALTER INDEX IX_Rmp_CommsHubLinkDeviceId_UPRN ON dbo.Rmp DISABLE;
GO
*/

-- ============================================================
-- 6) REVIEW-ONLY: Drop commands after a successful disable trial
--
-- Uncomment only after the disable phase is validated.
-- ============================================================
/*
DROP INDEX IX_Rmp_AddressSource_UPRN ON dbo.Rmp;
DROP INDEX IX_Rmp_CommsHubLinkDeviceId_UPRN ON dbo.Rmp;
GO
*/
