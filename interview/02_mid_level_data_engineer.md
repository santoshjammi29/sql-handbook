# 🎓 Interview Question Bank — Tier 2: Mid-Level Data Engineer (Analytical Mastery)

> **Focus Areas**: Advanced Window Functions, Gaps & Islands, Recursive CTEs, Deduplication, Query SARGability, and Hierarchical Data Traversal.

---

### Q2.1: Compare `ROW_NUMBER()`, `RANK()`, and `DENSE_RANK()` when processing tied values.

**Answer:**  
Suppose five employees earn salaries: `[100k, 90k, 90k, 80k, 70k]`.

| Salary | `ROW_NUMBER()` | `RANK()` | `DENSE_RANK()` | Explanation |
| :---: | :---: | :---: | :---: | :--- |
| **100k** | 1 | 1 | 1 | Highest salary. |
| **90k** | 2 | 2 | 2 | First tied value. |
| **90k** | 3 | 2 | 2 | Second tied value. `ROW_NUMBER` increments arbitrarily; `RANK` & `DENSE_RANK` match. |
| **80k** | 4 | **4** | **3** | `RANK` skips to 4 (accounts for 3 prior rows). `DENSE_RANK` produces next contiguous rank (3). |
| **70k** | 5 | 5 | 4 | Next rank. |

**Interview Coding Challenge**: Find the 2nd highest salary department-wise:
```sql
WITH ranked_salaries AS (
    SELECT 
        department_id,
        employee_id,
        salary,
        DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS salary_rank
    FROM employees
)
SELECT * FROM ranked_salaries WHERE salary_rank = 2;
```

---

### Q2.2: How do you solve the classic "Gaps & Islands" problem to detect consecutive user activity streaks?

**Answer:**  
The Gaps & Islands problem is solved using the **"Date Minus Row Number"** technique. When consecutive dates increase by 1 day and `ROW_NUMBER()` increases by 1 each row, subtracting `ROW_NUMBER()` days from the event date yields a **constant anchor date** (the "Island Key").

```sql
-- Detect consecutive login streaks per user:
WITH distinct_logins AS (
    -- Step 1: Deduplicate multiple logins on the same day
    SELECT DISTINCT user_id, login_date FROM user_logins
),
streaks AS (
    -- Step 2: Compute Island Key = login_date - row_number
    SELECT 
        user_id,
        login_date,
        -- Subtracting integer row_number from date produces identical date for contiguous streaks
        login_date - CAST(ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date ASC) AS INT) AS island_key
    FROM distinct_logins
)
-- Step 3: Aggregate contiguous islands
SELECT 
    user_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*)        AS streak_length_days
FROM streaks
GROUP BY user_id, island_key
HAVING COUNT(*) >= 3 -- Filter for streaks of 3 or more days
ORDER BY streak_length_days DESC;
```

---

### Q2.3: How do you delete duplicate records from a table while preserving exactly one record?

**Answer:**  
Using a Common Table Expression (CTE) combined with `ROW_NUMBER()`:

```sql
-- PostgreSQL / SQL Server / SQLite:
WITH duplicate_cte AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY email, company_id 
            ORDER BY created_at ASC, id ASC -- Preserves earliest inserted record
        ) AS rn
    FROM customers
)
DELETE FROM customers
WHERE id IN (
    SELECT id FROM duplicate_cte WHERE rn > 1
);
```

---

### Q2.4: Solve the Binary Tree Node Classification Problem (LeetCode 608).

**Problem**: Given a table `tree (id INT, p_id INT)` where `id` is the node and `p_id` is its parent:
- **Root**: `p_id IS NULL`
- **Inner**: has a parent AND has at least one child
- **Leaf**: has a parent AND has NO children

**Optimal Solution:**
```sql
SELECT 
    id,
    CASE 
        WHEN p_id IS NULL THEN 'Root'
        WHEN id IN (SELECT p_id FROM tree WHERE p_id IS NOT NULL) THEN 'Inner'
        ELSE 'Leaf'
    END AS node_type
FROM tree
ORDER BY id ASC;
```
*(Notice the critical `WHERE p_id IS NOT NULL` guard inside the `IN` subquery to prevent 3VL NULL collapse!)*

---

### Q2.5: What is SARGability, and how does it dictate index usage?

**Answer:**  
A search argument is **SARGable** if the query optimizer can utilize a B-Tree index range scan or seek. Wrapping an indexed column inside a scalar function renders the predicate non-SARGable.

**Example**:
```sql
-- NON-SARGable: Scans all 50M rows (Full Table Scan)
SELECT * FROM sales WHERE EXTRACT(YEAR FROM sale_date) = 2024;

-- SARGable: Seeks directly to range boundary in B-Tree (Index Seek)
SELECT * FROM sales 
WHERE sale_date >= '2024-01-01' AND sale_date < '2025-01-01';
```
