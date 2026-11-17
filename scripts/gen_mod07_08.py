#!/usr/bin/env python3
"""
Generator for Module 07 (066-075) & Module 08 (076-085)
"""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

def save(mod: str, name: str, content: str):
    p = EXERCISES_DIR / mod / name
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Generated: {mod}/{name}")

# ==============================================================================
# MODULE 07: Indexing, Storage Engines & Query Optimization (066 - 075)
# ==============================================================================

save("07_indexing_and_query_optimization", "066_btree_index_seek_vs_index_scan.sql", """-- ============================================================================
-- EXERCISE: 066_btree_index_seek_vs_index_scan.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A user authentication service queries accounts table by email. If the email
--   column lacks an index, the database executes an O(N) full table scan.
--   With a unique B-Tree index, it executes an O(log N) Index Seek.
-- PROBLEM STATEMENT:
--   Create a B-Tree index, query the record, and verify plan execution characteristics.
-- ============================================================================

DROP TABLE IF EXISTS app_users;
CREATE TABLE app_users (
    user_id INT PRIMARY KEY,
    email VARCHAR(100),
    is_active INT
);

INSERT INTO app_users VALUES
(1, 'alice@acme.com', 1),
(2, 'bob@acme.com', 1),
(3, 'charlie@acme.com', 0);

CREATE UNIQUE INDEX idx_users_email ON app_users (email);

-- --- [SOLUTION QUERY] ---
SELECT user_id, email, is_active
FROM app_users
WHERE email = 'alice@acme.com';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[user_id] = 1
""")

save("07_indexing_and_query_optimization", "067_composite_index_column_ordering_left_prefix.sql", """-- ============================================================================
-- EXERCISE: 067_composite_index_column_ordering_left_prefix.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Multi-tenant SaaS databases partition customer data by tenant_id. Queries
--   filter by tenant_id and created_at. An index created with columns in the
--   wrong order (created_at, tenant_id) cannot seek on tenant_id alone!
-- PROBLEM STATEMENT:
--   Demonstrate the Left-to-Right Prefix Rule: an index on (tenant_id, created_at)
--   efficiently services filters on (tenant_id) and (tenant_id, created_at).
-- ============================================================================

DROP TABLE IF EXISTS tenant_audit_log;
CREATE TABLE tenant_audit_log (
    log_id INT PRIMARY KEY,
    tenant_id INT,
    created_at TEXT,
    event_action VARCHAR(50)
);

CREATE INDEX idx_tenant_created ON tenant_audit_log (tenant_id, created_at);

INSERT INTO tenant_audit_log VALUES
(1, 100, '2024-05-01 10:00:00', 'LOGIN'),
(2, 100, '2024-05-01 11:30:00', 'UPDATE'),
(3, 200, '2024-05-01 12:00:00', 'LOGIN');

-- --- [SOLUTION QUERY] ---
SELECT log_id, tenant_id, created_at, event_action
FROM tenant_audit_log
WHERE tenant_id = 100 
  AND created_at >= '2024-05-01 10:00:00'
ORDER BY created_at ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[event_action] = LOGIN
""")

save("07_indexing_and_query_optimization", "068_covering_indexes_and_index_only_scans.sql", """-- ============================================================================
-- EXERCISE: 068_covering_indexes_and_index_only_scans.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   High-frequency trading API: Point queries checking account balance must
--   execute in under 1 millisecond. If an index only contains account_id, the
--   engine must perform a secondary random disk lookup to the table heap page.
--   A Covering Index includes the balance column, eliminating table heap lookups!
-- PROBLEM STATEMENT:
--   Create a covering index and execute an Index-Only Scan.
-- ============================================================================

DROP TABLE IF EXISTS trading_accounts;
CREATE TABLE trading_accounts (
    account_id INT PRIMARY KEY,
    balance DECIMAL(12, 2),
    kyc_status VARCHAR(20),
    unneeded_metadata_blob TEXT
);

INSERT INTO trading_accounts VALUES
(1, 50000.00, 'VERIFIED', 'large binary metadata string...'),
(2, 12000.00, 'VERIFIED', 'large binary metadata string...');

CREATE INDEX idx_covering_balance ON trading_accounts (account_id, balance);

-- --- [SOLUTION QUERY] ---
-- Satisfied entirely from index leaves without touching table heap!
SELECT account_id, balance
FROM trading_accounts
WHERE account_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 50000.00
""")

