# CP4: Scalability report

**Status on 18 Nov 2026: design prepared; large-data measurements pending.** The project instructions say the faculty will release `large_data.zip` on 19 Nov 2026. It is not present in this checkout, and this machine has no PostgreSQL client/server available. Therefore no large-data timing, plan, storage figure, target result, or measured growth ratio is claimed here. `benchmarks/results/large/summary.csv` currently contains only its standard header. Do not treat this design-stage file as a completed benchmark.

## Current measured reference

CP3 used the seed set of 120,000 listings on PostgreSQL 18.6 and measured three runs per query. Its optimized averages are recorded in [`../benchmarks/results/optimized/summary.csv`](../benchmarks/results/optimized/summary.csv), with plans alongside it. The 30 query averages sum to 211.197 ms (the sum of separate averages, not an end-to-end request). This is a seed-scale reference only; it does not establish 20× behavior.

## Large-data results and targets

The faculty large dataset and a PostgreSQL run are required to fill this table. The target column repeats the project's CP4 limits. “Pending” means not measured; it does not mean the target passed.

| Query | Seed optimized (ms) | Large optimized (ms) | Growth | Target | Status |
|---|---:|---:|---:|---:|---|
| R01 | 0.419 | — | — | <5 ms | Pending large data |
| R02 | 0.076 | — | — | <5 ms | Pending large data |
| R03 | 0.695 | — | — | <5 ms | Pending large data |
| R04 | 0.099 | — | — | <5 ms | Pending large data |
| R05 | 0.088 | — | — | <5 ms | Pending large data |
| R06 | 0.215 | — | — | <5 ms | Pending large data |
| R07 | 3.099 | — | — | <5 ms | Pending large data |
| R08 | 1.393 | — | — | <5,000 ms | Pending large data |
| R09 | 0.086 | — | — | <5 ms | Pending large data |
| R10 | 0.142 | — | — | <250 ms | Pending large data |
| R11 | 1.812 | — | — | <250 ms | Pending large data |
| R12 | 36.544 | — | — | <5,000 ms | Pending large data |
| R13 | 12.001 | — | — | <250 ms | Pending large data |
| R14 | 5.183 | — | — | <5,000 ms | Pending large data |
| R15 | 12.769 | — | — | <5,000 ms | Pending large data |
| R16 | 3.298 | — | — | <250 ms | Pending large data |
| R17 | 12.596 | — | — | <5,000 ms | Pending large data |
| R18 | 36.089 | — | — | <5,000 ms | Pending large data |
| R19 | 0.931 | — | — | <5,000 ms | Pending large data |
| R20 | 1.062 | — | — | <5,000 ms | Pending large data |
| R21 | 7.864 | — | — | <5,000 ms | Pending large data |
| R22 | 4.585 | — | — | <250 ms | Pending large data |
| R23 | 0.024 | — | — | <5 ms | Pending large data |
| R24 | 4.885 | — | — | <5,000 ms | Pending large data |
| R25 | 37.401 | — | — | <5,000 ms | Pending large data |
| W01 | 1.274 | — | — | <5 ms | Pending large data |
| W02 | 0.290 | — | — | <5 ms | Pending large data |
| W03 | 0.364 | — | — | <5 ms | Pending large data |
| W04 | 25.713 | — | — | <1,000 ms | Pending large data |
| W05 | 0.200 | — | — | <5 ms | Pending large data |

## Growth analysis

No query can yet be assigned to a measured growth band. As a hypothesis to check against the large plans: indexed point lookups and selective partial-index probes should grow slower than row count; broad aggregates (R12, R15, R17, R18, R21, R25) must process much of their input and are likely to grow with input size; R19 should benefit from its CP3 rewrite and thread/message indexes but still scales with the number of qualifying ads and chats. These are plan-based expectations, not observed outcomes. After loading the large set, group queries by measured large/seed ratio and explain deviations from these expectations.

## Scale-only problems and storage

Not assessed yet. Record plans before and after every scale-specific fix and keep the three-run raw plans with the summary. Capture `pg_database_size`, per-table heap size, and per-index size on the same server for the seed and large databases. Do not estimate those values from row counts.

## Partitioning design

[`../sql/08_partitioning.sql`](../sql/08_partitioning.sql) builds an isolated 16-way HASH partitioned copy of `listings` using `listing_id`. Hash partitioning retains `listing_id` as a valid primary key because the partition key is part of the unique key; existing child table foreign keys can keep their single-column shape if the partitioned table replaces the original. This distributes writes and maintenance across child relations and enables pruning for queries constrained by listing ID.

The tradeoff is significant: the main browse and reporting workload filters by city, category, status, or time, not by `listing_id`, so the hash design will scan all 16 partitions for those queries. It is a candidate for ID-oriented distribution, not a proven latency improvement. The SQL keeps the original `olx.listings` intact and copies rows into `olx_partitioned.listings`; dependent tables continue to reference the original during the experiment. Compare `EXPLAIN (ANALYZE, BUFFERS)` and storage on both tables after the large data arrives before adopting it.

Range partitioning on `posted_at` could prune time-bounded reports, but PostgreSQL requires every primary/unique constraint on a partitioned table to include the partition key. The current `PRIMARY KEY (listing_id)` and all single-column child foreign keys would need a coordinated key/FK redesign (for example `(listing_id, posted_at)` carried through every referencing table), or a separate unpartitioned ID registry. No range migration is claimed until that integrity cost is designed and tested.

## 100× architecture proposal

- **Sharding:** Do not shard by category because categories are few and workload joins frequently span categories. Seller hashing can keep a seller's listings together but buyer–seller chats can cross shards. City sharding aligns local browse, but users move and chats/offers/favourites can involve distant cities. At 100×, use a stable listing-ID shard key and keep chat threads/messages colocated by `thread_id`; route a thread through its listing's shard and use a small global user directory. R01/R02/R09, R05, and listing-specific writes can route; R15/R17/R18/R21/R24/R25, global search, and cross-shard buyer inbox discovery require fan-out or pre-aggregated results. Validate this design with measured cardinalities before adoption.
- **Read replicas and caching:** R01–R03, R08–R25 are reads suitable for replicas where slight replication lag is acceptable. Cache browse and aggregate results with short TTLs and invalidate listing detail/browse keys on writes. Login R23 and seller/chat state may need primary reads for fresh ban or unread state. W01–W05 always go to the primary; W04 is a primary batch update.
- **Maintenance:** Tune autovacuum per relation from measured update churn and dead-tuple growth, especially `listings` under W04 and status changes. Monitor `pg_stat_user_tables`, vacuum progress, bloat, WAL volume and replica lag. Archive expired/sold listing history only after retention and FK requirements are agreed; preserve recent data and query semantics. Refresh materialized daily/category summaries after ingestion, with a documented freshness window. Choose thresholds and schedules from large-run measurements rather than guessing them now.

## Conclusion

The CP3 seed workload is optimized and measured, but readiness for 20× volume is not yet demonstrated. The partition DDL and architecture choices are proposals only. Completion requires the faculty `large_data.zip`, three-run PostgreSQL measurements, target checks, query plans, and seed-versus-large storage numbers. Remaining risks include broad aggregation cost, W04 update/WAL volume, replica lag, and the mismatch between listing-ID hash partitioning and the workload's city/date filters.
