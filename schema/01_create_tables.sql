-- =============================================================================
-- Project:  Corporate Catering Operations Analysis
-- Author:   Gonzalo Guerreros
-- Purpose:  Define the relational schema for a B2B catering marketplace.
--           Mirrors the operational data model of platforms like ezCater where
--           corporate clients place catering orders fulfilled by local caterers.
-- Engine:   PostgreSQL 15+
-- =============================================================================


-- -----------------------------------------------------------------------------
-- ENUM TYPES
-- Centralise allowed values to enforce domain integrity at the DB layer.
-- -----------------------------------------------------------------------------

CREATE TYPE order_status   AS ENUM ('pending','confirmed','in_transit','delivered','cancelled');
CREATE TYPE delivery_tier  AS ENUM ('standard','express','scheduled');
CREATE TYPE account_tier   AS ENUM ('smb','mid_market','enterprise');   -- corporate account size


-- -----------------------------------------------------------------------------
-- corporate_accounts
-- Each row represents a corporate client (the buyer side of the marketplace).
-- -----------------------------------------------------------------------------
CREATE TABLE corporate_accounts (
    account_id       SERIAL        PRIMARY KEY,
    company_name     VARCHAR(120)  NOT NULL,
    industry         VARCHAR(80),                        -- e.g. 'Technology', 'Finance'
    account_tier     account_tier  NOT NULL DEFAULT 'smb',
    city             VARCHAR(60)   NOT NULL,
    state_code       CHAR(2)       NOT NULL,
    created_at       DATE          NOT NULL,             -- first order / account open date
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE
);


-- -----------------------------------------------------------------------------
-- caterers
-- Supplier side of the marketplace — local catering businesses.
-- -----------------------------------------------------------------------------
CREATE TABLE caterers (
    caterer_id       SERIAL        PRIMARY KEY,
    caterer_name     VARCHAR(120)  NOT NULL,
    city             VARCHAR(60)   NOT NULL,
    state_code       CHAR(2)       NOT NULL,
    cuisine_type     VARCHAR(60),                        -- e.g. 'American', 'Mexican', 'Mediterranean'
    avg_rating       NUMERIC(3,2)  CHECK (avg_rating BETWEEN 1.0 AND 5.0),
    total_reviews    INT           NOT NULL DEFAULT 0,
    onboarded_at     DATE          NOT NULL,
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE
);


-- -----------------------------------------------------------------------------
-- orders
-- Core transaction table.  One row per catering order.
-- -----------------------------------------------------------------------------
CREATE TABLE orders (
    order_id             SERIAL          PRIMARY KEY,
    account_id           INT             NOT NULL REFERENCES corporate_accounts(account_id),
    caterer_id           INT             NOT NULL REFERENCES caterers(caterer_id),
    order_status         order_status    NOT NULL DEFAULT 'pending',
    delivery_tier        delivery_tier   NOT NULL DEFAULT 'standard',
    headcount            INT             NOT NULL CHECK (headcount > 0),   -- number of guests
    order_total_usd      NUMERIC(10,2)   NOT NULL CHECK (order_total_usd >= 0),
    delivery_fee_usd     NUMERIC(8,2)    NOT NULL DEFAULT 0,
    discount_usd         NUMERIC(8,2)    NOT NULL DEFAULT 0,               -- promos / credits applied
    placed_at            TIMESTAMPTZ     NOT NULL,
    scheduled_delivery   TIMESTAMPTZ     NOT NULL,                         -- promised delivery window
    actual_delivery      TIMESTAMPTZ,                                      -- NULL if not yet delivered
    cancelled_at         TIMESTAMPTZ                                       -- NULL unless cancelled
);

-- Index supporting time-series queries (most dashboards filter by date range)
CREATE INDEX idx_orders_placed_at   ON orders (placed_at);
-- Index supporting caterer-level performance queries
CREATE INDEX idx_orders_caterer     ON orders (caterer_id, order_status);
-- Index supporting account-level revenue queries
CREATE INDEX idx_orders_account     ON orders (account_id, placed_at);


-- -----------------------------------------------------------------------------
-- order_items
-- Line-item breakdown of each order (menu items ordered).
-- -----------------------------------------------------------------------------
CREATE TABLE order_items (
    item_id          SERIAL          PRIMARY KEY,
    order_id         INT             NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    item_name        VARCHAR(120)    NOT NULL,
    category         VARCHAR(60),                        -- 'Entree', 'Side', 'Beverage', 'Dessert'
    unit_price_usd   NUMERIC(8,2)    NOT NULL CHECK (unit_price_usd >= 0),
    quantity         INT             NOT NULL CHECK (quantity > 0)
);

-- Index to speed up order-level item rollups
CREATE INDEX idx_order_items_order  ON order_items (order_id);


-- -----------------------------------------------------------------------------
-- delivery_events
-- Operational log of each delivery attempt/update (SLA tracking).
-- Enables on-time delivery analysis without polluting the orders table.
-- -----------------------------------------------------------------------------
CREATE TABLE delivery_events (
    event_id         SERIAL          PRIMARY KEY,
    order_id         INT             NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    event_type       VARCHAR(40)     NOT NULL,           -- 'dispatched','arrived','completed','failed'
    event_ts         TIMESTAMPTZ     NOT NULL,
    notes            TEXT                                -- free-text from driver / caterer
);

CREATE INDEX idx_delivery_events_order ON delivery_events (order_id, event_ts);


-- -----------------------------------------------------------------------------
-- promotions
-- Tracks promotional campaigns run on the platform (needed for A/B analysis).
-- -----------------------------------------------------------------------------
CREATE TABLE promotions (
    promo_id         SERIAL          PRIMARY KEY,
    promo_code       VARCHAR(30)     UNIQUE NOT NULL,
    description      VARCHAR(200),
    discount_type    VARCHAR(20)     NOT NULL,           -- 'flat','percent','free_delivery'
    discount_value   NUMERIC(8,2)    NOT NULL,           -- dollar amount or percentage points
    start_date       DATE            NOT NULL,
    end_date         DATE            NOT NULL,
    target_tier      account_tier                        -- NULL = applies to all tiers
);

-- orders.discount_usd links back to this table conceptually;
-- a promo_orders join table is added below for explicit traceability.
CREATE TABLE promo_orders (
    promo_id         INT  NOT NULL REFERENCES promotions(promo_id),
    order_id         INT  NOT NULL REFERENCES orders(order_id),
    PRIMARY KEY (promo_id, order_id)
);
