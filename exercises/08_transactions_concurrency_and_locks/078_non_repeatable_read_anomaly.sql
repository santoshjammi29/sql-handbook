-- ============================================================================
-- EXERCISE: 078_non_repeatable_read_anomaly.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Staff Database Architect & Distributed Storage Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Tier Inventory Rebalancing & Warehouse Allocation Service.
--   Non-Repeatable Read (Fuzzy Read) Anomaly:
--   - Under READ COMMITTED isolation: Transaction A reads SKU stock at T1 (finds 50 units).
--   - Concurrently, Transaction B issues UPDATE deducting 30 units and commits at T2.
--   - Transaction A re-reads the exact same SKU at T3 within the same transaction and finds 20 units!
--   The values changed inside Transaction A's single atomic unit of work!
--
-- BUSINESS CONTEXT:
--   Automated inventory replenishment and allocation batch processes generate erroneous
--   purchase orders when successive queries within an audit run see shifting stock numbers.
--   Under REPEATABLE READ or Snapshot Isolation, the database engine freezes the visible
--   snapshot view at transaction initiation timestamp T0.
--
-- PROBLEM STATEMENT:
--   Model a temporal snapshot inventory ledger tracking warehouse SKU stock across
--   snapshot points (T1 = 10:00:00 and T2 = 10:05:00). Write an analytical query
--   demonstrating how a Repeatable Read snapshot freezes the point-in-time value
--   at T1 (100 units) regardless of subsequent committed deductions.
-- ============================================================================

DROP TABLE IF EXISTS inventory_mutation_log;
DROP TABLE IF EXISTS warehouse_sku_inventory;

CREATE TABLE warehouse_sku_inventory (
    sku_id VARCHAR(32) PRIMARY KEY,
    warehouse_id VARCHAR(20) NOT NULL,
    base_stock_units INT NOT NULL
);

CREATE TABLE inventory_mutation_log (
    mutation_id INT PRIMARY KEY,
    sku_id VARCHAR(32) NOT NULL,
    delta_units INT NOT NULL,
    committed_at TEXT NOT NULL,
    tx_id INT NOT NULL,
    FOREIGN KEY (sku_id) REFERENCES warehouse_sku_inventory(sku_id)
);

INSERT INTO warehouse_sku_inventory VALUES
('SKU-GRAPHICS-CARD', 'WH-CENTRAL-01', 100);

-- Concurrent Transaction commits at 10:02:00
INSERT INTO inventory_mutation_log VALUES
(1, 'SKU-GRAPHICS-CARD', -35, '2024-06-01 10:02:00', 5002);

-- --- [SOLUTION QUERY] ---
-- Simulates REPEATABLE READ snapshot consistency at T1 ('2024-06-01 10:00:00')
-- vs READ COMMITTED view at current time ('2024-06-01 10:05:00')
WITH snapshot_t1_view AS (
    SELECT 
        i.sku_id,
        i.warehouse_id,
        i.base_stock_units + COALESCE(SUM(CASE WHEN m.committed_at <= '2024-06-01 10:00:00' THEN m.delta_units ELSE 0 END), 0) AS stock_at_repeatable_read_t1
    FROM warehouse_sku_inventory i
    LEFT JOIN inventory_mutation_log m ON i.sku_id = m.sku_id
    GROUP BY i.sku_id, i.warehouse_id, i.base_stock_units
),
current_committed_view AS (
    SELECT 
        i.sku_id,
        i.base_stock_units + COALESCE(SUM(m.delta_units), 0) AS stock_at_read_committed_t2
    FROM warehouse_sku_inventory i
    LEFT JOIN inventory_mutation_log m ON i.sku_id = m.sku_id
    GROUP BY i.sku_id, i.base_stock_units
)
SELECT 
    t1.sku_id,
    t1.warehouse_id,
    t1.stock_at_repeatable_read_t1,
    t2.stock_at_read_committed_t2,
    (t1.stock_at_repeatable_read_t1 - t2.stock_at_read_committed_t2) AS committed_drift_delta,
    'REPEATABLE_READ_PROTECTS_AGAINST_FUZZY_DRIFT' AS concurrency_mechanism
FROM snapshot_t1_view t1
INNER JOIN current_committed_view t2 ON t1.sku_id = t2.sku_id;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[sku_id] = SKU-GRAPHICS-CARD
-- ASSERT: COL[stock_at_repeatable_read_t1] = 100
-- ASSERT: COL[stock_at_read_committed_t2] = 65
-- ASSERT: COL[committed_drift_delta] = 35\n