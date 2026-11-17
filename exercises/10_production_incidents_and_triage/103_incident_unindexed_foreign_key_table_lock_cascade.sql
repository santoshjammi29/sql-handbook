-- ============================================================================
-- EXERCISE: 103_incident_unindexed_foreign_key_table_lock_cascade.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead OLTP Database Administrator & Performance Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   PRODUCTION INCIDENT POSTMORTEM: Unindexed Foreign Key Table-Lock Cascade.
--   During business hours, an administrative script deleted an inactive customer:
--   `DELETE FROM customers WHERE customer_id = 'CUST-OLD-99';`
--   Instantly, the entire 25-million row `child_order_history` table locked with a Table Share Lock.
--   All incoming customer checkouts blocked in lock wait for 45 seconds, collapsing storefront SLAs.
--
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT ROOT CAUSE:
--   The child table `child_order_history` had a FOREIGN KEY referencing `customers(customer_id)`,
--   but NO INDEX on `customer_id`!
--   To verify that no child orders referenced the deleted customer, the engine acquired
--   a full table-level share lock on `child_order_history` and initiated a full sequential table scan!
--
-- PROBLEM STATEMENT:
--   SURGICAL TRIAGE & REMEDIATION:
--   MANDATORY ARCHITECTURAL RULE: Every Foreign Key column in a child table MUST have
--   an explicit supporting B-Tree index:
--   `CREATE INDEX idx_orders_customer_id ON child_order_history(customer_id);`
--   This converts a 45-second table lock scan into an instantaneous O(log N) index seek.
-- ============================================================================

DROP TABLE IF EXISTS child_order_history;
DROP TABLE IF EXISTS parent_customer_registry;

CREATE TABLE parent_customer_registry (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL
);

CREATE TABLE child_order_history (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_total_usd DECIMAL(12, 2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES parent_customer_registry(customer_id)
);

-- Crucial mitigation: Explicit Foreign Key index prevents table lock escalation
CREATE INDEX idx_child_orders_fk_cust ON child_order_history(customer_id);

INSERT INTO parent_customer_registry VALUES
('CUST-ACTIVE-01', 'Alice Smith'),
('CUST-INACTIVE-99', 'Ghost Account');

INSERT INTO child_order_history VALUES
('ORD-101', 'CUST-ACTIVE-01', 250.00);

-- Safe deletion of parent customer with index-backed referential validation
DELETE FROM parent_customer_registry WHERE customer_id = 'CUST-INACTIVE-99';

-- --- [SOLUTION QUERY] ---
-- Query auditing remaining parent registry and child order association
SELECT 
    p.customer_id,
    p.customer_name,
    COUNT(c.order_id) AS total_active_orders,
    COALESCE(SUM(c.order_total_usd), 0.00) AS total_spend_usd,
    'INDEX_SEEK_PREVENTS_TABLE_LOCK_ESCALATION' AS lock_behavior
FROM parent_customer_registry p
LEFT JOIN child_order_history c ON p.customer_id = c.customer_id
GROUP BY p.customer_id, p.customer_name;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[customer_id] = CUST-ACTIVE-01
-- ASSERT: COL[total_active_orders] = 1
-- ASSERT: COL[total_spend_usd] = 250.0\n