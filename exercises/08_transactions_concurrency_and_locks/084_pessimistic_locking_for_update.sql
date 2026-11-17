-- ============================================================================
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
