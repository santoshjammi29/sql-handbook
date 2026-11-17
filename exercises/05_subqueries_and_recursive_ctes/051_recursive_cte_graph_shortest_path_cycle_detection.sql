-- ============================================================================
-- EXERCISE: 051_recursive_cte_graph_shortest_path_cycle_detection.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ----------------------------------------------------------------------------
-- BUSINESS CONTEXT:
--   Flight route network optimizer: Find all possible flight itineraries between
--   London (LHR) and Tokyo (HND) with maximum 2 layovers, preventing infinite
--   loops in cyclic graph networks.
-- PROBLEM STATEMENT:
--   Traverse cyclic flight connections using a Recursive CTE with cycle-detection guards.
-- ============================================================================

DROP TABLE IF EXISTS flight_routes;
CREATE TABLE flight_routes (
    origin VARCHAR(10),
    destination VARCHAR(10),
    cost DECIMAL(10, 2)
);

INSERT INTO flight_routes VALUES
('LHR', 'DXB', 400.00),
('DXB', 'HND', 500.00),
('LHR', 'SIN', 600.00),
('SIN', 'HND', 350.00),
('DXB', 'LHR', 400.00); -- Cycle!

-- --- [SOLUTION QUERY] ---
WITH RECURSIVE flight_paths AS (
    SELECT 
        origin,
        destination,
        cost AS total_cost,
        1 AS stops,
        CAST(origin || '->' || destination AS VARCHAR(255)) AS path_str
    FROM flight_routes
    WHERE origin = 'LHR'

    UNION ALL

    SELECT 
        r.origin,
        r.destination,
        p.total_cost + r.cost,
        p.stops + 1,
        CAST(p.path_str || '->' || r.destination AS VARCHAR(255))
    FROM flight_routes r
    JOIN flight_paths p ON r.origin = p.destination
    -- Cycle prevention: do not revisit airport already in path; max 3 flights
    WHERE INSTR(p.path_str, r.destination) = 0
      AND p.stops < 3
)
SELECT 
    path_str,
    stops,
    total_cost
FROM flight_paths
WHERE destination = 'HND'
ORDER BY total_cost ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[total_cost] = 900.00
