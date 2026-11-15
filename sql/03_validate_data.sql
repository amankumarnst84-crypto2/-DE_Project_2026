SET search_path TO olx;
SET TIME ZONE 'Asia/Kolkata';
-- A nonzero delta indicates a missing or additional row.
SELECT 'cities' AS table_name, count(*) AS actual, 10 AS expected, count(*) - 10 AS delta FROM cities
UNION ALL
SELECT 'categories' AS table_name, count(*) AS actual, 12 AS expected, count(*) - 12 AS delta FROM categories
UNION ALL
SELECT 'boost_packages' AS table_name, count(*) AS actual, 6 AS expected, count(*) - 6 AS delta FROM boost_packages
UNION ALL
SELECT 'users' AS table_name, count(*) AS actual, 50000 AS expected, count(*) - 50000 AS delta FROM users
UNION ALL
SELECT 'listings' AS table_name, count(*) AS actual, 120000 AS expected, count(*) - 120000 AS delta FROM listings
UNION ALL
SELECT 'chat_threads' AS table_name, count(*) AS actual, 59855 AS expected, count(*) - 59855 AS delta FROM chat_threads
UNION ALL
SELECT 'chat_messages' AS table_name, count(*) AS actual, 209529 AS expected, count(*) - 209529 AS delta FROM chat_messages
UNION ALL
SELECT 'offers' AS table_name, count(*) AS actual, 19943 AS expected, count(*) - 19943 AS delta FROM offers
UNION ALL
SELECT 'favourites' AS table_name, count(*) AS actual, 70000 AS expected, count(*) - 70000 AS delta FROM favourites
UNION ALL
SELECT 'reports' AS table_name, count(*) AS actual, 7999 AS expected, count(*) - 7999 AS delta FROM reports
UNION ALL
SELECT 'seller_ratings' AS table_name, count(*) AS actual, 11244 AS expected, count(*) - 11244 AS delta FROM seller_ratings;

-- Cross-table business checks: zero violations expected.
SELECT 'chat_buyer_is_seller' AS check_name, (SELECT count(*) FROM chat_threads t JOIN listings l USING (listing_id) WHERE t.buyer_id = l.seller_id) AS violations
UNION ALL
SELECT 'message_sender_not_participant' AS check_name, (SELECT count(*) FROM chat_messages m JOIN chat_threads t USING (thread_id) JOIN listings l USING (listing_id) WHERE m.sender_id NOT IN (t.buyer_id,l.seller_id)) AS violations
UNION ALL
SELECT 'sold_before_posted' AS check_name, (SELECT count(*) FROM listings WHERE sold_at < posted_at) AS violations
UNION ALL
SELECT 'rating_seller_mismatch' AS check_name, (SELECT count(*) FROM seller_ratings r JOIN listings l USING (listing_id) WHERE r.seller_id <> l.seller_id) AS violations
UNION ALL
SELECT 'offer_buyer_is_seller' AS check_name, (SELECT count(*) FROM offers o JOIN listings l USING (listing_id) WHERE o.buyer_id = l.seller_id) AS violations
UNION ALL
SELECT 'message_before_thread' AS check_name, (SELECT count(*) FROM chat_messages m JOIN chat_threads t USING (thread_id) WHERE m.sent_at < t.created_at) AS violations
UNION ALL
SELECT 'rating_before_sale' AS check_name, (SELECT count(*) FROM seller_ratings r JOIN listings l USING (listing_id) WHERE l.sold_at IS NULL OR r.created_at < l.sold_at) AS violations;

-- All indexes must originate from PRIMARY KEY or UNIQUE constraints.
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'olx' ORDER BY tablename,indexname;
