-- ============================================================================
-- EXERCISE: 030_statistical_aggregations_median_and_percentiles.sql
-- MODULE:   03_aggregations_and_grouping
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Site Reliability Engineer & Performance Systems Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Microservice API Gateway SLA & Latency Percentile Benchmarking.
--   High-frequency API request duration logs measuring p50 (Median), p90, and p99.
--
-- BUSINESS CONTEXT:
--   Averages (MEAN) are dangerously misleading in latency monitoring because a small
--   number of 10-second timeouts skew the metric, hiding the true user experience.
--   Site Reliability Engineers rely on Percentiles (p50 Median, p90, p99):
--   - p50: 50% of users experience response times at or below this value.
--   - p90: 90% of requests meet this threshold.
--   - p99: 99% of requests meet this SLA guarantee.
--
-- PROBLEM STATEMENT:
--   Calculate median (p50) and 90th percentile latency per microservice endpoint
--   using continuous ranking percentile calculations.
-- ============================================================================

DROP TABLE IF EXISTS api_request_telemetry;

CREATE TABLE api_request_telemetry (
    request_id VARCHAR(32) PRIMARY KEY,
    endpoint_name VARCHAR(50) NOT NULL,
    latency_ms INT NOT NULL
);

INSERT INTO api_request_telemetry VALUES
-- Checkout Service: Generally fast, but tail latency exists
('R-01', '/api/v1/checkout', 45),
('R-02', '/api/v1/checkout', 50),
('R-03', '/api/v1/checkout', 52),
('R-04', '/api/v1/checkout', 55),
('R-05', '/api/v1/checkout', 58),
('R-06', '/api/v1/checkout', 62),
('R-07', '/api/v1/checkout', 70),
('R-08', '/api/v1/checkout', 85),
('R-09', '/api/v1/checkout', 240),
('R-10', '/api/v1/checkout', 1250); -- Tail latency spike!

-- --- [SOLUTION QUERY] ---
-- Exact continuous percentile calculation using NTILE bucketing and window ranking
WITH ranked_requests AS (
    SELECT 
        endpoint_name,
        latency_ms,
        ROW_NUMBER() OVER (PARTITION BY endpoint_name ORDER BY latency_ms ASC) AS rank_idx,
        COUNT(*) OVER (PARTITION BY endpoint_name) AS total_requests
    FROM api_request_telemetry
)
SELECT 
    endpoint_name,
    total_requests,
    MIN(latency_ms) AS min_latency_ms,
    MAX(CASE WHEN rank_idx = (total_requests + 1) / 2 THEN latency_ms END) AS p50_median_latency_ms,
    MAX(CASE WHEN rank_idx = CAST(total_requests * 0.90 AS INT) THEN latency_ms END) AS p90_latency_ms,
    MAX(latency_ms) AS max_latency_ms
FROM ranked_requests
GROUP BY endpoint_name, total_requests;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 1
-- ASSERT: COL[endpoint_name] = /api/v1/checkout
