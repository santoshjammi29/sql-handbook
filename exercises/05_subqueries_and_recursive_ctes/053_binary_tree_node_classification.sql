-- ============================================================================
-- EXERCISE: 053_binary_tree_node_classification.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   LeetCode 608: Tree Node Classification. Given a binary tree table, classify
--   each node as 'Root', 'Inner', or 'Leaf'.
-- PROBLEM STATEMENT:
--   Root has p_id IS NULL; Leaf has no children; Inner has both parent and children.
--   Must be resilient to NULL in child subqueries (preventing 3VL collapse).
-- ============================================================================

DROP TABLE IF EXISTS tree_nodes;
CREATE TABLE tree_nodes (
    id INT PRIMARY KEY,
    p_id INT
);

INSERT INTO tree_nodes VALUES
(1, NULL),
(2, 1),
(3, 1),
(4, 2),
(5, 2);

-- --- [SOLUTION QUERY] ---
SELECT 
    id,
    CASE 
        WHEN p_id IS NULL THEN 'Root'
        WHEN id IN (SELECT p_id FROM tree_nodes WHERE p_id IS NOT NULL) THEN 'Inner'
        ELSE 'Leaf'
    END AS node_type
FROM tree_nodes
ORDER BY id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[node_type] = Root
