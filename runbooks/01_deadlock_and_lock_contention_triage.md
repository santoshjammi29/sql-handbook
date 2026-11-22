# 🚨 Production Runbook 01: Deadlock & Lock Contention Emergency Triage

> **Incident Severity**: SEV-1 / SEV-2  
> **Target Systems**: PostgreSQL, Microsoft SQL Server, Azure SQL, MySQL / Aurora, Oracle  
> **Recovery Objective**: Restore application throughput, terminate blocking root nodes, eliminate transaction queueing within 5 minutes.

---

## 1. Emergency Decision Tree

```
                       [Application Alert: HTTP 504 / DB Connection Pool Exhaustion]
                                                      │
                                    Check Active Sessions & Lock Chains
                                                      │
                       ┌──────────────────────────────┴──────────────────────────────┐
                       ▼                                                             ▼
         [Cyclic Dependency (Deadlock)]                             [Linear Chain (Lock Wait)]
                       │                                                             │
           Engine Auto-Terminates Victim                               Find Root Blocker Head Session
                 (Error 1205 / 40P01)                                                │
                       │                                                Is Blocker an Idle Transaction?
             Extract Deadlock XML / Graph                                            │
                       │                                          ┌──────────────────┴──────────────────┐
             Identify Resource Ordering Conflict                  ▼                                     ▼
                       │                                        [YES]                                 [NO]
        Enforce Strict Canonical Key Ordering           Kill Session Immediately               Long-Running Batch DML
                                                     (pg_terminate_backend / KILL)                      │
                                                                                       Check for Unindexed FK or Escaped Lock
```

---

## 2. PostgreSQL Lock Triage Diagnostic Queries

### 2.1 Identify the Root Blocker and Blocking Tree
Run this query to locate which PID is holding locks and blocking downstream queries:

```sql
SELECT
    blocked_locks.pid     AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid    AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query   AS blocked_statement,
    blocking_activity.query  AS current_statement_in_blocking_process,
    blocked_activity.state   AS blocked_state,
    blocking_activity.state  AS blocking_state,
    NOW() - blocked_activity.query_start AS waiting_duration
FROM  pg_catalog.pg_locks         blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks         blocking_locks
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

### 2.2 Surgical Termination of Root Blocker
```sql
-- Step 1: Attempt graceful cancel of current statement
SELECT pg_cancel_backend(12345);

-- Step 2: If unresponsive after 10 seconds, forcefully terminate connection
SELECT pg_terminate_backend(12345);
```

---

## 3. SQL Server & Azure SQL Lock & Deadlock Triage

### 3.1 Identify Lead Blocker in Session Chains
```sql
SELECT
    r.session_id,
    r.blocking_session_id,
    r.status,
    r.wait_type,
    r.wait_time / 1000.0 AS wait_time_seconds,
    r.cpu_time,
    r.total_elapsed_time / 1000.0 AS elapsed_seconds,
    t.text AS sql_text,
    p.query_plan
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) p
WHERE r.blocking_session_id <> 0 OR r.session_id IN (
    SELECT blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0
)
ORDER BY r.blocking_session_id ASC;
```

### 3.2 Extract Deadlock XML Graph from Extended Events
```sql
SELECT
    XEvent.value('(event/data[@name="xml_report"]/value)[1]', 'VARCHAR(MAX)') AS DeadlockGraphXML
FROM (
    SELECT CAST(target_data AS XML) AS TargetData
    FROM sys.dm_xe_session_targets st
    JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
    WHERE s.name = 'system_health' AND st.target_name = 'ring_buffer'
) AS Data
CROSS APPLY TargetData.nodes('//RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData(XEvent);
```

---

## 4. Root Causes & Permanent Architectural Mitigations

### 1. Inconsistent Resource Ordering
- **Problem**: Thread 1 updates Table A then Table B. Thread 2 updates Table B then Table A.
- **Remediation**: Always sort resource IDs numerically before acquiring update locks in application code or stored procedures.

### 2. Unindexed Foreign Keys Causing Table-Lock Cascades
- **Problem**: Executing `DELETE FROM parent WHERE id = 1` or `UPDATE parent` requires checking child tables. If the child foreign key column lacks an index, PostgreSQL and SQL Server are forced to scan or share-lock the entire child table, blocking all concurrent child inserts.
- **Remediation**: Index every foreign key column in your schema.

```sql
-- Audit missing indexes on Foreign Keys in PostgreSQL
SELECT
    conrelid::regclass AS table_name,
    conname AS foreign_key_name,
    pg_get_constraintdef(c.oid) AS constraint_definition
FROM pg_constraint c
WHERE c.contype = 'f'
  AND NOT EXISTS (
      SELECT 1 FROM pg_index i
      WHERE i.indrelid = c.conrelid
        AND ARRAY[c.conkey[1]] <@ (i.indkey::int[])
  );
```

### 3. Overly Permissive Session Timeouts
- **Problem**: Client connection network drops while keeping an open transaction (`idle in transaction`), locking table rows for hours.
- **Remediation**: Configure aggressive statement and idle timeouts:

```sql
-- PostgreSQL global configuration
ALTER SYSTEM SET idle_in_transaction_session_timeout = '30s';
ALTER SYSTEM SET statement_timeout = '60s';
ALTER SYSTEM SET lock_timeout = '10s';
SELECT pg_reload_conf();

-- SQL Server connection setting
SET LOCK_TIMEOUT 10000; -- Aborts query if lock wait exceeds 10,000ms
```
