-- ============================================================================
-- EXERCISE: 097_incident_payment_gateway_deadlock_storm.sql
-- MODULE:   10_production_incidents_and_triage
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   PRODUCTION INCIDENT POSTMORTEM: Deadlock Storm in Payment Processing.
--   During Black Friday, concurrent refund webhooks deadlocked across ledger accounts.
--   Transaction 1 updated Account 10 then 20; Transaction 2 updated Account 20 then 10.
-- PROBLEM STATEMENT:
--   Triage and execute production recovery.
-- SURGICAL REMEDIATION:
--   Enforce strict ascending primary key locking order across all endpoints.
-- ============================================================================

DROP TABLE IF EXISTS incident_accounts;
CREATE TABLE incident_accounts (account_id INT PRIMARY KEY, balance DECIMAL(10, 2));

INSERT INTO incident_accounts VALUES (10, 1000.00), (20, 2000.00);

-- Deadlock-proof ordered transfer: Transfer $300 from Account 20 to Account 10
-- Mandatory rule: Lock min(10, 20) first, max(10, 20) second!
BEGIN TRANSACTION;
UPDATE incident_accounts SET balance = balance + 300.00 WHERE account_id = 10;
UPDATE incident_accounts SET balance = balance - 300.00 WHERE account_id = 20;
COMMIT;

-- --- [SOLUTION QUERY] ---
SELECT account_id, balance FROM incident_accounts ORDER BY account_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[balance] = 1300.00