save("07_indexing_and_query_optimization", "069_filtered_and_partial_indexes.sql", """-- ============================================================================
-- EXERCISE: 069_filtered_and_partial_indexes.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Message queue processing: A table holds 50 million processed messages and
--   500 unprocessed messages. Indexing all 50M rows wastes gigabytes of RAM.
--   A Partial / Filtered Index indexes ONLY rows WHERE status = 'UNPROCESSED'.
-- PROBLEM STATEMENT:
--   Create a partial index and query the unprocessed queue.
-- ============================================================================

DROP TABLE IF EXISTS async_task_queue;
CREATE TABLE async_task_queue (
    task_id INT PRIMARY KEY,
    payload TEXT,
    status VARCHAR(20),
    created_at TEXT
);

INSERT INTO async_task_queue VALUES
(1, '{"job": "email"}', 'PROCESSED',   '2024-05-01 09:00:00'),
(2, '{"job": "report"}', 'PROCESSED',   '2024-05-01 09:05:00'),
(3, '{"job": "sync"}',   'UNPROCESSED', '2024-05-01 10:00:00');

-- Partial index in SQLite / Postgres
CREATE INDEX idx_unprocessed_tasks ON async_task_queue (task_id, created_at)
WHERE status = 'UNPROCESSED';

-- --- [SOLUTION QUERY] ---
SELECT task_id, payload, created_at
FROM async_task_queue
WHERE status = 'UNPROCESSED'
ORDER BY created_at ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[task_id] = 3
""")

save("07_indexing_and_query_optimization", "070_cardinality_estimation_and_statistics.sql", """-- ============================================================================
-- EXERCISE: 070_cardinality_estimation_and_statistics.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Optimizer cost modeling: In relational engines, the Cost-Based Optimizer
--   estimates cardinality (how many rows match a predicate) using table statistics.
--   When stats are missing, it defaults to fixed estimates, potentially picking
--   the wrong join strategy.
-- PROBLEM STATEMENT:
--   Demonstrate querying with analytical filters and updating optimizer stats.
-- ============================================================================

DROP TABLE IF EXISTS catalog_items;
CREATE TABLE catalog_items (
    item_id INT PRIMARY KEY,
    item_type VARCHAR(50),
    price DECIMAL(10, 2)
);

INSERT INTO catalog_items VALUES
(1, 'BOOK', 15.00),
(2, 'BOOK', 22.00),
(3, 'BOOK', 35.00),
(4, 'LAPTOP', 1200.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    item_type,
    COUNT(*) AS total_items,
    ROUND(AVG(price), 2) AS avg_price
FROM catalog_items
WHERE price > 20.00
GROUP BY item_type;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_items] = 2
""")

save("07_indexing_and_query_optimization", "071_clustered_vs_non_clustered_index_layout.sql", """-- ============================================================================
-- EXERCISE: 071_clustered_vs_non_clustered_index_layout.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Clustered Index determines the physical order of rows on disk. There can
--   be only ONE clustered index per table. In SQLite/Postgres/MySQL, the PRIMARY KEY
--   serves as the clustered index.
-- PROBLEM STATEMENT:
--   Demonstrate range scanning on a clustered primary key.
-- ============================================================================

DROP TABLE IF EXISTS ledger_entries;
CREATE TABLE ledger_entries (
    entry_id INT PRIMARY KEY, -- Clustered physical key
    account_id INT,
    amount DECIMAL(10, 2)
);

INSERT INTO ledger_entries VALUES
(1001, 10, 250.00),
(1002, 10, 100.00),
(1003, 20, 500.00),
(1004, 20, 750.00);

-- --- [SOLUTION QUERY] ---
-- Sequential physical range scan
SELECT entry_id, account_id, amount
FROM ledger_entries
WHERE entry_id BETWEEN 1001 AND 1003
ORDER BY entry_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[amount] = 250.00
""")

