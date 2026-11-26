# CP5: Large-data scalability report

**Status:** Phase 5 benchmark and analysis complete; no commit or push has been made.  
**Measurement date:** 24 Nov 2026  
**Database:** PostgreSQL 18.6, `olx_large`; optimized seed comparison: `olx_capstone`.

## Method

Loaded the provided `large_data/` CSVs into the same schema in a separate database, applied `sql/05_indexes.sql`, ran `ANALYZE`, and used the 30-query optimized workload in `sql/06_optimized_queries.sql`. Each query was measured three times using the existing benchmark runner. `benchmarks/results/large/summary.csv` contains the mean, median, min/max, and scan nodes; each `Rxx.txt`/`Wxx.txt` file records all three `EXPLAIN ANALYZE` plans. The seed comparison uses the refreshed three-run optimized results at `benchmarks/results/optimized/summary.csv`. Database and machine were the same for both sets; cache state and ordinary run-to-run variation still affect timings.

The benchmark database was analyzed and vacuumed before the final runs. The seed reference was likewise refreshed using the final R07 rewrite. Large CSVs are local-only and ignored by Git (`large_data/`); do not include them in the submission.

## Dataset scale and storage

The large set contains 1,000,000 users; 2,400,000 listings; 1,197,387 chat threads; 4,190,915 messages; 399,105 offers; 1,399,998 favourites; 159,983 reports; and 226,984 seller ratings (plus small lookup tables). Compared with the seed set, it has 20× listings and users, while related tables grew by roughly 20× as expected from the provided data.

| Database | Table relations | Index relations | Database size |
|---|---:|---:|---:|
| Seed `olx_capstone` | 72 MB | 65 MB | 145 MB |
| Large `olx_large` | 1,417 MB | 1,335 MB | 2,760 MB |

Database size grew about **19×**. Listings occupy about 1,471 MB including indexes; chat messages about 633 MB; chat threads about 186 MB. Indexes consume nearly as much as table storage, so index usefulness and write cost need continued review at larger scale.

## Seed vs. large query timings

Ratios compare large average to seed average. Targets follow the README workload classes: real-time queries under 5 ms, interactive tools under 250 ms, analytics under 5,000 ms, and batch W04 under 1,000 ms. The notes call out the two misses.

| Query | Seed avg (ms) | Large avg (ms) | Growth | Target | Observation |
|---|---:|---:|---:|---|---|
| R01 | 0.464 | 0.108 | 0.2× | PASS (<5 ms; real-time) |  |
| R02 | 0.049 | 2.851 | 58.2× | PASS (<5 ms; real-time) |  |
| R03 | 0.790 | 23.581 | 29.8× | MISS (<5 ms; real-time) | Substring search; GIN finds candidates but heap reads and price sort dominate. |
| R04 | 0.084 | 0.307 | 3.7× | PASS (<5 ms; real-time) |  |
| R05 | 0.072 | 0.069 | 1.0× | PASS (<5 ms; real-time) |  |
| R06 | 0.190 | 1.554 | 8.2× | PASS (<5 ms; real-time) |  |
| R07 | 0.113 | 0.389 | 3.4× | PASS (<5 ms; real-time) |  |
| R08 | 1.474 | 43.112 | 29.2× | PASS (<5,000 ms; analytics) |  |
| R09 | 0.079 | 0.210 | 2.7× | PASS (<5 ms; real-time) |  |
| R10 | 0.078 | 0.889 | 11.4× | PASS (<250 ms; interactive) |  |
| R11 | 1.614 | 23.420 | 14.5× | PASS (<250 ms; interactive) |  |
| R12 | 36.585 | 773.144 | 21.1× | PASS (<5,000 ms; analytics) |  |
| R13 | 11.860 | 208.830 | 17.6× | PASS (<250 ms; interactive) |  |
| R14 | 3.711 | 32.320 | 8.7× | PASS (<5,000 ms; analytics) |  |
| R15 | 12.245 | 234.026 | 19.1× | PASS (<5,000 ms; analytics) |  |
| R16 | 1.494 | 18.133 | 12.1× | PASS (<250 ms; interactive) |  |
| R17 | 12.152 | 192.311 | 15.8× | PASS (<5,000 ms; analytics) |  |
| R18 | 36.551 | 1236.503 | 33.8× | PASS (<5,000 ms; analytics) |  |
| R19 | 0.849 | 163.516 | 192.6× | PASS (<5,000 ms; analytics) |  |
| R20 | 0.959 | 18.795 | 19.6× | PASS (<5,000 ms; analytics) |  |
| R21 | 8.039 | 161.489 | 20.1× | PASS (<5,000 ms; analytics) |  |
| R22 | 3.108 | 3.463 | 1.1× | PASS (<250 ms; interactive) |  |
| R23 | 0.024 | 0.211 | 8.8× | PASS (<5 ms; real-time) |  |
| R24 | 2.168 | 19.796 | 9.1× | PASS (<5,000 ms; analytics) |  |
| R25 | 40.470 | 826.653 | 20.4× | PASS (<5,000 ms; analytics) |  |
| W01 | 1.206 | 1.534 | 1.3× | PASS (<5 ms; real-time) |  |
| W02 | 0.268 | 0.358 | 1.3× | PASS (<5 ms; real-time) |  |
| W03 | 0.390 | 0.552 | 1.4× | PASS (<5 ms; real-time) |  |
| W04 | 89.432 | 7168.431 | 80.2× | MISS (<1,000 ms; batch) | Bulk expiry update is write/I/O bound after indexed row discovery. |
| W05 | 0.208 | 0.193 | 0.9× | PASS (<5 ms; real-time) |  |

