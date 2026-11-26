# CP3: Query optimization report

**Status:** Complete; seed benchmark refreshed on 24 Nov 2026 with the final R07 rewrite.

## Measurement setup

- Database: `olx_capstone`, PostgreSQL 18.6 (Postgres.app), session time zone `Asia/Kolkata`.
- Dataset: CP1 seed data (120,000 listings); same local database and machine as CP2.
- Baseline: `benchmarks/results/baseline/summary.csv` and its raw plans (3 runs/query).
- Optimized: `benchmarks/results/optimized/summary.csv` and its raw plans (3 runs/query).
- Indexes: `sql/05_indexes.sql`; optimized workload: `sql/06_optimized_queries.sql`.
- No server tuning or data changes. Write timings use the benchmark script's transaction rollback.

The sum of the 30 per-query average times changed from **1537.128 ms** to **266.726 ms**, an **82.6%** reduction. This is a sum of separate query averages, not a single end-to-end run; R19 accounts for most of the reduction.

## Before vs. after

Improvement is `(before − after) / before × 100`; negative values are regressions. The scan/problem notes summarize the baseline plan and measured optimized plan. Full three-run plans are stored in the linked files.

| Query | Before (ms) | Problem found in the plan | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|---|
| R01 | 9.311 | Baseline scanned listings then sorted matching rows. | Partial city/category/newest-first index; price remains a filter. | 0.464 | +95.0% | Yes; SQL unchanged. |
| R02 | 5.827 | Sequential scan and JSON expressions filtered the listings table. | Tiny partial expression index for active Pune Diesel cars, ordered by year. | 0.049 | +99.2% | Yes; SQL unchanged. |
| R03 | 45.418 | Sequential scan checked all listings for a leading-wildcard ILIKE. | Partial GIN trigram index on active titles. | 0.790 | +98.3% | Yes; SQL unchanged. |
| R04 | 0.394 | Seller rating scalar lookup scanned ratings. | Seller-key index including stars; enables index-only rating aggregation. | 0.084 | +78.7% | Yes; SQL unchanged. |
| R05 | 8.639 | Sequential scan read 120,000 listings to find 9 rows. | Seller/status index includes listing_id and view_count. | 0.072 | +99.2% | Yes; SQL unchanged. |
| R06 | 62.690 | OR across buyer/seller forced broad joins; latest-message lateral lookup had broad scans. | Split buyer and seller thread discovery with UNION de-duplication; buyer, seller, and latest-message indexes. | 0.190 | +99.7% | Yes; bidirectional EXCEPT ALL returned 0 rows. |
| R07 | 5.569 | Unread-message counting used broad scans and recipient joins. | UNION buyer/seller thread discovery plus partial unread-message index. | 0.113 | +98.0% | Yes; bidirectional EXCEPT ALL returned 0 rows. |
| R08 | 6.002 | Sequential scan filtered model/category and 2026 ads before median aggregation. | Category/model/date index includes price and condition. | 1.474 | +75.4% | Yes; SQL unchanged. |
| R09 | 6.434 | Sequential scan applied a latitude/longitude bounding box and distance sort. | Partial active category/coordinate index. | 0.079 | +98.8% | Yes; SQL unchanged. |
| R10 | 5.535 | Sequential scan searched active listings by an expiry date range. | Partial active expiry-date index covers reminder output. | 0.078 | +98.6% | Yes; SQL unchanged. |
| R11 | 1.937 | Open reports were scanned before grouping. | Partial index on open reports by listing includes reasons. | 1.614 | +16.7% | Yes; SQL unchanged. |
| R12 | 33.800 | Full-table grouping by seller and session-local date remains necessary. | No rewrite; avoid keeping an unused index after the planner preferred a sequential scan. | 36.585 | -8.2% | Yes; SQL unchanged. |
| R13 | 13.719 | NOT IN returned no rows because the subquery contains NULL boost_package_id values. | Replace NOT IN with NULL-safe NOT EXISTS; correctly returns unused package IDs 5 and 6. | 11.860 | +13.6% | Corrected NULL bug; original returned 0 rows, rewrite returns 2. |
| R14 | 9.180 | EXTRACT(YEAR FROM sold_at) prevented a direct date-range index condition. | Use a session-time-zone-equivalent half-open timestamp range and a partial sold_at index. | 3.711 | +59.6% | Yes; bidirectional EXCEPT ALL returned 0 rows. |
| R15 | 12.505 | The query aggregates all offers and joins their listings; sequential scans remain cheaper. | W05 uses the offer index; full-table R15 aggregation is unchanged. | 12.245 | +2.1% | Yes; SQL unchanged. |
| R16 | 11.992 | Sequential scan/filter over favourites and listing status. | Saved_at/listing_id index plus active listing index. | 1.494 | +87.5% | Yes; SQL unchanged. |
| R17 | 12.411 | Every listing contributes to the category/boosted aggregate. | No rewrite; full data scan remains cheapest for this aggregate. | 12.152 | +2.1% | Yes; SQL unchanged. |
| R18 | 36.416 | Grouping by seller/title/price needs most listing rows; planner keeps a sequential scan. | No query rewrite; avoid a dedicated grouping index that the plan did not choose. | 36.551 | -0.4% | Yes; SQL unchanged. |
| R19 | 1112.094 | Two correlated scalar subqueries ran for each of 279 matching ads; message subplan alone touched ~296k shared buffers. | One lateral aggregate per listing with indexed thread and latest-message lookups. | 0.849 | +99.9% | Yes; bidirectional EXCEPT ALL returned 0 rows. |
| R20 | 7.184 | posted_at::date in WHERE blocked a timestamp range scan. | Use a half-open June timestamp range; retain date grouping and window total. | 0.959 | +86.7% | Yes; bidirectional EXCEPT ALL returned 0 rows. |
| R21 | 7.947 | Ratings and users are aggregated with sequential scans; 11k ratings make a full aggregate competitive. | Seller/stars index is available, but planner chose sequential scans for the complete aggregate. | 8.039 | -1.2% | Yes; SQL unchanged. |
| R22 | 29.513 | Full listing scan and external merge sort spilled ~7.5 MiB before discarding 50,000 rows. | Covering posted_at DESC index avoids sort and reads the requested deep page in order. | 3.108 | +89.5% | Yes; SQL unchanged. |
| R23 | 0.023 | Already uses the unique phone index; runtime is effectively at the measurement floor. | No change. | 0.024 | -4.3% | Yes; SQL unchanged. |
| R24 | 10.907 | Baseline scanned all listings to count active ads by top-level category. | Active partial index lets the plan visit active listings only. | 2.168 | +80.1% | Yes; SQL unchanged. |
| R25 | 39.277 | The response-time report must aggregate messages across qualifying threads. | Composite thread/time index enables an index-only message scan; remaining joins and aggregation are necessary. | 40.470 | -3.0% | Yes; SQL unchanged. |
| W01 | 0.739 | Insert writes a new listing row. | Insert maintains the CP3 indexes; this adds a small absolute cost. | 1.206 | -63.2% | Yes; SQL unchanged. |
| W02 | 8.817 | Subquery searched active listings for seller 1042 before updating one. | Seller/status index finds the target without scanning listings. | 0.268 | +97.0% | Yes; SQL unchanged. |
| W03 | 0.526 | Thread discovery for buyer 1042. | Buyer/thread index speeds the lookup; the new message still updates indexes. | 0.390 | +25.9% | Yes; SQL unchanged. |
| W04 | 31.048 | Bulk update filters active listings by expiry. | The partial expiry index locates qualifying rows; the mass update remains write-bound. | 89.432 | -188.0% | Yes; SQL unchanged. |
| W05 | 1.274 | Pending offers were searched and ordered by price. | Listing/price/offer index supports highest-pending-offer lookup. | 0.208 | +83.7% | Yes; SQL unchanged. |
| **Total of per-query averages** | **1537.128** | | | **266.726** | **82.6%** | |

