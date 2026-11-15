# OLX marketplace: problem understanding

Team T0138 · Nexora · Section D

We are rebuilding the relational database behind a used-goods marketplace from its CSV export. A user may buy and sell; a listing connects an owner, category, location and optional paid boost. Conversations, offers, favourites, reports and ratings describe activity around that listing. CP1 establishes correct storage; later checkpoints measure and improve the supplied workload.

| Problem | Business need and affected stakeholder | Workload | Service class |
|---|---|---|---|
| P1 | Buyers need relevant listings quickly while filtering price, item details, location or title. | R01–R03, R09 | Customer-facing / real-time |
| P2 | Sellers need reliable posting, listing status changes and a useful view of their ads; buyers need an ad page with seller reputation. | R04–R05, W01–W02 | Customer-facing / real-time |
| P3 | Buyers and sellers need an inbox with the latest reply, an accurate unread count and dependable message delivery. | R06–R07, W03 | Customer-facing / real-time |
| P4 | Moderators need to find heavily reported listings, posting bursts and repeated ads, then browse the review queue. | R11–R12, R18, R22 | Reporting / operational analytics; queue browsing is interactive |
| P5 | The revenue team needs to distinguish genuinely unused boost packages from a query that returns misleading results, and compare exposure. | R13, R17 | Reporting / analytics |
| P6 | Category managers need price guidance, selling duration, offer acceptance and response-time summaries. | R08, R14–R15, R25 | Reporting / analytics |
| P7 | Growth and platform teams need trend reports and expiry jobs that remain practical as data grows; users also need fast login and home-page counts. | R10, R16, R19–R24, W04–W05 | Mixed: login, home page and offer acceptance are real-time; summaries and expiry are batch/reporting |

## Assumptions and scope

- Preserve CSV names and the 30 supplied queries. A blank optional CSV field loads as NULL, not an invented value.
- Use PostgreSQL 15+, timezone-aware timestamps and Asia/Kolkata for calendar-day reporting. Historical workload dates stay unchanged.
- A seller can own many ads and also buy other ads. One buyer has at most one thread per listing. Repeated offers remain allowed.
- A listing can have zero or one current boost. The export contains neither payment history nor photo records; do not invent those tables.
- The supplied 120,000-listing dataset is a snapshot, so do not recompute status from today's date. No performance target or timing is claimed before measurement.
- Keep baseline indexes limited to primary-key and uniqueness enforcement. Preserve all supplied rows and document any semantic anomaly instead of silently cleaning it.
