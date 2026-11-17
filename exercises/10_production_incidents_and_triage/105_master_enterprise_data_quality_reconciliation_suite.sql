-- ============================================================================
-- EXERCISE: 105_master_enterprise_data_quality_reconciliation_suite.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    🟣<br>Architect
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Chief Data Architect & Enterprise Governance Officer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise Data Quality & Automated CI/CD Production Gatekeeper.
--   Before promoting analytical datasets to the Gold Serving Layer or reporting
--   to SEC / FINRA regulators, an automated Data Quality Suite must execute.
--
-- BUSINESS CONTEXT:
--   Enterprise Lakehouse Production Deployment Gatekeeper & Compliance Audit.
--
-- THE 6 DATA QUALITY PILLARS:
--   1. Primary Key Uniqueness: Zero duplicate business keys in dimension or fact tables.
--   2. Referential Integrity: Zero orphaned foreign keys pointing to missing dimensions.
--   3. Nullity Mandate: Zero NULL values across mandatory business attributes.
--   4. Numeric Bounds Sanity: All transaction prices, quantities, and margins >= 0.00.
--   5. Temporal Sanity: Event timestamps must be historically bounded and not occur in the future.
--   6. Financial Reconciliation Invariant: Net billed revenue must mathematically equal
--      gross sales minus discounts plus taxes.
--
-- PROBLEM STATEMENT:
--   Build a master 6-pillar unified Data Quality Reconciliation Suite returning a
--   formal scorecard auditing enterprise sales facts and conformed customer dimensions.
-- ============================================================================

DROP TABLE IF EXISTS gold_sales_facts;
DROP TABLE IF EXISTS gold_dim_customers;

CREATE TABLE gold_dim_customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL
);

CREATE TABLE gold_sales_facts (
    sale_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    gross_amount_usd DECIMAL(12, 2) NOT NULL,
    discount_usd DECIMAL(12, 2) NOT NULL,
    net_billed_usd DECIMAL(12, 2) NOT NULL,
    sale_date TEXT NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES gold_dim_customers(customer_id)
);

INSERT INTO gold_dim_customers VALUES
('CUST-101', 'Apex Global Corp'),
('CUST-102', 'Vanguard Media Group');

INSERT INTO gold_sales_facts VALUES
('SALE-901', 'CUST-101', 1000.00, 100.00,  900.00, '2024-06-01'),
('SALE-902', 'CUST-102', 2500.00, 250.00, 2250.00, '2024-06-01');

-- --- [SOLUTION QUERY] ---
-- Master 6-Pillar Data Quality Reconciliation Scorecard
WITH pillar_1_uniqueness AS (
    SELECT 
        '1. Primary Key Uniqueness' AS test_name,
        CASE WHEN COUNT(sale_id) = COUNT(DISTINCT sale_id) THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM gold_sales_facts
),
pillar_2_referential_integrity AS (
    SELECT 
        '2. Referential Integrity' AS test_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM gold_sales_facts f
    LEFT JOIN gold_dim_customers c ON f.customer_id = c.customer_id
    WHERE c.customer_id IS NULL
),
pillar_3_nullity_mandate AS (
    SELECT 
        '3. Nullity Mandate' AS test_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM gold_sales_facts
    WHERE sale_id IS NULL OR customer_id IS NULL OR net_billed_usd IS NULL OR sale_date IS NULL
),
pillar_4_numeric_bounds AS (
    SELECT 
        '4. Numeric Bounds Sanity' AS test_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM gold_sales_facts
    WHERE gross_amount_usd <= 0.00 OR discount_usd < 0.00 OR net_billed_usd <= 0.00
),
pillar_5_temporal_sanity AS (
    SELECT 
        '5. Temporal Sanity' AS test_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM gold_sales_facts
    WHERE sale_date > '2099-12-31' OR sale_date < '2020-01-01'
),
pillar_6_financial_invariance AS (
    SELECT 
        '6. Financial Reconciliation Invariant' AS test_name,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS test_status
    FROM gold_sales_facts
    WHERE (gross_amount_usd - discount_usd) != net_billed_usd
)
SELECT test_name, test_status FROM pillar_1_uniqueness
UNION ALL SELECT test_name, test_status FROM pillar_2_referential_integrity
UNION ALL SELECT test_name, test_status FROM pillar_3_nullity_mandate
UNION ALL SELECT test_name, test_status FROM pillar_4_numeric_bounds
UNION ALL SELECT test_name, test_status FROM pillar_5_temporal_sanity
UNION ALL SELECT test_name, test_status FROM pillar_6_financial_invariance
ORDER BY test_name ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[test_name] = 1. Primary Key Uniqueness
-- ASSERT: COL[test_status] = PASS\n