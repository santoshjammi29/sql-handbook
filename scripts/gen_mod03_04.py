#!/usr/bin/env python3
"""
Generator for Module 03 (021-030) & Module 04 (031-045)
"""
import os
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
# MODULE 03: Aggregations, Grouping & Dimensional Pivoting (021 - 030)
# ==============================================================================

save("03_aggregations_and_grouping", "021_count_semantics_star_one_column.sql", """-- ============================================================================
-- EXERCISE: 021_count_semantics_star_one_column.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A data quality dashboard needs to report total rows, populated rows,
--   missing values, and unique counts across a customer transactions table.
-- PROBLEM STATEMENT:
--   Demonstrate the exact behavioral differences between COUNT(*), COUNT(1),
--   COUNT(column), and COUNT(DISTINCT column) in the presence of NULL values.
-- ============================================================================

DROP TABLE IF EXISTS audit_transactions;
CREATE TABLE audit_transactions (
    txn_id INT PRIMARY KEY,
    customer_id INT,
    discount_code VARCHAR(20) -- Contains NULLs and duplicate promo codes
);

INSERT INTO audit_transactions VALUES
(1, 101, 'SUMMER10'),
(2, 102, NULL),
(3, 103, 'SUMMER10'),
(4, 104, NULL),
(5, 105, 'WELCOME5');

-- --- [SOLUTION QUERY] ---
SELECT 
    COUNT(*) AS total_rows_star,
    COUNT(1) AS total_rows_one,
    COUNT(discount_code) AS populated_discounts,
    COUNT(*) - COUNT(discount_code) AS missing_discounts,
    COUNT(DISTINCT discount_code) AS unique_discount_codes
FROM audit_transactions;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[total_rows_star] = 5
-- ASSERT: COL[populated_discounts] = 3
-- ASSERT: COL[unique_discount_codes] = 2
""")

save("03_aggregations_and_grouping", "022_multi_column_group_by_and_grain_integrity.sql", """-- ============================================================================
-- EXERCISE: 022_multi_column_group_by_and_grain_integrity.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A SaaS company bills customers based on product tier across multiple geographic
--   regions. The billing team needs aggregated metrics at the (region, plan_tier) grain.
-- PROBLEM STATEMENT:
--   Group by multiple dimensions, ensuring proper grain integrity, and calculate
--   active subscriber count and total Monthly Recurring Revenue (MRR).
-- ============================================================================

DROP TABLE IF EXISTS subscriptions;
CREATE TABLE subscriptions (
    sub_id INT PRIMARY KEY,
    region VARCHAR(50),
    plan_tier VARCHAR(50),
    mrr DECIMAL(10, 2)
);

INSERT INTO subscriptions VALUES
(1, 'EMEA', 'Enterprise', 5000.00),
(2, 'EMEA', 'Standard', 1200.00),
(3, 'EMEA', 'Enterprise', 4500.00),
(4, 'US',   'Enterprise', 6000.00),
(5, 'US',   'Standard', 1500.00),
(6, 'US',   'Standard', 1100.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    region,
    plan_tier,
    COUNT(sub_id) AS active_subscribers,
    SUM(mrr)      AS total_mrr,
    ROUND(AVG(mrr), 2) AS avg_mrr_per_sub
FROM subscriptions
GROUP BY region, plan_tier
ORDER BY region ASC, total_mrr DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[total_mrr] = 9500.00
""")

save("03_aggregations_and_grouping", "023_where_pre_filtering_vs_having_post_aggregation.sql", """-- ============================================================================
-- EXERCISE: 023_where_pre_filtering_vs_having_post_aggregation.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Finance needs to audit departments whose total verified expense claims
--   exceed $1,000. Only claims with status 'APPROVED' should be evaluated.
-- PROBLEM STATEMENT:
--   Demonstrate combining WHERE (filtering out rejected/pending claims before
--   aggregation) with HAVING (filtering out departments with small total claims).
-- ============================================================================

DROP TABLE IF EXISTS expense_claims;
CREATE TABLE expense_claims (
    claim_id INT PRIMARY KEY,
    department VARCHAR(50),
    amount DECIMAL(10, 2),
    status VARCHAR(20)
);

INSERT INTO expense_claims VALUES
(1, 'Engineering', 800.00, 'APPROVED'),
(2, 'Engineering', 400.00, 'APPROVED'),
(3, 'Engineering', 500.00, 'REJECTED'),
(4, 'Marketing',   600.00, 'APPROVED'),
(5, 'Marketing',   300.00, 'APPROVED'),
(6, 'Sales',       1500.00, 'APPROVED');

-- --- [SOLUTION QUERY] ---
SELECT 
    department,
    SUM(amount) AS total_approved_expenses
FROM expense_claims
WHERE status = 'APPROVED'
GROUP BY department
HAVING SUM(amount) > 1000.00
ORDER BY total_approved_expenses DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_approved_expenses] = 1500.00
""")

