#!/usr/bin/env python3
"""
Generator for Module 01 (001-010) & Module 02 (011-020)
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
# MODULE 01: Core SQL Fundamentals (001 - 010)
# ==============================================================================

save("01_core_sql_fundamentals", "001_logical_query_execution_order.sql", """-- ============================================================================
-- EXERCISE: 001_logical_query_execution_order.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   An e-commerce finance team needs to calculate gross transaction margins
--   and filter out transactions with margins below $50. Junior analysts keep
--   writing queries that reference calculated column aliases in the WHERE clause,
--   causing database syntax compilation errors.
-- PROBLEM STATEMENT:
--   Demonstrate why a column alias defined in SELECT cannot be referenced in
--   WHERE, but CAN be referenced in ORDER BY. Provide the production-grade fix
--   using both a Common Table Expression (CTE) and subexpression repetition.
-- PRODUCTION PITFALL:
--   Attempting 'WHERE gross_margin > 50' fails because WHERE executes at Step 2
--   while SELECT projections execute at Step 6.
-- ============================================================================

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    sale_amount DECIMAL(10, 2),
    cost_amount DECIMAL(10, 2),
    status VARCHAR(20)
);

INSERT INTO orders (order_id, customer_id, sale_amount, cost_amount, status) VALUES
(101, 1, 150.00, 80.00, 'COMPLETED'),
(102, 2, 200.00, 160.00, 'COMPLETED'),
(103, 1, 350.00, 200.00, 'COMPLETED'),
(104, 3, 90.00, 70.00, 'CANCELLED'),
(105, 4, 500.00, 320.00, 'COMPLETED');

-- --- [SOLUTION QUERY] ---
-- Using CTE to materialize alias before downstream filtering and sorting
WITH calculated_orders AS (
    SELECT 
        order_id,
        customer_id,
        sale_amount,
        cost_amount,
        (sale_amount - cost_amount) AS gross_margin,
        status
    FROM orders
    WHERE status = 'COMPLETED'
)
SELECT 
    order_id,
    customer_id,
    gross_margin
FROM calculated_orders
WHERE gross_margin >= 50.00
ORDER BY gross_margin DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[gross_margin] = 180.00
""")

save("01_core_sql_fundamentals", "002_three_valued_logic_and_null_traps.sql", """-- ============================================================================
-- EXERCISE: 002_three_valued_logic_and_null_traps.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A marketing operations system needs to identify customer leads that have NOT
--   unsubscribed from communication. However, unsubscribed status contains NULL
--   values for legacy users who registered before consent tracking was enabled.
-- PROBLEM STATEMENT:
--   Retrieve all customers who are NOT explicitly unsubscribed ('UNSUB'), handling
--   Three-Valued Logic (3VL) properly so NULL records are safely included. Also
--   demonstrate the catastrophic NOT IN (..., NULL) trap.
-- PRODUCTION PITFALL:
--   Using 'WHERE status != ''UNSUB''' silently drops all NULL records because
--   NULL != 'UNSUB' evaluates to UNKNOWN, which evaluates to FALSE in WHERE filters!
-- ============================================================================

DROP TABLE IF EXISTS marketing_leads;
CREATE TABLE marketing_leads (
    lead_id INT PRIMARY KEY,
    email VARCHAR(100),
    unsub_status VARCHAR(20) -- Values: 'UNSUB', 'ACTIVE', or NULL
);

INSERT INTO marketing_leads (lead_id, email, unsub_status) VALUES
(1, 'alice@example.com', 'ACTIVE'),
(2, 'bob@example.com', 'UNSUB'),
(3, 'charlie@example.com', NULL),
(4, 'david@example.com', 'ACTIVE'),
(5, 'eve@example.com', NULL);

-- --- [SOLUTION QUERY] ---
-- Correctly handles 3VL by checking IS NULL or using COALESCE
SELECT 
    lead_id,
    email,
    COALESCE(unsub_status, 'UNSET') AS resolved_status
