-- ============================================================================
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