save("03_aggregations_and_grouping", "024_conditional_aggregation_filtered_metrics.sql", """-- ============================================================================
-- EXERCISE: 024_conditional_aggregation_filtered_metrics.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   An operations dashboard needs to report total transactions, total completed
--   revenue, total refunded amount, and refund rate in a SINGLE TABLE SCAN.
-- PROBLEM STATEMENT:
--   Implement conditional aggregation using CASE expressions inside SUM() and
--   COUNT() to calculate multiple business metrics simultaneously.
-- ============================================================================

DROP TABLE IF EXISTS gateway_txns;
CREATE TABLE gateway_txns (
    txn_id INT PRIMARY KEY,
    merchant_id INT,
    amount DECIMAL(10, 2),
    status VARCHAR(20) -- 'SUCCESS', 'REFUNDED', 'FAILED'
);

INSERT INTO gateway_txns VALUES
(1, 10, 100.00, 'SUCCESS'),
(2, 10, 250.00, 'SUCCESS'),
(3, 10, 50.00,  'REFUNDED'),
(4, 10, 75.00,  'FAILED'),
(5, 20, 500.00, 'SUCCESS'),
(6, 20, 200.00, 'REFUNDED');

-- --- [SOLUTION QUERY] ---
SELECT 
    merchant_id,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN status = 'SUCCESS' THEN amount ELSE 0.00 END) AS success_revenue,
    SUM(CASE WHEN status = 'REFUNDED' THEN amount ELSE 0.00 END) AS refunded_amount,
    ROUND(
        100.0 * SUM(CASE WHEN status = 'REFUNDED' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS refund_transaction_rate_pct
FROM gateway_txns
GROUP BY merchant_id
ORDER BY merchant_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[success_revenue] = 350.00
""")

save("03_aggregations_and_grouping", "025_multidimensional_olap_rollup_subtotals.sql", """-- ============================================================================
-- EXERCISE: 025_multidimensional_olap_rollup_subtotals.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Financial quarterly reporting requires displaying sales subtotals by Year,
--   subtotals by Year and Quarter, and the Grand Total for all records.
-- PROBLEM STATEMENT:
--   Emulate multidimensional OLAP ROLLUP using unioned grouping sets for
--   universal cross-database engine portability.
-- ============================================================================

DROP TABLE IF EXISTS fiscal_sales;
CREATE TABLE fiscal_sales (
    fiscal_year INT,
    fiscal_quarter VARCHAR(5),
    revenue DECIMAL(10, 2)
);

INSERT INTO fiscal_sales VALUES
(2023, 'Q1', 10000.00),
(2023, 'Q2', 15000.00),
(2024, 'Q1', 20000.00),
(2024, 'Q2', 25000.00);

-- --- [SOLUTION QUERY] ---
-- Emulating ROLLUP(fiscal_year, fiscal_quarter)
SELECT 
    CAST(fiscal_year AS VARCHAR) AS yr,
    fiscal_quarter AS qtr,
    SUM(revenue)   AS total_rev
FROM fiscal_sales
GROUP BY fiscal_year, fiscal_quarter

UNION ALL

SELECT 
    CAST(fiscal_year AS VARCHAR) AS yr,
    'SUBTOTAL'     AS qtr,
    SUM(revenue)   AS total_rev
FROM fiscal_sales
GROUP BY fiscal_year

UNION ALL

SELECT 
    'GRAND TOTAL'  AS yr,
    'ALL'          AS qtr,
    SUM(revenue)   AS total_rev
FROM fiscal_sales
ORDER BY yr ASC, qtr ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 7
-- ASSERT: COL[total_rev] = 25000.00
""")

save("03_aggregations_and_grouping", "026_multidimensional_olap_cube_combinations.sql", """-- ============================================================================
-- EXERCISE: 026_multidimensional_olap_cube_combinations.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Merchandise inventory analytics requires examining revenue across all
--   cross-combinations of Product Category and Store Channel.
-- PROBLEM STATEMENT:
--   Emulate multidimensional OLAP CUBE generating (Category, Channel),
--   (Category, ALL), (ALL, Channel), and (ALL, ALL).
-- ============================================================================

DROP TABLE IF EXISTS channel_sales;
CREATE TABLE channel_sales (
    category VARCHAR(50),
    channel VARCHAR(50),
    revenue DECIMAL(10, 2)
);

INSERT INTO channel_sales VALUES
('Electronics', 'Online', 50000.00),
('Electronics', 'Retail', 30000.00),
('Apparel',     'Online', 20000.00),
('Apparel',     'Retail', 15000.00);

-- --- [SOLUTION QUERY] ---
-- Portable CUBE emulation
SELECT category, channel, SUM(revenue) AS total_revenue FROM channel_sales GROUP BY category, channel
UNION ALL
SELECT category, 'ALL_CHANNELS', SUM(revenue) FROM channel_sales GROUP BY category
UNION ALL
SELECT 'ALL_CATEGORIES', channel, SUM(revenue) FROM channel_sales GROUP BY channel
UNION ALL
SELECT 'ALL_CATEGORIES', 'ALL_CHANNELS', SUM(revenue) FROM channel_sales
ORDER BY category ASC, channel ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 9
-- ASSERT: COL[total_revenue] = 35000.00
""")