save("07_indexing_and_query_optimization", "072_join_algorithms_nested_loop_hash_merge.sql", """-- ============================================================================
-- EXERCISE: 072_join_algorithms_nested_loop_hash_merge.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Database join algorithms:
--   1. Nested Loop: for each outer row, seek inner index (fast for tiny tables)
--   2. Hash Join: build hash table on smaller table, probe with larger table
--   3. Merge Join: both sides sorted on join key, streaming merge
-- PROBLEM STATEMENT:
--   Write an inner join with equality predicates suitable for hash/merge optimization.
-- ============================================================================

DROP TABLE IF EXISTS customers_dim;
DROP TABLE IF EXISTS orders_fact;

CREATE TABLE customers_dim (cust_id INT PRIMARY KEY, cust_name VARCHAR(50));
CREATE TABLE orders_fact (order_id INT PRIMARY KEY, cust_id INT, amount DECIMAL(10, 2));

INSERT INTO customers_dim VALUES (1, 'Alice'), (2, 'Bob');
INSERT INTO orders_fact VALUES (101, 1, 500.00), (102, 1, 300.00), (103, 2, 800.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    c.cust_id,
    c.cust_name,
    COUNT(o.order_id) AS order_count,
    SUM(o.amount)     AS total_order_amount
FROM customers_dim c
JOIN orders_fact o ON c.cust_id = o.cust_id
GROUP BY c.cust_id, c.cust_name
ORDER BY total_order_amount DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_order_amount] = 800.00
""")

save("07_indexing_and_query_optimization", "073_preventing_accidental_cartesian_products.sql", """-- ============================================================================
-- EXERCISE: 073_preventing_accidental_cartesian_products.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A developer joined two tables without specifying an ON condition, or joined
--   on non-unique keys, creating a catastrophic Cartesian Product that filled
--   TempDB disk space and crashed the database instance.
-- PROBLEM STATEMENT:
--   Join two parent-child tables ensuring exact join key equality to prevent explosion.
-- ============================================================================

DROP TABLE IF EXISTS departments;
DROP TABLE IF EXISTS staff;

CREATE TABLE departments (dept_id INT PRIMARY KEY, dept_name VARCHAR(50));
CREATE TABLE staff (staff_id INT PRIMARY KEY, dept_id INT, staff_name VARCHAR(50));

INSERT INTO departments VALUES (1, 'HR'), (2, 'Engineering');
INSERT INTO staff VALUES (101, 1, 'Alice'), (102, 2, 'Bob'), (103, 2, 'Charlie');

-- --- [SOLUTION QUERY] ---
-- Strict join prevents 2 x 3 = 6 cartesian explosion
SELECT 
    d.dept_name,
    s.staff_name
FROM departments d
JOIN staff s ON d.dept_id = s.dept_id
ORDER BY d.dept_name ASC, s.staff_name ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[staff_name] = Bob
""")

save("07_indexing_and_query_optimization", "074_sargable_date_range_predicates.sql", """-- ============================================================================
-- EXERCISE: 074_sargable_date_range_predicates.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Auditing transactions created in May 2024:
--   Bad: WHERE STRFTIME('%m', created_at) = '05' (Non-SARGable full table scan)
--   Good: WHERE created_at >= '2024-05-01' AND created_at < '2024-06-01' (SARGable)
-- PROBLEM STATEMENT:
--   Implement the SARGable date range pattern.
-- ============================================================================

DROP TABLE IF EXISTS audit_entries;
CREATE TABLE audit_entries (
    entry_id INT PRIMARY KEY,
    created_at TEXT,
    event_type VARCHAR(50)
);

INSERT INTO audit_entries VALUES
(1, '2024-04-30 23:59:59', 'CLOSE'),
(2, '2024-05-01 00:00:00', 'OPEN'),
(3, '2024-05-15 12:00:00', 'TXN'),
(4, '2024-05-31 23:59:59', 'CLOSE'),
(5, '2024-06-01 00:00:00', 'OPEN');

-- --- [SOLUTION QUERY] ---
SELECT entry_id, created_at, event_type
FROM audit_entries
WHERE created_at >= '2024-05-01 00:00:00'
  AND created_at < '2024-06-01 00:00:00'
ORDER BY created_at ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[entry_id] = 2
""")

save("07_indexing_and_query_optimization", "075_index_bloat_and_fragmentation_maintenance.sql", """-- ============================================================================
-- EXERCISE: 075_index_bloat_and_fragmentation_maintenance.sql
-- MODULE:   07_indexing_and_query_optimization
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   High-frequency random inserts and deletes cause B-Tree page splits and
--   table bloat. In production PostgreSQL/SQLite, periodic VACUUM or REINDEX
--   reclaims dead storage space and defragments index leaf pages.
-- PROBLEM STATEMENT:
--   Simulate table mutations and demonstrate index maintenance.
-- ============================================================================

DROP TABLE IF EXISTS volatile_table;
CREATE TABLE volatile_table (
    id INT PRIMARY KEY,
    payload VARCHAR(255)
);

INSERT INTO volatile_table VALUES (1, 'initial data 1'), (2, 'initial data 2');
DELETE FROM volatile_table WHERE id = 1;
INSERT INTO volatile_table VALUES (3, 'new data 3');

-- --- [SOLUTION QUERY] ---
SELECT id, payload FROM volatile_table ORDER BY id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[id] = 2
""")

