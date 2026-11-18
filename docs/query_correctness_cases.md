# Query correctness cases for regression review

These are proposed cases for a separate scratch dataset, not claims that new tests have been executed. The committed CP3 report records seed-data comparisons. Keep the supplied workload unchanged.

| Query | Case to construct | Required comparison |
|---|---|---|
| R06 | A user is both seller and buyer across different threads | UNION must not lose threads or duplicate the same thread. |
| R06 | Two latest messages share sent_at | The original query has no tie-breaker; a different chosen tied message is possible. Define a tie-breaker only as a separately approved workload change. |
| R13 | NULL boost IDs mixed with used and unused packages | NOT EXISTS returns unused packages; the original NOT IN may return none. This is an intentional correctness fix, not result equivalence. |
| R14 | Sales exactly at local midnight on 1 Jan 2026 and 1 Jan 2027 | Include the first boundary and exclude the second, in the same session timezone as EXTRACT. |
| R19 | Matching listing has no threads, or a thread has no messages | Keep the listing, report zero chats, and leave last_chat_at NULL when no message exists. |
| R20 | Listings around midnight at both June boundaries | Half-open bounds and date grouping must use the same timezone. |
| R22 | Multiple listings share posted_at around the offset boundary | SQL unchanged does not guarantee the same tied page rows after the access path changes; ordering is not total. |
| W05 | Two pending offers have the same highest price | The smaller offer_id wins, as required by the existing ORDER BY. |

For equivalent rewrites, compare both `original EXCEPT ALL optimized` and `optimized EXCEPT ALL original` within one snapshot. EXCEPT ALL retains duplicate multiplicity but does not compare presentation order. Inspect ordering separately; LIMIT/OFFSET and ties need special care. Compare writes in separate rollback transactions starting from the same logical state, including affected rows and resulting values.

Avoid treating a successful EXPLAIN as an equivalence test. Do not alter real seed records to manufacture test conditions in the benchmark database.
