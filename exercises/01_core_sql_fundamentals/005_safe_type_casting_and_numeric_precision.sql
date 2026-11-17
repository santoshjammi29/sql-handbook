-- ============================================================================
-- EXERCISE: 005_safe_type_casting_and_numeric_precision.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & FinTech Quantitative Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Cross-Border Foreign Exchange & Digital Asset Settlement Clearinghouse.
--   Financial ledgers receiving unstructured, dirty string extracts from external
--   banking APIs (containing currency symbols '$', commas ',', corrupted 'NaN' strings).
--
-- BUSINESS CONTEXT:
--   1. IEEE 754 Floating-Point Inaccuracies: Storing financial amounts as FLOAT or
--      DOUBLE causes cumulative rounding drift (e.g. 0.10 + 0.20 = 0.30000000000000004),
--      failing audit invariant balancing.
--   2. Type Casting Exceptions: Unchecked CAST('$1,200.50' AS DECIMAL) crashes
--      the entire batch in strict ANSI engines.
--   3. Production Standard: Clean raw strings, convert currency values to fixed-point
--      integer cents (Basis Points or Cents), and perform exact balance sheet balancing.
--
-- PROBLEM STATEMENT:
--   Build a data sanitization and high-precision settlement pipeline that cleans
--   raw payload strings, calculates basis point transaction fees, converts to integer
--   cents, and verifies zero-drift balance sheet balancing.
-- ============================================================================

DROP TABLE IF EXISTS raw_settlement_feed;
DROP TABLE IF EXISTS currency_exchange_rates;

CREATE TABLE currency_exchange_rates (
    currency_code VARCHAR(3) PRIMARY KEY,
    fx_rate_to_usd DECIMAL(12, 6) NOT NULL -- Units of USD per 1 unit of foreign currency
);

CREATE TABLE raw_settlement_feed (
    txn_ref_id VARCHAR(32) PRIMARY KEY,
    currency_code VARCHAR(3) NOT NULL,
    raw_amount_str VARCHAR(50) NOT NULL,
    fee_basis_points INT NOT NULL, -- 1 bp = 0.01% = 0.0001
    counterparty_id VARCHAR(32) NOT NULL
);

INSERT INTO currency_exchange_rates VALUES
('USD', 1.000000),
('EUR', 1.085000),
('GBP', 1.272000),
('JPY', 0.006400);

-- Seed raw dirty financial string records
INSERT INTO raw_settlement_feed VALUES
('TXN-8801', 'USD', '$1,250.50', 25, 'CP-ACME'),
('TXN-8802', 'EUR', '2,500.00 EUR', 30, 'CP-GLOBAL'),
('TXN-8803', 'GBP', 'GBP 15,400.75', 15, 'CP-BARCLAYS'),
('TXN-8804', 'USD', '850.25', 20, 'CP-STRIPE'),
('TXN-8805', 'JPY', '500,000', 50, 'CP-TOKYO'),
('TXN-8806', 'USD', 'CORRUPT_PAYLOAD', 25, 'CP-ERROR'), -- Corrupt record to be quarantined
('TXN-8807', 'EUR', '12,800.00', 35, 'CP-BERLIN');

-- --- [SOLUTION QUERY] ---
WITH cleaned_feed AS (
    -- Step 1: Strip non-numeric currency artifacts ('$', 'EUR', 'GBP', ',', whitespace)
    SELECT 
        txn_ref_id,
        currency_code,
        counterparty_id,
        fee_basis_points,
        raw_amount_str,
        -- Clean string: remove commas, currency symbols, and text
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(raw_amount_str, '$', ''), 
                    ',', ''), 
                'EUR', ''), 
            'GBP', ''), 
        ' ', '') AS sanitized_amount_str
    FROM raw_settlement_feed
),
validated_feed AS (
    -- Step 2: Validate numeric conformity; filter out corrupted payload strings
    SELECT 
        txn_ref_id,
        currency_code,
        counterparty_id,
        fee_basis_points,
        -- Check if string represents a valid decimal number
        CASE 
            WHEN sanitized_amount_str GLOB '*[0-9]*' AND NOT sanitized_amount_str GLOB '*[^0-9.]*' 
                THEN CAST(sanitized_amount_str AS DECIMAL(14, 2))
            ELSE NULL 
        END AS clean_amount_local
    FROM cleaned_feed
),
settlement_calculations AS (
    -- Step 3: Perform exact currency conversion and fee deduction in integer cents (preventing float drift)
    SELECT 
        v.txn_ref_id,
        v.counterparty_id,
        v.currency_code,
        v.clean_amount_local,
        r.fx_rate_to_usd,
        -- Calculate gross amount in USD cents
        ROUND(v.clean_amount_local * r.fx_rate_to_usd * 100, 0) AS gross_amount_usd_cents,
        -- Fee calculation: basis points (1 bp = 0.0001)
        ROUND((v.clean_amount_local * r.fx_rate_to_usd * 100) * (v.fee_basis_points / 10000.0), 0) AS fee_usd_cents
    FROM validated_feed v
    INNER JOIN currency_exchange_rates r ON v.currency_code = r.currency_code
    WHERE v.clean_amount_local IS NOT NULL -- Exclude quarantined corrupt payloads
)
-- Step 4: Final project presenting net settlement in USD with high-precision reconciliation
SELECT 
    txn_ref_id,
    counterparty_id,
    currency_code,
    clean_amount_local,
    fx_rate_to_usd,
    CAST(gross_amount_usd_cents / 100.0 AS DECIMAL(12, 2)) AS gross_usd,
    CAST(fee_usd_cents / 100.0 AS DECIMAL(12, 2)) AS fee_usd,
    CAST((gross_amount_usd_cents - fee_usd_cents) / 100.0 AS DECIMAL(12, 2)) AS net_settlement_usd
FROM settlement_calculations
ORDER BY gross_amount_usd_cents DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[txn_ref_id] = TXN-8803
