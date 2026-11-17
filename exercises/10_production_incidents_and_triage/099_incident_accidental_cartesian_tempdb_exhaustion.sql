-- ============================================================================
-- EXERCISE: 099_incident_accidental_cartesian_tempdb_exhaustion.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Principal Database Administrator & SQL Performance Triage Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Accidental Cartesian TempDB Storage Exhaustion.
--   At 08:30 EST, an ad-hoc promotional attribution report crashed the primary EDW cluster.
--   Within 3 minutes, local NVMe TempDB filled 750GB of disk space before terminating
--   with `OutOfDiskSpaceException: TempDB table space exhausted`.
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   The analyst joined `fact_orders` to `dim_promotions` on `promo_code`:
--   `SELECT ... FROM fact_orders o JOIN dim_promotions p ON o.promo_code = p.promo_code`
--   The analyst assumed `promo_code` was unique in `dim_promotions`.
--   In reality, `dim_promotions` contained multiple regional discount rules per promo code.
--   Joining 5 million orders against non-unique promotions produced an exponential 1:N fan-out,
--   multiplying order counts and ballooning intermediate hash tables into a 25-Trillion row Cartesian spill!
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   Pre-deduplicate the dimensional side using a CTE with deterministic tie-breaking:
--   `ROW_NUMBER() OVER (PARTITION BY promo_code ORDER BY effective_timestamp DESC)`
--   Filter strictly `WHERE rn = 1` before performing the join, guaranteeing a strict 1:1 join grain.
-- ============================================================================

DROP TABLE IF EXISTS non_unique_promotions;
DROP TABLE IF EXISTS incident_fact_orders;

CREATE TABLE incident_fact_orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    promo_code VARCHAR(30) NOT NULL,
    gross_order_usd DECIMAL(12, 2) NOT NULL
);

CREATE TABLE non_unique_promotions (
    promo_code VARCHAR(30) NOT NULL,
    discount_pct DECIMAL(5, 2) NOT NULL,
    created_at TEXT NOT NULL
);

INSERT INTO incident_fact_orders VALUES
('ORD-5001', 'CUST-A', 'SUMMER2024', 1000.00),
('ORD-5002', 'CUST-B', 'SUMMER2024', 2000.00);

-- Duplicate promo codes in dimension (regional campaign revisions):
INSERT INTO non_unique_promotions VALUES
('SUMMER2024', 10.00, '2024-05-01 00:00:00'),
('SUMMER2024', 15.00, '2024-05-15 00:00:00'); -- Latest active promotion

-- --- [SOLUTION QUERY] ---
-- Production recovery: Pre-deduplicate dimension to guarantee 1:1 join grain
WITH unique_dim_promotions AS (
    SELECT 
        promo_code,
        discount_pct,
        ROW_NUMBER() OVER (
            PARTITION BY promo_code 
            ORDER BY created_at DESC
        ) AS dedupe_rank
    FROM non_unique_promotions
)
SELECT 
    o.order_id,
    o.customer_id,
    o.promo_code,
    o.gross_order_usd,
    p.discount_pct AS applied_discount_pct,
    ROUND(o.gross_order_usd * (1.0 - p.discount_pct / 100.0), 2) AS net_discounted_usd,
    'CARTESIAN_PREVENTED_1_TO_1_GRAIN' AS join_safety_status
FROM incident_fact_orders o
INNER JOIN unique_dim_promotions p 
    ON o.promo_code = p.promo_code 
   AND p.dedupe_rank = 1
ORDER BY o.order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[order_id] = ORD-5001
-- ASSERT: COL[applied_discount_pct] = 15.0
-- ASSERT: COL[net_discounted_usd] = 850.0\n