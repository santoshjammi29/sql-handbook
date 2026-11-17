-- ============================================================================
-- EXERCISE: 098_incident_out_of_order_cdc_timeline_corruption.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Out-of-Order CDC Timeline Corruption.
--   Network delay caused a 10:00 AM customer address change to arrive AFTER
--   a 10:05 AM change in the Kafka topic. Both records were marked is_current = 1,
--   causing duplicate rows and invalid tax calculations in downstream orders!
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Execute a self-healing reconstruction query using LEAD() and ROW_NUMBER().
-- ============================================================================

DROP TABLE IF EXISTS raw_corrupted_cdc;
CREATE TABLE raw_corrupted_cdc (
    customer_id INT,
    address VARCHAR(100),
    event_time TEXT
);

INSERT INTO raw_corrupted_cdc VALUES
(101, '100 Broadway, NY', '2024-05-01 10:00:00'),
(101, '500 Market St, CA', '2024-05-01 10:05:00');

-- --- [SOLUTION QUERY] ---
-- Deterministic self-healing timeline rebuilder
WITH sequenced AS (
    SELECT 
        customer_id,
        address,
        event_time AS valid_from,
        COALESCE(
            LEAD(event_time) OVER (PARTITION BY customer_id ORDER BY event_time ASC),
            '9999-12-31 23:59:59'
        ) AS valid_to,
        CASE 
            WHEN LEAD(event_time) OVER (PARTITION BY customer_id ORDER BY event_time ASC) IS NULL THEN 1
            ELSE 0
        END AS is_current
    FROM raw_corrupted_cdc
)
SELECT customer_id, address, valid_from, valid_to, is_current
FROM sequenced
ORDER BY valid_from ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[is_current] = 0
