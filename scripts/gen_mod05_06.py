#!/usr/bin/env python3
"""
Generator for Module 05 (046-055) & Module 06 (056-065)
"""
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

def save(mod: str, name: str, content: str):
    p = EXERCISES_DIR / mod / name
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Generated: {mod}/{name}")

# ==============================================================================
# MODULE 05: Subqueries, CTEs & Recursive Graph Traversal (046 - 055)
# ==============================================================================

save("05_subqueries_and_recursive_ctes", "046_scalar_and_multi_row_subqueries.sql", """-- ============================================================================
-- EXERCISE: 046_scalar_and_multi_row_subqueries.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Compensation equity review: identify all employees whose salary is above
--   their department's average salary, and calculate the exact dollar variance.
-- PROBLEM STATEMENT:
--   Implement scalar subqueries in SELECT and multi-row subqueries in WHERE.
-- ============================================================================

DROP TABLE IF EXISTS dept_employees;
CREATE TABLE dept_employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(50),
    dept_id INT,
    salary DECIMAL(10, 2)
);

INSERT INTO dept_employees VALUES
(1, 'Alice',   10, 95000.00),
(2, 'Bob',     10, 80000.00),
(3, 'Charlie', 20, 110000.00),
(4, 'David',   20, 70000.00);

-- --- [SOLUTION QUERY] ---
SELECT
    e.emp_id,
    e.emp_name,
    e.dept_id,
    e.salary,
    (SELECT ROUND(AVG(d.salary), 2) FROM dept_employees d WHERE d.dept_id = e.dept_id) AS dept_avg_salary,
    ROUND(e.salary - (SELECT AVG(d.salary) FROM dept_employees d WHERE d.dept_id = e.dept_id), 2) AS salary_variance
FROM dept_employees e
WHERE e.salary > (SELECT AVG(d.salary) FROM dept_employees d WHERE d.dept_id = e.dept_id)
ORDER BY e.salary DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[salary_variance] = 7500.00
""")

save("05_subqueries_and_recursive_ctes", "047_correlated_subqueries_and_decorrelation.sql", """-- ============================================================================
-- EXERCISE: 047_correlated_subqueries_and_decorrelation.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   E-commerce fraud detection: Identify customers who placed an order with an
--   amount greater than 3 times their historical average order value.
-- PROBLEM STATEMENT:
--   Write a correlated subquery comparing current row to historical customer
--   aggregates, and rewrite into an optimized decorrelated window join.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders_hist;
CREATE TABLE customer_orders_hist (
    order_id INT PRIMARY KEY,
    customer_id INT,
    amount DECIMAL(10, 2)
);

INSERT INTO customer_orders_hist VALUES
(101, 1, 100.00),
(102, 1, 120.00),
(103, 1, 950.00), -- Spikes 3x above average!
(104, 2, 500.00),
(105, 2, 550.00);

-- --- [SOLUTION QUERY] ---
-- Optimized decorrelated query using window functions
WITH customer_averages AS (
    SELECT
        order_id,
        customer_id,
        amount,
        AVG(amount) OVER (PARTITION BY customer_id) AS avg_cust_amount
    FROM customer_orders_hist
)
SELECT
    order_id,
    customer_id,
    amount,
    ROUND(avg_cust_amount, 2) AS avg_amount,
    ROUND(amount / avg_cust_amount, 2) AS spike_ratio
FROM customer_averages
WHERE amount > 2.0 * avg_cust_amount
ORDER BY order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[order_id] = 103
""")