## Result equivalence and NULL correction

For rewritten read queries R06, R07, R14, R19, and R20, I compared the original and optimized results in both directions using `EXCEPT ALL`. Each comparison returned zero rows on both sides. R14's half-open timestamp range uses timestamp literals interpreted in the current `Asia/Kolkata` session zone, matching the original `EXTRACT(YEAR ...)` behavior for 2026. R20 also uses the session-local date boundary while preserving `posted_at::date` for grouping.

R13 is the required correctness fix. The original `NOT IN` subquery includes NULL `boost_package_id` values, so SQL's three-valued logic made the predicate unknown for every package and returned **0 rows**. The NULL-safe `NOT EXISTS` returns the two packages never referenced by any listing: package IDs **5 and 6**. This intentional result correction is documented rather than presented as an equivalent rewrite. The other 24 query bodies, including all five writes, remain unchanged; writes are benchmarked inside rollback transactions.

## Plans for the five largest time savings

These are the five largest reductions in absolute average milliseconds. Each linked raw plan file contains all three complete plans and execution times. Excerpts below show the plan change on run 1.

### R19: 1,112.094 → 0.849 ms (99.9% faster)

Before: the outer listing scan ran two correlated subplans per row; the message subplan touched about 296,399 shared buffers over 279 loops. After: the query uses the city/category listing index and per-listing thread/message index lookups.

