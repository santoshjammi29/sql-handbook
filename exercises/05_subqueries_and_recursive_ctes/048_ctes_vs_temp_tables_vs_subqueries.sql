-- ============================================================================
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
