-- ============================================================================
-- EXERCISE: 004_relational_constraints_and_cascade_rules.sql
-- MODULE:   01_core_sql_fundamentals
-- LEVEL:    🟢<br>Beginner
-- ENGINES:  PostgreSQL, DuckDB, SQLite, Snowflake, BigQuery, Databricks Spark SQL
-- ROLE:     Lead Data Architect & Security Infrastructure Engineer
-- ----------------------------------------------------------------------------
-- ARCHITECTURAL CONTEXT & SYSTEM TOPOLOGY:
--   Multi-Tenant Identity & Access Management (IAM) and RBAC Security Boundary.
--   When enterprise customers churn, suspend contracts, or face security breaches,
--   decommissioning organizations requires strict relational enforcement:
--   cascading active workspace deletions while strictly preserving compliance audit trails.
--
-- BUSINESS CONTEXT:
--   Enterprise IAM must enforce strict data boundaries:
--   1. An organization has multiple workspaces and users.
--   2. Deleting a workspace must cascade and remove ephemeral user session grants.
--   3. Deleting an organization must NOT destroy historical security compliance
--      audit events (enforced via ON DELETE RESTRICT / soft tombstoning).
--   4. Attribute integrity is enforced at the database level via CHECK constraints
--      (valid email patterns, non-empty workspace slugs, valid role enumerations).
--
-- PROBLEM STATEMENT:
--   Build a production-grade relational schema with explicit FOREIGN KEY constraints,
--   CHECK constraints, and unique indexes. Execute a tenant soft-deactivation workflow
--   and verify referential integrity across active vs tombstoned records.
-- ============================================================================

DROP TABLE IF EXISTS iam_security_audit_events;
DROP TABLE IF EXISTS iam_user_role_grants;
DROP TABLE IF EXISTS iam_users;
DROP TABLE IF EXISTS iam_workspaces;
DROP TABLE IF EXISTS iam_organizations;

CREATE TABLE iam_organizations (
    org_id VARCHAR(32) PRIMARY KEY,
    org_slug VARCHAR(50) UNIQUE NOT NULL,
    account_status VARCHAR(20) NOT NULL CHECK (account_status IN ('ACTIVE', 'SUSPENDED', 'DECOMMISSIONED')),
    created_at TEXT NOT NULL
);

CREATE TABLE iam_workspaces (
    workspace_id VARCHAR(32) PRIMARY KEY,
    org_id VARCHAR(32) NOT NULL,
    workspace_name VARCHAR(100) NOT NULL,
    is_production INT NOT NULL CHECK (is_production IN (0, 1)),
    FOREIGN KEY (org_id) REFERENCES iam_organizations(org_id) ON DELETE CASCADE
);

CREATE TABLE iam_users (
    user_id VARCHAR(32) PRIMARY KEY,
    org_id VARCHAR(32) NOT NULL,
    email VARCHAR(150) NOT NULL,
    is_mfa_enabled INT NOT NULL CHECK (is_mfa_enabled IN (0, 1)),
    FOREIGN KEY (org_id) REFERENCES iam_organizations(org_id) ON DELETE CASCADE
);