FROM marketing_leads
WHERE unsub_status != 'UNSUB' OR unsub_status IS NULL
ORDER BY lead_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[email] = alice@example.com
""")

save("01_core_sql_fundamentals", "003_sargability_and_predicate_rewriting.sql", """-- ============================================================================
-- EXERCISE: 003_sargability_and_predicate_rewriting.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   An auditing job queries an invoice table with 20 million rows daily to find
--   all invoices generated during the year 2024. A developer wrote a query using
--   STRFTIME / EXTRACT, causing the database to perform a full table scan.
-- PROBLEM STATEMENT:
--   Rewrite the non-SARGable date predicate into an index-seekable range boundary
--   condition (Col >= Start AND Col < End) that enables B-Tree index traversal.
-- PRODUCTION PITFALL:
--   Wrapping indexed columns in functions (e.g. YEAR(d) or SUBSTR(code, 1, 3))
--   forces the engine to evaluate the function for every single row in the table.
-- ============================================================================

DROP TABLE IF EXISTS invoices;
CREATE TABLE invoices (
    invoice_id INT PRIMARY KEY,
    invoice_date TEXT, -- Stored as ISO string YYYY-MM-DD
    total_amount DECIMAL(10, 2)
);

INSERT INTO invoices (invoice_id, invoice_date, total_amount) VALUES
(1, '2023-12-31', 120.00),
(2, '2024-01-01', 450.00),
(3, '2024-06-15', 780.00),
(4, '2024-12-31', 310.00),
(5, '2025-01-01', 990.00);

-- --- [SOLUTION QUERY] ---
-- SARGable range predicate that enables B-Tree Index Seek
SELECT 
    invoice_id,
    invoice_date,
    total_amount
FROM invoices
WHERE invoice_date >= '2024-01-01' 
  AND invoice_date < '2025-01-01'
ORDER BY invoice_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[invoice_id] = 2
""")

save("01_core_sql_fundamentals", "004_relational_constraints_and_cascade_rules.sql", """-- ============================================================================
-- EXERCISE: 004_relational_constraints_and_cascade_rules.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   In a SaaS multi-tenant application, tenants can be deactivated or deleted.
--   When a tenant is deleted, all child user accounts must be automatically
--   purged, but their financial invoice history must be preserved with tenant_id
--   set to NULL for legal compliance.
-- PROBLEM STATEMENT:
--   Demonstrate the architectural difference between ON DELETE CASCADE and
--   ON DELETE SET NULL / RESTRICT.
-- ============================================================================

DROP TABLE IF EXISTS tenant_users;
DROP TABLE IF EXISTS tenant_invoices;
DROP TABLE IF EXISTS tenants;

CREATE TABLE tenants (
    tenant_id INT PRIMARY KEY,
    tenant_name VARCHAR(100)
);

CREATE TABLE tenant_users (
    user_id INT PRIMARY KEY,
    tenant_id INT,
    user_name VARCHAR(100),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE CASCADE
);

CREATE TABLE tenant_invoices (
    invoice_id INT PRIMARY KEY,
    tenant_id INT,
    amount DECIMAL(10, 2),
    FOREIGN KEY (tenant_id) REFERENCES tenants(tenant_id) ON DELETE SET NULL
);

INSERT INTO tenants VALUES (1, 'Acme Corp'), (2, 'Globex Inc');
INSERT INTO tenant_users VALUES (101, 1, 'Alice'), (102, 1, 'Bob'), (103, 2, 'Charlie');
INSERT INTO tenant_invoices VALUES (501, 1, 1500.00), (502, 2, 2400.00);

-- Execute tenant deletion
DELETE FROM tenants WHERE tenant_id = 1;

-- --- [SOLUTION QUERY] ---
-- Verify users were cascaded (deleted) and invoice tenant_id was set to NULL
SELECT 
    i.invoice_id,
    i.tenant_id AS orphaned_tenant_id,
    i.amount,
    (SELECT COUNT(*) FROM tenant_users WHERE tenant_id = 1) AS remaining_users_for_tenant_1
FROM tenant_invoices i
WHERE i.invoice_id = 501;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[remaining_users_for_tenant_1] = 0
""")

save("01_core_sql_fundamentals", "005_safe_type_casting_and_numeric_precision.sql", """-- ============================================================================
-- EXERCISE: 005_safe_type_casting_and_numeric_precision.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A financial reporting service computes portfolio performance percentages.
--   Raw input fields contain corrupted string entries ('N/A', 'PENDING', empty)
--   and integers. Integer division truncates percentages to 0, and invalid casts
--   crash the overnight ETL batch.
-- PROBLEM STATEMENT:
--   Implement safe type casting that guards against non-numeric corruptions and
--   prevents integer division truncation without throwing fatal exceptions.
-- ============================================================================