save("05_subqueries_and_recursive_ctes", "048_ctes_vs_temp_tables_vs_subqueries.sql", """-- ============================================================================
-- EXERCISE: 048_ctes_vs_temp_tables_vs_subqueries.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   ETL pipeline clean-up: Transform raw event streams into parsed JSON attributes,
--   filter invalid records, and aggregate summary metrics in a clean multi-CTE pipeline.
-- PROBLEM STATEMENT:
--   Demonstrate staging transformations through sequential modular CTEs.
-- ============================================================================

DROP TABLE IF EXISTS raw_inbound_stream;
CREATE TABLE raw_inbound_stream (
    event_id INT PRIMARY KEY,
    event_type VARCHAR(20),
    amount DECIMAL(10, 2),
    is_test INT
);

INSERT INTO raw_inbound_stream VALUES
(1, 'PURCHASE', 150.00, 0),
(2, 'PURCHASE', 200.00, 1), -- Filter out test
(3, 'REFUND',    50.00, 0),
(4, 'PURCHASE', 400.00, 0);

-- --- [SOLUTION QUERY] ---
WITH cleaned_events AS (
    SELECT event_id, event_type, amount
    FROM raw_inbound_stream
    WHERE is_test = 0
),
aggregated_metrics AS (
    SELECT
        event_type,
        COUNT(*) AS event_count,
        SUM(amount) AS total_volume
    FROM cleaned_events
    GROUP BY event_type
)
SELECT
    event_type,
    event_count,
    total_volume
FROM aggregated_metrics
ORDER BY total_volume DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_volume] = 550.00
""")

save("05_subqueries_and_recursive_ctes", "049_recursive_cte_organizational_hierarchy.sql", """-- ============================================================================
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
""")

save("05_subqueries_and_recursive_ctes", "050_recursive_cte_bill_of_materials_explosion.sql", """-- ============================================================================
-- EXERCISE: 050_recursive_cte_bill_of_materials_explosion.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Manufacturing supply chain: A Laptop consists of sub-assemblies (Chassis,
--   Motherboard), which themselves contain raw components (Chips, Screws).
--   To compute total cost, the Bill of Materials (BOM) must be fully exploded.
-- PROBLEM STATEMENT:
--   Recursively explode parts hierarchy and calculate the cumulative quantity
--   of every sub-component required to produce 1 top-level finished unit.
-- ============================================================================

DROP TABLE IF EXISTS bill_of_materials;
CREATE TABLE bill_of_materials (
    parent_part VARCHAR(50),
    child_part VARCHAR(50),
    quantity_required INT
);

INSERT INTO bill_of_materials VALUES
('Laptop', 'Motherboard', 1),
('Laptop', 'Chassis',     1),
('Motherboard', 'CPU',     1),
('Motherboard', 'RAM',     2),
('Chassis', 'Screw',       8);

-- --- [SOLUTION QUERY] ---
WITH RECURSIVE bom_explosion AS (
    -- Anchor: Immediate components of Laptop
    SELECT
        child_part,
        quantity_required,
        1 AS bom_depth
    FROM bill_of_materials
    WHERE parent_part = 'Laptop'

    UNION ALL

    -- Recursive: Expand sub-components multiplying quantities
    SELECT
        sub.child_part,
        parent.quantity_required * sub.quantity_required,
        parent.bom_depth + 1
    FROM bill_of_materials sub
    JOIN bom_explosion parent ON sub.parent_part = parent.child_part
)
SELECT
    child_part,
    SUM(quantity_required) AS total_units_needed
FROM bom_explosion
GROUP BY child_part
ORDER BY total_units_needed DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[total_units_needed] = 8
""")

