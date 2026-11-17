-- ============================================================================
-- EXERCISE: 093_delta_merge_into_multi_condition_matching.sql
-- MODULE:   09_mpp_and_cloud_warehouses
-- LEVEL:    Advanced
-- ENGINES:  Databricks Spark SQL, Snowflake, BigQuery, PostgreSQL, DuckDB, SQLite
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Modern Lakehouse Upsert: Incoming CDC stream contains new inserts, updates,
--   and soft deletes. Standard ANSI MERGE INTO applies multiple WHEN MATCHED
--   clauses to delete or update rows and WHEN NOT MATCHED to insert rows.
-- PROBLEM STATEMENT:
--   Emulate atomic multi-condition MERGE upsert logic.
-- ============================================================================

DROP TABLE IF EXISTS cdc_target;
DROP TABLE IF EXISTS cdc_incoming;

CREATE TABLE cdc_target (id INT PRIMARY KEY, val VARCHAR(50), is_deleted INT);
CREATE TABLE cdc_incoming (id INT PRIMARY KEY, val VARCHAR(50), is_deleted INT);

INSERT INTO cdc_target VALUES (1, 'Old Val 1', 0), (2, 'Old Val 2', 0);
INSERT INTO cdc_incoming VALUES (1, 'Updated Val 1', 0), (2, 'Delete Val 2', 1), (3, 'New Val 3', 0);

-- Emulate MERGE: Delete where is_deleted = 1
DELETE FROM cdc_target WHERE id IN (SELECT id FROM cdc_incoming WHERE is_deleted = 1);
-- Update matching
INSERT INTO cdc_target (id, val, is_deleted)
SELECT id, val, is_deleted FROM cdc_incoming WHERE is_deleted = 0
ON CONFLICT(id) DO UPDATE SET val = EXCLUDED.val, is_deleted = EXCLUDED.is_deleted;

-- --- [SOLUTION QUERY] ---
SELECT id, val, is_deleted FROM cdc_target ORDER BY id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[val] = Updated Val 1