DROP TABLE IF EXISTS raw_portfolio_feed;
CREATE TABLE raw_portfolio_feed (
    holding_id INT PRIMARY KEY,
    shares_count INT,
    total_shares INT,
    raw_valuation VARCHAR(50)
);

INSERT INTO raw_portfolio_feed VALUES
(1, 25, 100, '5000.50'),
(2, 40, 80, 'N/A'),
(3, 10, 10, '1200.00'),
(4, 5, 50, ''),
(5, 0, 100, '0.00');

-- --- [SOLUTION QUERY] ---
-- Demonstrates floating cast to prevent int truncation and safe conversion logic
SELECT 
    holding_id,
    shares_count,
    total_shares,
    -- Prevent integer division (25/100 = 0 in SQL without float conversion)
    ROUND(CAST(shares_count AS FLOAT) / NULLIF(total_shares, 0) * 100.0, 2) AS ownership_pct,
    -- Safe parse: if raw_valuation is numeric string, cast; otherwise default to 0.00
    CASE 
        WHEN raw_valuation GLOB '[0-9]*.[0-9]*' OR raw_valuation GLOB '[0-9]*'
        THEN CAST(raw_valuation AS DECIMAL(10, 2))
        ELSE 0.00
    END AS sanitized_valuation
FROM raw_portfolio_feed
ORDER BY holding_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[ownership_pct] = 25.0
""")

save("01_core_sql_fundamentals", "006_string_manipulation_and_pattern_extraction.sql", """-- ============================================================================
-- EXERCISE: 006_string_manipulation_and_pattern_extraction.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   User identity management records email addresses in mixed casing with leading
--   and trailing whitespace. Fraud teams need to extract the email domain to
--   aggregate disposable domain abuse.
-- PROBLEM STATEMENT:
--   Sanitize customer emails (trim, lowercase) and extract the domain substring
--   after the '@' symbol using standard SQL string functions.
-- ============================================================================

DROP TABLE IF EXISTS user_registrations;
CREATE TABLE user_registrations (
    user_id INT PRIMARY KEY,
    raw_email VARCHAR(255)
);

INSERT INTO user_registrations VALUES
(1, '  Alice@CORP.ACME.COM  '),
(2, 'Bob.Smith@gmail.com'),
(3, 'CHARLIE@TEMP-MAIL.ORG  '),
(4, '  david@corp.acme.com');

-- --- [SOLUTION QUERY] ---
SELECT 
    user_id,
    LOWER(TRIM(raw_email)) AS clean_email,
    SUBSTR(
        LOWER(TRIM(raw_email)), 
        INSTR(LOWER(TRIM(raw_email)), '@') + 1
    ) AS email_domain
FROM user_registrations
ORDER BY user_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[email_domain] = corp.acme.com
""")

save("01_core_sql_fundamentals", "007_temporal_and_timestamp_arithmetic.sql", """-- ============================================================================
-- EXERCISE: 007_temporal_and_timestamp_arithmetic.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A subscription platform charges monthly recurring subscriptions. If an
--   account is 30 days overdue, it must be flagged for cancellation. If an
--   invoice was generated within the last 7 days, it is considered in the
--   grace period.
-- PROBLEM STATEMENT:
--   Calculate the exact date difference between invoice date and due date,
--   and categorize billing status based on temporal intervals.
-- ============================================================================

DROP TABLE IF EXISTS billing_schedules;
CREATE TABLE billing_schedules (
    subscription_id INT PRIMARY KEY,
    customer_id INT,
    invoice_date TEXT,
    due_date TEXT,
    paid_date TEXT
);

INSERT INTO billing_schedules VALUES
(1, 101, '2024-05-01', '2024-05-15', '2024-05-10'),
(2, 102, '2024-05-01', '2024-05-15', '2024-05-28'),
(3, 103, '2024-05-01', '2024-05-15', NULL),
(4, 104, '2024-04-01', '2024-04-15', NULL);

-- --- [SOLUTION QUERY] ---
SELECT 
    subscription_id,
    customer_id,
    invoice_date,
    due_date,
    paid_date,
    CASE 
        WHEN paid_date IS NOT NULL AND paid_date <= due_date THEN 'ON_TIME'
        WHEN paid_date IS NOT NULL AND paid_date > due_date THEN 'PAID_LATE'
        WHEN paid_date IS NULL AND due_date < '2024-05-20' THEN 'DEFAULTED_OVERDUE'
        ELSE 'PENDING'
    END AS billing_status