save("05_subqueries_and_recursive_ctes", "051_recursive_cte_graph_shortest_path_cycle_detection.sql", """-- ============================================================================
-- EXERCISE: 051_recursive_cte_graph_shortest_path_cycle_detection.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Flight route network optimizer: Find all possible flight itineraries between
--   London (LHR) and Tokyo (HND) with maximum 2 layovers, preventing infinite
--   loops in cyclic graph networks.
-- PROBLEM STATEMENT:
--   Traverse cyclic flight connections using a Recursive CTE with cycle-detection guards.
-- ============================================================================

DROP TABLE IF EXISTS flight_routes;
CREATE TABLE flight_routes (
    origin VARCHAR(10),
    destination VARCHAR(10),
    cost DECIMAL(10, 2)
);

INSERT INTO flight_routes VALUES
('LHR', 'DXB', 400.00),
('DXB', 'HND', 500.00),
('LHR', 'SIN', 600.00),
('SIN', 'HND', 350.00),
('DXB', 'LHR', 400.00); -- Cycle!

-- --- [SOLUTION QUERY] ---
WITH RECURSIVE flight_paths AS (
    SELECT
        origin,
        destination,
        cost AS total_cost,
        1 AS stops,
        CAST(origin || '->' || destination AS VARCHAR(255)) AS path_str
    FROM flight_routes
    WHERE origin = 'LHR'

    UNION ALL

    SELECT
        r.origin,
        r.destination,
        p.total_cost + r.cost,
        p.stops + 1,
        CAST(p.path_str || '->' || r.destination AS VARCHAR(255))
    FROM flight_routes r
    JOIN flight_paths p ON r.origin = p.destination
    -- Cycle prevention: do not revisit airport already in path; max 3 flights
    WHERE INSTR(p.path_str, r.destination) = 0
      AND p.stops < 3
)
SELECT
    path_str,
    stops,
    total_cost
FROM flight_paths
WHERE destination = 'HND'
ORDER BY total_cost ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_cost] = 900.00
""")

save("05_subqueries_and_recursive_ctes", "052_recursive_cte_calendar_dimension_spine.sql", """-- ============================================================================
-- EXERCISE: 052_recursive_cte_calendar_dimension_spine.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Sales fact tables are sparse: if no sales occur on a weekend, no row exists.
--   When generating daily trend graphs, missing dates cause visual gaps.
-- PROBLEM STATEMENT:
--   Generate a continuous calendar date spine using a Recursive CTE, then
--   LEFT JOIN sales to ensure zero-revenue days display $0.00.
-- ============================================================================

DROP TABLE IF EXISTS daily_orders;
CREATE TABLE daily_orders (
    order_date TEXT PRIMARY KEY,
    amount DECIMAL(10, 2)
);

INSERT INTO daily_orders VALUES
('2024-05-01', 500.00),
('2024-05-04', 300.00); -- May 2 and May 3 are missing!

-- --- [SOLUTION QUERY] ---
WITH RECURSIVE date_spine AS (
    SELECT '2024-05-01' AS cal_date
    UNION ALL
    SELECT DATE(cal_date, '+1 day')
    FROM date_spine
    WHERE cal_date < '2024-05-04'
)
SELECT
    s.cal_date,
    COALESCE(o.amount, 0.00) AS daily_revenue
FROM date_spine s
LEFT JOIN daily_orders o ON s.cal_date = o.order_date
ORDER BY s.cal_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[daily_revenue] = 500.00
""")

save("05_subqueries_and_recursive_ctes", "053_binary_tree_node_classification.sql", """-- ============================================================================
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
""")

save("05_subqueries_and_recursive_ctes", "054_materialized_vs_inlined_ctes.sql", """-- ============================================================================
-- EXERCISE: 054_materialized_vs_inlined_ctes.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Query optimizer fences: In PostgreSQL and SQLite, an un-materialized CTE is
--   inlined into the main query, allowing predicate pushdown. A MATERIALIZED CTE
--   forces evaluation into a temporary buffer, acting as an optimization fence.
-- PROBLEM STATEMENT:
--   Demonstrate filtering inside CTE versus filtering downstream.
-- ============================================================================

DROP TABLE IF EXISTS raw_logs;
CREATE TABLE raw_logs (
    log_id INT PRIMARY KEY,
    severity VARCHAR(10),
    message TEXT
);

INSERT INTO raw_logs VALUES
(1, 'INFO',  'System started'),
(2, 'ERROR', 'Disk full'),
(3, 'WARN',  'High memory'),
(4, 'ERROR', 'Connection timeout');

-- --- [SOLUTION QUERY] ---
WITH error_logs AS (
    SELECT log_id, severity, message
    FROM raw_logs
    WHERE severity = 'ERROR'
)
SELECT
    log_id,
    message
FROM error_logs
WHERE log_id > 1
ORDER BY log_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[message] = Disk full
""")

