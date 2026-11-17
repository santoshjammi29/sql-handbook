-- ============================================================================
-- EXERCISE: 017_lateral_joins_and_cross_apply_expansions.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & High-Throughput Analytics Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Customer 360 & Top-N Recent Purchase Attribution Engine.
--   Analytical mart querying top-tier enterprise accounts and dynamically fetching
--   their Top-2 highest-value closed transactions without generating expensive
--   full-table window sorts across millions of irrelevant historical rows.
--
-- BUSINESS CONTEXT:
--   In PostgreSQL, DuckDB, and BigQuery, LATERAL joins allow a subquery in the FROM
--   clause to reference columns provided by preceding FROM items (like a for-each loop in SQL).
--   In standard ANSI SQL / SQLite, this is emulated using correlated subqueries or window
--   qualifications to achieve identical query semantics and execution efficiency.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 017 lateral joins and cross apply expansions.
-- ============================================================================

DROP TABLE IF EXISTS customer_transactions;
DROP TABLE IF EXISTS enterprise_clients;

CREATE TABLE enterprise_clients (
    client_id VARCHAR(32) PRIMARY KEY,
    client_name VARCHAR(100) NOT NULL,
    industry_tier VARCHAR(30) NOT NULL
);

CREATE TABLE customer_transactions (
    txn_id VARCHAR(32) PRIMARY KEY,
    client_id VARCHAR(32) NOT NULL,
    txn_amount_usd DECIMAL(12, 2) NOT NULL,
    txn_timestamp TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES enterprise_clients(client_id)
);

INSERT INTO enterprise_clients VALUES
('CL-01', 'Acme Aerospace Corp', 'DEFENSE'),
('CL-02', 'Globex BioTech Group', 'HEALTHCARE'),
('CL-03', 'Starlight Energy Ltd', 'UTILITIES');

INSERT INTO customer_transactions VALUES
('TX-101', 'CL-01', 450000.00, '2024-05-01 10:00:00'),
('TX-102', 'CL-01', 820000.00, '2024-05-02 11:30:00'),
('TX-103', 'CL-01', 120000.00, '2024-05-03 14:00:00'),
('TX-104', 'CL-02', 210000.00, '2024-05-01 09:15:00'),
('TX-105', 'CL-02', 380000.00, '2024-05-02 16:45:00'),
('TX-106', 'CL-02', 95000.00,  '2024-05-03 10:30:00'),
('TX-107', 'CL-03', 600000.00, '2024-05-01 12:00:00');

-- --- [SOLUTION QUERY] ---
-- Standard ANSI SQL correlated ranking: Extracts Top-2 highest-value transactions per client
WITH ranked_client_txns AS (
    SELECT 
        c.client_id,
        c.client_name,
        c.industry_tier,
        t.txn_id,
        t.txn_amount_usd,
        t.txn_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.client_id 
            ORDER BY t.txn_amount_usd DESC, t.txn_timestamp DESC
        ) AS rank_within_client
    FROM enterprise_clients c
    INNER JOIN customer_transactions t ON c.client_id = t.client_id
)
SELECT 
    client_id,
    client_name,
    industry_tier,
    rank_within_client,
    txn_id,
    txn_amount_usd,
    txn_timestamp
FROM ranked_client_txns
WHERE rank_within_client <= 2
ORDER BY client_id ASC, rank_within_client ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[client_id] = CL-01