save("03_aggregations_and_grouping", "027_grouping_sets_for_targeted_cubes.sql", """-- ============================================================================
-- EXERCISE: 027_grouping_sets_for_targeted_cubes.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Management requires sales reporting at the Brand level, and at the
--   (Country, Region) level, but explicitly does NOT want a full CUBE.
-- PROBLEM STATEMENT:
--   Implement targeted grouping sets to aggregate specific subsets of dimensions.
-- ============================================================================

DROP TABLE IF EXISTS global_sales;
CREATE TABLE global_sales (
    country VARCHAR(50),
    region VARCHAR(50),
    brand VARCHAR(50),
    units INT
);

INSERT INTO global_sales VALUES
('USA', 'East', 'BrandA', 100),
('USA', 'West', 'BrandA', 150),
('USA', 'East', 'BrandB', 80),
('UK',  'South', 'BrandA', 90);

-- --- [SOLUTION QUERY] ---
-- Emulating GROUPING SETS ((country, region), (brand))
SELECT country, region, 'ALL_BRANDS' AS brand, SUM(units) AS total_units
FROM global_sales
GROUP BY country, region
UNION ALL
SELECT 'ALL_COUNTRIES' AS country, 'ALL_REGIONS' AS region, brand, SUM(units) AS total_units
FROM global_sales
GROUP BY brand
ORDER BY country ASC, brand ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[total_units] = 340
""")

save("03_aggregations_and_grouping", "028_relational_pivoting_rows_to_columns.sql", """-- ============================================================================
-- EXERCISE: 028_relational_pivoting_rows_to_columns.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Monthly financial summary tables store sales vertically by month.
--   Executive reporting presentations require pivoting months into horizontal
--   columns (Jan, Feb, Mar) per product.
-- PROBLEM STATEMENT:
--   Pivot relational rows into columns using conditional aggregation.
-- ============================================================================

DROP TABLE IF EXISTS monthly_product_revenue;
CREATE TABLE monthly_product_revenue (
    product_name VARCHAR(50),
    month_name VARCHAR(10),
    revenue DECIMAL(10, 2)
);

INSERT INTO monthly_product_revenue VALUES
('Laptop', 'Jan', 10000.00),
('Laptop', 'Feb', 12000.00),
('Laptop', 'Mar', 15000.00),
('Phone',  'Jan', 8000.00),
('Phone',  'Feb', 9500.00),
('Phone',  'Mar', 11000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    product_name,
    SUM(CASE WHEN month_name = 'Jan' THEN revenue ELSE 0.00 END) AS jan_rev,
    SUM(CASE WHEN month_name = 'Feb' THEN revenue ELSE 0.00 END) AS feb_rev,
    SUM(CASE WHEN month_name = 'Mar' THEN revenue ELSE 0.00 END) AS mar_rev,
    SUM(revenue) AS q1_total_rev
FROM monthly_product_revenue
GROUP BY product_name
ORDER BY product_name ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[jan_rev] = 10000.00
""")

save("03_aggregations_and_grouping", "029_relational_unpivoting_columns_to_rows.sql", """-- ============================================================================
-- EXERCISE: 029_relational_unpivoting_columns_to_rows.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A legacy spreadsheet ingest landed data with quarters as columns
--   (q1_sales, q2_sales, q3_sales). The Lakehouse Kimball schema requires
--   normalizing this into a tall Fact table.
-- PROBLEM STATEMENT:
--   Unpivot wide columns into relational rows using CROSS JOIN / UNION.
-- ============================================================================

DROP TABLE IF EXISTS wide_sales_report;
CREATE TABLE wide_sales_report (
    region VARCHAR(50) PRIMARY KEY,
    q1_sales DECIMAL(10, 2),
    q2_sales DECIMAL(10, 2),
    q3_sales DECIMAL(10, 2)
);

INSERT INTO wide_sales_report VALUES
('North America', 50000.00, 65000.00, 70000.00),
('Europe',        30000.00, 35000.00, 42000.00);

-- --- [SOLUTION QUERY] ---
SELECT region, 'Q1' AS quarter, q1_sales AS sales_amount FROM wide_sales_report
UNION ALL
SELECT region, 'Q2' AS quarter, q2_sales AS sales_amount FROM wide_sales_report
UNION ALL
SELECT region, 'Q3' AS quarter, q3_sales AS sales_amount FROM wide_sales_report
ORDER BY region ASC, quarter ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[sales_amount] = 30000.00
""")