- Before: [baseline R19 plan](../benchmarks/results/baseline/R19.txt)
- After: [optimized R19 plan](../benchmarks/results/optimized/R19.txt)

```text
Before: Parallel Seq Scan on listings; correlated SubPlan 2 loops=279; Buffers shared hit=296399
After:  Index Only Scan using idx_listings_active_city_category_posted; indexed thread/message lookups
```

### R06: 62.690 → 0.190 ms (99.7% faster)

Before: a broad join scanned all 120,000 listings and 59,855 threads, then filtered with buyer OR seller. After: separate buyer/seller branches use targeted indexes, `UNION` removes duplicate threads, and the latest message is found with an ordered per-thread lookup.

- Before: [baseline R06 plan](../benchmarks/results/baseline/R06.txt)
- After: [optimized R06 plan](../benchmarks/results/optimized/R06.txt)

```text
Before: Parallel Seq Scan on listings; Seq Scan on chat_threads; OR join filter
After:  Index Only Scan using idx_chat_threads_buyer_thread; seller lookup via idx_listings_seller_status_views
```

### R03: 45.418 → 0.790 ms (98.3% faster)

Before: sequentially checked all 120,000 titles for `%iphone 13%`. After: a trigram bitmap index finds matching titles, then PostgreSQL sorts the 375 candidates by price.

- Before: [baseline R03 plan](../benchmarks/results/baseline/R03.txt)
- After: [optimized R03 plan](../benchmarks/results/optimized/R03.txt)

```text
Before: Seq Scan on listings; 119,625 rows removed by filter
After:  Bitmap Index Scan on idx_listings_active_title_trgm → Bitmap Heap Scan
```

### R22: 29.513 → 3.108 ms (89.5% faster)

Before: a sequential scan fed an external merge sort that spilled about 7.5 MiB to disk, then skipped 50,000 rows. After: the covering `posted_at DESC` index supplies the requested page in order, though it still walks the 50,000 skipped entries.

- Before: [baseline R22 plan](../benchmarks/results/baseline/R22.txt)
- After: [optimized R22 plan](../benchmarks/results/optimized/R22.txt)

```text
Before: Seq Scan on listings → external merge Sort (Disk: 7688kB) → OFFSET 50000
After:  Index Only Scan using idx_listings_posted_desc; 50,025 index rows visited
```

### R05: 8.639 → 0.072 ms (99.2% faster)

Before: the plan scanned the whole listings table to find 9 ads for seller 1042. After: the seller/status covering index reads those rows directly and supplies `view_count` for the grouped sum.

- Before: [baseline R05 plan](../benchmarks/results/baseline/R05.txt)
- After: [optimized R05 plan](../benchmarks/results/optimized/R05.txt)

```text
Before: Seq Scan on listings; 119,991 rows removed by filter
After:  Index Only Scan using idx_listings_seller_status_views; Index Cond: seller_id = 1042
```

## Write overhead

