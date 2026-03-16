# Index Review Summary

Date: 2026-03-16

## Scope

Reviewed index fragmentation, index usage, expensive query patterns, and large-table index design with focus on `dbo.Rmp` and `dbo.Registration`.

## Key Findings

- The largest performance pattern is not general DTU pressure, but repeated "latest row as of date" lookups on `Rmp` and `Registration`.
- Current indexes on `Rmp` and `Registration` are mostly status-oriented and do not optimally support `MAX(LastUpdated)` / latest-version query patterns.
- Two `Rmp` indexes currently show no observed read usage in maintenance monitoring and should be reviewed later for disable/drop:
  - `IX_Rmp_AddressSource_UPRN`
  - `IX_Rmp_CommsHubLinkDeviceId_UPRN`
- Fragmentation is very high across key `Rmp` and `Registration` indexes, so index design and maintenance approach both matter here.
- Database size/capacity is also a concern and should stay under review separately from index tuning.

## Agreed Direction

- Keep the SQL weekly maintenance script in its standard mode:
  - `REORGANIZE` for indexes above 10% fragmentation
  - `REBUILD` for indexes above 30% fragmentation
- Update the PowerShell helper to:
  - `REORGANIZE` all indexes above 10% fragmentation, including those above 30%
  - explicitly update statistics after each reorg
  - still flag indexes above 30% for manual online rebuild later
- Keep existing fill factors unchanged for now so they can be reviewed properly later.

## New Scripts Added

- `monthly/08_proposed_index_changes.sql`
  - concrete proposed index additions for `dbo.Registration` and `dbo.Rmp`
  - optional additional `Rmp` reporting index
  - review-only candidates for staged disable/drop

- `monthly/09_validate_proposed_index_changes.sql`
  - validates whether the proposed indexes exist
  - checks usage, fragmentation, and write/read balance
  - helps decide whether to keep, monitor, disable, or drop related indexes

## Proposed Index Changes

- Add `IX_Registration_RegistrationId_LastUpdated`
  - supports latest-row lookups on `RegistrationId` + `LastUpdated`

- Add `IX_Rmp_Mpxn_LastUpdated`
  - supports latest-row lookups on `Mpxn` + `LastUpdated`

- Optionally add `IX_Rmp_RmpStatus_ActiveRegistrationId_LastUpdated`
  - only if terminated-RMP reporting remains expensive after the first two changes

## Recommendation

- Deploy the two primary latest-row indexes first.
- Validate benefit using the companion validation script.
- After an observation period, review low-value `Rmp` indexes for staged disable/drop.
- Follow up separately on query rewrites for the most expensive `Rmp` and `Registration` report queries.