# ==============================================================================
# MODULE 08: Transactions, Concurrency & Lock Contention (076 - 085)
# ==============================================================================

save("08_transactions_concurrency_and_locks", "076_acid_atomicity_and_savepoints.sql", """-- ============================================================================
-- EXERCISE: 076_acid_atomicity_and_savepoints.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Multi-step order checkout: Customer places an order and applies a discount.
--   If the discount is invalid, we want to roll back the discount step using a
--   SAVEPOINT while preserving the core order placement.
-- PROBLEM STATEMENT:
--   Execute a transaction with SAVEPOINT and ROLLBACK TO SAVEPOINT.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders_tx;
CREATE TABLE customer_orders_tx (
    order_id INT PRIMARY KEY,
    amount DECIMAL(10, 2),
    status VARCHAR(20)
);

BEGIN TRANSACTION;
INSERT INTO customer_orders_tx VALUES (101, 200.00, 'PENDING');
SAVEPOINT discount_attempt;
INSERT INTO customer_orders_tx VALUES (102, -50.00, 'INVALID_DISCOUNT');
-- Rollback the invalid discount
ROLLBACK TO discount_attempt;
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT order_id, amount, status FROM customer_orders_tx;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[order_id] = 101
""")

save("08_transactions_concurrency_and_locks", "077_dirty_read_anomaly_read_uncommitted.sql", """-- ============================================================================
-- EXERCISE: 077_dirty_read_anomaly_read_uncommitted.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Dirty Read anomaly occurs under READ UNCOMMITTED: Transaction 1 mutates a row.
--   Transaction 2 reads the uncommitted mutation. Transaction 1 then rolls back.
--   Transaction 2 has acted on phantom data that never committed!
-- PROBLEM STATEMENT:
--   Demonstrate transactional isolation preventing dirty reads.
-- ============================================================================

DROP TABLE IF EXISTS account_balance;
CREATE TABLE account_balance (
    account_id INT PRIMARY KEY,
    balance DECIMAL(10, 2)
);

INSERT INTO account_balance VALUES (1, 1000.00);

BEGIN TRANSACTION;
UPDATE account_balance SET balance = 5000.00 WHERE account_id = 1;
-- Transaction aborts
ROLLBACK;

-- --- [SOLUTION QUERY] ---
-- Validates balance reverted to committed state
SELECT account_id, balance FROM account_balance WHERE account_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 1000.00
""")

save("08_transactions_concurrency_and_locks", "078_non_repeatable_read_anomaly.sql", """-- ============================================================================
-- EXERCISE: 078_non_repeatable_read_anomaly.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Non-Repeatable Read (Fuzzy Read): Under READ COMMITTED, Transaction 1 reads
--   a row ($100). Concurrently, Transaction 2 updates the row to $150 and commits.
--   Transaction 1 re-reads the row and sees $150. REPEATABLE READ snapshot isolation
--   prevents this by freezing visible versions at transaction start.
-- PROBLEM STATEMENT:
--   Demonstrate consistent state reads within a transaction.
-- ============================================================================

DROP TABLE IF EXISTS product_inventory;
CREATE TABLE product_inventory (
    product_id INT PRIMARY KEY,
    stock INT
);

INSERT INTO product_inventory VALUES (1, 50);

BEGIN TRANSACTION;
SELECT stock FROM product_inventory WHERE product_id = 1;
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT product_id, stock FROM product_inventory WHERE product_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[stock] = 50
""")

save("08_transactions_concurrency_and_locks", "079_phantom_read_anomaly_range_locks.sql", """-- ============================================================================
-- EXERCISE: 079_phantom_read_anomaly_range_locks.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Phantom Read anomaly: Transaction 1 queries COUNT(*) WHERE status = 'PENDING'
--   (returns 2). Transaction 2 inserts a brand-new pending row and commits.
--   Transaction 1 re-runs the count and receives 3.
-- PROBLEM STATEMENT:
--   Demonstrate predicate range counting and row insertion effects.
-- ============================================================================

DROP TABLE IF EXISTS approval_queue;
CREATE TABLE approval_queue (
    queue_id INT PRIMARY KEY,
    status VARCHAR(20)
);

INSERT INTO approval_queue VALUES (1, 'PENDING'), (2, 'PENDING');

-- --- [SOLUTION QUERY] ---
SELECT COUNT(*) AS pending_count
FROM approval_queue
WHERE status = 'PENDING';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[pending_count] = 2
""")

