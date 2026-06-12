-- =============================================================================
-- Query Set 1:  Caterer Performance & On-Time Delivery Analysis
-- Author:       Gonzalo Guerreros
-- Purpose:      Rank caterers by fulfillment volume, revenue, and on-time
--               delivery rate.  These metrics directly inform supplier health
--               scoring on a catering marketplace.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1A.  Caterer Scorecard — orders, GMV, avg order size, OTD rate
--
--      OTD (On-Time Delivery) is flagged when actual_delivery <=
--      scheduled_delivery.  A 15-min grace window is industry-standard for
--      catering logistics; we surface both strict and grace-window rates.
-- -----------------------------------------------------------------------------
WITH delivered_orders AS (
    -- Restrict to completed deliveries only; exclude cancellations and in-flight
    SELECT
        o.caterer_id,
        o.order_id,
        o.order_total_usd,
        o.headcount,
        o.scheduled_delivery,
        o.actual_delivery,
        -- Minutes late: negative = arrived early
        EXTRACT(EPOCH FROM (o.actual_delivery - o.scheduled_delivery)) / 60 AS minutes_late
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.actual_delivery IS NOT NULL
)
SELECT
    c.caterer_name,
    c.cuisine_type,
    c.avg_rating,
    COUNT(d.order_id)                                                   AS total_orders,
    SUM(d.order_total_usd)                                              AS total_gmv_usd,
    ROUND(AVG(d.order_total_usd), 2)                                    AS avg_order_value_usd,
    ROUND(AVG(d.headcount), 1)                                          AS avg_headcount,
    -- Strict OTD: delivered at or before scheduled time
    ROUND(
        100.0 * SUM(CASE WHEN d.minutes_late <= 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(d.order_id), 0), 1
    )                                                                   AS otd_strict_pct,
    -- Grace-window OTD: within 15 minutes of scheduled time
    ROUND(
        100.0 * SUM(CASE WHEN d.minutes_late <= 15 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(d.order_id), 0), 1
    )                                                                   AS otd_15min_grace_pct,
    ROUND(AVG(d.minutes_late), 1)                                       AS avg_minutes_late
FROM caterers c
-- LEFT JOIN so caterers with zero delivered orders still appear in the output
LEFT JOIN delivered_orders d ON c.caterer_id = d.caterer_id
WHERE c.is_active = TRUE
GROUP BY c.caterer_id, c.caterer_name, c.cuisine_type, c.avg_rating
ORDER BY total_gmv_usd DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- 1B.  Monthly OTD Trend per Caterer
--
--      Identifies whether delivery reliability is improving or degrading over
--      time — key for capacity planning and supplier review cycles.
-- -----------------------------------------------------------------------------
SELECT
    c.caterer_name,
    DATE_TRUNC('month', o.placed_at)                                    AS order_month,
    COUNT(*)                                                            AS orders,
    ROUND(
        100.0 * SUM(CASE WHEN o.actual_delivery <= o.scheduled_delivery THEN 1 ELSE 0 END)
        / COUNT(*), 1
    )                                                                   AS otd_pct,
    -- 3-month rolling average OTD — smooths month-to-month noise
    ROUND(
        AVG(
            100.0 * SUM(CASE WHEN o.actual_delivery <= o.scheduled_delivery THEN 1 ELSE 0 END)
            / COUNT(*)
        ) OVER (
            PARTITION BY c.caterer_id
            ORDER BY DATE_TRUNC('month', o.placed_at)
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 1
    )                                                                   AS otd_3mo_rolling_avg
FROM orders o
JOIN caterers c ON o.caterer_id = c.caterer_id
WHERE o.order_status = 'delivered'
  AND o.actual_delivery IS NOT NULL
GROUP BY c.caterer_id, c.caterer_name, DATE_TRUNC('month', o.placed_at)
ORDER BY c.caterer_name, order_month;


-- -----------------------------------------------------------------------------
-- 1C.  Caterer Tier Ranking using NTILE
--
--      Buckets caterers into performance tiers (Platinum / Gold / Silver /
--      Needs Improvement) based on a composite score.  This directly maps to
--      marketplace badging / preferential placement logic.
-- -----------------------------------------------------------------------------
WITH caterer_stats AS (
    SELECT
        c.caterer_id,
        c.caterer_name,
        c.avg_rating,
        COUNT(o.order_id)                                               AS total_orders,
        COALESCE(SUM(o.order_total_usd), 0)                             AS total_gmv,
        ROUND(
            100.0 * SUM(CASE WHEN o.actual_delivery <= o.scheduled_delivery THEN 1 ELSE 0 END)
            / NULLIF(COUNT(CASE WHEN o.order_status = 'delivered' THEN 1 END), 0), 1
        )                                                               AS otd_pct
    FROM caterers c
    LEFT JOIN orders o ON c.caterer_id = o.caterer_id
    WHERE c.is_active = TRUE
    GROUP BY c.caterer_id, c.caterer_name, c.avg_rating
),
ranked AS (
    SELECT
        *,
        -- Composite score weights: 40% GMV rank, 35% OTD, 25% rating
        ROUND(
            (0.40 * PERCENT_RANK() OVER (ORDER BY total_gmv))
          + (0.35 * COALESCE(otd_pct, 0) / 100)
          + (0.25 * (avg_rating - 1) / 4),   -- normalise 1-5 scale to 0-1
        4)                                                              AS composite_score,
        NTILE(4) OVER (ORDER BY
              0.40 * PERCENT_RANK() OVER (ORDER BY total_gmv)
            + 0.35 * COALESCE(otd_pct, 0) / 100
            + 0.25 * (avg_rating - 1) / 4
        )                                                               AS performance_quartile
    FROM caterer_stats
)
SELECT
    caterer_name,
    total_orders,
    total_gmv,
    avg_rating,
    otd_pct,
    composite_score,
    CASE performance_quartile
        WHEN 4 THEN 'Platinum'
        WHEN 3 THEN 'Gold'
        WHEN 2 THEN 'Silver'
        WHEN 1 THEN 'Needs Improvement'
    END                                                                 AS performance_tier
FROM ranked
ORDER BY composite_score DESC;
