-- ============================================================================
-- EXERCISE: 053_binary_tree_node_classification.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Algorithmic Systems Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Binary Tree Node Structural Classification.
--   Classifying tree nodes into Root, Inner, and Leaf based on parent/child relationships.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 053 binary tree node classification.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 053 binary tree node classification.
-- ============================================================================

DROP TABLE IF EXISTS binary_tree_nodes;

CREATE TABLE binary_tree_nodes (
    node_id INT PRIMARY KEY,
    parent_id INT -- NULL if Root
);

INSERT INTO binary_tree_nodes VALUES
(1, 2),
(3, 2),
(6, 8),
(9, 8),
(2, 5),
(8, 5),
(5, NULL); -- Root

-- --- [SOLUTION QUERY] ---
-- Classifying nodes:
-- Root: parent_id IS NULL
-- Inner: has a parent AND appears as a parent to other nodes
-- Leaf: has a parent AND does NOT appear as a parent to other nodes
SELECT 
    node_id,
    CASE 
        WHEN parent_id IS NULL THEN 'ROOT'
        WHEN node_id IN (SELECT DISTINCT parent_id FROM binary_tree_nodes WHERE parent_id IS NOT NULL) THEN 'INNER'
        ELSE 'LEAF'
    END AS node_classification
FROM binary_tree_nodes
ORDER BY node_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 7
-- ASSERT: COL[node_id] = 1
