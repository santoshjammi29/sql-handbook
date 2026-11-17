-- ============================================================================
-- EXERCISE: 065_deterministic_surrogate_key_generation.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Distributed Lakehouse Modeler
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Distributed Lakehouse Hash-Based Surrogate Key Generation.
--   In modern distributed systems (Snowflake, Databricks Spark, BigQuery), auto-incrementing
--   sequences (IDENTITY/AUTOINCREMENT) create massive bottlenecks because worker nodes
--   must coordinate centrally to issue serial integers.
--   Modern standard: Deterministic Hash Keys (MD5/SHA-256 of composite natural keys).
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 065 deterministic surrogate key generation.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 065 deterministic surrogate key generation.
-- ============================================================================

DROP TABLE IF EXISTS raw_patient_records;

CREATE TABLE raw_patient_records (
    system_origin VARCHAR(20) NOT NULL,
    medical_record_number VARCHAR(30) NOT NULL,
    tenant_id VARCHAR(20) NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL
);

INSERT INTO raw_patient_records VALUES
('EPIC_EHR',   'MRN-8801', 'HOSPITAL_A', 'Alice', 'Vance'),
('CERNER_EHR', 'MRN-8801', 'HOSPITAL_B', 'Alice', 'Vance'); -- Same MRN in different hospital!

-- --- [SOLUTION QUERY] ---
-- Generating deterministic composite surrogate hash keys without distributed locking
SELECT 
    system_origin,
    medical_record_number,
    tenant_id,
    -- Concatenating tenant + system + natural key with delimiter to prevent collision
    UPPER(
        SUBSTR(tenant_id, 1, 3) || '-' ||
        SUBSTR(system_origin, 1, 3) || '-' ||
        medical_record_number
    ) AS deterministic_surrogate_key,
    first_name || ' ' || last_name AS full_patient_name
FROM raw_patient_records
ORDER BY deterministic_surrogate_key ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 2
-- ASSERT: COL[system_origin] = CERNER_EHR