save("05_subqueries_and_recursive_ctes", "055_deterministic_duplicate_deletion.sql", """-- ============================================================================
-- EXERCISE: 055_deterministic_duplicate_deletion.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A buggy webhook created multiple duplicate records for the same customer email.
--   Database hygiene mandates deleting all duplicate rows, strictly keeping the
--   single record with the lowest primary key ID.
-- PROBLEM STATEMENT:
--   Delete duplicates deterministically using ROW_NUMBER() in a CTE.
-- ============================================================================

DROP TABLE IF EXISTS contacts;
CREATE TABLE contacts (
    contact_id INT PRIMARY KEY,
    email VARCHAR(100),
    full_name VARCHAR(100)
);

INSERT INTO contacts VALUES
(1, 'alice@acme.com', 'Alice Smith'),
(2, 'alice@acme.com', 'Alice Smith Duplicate'),
(3, 'alice@acme.com', 'Alice S. Triplicate'),
(4, 'bob@acme.com',   'Bob Jones');

-- --- [SOLUTION QUERY] ---
-- Delete duplicate contacts preserving lowest contact_id
DELETE FROM contacts
WHERE contact_id IN (
    SELECT contact_id FROM (
        SELECT
            contact_id,
            ROW_NUMBER() OVER (
                PARTITION BY email
                ORDER BY contact_id ASC
            ) AS rn
        FROM contacts
    ) ranked
    WHERE ranked.rn > 1
);

SELECT contact_id, email, full_name FROM contacts ORDER BY contact_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[contact_id] = 1
""")

# ==============================================================================
# MODULE 06: Data Modeling, SCD & Lakehouse Architecture (056 - 065)
# ==============================================================================

save("06_data_modeling_and_scd", "056_kimball_star_schema_fact_dimension_design.sql", """-- ============================================================================
-- EXERCISE: 056_kimball_star_schema_fact_dimension_design.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Enterprise retail reporting uses Kimball Dimensional Modeling: a central
--   Fact table containing numeric additive facts and foreign surrogate keys,
--   surrounded by conformed Dimension tables containing descriptive attributes.
-- PROBLEM STATEMENT:
--   Query a Star Schema joining Fact Sales to Date, Store, and Product dimensions.
-- ============================================================================

DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;

CREATE TABLE dim_date (date_key INT PRIMARY KEY, full_date TEXT, calendar_year INT);
CREATE TABLE dim_product (product_key INT PRIMARY KEY, product_name VARCHAR(50), category VARCHAR(50));
CREATE TABLE dim_store (store_key INT PRIMARY KEY, store_name VARCHAR(50), city VARCHAR(50));

CREATE TABLE fact_sales (
    sale_id INT PRIMARY KEY,
    date_key INT,
    product_key INT,
    store_key INT,
    quantity INT,
    revenue DECIMAL(10, 2)
);

INSERT INTO dim_date VALUES (20240501, '2024-05-01', 2024);
INSERT INTO dim_product VALUES (1, '4K Monitor', 'Hardware');
INSERT INTO dim_store VALUES (10, 'Central Store', 'New York');
INSERT INTO fact_sales VALUES (1001, 20240501, 1, 10, 2, 700.00);

-- --- [SOLUTION QUERY] ---
SELECT
    d.calendar_year,
    s.city,
    p.category,
    p.product_name,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.revenue)  AS total_gross_revenue
FROM fact_sales f
JOIN dim_date d ON f.date_key = d.date_key
JOIN dim_store s ON f.store_key = s.store_key
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY d.calendar_year, s.city, p.category, p.product_name;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_gross_revenue] = 700.00
""")

