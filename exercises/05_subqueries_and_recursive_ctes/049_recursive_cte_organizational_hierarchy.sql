-- ============================================================================
-- EXERCISE: 049_recursive_cte_organizational_hierarchy.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   HR organizational reporting: generate the complete reporting tree starting
--   from the CEO down to individual contributors, calculating employee hierarchy
--   depth level and full management breadcrumb path.
-- PROBLEM STATEMENT:
--   Traverse an employee-manager hierarchy using a Recursive CTE (WITH RECURSIVE).
-- ============================================================================

DROP TABLE IF EXISTS corporate_hierarchy;
CREATE TABLE corporate_hierarchy (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50),
    manager_id INT
);

INSERT INTO corporate_hierarchy VALUES
(1, 'Alice (CEO)', NULL),
(2, 'Bob (VP Eng)', 1),
(3, 'Charlie (VP Sales)', 1),
(4, 'David (Lead Dev)', 2),
(5, 'Eve (Junior Dev)', 4);

-- --- [SOLUTION QUERY] ---
WITH RECURSIVE org_tree AS (
    -- Anchor member: CEO (manager_id IS NULL)
    SELECT 
        emp_id,
        emp_name,
        manager_id,
        1 AS org_level,
        CAST(emp_name AS VARCHAR(255)) AS management_path
    FROM corporate_hierarchy
    WHERE manager_id IS NULL

    UNION ALL

    -- Recursive member: join child to parent
    SELECT 
        child.emp_id,
        child.emp_name,
        child.manager_id,
        parent.org_level + 1,
        CAST(parent.management_path || ' -> ' || child.emp_name AS VARCHAR(255))
    FROM corporate_hierarchy child
    JOIN org_tree parent ON child.manager_id = parent.emp_id
)
SELECT 
    emp_id,
    emp_name,
    org_level,
    management_path
FROM org_tree
ORDER BY org_level ASC, emp_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[org_level] = 1
