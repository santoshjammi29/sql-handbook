-- ============================================================================
-- EXERCISE: 105_master_enterprise_data_quality_reconciliation_suite.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Principal / Architect
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   MASTER ENTERPRISE DATA QUALITY AUDIT SUITE:
--   Automated daily gatekeeper validating:
--   1. Primary key uniqueness (duplicate check)
--   2. Referential integrity (orphaned child records)
--   3. Required nullity checks (missing critical fields)
--   4. Numeric range sanity (negative revenue / prices)
--   5. Date sanity (future event timestamps)
-- PROBLEM STATEMENT:
--   Execute a unified 5-pillar Data Quality Reconciliation Suite returning a
--   clean scorecard of passed/failed tests.
-- ============================================================================

DROP TABLE IF EXISTS dq_sales_fact;
DROP TABLE IF EXISTS dq_customer_dim;

CREATE TABLE dq_customer_dim (cust_id INT PRIMARY KEY, cust_name VARCHAR(50));
CREATE TABLE dq_sales_fact (
    sale_id INT PRIMARY KEY,
    cust_id INT,
    amount DECIMAL(10, 2),
    sale_date TEXT
);

INSERT INTO dq_customer_dim VALUES (1, 'Acme Corp'), (2, 'Globex Inc');
INSERT INTO dq_sales_fact VALUES
(101, 1, 500.00, '2024-05-01'),
(102, 2, 750.00, '2024-05-02');

-- --- [SOLUTION QUERY] ---
-- Master 5-Pillar Data Quality Reconciliation Scorecard
WITH check_duplicates AS (
    SELECT '1. PK Uniqueness' AS test_name, 
           CASE WHEN COUNT(sale_id) = COUNT(DISTINCT sale_id) THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
),
check_orphans AS (
    SELECT '2. Referential Integrity' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact s
    LEFT JOIN dq_customer_dim c ON s.cust_id = c.cust_id
    WHERE c.cust_id IS NULL
),
check_nulls AS (
    SELECT '3. Nullity Mandatory Checks' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
    WHERE cust_id IS NULL OR amount IS NULL OR sale_date IS NULL
),
check_numeric_ranges AS (
    SELECT '4. Numeric Range Sanity' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
    WHERE amount <= 0.00
),
check_date_sanity AS (
    SELECT '5. Date Bounds Sanity' AS test_name,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM dq_sales_fact
    WHERE sale_date > '2099-12-31'
)
SELECT test_name, test_status FROM check_duplicates
UNION ALL
SELECT test_name, test_status FROM check_orphans
UNION ALL
SELECT test_name, test_status FROM check_nulls
UNION ALL
SELECT test_name, test_status FROM check_numeric_ranges
UNION ALL
SELECT test_name, test_status FROM check_date_sanity
ORDER BY test_name ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[test_status] = PASS
