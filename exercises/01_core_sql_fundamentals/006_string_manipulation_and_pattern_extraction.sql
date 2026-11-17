-- ============================================================================
-- EXERCISE: 006_string_manipulation_and_pattern_extraction.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Security Operations Center (SOC) Data Engineer & Privacy Architect
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Security Information & Event Management (SIEM) Ingress Pipeline.
--   Raw web application gateway access logs stream into an analytical lakehouse.
--   SOC analysts require parsing semi-structured HTTP log strings, isolating
--   URI endpoints, client IP subnets, and masking PII (email addresses & tokens)
--   in compliance with PCI-DSS & HIPAA regulations.
--
-- BUSINESS CONTEXT:
--   Raw logs arrive in standard Combined Log Format or custom proxy strings:
--   '192.168.1.105 - alice@acme.com [2024-05-01] "POST /api/v2/checkout/process HTTP/1.1" 200 4520'
--   1. Extract client IP and mask to /24 subnet for pseudonymization ('192.168.1.0/24').
--   2. Extract HTTP Method ('POST') and clean resource endpoint ('/api/v2/checkout/process').
--   3. Mask email user local part: 'alice@acme.com' -> 'a***e@acme.com'.
--
-- PROBLEM STATEMENT:
--   Parse the raw log payload using standard ANSI SQL string manipulation functions:
--   INSTR, SUBSTR, LENGTH, REPLACE, and TRIM. Generate an enterprise SIEM audit manifest.
-- ============================================================================

DROP TABLE IF EXISTS raw_siem_ingress_logs;

CREATE TABLE raw_siem_ingress_logs (
    log_id VARCHAR(32) PRIMARY KEY,
    raw_payload TEXT NOT NULL,
    ingestion_timestamp TEXT NOT NULL
);

INSERT INTO raw_siem_ingress_logs VALUES
('LOG-001', '192.168.1.105 - user.one@domain.com [2024-05-01 10:15:30] "POST /api/v2/checkout/payment HTTP/1.1" 200 4520', '2024-05-01 10:15:31'),
('LOG-002', '10.0.4.52 - admin_corp@enterprise.org [2024-05-01 10:16:02] "GET /api/v2/admin/users HTTP/1.1" 200 12080', '2024-05-01 10:16:03'),
('LOG-003', '172.16.20.8 - hacker_probe@badactor.net [2024-05-01 10:16:45] "GET /wp-login.php HTTP/1.1" 404 310', '2024-05-01 10:16:46'),
('LOG-004', '192.168.1.200 - support_agent@domain.com [2024-05-01 10:17:10] "PUT /api/v2/tickets/492 HTTP/1.1" 200 890', '2024-05-01 10:17:11'),
('LOG-005', '10.0.4.88 - guest_checkout@domain.com [2024-05-01 10:17:55] "POST /api/v2/checkout/payment HTTP/1.1" 500 142', '2024-05-01 10:17:56'),
('LOG-006', '10.0.4.99 - secops_lead@enterprise.org [2024-05-01 10:18:20] "DELETE /api/v2/sessions/kill HTTP/1.1" 204 0', '2024-05-01 10:18:21');

-- --- [SOLUTION QUERY] ---
WITH tokenized_logs AS (
    SELECT 
        log_id,
        raw_payload,
        -- Extract Client IP: substring from start to first space
        SUBSTR(raw_payload, 1, INSTR(raw_payload, ' ') - 1) AS client_ip,
        -- Extract Email: substring between '- ' and ' ['
        SUBSTR(
            raw_payload,
            INSTR(raw_payload, '- ') + 2,
            INSTR(raw_payload, ' [') - (INSTR(raw_payload, '- ') + 2)
        ) AS raw_email,
        -- Extract Request Line: substring between first quote '"' and second quote '"'
        SUBSTR(
            raw_payload,
            INSTR(raw_payload, '"') + 1,
            INSTR(SUBSTR(raw_payload, INSTR(raw_payload, '"') + 1), '"') - 1
        ) AS request_line,
        -- Extract Status Code: last 7 characters before response size (e.g. ' 200 4520')
        CAST(SUBSTR(raw_payload, INSTR(raw_payload, '" ') + 2, 3) AS INT) AS http_status
    FROM raw_siem_ingress_logs
),
parsed_fields AS (
    SELECT 
        log_id,
        client_ip,
        raw_email,
        -- HTTP Method: token before first space in request_line
        SUBSTR(request_line, 1, INSTR(request_line, ' ') - 1) AS http_method,
        -- URI Path: token between first space and last space in request_line
        SUBSTR(
            request_line,
            INSTR(request_line, ' ') + 1,
            INSTR(SUBSTR(request_line, INSTR(request_line, ' ') + 1), ' ') - 1
        ) AS uri_path,
        http_status
    FROM tokenized_logs
),
masked_compliance_layer AS (
    SELECT 
        log_id,
        -- Pseudonymize IP to /24 Class C subnet: keep first 3 octets, mask 4th octet
        SUBSTR(client_ip, 1, INSTR(client_ip, '.') - 1) || '.0.0.0/8' AS anonymized_subnet,
        -- Email domain extraction
        SUBSTR(raw_email, INSTR(raw_email, '@') + 1) AS email_domain,
        -- PII Masking: first char + '***' + '@domain'
        SUBSTR(raw_email, 1, 1) || '***@' || SUBSTR(raw_email, INSTR(raw_email, '@') + 1) AS masked_email,
        http_method,
        uri_path,
        http_status
    FROM parsed_fields
)
SELECT 
    log_id,
    anonymized_subnet,
    masked_email,
    http_method,
    uri_path,
    http_status,
    CASE 
        WHEN http_status >= 500 THEN 'SEV1_SERVER_ERROR'
        WHEN http_status = 404 THEN 'WARN_NOT_FOUND'
        WHEN http_method IN ('POST', 'DELETE') THEN 'AUDIT_STATE_MUTATION'
        ELSE 'INFO_READ_TRAFFIC'
    END AS telemetry_classification
FROM masked_compliance_layer
ORDER BY log_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 6
-- ASSERT: COL[log_id] = LOG-001
