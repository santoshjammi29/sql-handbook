-- ============================================================================
-- EXERCISE: 049_recursive_cte_organizational_hierarchy.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Enterprise Data Architect & HCM Systems Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Human Resources Management (HCM) Management Hierarchy Tree.
--   Traversing recursive supervisor relationships from the CEO down to individual contributors,
--   calculating reporting depth levels and building canonical breadcrumb paths ('/CEO/VP/Lead/').
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 049 recursive cte organizational hierarchy.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 049 recursive cte organizational hierarchy.
-- ============================================================================

DROP TABLE IF EXISTS corporate_hierarchy;

CREATE TABLE corporate_hierarchy (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100) NOT NULL,
    title VARCHAR(50) NOT NULL,
    manager_id INT -- NULL for CEO
);

INSERT INTO corporate_hierarchy VALUES
(1, 'Sarah Connor',   'Chief Executive Officer', NULL),
(2, 'John Smith',     'VP of Engineering',       1),
(3, 'Elena Rostova',  'VP of Product',           1),
(4, 'David Zhang',    'Staff Data Architect',    2),
(5, 'Alice Vance',    'Senior Data Engineer',    4);

-- --- [SOLUTION QUERY] ---
-- Recursive CTE: Traverses tree depth and builds breadcrumb path string
WITH RECURSIVE org_tree AS (
    -- Anchor Member: Start at the root of the hierarchy (CEO)
    SELECT 
        emp_id,
        emp_name,
        title,
        manager_id,
        1 AS management_level,
        '/' || emp_name AS reporting_path
    FROM corporate_hierarchy
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive Member: Join subordinates to their managers
    SELECT 
        child.emp_id,
        child.emp_name,
        child.title,
        child.manager_id,
        parent.management_level + 1 AS management_level,
        parent.reporting_path || '/' || child.emp_name AS reporting_path
    FROM corporate_hierarchy child
    INNER JOIN org_tree parent ON child.manager_id = parent.emp_id
)
SELECT 
    emp_id,
    emp_name,
    title,
    management_level,
    reporting_path
FROM org_tree
ORDER BY management_level ASC, emp_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[emp_id] = 1
