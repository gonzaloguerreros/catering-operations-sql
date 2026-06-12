-- =============================================================================
-- 00_setup.sql
-- Purpose : Session-level configuration and runtime parameter declarations.
--           Execute this file before any other script in the project.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Analysis reference date
-- Change this value when refreshing the analysis against a newer data pull.
-- All dormancy / churn queries use :analysis_date rather than a hardcoded
-- literal so the queries remain correct across reporting cycles.
-- ---------------------------------------------------------------------------
\set analysis_date '2024-12-31'

-- Confirm the active search path (avoids schema-resolution surprises)
SHOW search_path;

-- Ensure the client encoding is UTF-8 (required for any Unicode caterer names)
SET client_encoding = 'UTF8';

-- ---------------------------------------------------------------------------
-- Development helper: show query execution plans inline
-- Uncomment during query tuning; leave commented in production.
-- ---------------------------------------------------------------------------
-- SET auto_explain.log_min_duration = 0;
-- LOAD 'auto_explain';
