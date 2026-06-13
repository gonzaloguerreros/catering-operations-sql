# Corporate Catering Operations Analysis — PostgreSQL

**Role context:** Product Analyst portfolio project demonstrating SQL proficiency across schema design, performance analytics, retention measurement, and promotional ROI evaluation in a B2B catering marketplace context.

---

## Business Context

A corporate catering marketplace (modelled after platforms like ezCater) connects corporate accounts with local caterers for office meals, working lunches, and event catering. This analysis covers **24 months of operations (Jan 2023 – Dec 2024)** across 20 corporate accounts and 15 caterers in the Boston metro area.

The four analytical themes reflect the questions a Product Analyst at a catering marketplace is expected to answer week-over-week:

| # | Theme | Business Question |
|---|-------|------------------|
| 1 | Caterer Performance | Which suppliers are reliable enough to be featured, and which need a PIP? |
| 2 | Revenue & GMV | Where is growth coming from, and which accounts are driving it? |
| 3 | Account Retention | Which accounts are at churn risk, and how do cohorts behave over time? |
| 4 | Promo Effectiveness | Are our campaigns generating incremental GMV or just subsidising existing demand? |

---

## Schema Design

```
corporate_accounts ──< orders >── caterers
                         │
                    order_items
                    delivery_events
                    promo_orders >── promotions
```

Six tables, normalised to 3NF. ENUMs enforce domain integrity on `order_status`, `delivery_tier`, and `account_tier`. Indexes are placed on high-cardinality filter columns (`placed_at`, `caterer_id`, `account_id`) to reflect real query patterns.

**Full schema:** [`schema/01_create_tables.sql`](schema/01_create_tables.sql)  
**Seed data (24-month synthetic dataset):** [`data/02_seed_data.sql`](data/02_seed_data.sql)

---

## Query Files

### [`queries/03_caterer_performance.sql`](queries/03_caterer_performance.sql)
- **1A. Caterer Scorecard** — GMV, average order value, strict and 15-min-grace OTD rates
- **1B. Monthly OTD Trend** — Rolling 3-month on-time delivery average per caterer using `ROWS BETWEEN` window frame
- **1C. Composite Performance Tier** — `NTILE(4)` ranking weighted across GMV, OTD, and rating; outputs Platinum / Gold / Silver / Needs Improvement badges

### [`queries/04_revenue_analysis.sql`](queries/04_revenue_analysis.sql)
- **2A. Monthly GMV with MoM/YoY Growth** — `LAG` window functions for growth rates; cumulative GMV with `UNBOUNDED PRECEDING`
- **2B. Revenue Concentration (Pareto)** — Running cumulative GMV share to identify the accounts comprising 80% of platform revenue
- **2C. GMV by Account Tier & Quarter** — Orders-per-active-account engagement metric by tier over time

### [`queries/05_account_retention.sql`](queries/05_account_retention.sql)
- **3A. Ordering Cadence per Account** — `LAG`-based inter-order gap calculation; dormancy measurement
- **3B. Monthly Cohort Retention Table** — Standard cohort × period matrix suitable for heatmap visualisation; ready to import into Tableau or Sigma
- **3C. Churn Risk Flagging** — Dormancy-relative-to-cadence scoring with High / Medium / Active risk tiers; sorted by lifetime GMV for AM prioritisation

### [`queries/06_promo_effectiveness.sql`](queries/06_promo_effectiveness.sql)
- **4A. Promo vs. Non-Promo AOV** — Side-by-side comparison by account tier; discount rate as a margin erosion metric
- **4B. Campaign ROI Summary** — GMV-per-discount-dollar with a 5× ROI threshold flag
- **4C. First-Order Promo Attribution** — LTV comparison for promo-acquired vs. organic accounts using `FILTER` aggregate syntax

---

## SQL Techniques Demonstrated

| Technique | Where Used |
|-----------|-----------|
| CTEs (`WITH`) | All query files — multi-step transformations without nested subqueries |
| Window functions (`LAG`, `LEAD`, `ROW_NUMBER`, `NTILE`, `PERCENT_RANK`) | `03_caterer_performance`, `04_revenue_analysis`, `05_account_retention` |
| Rolling aggregates (`ROWS BETWEEN`) | `03_caterer_performance` 1B |
| `FILTER` clause on aggregates | `06_promo_effectiveness` 4C |
| Conditional aggregation (`CASE WHEN` inside `SUM`) | All files |
| `NULLIF` / `COALESCE` for safe division | All files |
| ENUM types + CHECK constraints | `01_create_tables` |
| Composite indexing strategy | `01_create_tables` — comments explain each index rationale |
| `EXTRACT(EPOCH FROM ...)` for duration math | `03_caterer_performance` |

---

## Snowflake Compatibility

These queries were written and tested in **PostgreSQL 15**, but are directly portable to **Snowflake** — the syntax for CTEs, window functions (`LAG`, `NTILE`, `PERCENT_RANK`), and conditional aggregation is identical across both dialects. The main difference is infrastructure: Snowflake replaces `psql` with Snowsight or `snowsql`, and `ENUM` types are replaced with `VARCHAR` with `CHECK` constraints. All business logic and analytical patterns apply unchanged.

---

## How to Run

**Requirements:** PostgreSQL 15+

```bash
# 1. Create a fresh database
createdb catering_ops

# 2. Load schema
psql -d catering_ops -f schema/01_create_tables.sql

# 3. Seed data
psql -d catering_ops -f data/02_seed_data.sql

# 4. Run any query file
psql -d catering_ops -f queries/03_caterer_performance.sql
```

Or connect via any PostgreSQL client (pgAdmin, DBeaver, TablePlus) and run the files in order.

---

## Key Findings (on synthetic data)

- **Bella Cucina Events** and **Mediterranean Table** hold Platinum tier status — highest composite scores on GMV, OTD, and rating.
- **Enterprise accounts** (Axiom, Kinetic Health, NorthPoint Capital) represent ~65% of platform GMV despite being 15% of account count — a classic Pareto concentration.
- **Cohort retention** drops sharply after month 2 for SMB accounts, while enterprise accounts show stable reorder cadence — suggesting differentiated retention strategies are warranted.
- The **ENT100** enterprise promo achieved the highest GMV-per-discount-dollar ratio; **WELCOME25** showed weak LTV correlation, suggesting new-account discounts alone do not drive long-term retention.

---

*Dataset is fully synthetic. All company names, figures, and operational metrics are fictitious and created for portfolio demonstration purposes.*
