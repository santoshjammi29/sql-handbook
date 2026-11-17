-- ============================================================================
-- EXERCISE: 063_bridge_tables_for_many_to_many_relationships.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Joint bank accounts: A bank account can have multiple owners (Alice 60%, Bob 40%),
--   and an owner can hold multiple accounts. A Bridge Table resolves this Many-to-Many
--   relationship with weighting factors to prevent balance overstatement.
-- PROBLEM STATEMENT:
--   Implement a weighted bridge table and calculate exact weighted customer balances.
-- ============================================================================

DROP TABLE IF EXISTS bridge_account_customer;
DROP TABLE IF EXISTS dim_joint_customers;
DROP TABLE IF EXISTS fact_account_balances;

CREATE TABLE dim_joint_customers (customer_id INT PRIMARY KEY, customer_name VARCHAR(50));
CREATE TABLE fact_account_balances (account_id INT PRIMARY KEY, balance DECIMAL(10, 2));

CREATE TABLE bridge_account_customer (
    account_id INT,
    customer_id INT,
    weight_factor DECIMAL(3, 2),
    PRIMARY KEY (account_id, customer_id)
);

INSERT INTO dim_joint_customers VALUES (1, 'Alice'), (2, 'Bob');
INSERT INTO fact_account_balances VALUES (101, 100000.00);
INSERT INTO bridge_account_customer VALUES (101, 1, 0.60), (101, 2, 0.40);

-- --- [SOLUTION QUERY] ---
SELECT 
    c.customer_name,
    f.account_id,
    f.balance AS total_account_balance,
    b.weight_factor,
    ROUND(f.balance * b.weight_factor, 2) AS customer_attributed_balance
FROM fact_account_balances f
JOIN bridge_account_customer b ON f.account_id = b.account_id
JOIN dim_joint_customers c ON b.customer_id = c.customer_id
ORDER BY customer_attributed_balance DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[customer_attributed_balance] = 60000.00
