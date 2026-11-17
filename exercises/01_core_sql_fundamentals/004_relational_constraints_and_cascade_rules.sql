-- ============================================================================
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
