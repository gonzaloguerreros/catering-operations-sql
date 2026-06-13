-- =============================================================================
-- Query Set 5:  A/B Experiment Analysis in Snowflake
-- Author:       Gonzalo Guerreros
-- Purpose:      Demonstrate Snowflake-specific SQL patterns for pulling and
--               analysing A/B test data at a B2B catering marketplace.
--               These patterns reflect how a Product Analyst would work in
--               a Snowflake + dbt environment (ezCater's actual stack).
-- Engine:       Snowflake (compatible with most standard SQL warehouses)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- KEY SNOWFLAKE DIFFERENCES FROM POSTGRESQL
-- 1. QUALIFY  — filters window function results inline (no subquery needed)
-- 2. IFF()    — single-condition IF expression (shorter than CASE WHEN)
-- 3. ZEROIFNULL() / NULLIFZERO() — handle nulls in calculations
-- 4. DATE_TRUNC works the same; DATEDIFF syntax differs slightly
-- 5. FLATTEN / LATERAL JOIN — for semi-structured (JSON/VARIANT) data
-- 6. $1, $2   — column references in stage queries
-- 7. SAMPLE() — built-in random sampling (useful for large tables)
-- -----------------------------------------------------------------------------


-- =============================================================================
-- PART A: PULLING EXPERIMENT DATA FROM THE WAREHOUSE
-- Typical pattern: experiment assignments live in one table, outcomes in another
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A1. Get accounts enrolled in an experiment with their variant assignment
--     Uses QUALIFY to keep only the first assignment per account
--     (handles cases where the same account appears multiple times due to
--      logging retries — a common data quality issue)
-- -----------------------------------------------------------------------------
SELECT
    ea.account_id,
    ea.experiment_name,
    ea.variant,                                      -- 'control' or 'treatment'
    ea.assigned_at::DATE                             AS assignment_date,
    ca.account_tier,
    ca.industry,
    ca.city
FROM experiment_assignments ea
JOIN corporate_accounts ca
  ON ea.account_id = ca.account_id
WHERE ea.experiment_name = 'SPRING20'
  AND ea.assigned_at >= '2024-03-01'
  AND ea.assigned_at <  '2024-06-01'
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ea.account_id                       -- one row per account
    ORDER BY ea.assigned_at                          -- keep the earliest assignment
) = 1;


-- -----------------------------------------------------------------------------
-- A2. Join experiment assignments to outcome metrics
--     The QUALIFY pattern avoids a self-join or subquery
-- -----------------------------------------------------------------------------
WITH experiment_cohort AS (
    -- Pull clean assignment data (one row per account, first assignment)
    SELECT
        account_id,
        variant,
        assigned_at::DATE AS enrollment_date
    FROM experiment_assignments
    WHERE experiment_name = 'SPRING20'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY assigned_at) = 1
),
order_outcomes AS (
    -- First order placed within 30 days of enrollment (conversion signal)
    SELECT
        o.account_id,
        MIN(o.placed_at)::DATE                       AS first_order_date,
        MIN(o.order_total_usd)                       AS first_order_value,
        DATEDIFF('day', ec.enrollment_date, MIN(o.placed_at)::DATE)
                                                     AS days_to_first_order
    FROM orders o
    JOIN experiment_cohort ec
      ON o.account_id = ec.account_id
     AND o.placed_at  >= ec.enrollment_date            -- only orders AFTER enrollment
     AND DATEDIFF('day', ec.enrollment_date, o.placed_at) <= 30
    WHERE o.order_status = 'delivered'
    GROUP BY o.account_id, ec.enrollment_date
),
gmv_60d AS (
    -- Total GMV in 60-day window post-enrollment
    SELECT
        o.account_id,
        SUM(o.order_total_usd)                       AS gmv_60d,
        COUNT(o.order_id)                            AS orders_60d
    FROM orders o
    JOIN experiment_cohort ec
      ON o.account_id = ec.account_id
    WHERE o.order_status = 'delivered'
      AND DATEDIFF('day', ec.enrollment_date, o.placed_at) BETWEEN 0 AND 60
    GROUP BY o.account_id
)
SELECT
    ec.account_id,
    ec.variant,
    ec.enrollment_date,
    ca.account_tier,
    ca.industry,
    -- Conversion (1/0)
    IFF(oo.account_id IS NOT NULL, 1, 0)             AS converted,
    oo.first_order_date,
    oo.days_to_first_order,
    ZEROIFNULL(oo.first_order_value)                 AS first_order_value,
    -- 60-day GMV (0 for non-converters)
    ZEROIFNULL(g.gmv_60d)                            AS gmv_60d,
    ZEROIFNULL(g.orders_60d)                         AS orders_60d