## Growth analysis

For a simple grouping, “about the same” means less than 5×, “roughly proportional” means 5–25×, and “more than proportional” means above 25×. Ratios are sensitive to sub-millisecond seed measurements, so read them together with the actual large-data time and scan plan.

- **Stayed about the same (<5×):** R01, R04, R05, R07, R09, R22, W01, W02, W03, W05. These use selective indexes or do fixed small work; several seed averages were already close to the measurement floor.
- **Grew roughly with data volume (5–25×):** R06, R10–R17, R20, R21, R23–R25. These include broad scans/aggregations that process a larger share of rows, and selective lookups whose candidate or joined data grew. R12 (0.773 s), R18 (1.237 s), and R25 (0.827 s) remain below the 5 s analytics target; they still merit monitoring because their plans read or aggregate broad data. R13 (209 ms), R15 (234 ms), and R17 (192 ms) are analytics queries, within the 5 s target.
- **Grew more than proportionally (>25×):** R02 (58×, but only 2.851 ms), R03 (30×), R08 (29×), R18 (34×), R19 (193×), and W04 (80×). Tiny seed timings magnify the ratios for R02/R08. R03 visits thousands of title matches and sorts by price. R18 groups most listings. R19 combines listings, threads, and messages; its 13.3–463.6 ms range indicates cache/run sensitivity, so track p95 and buffer reads as well as the mean. W04 updates tens of thousands of rows and pays heap/index/WAL costs.

R03 and W04 remain target misses despite their plans using the expected indexes for finding candidates. The R03 trial price index made performance worse and was removed. Meaningful further improvements need a changed search/read model for R03 and a batched expiry job for W04; those are documented as next actions rather than claimed as completed fixes. The completed Phase 5 query fix is R07, detailed below.
- R03 misses its <5 ms user-facing target: mean 23.581 ms (10.076–43.244 ms). The trigram GIN index is used and sharply narrows the title search, but it still returns thousands of candidates whose heap rows must be visited before ordering by price. A trial price B-tree did not help, so it was removed; adding an index without a matching access path would add storage/write cost without fixing the work.
- W04 misses its <1,000 ms target: mean 7,168 ms (5,771–8,401 ms). The expiry index finds the eligible rows, but updating tens of thousands of rows writes heap pages, indexes, and WAL. This is a bulk-write bottleneck rather than a row-discovery scan problem. At application level, expire listings in bounded batches; at larger scale, time-based partitions can make retention/removal less costly when the data model permits it.

