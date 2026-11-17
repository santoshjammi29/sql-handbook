# ⚡ 50 Rapid-Fire Technical SQL & Data Engineering Flashcards

> **Format**: Question & Answer designed for high-density interview revision and mental model verification.

---

### Flashcards 01 – 10: SQL Core & Logic
1. **Q: Does `NULL = NULL` return `TRUE`?**  
   *A: No, it evaluates to `UNKNOWN` under Three-Valued Logic (3VL). Use `IS NULL`.*
2. **Q: What is the first clause logically evaluated in a SQL query?**  
   *A: The `FROM` clause (along with `JOIN` operations).*
3. **Q: Can a column alias declared in `SELECT` be referenced in `WHERE`?**  
   *A: No, because `WHERE` is evaluated at Step 2, while `SELECT` is evaluated at Step 6.*
4. **Q: Can a column alias declared in `SELECT` be referenced in `ORDER BY`?**  
   *A: Yes, because `ORDER BY` (Step 9) executes after `SELECT` (Step 6).*
5. **Q: What is the output of `SELECT COUNT(x)` when column `x` has only NULLs?**  
   *A: `0`. Unlike `COUNT(*)`, `COUNT(column)` ignores `NULL` entries.*
6. **Q: What is the result of `WHERE id NOT IN (1, 2, NULL)`?**  
   *A: Always evaluates to `UNKNOWN` (returns 0 rows). Use `NOT EXISTS`.*
7. **Q: What is the difference between `TRUNCATE` and `DELETE`?**  
   *A: `DELETE` is DML, row-by-row logged, fires triggers, can be rolled back. `TRUNCATE` is DDL, deallocates entire data pages, minimally logged, faster.*
8. **Q: What is SARGability?**  
   *A: Search Argument Able — writing predicates so the engine can perform a B-Tree Index Seek rather than a Full Table Scan.*
9. **Q: Why does `WHERE YEAR(date) = 2024` kill index performance?**  
   *A: Wrapping an indexed column in a function prevents index traversal. Rewrite as `date >= '2024-01-01' AND date < '2025-01-01'`.*
10. **Q: What is the difference between `COALESCE` and `ISNULL`?**  
    *A: `COALESCE` is ANSI SQL standard, accepts $N$ arguments, evaluates short-circuit. `ISNULL` is T-SQL specific and accepts exactly 2 arguments.*

---

### Flashcards 11 – 20: Joins & Aggregations
11. **Q: What happens if an `INNER JOIN` matches 3 rows on the left to 4 rows on the right?**  
    *A: It produces a Cartesian product for those keys: $3 \times 4 = 12$ rows.*
12. **Q: What is a Semi-Join?**  
    *A: An operation (e.g. `EXISTS`) that filters the left table to rows matching the right table without duplicating left rows.*
13. **Q: What is an Anti-Join?**  
    *A: An operation (e.g. `NOT EXISTS`) that returns rows from the left table that have NO matching rows in the right table.*
14. **Q: What is the difference between `UNION` and `UNION ALL`?**  
    *A: `UNION` executes an expensive deduplication sort; `UNION ALL` appends rows directly with zero sorting overhead.*
15. **Q: What is a Lateral Join / Cross Apply?**  
    *A: A join where the right-side subquery or table-valued function can reference columns from the left-side row currently being evaluated.*
16. **Q: What does `GROUP BY ROLLUP(a, b)` produce?**  
    *A: Hierarchical subtotals: `(a, b)`, `(a)`, and `()` (grand total).*
17. **Q: What does `GROUP BY CUBE(a, b)` produce?**  
    *A: All combinatorial aggregations: `(a, b)`, `(a)`, `(b)`, and `()`.*
18. **Q: When does `HAVING` execute relative to `GROUP BY`?**  
    *A: Immediately after `GROUP BY` groups and aggregates the rows.*
19. **Q: Can you use aggregate functions like `SUM()` in a `WHERE` clause?**  
    *A: No, because `WHERE` executes before aggregations are computed.*
20. **Q: How does `STRING_AGG` (or `GROUP_CONCAT`) handle `NULL` values?**  
    *A: It skips `NULL` entries and concatenates only non-null values.*

---

### Flashcards 21 – 30: Window Functions
21. **Q: How does `RANK()` differ from `DENSE_RANK()` on tied values?**  
    *A: `RANK()` leaves gaps in ranking numbers after ties (1, 2, 2, 4); `DENSE_RANK()` has no gaps (1, 2, 2, 3).*
