-- CP5 partitioning design demonstration.
-- Run against a database where sql/01_schema.sql has created olx.listings.
-- This creates a disposable partitioned copy, prints a pruning EXPLAIN, then rolls back.
-- It does not move or alter the benchmark table.
BEGIN;
CREATE SCHEMA olx_partition_demo;

-- RANGE on posted_at keeps time-window reports and retention operations local to partitions.
-- LIKE copies the source columns, defaults, NOT NULL, and CHECK constraints, but not its PK.
CREATE TABLE olx_partition_demo.listings (
    LIKE olx.listings INCLUDING DEFAULTS INCLUDING CONSTRAINTS
) PARTITION BY RANGE (posted_at);

-- A partitioned unique/primary key must include the partition key. This composite key
-- enforces uniqueness of (listing_id, posted_at), not listing_id alone.
ALTER TABLE olx_partition_demo.listings
    ADD CONSTRAINT listings_partitioned_pk PRIMARY KEY (listing_id, posted_at);

CREATE TABLE olx_partition_demo.listings_2025
    PARTITION OF olx_partition_demo.listings
    FOR VALUES FROM (TIMESTAMPTZ '2025-01-01 00:00:00+05:30')
             TO (TIMESTAMPTZ '2026-01-01 00:00:00+05:30');
CREATE TABLE olx_partition_demo.listings_2026
    PARTITION OF olx_partition_demo.listings
    FOR VALUES FROM (TIMESTAMPTZ '2026-01-01 00:00:00+05:30')
             TO (TIMESTAMPTZ '2027-01-01 00:00:00+05:30');
CREATE TABLE olx_partition_demo.listings_other
    PARTITION OF olx_partition_demo.listings DEFAULT;

-- The plan should scan only listings_2026; other partitions are pruned at plan time.
EXPLAIN (COSTS OFF)
SELECT listing_id, title, posted_at
FROM olx_partition_demo.listings
WHERE posted_at >= TIMESTAMPTZ '2026-06-01 00:00:00+05:30'
  AND posted_at <  TIMESTAMPTZ '2026-07-01 00:00:00+05:30';

ROLLBACK;