## R07 query fix

The original R07 plan scanned all 1,197,387 chat threads in parallel on each measured execution, then performed thousands of listing lookups. Its recorded mean on the large data was about 32.7 ms (28.182–41.248 ms). The rewritten R07 first discovers threads through separate buyer and seller indexes, de-duplicates them, then counts unread messages through the partial unread-message index. The final benchmark mean is **0.389 ms**, and the new plans show indexed lookups rather than a parallel scan of all threads. `benchmarks/results/large/R07_before_fix.txt` preserves the three original plans for comparison. A bidirectional `EXCEPT ALL` comparison on the large database returned no differences, confirming the rewrite preserves results.

## Partitioning demonstration

`sql/08_partitioning.sql` is a rollback-only demonstration that creates a partitioned copy of `listings`, partitioned by `posted_at`, and runs `EXPLAIN` for a June 2026 date window. PostgreSQL prunes the other partitions and scans only `listings_2026`. The script ends with `ROLLBACK`, so it does not alter the benchmark schema/data.

For production, use monthly RANGE partitions if time-window scans and retention dominate, with a default partition and future partitions created ahead of time. This helps queries that filter on `posted_at` and permits old data to be detached or archived quickly. It does not accelerate every workload: city/category searches without a posted-time bound may still touch many partitions, and `sold_at` queries need a separate design. PostgreSQL requires a partitioned unique/primary key to include the partition key; the demo therefore uses `(listing_id, posted_at)`. The current child tables reference `listing_id`, so a real migration must redesign/propagate keys and foreign keys before partitioning the production table.

## Architecture recommendation at 100×

1. **Partition time-oriented data.** Partition listings by `posted_at` and messages by message timestamp; detach/archive old partitions under a retention policy. Keep frequently queried recent partitions local and maintain a default partition.
2. **Shard only after vertical capacity and partitioning are insufficient.** A practical listing shard key is `seller_id` (hash) for seller-owned reads and writes; retain a routing directory for `listing_id`. City/category marketplace searches then fan out across shards, so use a search index or a dedicated read model for global browsing. Chat needs deliberate colocation/routing: store each thread and its messages together and keep participant-to-thread lookup data available to both buyer and seller inbox paths.
3. **Separate read-heavy analytics.** Send broad reporting queries (R08, R12, R14–R25) to an asynchronous read replica or refreshed reporting store. Keep fresh chat/unread state and transactional writes on the primary. Use short-lived caches for repeated popular city/category/model aggregates, with invalidation tied to listing changes.
4. **Control write amplification.** Batch expiry updates, monitor WAL volume and replication lag, and avoid unnecessary indexes. Tune autovacuum/analyze for high-churn tables based on measured dead tuples and vacuum lag; for listings, evaluate a lower per-table scale factor (for example 0.02) only after observing actual churn, rather than applying one global setting blindly.
5. **Keep observability in the loop.** Track query p95/p99, buffer reads, index/table sizes, dead tuples, vacuum lag, replica lag, and partition growth. Re-run the same three-run workload after each data/layout change.

## Conclusion

Most read queries and four of five writes meet the stated limits at this data size. R03 substring search and W04 mass expiry update are the two measured target misses; their measured bottlenecks and practical next actions are stated above. R07's full-thread scan was removed with an equivalent indexed rewrite. The partitioning demo confirms time-window pruning, but the composite-key/foreign-key implications need a planned schema migration. At 100×, partitioning, bounded expiry processing, read replicas/reporting models, selective caching, and only then sharding provide a sensible progression; this measurement does not claim that unmitigated 100× production is already within target.

## Handoff files

- `benchmarks/results/large/summary.csv` and the 30 raw large-data plans
- `benchmarks/results/large/R07_before_fix.txt` (original R07 comparison)
- `docs/05_scalability_report.md` (this report)
- `sql/06_optimized_queries.sql` (equivalent optimized R07 rewrite)
- `sql/08_partitioning.sql` (partitioning proof)
- Refreshed seed comparison: `benchmarks/results/optimized/summary.csv` and `docs/04_optimization_report.md`
