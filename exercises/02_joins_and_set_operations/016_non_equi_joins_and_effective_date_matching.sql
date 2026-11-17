-- ============================================================================
-- EXERCISE: 016_non_equi_joins_and_effective_date_matching.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Quantitative Data Architect & High-Frequency Risk Modeler
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Currency Algorithmic Trading & As-Of Rate Conversion Engine.
--   High-frequency financial trade executions occur in foreign currencies.
--   Exchange rates fluctuate continuously throughout the day, logged as temporal
--   rate intervals with [rate_effective_from, rate_effective_to) timestamp boundaries.
--
-- BUSINESS CONTEXT:
--   Trades cannot be joined using standard equi-joins ('ON trade_date = rate_date')
--   because currency markets move every few minutes. Each trade must be matched using
--   a non-equi range condition:
--   'ON t.currency = r.currency AND t.trade_timestamp >= r.rate_effective_from AND t.trade_timestamp < r.rate_effective_to'
--
-- PROBLEM STATEMENT:
--   Execute a high-precision temporal non-equi join that aligns trade executions
--   with the exact applicable FX rate interval, calculating converted USD settlement amounts.
-- ============================================================================

DROP TABLE IF EXISTS execution_trades;
DROP TABLE IF EXISTS temporal_fx_rates;

CREATE TABLE temporal_fx_rates (
    rate_id VARCHAR(32) PRIMARY KEY,
    currency_pair VARCHAR(7) NOT NULL, -- e.g. 'EUR/USD'
    fx_rate DECIMAL(12, 6) NOT NULL,
    valid_from TEXT NOT NULL,          -- ISO-8601 inclusive
    valid_to TEXT NOT NULL             -- ISO-8601 exclusive
);

CREATE TABLE execution_trades (
    trade_id VARCHAR(32) PRIMARY KEY,
    currency_pair VARCHAR(7) NOT NULL,
    trade_timestamp TEXT NOT NULL,
    local_volume DECIMAL(12, 2) NOT NULL
);

INSERT INTO temporal_fx_rates VALUES
('FX-01', 'EUR/USD', 1.082000, '2024-05-01 08:00:00', '2024-05-01 10:00:00'),
('FX-02', 'EUR/USD', 1.086500, '2024-05-01 10:00:00', '2024-05-01 12:00:00'),
('FX-03', 'EUR/USD', 1.084000, '2024-05-01 12:00:00', '2024-05-01 16:00:00'),
('FX-04', 'GBP/USD', 1.271000, '2024-05-01 08:00:00', '2024-05-01 12:00:00'),
('FX-05', 'GBP/USD', 1.274500, '2024-05-01 12:00:00', '2024-05-01 16:00:00');

INSERT INTO execution_trades VALUES
('TRD-101', 'EUR/USD', '2024-05-01 09:15:30', 500000.00), -- Matches FX-01
('TRD-102', 'EUR/USD', '2024-05-01 10:45:10', 250000.00), -- Matches FX-02
('TRD-103', 'EUR/USD', '2024-05-01 14:20:00', 800000.00), -- Matches FX-03
('TRD-104', 'GBP/USD', '2024-05-01 11:30:00', 150000.00), -- Matches FX-04
('TRD-105', 'GBP/USD', '2024-05-01 15:10:00', 400000.00); -- Matches FX-05

-- --- [SOLUTION QUERY] ---
-- Non-equi temporal range join matching each execution to its active interval
SELECT 
    t.trade_id,
    t.trade_timestamp,
    t.currency_pair,
    t.local_volume,
    r.fx_rate,
    r.valid_from AS rate_interval_start,
    r.valid_to AS rate_interval_end,
    ROUND(t.local_volume * r.fx_rate, 2) AS converted_usd_value
FROM execution_trades t
INNER JOIN temporal_fx_rates r 
    ON t.currency_pair = r.currency_pair
   AND t.trade_timestamp >= r.valid_from 
   AND t.trade_timestamp < r.valid_to
ORDER BY t.trade_timestamp ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[trade_id] = TRD-101