FROM billing_schedules
ORDER BY subscription_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[billing_status] = ON_TIME
""")

save("01_core_sql_fundamentals", "008_conditional_case_logic_and_nullif_coalesce.sql", """-- ============================================================================
-- EXERCISE: 008_conditional_case_logic_and_nullif_coalesce.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   E-commerce return rate analytics require calculating the ratio of returned
--   items to total sold items. If total sold is 0, the query will crash with a
--   fatal division-by-zero error.
-- PROBLEM STATEMENT:
--   Safely compute the return percentage using NULLIF to transform 0 denominators
--   into NULL, then COALESCE the resulting quotient to 0.00%.
-- ============================================================================

DROP TABLE IF EXISTS product_sales_stats;
CREATE TABLE product_sales_stats (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    units_sold INT,
    units_returned INT
);

INSERT INTO product_sales_stats VALUES
(1, 'Wireless Mouse', 500, 25),
(2, 'Mechanical Keyboard', 200, 10),
(3, 'USB-C Cable', 0, 0),
(4, 'Noise Cancelling Headphones', 100, 15);

-- --- [SOLUTION QUERY] ---
SELECT 
    product_id,
    product_name,
    units_sold,
    units_returned,
    COALESCE(
        ROUND(CAST(units_returned AS FLOAT) / NULLIF(units_sold, 0) * 100.0, 2),
        0.00
    ) AS return_rate_pct
FROM product_sales_stats
ORDER BY product_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[return_rate_pct] = 5.0
""")

save("01_core_sql_fundamentals", "009_filtering_edge_cases_not_exists_vs_not_in.sql", """-- ============================================================================
-- EXERCISE: 009_filtering_edge_cases_not_exists_vs_not_in.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   A security audit must locate all internal employee badges that have NEVER
--   accessed secure server facilities. The badge swipe log contains NULL entries
--   for anonymized or unauthenticated gateway attempts.
-- PROBLEM STATEMENT:
--   Write an anti-join query using NOT EXISTS to find employees without swipe
--   logs, and explain why NOT IN fails catastrophically when subquery contains NULL.
-- ============================================================================

DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS facility_access_log;

CREATE TABLE employees (
    badge_id INT PRIMARY KEY,
    employee_name VARCHAR(100)
);

CREATE TABLE facility_access_log (
    log_id INT PRIMARY KEY,
    badge_id INT, -- Contains NULLs for guest/unregistered taps
    access_time TEXT
);

INSERT INTO employees VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie'), (4, 'David');
INSERT INTO facility_access_log VALUES (101, 1, '2024-05-01 08:30:00'), (102, 2, '2024-05-01 09:15:00'), (103, NULL, '2024-05-01 10:00:00');

-- --- [SOLUTION QUERY] ---
-- Using NOT EXISTS: resilient to NULL values in the target table
SELECT 
    e.badge_id,
    e.employee_name
FROM employees e
WHERE NOT EXISTS (
    SELECT 1 
    FROM facility_access_log l 
    WHERE l.badge_id = e.badge_id
)
ORDER BY e.badge_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[employee_name] = Charlie
""")

save("01_core_sql_fundamentals", "010_idempotent_ddl_and_safe_schema_migrations.sql", """-- ============================================================================
-- EXERCISE: 010_idempotent_ddl_and_safe_schema_migrations.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Continuous deployment CI/CD pipelines run database migration scripts on
--   every deployment. If a migration script is re-run against an existing database,
--   it must be idempotent (must not throw 'table already exists' or fail).
-- PROBLEM STATEMENT:
--   Create an idempotent DDL migration script with table creation guards,
--   index checks, and safe default value population.
-- ============================================================================

CREATE TABLE IF NOT EXISTS system_feature_flags (
    feature_key VARCHAR(50) PRIMARY KEY,
    is_enabled BOOLEAN DEFAULT FALSE,
    rollout_percentage INT DEFAULT 0
);

INSERT INTO system_feature_flags (feature_key, is_enabled, rollout_percentage)
VALUES ('dark_mode', 1, 100)
ON CONFLICT(feature_key) DO UPDATE SET
    is_enabled = EXCLUDED.is_enabled,
    rollout_percentage = EXCLUDED.rollout_percentage;

-- --- [SOLUTION QUERY] ---
SELECT 
    feature_key,
    is_enabled,
    rollout_percentage
