# Azure SQL Maintenance Scripts — Prod Reporting DB

## Environment
| Property | Value |
|---|---|
| Service Tier | Premium (DTU model) |
| Primary Region | UK South (uks) |
| Secondary Region | UK West (ukw) |
| HA / DR | Active Geo-Replication (readable secondary) |
| Workload | Production Reporting |

---

## Scripts

| Script | Frequency | Run On |
|---|---|---|
| `daily_maintenance.sql` | Every day, low-traffic window | Primary |
| `weekly_maintenance.sql` | Once a week, maintenance window | Primary |
| `monthly_maintenance.sql` | Once a month | Primary |

---

## DTU-Specific Notes

### What is DTU %?
Azure SQL DTU tiers do not expose raw CPU/memory/IO independently — the effective DTU consumption is approximated as:
```sql
GREATEST(avg_cpu_percent, avg_data_io_percent, avg_log_write_percent)
```
If this consistently exceeds **80–85%**, consider scaling up your Premium tier (P1 → P2 etc.) or reviewing the top CPU queries surfaced in the weekly script.

### `sys.dm_db_resource_stats` Retention
- Retains **~1 hour** of data at 15-second intervals.
- The 7-day (weekly) and 30-day (monthly) DTU trend queries will return limited rows unless you export snapshots to a history table.
- Recommended: schedule a daily job to INSERT into a custom `dbo.dtu_history` table from `sys.dm_db_resource_stats`.

### `sys.event_log`
- Only accessible from the **`master` database** context on Azure SQL.
- Connect to `master` before running section 5 of `daily_maintenance.sql`.

### `ONLINE = ON` for Index Rebuilds
- Fully supported on **Premium tier** — no change needed.
- If you ever downgrade to Standard or Basic, remove `WITH (ONLINE = ON)` from `weekly_maintenance.sql` as it is not supported on those tiers.

### Statistics Updates
- `sp_updatestats` (weekly) only updates stats with changes since the last update.
- The daily script targets tables where fewer than 80% of rows were sampled, catching stale stats between weekly runs.

---

## Active Geo-Replication Notes

### General
- All **write** operations (index rebuilds, stats updates) must run on the **primary (UK South)**.
- The secondary (UK West) is **read-only** — use it for reporting queries to offload DTU from primary.

### Connecting to the Secondary for Reporting
```
Server:   <your-server>.secondary.database.windows.net
-- or use the geo-replication endpoint directly in your connection string:
ApplicationIntent=ReadOnly
```

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
- After a **planned failover** (e.g. DR test), re-run `weekly_maintenance.sql` on the new primary — index usage stats (`sys.dm_db_index_usage_stats`) reset on failover.
- Missing index DMVs (`sys.dm_db_missing_index_details`) also reset — allow at least a week of workload before acting on monthly recommendations post-failover.
- `sys.dm_db_resource_stats` history is **not replicated** to the secondary.

### Do Not Run on Secondary
The following will fail or produce misleading results on the read-only secondary:
- `weekly_maintenance.sql` (index rebuild/reorganize, sp_updatestats)
- Section 4 of `daily_maintenance.sql` (UPDATE STATISTICS)

---

## Recommended Maintenance Window
Given the UK South primary, a suitable low-traffic window is typically **01:00–04:00 UTC** (02:00–05:00 BST in summer). Confirm against your actual reporting load patterns using the DTU trend queries.