save("03_aggregations_and_grouping", "030_statistical_aggregations_median_and_percentiles.sql", """-- ============================================================================
-- EXERCISE: 030_statistical_aggregations_median_and_percentiles.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Compensation benchmarking requires computing median salary per department.
--   Averages are heavily distorted by C-level outliers.
-- PROBLEM STATEMENT:
--   Calculate the statistical median salary using analytical window functions
--   and row numbering across even and odd partition sizes.
-- ============================================================================

DROP TABLE IF EXISTS compensation;
CREATE TABLE compensation (
    emp_id INT PRIMARY KEY,
    dept VARCHAR(50),
    salary DECIMAL(10, 2)
);

INSERT INTO compensation VALUES
(1, 'Engineering', 90000.00),
(2, 'Engineering', 100000.00),
(3, 'Engineering', 110000.00),
(4, 'Engineering', 120000.00),
(5, 'Engineering', 300000.00); -- Extreme outlier!

-- --- [SOLUTION QUERY] ---
WITH ranked_salaries AS (
    SELECT 
        dept,
        salary,
        ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary ASC) AS rk,
        COUNT(*)     OVER (PARTITION BY dept) AS total_count
    FROM compensation
)
SELECT 
    dept,
    ROUND(AVG(salary), 2) AS median_salary
FROM ranked_salaries
WHERE rk IN ((total_count + 1) / 2, (total_count + 2) / 2)
GROUP BY dept;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[median_salary] = 110000.0
""")

# ==============================================================================
# MODULE 04: Analytical Window Functions Mastery (031 - 045)
# ==============================================================================

save("04_window_functions_mastery", "031_ranking_functions_row_number_rank_dense_rank.sql", """-- ============================================================================
-- EXERCISE: 031_ranking_functions_row_number_rank_dense_rank.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Sales leaderboard computation requires rewarding top performers. When two
--   reps tie for 2nd place, HR policy mandates that the next rep receive 3rd
--   rank (DENSE_RANK) rather than skipping to 4th rank (RANK).
-- PROBLEM STATEMENT:
--   Demonstrate ROW_NUMBER(), RANK(), and DENSE_RANK() side-by-side with tied values.
-- ============================================================================

DROP TABLE IF EXISTS sales_scores;
CREATE TABLE sales_scores (
    rep_id INT PRIMARY KEY,
    rep_name VARCHAR(50),
    score INT
);

INSERT INTO sales_scores VALUES
(1, 'Alice',   100),
(2, 'Bob',     90),
(3, 'Charlie', 90),
(4, 'David',   80),
(5, 'Eve',     70);

-- --- [SOLUTION QUERY] ---
SELECT 
    rep_id,
    rep_name,
    score,
    ROW_NUMBER() OVER (ORDER BY score DESC) AS row_num,
    RANK()       OVER (ORDER BY score DESC) AS rnk,
    DENSE_RANK() OVER (ORDER BY score DESC) AS dense_rnk
FROM sales_scores
ORDER BY score DESC, rep_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[dense_rnk] = 1
""")

save("04_window_functions_mastery", "032_quantile_distribution_ntile_bucketing.sql", """-- ============================================================================
-- EXERCISE: 032_quantile_distribution_ntile_bucketing.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Marketing customer segmentation divides customers into 4 spending quartiles
--   (Top 25% VIP, Upper Middle, Lower Middle, Bottom 25% Low Engagement).
-- PROBLEM STATEMENT:
--   Segment accounts into 4 equal quartiles using NTILE(4) ordered by total spend.
-- ============================================================================

DROP TABLE IF EXISTS customer_spend;
CREATE TABLE customer_spend (
    customer_id INT PRIMARY KEY,
    total_spend DECIMAL(10, 2)
);

INSERT INTO customer_spend VALUES
(1, 12000.00), (2, 8500.00), (3, 6200.00), (4, 5100.00),
(5, 3400.00),  (6, 2100.00), (7, 950.00),  (8, 200.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    customer_id,
    total_spend,
    NTILE(4) OVER (ORDER BY total_spend DESC) AS spend_quartile,
    CASE NTILE(4) OVER (ORDER BY total_spend DESC)
        WHEN 1 THEN 'VIP Tier 1'
        WHEN 2 THEN 'Growth Tier 2'
        WHEN 3 THEN 'Standard Tier 3'
        ELSE 'Low Engagement Tier 4'
    END AS segment_label
FROM customer_spend
ORDER BY total_spend DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 8
-- ASSERT: COL[spend_quartile] = 1
""")

