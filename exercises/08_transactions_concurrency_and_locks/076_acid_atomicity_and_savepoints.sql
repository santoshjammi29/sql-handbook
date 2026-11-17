-- ============================================================================
-- EXERCISE: 076_acid_atomicity_and_savepoints.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead OLTP Database Architect & Systems Reliability Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Distributed E-Commerce Checkout Pipeline & Transaction Boundaries.
--   A checkout session requires coordinating three atomic stages:
--   1. Master Order Header & Billing Line Creation
--   2. Real-Time Warehouse Inventory Stock Reservation
--   3. Third-Party Promotional Voucher / Gift Card Redemption
--
-- BUSINESS CONTEXT:
--   During high-volume flash checkout, third-party promotional redemption APIs
--   can return validation errors (e.g., voucher expired, minimum cart value not met).
--   Aborting the entire order causes abandoned carts and lost revenue ($2.4M ARR impact).
--   Architectural solution: Use nested transaction SAVEPOINTS. If the promotional
--   deduction fails or proves invalid, rollback specifically to the savepoint,
--   preserving the base order and inventory reservation while alerting the customer.
--
-- PROBLEM STATEMENT:
--   1. Initiate an atomic transaction inserting the base order ORD-9901 and reserving
--      1 unit of SKU-LAPTOP-PRO from inventory.
--   2. Establish SAVEPOINT 'promo_voucher_redemption'.
--   3. Attempt to apply an invalid voucher VOUCH-SUMMER-100 violating minimum spend.
--   4. Roll back to the SAVEPOINT, discarding the invalid promotion while preserving
--      the order header and inventory reservation.
--   5. Commit the transaction and output a consolidated order confirmation audit.
-- ============================================================================

DROP TABLE IF EXISTS checkout_discounts;
DROP TABLE IF EXISTS checkout_inventory_reservations;
DROP TABLE IF EXISTS checkout_orders;

CREATE TABLE checkout_orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    base_order_total_usd DECIMAL(12, 2) NOT NULL,
    order_status VARCHAR(20) NOT NULL, -- PENDING, CONFIRMED, CANCELLED
    created_at TEXT NOT NULL
);

CREATE TABLE checkout_inventory_reservations (
    reservation_id VARCHAR(32) PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL,
    sku_id VARCHAR(32) NOT NULL,
    reserved_qty INT NOT NULL,
    warehouse_code VARCHAR(20) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES checkout_orders(order_id)
);

CREATE TABLE checkout_discounts (
    discount_id VARCHAR(32) PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL,
    voucher_code VARCHAR(32) NOT NULL,
    discount_amount_usd DECIMAL(12, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES checkout_orders(order_id)
);

-- Execute transactional checkout with SAVEPOINT isolation
BEGIN TRANSACTION;

-- Step 1: Base order placement
INSERT INTO checkout_orders VALUES
('ORD-9901', 'CUST-8801', 1200.00, 'CONFIRMED', '2024-06-01 10:15:00');

-- Step 2: Inventory reservation
INSERT INTO checkout_inventory_reservations VALUES
('RES-501', 'ORD-9901', 'SKU-LAPTOP-PRO', 1, 'WH-US-EAST');

-- Step 3: Define savepoint before risky promo redemption
SAVEPOINT promo_voucher_redemption;

-- Step 3a: Attempt invalid promotion insertion
INSERT INTO checkout_discounts VALUES
('DISC-99', 'ORD-9901', 'VOUCH-SUMMER-100', -150.00);

-- Step 3b: Validation fails -> Rollback specifically to savepoint
ROLLBACK TO promo_voucher_redemption;

-- Release savepoint and commit durable order and inventory reservation
RELEASE promo_voucher_redemption;
COMMIT;

-- --- [SOLUTION QUERY] ---
-- Consolidated checkout reconciliation confirming base order and reservation persisted
SELECT 
    o.order_id,
    o.customer_id,
    o.base_order_total_usd,
    o.order_status,
    r.sku_id AS reserved_sku,
    r.reserved_qty,
    COALESCE(d.discount_amount_usd, 0.00) AS applied_discount_usd,
    (o.base_order_total_usd + COALESCE(d.discount_amount_usd, 0.00)) AS final_payable_usd,
    CASE 
        WHEN d.discount_id IS NULL THEN 'SAVEPOINT_ROLLBACK_PRESERVED_ORDER'
        ELSE 'DISCOUNT_APPLIED'
    END AS transaction_execution_status
FROM checkout_orders o
INNER JOIN checkout_inventory_reservations r ON o.order_id = r.order_id
LEFT JOIN checkout_discounts d ON o.order_id = d.order_id
WHERE o.order_id = 'ORD-9901';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[order_id] = ORD-9901
-- ASSERT: COL[final_payable_usd] = 1200.0
-- ASSERT: COL[transaction_execution_status] = SAVEPOINT_ROLLBACK_PRESERVED_ORDER\n