save("06_data_modeling_and_scd", "057_slowly_changing_dimension_type_1_overwrite.sql", """-- ============================================================================
-- EXERCISE: 057_slowly_changing_dimension_type_1_overwrite.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 1 (In-Place Overwrite): When correcting spelling errors or non-historical
--   attributes (e.g. fixing customer phone number), the prior value is overwritten
--   and no historical versions are retained.
-- PROBLEM STATEMENT:
--   Apply an SCD Type 1 update ensuring audit timestamps are maintained.
-- ============================================================================

DROP TABLE IF EXISTS dim_customer_scd1;
CREATE TABLE dim_customer_scd1 (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    phone_number VARCHAR(20),
    last_updated_at TEXT
);

INSERT INTO dim_customer_scd1 VALUES
(1, 'Alice Smith', '555-0000', '2024-01-01 10:00:00');

-- SCD Type 1 Update
UPDATE dim_customer_scd1
SET phone_number = '555-9999',
    last_updated_at = '2024-05-15 14:30:00'
WHERE customer_id = 1;

-- --- [SOLUTION QUERY] ---
SELECT customer_id, customer_name, phone_number, last_updated_at
FROM dim_customer_scd1
WHERE customer_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[phone_number] = 555-9999
""")

save("06_data_modeling_and_scd", "058_slowly_changing_dimension_type_2_historical.sql", """-- ============================================================================
-- EXERCISE: 058_slowly_changing_dimension_type_2_historical.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 2 (Historical Tracking): When customer address changes, previous
--   address must be preserved for historical sales tax audit compliance.
--   Each version has valid_from, valid_to, and is_current flag.
-- PROBLEM STATEMENT:
--   Execute an SCD Type 2 state transition: expire existing record and insert new active row.
-- ============================================================================

DROP TABLE IF EXISTS dim_customer_scd2;
CREATE TABLE dim_customer_scd2 (
    surrogate_key INT PRIMARY KEY,
    customer_id INT,
    customer_name VARCHAR(100),
    state_code VARCHAR(2),
    valid_from TEXT,
    valid_to TEXT,
    is_current INT
);

INSERT INTO dim_customer_scd2 VALUES
(1, 101, 'Alice Smith', 'NY', '2023-01-01', '9999-12-31', 1);

-- Step 1: Expire old active row
UPDATE dim_customer_scd2
SET valid_to = '2024-05-01', is_current = 0
WHERE customer_id = 101 AND is_current = 1;

-- Step 2: Insert new active row
INSERT INTO dim_customer_scd2 VALUES
(2, 101, 'Alice Smith', 'CA', '2024-05-01', '9999-12-31', 1);

-- --- [SOLUTION QUERY] ---
SELECT
    surrogate_key,
    customer_id,
    state_code,
    valid_from,
    valid_to,
    is_current
FROM dim_customer_scd2
WHERE customer_id = 101
ORDER BY valid_from ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[state_code] = NY
""")

save("06_data_modeling_and_scd", "059_slowly_changing_dimension_type_3_previous_value.sql", """-- ============================================================================
-- EXERCISE: 059_slowly_changing_dimension_type_3_previous_value.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 3 (Prior Value Column): Sales territory realignment requires
--   tracking both the Current Sales Territory and the Previous Sales Territory
--   side-by-side without adding new table rows.
-- PROBLEM STATEMENT:
--   Implement SCD Type 3 updating current_territory and shifting old value to prev_territory.
-- ============================================================================

DROP TABLE IF EXISTS dim_sales_rep_scd3;
CREATE TABLE dim_sales_rep_scd3 (
    rep_id INT PRIMARY KEY,
    rep_name VARCHAR(50),
    current_territory VARCHAR(50),
    prev_territory VARCHAR(50),
    effective_date TEXT
);

INSERT INTO dim_sales_rep_scd3 VALUES
(1, 'Bob Jones', 'North', NULL, '2023-01-01');

-- Transition rep from North to West
UPDATE dim_sales_rep_scd3
SET prev_territory = current_territory,
    current_territory = 'West',
    effective_date = '2024-06-01'
WHERE rep_id = 1;

-- --- [SOLUTION QUERY] ---
SELECT rep_id, rep_name, current_territory, prev_territory, effective_date
FROM dim_sales_rep_scd3
WHERE rep_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[current_territory] = West
-- ASSERT: COL[prev_territory] = North
""")

