# Changelog

All notable changes to this project are documented here.

## [1.2.0] - 2026-06-14
### Added
- Snowflake compatibility note to README — queries port directly from PostgreSQL
- Documented dialect differences (ENUM → VARCHAR + CHECK, psql → snowsql)

### Improved
- README restructured with clearer section ordering
- Key findings section expanded with business context for each result

## [1.1.0] - 2026-06-07
### Added
- `.sqlfluff` configuration enforcing Mazur style guide (keywords UPPER, identifiers lower)
- `schema/00_setup.sql` with `\set analysis_date` parameter — eliminates hardcoded dates
- Composite B-tree indexes on `placed_at`, `caterer_id`, `account_id` with rationale comments

### Changed
- `05_account_retention.sql`: cohort period now uses `EXTRACT(YEAR/MONTH FROM AGE(...))` for
  cross-year cohort accuracy (previously broke on Jan→Dec transitions)
- `06_promo_effectiveness.sql`: ROI threshold changed from 3× to 5× to reflect platform economics

### Fixed
- `NULLIF` added to all division expressions to prevent divide-by-zero on new accounts

## [1.0.0] - 2026-06-01
### Added
- Initial schema: 6 tables normalised to 3NF with ENUM types and CHECK constraints
- 24-month synthetic dataset (20 accounts, 15 caterers, ~75 delivered orders)
- Four query sets: caterer performance, revenue analysis, account retention, promo effectiveness
- Window functions: LAG, LEAD, NTILE(4), PERCENT_RANK, rolling ROWS BETWEEN aggregates
- Pareto revenue concentration, cohort retention matrix, churn risk scoring