save("04_window_functions_mastery", "033_value_offsets_lag_lead_period_over_period.sql", """-- ============================================================================
-- EXERCISE: 033_value_offsets_lag_lead_period_over_period.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Financial health tracking requires comparing this month's revenue to the
--   previous month to calculate Month-over-Month (MoM) growth rates.
-- PROBLEM STATEMENT:
--   Use LAG() to access the prior month's revenue and compute absolute and
--   percentage change.
-- ============================================================================

DROP TABLE IF EXISTS monthly_mrr;
CREATE TABLE monthly_mrr (
    month_id INT PRIMARY KEY,
    month_str VARCHAR(10),
    mrr_amount DECIMAL(10, 2)
);

INSERT INTO monthly_mrr VALUES
(1, '2024-01', 50000.00),
(2, '2024-02', 55000.00),
(3, '2024-03', 52000.00),
(4, '2024-04', 60000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    month_id,
    month_str,
    mrr_amount,
    LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC) AS prev_month_mrr,
    (mrr_amount - LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC)) AS mom_absolute_growth,
    ROUND(
        100.0 * (mrr_amount - LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC)) / 
        NULLIF(LAG(mrr_amount, 1) OVER (ORDER BY month_id ASC), 0),
        2
    ) AS mom_growth_pct
FROM monthly_mrr
ORDER BY month_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[mom_growth_pct] = 10.0
""")

save("04_window_functions_mastery", "034_navigation_functions_first_last_nth_value.sql", """-- ============================================================================
-- EXERCISE: 034_navigation_functions_first_last_nth_value.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Customer journey attribution requires comparing each touchpoint order amount
--   against both the customer's very first order amount and their latest order amount.
-- PROBLEM STATEMENT:
--   Use FIRST_VALUE() and LAST_VALUE() with explicit window framing
--   (ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) to avoid framing traps.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders_stream;
CREATE TABLE customer_orders_stream (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date TEXT,
    order_amount DECIMAL(10, 2)
);

INSERT INTO customer_orders_stream VALUES
(1, 101, '2024-01-10', 50.00),
(2, 101, '2024-02-15', 120.00),
(3, 101, '2024-03-20', 300.00),
(4, 102, '2024-01-15', 200.00),
(5, 102, '2024-04-01', 180.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    order_id,
    customer_id,
    order_date,
    order_amount,
    FIRST_VALUE(order_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS initial_order_amount,
    LAST_VALUE(order_amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS terminal_order_amount
FROM customer_orders_stream
ORDER BY customer_id ASC, order_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[initial_order_amount] = 50.00
""")

save("04_window_functions_mastery", "035_cumulative_and_running_totals.sql", """-- ============================================================================
-- EXERCISE: 035_cumulative_and_running_totals.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Cashflow forecasting requires calculating a running bank account balance
--   across chronological credits and debits.
-- PROBLEM STATEMENT:
--   Compute running balance using SUM() OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW).
-- ============================================================================

DROP TABLE IF EXISTS account_transactions;
CREATE TABLE account_transactions (
    txn_id INT PRIMARY KEY,
    txn_date TEXT,
    amount DECIMAL(10, 2) -- Positive = Credit, Negative = Debit
);

INSERT INTO account_transactions VALUES
(1, '2024-05-01', 1000.00),
(2, '2024-05-02', -200.00),
(3, '2024-05-03', -150.00),
(4, '2024-05-04', 500.00),
(5, '2024-05-05', -100.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    txn_id,
    txn_date,
    amount,
    SUM(amount) OVER (
        ORDER BY txn_date ASC, txn_id ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM account_transactions
ORDER BY txn_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[running_balance] = 1000.00
""")

save("04_window_functions_mastery", "036_moving_averages_and_rolling_windows.sql", """-- ============================================================================
-- EXERCISE: 036_moving_averages_and_rolling_windows.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Telemetry anomaly detection requires computing a 3-day trailing moving
--   average of server CPU load to filter out transient micro-spikes.
-- PROBLEM STATEMENT:
--   Compute moving average using ROWS BETWEEN 2 PRECEDING AND CURRENT ROW.
-- ============================================================================

DROP TABLE IF EXISTS server_telemetry;
CREATE TABLE server_telemetry (
    day_id INT PRIMARY KEY,
    day_date TEXT,
    avg_cpu_pct DECIMAL(5, 2)
);

INSERT INTO server_telemetry VALUES
(1, '2024-06-01', 45.00),
(2, '2024-06-02', 55.00),
(3, '2024-06-03', 80.00),
(4, '2024-06-04', 60.00),
(5, '2024-06-05', 50.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    day_id,
    day_date,
    avg_cpu_pct,
    ROUND(
        AVG(avg_cpu_pct) OVER (
            ORDER BY day_id ASC
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2
    ) AS rolling_3day_avg_cpu
FROM server_telemetry
ORDER BY day_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[rolling_3day_avg_cpu] = 45.0
""")

