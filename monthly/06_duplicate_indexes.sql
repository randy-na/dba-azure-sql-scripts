-- ============================================================
-- Monthly | 06 - Duplicate / Overlapping Indexes
-- Run on: Primary (UK South)
-- REVIEW before dropping — confirm with query workload first.
-- ============================================================
SELECT
    SCHEMA_NAME(t.schema_id)  AS schema_name,
    t.name                    AS table_name,
    i1.name                   AS index1,
    i2.name                   AS index2,
    i1.type_desc
FROM sys.indexes i1
JOIN sys.indexes i2
     ON  i1.object_id = i2.object_id
     AND i1.index_id  < i2.index_id
     AND i1.type      = i2.type
JOIN sys.tables t ON i1.object_id = t.object_id
WHERE EXISTS (
    SELECT ic1.column_id
    FROM sys.index_columns ic1
    WHERE ic1.object_id = i1.object_id AND ic1.index_id = i1.index_id AND ic1.is_included_column = 0
    INTERSECT
    SELECT ic2.column_id
    FROM sys.index_columns ic2
    WHERE ic2.object_id = i2.object_id AND ic2.index_id = i2.index_id AND ic2.is_included_column = 0
)
ORDER BY schema_name, table_name;
