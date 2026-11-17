-- ============================================================================
-- EXERCISE: 011_inner_left_right_full_outer_joins.sql
-- MODULE:   02_joins_and_set_operations
-- LEVEL:    🟡<br>Intermediate
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Revenue Operations Lead
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Enterprise CRM & Revenue Attribution Mart (Salesforce & ERP Integration).
--   A reporting pipeline joins sales representatives with CRM opportunity deals.
--   A pervasive production defect occurs when engineers place right-table filters
--   inside the WHERE clause of a LEFT JOIN, accidentally converting it to an INNER JOIN
--   and completely dropping sales reps who have zero closed deals!
--
-- BUSINESS CONTEXT:
--   Sales leadership requires an audited quarterly commission and performance report.
--   1. Every registered sales rep must appear, even if they closed $0 in deals.
--   2. Closed-won deals must be aggregated to compute total commission payouts.
--   3. Putting 'WHERE deals.status = ''WON''' filters out reps with 0 won deals
--      because for those reps, status IS NULL (which fails the equality check).
--   4. The condition must be placed in the ON clause of the LEFT JOIN!
--
-- PROBLEM STATEMENT:
--   Construct a robust revenue attribution query that correctly demonstrates the
--   semantic difference between filtering in the ON clause vs WHERE clause of an outer join,
--   producing an enterprise sales leaderboard with zero data loss.
-- ============================================================================

DROP TABLE IF EXISTS sales_deals;
DROP TABLE IF EXISTS sales_reps;

CREATE TABLE sales_reps (
    rep_id VARCHAR(32) PRIMARY KEY,
    rep_name VARCHAR(100) NOT NULL,
    territory VARCHAR(50) NOT NULL,
    quarterly_quota_usd DECIMAL(12, 2) NOT NULL
);

CREATE TABLE sales_deals (
    deal_id VARCHAR(32) PRIMARY KEY,
    rep_id VARCHAR(32) NOT NULL,
    deal_name VARCHAR(100) NOT NULL,
    deal_amount_usd DECIMAL(12, 2) NOT NULL,
    deal_stage VARCHAR(30) NOT NULL, -- 'CLOSED_WON', 'CLOSED_LOST', 'PIPELINE'
    closed_date TEXT,
    FOREIGN KEY (rep_id) REFERENCES sales_reps(rep_id)
);

INSERT INTO sales_reps VALUES
('REP-101', 'Alexander Hayes', 'NORTH_AMERICA', 250000.00),
('REP-102', 'Beatriz Santos',  'LATAM',         150000.00),
('REP-103', 'Chloe Dubois',    'EMEA',          200000.00),
('REP-104', 'Daisuke Tanaka',   'APAC',          180000.00);

INSERT INTO sales_deals VALUES
('DL-01', 'REP-101', 'Acme Global Expansion',     180000.00, 'CLOSED_WON',  '2024-05-10'),
('DL-02', 'REP-101', 'Wayne Enterprises Renewal',  95000.00, 'CLOSED_WON',  '2024-05-22'),
('DL-03', 'REP-101', 'LexCorp Migration',          50000.00, 'CLOSED_LOST', '2024-04-15'),
('DL-04', 'REP-102', 'Starlight Logistics Pilot',  45000.00, 'CLOSED_LOST', '2024-05-01'),
('DL-05', 'REP-102', 'Globex Telemetry Suite',     30000.00, 'PIPELINE',    NULL),
-- REP-103 (Chloe Dubois): Closed 1 Won Deal
('DL-06', 'REP-103', 'Soylent Health SaaS Mart',  210000.00, 'CLOSED_WON',  '2024-05-18');
-- REP-104 (Daisuke Tanaka): Has 0 deals in the system entirely

-- --- [SOLUTION QUERY] ---
-- Correct pattern: Condition 'deal_stage = CLOSED_WON' placed inside ON clause
-- to preserve all representatives on the left side of the relation!
WITH rep_deal_aggregates AS (
    SELECT 
        r.rep_id,
        r.rep_name,
        r.territory,
        r.quarterly_quota_usd,
        COUNT(d.deal_id) AS total_won_deals_count,
        COALESCE(SUM(d.deal_amount_usd), 0.00) AS total_won_revenue_usd
    FROM sales_reps r
    LEFT JOIN sales_deals d 
        ON r.rep_id = d.rep_id 
        AND d.deal_stage = 'CLOSED_WON' -- Crucial: Evaluated during join pass!
    GROUP BY 
        r.rep_id, 
        r.rep_name, 
        r.territory, 
        r.quarterly_quota_usd
),
quota_attainment_scoring AS (
    SELECT 
        rep_id,
        rep_name,
        territory,
        quarterly_quota_usd,
        total_won_deals_count,
        total_won_revenue_usd,
        ROUND((total_won_revenue_usd / NULLIF(quarterly_quota_usd, 0.00)) * 100.0, 2) AS quota_attainment_pct
    FROM rep_deal_aggregates
)
SELECT 
    rep_id,
    rep_name,
    territory,
    quarterly_quota_usd,
    total_won_deals_count,
    total_won_revenue_usd,
    quota_attainment_pct,
    CASE 
        WHEN quota_attainment_pct >= 100.0 THEN 'QUOTA_ACHIEVED_BONUS'
        WHEN quota_attainment_pct >= 70.0  THEN 'ON_TRACK'
        WHEN total_won_revenue_usd = 0.00 THEN 'ZERO_WON_DEALS_ATTENTION'
        ELSE 'BELOW_QUOTA_COACHING'
    END AS performance_bracket
FROM quota_attainment_scoring
ORDER BY total_won_revenue_usd DESC, rep_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 4
-- ASSERT: COL[rep_id] = REP-101
