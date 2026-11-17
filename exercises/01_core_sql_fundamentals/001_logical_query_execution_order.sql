-- ============================================================================
-- EXERCISE: 001_logical_query_execution_order.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Senior Analytics Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Multi-Tenant SaaS Billing & Margin Reconciliation Engine.
--   Incoming billing transactions stream from Stripe webhooks and ERP feeds into
--   a staging lakehouse layer. Upstream pipeline failures occur when downstream
--   analytical marts attempt non-SARGable predicate filtering on computed projections.
--
-- BUSINESS CONTEXT:
--   A B2B SaaS platform bills enterprise customers based on base platform fees,
--   tiered compute overages, and contracted partner revenue shares. Finance requires
--   an automated margin waterfall to detect accounts operating at an effective
--   gross margin below 35% after accounting for infrastructure compute costs.
--   Junior engineers repeatedly encounter SQL compilation errors by referencing
--   SELECT-projected column aliases ('effective_margin_pct') inside the WHERE clause.
--
-- PROBLEM STATEMENT:
--   1. Enforce understanding of the ANSI SQL Logical Execution Pipeline:
--      (1) FROM -> (2) ON -> (3) JOIN -> (4) WHERE -> (5) GROUP BY -> 
--      (6) HAVING -> (7) WINDOW -> (8) SELECT -> (9) DISTINCT -> (10) ORDER BY -> (11) LIMIT
--   2. Build a production-grade multi-stage CTE pipeline that materializes
--      computed billing metrics, calculates cost-of-goods-sold (COGS) allocations,
--      and filters accounts breaching margin thresholds without alias compilation errors.
--
-- DISTRIBUTED ENGINE & COMPILATION INTERNALS:
--   In Snowflake, Google BigQuery, and Databricks Spark SQL, logical query plan
--   analyzers resolve column identifiers at Step 4 (Filter/WHERE) before projection
--   expressions at Step 8 (Project/SELECT) are even bound. Attempting to filter on an
--   unbound alias forces query recompilation or plan failure.
-- ============================================================================

DROP TABLE IF EXISTS saas_invoice_lines;
DROP TABLE IF EXISTS saas_billing_invoices;
DROP TABLE IF EXISTS saas_tenants;

CREATE TABLE saas_tenants (
    tenant_id VARCHAR(32) PRIMARY KEY,
    organization_name VARCHAR(100) NOT NULL,
    pricing_tier VARCHAR(20) NOT NULL, -- ENTERPRISE, MID_MARKET, GROWTH
    contract_discount_pct DECIMAL(5, 4) NOT NULL
);

CREATE TABLE saas_billing_invoices (
    invoice_id VARCHAR(32) PRIMARY KEY,
    tenant_id VARCHAR(32) NOT NULL,
    billing_cycle_month VARCHAR(7) NOT NULL, -- YYYY-MM
    invoice_status VARCHAR(20) NOT NULL,    -- PAID, PENDING, VOID, DISPUTED
    issued_timestamp TEXT NOT NULL,
    FOREIGN KEY (tenant_id) REFERENCES saas_tenants(tenant_id)
);

CREATE TABLE saas_invoice_lines (
    line_item_id VARCHAR(32) PRIMARY KEY,
    invoice_id VARCHAR(32) NOT NULL,
    service_category VARCHAR(30) NOT NULL, -- CORE_PLATFORM, COMPUTE_OVERAGE, PREMIUM_SUPPORT
    raw_units INT NOT NULL,
    unit_rate_usd DECIMAL(10, 4) NOT NULL,
    allocated_infra_cogs_usd DECIMAL(10, 4) NOT NULL,
    FOREIGN KEY (invoice_id) REFERENCES saas_billing_invoices(invoice_id)
);

-- Seed realistic enterprise billing data across multiple tenants and cycles
INSERT INTO saas_tenants VALUES
('TNT-1001', 'Acme Global Cloud', 'ENTERPRISE', 0.1500),
('TNT-1002', 'Starlight Media Systems', 'MID_MARKET', 0.0500),
('TNT-1003', 'Apex Financial Technologies', 'ENTERPRISE', 0.2000),
('TNT-1004', 'OmniRetail Logistics', 'GROWTH', 0.0000);

INSERT INTO saas_billing_invoices VALUES
('INV-2024-001', 'TNT-1001', '2024-05', 'PAID', '2024-05-31 23:59:59'),
('INV-2024-002', 'TNT-1002', '2024-05', 'PAID', '2024-05-31 23:59:59'),
('INV-2024-003', 'TNT-1003', '2024-05', 'PAID', '2024-05-31 23:59:59'),
('INV-2024-004', 'TNT-1004', '2024-05', 'VOID', '2024-05-31 23:59:59'), -- Should be excluded in WHERE
('INV-2024-005', 'TNT-1001', '2024-06', 'PAID', '2024-06-30 23:59:59');

