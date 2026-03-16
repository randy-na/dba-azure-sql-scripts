param(
    [string]$ServerName = "sqlsvr-css-reporting-pre-uks.database.windows.net",
    [string]$DatabaseName = "reporting",
    [int]$MinimumPageCount = 1000,
    [switch]$WhatIf
)

Connect-AzAccount -Identity | Out-Null
$token = (Get-AzAccessToken -ResourceUrl "https://database.windows.net/").Token
$connectionString = "Server=tcp:$ServerName,1433;Initial Catalog=$DatabaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

function Invoke-SqlQuery {
    param(
        [string]$Query,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query
    $cmd.CommandTimeout = 300

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataset) | Out-Null

    return $dataset.Tables[0]
}

function Invoke-SqlNonQuery {
    param(
        [string]$Query,
        [System.Data.SqlClient.SqlConnection]$Connection
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Query
    $cmd.CommandTimeout = 3600
    $cmd.ExecuteNonQuery() | Out-Null
}

$connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
$connection.AccessToken = $token
$connection.Open()

Write-Output "Connected to $DatabaseName on $ServerName"
Write-Output "=================================================="

$reorganizeQuery = @"
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    s.avg_fragmentation_in_percent,
    s.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') s
JOIN sys.indexes i
  ON i.object_id = s.object_id
 AND i.index_id = s.index_id
WHERE s.avg_fragmentation_in_percent > 10
  AND s.page_count >= $MinimumPageCount
  AND i.index_id > 0
ORDER BY s.avg_fragmentation_in_percent DESC;
"@

$rebuildFlagQuery = @"
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    s.avg_fragmentation_in_percent,
    s.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') s
JOIN sys.indexes i
  ON i.object_id = s.object_id
 AND i.index_id = s.index_id
WHERE s.avg_fragmentation_in_percent > 30
  AND s.page_count >= $MinimumPageCount
  AND i.index_id > 0
ORDER BY s.avg_fragmentation_in_percent DESC;
"@

Write-Output "Scanning for indexes to REORGANIZE (>10% fragmentation)..."
$indexes = Invoke-SqlQuery -Query $reorganizeQuery -Connection $connection

if ($indexes.Rows.Count -eq 0) {
    Write-Output "No indexes found requiring REORGANIZE."
} else {
    Write-Output "Found $($indexes.Rows.Count) index(es) requiring REORGANIZE."
    Write-Output "--------------------------------------------------"

    foreach ($row in $indexes.Rows) {
        $schema = $row.schema_name
        $table = $row.table_name
        $index = $row.index_name
        $fragBefore = [math]::Round($row.avg_fragmentation_in_percent, 2)
        $pages = $row.page_count

        Write-Output "Target: [$schema].[$table] -> [$index]"
        Write-Output "  Fragmentation: $fragBefore% | Pages: $pages"
        if ($fragBefore -gt 30) {
            Write-Output "  NOTE: Manual ONLINE REBUILD still recommended after this REORGANIZE."
        }

        if ($WhatIf) {
            Write-Output "  WHATIF: ALTER INDEX [$index] ON [$schema].[$table] REORGANIZE;"
            Write-Output "  WHATIF: UPDATE STATISTICS [$schema].[$table]([$index]);"
            Write-Output "--------------------------------------------------"
            continue
        }

        try {
            $reorganizeSql = "ALTER INDEX [$index] ON [$schema].[$table] REORGANIZE;"
            Invoke-SqlNonQuery -Query $reorganizeSql -Connection $connection
            Write-Output "  REORGANIZE completed."

            $updateStatsSql = "UPDATE STATISTICS [$schema].[$table]([$index]);"
            Invoke-SqlNonQuery -Query $updateStatsSql -Connection $connection
            Write-Output "  Statistics updated for [$index]."
        } catch {
            Write-Output "  ERROR during REORGANIZE or statistics update: $_"
        }

        Write-Output "--------------------------------------------------"
    }
}

Write-Output ""
Write-Output "Indexes that still require manual ONLINE REBUILD (>30% fragmentation):"
$rebuildFlags = Invoke-SqlQuery -Query $rebuildFlagQuery -Connection $connection

if ($rebuildFlags.Rows.Count -eq 0) {
    Write-Output "None."
} else {
    foreach ($row in $rebuildFlags.Rows) {
        $frag = [math]::Round($row.avg_fragmentation_in_percent, 2)
        Write-Output "[$($row.schema_name)].[$($row.table_name)] -> [$($row.index_name)] | $frag% | Pages: $($row.page_count) | ONLINE REBUILD REQUIRED"
    }
}

$connection.Close()
Write-Output ""
Write-Output "Index maintenance job completed."
