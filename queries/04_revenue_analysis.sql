-- =============================================================================
-- Query Set 2:  Revenue & GMV Analysis
-- Author:       Gonzalo Guerreros
-- Purpose:      Break down platform revenue by time period, account tier,
--               and geography.  Surfaces growth trends and identifies the
--               accounts driving disproportionate share of GMV.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 2A.  Monthly GMV with MoM and YoY Growth Rates
--
--      LAG window functions avoid self-joins and keep the query readable.
--      This output feeds the executive revenue dashboard.
-- -----------------------------------------------------------------------------
WITH monthly_gmv AS (
    SELECT
        DATE_TRUNC('month', placed_at)   AS order_month,
        COUNT(*)                         AS order_count,
        SUM(order_total_usd)             AS gmv_usd,
        SUM(discount_usd)                AS total_discounts_usd,
        -- Net revenue after discounts
        SUM(order_total_usd - discount_usd) AS net_revenue_usd
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY DATE_TRUNC('month', placed_at)
)
SELECT
    order_month,
    order_count,
    gmv_usd,
    total_discounts_usd,
    net_revenue_usd,
    -- Month-over-month GMV growth
    ROUND(
        100.0 * (gmv_usd - LAG(gmv_usd) OVER (ORDER BY order_month))
        / NULLIF(LAG(gmv_usd) OVER (ORDER BY order_month), 0), 1
    )                                    AS mom_growth_pct,
    -- Year-over-year GMV growth (12-month lag)
    ROUND(
        100.0 * (gmv_usd - LAG(gmv_usd, 12) OVER (ORDER BY order_month))
        / NULLIF(LAG(gmv_usd, 12) OVER (ORDER BY order_month), 0), 1
    )                                    AS yoy_growth_pct,
    -- Cumulative GMV — useful for annual run-rate tracking
    SUM(gmv_usd) OVER (
        ORDER BY order_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                    AS cumulative_gmv_usd
FROM monthly_gmv
ORDER BY order_month;


-- -----------------------------------------------------------------------------
-- 2B.  Revenue Concentration — Pareto / 80-20 Analysis
--
--      Identifies what percentage of accounts drive 80% of platform GMV.
--      Critical for deciding where to invest account management resources.
-- -----------------------------------------------------------------------------
WITH account_gmv AS (
    SELECT
        ca.account_id,
        ca.company_name,
        ca.account_tier,
        ca.industry,
        SUM(o.order_total_usd)               AS total_gmv,
        COUNT(o.order_id)                    AS total_orders,
        MIN(o.placed_at)::DATE               AS first_order_date,
        MAX(o.placed_at)::DATE               AS last_order_date
    FROM corporate_accounts ca
    JOIN orders o ON ca.account_id = o.account_id
    WHERE o.order_status = 'delivered'
    GROUP BY ca.account_id, ca.company_name, ca.account_tier, ca.industry
),
ranked AS (
    SELECT
        *,
        -- Cumulative GMV share — stops at the account that crosses 80%
        ROUND(
            100.0 * SUM(total_gmv) OVER (ORDER BY total_gmv DESC)
            / SUM(total_gmv) OVER (), 1
        )                                    AS cumulative_gmv_pct,
        ROUND(
            100.0 * total_gmv / SUM(total_gmv) OVER (), 2
        )                                    AS gmv_share_pct
    FROM account_gmv
)
SELECT
    company_name,
    account_tier,
    industry,
    total_orders,
    total_gmv,
    gmv_share_pct,
    cumulative_gmv_pct,
    -- Flag accounts in the "vital few" that make up 80% of GMV
    CASE WHEN cumulative_gmv_pct <= 80 THEN 'Top 80% GMV' ELSE 'Long Tail' END AS gmv_segment
FROM ranked
ORDER BY total_gmv DESC;


-- -----------------------------------------------------------------------------
-- 2C.  GMV by Account Tier and Quarter
--
--      Helps understand whether growth is coming from new SMB acquisition or
--      expansion within enterprise accounts — two very different strategies.
-- -----------------------------------------------------------------------------
SELECT
    ca.account_tier,
    DATE_TRUNC('quarter', o.placed_at)   AS order_quarter,
    COUNT(DISTINCT o.account_id)         AS active_accounts,
    COUNT(o.order_id)                    AS total_orders,
    SUM(o.order_total_usd)               AS gmv_usd,
    ROUND(AVG(o.order_total_usd), 2)     AS avg_order_value_usd,
    -- Orders per active account — signals engagement depth
    ROUND(
        COUNT(o.order_id)::NUMERIC
        / NULLIF(COUNT(DISTINCT o.account_id), 0), 2
    )                                    AS orders_per_account
FROM orders o
JOIN corporate_accounts ca ON o.account_id = ca.account_id
WHERE o.order_status = 'delivered'
GROUP BY ca.account_tier, DATE_TRUNC('quarter', o.placed_at)
ORDER BY order_quarter, ca.account_tier;
