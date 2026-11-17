-- ============================================================================
-- EXERCISE: 050_recursive_cte_bill_of_materials_explosion.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Manufacturing supply chain: A Laptop consists of sub-assemblies (Chassis,
--   Motherboard), which themselves contain raw components (Chips, Screws).
--   To compute total cost, the Bill of Materials (BOM) must be fully exploded.
-- PROBLEM STATEMENT:
--   Recursively explode parts hierarchy and calculate the cumulative quantity
--   of every sub-component required to produce 1 top-level finished unit.
-- ============================================================================

DROP TABLE IF EXISTS bill_of_materials;
CREATE TABLE bill_of_materials (
    parent_part VARCHAR(50),
    child_part VARCHAR(50),
    quantity_required INT
);

INSERT INTO bill_of_materials VALUES
('Laptop', 'Motherboard', 1),
('Laptop', 'Chassis',     1),
('Motherboard', 'CPU',     1),
('Motherboard', 'RAM',     2),
('Chassis', 'Screw',       8);

-- --- [SOLUTION QUERY] ---
WITH RECURSIVE bom_explosion AS (
    -- Anchor: Immediate components of Laptop
    SELECT 
        child_part,
        quantity_required,
        1 AS bom_depth
    FROM bill_of_materials
    WHERE parent_part = 'Laptop'

    UNION ALL

    -- Recursive: Expand sub-components multiplying quantities
    SELECT 
        sub.child_part,
        parent.quantity_required * sub.quantity_required,
        parent.bom_depth + 1
    FROM bill_of_materials sub
    JOIN bom_explosion parent ON sub.parent_part = parent.child_part
)
SELECT 
    child_part,
    SUM(quantity_required) AS total_units_needed
FROM bom_explosion
GROUP BY child_part
ORDER BY total_units_needed DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[total_units_needed] = 8
