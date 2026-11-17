# 🗿 Production Runbook 05: Cross-Engine SQL Rosetta Stone

> **Quick Reference Cheatsheet**  
> Comparing core SQL dialect syntax across the 6 leading enterprise engines: **PostgreSQL**, **DuckDB**, **Databricks Spark SQL**, **Snowflake**, **Google BigQuery**, and **Microsoft SQL Server (T-SQL)**.

---

## 1. Syntax Equivalence Matrix

| Operation | PostgreSQL | DuckDB | Databricks Spark SQL | Snowflake | Google BigQuery | SQL Server (T-SQL) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **String Concat** | `col1 \|\| col2` | `col1 \|\| col2` | `concat(col1, col2)` or `\|\|` | `col1 \|\| col2` or `concat()` | `concat(col1, col2)` or `\|\|` | `col1 + col2` or `CONCAT()` |
| **Safe Coalesce** | `COALESCE(a, b)` | `COALESCE(a, b)` | `COALESCE(a, b)` or `nvl(a, b)` | `NVL(a, b)` or `COALESCE()` | `IFNULL(a, b)` or `COALESCE()` | `ISNULL(a, b)` or `COALESCE()` |
| **Safe Type Cast** | `CAST(x AS INT)` | `TRY_CAST(x AS INT)` | `try_cast(x AS INT)` | `TRY_CAST(x AS INT)` | `SAFE_CAST(x AS INT64)` | `TRY_CAST(x AS INT)` |
| **Date Truncate** | `DATE_TRUNC('month', d)` | `DATE_TRUNC('month', d)` | `date_trunc('month', d)` | `DATE_TRUNC('month', d)` | `DATE_TRUNC(d, MONTH)` | `DATETRUNC(month, d)` |
| **Date Arithmetic**| `d + INTERVAL '7 days'` | `d + INTERVAL 7 DAYS` | `date_add(d, 7)` | `DATEADD(day, 7, d)` | `DATE_ADD(d, INTERVAL 7 DAY)` | `DATEADD(day, 7, d)` |
| **Date Difference**| `d2 - d1` (returns days) | `DATE_DIFF('day', d1, d2)` | `datediff(d2, d1)` | `DATEDIFF(day, d1, d2)` | `DATE_DIFF(d2, d1, DAY)` | `DATEDIFF(day, d1, d2)` |
| **Current UTC Time**| `CURRENT_TIMESTAMP` | `CURRENT_TIMESTAMP` | `current_timestamp()` | `CURRENT_TIMESTAMP()` | `CURRENT_TIMESTAMP()` | `SYSUTCDATETIME()` |
| **JSON Extraction**| `data->>'key'` | `data->>'key'` | `data:key` or `get_json_object()` | `data:key::string` | `JSON_VALUE(data, '$.key')` | `JSON_VALUE(data, '$.key')` |
| **Regex Match** | `col ~ '^[A-Z]'` | `regexp_matches(col, '...')` | `col RLIKE '^[A-Z]'` | `REGEXP_LIKE(col, '...')` | `REGEXP_CONTAINS(col, r'...')` | `col LIKE '[A-Z]%'` (Native basic) |
| **Regex Extract** | `substring(col from 'pattern')`| `regexp_extract(col, 'pattern')` | `regexp_extract(col, 'pattern', 1)` | `REGEXP_SUBSTR(col, 'pattern')` | `REGEXP_EXTRACT(col, r'pattern')` | Requires CLR / Ole Automation |
| **Surrogate Hash** | `md5(col)` | `md5(col)` | `md5(col)` or `sha2(col, 256)` | `MD5(col)` or `SHA2(col, 256)` | `TO_HEX(MD5(col))` | `HASHBYTES('MD5', col)` |
| **List Aggregation**| `string_agg(col, ',')` | `string_agg(col, ',')` | `concat_ws(',', collect_list(col))` | `LISTAGG(col, ',')` | `STRING_AGG(col, ',')` | `STRING_AGG(col, ',')` |
| **Row Number** | `ROW_NUMBER() OVER (...)` | `ROW_NUMBER() OVER (...)` | `row_number() over (...)` | `ROW_NUMBER() OVER (...)` | `ROW_NUMBER() OVER (...)` | `ROW_NUMBER() OVER (...)` |
| **Limit Rows** | `LIMIT 10` | `LIMIT 10` | `LIMIT 10` | `LIMIT 10` | `LIMIT 10` | `TOP 10` or `FETCH NEXT 10 ROWS` |
| **Generate Series**| `generate_series(1, 10)` | `range(1, 11)` | `sequence(1, 10)` | `TABLE(GENERATOR(ROWCOUNT => 10))`| `GENERATE_ARRAY(1, 10)` | Recursive CTE / Tally Table |

---

## 2. JSON & Semi-Structured Query Comparison

Extracting `city` from a JSON payload `{"customer": {"address": {"city": "Zurich"}}}`:

```sql
-- 1. PostgreSQL
SELECT payload->'customer'->'address'->>'city' AS city FROM raw_events;

-- 2. DuckDB
SELECT payload.customer.address.city::VARCHAR AS city FROM raw_events;

-- 3. Databricks Spark SQL
SELECT payload:customer.address.city::string AS city FROM raw_events;

-- 4. Snowflake
SELECT payload:customer:address:city::string AS city FROM raw_events;

-- 5. Google BigQuery
SELECT JSON_VALUE(payload, '$.customer.address.city') AS city FROM raw_events;

-- 6. SQL Server (T-SQL)
SELECT JSON_VALUE(payload, '$.customer.address.city') AS city FROM raw_events;
```

---

## 3. Native Upsert & Merge Syntax Comparison

### Standard ANSI SQL `MERGE` (PostgreSQL 15+, Databricks, Snowflake, BigQuery, SQL Server):

```sql
MERGE INTO target_table AS t
USING source_staging AS s
ON t.id = s.id
WHEN MATCHED AND s.is_deleted = TRUE THEN
    DELETE
WHEN MATCHED THEN
    UPDATE SET 
        t.val = s.val,
        t.updated_at = CURRENT_TIMESTAMP
WHEN NOT MATCHED THEN
    INSERT (id, val, updated_at)
    VALUES (s.id, s.val, CURRENT_TIMESTAMP);
```

### PostgreSQL Native `ON CONFLICT` (High Performance OLTP Upsert):

```sql
INSERT INTO target_table (id, val, updated_at)
VALUES (1, 'Alpha', CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    val = EXCLUDED.val,
    updated_at = EXCLUDED.updated_at;
```

### DuckDB Native `INSERT OR REPLACE`:

```sql
INSERT OR REPLACE INTO target_table (id, val, updated_at)
VALUES (1, 'Alpha', CURRENT_TIMESTAMP);
```