FROM system_feature_flags
WHERE feature_key = 'dark_mode';

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[feature_key] = dark_mode
""")

# ==============================================================================
# MODULE 02: Joins & Set Operations Deep Dive (011 - 020)
# ==============================================================================

save("02_joins_and_set_operations", "011_inner_left_right_full_outer_joins.sql", """-- ============================================================================
-- EXERCISE: 011_inner_left_right_full_outer_joins.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Sales management wants a complete list of all registered sales reps and
--   their deals closed this quarter. A junior developer placed a filter on deal
--   status in the WHERE clause of a LEFT JOIN, accidentally turning it into an
--   INNER JOIN and dropping reps who have closed zero deals.
-- PROBLEM STATEMENT:
--   Demonstrate the critical semantic difference between filtering the right-side
--   table in the ON clause vs. in the WHERE clause of an outer join.
-- ============================================================================

DROP TABLE IF EXISTS sales_deals;
DROP TABLE IF EXISTS sales_reps;

CREATE TABLE sales_reps (
    rep_id INT PRIMARY KEY,
    rep_name VARCHAR(100)
);

CREATE TABLE sales_deals (
    deal_id INT PRIMARY KEY,
    rep_id INT,
    amount DECIMAL(10, 2),
    deal_status VARCHAR(20)
);

INSERT INTO sales_reps VALUES (1, 'Alice'), (2, 'Bob'), (3, 'Charlie');
INSERT INTO sales_deals VALUES (101, 1, 50000.00, 'WON'), (102, 1, 20000.00, 'LOST'), (103, 2, 15000.00, 'LOST');

-- --- [SOLUTION QUERY] ---
-- Keep condition in ON clause so reps with 0 WON deals are NOT eliminated!
SELECT 
    r.rep_id,
    r.rep_name,
    COALESCE(SUM(d.amount), 0.00) AS total_won_amount,
    COUNT(d.deal_id) AS total_won_deals
FROM sales_reps r
LEFT JOIN sales_deals d 
    ON r.rep_id = d.rep_id 
    AND d.deal_status = 'WON' -- Evaluated during join, preserving all left rows!
GROUP BY r.rep_id, r.rep_name
ORDER BY r.rep_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[total_won_amount] = 50000.00
""")

save("02_joins_and_set_operations", "012_semi_joins_and_duplicate_multiplier_prevention.sql", """-- ============================================================================
-- EXERCISE: 012_semi_joins_and_duplicate_multiplier_prevention.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Finance needs to calculate the total credit limit of customers who placed
--   at least one high-value order (> $1,000). Joining customers directly to orders
--   multiplies the customer's credit limit by the number of orders they placed,
--   vastly overstating company risk.
-- PROBLEM STATEMENT:
--   Implement a Semi-Join using EXISTS to qualify customers without row multiplication.
-- ============================================================================

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    credit_limit DECIMAL(10, 2)
);

CREATE TABLE order_items (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_total DECIMAL(10, 2)
);

INSERT INTO customers VALUES (1, 'Acme Corp', 50000.00), (2, 'Beta LLC', 30000.00), (3, 'Gamma Inc', 20000.00);
INSERT INTO order_items VALUES (101, 1, 1500.00), (102, 1, 2000.00), (103, 1, 1200.00), (104, 2, 500.00);

-- --- [SOLUTION QUERY] ---
-- Semi-Join via EXISTS: zero row multiplication
SELECT 
    c.customer_id,
    c.customer_name,
    c.credit_limit
FROM customers c
WHERE EXISTS (
    SELECT 1 
    FROM order_items o 
    WHERE o.customer_id = c.customer_id 
      AND o.order_total > 1000.00
)
ORDER BY c.customer_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[credit_limit] = 50000.00
""")

save("02_joins_and_set_operations", "013_anti_joins_for_missing_record_detection.sql", """-- ============================================================================
-- EXERCISE: 013_anti_joins_for_missing_record_detection.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Customer Success needs a report of all accounts that signed up over 90 days
--   ago but have never created an active project.
-- PROBLEM STATEMENT:
--   Implement an Anti-Join comparing NOT EXISTS vs. LEFT JOIN ... WHERE right.id IS NULL.
-- ============================================================================

DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS accounts;

CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    account_name VARCHAR(100),
    created_at TEXT
);

CREATE TABLE projects (
    project_id INT PRIMARY KEY,
    account_id INT,
    project_name VARCHAR(100)
);

