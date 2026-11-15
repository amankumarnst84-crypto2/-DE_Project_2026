-- Nexora T0138: PostgreSQL 15+; run once on an empty database.
-- CP1: only constraint-backed indexes, no performance indexes.
BEGIN;
CREATE SCHEMA olx;
SET search_path TO olx;
SET TIME ZONE 'Asia/Kolkata';
CREATE TABLE cities (
 city_id integer PRIMARY KEY,
 city_name text NOT NULL CHECK (btrim(city_name) <> ''),
 state text NOT NULL CHECK (btrim(state) <> ''),
 UNIQUE (city_name, state)
);
CREATE TABLE categories (
 category_id integer PRIMARY KEY,
 category_name text NOT NULL CHECK (btrim(category_name) <> ''),
 parent_id integer REFERENCES categories(category_id) ON DELETE RESTRICT,
 CHECK (parent_id <> category_id)
);
CREATE TABLE boost_packages (
 package_id integer PRIMARY KEY,
 package_name text NOT NULL UNIQUE CHECK (btrim(package_name) <> ''),
 price numeric(12,2) NOT NULL CHECK (price > 0),
 duration_days smallint NOT NULL CHECK (duration_days > 0)
);
CREATE TABLE users (
 user_id bigint PRIMARY KEY,
 full_name text NOT NULL CHECK (btrim(full_name) <> ''),
 phone varchar(15) NOT NULL UNIQUE CHECK (phone ~ '^[0-9]{10,15}$'),
 email text UNIQUE,
 city_id integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
 phone_verified boolean NOT NULL DEFAULT false,
 is_banned boolean NOT NULL DEFAULT false,
 joined_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE listings (
 listing_id bigint PRIMARY KEY,
 seller_id bigint NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 category_id integer NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
 title text NOT NULL CHECK (btrim(title) <> ''),
 description text,
 price numeric(12,2) NOT NULL CHECK (price >= 0),
 is_negotiable boolean NOT NULL DEFAULT true,
 item_condition text NOT NULL CHECK (item_condition IN ('NEW','LIKE_NEW','GOOD','FAIR')),
 attributes jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(attributes) = 'object'),
 city_id integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
 locality text NOT NULL CHECK (btrim(locality) <> ''),
 latitude numeric(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
 longitude numeric(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
 image_count smallint NOT NULL DEFAULT 0 CHECK (image_count BETWEEN 0 AND 12),
 view_count bigint NOT NULL DEFAULT 0 CHECK (view_count >= 0),
 boost_package_id integer REFERENCES boost_packages(package_id) ON DELETE RESTRICT,
 status text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SOLD','EXPIRED','REMOVED')),
 posted_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 expires_at timestamptz NOT NULL,
 sold_at timestamptz,
 CHECK (expires_at > posted_at),
 CHECK ((status = 'SOLD') = (sold_at IS NOT NULL)),
 CHECK (sold_at IS NULL OR sold_at >= posted_at)
);
CREATE TABLE chat_threads (
 thread_id bigint PRIMARY KEY,
 listing_id bigint NOT NULL REFERENCES listings(listing_id) ON DELETE RESTRICT,
 buyer_id bigint NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE (listing_id, buyer_id)
);
CREATE TABLE chat_messages (
 message_id bigint PRIMARY KEY,
 thread_id bigint NOT NULL REFERENCES chat_threads(thread_id) ON DELETE RESTRICT,
 sender_id bigint NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 body text NOT NULL CHECK (btrim(body) <> ''),
 sent_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 is_read boolean NOT NULL DEFAULT false
);
CREATE TABLE offers (
 offer_id bigint PRIMARY KEY,
 listing_id bigint NOT NULL REFERENCES listings(listing_id) ON DELETE RESTRICT,
 buyer_id bigint NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 offer_price numeric(12,2) NOT NULL CHECK (offer_price > 0),
 status text NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','REJECTED','COUNTERED')),
 created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 responded_at timestamptz,
 CHECK ((status = 'PENDING') = (responded_at IS NULL)),
 CHECK (responded_at IS NULL OR responded_at >= created_at)
);
CREATE TABLE favourites (
 user_id bigint NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
 listing_id bigint NOT NULL REFERENCES listings(listing_id) ON DELETE CASCADE,
 saved_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (user_id, listing_id)
);
CREATE TABLE reports (
 report_id bigint PRIMARY KEY,
 listing_id bigint NOT NULL REFERENCES listings(listing_id) ON DELETE RESTRICT,
 reporter_id bigint NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 reason text NOT NULL CHECK (reason IN ('SPAM','FRAUD','OFFENSIVE','WRONG_CATEGORY','ALREADY_SOLD')),
 created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 status text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','ACTIONED','DISMISSED')),
 UNIQUE (listing_id, reporter_id)
);
CREATE TABLE seller_ratings (
 rating_id bigint PRIMARY KEY,
 seller_id bigint NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 rater_id bigint NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
 listing_id bigint NOT NULL REFERENCES listings(listing_id) ON DELETE RESTRICT,
 stars smallint NOT NULL CHECK (stars BETWEEN 1 AND 5),
 comment text,
 created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE (listing_id, rater_id),
 CHECK (seller_id <> rater_id)
);
COMMIT;
