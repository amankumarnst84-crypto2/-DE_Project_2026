# Contributing to Nexora DE

1. Pull the latest main before editing. Use your own Git identity and GitHub account.
2. Choose a concrete change: fix a documented issue, improve a schema explanation, validate a query edge case, or collect a reproducible result. Describe what changed and why.
3. Keep queries/workload_30.sql and the instructor benchmark runner unchanged. Optimized query bodies belong in sql/06_optimized_queries.sql.
4. Keep generated CSV seed data out of Git. Do not commit database passwords, connection URLs containing credentials, local databases or node_modules.
5. If results change, include all three raw plans and the corresponding summary/report together. Run `python3 scripts/check_benchmarks.py` before submission.
6. Review the diff with `git diff` and stage only the files you intend to submit. Commit under the actual contributor's identity; do not impersonate another team member.
7. Use a normal push or pull request; do not force-push shared main. A tracker only sees the final files once merged/pushed to its default branch.

A commit count is not evidence that every member understands the work. Each contributor should be able to explain their changes and the limitations of any measurements they report.