INSERT INTO saas_invoice_lines VALUES
-- TNT-1001 (Acme Global) May: High revenue, healthy margin
('LIN-001', 'INV-2024-001', 'CORE_PLATFORM', 1, 15000.0000, 3200.0000),
('LIN-002', 'INV-2024-001', 'COMPUTE_OVERAGE', 450, 20.0000, 6800.0000),
-- TNT-1002 (Starlight) May: Unhealthy compute cost blowout (Low Margin)
('LIN-003', 'INV-2024-002', 'CORE_PLATFORM', 1, 5000.0000, 1800.0000),
('LIN-004', 'INV-2024-002', 'COMPUTE_OVERAGE', 800, 12.0000, 9100.0000),
-- TNT-1003 (Apex) May: Moderate margin
('LIN-005', 'INV-2024-003', 'CORE_PLATFORM', 1, 25000.0000, 8500.0000),
('LIN-006', 'INV-2024-003', 'PREMIUM_SUPPORT', 1, 5000.0000, 1200.0000),
-- TNT-1004 (Voided invoice lines)
('LIN-007', 'INV-2024-004', 'CORE_PLATFORM', 1, 2000.0000, 600.0000),
-- TNT-1001 June
('LIN-008', 'INV-2024-005', 'CORE_PLATFORM', 1, 15000.0000, 3100.0000);

-- --- [SOLUTION QUERY] ---
-- Production multi-tier CTE pipeline respecting logical execution order
WITH stg_active_invoices AS (
    -- Step 1 & 2: Filter out non-actionable invoices BEFORE downstream joins and grouping
    SELECT 
        inv.invoice_id,
        inv.tenant_id,
        inv.billing_cycle_month,
        t.organization_name,
        t.pricing_tier,
        t.contract_discount_pct
    FROM saas_billing_invoices inv
    INNER JOIN saas_tenants t ON inv.tenant_id = t.tenant_id
    WHERE inv.invoice_status = 'PAID'
),
invoice_waterfall_aggregates AS (
    -- Step 3 & 4: Aggregate line items to invoice grain, computing net revenue and total COGS
    SELECT 
        inv.tenant_id,
        inv.organization_name,
        inv.pricing_tier,
        inv.billing_cycle_month,
        COUNT(l.line_item_id) AS total_line_items,
        SUM(l.raw_units * l.unit_rate_usd) AS gross_billed_usd,
        ROUND(SUM(l.raw_units * l.unit_rate_usd * (1.0 - inv.contract_discount_pct)), 2) AS net_billed_usd,
        ROUND(SUM(l.allocated_infra_cogs_usd), 2) AS total_cogs_usd
    FROM stg_active_invoices inv
    INNER JOIN saas_invoice_lines l ON inv.invoice_id = l.invoice_id
    GROUP BY 
        inv.tenant_id,
        inv.organization_name,
        inv.pricing_tier,
        inv.billing_cycle_month,
        inv.contract_discount_pct
),
margin_evaluation AS (
    -- Step 5: Project calculated margin expressions in a materialized CTE layer
    -- This resolves aliases so downstream steps can safely filter and sort without 
    -- violating ANSI SQL logical evaluation order!
    SELECT 
        tenant_id,
        organization_name,
        pricing_tier,
        billing_cycle_month,
        gross_billed_usd,
        net_billed_usd,
        total_cogs_usd,
        ROUND(net_billed_usd - total_cogs_usd, 2) AS gross_margin_usd,
        ROUND((net_billed_usd - total_cogs_usd) / NULLIF(net_billed_usd, 0.0), 4) AS effective_margin_pct
    FROM invoice_waterfall_aggregates
)
-- Step 6: Final presentation & audit threshold filtering
SELECT 
    tenant_id,
    organization_name,
    pricing_tier,
    billing_cycle_month,
    net_billed_usd,
    total_cogs_usd,
    gross_margin_usd,
    effective_margin_pct,
    CASE 
        WHEN effective_margin_pct >= 0.50 THEN 'HEALTHY_EXPANSION'
        WHEN effective_margin_pct >= 0.35 THEN 'STABLE_STANDARD'
        ELSE 'CRITICAL_MARGIN_EROSION'
    END AS financial_health_grade
FROM margin_evaluation
WHERE billing_cycle_month = '2024-05'
ORDER BY effective_margin_pct ASC, net_billed_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[tenant_id] = TNT-1002