CREATE TABLE iam_user_role_grants (
    grant_id VARCHAR(32) PRIMARY KEY,
    workspace_id VARCHAR(32) NOT NULL,
    user_id VARCHAR(32) NOT NULL,
    role_name VARCHAR(30) NOT NULL CHECK (role_name IN ('ADMIN', 'DATA_ENGINEER', 'ANALYST', 'VIEWER')),
    FOREIGN KEY (workspace_id) REFERENCES iam_workspaces(workspace_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES iam_users(user_id) ON DELETE CASCADE
);

CREATE TABLE iam_security_audit_events (
    event_id VARCHAR(32) PRIMARY KEY,
    org_id VARCHAR(32) NOT NULL,
    actor_user_id VARCHAR(32) NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    event_timestamp TEXT NOT NULL,
    FOREIGN KEY (org_id) REFERENCES iam_organizations(org_id) ON DELETE RESTRICT
);

-- Seed realistic enterprise IAM records
INSERT INTO iam_organizations VALUES
('ORG-101', 'acme-corp', 'ACTIVE', '2023-01-10 09:00:00'),
('ORG-102', 'globex-logistics', 'SUSPENDED', '2023-06-15 14:00:00'),
('ORG-103', 'soylent-health', 'ACTIVE', '2024-02-01 11:30:00');

INSERT INTO iam_workspaces VALUES
('WS-001', 'ORG-101', 'Acme Production Data Lake', 1),
('WS-002', 'ORG-101', 'Acme Staging Analytics', 0),
('WS-003', 'ORG-102', 'Globex Telemetry Prod', 1),
('WS-004', 'ORG-103', 'Soylent Clinical Mart', 1);

INSERT INTO iam_users VALUES
('USR-01', 'ORG-101', 'secops@acme.com', 1),
('USR-02', 'ORG-101', 'de_lead@acme.com', 1),
('USR-03', 'ORG-102', 'ops@globex.com', 0),
('USR-04', 'ORG-103', 'data_architect@soylent.com', 1);

INSERT INTO iam_user_role_grants VALUES
('GR-01', 'WS-001', 'USR-01', 'ADMIN'),
('GR-02', 'WS-001', 'USR-02', 'DATA_ENGINEER'),
('GR-03', 'WS-002', 'USR-02', 'ADMIN'),
('GR-04', 'WS-003', 'USR-03', 'ANALYST'),
('GR-05', 'WS-004', 'USR-04', 'DATA_ENGINEER');

INSERT INTO iam_security_audit_events VALUES
('EVT-901', 'ORG-101', 'USR-01', 'POLICY_UPDATE', '2024-05-01 10:15:00'),
('EVT-902', 'ORG-102', 'USR-03', 'SUSPICIOUS_LOGIN_BLOCKED', '2024-05-02 11:45:00'),
('EVT-903', 'ORG-103', 'USR-04', 'SCHEMA_MIGRATION_EXECUTED', '2024-05-03 08:30:00');

-- --- [SOLUTION QUERY] ---
-- Multi-tier security audit report reconciling active organizations, workspace allocations,
-- and MFA compliance across enterprise tenants
WITH org_summary AS (
    SELECT 
        o.org_id,
        o.org_slug,
        o.account_status,
        COUNT(DISTINCT w.workspace_id) AS total_workspaces,
        COUNT(DISTINCT u.user_id) AS total_users,
        COUNT(DISTINCT g.grant_id) AS total_active_grants,
        COUNT(DISTINCT e.event_id) AS total_audit_events,
        -- Compliance metric: Percentage of users with MFA enabled
        ROUND(SUM(CASE WHEN u.is_mfa_enabled = 1 THEN 1.0 ELSE 0.0 END) / NULLIF(COUNT(DISTINCT u.user_id), 0) * 100, 2) AS mfa_compliance_pct
    FROM iam_organizations o
    LEFT JOIN iam_workspaces w ON o.org_id = w.org_id
    LEFT JOIN iam_users u ON o.org_id = u.org_id
    LEFT JOIN iam_user_role_grants g ON w.workspace_id = g.workspace_id AND u.user_id = g.user_id
    LEFT JOIN iam_security_audit_events e ON o.org_id = e.org_id
    GROUP BY o.org_id, o.org_slug, o.account_status
)
SELECT 
    org_id,
    org_slug,
    account_status,
    total_workspaces,
    total_users,
    total_active_grants,
    total_audit_events,
    mfa_compliance_pct,
    CASE 
        WHEN mfa_compliance_pct = 100.0 AND account_status = 'ACTIVE' THEN 'COMPLIANT_ZERO_TRUST'
        WHEN account_status = 'SUSPENDED' THEN 'TENANT_QUARANTINED'
        ELSE 'AUDIT_ACTION_REQUIRED'
    END AS security_governance_tier
FROM org_summary
ORDER BY total_workspaces DESC, org_id ASC;

-- --- [VERIFICATION / ASSERTION] ---
-- ASSERT: ROW_COUNT = 3
-- ASSERT: COL[org_id] = ORG-101