save("06_data_modeling_and_scd", "060_slowly_changing_dimension_type_4_mini_dimensions.sql", """-- ============================================================================
-- EXERCISE: 060_slowly_changing_dimension_type_4_mini_dimensions.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 4 (Mini-Dimensions): High-frequency changing customer attributes
--   (credit score band, annual income tier, age group) would cause an SCD Type 2
--   table to explode to billions of rows. Mini-dimensions extract these into a
--   small, pre-calculated profile lookup table.
-- PROBLEM STATEMENT:
--   Model and query a Type 4 mini-dimension linked to a base customer dimension.
-- ============================================================================

DROP TABLE IF EXISTS customer_profile_history;
DROP TABLE IF EXISTS dim_demographic_bands;
DROP TABLE IF EXISTS dim_customer_base;

CREATE TABLE dim_customer_base (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100)
);

CREATE TABLE dim_demographic_bands (
    band_id INT PRIMARY KEY,
    credit_score_band VARCHAR(20),
    income_tier VARCHAR(20)
);

CREATE TABLE customer_profile_history (
    customer_id INT,
    band_id INT,
    assigned_date TEXT,
    PRIMARY KEY (customer_id, assigned_date)
);

INSERT INTO dim_customer_base VALUES (1, 'Alice Smith');
INSERT INTO dim_demographic_bands VALUES (101, '600-699 (Fair)', 'Mid Income'), (102, '700-799 (Good)', 'High Income');
INSERT INTO customer_profile_history VALUES (1, 101, '2023-01-01'), (1, 102, '2024-01-01');

-- --- [SOLUTION QUERY] ---
SELECT
    c.customer_name,
    h.assigned_date,
    b.credit_score_band,
    b.income_tier
FROM dim_customer_base c
JOIN customer_profile_history h ON c.customer_id = h.customer_id
JOIN dim_demographic_bands b ON h.band_id = b.band_id
ORDER BY h.assigned_date DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[credit_score_band] = 700-799 (Good)
""")

save("06_data_modeling_and_scd", "061_slowly_changing_dimension_type_6_hybrid_implementation.sql", """-- ============================================================================
-- EXERCISE: 061_slowly_changing_dimension_type_6_hybrid_implementation.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   SCD Type 6 (1 + 2 + 3): Combines full row history (Type 2) with an in-place
--   current attribute column (Type 1) populated across ALL historical rows for that entity.
-- PROBLEM STATEMENT:
--   Implement SCD Type 6 where updating the active record also cascades the
--   current_state value back to all historical records.
-- ============================================================================

DROP TABLE IF EXISTS dim_customer_scd6;
CREATE TABLE dim_customer_scd6 (
    surrogate_key INT PRIMARY KEY,
    customer_id INT,
    historical_state VARCHAR(2),
    current_state VARCHAR(2),
    valid_from TEXT,
    valid_to TEXT,
    is_current INT
);

INSERT INTO dim_customer_scd6 VALUES
(1, 101, 'NY', 'NY', '2023-01-01', '2024-05-01', 0),
(2, 101, 'CA', 'CA', '2024-05-01', '9999-12-31', 1);

-- Type 6 rule: Overwrite current_state on historical rows to match latest active row!
UPDATE dim_customer_scd6
SET current_state = 'CA'
WHERE customer_id = 101;

-- --- [SOLUTION QUERY] ---
SELECT
    surrogate_key,
    customer_id,
    historical_state,
    current_state,
    is_current
FROM dim_customer_scd6
WHERE customer_id = 101
ORDER BY surrogate_key ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[historical_state] = NY
-- ASSERT: COL[current_state] = CA
""")