FROM experiment_cohort ec
JOIN corporate_accounts ca ON ec.account_id = ca.account_id
LEFT JOIN order_outcomes  oo ON ec.account_id = oo.account_id
LEFT JOIN gmv_60d         g  ON ec.account_id = g.account_id;


-- =============================================================================
-- PART B: EXPERIMENT PERFORMANCE ANALYSIS
-- The queries you run to assess whether the experiment worked
-- =============================================================================

-- -----------------------------------------------------------------------------
-- B1. Primary metric: Conversion rate by variant
--     (What proportion of accounts placed a first order within 30 days?)
-- -----------------------------------------------------------------------------
SELECT
    variant,
    COUNT(*)                                         AS n_accounts,
    SUM(converted)                                   AS conversions,
    ROUND(AVG(converted) * 100, 2)                   AS conversion_rate_pct,
    -- Confidence interval (Wilson score — better than normal approximation)
    -- Note: in Snowflake you'd typically compute CIs in Python after pulling this
    ROUND(STDDEV(converted) / SQRT(COUNT(*)) * 1.96 * 100, 2) AS margin_of_error_pct
FROM experiment_results                              -- replace with your CTE above
GROUP BY variant
ORDER BY variant;


-- -----------------------------------------------------------------------------
-- B2. Secondary metrics: GMV comparison by variant
-- -----------------------------------------------------------------------------
SELECT
    variant,
    COUNT(*)                                         AS n_accounts,
    -- First-order GMV (converters only)
    COUNT(CASE WHEN converted = 1 THEN 1 END)        AS n_converters,
    ROUND(AVG(CASE WHEN converted = 1 THEN first_order_value END), 2)
                                                     AS avg_first_order_gmv,
    -- 60-day GMV (all accounts including zeros)
    ROUND(AVG(gmv_60d), 2)                           AS avg_gmv_60d,
    ROUND(MEDIAN(gmv_60d), 2)                        AS median_gmv_60d,    -- Snowflake has MEDIAN()
    ROUND(STDDEV(gmv_60d), 2)                        AS stddev_gmv_60d,
    SUM(gmv_60d)                                     AS total_gmv_60d
FROM experiment_results
GROUP BY variant
ORDER BY variant;


-- =============================================================================
-- PART C: DATA CUTS — SEGMENT ANALYSIS
-- "What about just for power users?" — the question every PM asks
-- =============================================================================

-- -----------------------------------------------------------------------------
-- C1. Results by account tier (SMB vs. mid-market vs. enterprise)
--     Answers: does the promo work differently for large vs. small accounts?
-- -----------------------------------------------------------------------------
SELECT
    account_tier,
    variant,
    COUNT(*)                                         AS n_accounts,
    ROUND(AVG(converted) * 100, 2)                   AS conversion_rate_pct,
    ROUND(AVG(gmv_60d), 2)                           AS avg_gmv_60d,
    -- Lift vs. control within each tier (using window function)
    ROUND(
        AVG(converted) * 100 -
        AVG(AVG(converted) * 100) OVER (PARTITION BY account_tier),
    2)                                               AS lift_vs_control_pp
FROM experiment_results
GROUP BY account_tier, variant
ORDER BY account_tier, variant;