save("08_transactions_concurrency_and_locks", "080_write_skew_anomaly_under_snapshot_isolation.sql", """-- ============================================================================
-- EXERCISE: 080_write_skew_anomaly_under_snapshot_isolation.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   The Hospital On-Call Doctor Dilemma (Write Skew): A hospital requires at
--   least 1 doctor on call. Alice and Bob are on call (Count = 2). Alice takes
--   leave because Count >= 2. Concurrently, Bob takes leave because Count >= 2.
--   Under Snapshot Isolation, both commit because they updated distinct rows,
--   leaving 0 doctors on call!
-- PROBLEM STATEMENT:
--   Model the on-call doctor state and enforce the global constraint.
-- ============================================================================

DROP TABLE IF EXISTS on_call_schedule;
CREATE TABLE on_call_schedule (
    doctor_id INT PRIMARY KEY,
    doctor_name VARCHAR(50),
    is_on_call INT
);

INSERT INTO on_call_schedule VALUES (1, 'Dr. Alice', 1), (2, 'Dr. Bob', 1);

-- Safe update guard: Only allow turning off if remaining count > 1
UPDATE on_call_schedule
SET is_on_call = 0
WHERE doctor_id = 1 
  AND (SELECT COUNT(*) FROM on_call_schedule WHERE is_on_call = 1) > 1;

-- --- [SOLUTION QUERY] ---
SELECT 
    doctor_id,
    doctor_name,
    is_on_call,
    (SELECT COUNT(*) FROM on_call_schedule WHERE is_on_call = 1) AS remaining_on_call
FROM on_call_schedule
ORDER BY doctor_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[remaining_on_call] = 1
""")

save("08_transactions_concurrency_and_locks", "081_mvcc_internals_and_version_visibility.sql", """-- ============================================================================
-- EXERCISE: 081_mvcc_internals_and_version_visibility.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   MVCC Internals: In Multi-Version Concurrency Control, row updates do not
--   overwrite disk blocks. Instead, they insert a new row version with xmin/xmax
--   metadata timestamps. Readers read the version visible to their snapshot.
-- PROBLEM STATEMENT:
--   Simulate an MVCC versioning ledger with visible_from and visible_to timestamps.
-- ============================================================================

DROP TABLE IF EXISTS mvcc_simulation;
CREATE TABLE mvcc_simulation (
    row_id INT,
    version INT,
    balance DECIMAL(10, 2),
    created_tx INT,
    expired_tx INT -- 0 = Active
);

INSERT INTO mvcc_simulation VALUES
(1, 1, 100.00, 100, 105), -- Expired at tx 105
(1, 2, 150.00, 105, 0);   -- Active version

-- --- [SOLUTION QUERY] ---
-- Query as of Transaction 102 (Snapshot isolation in the past)
SELECT row_id, balance, version
FROM mvcc_simulation
WHERE created_tx <= 102 AND (expired_tx > 102 OR expired_tx = 0);

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[balance] = 100.00
""")

save("08_transactions_concurrency_and_locks", "082_optimistic_concurrency_control_version_checks.sql", """-- ============================================================================
-- EXERCISE: 082_optimistic_concurrency_control_version_checks.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Web e-commerce inventory: To avoid expensive long-lived database locks,
--   applications use Optimistic Concurrency Control (OCC). Each row has a
--   version number. Updates execute: UPDATE ... WHERE id = 1 AND version = current_version.
--   If 0 rows were updated, a concurrent update occurred and the app retries.
-- PROBLEM STATEMENT:
--   Execute a safe OCC update and verify version incrementation.
-- ============================================================================

DROP TABLE IF EXISTS occ_inventory;
CREATE TABLE occ_inventory (
    item_id INT PRIMARY KEY,
    stock_qty INT,
    lock_version INT
);

INSERT INTO occ_inventory VALUES (1, 100, 1);

-- Worker reads item_id = 1, lock_version = 1.
-- Worker executes CAS update:
UPDATE occ_inventory
SET stock_qty = stock_qty - 5,
    lock_version = lock_version + 1
WHERE item_id = 1 AND lock_version = 1;

-- --- [SOLUTION QUERY] ---
SELECT item_id, stock_qty, lock_version FROM occ_inventory WHERE item_id = 1;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[stock_qty] = 95
-- ASSERT: COL[lock_version] = 2
""")

