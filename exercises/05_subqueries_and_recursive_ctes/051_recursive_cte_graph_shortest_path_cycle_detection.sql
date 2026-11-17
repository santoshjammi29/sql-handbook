-- ============================================================================
-- EXERCISE: 051_recursive_cte_graph_shortest_path_cycle_detection.sql
-- MODULE:   05_subqueries_and_recursive_ctes
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Network Graph Architect & Transportation Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Airline Route Network & Shortest Connection Path Finder with Cycle Detection.
--   Finding all flight connection paths from Origin (JFK) to Destination (LHR),
--   calculating cumulative cost and preventing infinite recursion cycles.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 051 recursive cte graph shortest path cycle detection.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 051 recursive cte graph shortest path cycle detection.
-- ============================================================================

DROP TABLE IF EXISTS flight_routes;

CREATE TABLE flight_routes (
    origin VARCHAR(3) NOT NULL,
    destination VARCHAR(3) NOT NULL,
    cost_usd DECIMAL(10, 2) NOT NULL
);

INSERT INTO flight_routes VALUES
('JFK', 'BOS', 120.00),
('BOS', 'LHR', 450.00),
('JFK', 'ORD', 180.00),
('ORD', 'LHR', 550.00),
('JFK', 'LHR', 850.00), -- Direct flight
('BOS', 'JFK', 120.00); -- Cycle back!

-- --- [SOLUTION QUERY] ---
-- Recursive path traversal with cycle prevention via path string inspection
WITH RECURSIVE flight_paths AS (
    -- Anchor: Direct departures from JFK
    SELECT 
        origin,
        destination,
        cost_usd AS total_cost_usd,
        1 AS flight_hops,
        origin || '->' || destination AS flight_itinerary
    FROM flight_routes
    WHERE origin = 'JFK'
    
    UNION ALL
    
    -- Recursive: Extend path while ensuring next destination is NOT already in itinerary (Cycle Prevention)
    SELECT 
        parent.origin,
        nxt.destination,
        ROUND(parent.total_cost_usd + nxt.cost_usd, 2) AS total_cost_usd,
        parent.flight_hops + 1 AS flight_hops,
        parent.flight_itinerary || '->' || nxt.destination AS flight_itinerary
    FROM flight_routes nxt
    INNER JOIN flight_paths parent ON nxt.origin = parent.destination
    WHERE parent.flight_itinerary NOT LIKE '%' || nxt.destination || '%'
      AND parent.flight_hops < 4 -- Guardrail max hops
)
SELECT 
    origin,
    destination,
    flight_hops,
    total_cost_usd,
    flight_itinerary
FROM flight_paths
WHERE destination = 'LHR'
ORDER BY total_cost_usd ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[total_cost_usd] = 570.00