save("04_window_functions_mastery", "037_physical_vs_logical_frames_rows_vs_range.sql", """-- ============================================================================
-- EXERCISE: 037_physical_vs_logical_frames_rows_vs_range.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   When computing running totals over duplicate order dates, the default frame
--   RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW groups peer rows together,
--   producing duplicate running totals on the same date!
-- PROBLEM STATEMENT:
--   Demonstrate the critical semantic difference between ROWS (physical offsets)
--   and RANGE (logical peer groups).
-- ============================================================================

DROP TABLE IF EXISTS peer_orders;
CREATE TABLE peer_orders (
    order_id INT PRIMARY KEY,
    order_date TEXT,
    amount DECIMAL(10, 2)
);

INSERT INTO peer_orders VALUES
(1, '2024-05-01', 100.00),
(2, '2024-05-01', 150.00), -- Same date!
(3, '2024-05-02', 200.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    order_id,
    order_date,
    amount,
    -- ROWS advances row by row
    SUM(amount) OVER (
        ORDER BY order_date ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS rows_running_total,
    -- RANGE advances peer group by peer group
    SUM(amount) OVER (
        ORDER BY order_date ASC
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS range_running_total
FROM peer_orders
ORDER BY order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[rows_running_total] = 100.00
""")

save("04_window_functions_mastery", "038_gaps_and_islands_consecutive_streaks.sql", """-- ============================================================================
-- EXERCISE: 038_gaps_and_islands_consecutive_streaks.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Gaming engagement systems reward players who maintain consecutive daily login
--   streaks of 3 or more days.
-- PROBLEM STATEMENT:
--   Solve the classic Gaps & Islands problem using the Date - RowNumber island
--   grouping method.
-- ============================================================================

DROP TABLE IF EXISTS player_logins;
CREATE TABLE player_logins (
    player_id INT,
    login_date TEXT, -- YYYY-MM-DD
    PRIMARY KEY (player_id, login_date)
);

INSERT INTO player_logins VALUES
(1, '2024-05-01'),
(1, '2024-05-02'),
(1, '2024-05-03'), -- Streak 1: 3 days
(1, '2024-05-05'),
(1, '2024-05-06'); -- Streak 2: 2 days

-- --- [SOLUTION QUERY] ---
WITH ranked_logins AS (
    SELECT 
        player_id,
        login_date,
        -- Subtracting row_number days from login_date yields a constant anchor date for consecutive days
        DATE(login_date, '-' || (ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY login_date ASC)) || ' days') AS island_anchor
    FROM player_logins
)
SELECT 
    player_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*) AS streak_length_days
FROM ranked_logins
GROUP BY player_id, island_anchor
HAVING COUNT(*) >= 3
ORDER BY streak_start ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[streak_length_days] = 3
""")

save("04_window_functions_mastery", "039_gaps_and_islands_threshold_sessionization.sql", """-- ============================================================================
-- EXERCISE: 039_gaps_and_islands_threshold_sessionization.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Web traffic analytics sessionizer: consecutive page clicks separated by
--   less than 30 minutes (1800 seconds) belong to the same session. A gap
--   greater than 30 minutes starts a new session ID.
-- PROBLEM STATEMENT:
--   Detect gaps using LAG() and generate sequential session IDs using a
--   cumulative sum over the gap boundary indicator.
-- ============================================================================

DROP TABLE IF EXISTS clickstream;
CREATE TABLE clickstream (
    click_id INT PRIMARY KEY,
    user_id INT,
    click_epoch INT -- Epoch seconds
);

INSERT INTO clickstream VALUES
(1, 101, 1000),
(2, 101, 1500), -- 500s gap (same session)
(3, 101, 4000), -- 2500s gap (>1800s -> New session!)
(4, 101, 4200); -- 200s gap (same session)

-- --- [SOLUTION QUERY] ---
WITH flag_boundaries AS (
    SELECT 
        click_id,
        user_id,
        click_epoch,
        CASE 
            WHEN click_epoch - LAG(click_epoch) OVER (PARTITION BY user_id ORDER BY click_epoch ASC) > 1800 
                 OR LAG(click_epoch) OVER (PARTITION BY user_id ORDER BY click_epoch ASC) IS NULL 
            THEN 1 
            ELSE 0 
        END AS is_new_session
    FROM clickstream
)
SELECT 
    click_id,
    user_id,
    click_epoch,
    SUM(is_new_session) OVER (
        PARTITION BY user_id 
        ORDER BY click_epoch ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS session_id
FROM flag_boundaries
ORDER BY click_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[session_id] = 1
""")

