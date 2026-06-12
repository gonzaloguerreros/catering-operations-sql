-- =============================================================================
-- Query Set 4:  Promotional Effectiveness Analysis
-- Author:       Gonzalo Guerreros
-- Purpose:      Evaluate whether promotional campaigns drive incremental GMV
--               or merely subsidise orders that would have occurred anyway.
--               Outputs feed the A/B testing and campaign planning process.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 4A.  Promo Cost vs. Incremental GMV
--
--      Compares average order value for promo vs. non-promo orders within
--      the same account tier.  A well-designed promo lifts AOV; a poorly
--      designed one just transfers margin to the customer.
-- -----------------------------------------------------------------------------
SELECT
    ca.account_tier,
    CASE WHEN po.promo_id IS NOT NULL THEN 'Promo'
         ELSE 'Non-Promo' END                       AS order_type,
    COUNT(o.order_id)                               AS order_count,
    ROUND(AVG(o.order_total_usd), 2)                AS avg_order_value_usd,
    ROUND(AVG(o.discount_usd), 2)                   AS avg_discount_usd,
    -- Net revenue per order after discount cost
    ROUND(AVG(o.order_total_usd - o.discount_usd), 2) AS avg_net_revenue_usd,
    ROUND(AVG(o.headcount), 1)                      AS avg_headcount,
    -- Discount as a share of order value — margin erosion metric
    ROUND(
        100.0 * SUM(o.discount_usd) / NULLIF(SUM(o.order_total_usd), 0), 2
    )                                               AS discount_rate_pct
FROM orders o
JOIN corporate_accounts ca ON o.account_id = ca.account_id
LEFT JOIN promo_orders po ON o.order_id = po.order_id
WHERE o.order_status = 'delivered'
GROUP BY ca.account_tier, CASE WHEN po.promo_id IS NOT NULL THEN 'Promo' ELSE 'Non-Promo' END
ORDER BY ca.account_tier, order_type;


-- -----------------------------------------------------------------------------
-- 4B.  Campaign-Level ROI Summary
--
--      For each promotion, calculates total discount spend, orders influenced,
--      and GMV generated.  A promo is considered ROI-positive if GMV lift
--      per discounted dollar exceeds a 5x threshold (platform take-rate ~20%).
-- -----------------------------------------------------------------------------
WITH promo_metrics AS (
    SELECT
        p.promo_id,
        p.promo_code,
        p.description,
        p.discount_type,
        p.discount_value,
        p.target_tier,
        p.start_date,
        p.end_date,
        COUNT(po.order_id)                              AS orders_with_promo,
        SUM(o.order_total_usd)                          AS gross_gmv_usd,
        SUM(o.discount_usd)                             AS total_discount_cost_usd,
        SUM(o.order_total_usd - o.discount_usd)         AS net_gmv_usd
    FROM promotions p
    LEFT JOIN promo_orders po ON p.promo_id = po.promo_id
    LEFT JOIN orders o ON po.order_id = o.order_id AND o.order_status = 'delivered'
    GROUP BY p.promo_id, p.promo_code, p.description, p.discount_type,
             p.discount_value, p.target_tier, p.start_date, p.end_date
)
SELECT
    promo_code,
    description,
    discount_type,
    target_tier,
    start_date,
    end_date,
    orders_with_promo,
    gross_gmv_usd,
    total_discount_cost_usd,
    net_gmv_usd,
    -- GMV generated per $1 of discount spend
    ROUND(gross_gmv_usd / NULLIF(total_discount_cost_usd, 0), 2)    AS gmv_per_discount_dollar,
    -- Flag campaigns that meet the 5x ROI threshold
    CASE
        WHEN gross_gmv_usd / NULLIF(total_discount_cost_usd, 0) >= 5
            THEN 'ROI Positive'
        WHEN total_discount_cost_usd = 0
            THEN 'Free Delivery (No Discount Cost)'
        ELSE 'ROI Negative'
    END                                                              AS roi_assessment
FROM promo_metrics
ORDER BY net_gmv_usd DESC NULLS LAST;


-- -----------------------------------------------------------------------------
-- 4C.  First-Order Promo Attribution
--
--      Checks whether promo usage at acquisition correlates with higher
--      lifetime value — important for justifying new-customer incentive spend.
-- -----------------------------------------------------------------------------
WITH first_order_promo AS (
    SELECT
        o.account_id,
        o.order_id                                  AS first_order_id,
        (po.promo_id IS NOT NULL)                   AS first_order_had_promo
    FROM orders o
    -- Select only the first order per account
    JOIN (
        SELECT account_id, MIN(placed_at) AS first_order_ts
        FROM orders WHERE order_status != 'cancelled'
        GROUP BY account_id
    ) fo ON o.account_id = fo.account_id
         AND o.placed_at = fo.first_order_ts
    LEFT JOIN promo_orders po ON o.order_id = po.order_id
),
account_ltv AS (
    SELECT
        account_id,
        COUNT(order_id)             AS lifetime_orders,
        SUM(order_total_usd)        AS lifetime_gmv
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY account_id
)
SELECT
    fop.first_order_had_promo,
    COUNT(fop.account_id)                               AS accounts,
    ROUND(AVG(ltv.lifetime_orders), 1)                  AS avg_lifetime_orders,
    ROUND(AVG(ltv.lifetime_gmv), 2)                     AS avg_lifetime_gmv_usd,
    -- LTV uplift from promo at acquisition vs. organic
    ROUND(
        AVG(ltv.lifetime_gmv) FILTER (WHERE fop.first_order_had_promo)
      - AVG(ltv.lifetime_gmv) FILTER (WHERE NOT fop.first_order_had_promo), 2
    )                                                   AS promo_ltv_lift_usd
FROM first_order_promo fop
JOIN account_ltv ltv ON fop.account_id = ltv.account_id
GROUP BY fop.first_order_had_promo
ORDER BY fop.first_order_had_promo DESC;
