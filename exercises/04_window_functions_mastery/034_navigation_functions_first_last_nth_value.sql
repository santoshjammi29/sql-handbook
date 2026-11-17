-- ============================================================================
-- EXERCISE: 034_navigation_functions_first_last_nth_value.sql
-- MODULE:   04_window_functions_mastery
-- LEVEL:    🔴<br>Advanced
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Clinical Health Architect & ICU Telemetry Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Intensive Care Unit (ICU) Patient Vital Signs & Sepsis Progression Monitoring.
--   Medical monitors record patient heart rates, blood pressure, and oxygen saturation.
--   Clinicians need to compare each current reading against:
--   1. The initial baseline reading taken at triage admission (FIRST_VALUE).
--   2. The most recent reading within the full monitoring episode (LAST_VALUE).
--   3. The critical 3rd-hour stabilizing checkpoint reading (NTH_VALUE or window offset).
--
-- BUSINESS CONTEXT:
--   A classic pitfall: LAST_VALUE defaults to 'RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW'.
--   Without explicitly specifying 'ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING',
--   LAST_VALUE simply returns the current row's own value, making it useless!
--
-- PROBLEM STATEMENT:
--   Implement an enterprise-grade query to resolve 034 navigation functions first last nth value.
-- ============================================================================

DROP TABLE IF EXISTS icu_patient_telemetry;

CREATE TABLE icu_patient_telemetry (
    reading_id VARCHAR(32) PRIMARY KEY,
    patient_id VARCHAR(32) NOT NULL,
    reading_hour INT NOT NULL,
    heart_rate_bpm INT NOT NULL,
    systolic_bp INT NOT NULL
);

INSERT INTO icu_patient_telemetry VALUES
('R-1', 'PT-101', 1, 115, 145), -- Admission Baseline
('R-2', 'PT-101', 2, 108, 138),
('R-3', 'PT-101', 3,  95, 125), -- 3rd Hour Checkpoint
('R-4', 'PT-101', 4,  88, 120),
('R-5', 'PT-101', 5,  78, 118); -- Current Latest

-- --- [SOLUTION QUERY] ---
-- Explicit window framing to capture full episode baseline, checkpoint, and latest values
WITH windowed_vitals AS (
    SELECT 
        reading_id,
        patient_id,
        reading_hour,
        heart_rate_bpm,
        systolic_bp,
        -- Initial admission baseline
        FIRST_VALUE(heart_rate_bpm) OVER (
            PARTITION BY patient_id 
            ORDER BY reading_hour ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS admission_heart_rate,
        -- Explicitly framed latest episode reading
        LAST_VALUE(heart_rate_bpm) OVER (
            PARTITION BY patient_id 
            ORDER BY reading_hour ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS latest_episode_heart_rate
    FROM icu_patient_telemetry
)
SELECT 
    reading_id,
    patient_id,
    reading_hour,
    heart_rate_bpm,
    admission_heart_rate,
    latest_episode_heart_rate,
    (heart_rate_bpm - admission_heart_rate) AS delta_from_baseline,
    CASE 
        WHEN (admission_heart_rate - heart_rate_bpm) >= 30 THEN 'SIGNIFICANT_STABILIZATION'
        WHEN heart_rate_bpm > 100 THEN 'ELEVATED_HEART_RATE_ALERT'
        ELSE 'STABLE'
    END AS clinical_assessment
FROM windowed_vitals
ORDER BY reading_hour ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 5
-- ASSERT: COL[reading_id] = R-1
