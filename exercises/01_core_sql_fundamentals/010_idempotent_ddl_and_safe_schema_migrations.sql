-- ============================================================================
-- EXERCISE: 010_idempotent_ddl_and_safe_schema_migrations.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Continuous deployment CI/CD pipelines run database migration scripts on
--   every deployment. If a migration script is re-run against an existing database,
--   it must be idempotent (must not throw 'table already exists' or fail).
-- PROBLEM STATEMENT:
--   Create an idempotent DDL migration script with table creation guards,
--   index checks, and safe default value population.
-- ============================================================================

CREATE TABLE IF NOT EXISTS system_feature_flags (
    feature_key VARCHAR(50) PRIMARY KEY,
    is_enabled BOOLEAN DEFAULT FALSE,
    rollout_percentage INT DEFAULT 0
);

INSERT INTO system_feature_flags (feature_key, is_enabled, rollout_percentage)
VALUES ('dark_mode', 1, 100)
ON CONFLICT(feature_key) DO UPDATE SET
    is_enabled = EXCLUDED.is_enabled,
    rollout_percentage = EXCLUDED.rollout_percentage;

-- --- [SOLUTION QUERY] ---
SELECT 
    feature_key,
    is_enabled,
    rollout_percentage
FROM system_feature_flags
WHERE feature_key = 'dark_mode';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[feature_key] = dark_mode
