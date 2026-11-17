-- ============================================================================
-- EXERCISE: 010_idempotent_ddl_and_safe_schema_migrations.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & DevOps Database Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Zero-Downtime Blue/Green Database Schema Migration Engine.
--   In automated CI/CD deployment pipelines, migration scripts must be 100% idempotent:
--   running the script multiple times against the target database must produce the
--   identical end state without throwing 'OBJECT ALREADY EXISTS' errors, corrupting data,
--   or causing exclusive lock table freezes.
--
-- BUSINESS CONTEXT:
--   An enterprise financial ledger table requires adding an audit tracking column
--   ('compliance_verified_at'), creating supporting search indexes, and backfilling
--   historical records with deterministic defaults without dropping active data.
--
-- PROBLEM STATEMENT:
--   1. Implement safe, idempotent DDL patterns (CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS).
--   2. Add a new column safely and backfill default data using atomic transactional logic.
--   3. Maintain a schema migration audit journal recording execution timestamps and versioning.
-- ============================================================================

-- Step 1: Idempotent creation of migration audit journal
CREATE TABLE IF NOT EXISTS schema_migration_journal (
    migration_version VARCHAR(50) PRIMARY KEY,
    description TEXT NOT NULL,
    executed_at TEXT NOT NULL,
    execution_status VARCHAR(20) NOT NULL
);

-- Step 2: Idempotent creation of base business table
CREATE TABLE IF NOT EXISTS enterprise_accounts (
    account_id VARCHAR(32) PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    account_tier VARCHAR(20) NOT NULL,
    balance_usd DECIMAL(14, 2) NOT NULL
);

-- Seed initial records idempotently
INSERT OR IGNORE INTO enterprise_accounts VALUES
('ACC-001', 'Acme Corporation', 'ENTERPRISE', 150000.00),
('ACC-002', 'Globex Industries', 'MID_MARKET', 45000.00),
('ACC-003', 'Initech Systems', 'GROWTH', 12000.00);

-- Step 3: Record successful migration execution in audit journal
INSERT OR REPLACE INTO schema_migration_journal VALUES
('V1.0__core_accounts_init', 'Initialize enterprise accounts and security journal', datetime('now'), 'SUCCESS');

-- --- [SOLUTION QUERY] ---
-- Verification query checking schema state and audit journal integrity
SELECT 
    m.migration_version,
    m.description,
    a.account_id,
    a.company_name,
    a.account_tier,
    a.balance_usd,
    m.execution_status
FROM enterprise_accounts a
CROSS JOIN schema_migration_journal m
WHERE m.migration_version = 'V1.0__core_accounts_init'
ORDER BY a.balance_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[account_id] = ACC-001
