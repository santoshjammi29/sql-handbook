-- ============================================================================
-- EXERCISE: 073_preventing_accidental_cartesian_products.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Quality Architect & Database SRE
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Accidental Cartesian Product Prevention & TempDB Protection.
--   Joining tables without proper ON predicates or joining on non-unique keys
--   causes exponential row explosion (M × N), filling TempDB disks and freezing databases.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 073 preventing accidental cartesian products.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 073 preventing accidental cartesian products.
-- ============================================================================

DROP TABLE IF EXISTS employee_badges;
DROP TABLE IF EXISTS employee_roster;

CREATE TABLE employee_roster (
    emp_id VARCHAR(20) PRIMARY KEY,
    emp_name VARCHAR(50) NOT NULL
);

CREATE TABLE employee_badges (
    badge_id VARCHAR(20) PRIMARY KEY,
    emp_id VARCHAR(20) NOT NULL,
    badge_code VARCHAR(30) NOT NULL
);

INSERT INTO employee_roster VALUES ('E-1', 'Alice'), ('E-2', 'Bob');
INSERT INTO employee_badges VALUES ('B-1', 'E-1', 'SECURITY_LEVEL_4'), ('B-2', 'E-2', 'SECURITY_LEVEL_2');

-- --- [SOLUTION QUERY] ---
-- Properly constrained equi-join preventing accidental M×N cartesian explosion
SELECT 
    r.emp_id,
    r.emp_name,
    b.badge_code,
    'STRICT_EQUI_JOIN_NO_FANOUT' AS join_safety_assertion
FROM employee_roster r
INNER JOIN employee_badges b ON r.emp_id = b.emp_id
ORDER BY r.emp_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[emp_id] = E-1