INSERT INTO accounts VALUES (1, 'Alpha Corp', '2023-01-10'), (2, 'Beta Inc', '2023-02-15'), (3, 'Gamma LLC', '2023-03-20');
INSERT INTO projects VALUES (101, 1, 'Website Redesign'), (102, 1, 'Mobile App');

-- --- [SOLUTION QUERY] ---
SELECT 
    a.account_id,
    a.account_name,
    a.created_at
FROM accounts a
LEFT JOIN projects p ON a.account_id = p.account_id
WHERE p.project_id IS NULL
ORDER BY a.account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[account_name] = Beta Inc
""")

save("02_joins_and_set_operations", "014_full_outer_joins_for_reconciliation.sql", """-- ============================================================================
-- EXERCISE: 014_full_outer_joins_for_reconciliation.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Daily reconciliation between internal payment ledger and Stripe settlement
--   files. Records can exist in internal ledger but missing in Stripe, or exist
--   in Stripe but missing internally, or have mismatched amounts.
-- PROBLEM STATEMENT:
--   Perform bidirectional data reconciliation using a FULL OUTER JOIN (emulated
--   via UNION in SQLite for universal engine portability).
-- ============================================================================

DROP TABLE IF EXISTS internal_ledger;
DROP TABLE IF EXISTS stripe_settlements;

CREATE TABLE internal_ledger (
    txn_id VARCHAR(50) PRIMARY KEY,
    internal_amount DECIMAL(10, 2)
);

CREATE TABLE stripe_settlements (
    txn_id VARCHAR(50) PRIMARY KEY,
    stripe_amount DECIMAL(10, 2)
);

INSERT INTO internal_ledger VALUES ('TXN_001', 100.00), ('TXN_002', 250.00), ('TXN_003', 400.00);
INSERT INTO stripe_settlements VALUES ('TXN_001', 100.00), ('TXN_002', 240.00), ('TXN_004', 550.00);

-- --- [SOLUTION QUERY] ---
-- Universal Full Outer Reconciliation
WITH full_reconciliation AS (
    SELECT 
        COALESCE(i.txn_id, s.txn_id) AS txn_id,
        i.internal_amount,
        s.stripe_amount
    FROM internal_ledger i
    LEFT JOIN stripe_settlements s ON i.txn_id = s.txn_id
    UNION
    SELECT 
        COALESCE(i.txn_id, s.txn_id) AS txn_id,
        i.internal_amount,
        s.stripe_amount
    FROM stripe_settlements s
    LEFT JOIN internal_ledger i ON s.txn_id = i.txn_id
)
SELECT 
    txn_id,
    internal_amount,
    stripe_amount,
    CASE 
        WHEN internal_amount IS NULL THEN 'MISSING_IN_INTERNAL_LEDGER'
        WHEN stripe_amount IS NULL THEN 'MISSING_IN_STRIPE'
        WHEN internal_amount != stripe_amount THEN 'AMOUNT_MISMATCH'
        ELSE 'RECONCILED_MATCH'
    END AS recon_status
FROM full_reconciliation
ORDER BY txn_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[recon_status] = RECONCILED_MATCH
""")

save("02_joins_and_set_operations", "015_cross_joins_and_cartesian_grid_generation.sql", """-- ============================================================================
-- EXERCISE: 015_cross_joins_and_cartesian_grid_generation.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Retail store analytics requires generating a continuous reporting grid of
--   all stores for all dates in a promo week, even if a store recorded 0 sales.
-- PROBLEM STATEMENT:
--   Generate a complete Cartesian grid using CROSS JOIN, then LEFT JOIN actual
--   sales to impute 0 for missing store-date combinations.
-- ============================================================================

DROP TABLE IF EXISTS store_sales;
DROP TABLE IF EXISTS dim_stores;
DROP TABLE IF EXISTS dim_dates;

CREATE TABLE dim_stores (
    store_id INT PRIMARY KEY,
    store_name VARCHAR(50)
);

CREATE TABLE dim_dates (
    calendar_date TEXT PRIMARY KEY
);

CREATE TABLE store_sales (
    store_id INT,
    calendar_date TEXT,
    revenue DECIMAL(10, 2),
    PRIMARY KEY (store_id, calendar_date)
);

