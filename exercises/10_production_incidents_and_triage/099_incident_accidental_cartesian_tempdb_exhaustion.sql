-- ============================================================================
-- EXERCISE: 099_incident_accidental_cartesian_tempdb_exhaustion.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Accidental Cartesian TempDB Exhaustion.
--   A developer joined orders to order_discounts on promo_code without realizing
--   promo_code was non-unique, causing a 10M x 10M row explosion that exhausted
--   warehouse temp storage.
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Deduplicate dimension to unique promo_code grain before joining!
-- ============================================================================

DROP TABLE IF EXISTS incident_orders;
DROP TABLE IF EXISTS non_unique_discounts;

CREATE TABLE incident_orders (order_id INT PRIMARY KEY, promo_code VARCHAR(20), amount DECIMAL(10, 2));
CREATE TABLE non_unique_discounts (promo_code VARCHAR(20), discount_pct DECIMAL(4, 2), created_at TEXT);

INSERT INTO incident_orders VALUES (1, 'SUMMER', 100.00), (2, 'SUMMER', 200.00);
-- Non-unique promo codes in discount table!
INSERT INTO non_unique_discounts VALUES ('SUMMER', 10.0, '2024-05-01'), ('SUMMER', 15.0, '2024-05-02');

-- --- [SOLUTION QUERY] ---
-- Pre-deduplicate discount table to ensure 1:1 join relationship
WITH unique_discounts AS (
    SELECT 
        promo_code,
        discount_pct,
        ROW_NUMBER() OVER (PARTITION BY promo_code ORDER BY created_at DESC) AS rn
    FROM non_unique_discounts
)
SELECT 
    o.order_id,
    o.promo_code,
    o.amount,
    d.discount_pct,
    ROUND(o.amount * (1.0 - d.discount_pct / 100.0), 2) AS net_amount
FROM incident_orders o
JOIN unique_discounts d ON o.promo_code = d.promo_code AND d.rn = 1
ORDER BY o.order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[net_amount] = 85.00
