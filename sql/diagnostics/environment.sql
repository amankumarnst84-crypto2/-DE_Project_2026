-- Run with psql -X -v ON_ERROR_STOP=1 -d DATABASE -f this-file.sql.
-- Read-only inventory; capture separately for each measured environment.
BEGIN READ ONLY;
SELECT version() AS server_version, current_database() AS database_name;
SELECT name, setting, unit FROM pg_settings
WHERE name IN ('TimeZone', 'work_mem', 'shared_buffers', 'effective_cache_size',
               'max_parallel_workers_per_gather', 'random_page_cost', 'jit')
ORDER BY name;
SELECT tablename, indexname, indexdef FROM pg_indexes
WHERE schemaname = 'olx' ORDER BY tablename, indexname;
SELECT relname, n_live_tup AS estimated_live_rows, last_analyze, last_autoanalyze
FROM pg_stat_user_tables WHERE schemaname = 'olx' ORDER BY relname;
-- n_live_tup is an estimate; use sql/03_validate_data.sql for exact counts.
COMMIT;
