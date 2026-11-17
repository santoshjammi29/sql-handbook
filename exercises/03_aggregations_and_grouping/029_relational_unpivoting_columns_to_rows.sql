-- ============================================================================
-- EXERCISE: 029_relational_unpivoting_columns_to_rows.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Data Warehouse Modeler
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Financial Planning & Analysis (FP&A) Ingestion Mart.
--   FP&A analysts export wide Excel spreadsheets where months or metrics are
--   spread across separate columns (e.g., [Dept, Jan_Spend, Feb_Spend, Mar_Spend]).
--   Dimensional star schemas require unpivoting wide columns into normalized rows:
--   [Dept, Month_Date, Spend_Amount].
--
-- BUSINESS CONTEXT:
--   Unpivoting transforms wide columns into normalized relational rows.
--   Standard ANSI SQL uses CROSS JOIN with a value generator table (VALUES) or UNION ALL,
--   ensuring complete portability without proprietary UNPIVOT keywords.
--
-- PROBLEM STATEMENT:
--   Unpivot wide quarterly budget projections into a normalized Kimball fact table format.
-- ============================================================================

DROP TABLE IF EXISTS wide_quarterly_budget;

CREATE TABLE wide_quarterly_budget (
    department_id VARCHAR(20) PRIMARY KEY,
    department_name VARCHAR(50) NOT NULL,
    q1_budget_usd DECIMAL(12, 2) NOT NULL,
    q2_budget_usd DECIMAL(12, 2) NOT NULL,
    q3_budget_usd DECIMAL(12, 2) NOT NULL,
    q4_budget_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO wide_quarterly_budget VALUES
('D-01', 'Cloud Infrastructure', 500000.00, 520000.00, 550000.00, 600000.00),
('D-02', 'Data Science & AI',     300000.00, 350000.00, 420000.00, 480000.00);

-- --- [SOLUTION QUERY] ---
-- Portable ANSI SQL unpivoting using UNION ALL to normalize columns into rows
SELECT department_id, department_name, '2024-Q1' AS fiscal_quarter, q1_budget_usd AS allocated_budget_usd
FROM wide_quarterly_budget

UNION ALL

SELECT department_id, department_name, '2024-Q2' AS fiscal_quarter, q2_budget_usd AS allocated_budget_usd
FROM wide_quarterly_budget

UNION ALL

SELECT department_id, department_name, '2024-Q3' AS fiscal_quarter, q3_budget_usd AS allocated_budget_usd
FROM wide_quarterly_budget

UNION ALL

SELECT department_id, department_name, '2024-Q4' AS fiscal_quarter, q4_budget_usd AS allocated_budget_usd
FROM wide_quarterly_budget
ORDER BY department_id ASC, fiscal_quarter ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 8
-- ASSERT: COL[department_id] = D-01
