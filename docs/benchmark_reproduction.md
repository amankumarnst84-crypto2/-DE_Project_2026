# Reproducing the saved benchmark phases

Run from repository root on a native PostgreSQL installation, using a new dedicated database. Preserve the existing evidence until a complete new run has been reviewed. The instructor runner overwrites the output directory selected by its phase argument.

```sh
unzip -n seed_data.zip
createdb nexora_recheck
psql -X -v ON_ERROR_STOP=1 -d nexora_recheck -f sql/01_schema.sql
psql -X -v ON_ERROR_STOP=1 -d nexora_recheck -f sql/02_load_data.sql
mkdir -p benchmarks/environment
PGOPTIONS='-c timezone=Asia/Kolkata' psql -X -v ON_ERROR_STOP=1 -d nexora_recheck -f sql/diagnostics/environment.sql > benchmarks/environment/recheck-before.txt
PGOPTIONS='-c timezone=Asia/Kolkata' bash benchmarks/run_benchmark.sh nexora_recheck recheck_baseline 3
psql -X -v ON_ERROR_STOP=1 -d nexora_recheck -f sql/05_indexes.sql
PGOPTIONS='-c timezone=Asia/Kolkata' bash benchmarks/run_benchmark.sh nexora_recheck recheck_optimized 3 sql/06_optimized_queries.sql
PGOPTIONS='-c timezone=Asia/Kolkata' psql -X -v ON_ERROR_STOP=1 -d nexora_recheck -f sql/diagnostics/environment.sql > benchmarks/environment/recheck-after.txt
python3 scripts/check_benchmarks.py benchmarks/results/recheck_baseline benchmarks/results/recheck_optimized
```

If the database name exists, choose another unused name. Never load the baseline after applying tuning indexes: rebuild a fresh database instead. Installing pg_trgm for the supplied indexes may require database-owner privileges. The server must already be running; psql connection settings can be supplied with PGHOST, PGPORT and PGUSER. Do not commit passwords.

Keep the same laptop, database contents, PostgreSQL settings and three-run policy across phases. Use the explicit timezone above because calendar casts in the workload depend on the session timezone. Close unrelated heavy jobs and record hardware separately; SQL cannot report laptop model or memory reliably.

The unchanged runner wraps writes in rollback transactions. Rolled-back writes can still affect cache state and leave dead tuples; rollback preserves logical data, not identical physical/cache state. Do not claim cold-cache timings without a defined cold-cache procedure.

The checker verifies saved run counts and timing arithmetic, not workload execution, semantic equivalence, scan-node correctness or authenticity. Recheck database row counts after the run. Keep complete raw plans with any replacement summary.
