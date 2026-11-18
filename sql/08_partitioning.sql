-- CP4 partitioning design experiment for PostgreSQL 15+.
-- Run after sql/01_schema.sql, sql/02_load_data.sql and sql/05_indexes.sql.
-- This creates an isolated comparison copy; it does not replace olx.listings.
-- HASH(listing_id) preserves listing_id as a globally unique partition key, so
-- the primary key and child-table foreign keys can retain their current shape.
BEGIN;
CREATE SCHEMA IF NOT EXISTS olx_partitioned;

CREATE TABLE olx_partitioned.listings (
    LIKE olx.listings INCLUDING DEFAULTS INCLUDING CONSTRAINTS
) PARTITION BY HASH (listing_id);

ALTER TABLE olx_partitioned.listings
    ADD CONSTRAINT listings_partitioned_pkey PRIMARY KEY (listing_id),
    ADD CONSTRAINT listings_partitioned_seller_fk
        FOREIGN KEY (seller_id) REFERENCES olx.users(user_id) ON DELETE RESTRICT,
    ADD CONSTRAINT listings_partitioned_category_fk
        FOREIGN KEY (category_id) REFERENCES olx.categories(category_id) ON DELETE RESTRICT,
    ADD CONSTRAINT listings_partitioned_city_fk
        FOREIGN KEY (city_id) REFERENCES olx.cities(city_id) ON DELETE RESTRICT,
    ADD CONSTRAINT listings_partitioned_boost_fk
        FOREIGN KEY (boost_package_id) REFERENCES olx.boost_packages(package_id) ON DELETE RESTRICT;

CREATE TABLE olx_partitioned.listings_h00 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 0);
CREATE TABLE olx_partitioned.listings_h01 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 1);
CREATE TABLE olx_partitioned.listings_h02 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 2);
CREATE TABLE olx_partitioned.listings_h03 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 3);
CREATE TABLE olx_partitioned.listings_h04 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 4);
CREATE TABLE olx_partitioned.listings_h05 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 5);
CREATE TABLE olx_partitioned.listings_h06 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 6);
CREATE TABLE olx_partitioned.listings_h07 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 7);
CREATE TABLE olx_partitioned.listings_h08 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 8);
CREATE TABLE olx_partitioned.listings_h09 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 9);
CREATE TABLE olx_partitioned.listings_h10 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 10);
CREATE TABLE olx_partitioned.listings_h11 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 11);
CREATE TABLE olx_partitioned.listings_h12 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 12);
CREATE TABLE olx_partitioned.listings_h13 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 13);
CREATE TABLE olx_partitioned.listings_h14 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 14);
CREATE TABLE olx_partitioned.listings_h15 PARTITION OF olx_partitioned.listings
    FOR VALUES WITH (MODULUS 16, REMAINDER 15);

-- The partition parent is a separate benchmark target. Child tables in the
-- other OLX relations continue to reference olx.listings during this experiment.
INSERT INTO olx_partitioned.listings
SELECT * FROM olx.listings;

CREATE INDEX listings_part_active_city_category_posted
    ON olx_partitioned.listings (city_id, category_id, posted_at DESC)
    INCLUDE (listing_id, title, price) WHERE status = 'ACTIVE';
CREATE INDEX listings_part_active_seller_status
    ON olx_partitioned.listings (seller_id, status)
    INCLUDE (listing_id, view_count);
CREATE INDEX listings_part_active_expires
    ON olx_partitioned.listings (expires_at)
    INCLUDE (listing_id, seller_id, title) WHERE status = 'ACTIVE';
CREATE INDEX listings_part_posted_desc
    ON olx_partitioned.listings (posted_at DESC)
    INCLUDE (listing_id, seller_id, category_id, title, status);

ANALYZE olx_partitioned.listings;
COMMIT;

-- Compare plans and relation sizes against olx.listings after loading large_data.
-- Hash-key probe: expect one child partition after constant folding of listing_id.
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT listing_id, title FROM olx_partitioned.listings WHERE listing_id = 100871;
--
-- R01-like browse: expect all 16 children, because city/category/status do not
-- constrain the HASH partition key. Compare its aggregate plan with CP3's index.
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT listing_id, title, price, posted_at
-- FROM olx_partitioned.listings
-- WHERE category_id = 2 AND city_id = 1 AND status = 'ACTIVE'
--   AND price BETWEEN 300000 AND 600000
-- ORDER BY posted_at DESC LIMIT 40;
