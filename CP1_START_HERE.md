# Nexora CP1: what to do next

Deadline: Monday 16 November 2026, 11:59 PM IST.

## DE deliverables

- `docs/01_problem_understanding.md`: business needs, stakeholder impact, workload categories and assumptions.
- `docs/02_schema_design.md`: complete column dictionary, keys, relationships, normalization exceptions and measured integrity results.
- `sql/01_schema.sql`: 11 PostgreSQL tables with constraints only.
- `sql/02_load_data.sql`: transactional import of the instructor CSV files.
- `sql/03_validate_data.sql`: row counts, seven integrity checks and baseline-index inventory.
- `diagrams/er_diagram.png`: complete ER diagram; editable Mermaid, DOT and SVG sources accompany it.
- `team.json`: all four members and the supplied enrollment numbers.

## Run on the team's PostgreSQL laptop

Install/start PostgreSQL 15+ before these commands. From this repository's root:

```sh
unzip -n seed_data.zip
createdb nexora_olx
psql -X -v ON_ERROR_STOP=1 -d nexora_olx -f sql/01_schema.sql
psql -X -v ON_ERROR_STOP=1 -d nexora_olx -f sql/02_load_data.sql
```

Use a fresh database name if nexora_olx already exists; do not delete existing databases just to rerun these commands. All expected-count differences and integrity-check violations should be zero. The seed CSVs are ignored by Git and must stay uncommitted.

The included correctness evidence used PostgreSQL 18.6/PGlite. Native psql has not been run on this machine. All 25 reads planned successfully; all five writes executed and rolled back. No CP2 timing numbers have been invented. For CP2, run the unchanged instructor benchmark script on the same native PostgreSQL laptop used for later comparisons, and fill the real version and laptop details in team.json.

## AP deliverable

`dbms/01_normalization.md` belongs in the WashTrack AP repository, not in this DE repository. It covers the team's supplied laundry features and proposes a relational design; compare it to the actual Prisma models before implementing CP2's schema.

## Team work that still needs people

Each member should read and explain their portion, make their own genuine contribution and commit from their own GitHub identity. The prepared work does not satisfy missing member-commit requirements on anyone else's behalf. Review the schema and normalization together before the individual evaluation.

Upcoming: CP2 Tue 17 Nov; CP3 Thu 19 Nov; final submission Mon 23 Nov; individual analysis Wed 25–Thu 26 Nov in class. The tracker may take up to three hours to refresh after a push.

## Optional embedded correctness recheck

This is not a replacement for native PostgreSQL benchmarks. With Node.js and npm installed, keep dependencies out of the repository:

```sh
validation_dir=$(mktemp -d)
npm install --prefix "$validation_dir" @electric-sql/pglite@0.5.16
cp scripts/validate_embedded.mjs "$validation_dir/validate.mjs"
node "$validation_dir/validate.mjs"
```

Run these commands from the repository root after extracting seed_data.zip. The script rewrites the two correctness-evidence files from actual results.
