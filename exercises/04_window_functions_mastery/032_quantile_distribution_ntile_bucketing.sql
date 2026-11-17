-- ============================================================================
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
