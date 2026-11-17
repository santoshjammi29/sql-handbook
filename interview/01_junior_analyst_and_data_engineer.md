# 🎓 Interview Question Bank — Tier 1: Junior Data Analyst & Engineer (Foundations)

> **Focus Areas**: Logical Query Execution Order, JOIN Mechanics, Three-Valued Logic, Aggregations, SARGability, and Basic Analytical Queries.

---

### Q1.1: What is the exact logical execution order of an ANSI SQL query, and why does it matter in practice?

**Answer:**  
SQL is a declarative language, but database engines evaluate clauses in a strictly defined logical pipeline:

1. `FROM` (including `JOIN` operations)
2. `WHERE` (row-level filtering)
3. `GROUP BY` (bucketing rows into aggregate groups)
4. `HAVING` (filtering aggregate buckets)
5. `WINDOW` (evaluating analytical window functions like `ROW_NUMBER()`)
6. `SELECT` (evaluating expressions, projecting columns, aliasing)
7. `DISTINCT` (deduplicating output projection)
8. `UNION` / `INTERSECT` / `EXCEPT` (set operations)
9. `ORDER BY` (sorting the final stream)
10. `LIMIT` / `OFFSET` / `TOP` (pagination / row truncation)

**Production Impact**:
- You cannot filter on an alias defined in `SELECT` within a `WHERE` clause because `WHERE` executes at Step 2 while `SELECT` executes at Step 6.
- Filtering in `WHERE` discards rows *before* memory is allocated for the `GROUP BY` hash table (Step 3), making queries up to $100\times$ faster than filtering post-aggregation in `HAVING`.

---

### Q1.2: What are the exact behavioral differences between `COUNT(*)`, `COUNT(1)`, and `COUNT(column)`?

**Answer:**  
- **`COUNT(*)`**: Counts all rows matching the predicate, including rows where every column is `NULL`. The optimizer recognizes this as "count tuples" and uses the smallest available index.
- **`COUNT(1)`**: Logically equivalent to `COUNT(*)`. The engine evaluates the constant expression `1` for each row. In modern optimizers (PostgreSQL, SQL Server, MySQL, Snowflake), `COUNT(1)` and `COUNT(*)` compile into the identical physical execution plan.
- **`COUNT(column)`**: Counts only rows where the specified `column` evaluates to **NOT NULL**. It incurs a null-check overhead and will return a strictly lower count if the column contains `NULL` values.

**Code Demonstration:**
```sql
CREATE TABLE test_counts (id INT, val VARCHAR(10));
INSERT INTO test_counts VALUES (1, 'A'), (2, NULL), (3, 'B'), (4, NULL);

SELECT 
    COUNT(*)      AS cnt_star,    -- Returns 4
    COUNT(1)      AS cnt_one,     -- Returns 4
    COUNT(val)    AS cnt_col      -- Returns 2 (ignores rows 2 and 4!)
FROM test_counts;
```

---

### Q1.3: Explain the difference between `WHERE` and `HAVING` with a practical business scenario.

**Answer:**  
- `WHERE` acts on **individual input rows** before aggregation takes place.
- `HAVING` acts on **aggregated summary buckets** after `GROUP BY` completes.

**Business Scenario**: Find departments with total payroll exceeding \$500,000, considering only full-time active employees (`is_active = TRUE`):

```sql
SELECT 
    department_id,
    SUM(salary) AS total_payroll
FROM employees
WHERE is_active = TRUE              -- Filters out inactive employees BEFORE aggregation
GROUP BY department_id
HAVING SUM(salary) > 500000;         -- Filters out departments whose sum is <= 500k AFTER aggregation
```

---

### Q1.4: How does Three-Valued Logic (3VL) affect comparisons involving `NULL`?

**Answer:**  
In SQL, boolean expressions evaluate to one of three truth values: `TRUE`, `FALSE`, or `UNKNOWN`. Any comparison with `NULL` (e.g., `x = NULL`, `x != NULL`, `x < NULL`) evaluates to `UNKNOWN`.

- The `WHERE` clause accepts rows only if the condition evaluates to `TRUE`. Rows evaluating to `FALSE` or `UNKNOWN` are discarded.
- To test for nullity, you must use `IS NULL` or `IS NOT NULL`.

**The `NOT IN` Trap**:
```sql
-- Suppose table B contains values: (1, 2, NULL)
SELECT * FROM table_a 
WHERE id NOT IN (SELECT id FROM table_b);
-- This ALWAYS returns 0 rows!
-- id NOT IN (1, 2, NULL) expands to:
-- (id != 1) AND (id != 2) AND (id != NULL)
-- Anything AND UNKNOWN evaluates to UNKNOWN!
-- FIX: Use NOT EXISTS or filter out NULLs:
SELECT * FROM table_a a
WHERE NOT EXISTS (SELECT 1 FROM table_b b WHERE b.id = a.id);
```

---

### Q1.5: Compare `UNION` vs. `UNION ALL`. When is each appropriate?

**Answer:**  
- **`UNION`**: Combines the result sets of two queries and performs an implicit deduplication (sorting or hashing the entire combined stream to remove identical tuples).
- **`UNION ALL`**: Combines the result sets without deduplication, simply streaming rows from both inputs.

**Performance Rule**: Always default to `UNION ALL` unless business logic strictly mandates deduplication. In distributed databases (Snowflake, Spark, BigQuery), `UNION` forces an expensive network shuffle and memory-intensive sort across all worker nodes.
