-- ============================================================================
-- EXERCISE: 032_quantile_distribution_ntile_bucketing.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Quantitative Risk Architect & FinTech Data Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Automated Consumer Lending Underwriting & Risk Decile Segmentation.
--   Credit scores and default risk factors must be partitioned into 4 quartiles
--   (or 10 deciles) to calibrate interest rate spreads and loss provisioning reserves.
--
-- BUSINESS CONTEXT:
--   NTILE(N) partitions an ordered result set into N approximately equal buckets.
--   If the total rows are not evenly divisible by N, earlier buckets receive the remainder.
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 032 quantile distribution ntile bucketing.
-- ============================================================================

DROP TABLE IF EXISTS loan_underwriting_scores;

CREATE TABLE loan_underwriting_scores (
    applicant_id VARCHAR(32) PRIMARY KEY,
    risk_score INT NOT NULL, -- 300 to 850
    requested_amount_usd DECIMAL(12, 2) NOT NULL
);

INSERT INTO loan_underwriting_scores VALUES
('APP-01', 820, 50000.00),
('APP-02', 790, 35000.00),
('APP-03', 750, 20000.00),
('APP-04', 720, 40000.00),
('APP-05', 680, 15000.00),
('APP-06', 640, 25000.00),
('APP-07', 590, 10000.00),
('APP-08', 520, 12000.00);

-- --- [SOLUTION QUERY] ---
-- Partition applicants into 4 risk quartiles using NTILE(4)
WITH quartile_assignments AS (
    SELECT 
        applicant_id,
        risk_score,
        requested_amount_usd,
        NTILE(4) OVER (ORDER BY risk_score DESC) AS risk_quartile
    FROM loan_underwriting_scores
)
SELECT 
    risk_quartile,
    COUNT(*) AS total_applicants,
    MIN(risk_score) AS min_score_in_quartile,
    MAX(risk_score) AS max_score_in_quartile,
    SUM(requested_amount_usd) AS total_capital_demand_usd,
    CASE 
        WHEN risk_quartile = 1 THEN 'TIER_1_SUPER_PRIME'
        WHEN risk_quartile = 2 THEN 'TIER_2_PRIME'
        WHEN risk_quartile = 3 THEN 'TIER_3_NEAR_PRIME'
        ELSE 'TIER_4_SUBPRIME_HIGH_RISK'
    END AS underwriting_bracket
FROM quartile_assignments
GROUP BY risk_quartile
ORDER BY risk_quartile ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[risk_quartile] = 1
