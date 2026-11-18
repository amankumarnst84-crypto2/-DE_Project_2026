# Reading the timing evidence

Start with [baseline](03_baseline_timings.md) and [optimization](04_optimization_report.md), then open the corresponding raw plan under benchmarks/results. Every average represents three executions of one query, not end-to-end application latency.

- Compare absolute milliseconds as well as percentage change. A tiny near-zero login timing can show a large percentage difference due to ordinary noise.
- Sum of query averages weights each query once. It is not production throughput, a percentile, or a workload weighted by user traffic.
- A sequential scan is not automatically a defect: reports that consume most rows can be cheaper with scans than indexes.
- EXPLAIN rows and times inside repeatedly executed nodes are generally per-loop figures. Inspect loops before explaining correlated-query cost.
- Shared hit and read buffers describe PostgreSQL buffer activity. A shared read is not proof that storage hardware performed physical disk I/O; the operating system may cache it.
- Index Only Scan can still have Heap Fetches when visibility checks require the heap. Read that field before claiming heap access was eliminated.
- Read speedups have storage and write-maintenance costs. Review W01–W05 and index sizes together with read improvements.
- R13 is a documented correction of NULL semantics, so its result count intentionally differs. Keep it separate from equivalence claims.

Verify saved arithmetic without running a database:

```sh
python3 scripts/check_benchmarks.py
python3 scripts/test_check_benchmarks.py
```

Passing checks means the summary agrees with the saved plans and all expected run slots exist. It does not establish how those plans were obtained or validate every prose claim in the reports.
