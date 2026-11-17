-- ============================================================================
-- EXERCISE: 098_incident_out_of_order_cdc_timeline_corruption.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🟣<br>Architect
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Principal Event-Driven Architect & Distributed Stream Processing Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Out-of-Order CDC Timeline Corruption.
--
-- BUSINESS CONTEXT:
--   Due to network partitions and Kafka partition consumer group rebalancing,
--   Change Data Capture (CDC) events arrived out of chronological sequence.
--   Customer CUST-101 updated their primary shipping address:
--   - Event 1: At 10:00:00 moved to '100 Broadway, NY'.
--   - Event 2: At 10:05:00 moved to '500 Market St, CA'.
--   The 10:05:00 event was processed FIRST, followed by the 10:00:00 event!
--   The naive ingestion pipeline set `is_current = 1` on the latest arrived record (the 10:00:00 event!),
--   corrupting the customer's active location and causing $1.4M in state tax miscalculations.
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   Execute a deterministic SQL self-healing reconciliation pipeline using window functions
--   (`LEAD` and `ROW_NUMBER`) over the true source event timestamp (`event_timestamp`),
--   reconstructing seamless, non-overlapping SCD Type 2 intervals (`valid_from`, `valid_to`, `is_current`).
-- ============================================================================

DROP TABLE IF EXISTS raw_corrupted_cdc_events;

CREATE TABLE raw_corrupted_cdc_events (
    event_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    address_line VARCHAR(100) NOT NULL,
    state_code VARCHAR(2) NOT NULL,
    event_timestamp TEXT NOT NULL,
    ingested_at TEXT NOT NULL -- Notice out-of-order ingestion times!
);

-- Ingested out of order: 10:05 event arrived at 10:06; 10:00 event arrived late at 10:08!
INSERT INTO raw_corrupted_cdc_events VALUES
('EVT-002', 'CUST-101', '500 Market St', 'CA', '2024-06-01 10:05:00', '2024-06-01 10:06:00'),
('EVT-001', 'CUST-101', '100 Broadway',  'NY', '2024-06-01 10:00:00', '2024-06-01 10:08:00');

-- --- [SOLUTION QUERY] ---
-- Self-healing deterministic timeline reconstruction query
WITH sequenced_cdc_events AS (
    SELECT 
        customer_id,
        address_line,
        state_code,
        event_timestamp AS valid_from,
        COALESCE(
            LEAD(event_timestamp) OVER (
                PARTITION BY customer_id 
                ORDER BY event_timestamp ASC
            ),
            '9999-12-31 23:59:59'
        ) AS valid_to,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY event_timestamp DESC
        ) AS recency_rank
    FROM raw_corrupted_cdc_events
)
SELECT 
    customer_id,
    address_line,
    state_code,
    valid_from,
    valid_to,
    CASE WHEN recency_rank = 1 THEN 1 ELSE 0 END AS is_current,
    'DETERMINISTIC_SELF_HEALING_SCD2_REPAIRED' AS audit_status
FROM sequenced_cdc_events
ORDER BY valid_from ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[customer_id] = CUST-101
-- ASSERT: COL[valid_from] = 2024-06-01 10:00:00
-- ASSERT: COL[valid_to] = 2024-06-01 10:05:00
-- ASSERT: COL[is_current] = 0\n