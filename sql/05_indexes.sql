-- CP3 performance indexes for the fixed 30-query workload.
-- Apply after loading seed data: psql -d olx_capstone -f sql/05_indexes.sql
-- Each index names the workload it targets and keeps equality keys before range/order keys.
BEGIN;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- R01, R19: active listings for a city/category, in newest-first order.
CREATE INDEX IF NOT EXISTS idx_listings_active_city_category_posted
    ON olx.listings (city_id, category_id, posted_at DESC)
    INCLUDE (listing_id, title, price)
    WHERE status = 'ACTIVE';

-- R02: partial index is restricted to the exact active Pune-car Diesel cohort; year is the range key, km remains a residual filter.
CREATE INDEX IF NOT EXISTS idx_listings_active_car_filters
    ON olx.listings (((attributes ->> 'year')::integer), price)
    INCLUDE (listing_id, title)
    WHERE status = 'ACTIVE' AND city_id = 6 AND category_id = 2
      AND attributes ->> 'fuel' = 'Diesel';

-- R03: trigram index supports the leading-wildcard ILIKE search on active listings.
CREATE INDEX IF NOT EXISTS idx_listings_active_title_trgm
    ON olx.listings USING gin (title gin_trgm_ops)
    WHERE status = 'ACTIVE';

-- R08: exact model/category equality followed by the 2026 date range; covers price/condition aggregation.
CREATE INDEX IF NOT EXISTS idx_listings_model_posted
    ON olx.listings (category_id, (attributes ->> 'model'), posted_at)
    INCLUDE (price, item_condition);

-- R04, R21: group or average ratings by seller; stars are covered for index-only scans.
CREATE INDEX IF NOT EXISTS idx_seller_ratings_seller_stars
    ON olx.seller_ratings (seller_id) INCLUDE (stars);

-- R05, R06: seller dashboard grouping plus seller-owned listing discovery for the inbox.
CREATE INDEX IF NOT EXISTS idx_listings_seller_status_views
    ON olx.listings (seller_id, status) INCLUDE (listing_id, view_count);

-- R06, R07: enumerate a buyer's threads without scanning all conversations.
CREATE INDEX IF NOT EXISTS idx_chat_threads_buyer_thread
    ON olx.chat_threads (buyer_id, thread_id) INCLUDE (listing_id);

-- R06, R19, R25: newest message and per-thread timestamps; sender_id also covers R25 aggregation.
CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_time
    ON olx.chat_messages (thread_id, sent_at DESC) INCLUDE (sender_id);

-- R07: unread messages only, reached after recipient threads are identified.
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread_thread
    ON olx.chat_messages (thread_id) INCLUDE (sender_id)
    WHERE is_read = false;

-- R09: active listings by category, with coordinate range access for the map query.
CREATE INDEX IF NOT EXISTS idx_listings_active_category_coordinates
    ON olx.listings (category_id, latitude, longitude)
    INCLUDE (listing_id, title, price)
    WHERE status = 'ACTIVE';

-- R10, W04: active expiry-date range and expiry job.
CREATE INDEX IF NOT EXISTS idx_listings_active_expires
    ON olx.listings (expires_at) INCLUDE (listing_id, seller_id, title)
    WHERE status = 'ACTIVE';

-- R11: moderation reads only open reports and groups them by listing.
CREATE INDEX IF NOT EXISTS idx_reports_open_listing
    ON olx.reports (listing_id) INCLUDE (reason)
    WHERE status = 'OPEN';

-- R14: sold listings in a timestamp range, with category and posted time covered.
CREATE INDEX IF NOT EXISTS idx_listings_sold_at
    ON olx.listings (sold_at) INCLUDE (category_id, posted_at)
    WHERE status = 'SOLD';

-- W05: locate a listing's offers and find the highest pending offer by price; R15 still scans all offers for its full aggregate.
CREATE INDEX IF NOT EXISTS idx_offers_listing_price
    ON olx.offers (listing_id, offer_price DESC, offer_id) INCLUDE (status);

-- R16: date range over favourites followed by listing grouping/join.
CREATE INDEX IF NOT EXISTS idx_favourites_saved_listing
    ON olx.favourites (saved_at, listing_id);

-- R20, R22: date-range scan and newest-first deep page; included columns cover R22.
CREATE INDEX IF NOT EXISTS idx_listings_posted_desc
    ON olx.listings (posted_at DESC)
    INCLUDE (listing_id, seller_id, category_id, title, status);

ANALYZE olx.listings;
ANALYZE olx.chat_threads;
ANALYZE olx.chat_messages;
ANALYZE olx.offers;
ANALYZE olx.favourites;
ANALYZE olx.reports;
ANALYZE olx.seller_ratings;
COMMIT;
