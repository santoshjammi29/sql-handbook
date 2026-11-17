-- ============================================================================
-- EXERCISE: 008_conditional_case_logic_and_nullif_coalesce.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Analytics Engineer & E-Commerce Data Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Direct-to-Consumer (D2C) E-Commerce Promotional Waterfall & Return Analytics.
--   Analytical mart calculating net order margins across promotional coupon codes,
--   tiered VIP loyalty discounts, and return processing fees.
--
-- BUSINESS CONTEXT:
--   1. Order Waterfall Precedence: VIP loyalty discounts apply first to gross order amount.
--      Coupons apply second to the residual amount.
--   2. Return Rate Calculation: Calculating return unit ratios (returned_units / total_units)
--      must be guarded against catastrophic 'DIVISION BY ZERO' when an order contains
--      zero physical goods (e.g. digital gift card orders).
--   3. Restocking Fee Handling: Returns on electronics incur a 15% restocking fee,
--      apparel incurs 0%, and other categories incur a flat 5.00 USD fee.
--
-- PROBLEM STATEMENT:
--   Construct a multi-branch CASE expression pipeline that safely evaluates
--   promotional discounts, guards against division by zero via NULLIF, and computes
--   net settled revenue.
-- ============================================================================

DROP TABLE IF EXISTS d2c_order_settlements;

CREATE TABLE d2c_order_settlements (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_tier VARCHAR(20) NOT NULL, -- VIP_PLATINUM, VIP_GOLD, STANDARD
    product_category VARCHAR(30) NOT NULL,
    gross_merchandise_value DECIMAL(10, 2) NOT NULL,
    ordered_units INT NOT NULL,
    returned_units INT NOT NULL,
    coupon_code VARCHAR(20)              -- Nullable
);

INSERT INTO d2c_order_settlements VALUES
('ORD-501', 'VIP_PLATINUM', 'ELECTRONICS', 1200.00, 2, 1, 'SPRING10'),
('ORD-502', 'VIP_GOLD',     'APPAREL',      350.00, 4, 2, NULL),
('ORD-503', 'STANDARD',     'HOME_GOODS',   180.00, 1, 0, 'FLAT20'),
('ORD-504', 'VIP_PLATINUM', 'DIGITAL_GIFT', 100.00, 0, 0, NULL),     -- Zero units edge case!
('ORD-505', 'STANDARD',     'ELECTRONICS',  850.00, 1, 0, NULL),
('ORD-506', 'VIP_GOLD',     'APPAREL',      500.00, 5, 5, 'VIPCLEAR'); -- 100% return

-- --- [SOLUTION QUERY] ---
WITH tiered_discounts AS (
    SELECT 
        order_id,
        customer_tier,
        product_category,
        gross_merchandise_value,
        ordered_units,
        returned_units,
        -- Tier 1 Loyalty Discount rate
        CASE 
            WHEN customer_tier = 'VIP_PLATINUM' THEN 0.20
            WHEN customer_tier = 'VIP_GOLD' THEN 0.10
            ELSE 0.00
        END AS loyalty_discount_rate,
        -- Coupon fixed discount
        CASE 
            WHEN coupon_code = 'SPRING10' THEN 0.10
            WHEN coupon_code = 'FLAT20' THEN 0.00 -- handled as flat deduction
            WHEN coupon_code = 'VIPCLEAR' THEN 0.15
            ELSE 0.00
        END AS coupon_pct_rate,
        CASE WHEN coupon_code = 'FLAT20' THEN 20.00 ELSE 0.00 END AS coupon_flat_usd
    FROM d2c_order_settlements
),
financial_waterfall AS (
    SELECT 
        order_id,
        customer_tier,
        product_category,
        gross_merchandise_value,
        ordered_units,
        returned_units,
        -- Safe return rate calculation guarding against DIVISION BY ZERO via NULLIF
        ROUND(CAST(returned_units AS DECIMAL) / NULLIF(ordered_units, 0), 4) AS return_ratio,
        -- Net value after loyalty discount and coupon
        ROUND(
            (gross_merchandise_value * (1.0 - loyalty_discount_rate) * (1.0 - coupon_pct_rate)) - coupon_flat_usd, 
            2
        ) AS discounted_order_value,
        -- Return restocking fee calculation
        CASE 
            WHEN returned_units = 0 THEN 0.00
            WHEN product_category = 'ELECTRONICS' THEN ROUND(gross_merchandise_value * 0.15, 2)
            WHEN product_category = 'APPAREL' THEN 0.00
            ELSE 5.00
        END AS restocking_fee_usd
    FROM tiered_discounts
)
SELECT 
    order_id,
    customer_tier,
    product_category,
    gross_merchandise_value,
    COALESCE(return_ratio, 0.0000) AS clean_return_ratio,
    discounted_order_value,
    restocking_fee_usd,
    ROUND(discounted_order_value + restocking_fee_usd, 2) AS final_net_settled_revenue
FROM financial_waterfall
ORDER BY final_net_settled_revenue DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[order_id] = ORD-501
