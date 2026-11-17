-- ============================================================================
-- EXERCISE: 055_deterministic_duplicate_deletion.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Quality Architect & Lakehouse Recovery Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Production Streaming Deduplication & Table Cleaning.
--   A Kafka CDC retry bug duplicated thousands of order rows in a relational mart.
--   SREs must safely prune duplicates, keeping strictly the earliest landed record.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 055 deterministic duplicate deletion.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 055 deterministic duplicate deletion.
-- ============================================================================

DROP TABLE IF EXISTS dirty_payment_stream;

CREATE TABLE dirty_payment_stream (
    row_surrogate_id INT PRIMARY KEY,
    transaction_uuid VARCHAR(36) NOT NULL,
    amount_usd DECIMAL(12, 2) NOT NULL,
    landed_timestamp TEXT NOT NULL
);

INSERT INTO dirty_payment_stream VALUES
(1, 'TXN-ABC-01', 1200.00, '2024-05-01 10:00:00'), -- Keep (Earliest)
(2, 'TXN-ABC-01', 1200.00, '2024-05-01 10:00:02'), -- Duplicate to delete!
(3, 'TXN-ABC-01', 1200.00, '2024-05-01 10:00:05'), -- Duplicate to delete!
(4, 'TXN-XYZ-02',  850.00, '2024-05-01 10:05:00'), -- Unique
(5, 'TXN-QWE-03',  420.00, '2024-05-01 10:10:00'); -- Unique

-- --- [SOLUTION QUERY] ---
-- Deterministic duplicate deletion: Delete all records with row_num > 1
DELETE FROM dirty_payment_stream
WHERE row_surrogate_id IN (
    SELECT row_surrogate_id
    FROM (
        SELECT 
            row_surrogate_id,
            ROW_NUMBER() OVER (
                PARTITION BY transaction_uuid 
                ORDER BY landed_timestamp ASC, row_surrogate_id ASC
            ) AS occurrence_rank
        FROM dirty_payment_stream
    )
    WHERE occurrence_rank > 1
);

SELECT 
    row_surrogate_id,
    transaction_uuid,
    amount_usd,
    landed_timestamp
FROM dirty_payment_stream
ORDER BY row_surrogate_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[row_surrogate_id] = 1