save("04_window_functions_mastery", "040_gaps_and_islands_overlapping_interval_merging.sql", """-- ============================================================================
-- EXERCISE: 040_gaps_and_islands_overlapping_interval_merging.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Hotel room booking intervals or fleet vehicle maintenance reservations
--   can overlap. Management needs to collapse overlapping booking dates into
--   contiguous booked blocks to calculate true occupancy duration.
-- PROBLEM STATEMENT:
--   Merge overlapping date intervals using windowed running maximums.
-- ============================================================================

DROP TABLE IF EXISTS booking_intervals;
CREATE TABLE booking_intervals (
    room_id INT,
    start_date TEXT,
    end_date TEXT
);

INSERT INTO booking_intervals VALUES
(1, '2024-05-01', '2024-05-05'),
(1, '2024-05-03', '2024-05-08'), -- Overlaps with booking 1!
(1, '2024-05-12', '2024-05-15'); -- Disjoint booking

-- --- [SOLUTION QUERY] ---
WITH max_prev_end AS (
    SELECT 
        room_id,
        start_date,
        end_date,
        MAX(end_date) OVER (
            PARTITION BY room_id 
            ORDER BY start_date ASC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS max_prev_end_date
    FROM booking_intervals
),
island_starts AS (
    SELECT 
        room_id,
        start_date,
        end_date,
        CASE 
            WHEN max_prev_end_date IS NULL OR start_date > max_prev_end_date THEN 1 
            ELSE 0 
        END AS is_island_start
    FROM max_prev_end
),
island_groups AS (
    SELECT 
        room_id,
        start_date,
        end_date,
        SUM(is_island_start) OVER (
            PARTITION BY room_id 
            ORDER BY start_date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS group_id
    FROM island_starts
)
SELECT 
    room_id,
    MIN(start_date) AS merged_start_date,
    MAX(end_date)   AS merged_end_date
FROM island_groups
GROUP BY room_id, group_id
ORDER BY merged_start_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[merged_end_date] = 2024-05-08
""")

save("04_window_functions_mastery", "041_running_peak_and_maximum_drawdown.sql", """-- ============================================================================
-- EXERCISE: 041_running_peak_and_maximum_drawdown.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Hedge fund risk systems calculate Maximum Drawdown (MDD) — the maximum peak-to-trough
--   percentage drop in asset portfolio value before a new peak is reached.
-- PROBLEM STATEMENT:
--   Calculate running peak and drawdown percentage using MAX() OVER (...) and arithmetic.
-- ============================================================================

DROP TABLE IF EXISTS portfolio_nav;
CREATE TABLE portfolio_nav (
    nav_date TEXT PRIMARY KEY,
    portfolio_value DECIMAL(10, 2)
);

INSERT INTO portfolio_nav VALUES
('2024-01-01', 10000.00),
('2024-01-02', 12000.00), -- Peak 1
('2024-01-03', 9000.00),  -- Drop 25% from 12k
('2024-01-04', 15000.00), -- New Peak 2
('2024-01-05', 13500.00); -- Drop 10% from 15k

-- --- [SOLUTION QUERY] ---
WITH peaks AS (
    SELECT 
        nav_date,
        portfolio_value,
        MAX(portfolio_value) OVER (
            ORDER BY nav_date ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_peak
    FROM portfolio_nav
)
SELECT 
    nav_date,
    portfolio_value,
    running_peak,
    ROUND(100.0 * (portfolio_value - running_peak) / running_peak, 2) AS drawdown_pct
FROM peaks
ORDER BY nav_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[drawdown_pct] = 0.0
""")

save("04_window_functions_mastery", "042_year_over_year_and_month_over_month_growth.sql", """-- ============================================================================
-- EXERCISE: 042_year_over_year_and_month_over_month_growth.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Annual financial reporting requires comparing monthly sales against the
--   exact same calendar month from the prior year (YoY Growth).
-- PROBLEM STATEMENT:
--   Calculate Year-over-Year (YoY) revenue percentage using self-joins or LAG(12).
-- ============================================================================

DROP TABLE IF EXISTS annual_monthly_sales;
CREATE TABLE annual_monthly_sales (
    yr INT,
    mo INT,
    sales DECIMAL(10, 2),
    PRIMARY KEY (yr, mo)
);

INSERT INTO annual_monthly_sales VALUES
(2023, 1, 100000.00),
(2023, 2, 110000.00),
(2024, 1, 125000.00),
(2024, 2, 130000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    curr.yr,
    curr.mo,
    curr.sales AS current_year_sales,
    prev.sales AS prior_year_sales,
    ROUND(100.0 * (curr.sales - prev.sales) / prev.sales, 2) AS yoy_growth_pct
FROM annual_monthly_sales curr
LEFT JOIN annual_monthly_sales prev 
    ON curr.yr = prev.yr + 1 
    AND curr.mo = prev.mo
WHERE curr.yr = 2024
ORDER BY curr.mo ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[yoy_growth_pct] = 25.0
""")