INSERT INTO dim_stores VALUES (1, 'Downtown'), (2, 'Uptown');
INSERT INTO dim_dates VALUES ('2024-06-01'), ('2024-06-02');
INSERT INTO store_sales VALUES (1, '2024-06-01', 1200.00), (2, '2024-06-02', 1800.00);

-- --- [SOLUTION QUERY] ---
SELECT 
    s.store_id,
    s.store_name,
    d.calendar_date,
    COALESCE(sales.revenue, 0.00) AS daily_revenue
FROM dim_stores s
CROSS JOIN dim_dates d
LEFT JOIN store_sales sales 
    ON s.store_id = sales.store_id 
    AND d.calendar_date = sales.calendar_date
ORDER BY s.store_id ASC, d.calendar_date ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[daily_revenue] = 1200.00
""")

save("02_joins_and_set_operations", "016_non_equi_joins_and_effective_date_matching.sql", """-- ============================================================================
-- EXERCISE: 016_non_equi_joins_and_effective_date_matching.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Product pricing changes over time. When an order is placed, it must be
--   joined with the product price active on that specific order timestamp.
-- PROBLEM STATEMENT:
--   Join orders to product price schedules using a Non-Equi Join where
--   order_date BETWEEN valid_from AND valid_to.
-- ============================================================================

DROP TABLE IF EXISTS product_prices;
DROP TABLE IF EXISTS raw_orders;

CREATE TABLE product_prices (
    product_id INT,
    unit_price DECIMAL(10, 2),
    valid_from TEXT,
    valid_to TEXT
);

CREATE TABLE raw_orders (
    order_id INT PRIMARY KEY,
    product_id INT,
    quantity INT,
    order_date TEXT
);

INSERT INTO product_prices VALUES
(1, 19.99, '2024-01-01', '2024-03-31'),
(1, 24.99, '2024-04-01', '2024-12-31'),
(2, 99.00, '2024-01-01', '2024-12-31');

INSERT INTO raw_orders VALUES
(101, 1, 2, '2024-02-15'),
(102, 1, 3, '2024-05-10'),
(103, 2, 1, '2024-05-10');

-- --- [SOLUTION QUERY] ---
SELECT 
    o.order_id,
    o.product_id,
    o.order_date,
    o.quantity,
    p.unit_price,
    ROUND(o.quantity * p.unit_price, 2) AS line_total
FROM raw_orders o
JOIN product_prices p 
    ON o.product_id = p.product_id
    AND o.order_date >= p.valid_from
    AND o.order_date <= p.valid_to
ORDER BY o.order_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[line_total] = 39.98
""")

save("02_joins_and_set_operations", "017_lateral_joins_and_cross_apply_expansions.sql", """-- ============================================================================
-- EXERCISE: 017_lateral_joins_and_cross_apply_expansions.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   For an executive summary, retrieve each customer along with their top 2
--   most expensive orders.
-- PROBLEM STATEMENT:
--   Implement Top-N per category using window functions and correlated subqueries.
-- ============================================================================

DROP TABLE IF EXISTS customer_orders;
DROP TABLE IF EXISTS clients;

CREATE TABLE clients (
    client_id INT PRIMARY KEY,
    client_name VARCHAR(100)
);

CREATE TABLE customer_orders (
    order_id INT PRIMARY KEY,
    client_id INT,
    amount DECIMAL(10, 2)
);

INSERT INTO clients VALUES (1, 'Acme Corp'), (2, 'Globex Inc');
INSERT INTO customer_orders VALUES
(1, 1, 500.00), (2, 1, 1200.00), (3, 1, 300.00), (4, 1, 950.00),
(5, 2, 2000.00), (6, 2, 1500.00), (7, 2, 800.00);

-- --- [SOLUTION QUERY] ---
WITH ranked_orders AS (
    SELECT 
        client_id,
        order_id,
        amount,
        ROW_NUMBER() OVER (
            PARTITION BY client_id 
            ORDER BY amount DESC
        ) AS order_rank
    FROM customer_orders
)
SELECT 
    c.client_id,
    c.client_name,
    r.order_id,
    r.amount,
    r.order_rank
FROM clients c
JOIN ranked_orders r 
    ON c.client_id = r.client_id 
    AND r.order_rank <= 2