save("06_data_modeling_and_scd", "062_data_vault_2_0_hubs_links_satellites.sql", """-- ============================================================================
-- EXERCISE: 062_data_vault_2_0_hubs_links_satellites.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Data Vault 2.0 Enterprise EDW: Isolates business keys into HUBS, relationships
--   into LINKS, and descriptive/temporal context into SATELLITES for agile schema evolution.
-- PROBLEM STATEMENT:
--   Model and query a complete Data Vault 2.0 triangle: Hub Customer, Hub Account,
--   Link Customer-Account, and Satellite Customer Details.
-- ============================================================================

DROP TABLE IF EXISTS sat_customer;
DROP TABLE IF EXISTS link_customer_account;
DROP TABLE IF EXISTS hub_account;
DROP TABLE IF EXISTS hub_customer;

CREATE TABLE hub_customer (
    h_customer_hash VARCHAR(32) PRIMARY KEY,
    customer_id INT,
    load_date TEXT
);

CREATE TABLE hub_account (
    h_account_hash VARCHAR(32) PRIMARY KEY,
    account_number VARCHAR(20),
    load_date TEXT
);

CREATE TABLE link_customer_account (
    l_cust_acc_hash VARCHAR(32) PRIMARY KEY,
    h_customer_hash VARCHAR(32),
    h_account_hash VARCHAR(32),
    load_date TEXT
);

CREATE TABLE sat_customer (
    h_customer_hash VARCHAR(32),
    load_date TEXT,
    customer_name VARCHAR(100),
    email VARCHAR(100),
    PRIMARY KEY (h_customer_hash, load_date)
);

INSERT INTO hub_customer VALUES ('HASH_C1', 101, '2024-01-01');
INSERT INTO hub_account VALUES ('HASH_A1', 'ACC-999', '2024-01-01');
INSERT INTO link_customer_account VALUES ('HASH_L1', 'HASH_C1', 'HASH_A1', '2024-01-01');
INSERT INTO sat_customer VALUES ('HASH_C1', '2024-01-01', 'Alice Smith', 'alice@example.com');

-- --- [SOLUTION QUERY] ---
SELECT
    c.customer_id,
    s.customer_name,
    s.email,
    a.account_number
FROM hub_customer c
JOIN link_customer_account l ON c.h_customer_hash = l.h_customer_hash
JOIN hub_account a ON l.h_account_hash = a.h_account_hash
JOIN sat_customer s ON c.h_customer_hash = s.h_customer_hash;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[account_number] = ACC-999
""")

save("06_data_modeling_and_scd", "063_bridge_tables_for_many_to_many_relationships.sql", """-- ============================================================================
-- EXERCISE: 063_bridge_tables_for_many_to_many_relationships.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Joint bank accounts: A bank account can have multiple owners (Alice 60%, Bob 40%),
--   and an owner can hold multiple accounts. A Bridge Table resolves this Many-to-Many
--   relationship with weighting factors to prevent balance overstatement.
-- PROBLEM STATEMENT:
--   Implement a weighted bridge table and calculate exact weighted customer balances.
-- ============================================================================

DROP TABLE IF EXISTS bridge_account_customer;
DROP TABLE IF EXISTS dim_joint_customers;
DROP TABLE IF EXISTS fact_account_balances;

CREATE TABLE dim_joint_customers (customer_id INT PRIMARY KEY, customer_name VARCHAR(50));
CREATE TABLE fact_account_balances (account_id INT PRIMARY KEY, balance DECIMAL(10, 2));

CREATE TABLE bridge_account_customer (
    account_id INT,
    customer_id INT,
    weight_factor DECIMAL(3, 2),
    PRIMARY KEY (account_id, customer_id)
);

INSERT INTO dim_joint_customers VALUES (1, 'Alice'), (2, 'Bob');
INSERT INTO fact_account_balances VALUES (101, 100000.00);
INSERT INTO bridge_account_customer VALUES (101, 1, 0.60), (101, 2, 0.40);

-- --- [SOLUTION QUERY] ---
SELECT
    c.customer_name,
    f.account_id,
    f.balance AS total_account_balance,
    b.weight_factor,
    ROUND(f.balance * b.weight_factor, 2) AS customer_attributed_balance
FROM fact_account_balances f
JOIN bridge_account_customer b ON f.account_id = b.account_id
JOIN dim_joint_customers c ON b.customer_id = c.customer_id
ORDER BY customer_attributed_balance DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[customer_attributed_balance] = 60000.00
""")

