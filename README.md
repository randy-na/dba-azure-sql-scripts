# Azure SQL Maintenance Scripts 

---

## Script Structure

Each maintenance cadence has its own folder. Every query is a separate file, numbered for run order.

```
dba-azure-sql-scripts/
├── daily/
│   ├── 01_dtu_snapshot.sql
│   ├── 02_active_sessions_blocking.sql
│   ├── 03_index_fragmentation_check.sql
│   ├── 04_update_statistics.sql
│   ├── 05_error_log_check.sql
│   └── 06_long_running_transactions.sql
├── scripts/
│   └── Invoke-IndexMaintenance.ps1
├── weekly/
│   ├── 01_index_maintenance.sql
│   ├── 02_update_stats.sql
│   ├── 03_unused_indexes.sql
│   ├── 04_top_cpu_queries.sql
│   ├── 05_dtu_trend_7day.sql
│   ├── 06_wait_stats_snapshot.sql
│   └── 07_replication_health.sql
└── monthly/
    ├── 01_database_size.sql
    ├── 02_table_space_usage.sql
    ├── 03_dtu_trend_30day.sql
    ├── 04_unused_tables.sql
    ├── 05_missing_index_recommendations.sql
    ├── 06_duplicate_indexes.sql
    └── 07_index_read_write_pressure.sql
```

### Daily Scripts

| File | Description | Run On |
|---|---|---|
| `01_dtu_snapshot.sql` | Current DTU consumption (CPU / IO / Log %) | Primary |
| `02_active_sessions_blocking.sql` | Active sessions and blocking chains | Primary |
| `03_index_fragmentation_check.sql` | Quick fragmentation scan (LIMITED mode) | Primary |
| `04_update_statistics.sql` | Update stats on stale tables only | Primary ONLY |
| `05_error_log_check.sql` | Error log check - last 24 hours | **master** DB |
| `06_long_running_transactions.sql` | Long-running requests and open transaction review | Primary |

### Weekly Scripts

| File | Description | Run On |
|---|---|---|
| `01_index_maintenance.sql` | REORGANIZE > 10%, REBUILD > 30% | Primary ONLY |
| `02_update_stats.sql` | Full `sp_updatestats` | Primary ONLY |
| `03_unused_indexes.sql` | Indexes with no seeks/scans/lookups | Primary |
| `04_top_cpu_queries.sql` | Top 10 queries by total CPU | Primary |
| `05_dtu_trend_7day.sql` | Hourly DTU max - last 7 days | Primary |
| `06_wait_stats_snapshot.sql` | Top waits by cumulative wait time | Primary |
| `07_replication_health.sql` | Geo-replication lag and state | Primary |

### Monthly Scripts

| File | Description | Run On |
|---|---|---|
| `01_database_size.sql` | Data and log file size | Primary |
| `02_table_space_usage.sql` | Top 20 tables by total size | Primary |
| `03_dtu_trend_30day.sql` | Daily DTU max/avg - last 30 days | Primary |
| `04_unused_tables.sql` | Tables with no user reads in stats cache | Primary |
| `05_missing_index_recommendations.sql` | Missing index recommendations (score > 1000) | Primary |
| `06_duplicate_indexes.sql` | Duplicate / overlapping index review | Primary |
| `07_index_read_write_pressure.sql` | Indexes with high write cost and low read value | Primary |

---

## DTU-Specific Notes

### What is DTU %?

Azure SQL DTU tiers do not expose raw CPU/memory/IO independently - the effective DTU consumption is approximated as:

```sql
GREATEST(avg_cpu_percent, avg_data_io_percent, avg_log_write_percent)
```

If this consistently exceeds **80-85%**, consider scaling up your Premium tier (P1 -> P2 etc.) or reviewing the top CPU queries surfaced in `weekly/04_top_cpu_queries.sql`.

### `sys.dm_db_resource_stats` Retention

-   Retains **~1 hour** of data at 15-second intervals.
-   `weekly/05_dtu_trend_7day.sql` and `monthly/03_dtu_trend_30day.sql` will return limited rows unless you export snapshots externally.
-   This repo intentionally does **not** create tracking/history tables. Long-term retention is expected to be handled manually or by an external process.

### `sys.event_log`

-   Only accessible from the **`master` database** context on Azure SQL.
-   Connect to `master` before running `daily/05_error_log_check.sql`.

### `ONLINE = ON` for Index Rebuilds

-   Fully supported on **Premium tier** - no change needed.
-   If you ever downgrade to Standard or Basic, remove `WITH (ONLINE = ON)` from `weekly/01_index_maintenance.sql` as it is not supported on those tiers.

### Index Maintenance Policy

-   `weekly/01_index_maintenance.sql` follows the standard pattern: `REORGANIZE` above **10%** fragmentation and `REBUILD` above **30%**.
-   `scripts/Invoke-IndexMaintenance.ps1` `REORGANIZE`s all indexes above **10%**, updates statistics for each reorganized index, and still flags indexes above **30%** for manual online rebuild.
-   The PowerShell script supports `-WhatIf`.

### Statistics Updates

-   `sp_updatestats` (weekly) only updates stats with changes since the last update.
-   `daily/04_update_statistics.sql` targets tables where fewer than 80% of rows were sampled, catching stale stats between weekly runs.

---

### Monitoring Replication Lag

Run on the **primary** to check replication health:

```sql
SELECT
    r.partner_server,
    r.partner_database,
    r.role_desc,
    r.replication_state_desc,
    r.replication_lag_sec
FROM sys.dm_geo_replication_link_status r;
```

A lag above **30 seconds** on a reporting workload warrants investigation.

### Failover Considerations

-   After a **planned failover** (e.g. DR test), re-run `weekly/01_index_maintenance.sql` on the new primary - `sys.dm_db_index_usage_stats` resets on failover.
-   `monthly/05_missing_index_recommendations.sql` - `sys.dm_db_missing_index_details` also resets on failover. Allow at least a week of workload before acting on results post-failover.
-   `sys.dm_db_resource_stats` history is **not replicated** to the secondary.

### Do Not Run on Secondary

The following will fail or produce misleading results on the read-only secondary:

| Script | Reason |
|---|---|
| `weekly/01_index_maintenance.sql` | Write operation - blocked by read-only guard |
| `weekly/02_update_stats.sql` | Write operation - will error |
| `daily/04_update_statistics.sql` | Write operation - will error |
| `monthly/03_dtu_trend_30day.sql` | `sys.dm_db_resource_stats` not replicated |

---

## Automation Notes

-   `scripts/Invoke-IndexMaintenance.ps1` uses Managed Identity and an Azure SQL access token.
-   The PowerShell script is intended as an operator-run helper, not a self-scheduling job definition.
-   Review server and database defaults before first use.

