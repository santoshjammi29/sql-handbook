-- ============================================================================
-- EXERCISE: 050_recursive_cte_bill_of_materials_explosion.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Supply Chain Data Architect & Manufacturing Systems Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Automotive & High-Tech Manufacturing Bill of Materials (BOM) Parts Explosion.
--   A finished product (Electric Vehicle) is composed of sub-assemblies (Battery Pack, Chassis),
--   which are in turn composed of sub-components and raw parts.
--   Calculating the total rolled-up unit quantity of every base raw component.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 050 recursive cte bill of materials explosion.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 050 recursive cte bill of materials explosion.
-- ============================================================================

DROP TABLE IF EXISTS manufacturing_bom;

CREATE TABLE manufacturing_bom (
    parent_assembly VARCHAR(50) NOT NULL,
    child_part VARCHAR(50) NOT NULL,
    quantity_required INT NOT NULL
);

INSERT INTO manufacturing_bom VALUES
-- Level 1: Electric Vehicle (Finished Good)
('ELECTRIC_VEHICLE', 'BATTERY_PACK', 1),
('ELECTRIC_VEHICLE', 'DRIVE_MOTOR',  2),
-- Level 2: Sub-assemblies
('BATTERY_PACK',     'LITHIUM_CELL', 100),
('BATTERY_PACK',     'BMS_MODULE',   1),
('DRIVE_MOTOR',      'COPPER_ROTOR', 1),
('DRIVE_MOTOR',      'STEEL_HOUSING',1);

-- --- [SOLUTION QUERY] ---
-- Recursive BOM explosion multiplying quantities down the manufacturing tree
WITH RECURSIVE bom_explosion AS (
    -- Anchor member: Direct components of the finished electric vehicle
    SELECT 
        parent_assembly,
        child_part,
        quantity_required AS cumulative_quantity,
        1 AS assembly_depth
    FROM manufacturing_bom
    WHERE parent_assembly = 'ELECTRIC_VEHICLE'
    
    UNION ALL
    
    -- Recursive member: Multiply parent quantity by child component requirement
    SELECT 
        child.parent_assembly,
        child.child_part,
        parent.cumulative_quantity * child.quantity_required AS cumulative_quantity,
        parent.assembly_depth + 1 AS assembly_depth
    FROM manufacturing_bom child
    INNER JOIN bom_explosion parent ON child.parent_assembly = parent.child_part
)
SELECT 
    child_part,
    cumulative_quantity,
    assembly_depth
FROM bom_explosion
ORDER BY assembly_depth ASC, child_part ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[child_part] = BATTERY_PACK
