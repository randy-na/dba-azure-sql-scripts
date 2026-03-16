-- ============================================================
-- Monthly | 06 - Duplicate / Overlapping Index Review
-- Run on: Primary
-- REVIEW before dropping anything.
--
-- This report is intentionally conservative:
-- 1) Exact duplicate      = same key columns, include columns,
--                           uniqueness, and filter definition.
-- 2) Left-prefix candidate = same leading key columns, same filter
--                           and uniqueness, where the wider index
--                           may cover the narrower one.
--
-- Excludes PKs, unique constraints, disabled indexes, and
-- hypothetical indexes. Always validate against workload first.
-- ============================================================

WITH index_usage AS (
    SELECT
        u.object_id,
        u.index_id,
        user_reads = ISNULL(u.user_seeks, 0) + ISNULL(u.user_scans, 0) + ISNULL(u.user_lookups, 0),
        user_writes = ISNULL(u.user_updates, 0)
    FROM sys.dm_db_index_usage_stats u
    WHERE u.database_id = DB_ID()
),
index_meta AS (
    SELECT
        t.object_id,
        t.schema_id,
        schema_name = SCHEMA_NAME(t.schema_id),
        table_name = t.name,
        i.index_id,
        index_name = i.name,
        i.type_desc,
        i.is_unique,
        i.has_filter,
        filter_definition = ISNULL(i.filter_definition, N''),
        key_columns = STUFF((
            SELECT
                N', ' + QUOTENAME(c.name)
                + CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE N' ASC' END
            FROM sys.index_columns ic
            JOIN sys.columns c
              ON c.object_id = ic.object_id
             AND c.column_id = ic.column_id
            WHERE ic.object_id = i.object_id
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 0
            ORDER BY ic.key_ordinal
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 2, N''),
        include_columns = STUFF((
            SELECT
                N', ' + QUOTENAME(c.name)
            FROM sys.index_columns ic
            JOIN sys.columns c
              ON c.object_id = ic.object_id
             AND c.column_id = ic.column_id
            WHERE ic.object_id = i.object_id
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 1
            ORDER BY c.column_id
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 2, N''),
        user_reads = ISNULL(u.user_reads, 0),
        user_writes = ISNULL(u.user_writes, 0)
    FROM sys.tables t
    JOIN sys.indexes i
      ON i.object_id = t.object_id
    LEFT JOIN index_usage u
      ON u.object_id = i.object_id
     AND u.index_id = i.index_id
    WHERE i.index_id > 0
      AND i.is_primary_key = 0
      AND i.is_unique_constraint = 0
      AND i.is_disabled = 0
      AND i.is_hypothetical = 0
),
paired AS (
    SELECT
        m1.schema_name,
        m1.table_name,
        duplicate_type = CASE
            WHEN m1.key_columns = m2.key_columns
             AND ISNULL(m1.include_columns, N'') = ISNULL(m2.include_columns, N'')
             AND m1.is_unique = m2.is_unique
             AND m1.has_filter = m2.has_filter
             AND m1.filter_definition = m2.filter_definition
                THEN N'EXACT_DUPLICATE'
            WHEN m1.is_unique = 0
             AND m2.is_unique = 0
             AND m1.has_filter = 0
             AND m2.has_filter = 0
             AND m2.key_columns LIKE m1.key_columns + N', %'
             AND (
                    ISNULL(m1.include_columns, N'') = N''
                 OR ISNULL(m2.include_columns, N'') = ISNULL(m1.include_columns, N'')
                 OR N', ' + ISNULL(m2.include_columns, N'') + N', ' LIKE N'%, ' + ISNULL(m1.include_columns, N'') + N', %'
             )
                THEN N'LEFT_PREFIX_CANDIDATE'
            ELSE NULL
        END,
        narrower_index = m1.index_name,
        wider_or_peer_index = m2.index_name,
        m1.type_desc,
        m1.key_columns,
        m1.include_columns AS narrower_include_columns,
        m2.include_columns AS wider_include_columns,
        filter_definition = NULLIF(m1.filter_definition, N''),
        narrower_reads = m1.user_reads,
        narrower_writes = m1.user_writes,
        wider_reads = m2.user_reads,
        wider_writes = m2.user_writes
    FROM index_meta m1
    JOIN index_meta m2
      ON m1.object_id = m2.object_id
     AND m1.index_id < m2.index_id
     AND m1.type_desc = m2.type_desc
     AND m1.is_unique = m2.is_unique
     AND m1.has_filter = m2.has_filter
     AND m1.filter_definition = m2.filter_definition
)
SELECT
    schema_name,
    table_name,
    duplicate_type,
    narrower_index,
    wider_or_peer_index,
    type_desc,
    key_columns,
    narrower_include_columns,
    wider_include_columns,
    filter_definition,
    narrower_reads,
    narrower_writes,
    wider_reads,
    wider_writes,
    review_hint = CASE
        WHEN duplicate_type = N'EXACT_DUPLICATE'
            THEN N'Exact structural match. Prefer keeping the index with the higher reads or clearer naming.'
        WHEN duplicate_type = N'LEFT_PREFIX_CANDIDATE'
            THEN N'Potential overlap only. Confirm plans and predicate patterns before considering consolidation.'
    END
FROM paired
WHERE duplicate_type IS NOT NULL
ORDER BY
    schema_name,
    table_name,
    CASE duplicate_type WHEN N'EXACT_DUPLICATE' THEN 0 ELSE 1 END,
    narrower_writes DESC,
    narrower_index,
    wider_or_peer_index;