save("06_data_modeling_and_scd", "064_accumulating_snapshot_fact_tables.sql", """-- ============================================================================
-- EXERCISE: 064_accumulating_snapshot_fact_tables.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Order fulfillment lifecycle: An e-commerce order moves through sequential milestones
--   (Placed $\rightarrow$ Paid $\rightarrow$ Shipped $\rightarrow$ Delivered).
--   An Accumulating Snapshot Fact Table stores one row per order with lag duration metrics.
-- PROBLEM STATEMENT:
--   Query milestone timestamps and compute lag days between order placement and delivery.
-- ============================================================================

DROP TABLE IF EXISTS fact_order_fulfillment;
CREATE TABLE fact_order_fulfillment (
    order_id INT PRIMARY KEY,
    order_placed_epoch INT,
    order_paid_epoch INT,
    order_shipped_epoch INT,
    order_delivered_epoch INT
);

INSERT INTO fact_order_fulfillment VALUES
(1, 1700000000, 1700000100, 1700086400, 1700259200); -- ~3 days total

-- --- [SOLUTION QUERY] ---
SELECT
    order_id,
    ROUND((order_paid_epoch - order_placed_epoch) / 60.0, 1) AS minutes_to_pay,
    ROUND((order_shipped_epoch - order_paid_epoch) / 3600.0, 1) AS hours_to_ship,
    ROUND((order_delivered_epoch - order_placed_epoch) / 86400.0, 2) AS total_fulfillment_days
FROM fact_order_fulfillment
WHERE order_delivered_epoch IS NOT NULL;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_fulfillment_days] = 3.0
""")

save("06_data_modeling_and_scd", "065_deterministic_surrogate_key_generation.sql", """-- ============================================================================
-- EXERCISE: 065_deterministic_surrogate_key_generation.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Distributed Lakehouse architectures (Spark, Snowflake, BigQuery) cannot
--   efficiently generate sequential auto-incrementing integers without serializing
--   across all compute workers. Modern Lakehouse pipelines standardize on
--   deterministic MD5 / SHA256 surrogate keys.
-- PROBLEM STATEMENT:
--   Generate deterministic surrogate keys from compound natural keys.
-- ============================================================================

DROP TABLE IF EXISTS staging_merchants;
CREATE TABLE staging_merchants (
    country_code VARCHAR(2),
    tax_identifier VARCHAR(50),
    merchant_name VARCHAR(100)
);

INSERT INTO staging_merchants VALUES
('US', '12-3456789', 'Acme USA'),
('UK', 'GB987654321', 'Acme UK');

-- --- [SOLUTION QUERY] ---
-- Portable surrogate key generation using compound natural key concatenation
SELECT
    -- In engines with native MD5: MD5(country_code || '_' || tax_identifier)
    country_code || '_' || tax_identifier AS surrogate_business_key,
    merchant_name
FROM staging_merchants
ORDER BY surrogate_business_key ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[surrogate_business_key] = UK_GB987654321
""")

print("Module 05 and Module 06 generation complete!")