-- -----------------------------------------------------------------------------
-- C2. Power user segment cut
--     Power users = accounts with >= 4 orders in the 90 days before enrollment
--     This is the segment cut most likely to give a cleaner signal because
--     power users have established ordering behaviour — less noise
-- -----------------------------------------------------------------------------
WITH power_users AS (
    -- Define power users from pre-experiment behaviour
    SELECT
        account_id,
        COUNT(order_id)                              AS orders_pre_experiment
    FROM orders
    WHERE placed_at >= DATEADD('day', -90, '2024-03-01')   -- 90 days before launch
      AND placed_at <  '2024-03-01'
      AND order_status = 'delivered'
    GROUP BY account_id
    HAVING COUNT(order_id) >= 4                      -- threshold: 4+ orders = power user
)
SELECT
    IFF(pu.account_id IS NOT NULL, 'Power User', 'Regular User') AS user_segment,
    er.variant,
    COUNT(*)                                         AS n_accounts,
    ROUND(AVG(er.converted) * 100, 2)                AS conversion_rate_pct,
    ROUND(AVG(er.gmv_60d), 2)                        AS avg_gmv_60d,
    ROUND(AVG(pu.orders_pre_experiment), 1)          AS avg_pre_exp_orders
FROM experiment_results er
LEFT JOIN power_users pu ON er.account_id = pu.account_id
GROUP BY IFF(pu.account_id IS NOT NULL, 'Power User', 'Regular User'), er.variant
ORDER BY user_segment, er.variant;


-- -----------------------------------------------------------------------------
-- C3. New vs. established accounts
--     New accounts (< 60 days old at enrollment) may respond differently
--     to a first-order discount than established accounts
-- -----------------------------------------------------------------------------
SELECT
    CASE
        WHEN DATEDIFF('day', ca.created_at, er.enrollment_date) < 60
            THEN 'New Account (< 60 days)'
        WHEN DATEDIFF('day', ca.created_at, er.enrollment_date) < 180
            THEN 'Growing Account (60–180 days)'
        ELSE 'Established Account (180+ days)'
    END                                              AS account_age_segment,
    er.variant,
    COUNT(*)                                         AS n_accounts,
    ROUND(AVG(er.converted) * 100, 2)                AS conversion_rate_pct,
    ROUND(AVG(er.gmv_60d), 2)                        AS avg_gmv_60d
FROM experiment_results er
JOIN corporate_accounts ca ON er.account_id = ca.account_id
GROUP BY account_age_segment, er.variant
ORDER BY account_age_segment, er.variant;


-- =============================================================================
-- PART D: SAMPLE RATIO MISMATCH CHECK (run before looking at outcomes)
-- If the split deviates from 50/50, the randomisation pipeline may be broken
-- =============================================================================
SELECT
    variant,
    COUNT(*)                                         AS n_enrolled,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_total,
    -- Flag if more than 2 percentage points from expected 50%
    IFF(ABS(COUNT(*) / SUM(COUNT(*)) OVER () - 0.5) > 0.02,
        '⚠ SRM DETECTED', 'OK')                     AS srm_status
FROM experiment_results
GROUP BY variant;


-- =============================================================================
-- PART E: GUARDRAIL METRIC — Cancellation Rate
-- Make sure the promo doesn't accidentally increase cancellations
-- (e.g., customers ordering more than they intended and cancelling)
-- =============================================================================
SELECT
    er.variant,
    COUNT(o.order_id)                                AS total_orders,
    SUM(IFF(o.order_status = 'cancelled', 1, 0))     AS cancellations,
    ROUND(
        SUM(IFF(o.order_status = 'cancelled', 1, 0))
        / NULLIFZERO(COUNT(o.order_id)) * 100, 2
    )                                                AS cancellation_rate_pct
FROM experiment_results er
JOIN orders o
  ON er.account_id = o.account_id
 AND o.placed_at >= er.enrollment_date
 AND DATEDIFF('day', er.enrollment_date, o.placed_at) <= 60
GROUP BY er.variant
ORDER BY er.variant;