save("04_window_functions_mastery", "043_customer_retention_cohort_curves.sql", """-- ============================================================================
-- EXERCISE: 043_customer_retention_cohort_curves.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Product analytics cohorts: Group users by acquisition month and calculate
--   the retention rate in subsequent activity months (Month 0, Month 1, Month 2).
-- PROBLEM STATEMENT:
--   Build a classic cohort retention matrix in SQL.
-- ============================================================================

DROP TABLE IF EXISTS user_activities;
DROP TABLE IF EXISTS user_first_seen;

CREATE TABLE user_activities (
    user_id INT,
    activity_month INT -- Month offset: 1 = Jan, 2 = Feb, 3 = Mar
);

INSERT INTO user_activities VALUES
(1, 1), (1, 2), (1, 3),
(2, 1), (2, 2),
(3, 1),
(4, 2), (4, 3);

-- --- [SOLUTION QUERY] ---
WITH cohort_assignment AS (
    SELECT 
        user_id,
        MIN(activity_month) AS cohort_month
    FROM user_activities
    GROUP BY user_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(user_id) AS total_cohort_users
    FROM cohort_assignment
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT 
        c.cohort_month,
        a.activity_month - c.cohort_month AS month_number,
        COUNT(DISTINCT a.user_id) AS active_users
    FROM user_activities a
    JOIN cohort_assignment c ON a.user_id = c.user_id
    GROUP BY c.cohort_month, month_number
)
SELECT 
    ca.cohort_month,
    ca.month_number,
    ca.active_users,
    cs.total_cohort_users,
    ROUND(100.0 * ca.active_users / cs.total_cohort_users, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month ASC, ca.month_number ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[retention_pct] = 100.0
""")

save("04_window_functions_mastery", "044_top_n_per_category_deterministic_ties.sql", """-- ============================================================================
-- EXERCISE: 044_top_n_per_category_deterministic_ties.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   E-commerce homepage display: show top 2 bestselling items per category.
--   When items tie in sales, tie-breaking must be strictly deterministic by product_id.
-- PROBLEM STATEMENT:
--   Implement Top-2 per category using DENSE_RANK() or ROW_NUMBER() with tie-breaking.
-- ============================================================================

DROP TABLE IF EXISTS catalog_products;
CREATE TABLE catalog_products (
    product_id INT PRIMARY KEY,
    category VARCHAR(50),
    units_sold INT
);

INSERT INTO catalog_products VALUES
(1, 'Audio', 500),
(2, 'Audio', 500), -- Tie!
(3, 'Audio', 200),
(4, 'Video', 900),
(5, 'Video', 750),
(6, 'Video', 300);

-- --- [SOLUTION QUERY] ---
WITH ranked_products AS (
    SELECT 
        category,
        product_id,
        units_sold,
        ROW_NUMBER() OVER (
            PARTITION BY category 
            ORDER BY units_sold DESC, product_id ASC -- Deterministic tie breaker
        ) AS rank_in_cat
    FROM catalog_products
)
SELECT 
    category,
    product_id,
    units_sold,
    rank_in_cat
FROM ranked_products
WHERE rank_in_cat <= 2
ORDER BY category ASC, rank_in_cat ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[units_sold] = 500
""")

save("04_window_functions_mastery", "045_windowed_aggregates_without_group_by.sql", """-- ============================================================================
-- EXERCISE: 045_windowed_aggregates_without_group_by.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Payroll transparency analysis: Show each employee's salary alongside their
--   department total payroll and their personal percentage contribution, without
--   collapsing the individual employee rows.
-- PROBLEM STATEMENT:
--   Compute ratio-to-report using SUM() OVER (PARTITION BY dept) without GROUP BY.
-- ============================================================================

DROP TABLE IF EXISTS staff_salaries;
CREATE TABLE staff_salaries (
    staff_id INT PRIMARY KEY,
    staff_name VARCHAR(50),
    dept VARCHAR(50),
    salary DECIMAL(10, 2)
);

INSERT INTO staff_salaries VALUES
(1, 'Alice',   'Finance', 8000.00),
(2, 'Bob',     'Finance', 12000.00),
(3, 'Charlie', 'IT',      10000.00),
(4, 'David',   'IT',      15000.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    staff_id,
    staff_name,
    dept,
    salary,
    SUM(salary) OVER (PARTITION BY dept) AS dept_total_payroll,
    ROUND(100.0 * salary / SUM(salary) OVER (PARTITION BY dept), 2) AS pct_of_dept_payroll
FROM staff_salaries
ORDER BY dept ASC, salary DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[dept_total_payroll] = 20000.00
""")

print("Module 03 and Module 04 generation complete!")