22. **Q: What is the default window frame when `ORDER BY` is present but no frame clause is specified?**  
    *A: `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.*
23. **Q: Why is `ROWS BETWEEN ...` preferred over `RANGE BETWEEN ...` for running totals?**  
    *A: `ROWS` operates on physical row offsets and avoids grouping identical values into a single range, consuming less memory and running faster.*
24. **Q: What does `LAG(col, 1)` return for the first row in a partition?**  
    *A: `NULL` (or the user-defined default fallback value).*
25. **Q: How do you identify consecutive streaks in the Gaps and Islands problem?**  
    *A: By subtracting `ROW_NUMBER()` from the event date to generate a constant `island_key`.*
26. **Q: Can window functions be used directly in a `WHERE` clause?**  
    *A: No. Window functions evaluate at Step 5, after `WHERE`. You must wrap them in a CTE or subquery.*
27. **Q: What does `NTILE(4)` do?**  
    *A: Divides an ordered partition into 4 approximately equal quartiles.*
28. **Q: What does `FIRST_VALUE(col)` return?**  
    *A: The value of `col` in the first row of the window frame.*
29. **Q: Why does `LAST_VALUE(col)` often return the current row instead of the true last row?**  
    *A: Because the default frame ends at `CURRENT ROW`. You must specify `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.*
30. **Q: What does `LEAD(amount, 1) OVER (ORDER BY date)` calculate?**  
    *A: The next row's transaction amount in chronological order.*

---

### Flashcards 31 – 40: Modeling & Optimization
31. **Q: What is a Kimball Star Schema?**  
    *A: A data model consisting of a central Fact table containing metrics/grain surrounded by de-normalized Dimension tables containing context.*
32. **Q: What is an SCD Type 2 dimension?**  
    *A: A dimension that tracks historical changes by inserting a new row per mutation with `valid_from`, `valid_to`, and `is_current` columns.*
33. **Q: What is a surrogate key?**  
    *A: A system-generated, artificial unique identifier (e.g. integer sequence, UUID, or MD5 hash) with zero business meaning.*
34. **Q: What is a conformed dimension?**  
    *A: A shared dimension (e.g. `dim_date`, `dim_customer`) with consistent schema and keys used across multiple fact tables.*
35. **Q: What is an Index Seek vs an Index Scan?**  
    *A: An Index Seek traverses B-Tree root-to-leaf ($\mathcal{O}(\log N)$); an Index Scan reads all leaf pages of the index ($\mathcal{O}(N)$).*
36. **Q: What is a Covering Index?**  
    *A: An index that contains all columns requested by a query (via key columns or `INCLUDE`), eliminating secondary key lookups.*
37. **Q: What is a composite index left-prefix rule?**  
    *A: An index on `(A, B, C)` can only accelerate queries filtering on `(A)`, `(A, B)`, or `(A, B, C)`. It cannot seek on `(B)` alone.*
38. **Q: What causes Cardinality Estimation regressions?**  
    *A: Stale table statistics, leading the optimizer to miscalculate row counts and choose disastrous execution plans.*
39. **Q: What is Parameter Sniffing?**  
    *A: When the database compiles a plan based on the parameters of the first execution, which may be unrepresentative of typical calls.*
40. **Q: How does a B+ Tree differ from a standard B-Tree?**  
    *A: In a B+ Tree, data rows/pointers reside exclusively in leaf nodes, and leaf nodes are doubly linked for fast sequential range scans.*

---

### Flashcards 41 – 50: Distributed Systems, MPP & Concurrency
41. **Q: What is Multi-Version Concurrency Control (MVCC)?**  
    *A: A concurrency mechanism where updates create new tuple versions so readers never block writers and writers never block readers.*
42. **Q: What is Write Skew?**  
    *A: A concurrency anomaly under Snapshot Isolation where two transactions read overlapping data, update distinct rows, and violate a global invariant.*
43. **Q: What causes a Deadlock (Error 1205)?**  
    *A: Two or more transactions waiting for locks held by each other, forming a cyclic dependency.*
44. **Q: What is the universal engineering fix for deadlocks?**  
    *A: Enforce strict canonical resource ordering (always lock resources in ascending primary key order).*
45. **Q: What is the "99% complete straggler task" symptom in distributed SQL?**  
    *A: Data skew — one executor partition has a disproportionate number of rows (e.g. due to NULLs or a dominant tenant ID).*
46. **Q: How does Key Salting resolve join skew?**  
    *A: It appends a random integer ($0 \dots K-1$) to skewed keys on the fact table and explodes the dimension table $K$ times.*
47. **Q: What is a Broadcast Join in Spark/MPP?**  
    *A: A join where the small table is copied to every worker node, eliminating network shuffles of the large table.*
48. **Q: What causes Shuffle Spill to Disk in Spark SQL?**  
    *A: When shuffle partition memory exceeds available executor RAM; solved by increasing `spark.sql.shuffle.partitions`.*
49. **Q: What is Snowflake's Micro-Partitioning?**  
    *A: Automatic, immutable 50–500MB columnar chunks with global metadata min/max statistics used for partition pruning.*
50. **Q: What is Delta Lake Liquid Clustering (`CLUSTER BY`)?**  
    *A: Dynamic multidimensional clustering that replaces rigid physical Hive directory partitioning, eliminating the small file problem.*
