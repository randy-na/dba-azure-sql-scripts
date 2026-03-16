-- ============================================================
-- Weekly | 02 - Full Statistics Update
-- Run on: Primary (UK South) ONLY — will fail on read-only secondary
-- sp_updatestats only updates stats that have changed since last update.
-- ============================================================
EXEC sp_updatestats;
