-- =============================================================================
-- Query Set 6:  Conversion Funnel & Customer Lifetime Value
-- Author:       Gonzalo Guerreros
-- Purpose:      Measure funnel drop-off from signup to first order, and
--               estimate long-run customer value — the two numbers that drive
--               acquisition budget decisions at a B2B marketplace.
--
-- Snowflake-compatible: uses IFF, ZEROIFNULL, QUALIFY, DATE_TRUNC
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 6A.  Signup-to-First-Order Conversion Funnel
--
--      Tracks each account's progression through the activation funnel:
--        Stage 1: Account created
--        Stage 2: First login (browsing intent)
--        Stage 3: First quote or menu view (purchase intent)
--        Stage 4: First order placed (conversion)
--
--      The gap between stages pinpoints where accounts abandon.
--      Optimising the Stage 3 → 4 step (purchase intent → conversion)
--      is typically the highest-ROI intervention for B2B marketplaces.
-- -----------------------------------------------------------------------------
WITH funnel AS (
    SELECT
        ca.account_id,
        ca.company_name,
        ca.account_tier,
        ca.industry,
        ca.signup_date,

        -- First order metrics (NULL if never ordered)
        MIN(o.placed_at)::DATE                                        AS first_order_date,
        DATEDIFF('day', ca.signup_date, MIN(o.placed_at)::DATE)       AS days_to_first_order,

        -- Stage flags
        IFF(MIN(o.placed_at) IS NOT NULL, 1, 0)                      AS converted,

        -- Account tenure as of analysis date
        DATEDIFF('day', ca.signup_date, '2024-12-31'::DATE)           AS account_age_days
    FROM corporate_accounts ca
    LEFT JOIN orders o
           ON o.account_id = ca.account_id
          AND o.order_status != 'cancelled'
    GROUP BY
        ca.account_id, ca.company_name, ca.account_tier,
        ca.industry, ca.signup_date
),
cohort_funnel AS (
    SELECT
        DATE_TRUNC('month', signup_date)::DATE   AS signup_cohort,
        COUNT(*)                                  AS accounts_created,
        SUM(converted)                            AS accounts_converted,
        ROUND(SUM(converted) / COUNT(*) * 100, 1) AS conversion_rate_pct,

        -- Time-to-convert distribution
        ROUND(AVG(IFF(converted = 1, days_to_first_order, NULL)), 1)   AS avg_days_to_convert,
        PERCENTILE_CONT(0.50) WITHIN GROUP (
            ORDER BY IFF(converted = 1, days_to_first_order, NULL)
        )                                                               AS median_days_to_convert
    FROM funnel
    GROUP BY DATE_TRUNC('month', signup_date)::DATE
)
SELECT
    signup_cohort,
    accounts_created,
    accounts_converted,
    conversion_rate_pct,
    avg_days_to_convert,
    median_days_to_convert,
    -- Cohort quality index: higher = faster AND more conversions
    ROUND(conversion_rate_pct / NULLIF(avg_days_to_convert, 0), 2)  AS cohort_quality_index
FROM cohort_funnel
ORDER BY signup_cohort;


