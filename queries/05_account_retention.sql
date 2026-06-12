-- =============================================================================
-- Query Set 3:  Account Retention & Order Frequency Analysis
-- Author:       Gonzalo Guerreros
-- Purpose:      Measure repeat ordering behaviour and identify accounts at
--               churn risk.  Retention is the primary growth lever for a
--               B2B marketplace once the top-of-funnel is healthy.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 3A.  Account-Level Ordering Cadence
--
--      Calculates days between consecutive orders per account using LAG.
--      Accounts with growing inter-order gaps are leading churn indicators.
-- -----------------------------------------------------------------------------
WITH order_gaps AS (
    SELECT
        o.account_id,
        ca.company_name,
        ca.account_tier,
        o.order_id,
        o.placed_at,
        -- Days since this account's previous order
        placed_at::DATE - LAG(placed_at::DATE) OVER (
            PARTITION BY o.account_id
            ORDER BY o.placed_at
        )                                            AS days_since_last_order,
        -- Order sequence number per account
        ROW_NUMBER() OVER (
            PARTITION BY o.account_id
            ORDER BY o.placed_at
        )                                            AS order_sequence
    FROM orders o
    JOIN corporate_accounts ca ON o.account_id = ca.account_id
    WHERE o.order_status != 'cancelled'
)
SELECT
    account_id,
    company_name,
    account_tier,
    COUNT(order_id)                              AS lifetime_orders,
    MIN(placed_at)::DATE                         AS first_order_date,
    MAX(placed_at)::DATE                         AS most_recent_order,
    -- Average gap signals expected reorder window
    ROUND(AVG(days_since_last_order), 0)         AS avg_days_between_orders,
    -- Most recent gap vs. average — positive delta = slowing down
    MAX(placed_at)::DATE - MAX(placed_at - INTERVAL '1 day')::DATE AS latest_gap,
    -- Days since last order as of analysis date (2024-12-31)
    ('2024-12-31'::DATE - MAX(placed_at)::DATE)  AS days_since_last_order_eod
FROM order_gaps
GROUP BY account_id, company_name, account_tier
ORDER BY days_since_last_order_eod DESC;


-- -----------------------------------------------------------------------------
-- 3B.  Monthly Cohort Retention Table
--
--      Each row is an (acquisition_month, activity_month) pair showing how
--      many accounts from a given cohort placed at least one order in each
--      subsequent month.  The standard format for a retention heatmap.
-- -----------------------------------------------------------------------------
WITH first_orders AS (
    -- Acquisition month = month of the account's very first order
    SELECT
        account_id,
        DATE_TRUNC('month', MIN(placed_at)) AS cohort_month
    FROM orders
    WHERE order_status != 'cancelled'
    GROUP BY account_id
),
activity AS (
    -- All months in which each account placed at least one order
    SELECT DISTINCT
        account_id,
        DATE_TRUNC('month', placed_at)      AS activity_month
    FROM orders
    WHERE order_status != 'cancelled'
),
cohort_activity AS (
    SELECT
        f.cohort_month,
        a.activity_month,
        COUNT(DISTINCT f.account_id)        AS active_accounts,
        -- Period index: 0 = acquisition month, 1 = one month later, etc.
        EXTRACT(
            YEAR FROM AGE(a.activity_month, f.cohort_month)
        ) * 12 +
        EXTRACT(
            MONTH FROM AGE(a.activity_month, f.cohort_month)
        )                                   AS period_number
    FROM first_orders f
    JOIN activity a ON f.account_id = a.account_id
    WHERE a.activity_month >= f.cohort_month
    GROUP BY f.cohort_month, a.activity_month
),
cohort_sizes AS (
    -- Denominator for retention rate: accounts acquired each month
    SELECT cohort_month, active_accounts AS cohort_size
    FROM cohort_activity
    WHERE period_number = 0
)
SELECT
    ca.cohort_month,
    cs.cohort_size,
    ca.activity_month,
    ca.period_number,
    ca.active_accounts,
    ROUND(
        100.0 * ca.active_accounts / cs.cohort_size, 1
    )                                       AS retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month, ca.period_number;


-- -----------------------------------------------------------------------------
-- 3C.  Churn Risk Flagging
--
--      Accounts that have gone silent for longer than 1.5x their historical
--      average inter-order gap are flagged as "At Risk."  Outputs a prioritised
--      list for the Account Management team to action.
-- -----------------------------------------------------------------------------
WITH account_cadence AS (
    SELECT
        o.account_id,
        ca.company_name,
        ca.account_tier,
        ca.industry,
        COUNT(o.order_id)                                       AS lifetime_orders,
        ROUND(AVG(
            placed_at::DATE - LAG(placed_at::DATE) OVER (
                PARTITION BY o.account_id ORDER BY o.placed_at
            )
        ), 0)                                                   AS avg_days_between_orders,
        MAX(o.placed_at)::DATE                                  AS last_order_date,
        SUM(o.order_total_usd)                                  AS lifetime_gmv
    FROM orders o
    JOIN corporate_accounts ca ON o.account_id = ca.account_id
    WHERE o.order_status != 'cancelled'
    GROUP BY o.account_id, ca.company_name, ca.account_tier, ca.industry
)
SELECT
    account_id,
    company_name,
    account_tier,
    industry,
    lifetime_orders,
    lifetime_gmv,
    last_order_date,
    avg_days_between_orders,
    ('2024-12-31'::DATE - last_order_date)                      AS days_dormant,
    -- Risk tier based on dormancy relative to expected cadence
    CASE
        WHEN ('2024-12-31'::DATE - last_order_date) > avg_days_between_orders * 2.0
            THEN 'High Risk'
        WHEN ('2024-12-31'::DATE - last_order_date) > avg_days_between_orders * 1.5
            THEN 'Medium Risk'
        ELSE 'Active'
    END                                                         AS churn_risk
FROM account_cadence
WHERE lifetime_orders > 1   -- single-order accounts need separate treatment
ORDER BY
    CASE churn_risk WHEN 'High Risk' THEN 1 WHEN 'Medium Risk' THEN 2 ELSE 3 END,
    lifetime_gmv DESC;       -- within risk tier, prioritise highest-value accounts
