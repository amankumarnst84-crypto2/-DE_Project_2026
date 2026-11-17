# CP2: Baseline query timings

**Status:** Complete. Timings are from native PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` on the CP1 seed database.

## Measurement setup

- PostgreSQL version: 18.6 (Postgres.app)
- Database: `olx_capstone`
- Dataset: the 11 CSV files in `seed_data/`
- Schema: `sql/01_schema.sql`
- Query workload: unchanged `queries/workload_30.sql`
- Runs per query: 3
- Method: `benchmarks/run_benchmark.sh <database> baseline`

## Timing results

Run times are the three `Execution Time` values in each raw plan. Averages and scan nodes come from `summary.csv`. Raw plans (`R01.txt` through `W05.txt`) are included alongside the summary.

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Scan type | Observation |
|---|---|---:|---:|---:|---:|---|---|
| R01: Browse active cars in Bengaluru, ₹3–6 lakh, newest first | READ | 11.067 | 8.957 | 7.908 | **9.311** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R02: Filter Pune diesel cars from 2018+, at most 60,000 km | READ | 6.361 | 5.830 | 5.291 | **5.827** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R03: Search active iPhone 13 ads, cheapest first | READ | 47.758 | 44.023 | 44.473 | **45.418** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R04: Listing 100871 with seller and average rating | READ | 0.394 | 0.415 | 0.374 | **0.394** | Index Scan using listings_pkey on listings; Index Scan using users_pkey on users; Seq Scan on seller_ratings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R05: User 1042 listings by status | READ | 8.760 | 8.851 | 8.307 | **8.639** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R06: User 1042 chat inbox with latest message | READ | 61.599 | 63.029 | 63.441 | **62.690** | Seq Scan on listings; Seq Scan on chat_threads; Seq Scan on chat_messages | Latest-message selection reads chat threads and messages with sequential scans. |
| R07: Unread messages for user 1042 | READ | 5.950 | 5.461 | 5.297 | **5.569** | Seq Scan on chat_messages; Index Scan using chat_threads_pkey on chat_threads; Index Scan using listings_pkey on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R08: Median 2026 iPhone 13 asking price by condition | READ | 6.274 | 5.844 | 5.887 | **6.002** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R09: Active furniture within ~2 km of central Bengaluru | READ | 6.505 | 6.404 | 6.394 | **6.434** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R10: Active ads expiring in first 3 days of July 2026 | READ | 5.612 | 5.315 | 5.679 | **5.535** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R11: Ads with 3+ open reports | READ | 1.906 | 1.893 | 2.012 | **1.937** | Seq Scan on reports; Index Scan using listings_pkey on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R12: Users posting 5+ ads on same day | READ | 33.712 | 34.101 | 33.588 | **33.800** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R13: Boost packages never purchased | READ | 13.842 | 13.616 | 13.700 | **13.719** | Seq Scan on boost_packages; Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R14: Average 2026 days to sell per category | READ | 9.123 | 9.171 | 9.247 | **9.180** | Seq Scan on listings; Seq Scan on categories | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R15: Accepted offer share per category | READ | 12.431 | 12.576 | 12.507 | **12.505** | Seq Scan on listings; Seq Scan on offers; Seq Scan on categories | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R16: Most-favourited active ads in last 7 days of June 2026 | READ | 11.665 | 12.357 | 11.954 | **11.992** | Seq Scan on listings; Seq Scan on favourites | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R17: Average views of boosted vs normal ads per category | READ | 11.709 | 12.130 | 13.395 | **12.411** | Seq Scan on listings; Seq Scan on categories | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R18: Same seller, title, and price posted more than once | READ | 38.739 | 34.515 | 35.995 | **36.416** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R19: Chats and latest chat time for each active Bengaluru car ad | READ | 1126.816 | 1104.660 | 1104.807 | **1112.094** | Seq Scan on listings; Index Only Scan using chat_threads_listing_id_buyer_id_key on chat_threads; Seq Scan on chat_messages; Index Scan using chat_threads_listing_id_buyer_id_key on chat_threads | Slowest query; scans messages and repeatedly probes threads for each listing. |
| R20: June 2026 new ads per day and running total | READ | 7.411 | 7.182 | 6.960 | **7.184** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R21: Best-rated sellers with at least 5 ratings | READ | 7.967 | 7.975 | 7.899 | **7.947** | Seq Scan on seller_ratings; Seq Scan on users | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R22: Moderation console page 2,001 (25 ads/page) | READ | 29.356 | 29.225 | 29.959 | **29.513** | Seq Scan on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R23: Login by mobile number | READ | 0.022 | 0.023 | 0.023 | **0.023** | Index Scan using users_phone_key on users | Selective lookup uses an existing primary-key or unique index. |
| R24: Active ads by top-level category | READ | 10.893 | 10.817 | 11.010 | **10.907** | Seq Scan on listings; Seq Scan on categories | Sequential scan reads table rows; CP1 has constraint indexes only. |
| R25: 2026 average first-response minutes per category | READ | 39.024 | 39.515 | 39.293 | **39.277** | Seq Scan on chat_messages; Seq Scan on chat_threads; Seq Scan on listings; Seq Scan on categories | Sequential scan reads table rows; CP1 has constraint indexes only. |
| W01: Post study table ad for user 1042 | WRITE | 0.949 | 0.615 | 0.654 | **0.739** | No scan node reported | See the matching raw plan for the execution details. |
| W02: Mark user 1042 oldest active ad sold | WRITE | 8.815 | 8.916 | 8.720 | **8.817** | Seq Scan on listings; Index Scan using listings_pkey on listings | Sequential scan reads table rows; CP1 has constraint indexes only. |
| W03: User 1042 sends message in most recent buyer conversation | WRITE | 0.547 | 0.528 | 0.503 | **0.526** | Index Scan using chat_threads_pkey on chat_threads | Selective lookup uses an existing primary-key or unique index. |
| W04: Expire active ads past expiry at 2026-07-01 | WRITE | 58.417 | 17.644 | 17.083 | **31.048** | Seq Scan on listings | Expiry update scans listings; runtime varies with rows that qualify. |
| W05: Accept highest pending offer on listing 118642 and reject others | WRITE | 1.298 | 1.288 | 1.235 | **1.274** | Seq Scan on offers | Sequential scan reads table rows; CP1 has constraint indexes only. |
| **Total (sum of all 30 averages)** | | | | | **1537.128** | | |
