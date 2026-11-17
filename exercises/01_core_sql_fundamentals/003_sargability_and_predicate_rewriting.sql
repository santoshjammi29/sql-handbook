-- ============================================================================
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
