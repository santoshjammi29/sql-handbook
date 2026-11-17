-- ============================================================================
-- EXERCISE: 063_bridge_tables_for_many_to_many_relationships.sql
-- MODULE:   06_data_modeling_and_scd
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Healthcare Data Architect & Clinical Informatics Specialist
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Healthcare & Clinical Outcomes Many-to-Many Bridge Table Architecture.
--   In clinical encounters, a single patient visit may result in multiple diagnoses
--   (e.g., Diabetes, Hypertension, Sepsis). A bridge table with weighting allocation
--   factors prevents metric double-counting when aggregating costs across diagnoses.
--
-- BUSINESS CONTEXT:
--   Enterprise analytical engine optimization for 063 bridge tables for many to many relationships.
--   Ensuring strict grain integrity, distributed performance, and deterministic results.
--
-- PROBLEM STATEMENT:
--   Write a production-grade SQL query fulfilling the architectural requirements for 063 bridge tables for many to many relationships.
-- ============================================================================

DROP TABLE IF EXISTS bridge_encounter_diagnosis;
DROP TABLE IF EXISTS dim_diagnosis;
DROP TABLE IF EXISTS fact_patient_encounters;

CREATE TABLE fact_patient_encounters (
    encounter_id VARCHAR(32) PRIMARY KEY,
    patient_id VARCHAR(32) NOT NULL,
    total_cost_usd DECIMAL(12, 2) NOT NULL
);

CREATE TABLE dim_diagnosis (
    diagnosis_key INT PRIMARY KEY,
    icd10_code VARCHAR(10) NOT NULL,
    description VARCHAR(100) NOT NULL
);

CREATE TABLE bridge_encounter_diagnosis (
    encounter_id VARCHAR(32) NOT NULL,
    diagnosis_key INT NOT NULL,
    weighting_factor DECIMAL(5, 4) NOT NULL, -- Sum of weights per encounter = 1.0000
    PRIMARY KEY (encounter_id, diagnosis_key),
    FOREIGN KEY (encounter_id) REFERENCES fact_patient_encounters(encounter_id),
    FOREIGN KEY (diagnosis_key) REFERENCES dim_diagnosis(diagnosis_key)
);

INSERT INTO fact_patient_encounters VALUES
('ENC-01', 'P-100', 10000.00),
('ENC-02', 'P-200',  4000.00);

INSERT INTO dim_diagnosis VALUES
(1, 'E11.9', 'Type 2 Diabetes'),
(2, 'I10',   'Essential Hypertension'),
(3, 'J44.9', 'COPD Chronic Obstructive Pulmonary Disease');

-- ENC-01 had Diabetes (60% weight) and Hypertension (40% weight)
INSERT INTO bridge_encounter_diagnosis VALUES
('ENC-01', 1, 0.6000),
('ENC-01', 2, 0.4000),
('ENC-02', 3, 1.0000);

-- --- [SOLUTION QUERY] ---
-- Bridge table traversal calculating weighted healthcare cost attribution without double-counting
SELECT 
    d.icd10_code,
    d.description,
    COUNT(f.encounter_id) AS total_encounters,
    ROUND(SUM(f.total_cost_usd * b.weighting_factor), 2) AS weighted_attributed_cost_usd
FROM fact_patient_encounters f
INNER JOIN bridge_encounter_diagnosis b ON f.encounter_id = b.encounter_id
INNER JOIN dim_diagnosis d ON b.diagnosis_key = d.diagnosis_key
GROUP BY d.icd10_code, d.description
ORDER BY weighted_attributed_cost_usd DESC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[icd10_code] = E11.9