- **W01** was slower: 0.739 → 1.206 ms (**+0.467 ms, +63.2%**), because inserting a listing maintains the new listing indexes. The absolute cost is about 1.2 ms on this seed database; it is acceptable for the tested workload, but should be watched as volume grows.
- **W02** improved 8.817 → 0.268 ms; the seller/status index finds the target listing.
- **W03** improved 0.526 → 0.390 ms; the buyer/thread index helps locate the conversation.
- **W04** was slower: 31.048 → 89.432 ms (**+188.0%**). The expiry index narrows the 2,256 qualifying rows, but the status changes and index/WAL work dominate the update.
- **W05** improved 1.274 → 0.208 ms; the offer index supports selection by listing and price.

These write timings are small and can vary with cache and WAL state. In particular, a single run of a bulk update is not representative; use the required three-run averages.

## Index storage

`pg_relation_size` snapshot after the final benchmark on 17 Nov 2026. Table sizes are the owning table's main relation size; percentages compare index size with that table. The indexes total about **46 MiB**. The largest are the posted-time covering index, model/date index, and chat-message time index.

| Index | Table | Index size | Table size | Index/table |
|---|---|---:|---:|---:|
| `idx_chat_messages_thread_time` | `chat_messages` | 8320 kB | 19 MB | 42.2% |
| `idx_chat_messages_unread_thread` | `chat_messages` | 16 kB | 19 MB | 0.1% |
| `idx_chat_threads_buyer_thread` | `chat_threads` | 2392 kB | 3584 kB | 66.7% |
| `idx_favourites_saved_listing` | `favourites` | 2168 kB | 3568 kB | 60.8% |
| `idx_listings_active_car_filters` | `listings` | 16 kB | 35 MB | 0.0% |
| `idx_listings_active_category_coordinates` | `listings` | 800 kB | 35 MB | 2.2% |
| `idx_listings_active_city_category_posted` | `listings` | 712 kB | 35 MB | 2.0% |
| `idx_listings_active_expires` | `listings` | 640 kB | 35 MB | 1.8% |
| `idx_listings_active_title_trgm` | `listings` | 672 kB | 35 MB | 1.9% |
| `idx_listings_model_posted` | `listings` | 10120 kB | 35 MB | 27.9% |
| `idx_listings_posted_desc` | `listings` | 12 MB | 35 MB | 32.9% |
| `idx_listings_seller_status_views` | `listings` | 6040 kB | 35 MB | 16.7% |
| `idx_listings_sold_at` | `listings` | 1736 kB | 35 MB | 4.8% |
| `idx_offers_listing_price` | `offers` | 1160 kB | 1688 kB | 68.7% |
| `idx_reports_open_listing` | `reports` | 48 kB | 704 kB | 6.8% |
| `idx_seller_ratings_seller_stars` | `seller_ratings` | 368 kB | 944 kB | 39.0% |

## Queries with little or no speedup

- **R12** still has to group all listings by seller and calendar date. PostgreSQL preferred a sequential scan; the date cast depends on the session time zone, so a straightforward immutable expression index is not available. It was 8.1% slower in this run.
- **R15** aggregates every offer and joins each to its listing/category; full sequential scans remain competitive on this 120,000-listing seed set. It was 2.1% slower.
- **R17** computes an aggregate over every listing by category and boost state, so reading most rows is unavoidable. It was 1.5% slower.
- **R18** groups all listings by seller, title, and price; the planner kept the sequential scan. It was effectively unchanged (0.9% faster).
- **R21** aggregates all 11,244 ratings and joins users; the full scan is cheap at this scale. It was effectively unchanged (1.0% faster).
- **R25** must read qualifying threads/messages to calculate first-message/first-reply times. The covering message index changed the message access to an index-only scan, but the aggregation still processes the broad workload; improvement was 4.8%.
- **R23** already used the unique phone index before CP3 and is near the measurement floor; the 0.001 ms difference is noise.

The optimized workload intentionally keeps these plans simple. At this dataset size, extra indexes or query complexity did not justify their write and storage cost. Reassess against the large dataset in CP4/CP5.
