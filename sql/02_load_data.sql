-- Run from repository root with psql -X -v ON_ERROR_STOP=1.
\set ON_ERROR_STOP on
BEGIN;
SET search_path TO olx;
SET TIME ZONE 'Asia/Kolkata';
\copy cities (city_id, city_name, state) FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy categories (category_id, category_name, parent_id) FROM 'seed_data/categories.csv' WITH (FORMAT csv, HEADER true)
\copy boost_packages (package_id, package_name, price, duration_days) FROM 'seed_data/boost_packages.csv' WITH (FORMAT csv, HEADER true)
\copy users (user_id, full_name, phone, email, city_id, phone_verified, is_banned, joined_at) FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy listings (listing_id, seller_id, category_id, title, description, price, is_negotiable, item_condition, attributes, city_id, locality, latitude, longitude, image_count, view_count, boost_package_id, status, posted_at, expires_at, sold_at) FROM 'seed_data/listings.csv' WITH (FORMAT csv, HEADER true)
\copy chat_threads (thread_id, listing_id, buyer_id, created_at) FROM 'seed_data/chat_threads.csv' WITH (FORMAT csv, HEADER true)
\copy chat_messages (message_id, thread_id, sender_id, body, sent_at, is_read) FROM 'seed_data/chat_messages.csv' WITH (FORMAT csv, HEADER true)
\copy offers (offer_id, listing_id, buyer_id, offer_price, status, created_at, responded_at) FROM 'seed_data/offers.csv' WITH (FORMAT csv, HEADER true)
\copy favourites (user_id, listing_id, saved_at) FROM 'seed_data/favourites.csv' WITH (FORMAT csv, HEADER true)
\copy reports (report_id, listing_id, reporter_id, reason, created_at, status) FROM 'seed_data/reports.csv' WITH (FORMAT csv, HEADER true)
\copy seller_ratings (rating_id, seller_id, rater_id, listing_id, stars, comment, created_at) FROM 'seed_data/seller_ratings.csv' WITH (FORMAT csv, HEADER true)
COMMIT;
ANALYZE;
\ir 03_validate_data.sql
