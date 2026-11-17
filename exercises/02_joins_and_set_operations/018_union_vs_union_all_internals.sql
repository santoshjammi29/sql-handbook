-- ============================================================================
-- EXERCISE: 018_union_vs_union_all_internals.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Consolidating transactional logs across web and mobile channels. Using UNION
--   incurs an unneeded multi-stage sort across millions of rows when rows are
--   already known to be disjoint.
-- PROBLEM STATEMENT:
--   Demonstrate when UNION is needed for deduplication versus when UNION ALL
--   is strictly required for performance and stream preservation.
-- ============================================================================

DROP TABLE IF EXISTS web_clicks;
DROP TABLE IF EXISTS mobile_clicks;

CREATE TABLE web_clicks (click_id INT, user_id INT, page VARCHAR(50));
CREATE TABLE mobile_clicks (click_id INT, user_id INT, page VARCHAR(50));

INSERT INTO web_clicks VALUES (1, 101, 'home'), (2, 102, 'cart'), (3, 103, 'checkout');
INSERT INTO mobile_clicks VALUES (3, 103, 'checkout'), (4, 104, 'search'), (5, 105, 'profile');

-- --- [SOLUTION QUERY] ---
-- UNION ALL preserves every raw event without sort overhead
SELECT 'WEB' AS channel, click_id, user_id, page FROM web_clicks
UNION ALL
SELECT 'MOBILE' AS channel, click_id, user_id, page FROM mobile_clicks
ORDER BY click_id ASC, channel ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[user_id] = 101