-- -----------------------------------------------------------------------------
-- 6B.  Customer Lifetime Value (LTV) by Acquisition Cohort
--
--      LTV = cumulative GMV an account generates over its lifetime.
--      Segmented by acquisition cohort to show whether newer accounts
--      are more or less valuable than earlier cohorts.
--
--      Key insight for budget planning: if 12-month LTV > CAC × 3,
--      growth investment is likely to generate positive ROI.
-- -----------------------------------------------------------------------------
WITH account_ltv AS (
    SELECT
        ca.account_id,
        ca.account_tier,
        ca.industry,
        DATE_TRUNC('month', ca.signup_date)::DATE        AS signup_cohort,

        -- Cumulative GMV at each milestone
        ZEROIFNULL(SUM(IFF(
            DATEDIFF('day', ca.signup_date, o.placed_at) <= 30,
            o.total_amount, NULL
        )))                                               AS ltv_30d,
        ZEROIFNULL(SUM(IFF(
            DATEDIFF('day', ca.signup_date, o.placed_at) <= 90,
            o.total_amount, NULL
        )))                                               AS ltv_90d,
        ZEROIFNULL(SUM(IFF(
            DATEDIFF('day', ca.signup_date, o.placed_at) <= 180,
            o.total_amount, NULL
        )))                                               AS ltv_180d,
        ZEROIFNULL(SUM(o.total_amount))                  AS ltv_lifetime,

        COUNT(DISTINCT o.order_id)                        AS total_orders
    FROM corporate_accounts ca
    LEFT JOIN orders o
           ON o.account_id = ca.account_id
          AND o.order_status != 'cancelled'
    GROUP BY
        ca.account_id, ca.account_tier, ca.industry,
        DATE_TRUNC('month', ca.signup_date)::DATE
)
SELECT
    signup_cohort,
    account_tier,
    COUNT(*)                              AS accounts,
    ROUND(AVG(ltv_30d),      0)          AS avg_ltv_30d,
    ROUND(AVG(ltv_90d),      0)          AS avg_ltv_90d,
    ROUND(AVG(ltv_180d),     0)          AS avg_ltv_180d,
    ROUND(AVG(ltv_lifetime), 0)          AS avg_ltv_lifetime,
    ROUND(AVG(total_orders), 1)          AS avg_orders,
    -- 90-day LTV-to-30-day LTV ratio shows expansion potential
    ROUND(AVG(ltv_90d) / NULLIF(AVG(ltv_30d), 0), 2) AS ltv_expansion_90d_vs_30d
FROM account_ltv
GROUP BY signup_cohort, account_tier
ORDER BY signup_cohort, account_tier;


-- -----------------------------------------------------------------------------
-- 6C.  Top Accounts by LTV with Churn Risk Signal
--
--      Identifies high-LTV accounts that show signs of disengagement.
--      These are the accounts a CSM should prioritise for outreach.
--
--      Churn risk signal: days since last order > 2× the account's own
--      average inter-order gap (personalised baseline, not a fixed threshold).
-- -----------------------------------------------------------------------------
WITH order_history AS (
    SELECT
        account_id,
        placed_at,
        total_amount,
        DATEDIFF('day',
            LAG(placed_at) OVER (PARTITION BY account_id ORDER BY placed_at),
            placed_at
        )                                           AS days_since_prev_order
    FROM orders
    WHERE order_status != 'cancelled'
),
account_summary AS (
    SELECT
        ca.account_id,
        ca.company_name,
        ca.account_tier,
        ca.industry,

        ZEROIFNULL(SUM(oh.total_amount))            AS lifetime_gmv,
        COUNT(DISTINCT oh.placed_at)                AS lifetime_orders,
        MAX(oh.placed_at)::DATE                     AS last_order_date,
        DATEDIFF('day', MAX(oh.placed_at)::DATE,
                 '2024-12-31'::DATE)                AS days_inactive,
        ROUND(AVG(oh.days_since_prev_order), 0)     AS avg_order_gap_days
    FROM corporate_accounts ca
    LEFT JOIN order_history oh ON oh.account_id = ca.account_id
    GROUP BY ca.account_id, ca.company_name, ca.account_tier, ca.industry
)
SELECT
    account_id,
    company_name,
    account_tier,
    industry,
    lifetime_gmv,
    lifetime_orders,
    last_order_date,
    days_inactive,
    avg_order_gap_days,
    -- Personalised churn signal: inactive for more than 2× their own reorder cadence
    IFF(
        days_inactive > avg_order_gap_days * 2
        AND lifetime_orders >= 3,            -- exclude one-timers: less reliable signal
        'AT RISK',
        'HEALTHY'
    )                                        AS churn_signal,
    -- Urgency score: higher = more valuable + more overdue
    ROUND(lifetime_gmv * (days_inactive / NULLIF(avg_order_gap_days, 0)), 0)
                                             AS outreach_priority_score
FROM account_summary
WHERE lifetime_gmv > 0
-- Surface only the highest-value at-risk accounts for CSM action
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY IFF(days_inactive > avg_order_gap_days * 2, 'AT RISK', 'HEALTHY')
    ORDER BY lifetime_gmv DESC
) <= 20
ORDER BY churn_signal DESC, outreach_priority_score DESC;
