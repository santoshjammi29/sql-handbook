-- ============================================================================
-- EXERCISE: 012_semi_joins_and_duplicate_multiplier_prevention.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Senior Data Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   E-Commerce Order Management & Fulfillment Reconciliation Mart.
--   A classic enterprise reporting bug: joining orders (1 row per order) with
--   shipment packages (multiple packages per order) to filter for shipped orders,
--   which accidentally duplicates the order header rows and inflates gross revenue by 2x-5x!
--
-- BUSINESS CONTEXT:
--   Finance needs to calculate total gross revenue of all orders that have at least
--   one expedited express delivery line item.
--   1. An INNER JOIN orders on line_items creates a 1:N fan-out multiplier: an order
--      with 4 expedited items gets multiplied by 4 in the SUM(order_total)!
--   2. A SEMI-JOIN using 'WHERE EXISTS (SELECT 1 ...)' matches the existence of a child
--      record and immediately halts evaluation for that order row, completely preventing
--      the cartesian multiplier bug while avoiding expensive DISTINCT deduplication.
--
-- PROBLEM STATEMENT:
--   Demonstrate the 1:N join fan-out trap and build an architect-grade SEMI-JOIN query
--   using EXISTS that preserves the true 1x grain of the parent table.
-- ============================================================================

DROP TABLE IF EXISTS fulfillment_packages;
DROP TABLE IF EXISTS customer_orders;

CREATE TABLE customer_orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_total_usd DECIMAL(12, 2) NOT NULL,
    order_date TEXT NOT NULL
);

CREATE TABLE fulfillment_packages (
    package_id VARCHAR(32) PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL,
    carrier_code VARCHAR(20) NOT NULL,
    shipping_service_level VARCHAR(20) NOT NULL, -- 'EXPRESS', 'GROUND', 'FREIGHT'
    tracking_number VARCHAR(50) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES customer_orders(order_id)
);

INSERT INTO customer_orders VALUES
('ORD-901', 'CUST-A', 500.00, '2024-05-01'),
('ORD-902', 'CUST-B', 1200.00, '2024-05-02'),
('ORD-903', 'CUST-C', 350.00, '2024-05-03'),
('ORD-904', 'CUST-D', 2400.00, '2024-05-04');

INSERT INTO fulfillment_packages VALUES
-- ORD-901 has 3 separate packages, 2 of which are EXPRESS
('PKG-01', 'ORD-901', 'FEDEX', 'EXPRESS', 'TRK-1001'),
('PKG-02', 'ORD-901', 'FEDEX', 'EXPRESS', 'TRK-1002'),
('PKG-03', 'ORD-901', 'USPS',  'GROUND',  'TRK-1003'),
-- ORD-902 has only GROUND packages
('PKG-04', 'ORD-902', 'UPS',    'GROUND',  'TRK-1004'),
-- ORD-903 has 1 EXPRESS package
('PKG-05', 'ORD-903', 'DHL',    'EXPRESS', 'TRK-1005'),
-- ORD-904 has 2 EXPRESS packages
('PKG-06', 'ORD-904', 'FEDEX', 'EXPRESS', 'TRK-1006'),
('PKG-07', 'ORD-904', 'FEDEX', 'EXPRESS', 'TRK-1007');

-- --- [SOLUTION QUERY] ---
-- Production Semi-Join pattern:
-- 1. Evaluates existence of express fulfillment without multiplying order rows
-- 2. Query optimizer terminates lookup on first match (Early Exit Optimization)
SELECT 
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_total_usd,
    'QUALIFIED_EXPRESS_ORDER' AS audit_status
FROM customer_orders o
WHERE EXISTS (
    SELECT 1 
    FROM fulfillment_packages p
    WHERE p.order_id = o.order_id
      AND p.shipping_service_level = 'EXPRESS'
)
ORDER BY o.order_total_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[order_id] = ORD-904