ORDER BY c.client_id ASC, r.order_rank ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[amount] = 1200.00
""")

save("02_joins_and_set_operations", "018_union_vs_union_all_internals.sql", """-- ============================================================================
-- EXERCISE: 018_union_vs_union_all_internals.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Beginner / Foundation
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Consolidating transactional logs across web and mobile channels. Using UNION
--   incurs an unneeded multi-stage sort across millions of rows when rows are
--   already known to be disjoint.
-- PROBLEM STATEMENT:
--   Demonstrate when UNION is needed for deduplication versus when UNION ALL
--   is strictly required for performance and stream preservation.
-- ============================================================================

DROP TABLE IF EXISTS web_clicks;
DROP TABLE IF EXISTS mobile_clicks;

CREATE TABLE web_clicks (click_id INT, user_id INT, page VARCHAR(50));
CREATE TABLE mobile_clicks (click_id INT, user_id INT, page VARCHAR(50));

INSERT INTO web_clicks VALUES (1, 101, 'home'), (2, 102, 'cart'), (3, 103, 'checkout');
INSERT INTO mobile_clicks VALUES (3, 103, 'checkout'), (4, 104, 'search'), (5, 105, 'profile');

-- --- [SOLUTION QUERY] ---
-- UNION ALL preserves every raw event without sort overhead
SELECT 'WEB' AS channel, click_id, user_id, page FROM web_clicks
UNION ALL
SELECT 'MOBILE' AS channel, click_id, user_id, page FROM mobile_clicks
ORDER BY click_id ASC, channel ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[user_id] = 101
""")

save("02_joins_and_set_operations", "019_intersect_and_except_data_audits.sql", """-- ============================================================================
-- EXERCISE: 019_intersect_and_except_data_audits.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Data migration verification between Legacy Oracle EDW and Modern Snowflake
--   Lakehouse. Data quality auditors require finding rows that exist in Legacy
--   but failed to land in Snowflake (EXCEPT), and rows common to both (INTERSECT).
-- PROBLEM STATEMENT:
--   Execute set operations INTERSECT and EXCEPT to perform audit reconciliations.
-- ============================================================================

DROP TABLE IF EXISTS legacy_customers;
DROP TABLE IF EXISTS modern_customers;

CREATE TABLE legacy_customers (customer_id INT, email VARCHAR(100));
CREATE TABLE modern_customers (customer_id INT, email VARCHAR(100));

INSERT INTO legacy_customers VALUES (1, 'alice@acme.com'), (2, 'bob@acme.com'), (3, 'charlie@acme.com');
INSERT INTO modern_customers VALUES (1, 'alice@acme.com'), (2, 'bob@acme.com'), (4, 'david@acme.com');

-- --- [SOLUTION QUERY] ---
-- Detect customers missing from Modern Lakehouse (Legacy EXCEPT Modern)
SELECT customer_id, email FROM legacy_customers
EXCEPT
SELECT customer_id, email FROM modern_customers
ORDER BY customer_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[customer_id] = 3
""")

save("02_joins_and_set_operations", "020_self_joins_for_sequential_event_pairs.sql", """-- ============================================================================
-- EXERCISE: 020_self_joins_for_sequential_event_pairs.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   User session flow analysis requires calculating how many seconds a user
--   spent on Step 1 before transitioning to Step 2 in a checkout funnel.
-- PROBLEM STATEMENT:
--   Self-join the funnel events table to match consecutive event steps for the
--   same user session and calculate time elapsed.
-- ============================================================================

DROP TABLE IF EXISTS funnel_steps;
CREATE TABLE funnel_steps (
    session_id INT,
    step_number INT,
    step_name VARCHAR(50),
    step_timestamp INT -- Unix epoch seconds
);

INSERT INTO funnel_steps VALUES
(101, 1, 'View Product', 1700000000),
(101, 2, 'Add to Cart', 1700000045),
(101, 3, 'Complete Purchase', 1700000120),
(102, 1, 'View Product', 1700000500),
(102, 2, 'Add to Cart', 1700000580);

-- --- [SOLUTION QUERY] ---
SELECT 
    curr.session_id,
    curr.step_number AS from_step_num,
    curr.step_name   AS from_step,
    next.step_name   AS to_step,
    (next.step_timestamp - curr.step_timestamp) AS duration_seconds
FROM funnel_steps curr
JOIN funnel_steps next 
    ON curr.session_id = next.session_id 
    AND curr.step_number + 1 = next.step_number
ORDER BY curr.session_id ASC, curr.step_number ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[duration_seconds] = 45
""")

print("Module 01 and Module 02 generation complete!")