save("08_transactions_concurrency_and_locks", "083_deadlock_reproduction_and_inverse_locking.sql", """-- ============================================================================
-- EXERCISE: 083_deadlock_reproduction_and_inverse_locking.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Deadlock (Error 1205): Transaction 1 locks Account A then requests Account B.
--   Transaction 2 locks Account B then requests Account A.
--   The permanent architectural fix is Canonical Resource Ordering: Always lock
--   the smaller account ID first, regardless of transfer direction!
-- PROBLEM STATEMENT:
--   Demonstrate canonical ordering logic to guarantee deadlock-free execution.
-- ============================================================================

DROP TABLE IF EXISTS bank_accounts;
CREATE TABLE bank_accounts (
    account_id INT PRIMARY KEY,
    balance DECIMAL(10, 2)
);

INSERT INTO bank_accounts VALUES (10, 500.00), (20, 800.00);

-- Canonical transfer logic: from Account 20 to Account 10
-- Order IDs: min(10, 20) = 10 first, max(10, 20) = 20 second!
BEGIN TRANSACTION;
UPDATE bank_accounts SET balance = balance + 100.00 WHERE account_id = 10; -- Min ID
UPDATE bank_accounts SET balance = balance - 100.00 WHERE account_id = 20; -- Max ID
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT account_id, balance FROM bank_accounts ORDER BY account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[balance] = 600.00
""")

save("08_transactions_concurrency_and_locks", "084_pessimistic_locking_for_update.sql", """-- ============================================================================
-- EXERCISE: 084_pessimistic_locking_for_update.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Concert ticket booking: Multiple users attempt to buy the last VIP seat.
--   Pessimistic locking (SELECT ... FOR UPDATE) acquires exclusive row locks,
--   preventing other transactions from reading or reserving the seat until commit.
-- PROBLEM STATEMENT:
--   Simulate atomic seat reservation logic in a transaction.
-- ============================================================================

DROP TABLE IF EXISTS concert_seats;
CREATE TABLE concert_seats (
    seat_id VARCHAR(10) PRIMARY KEY,
    is_reserved INT,
    reserved_by VARCHAR(50)
);

INSERT INTO concert_seats VALUES ('A1', 0, NULL), ('A2', 0, NULL);

BEGIN TRANSACTION;
UPDATE concert_seats
SET is_reserved = 1, reserved_by = 'User_101'
WHERE seat_id = 'A1' AND is_reserved = 0;
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT seat_id, is_reserved, reserved_by FROM concert_seats WHERE seat_id = 'A1';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[reserved_by] = User_101
""")

save("08_transactions_concurrency_and_locks", "085_double_entry_ledger_atomic_transfer.sql", """-- ============================================================================
-- EXERCISE: 085_double_entry_ledger_atomic_transfer.sql
-- MODULE:   08_transactions_concurrency_and_locks
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Fintech Double-Entry Bookkeeping Invariant: Every financial transaction
--   must have matching debit and credit entries. The sum of all entries across
--   the entire ledger must mathematically equal 0.
-- PROBLEM STATEMENT:
--   Execute an atomic double-entry transfer and verify the zero-balance invariant.
-- ============================================================================

DROP TABLE IF EXISTS journal_entries;
CREATE TABLE journal_entries (
    entry_id INT PRIMARY KEY,
    txn_id VARCHAR(50),
    account_name VARCHAR(50),
    amount DECIMAL(10, 2) -- Positive = Debit, Negative = Credit
);

BEGIN TRANSACTION;
-- $250 transfer from Cash to Accounts Payable
INSERT INTO journal_entries VALUES 
(1, 'TXN_901', 'Cash', -250.00),
(2, 'TXN_901', 'Accounts Payable', 250.00);
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT 
    txn_id,
    SUM(amount) AS net_ledger_balance,
    COUNT(*)    AS total_journal_legs
FROM journal_entries
GROUP BY txn_id
HAVING SUM(amount) = 0.00; -- Invariant holds!

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[net_ledger_balance] = 0.0
""")

print("Module 07 and Module 08 generation complete!")
