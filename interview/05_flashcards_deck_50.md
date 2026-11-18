# 🗂️ SQL & Cloud Data Warehouse Technical Flashcard Deck (50 Active Recall Questions)

> **Coverage**: Modules 01 through 10 of The SQL Handbook curriculum
> **Focus**: Rapid-fire SQL execution rules, query planner behaviors, index physics, and FinOps traps

---

### 1. What is the exact ANSI SQL logical query execution order?

**Answer:**  
1. FROM & JOIN -> 2. WHERE -> 3. GROUP BY -> 4. HAVING -> 5. WINDOW -> 6. SELECT -> 7. DISTINCT -> 8. UNION/INTERSECT/EXCEPT -> 9. ORDER BY -> 10. LIMIT/OFFSET.

---

### 2. Why can't you use a SELECT column alias in a WHERE clause?

**Answer:**  
Because WHERE executes at Step 2 (filtering base rows) whereas SELECT executes at Step 6 (projecting expressions). The alias does not exist when WHERE evaluates.

---

### 3. What is the difference between COUNT(*), COUNT(1), and COUNT(column)?

**Answer:**  
COUNT(*) and COUNT(1) count all rows matching the predicate, including rows where all columns are NULL. COUNT(column) increments only for rows where that specific column IS NOT NULL.

---

### 4. What is Three-Valued Logic (3VL) in SQL?

**Answer:**  
Every boolean comparison in SQL evaluates to TRUE, FALSE, or UNKNOWN (when evaluating against NULL). Predicates in WHERE and HAVING only retain rows where the expression evaluates strictly to TRUE.

---

### 5. What is the result of `SELECT * FROM tbl WHERE id NOT IN (1, 2, NULL)`?

**Answer:**  
Returns 0 rows (empty set). In SQL, `id NOT IN (1, 2, NULL)` expands to `id != 1 AND id != 2 AND id != NULL`. Since `id != NULL` evaluates to UNKNOWN, the entire conjunction evaluates to UNKNOWN, discarding all rows!

---

### 6. What is SARGability, and why is `WHERE YEAR(order_date) = 2026` an anti-pattern?

**Answer:**  
Search Argument Able (SARGable) predicates allow the optimizer to perform an efficient B-Tree index seek. Wrapping indexed columns in functions like `YEAR(order_date)` forces the engine to evaluate the function for every row, triggering an expensive full index or table scan. Use `WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01'` instead.

---

### 7. What is the difference between UNION and UNION ALL?

**Answer:**  
UNION performs an implicit deduplication (sort or hash distinct), which incurs high CPU and memory overhead. UNION ALL simply concatenates result streams without deduplication and should always be preferred unless deduplication is strictly required.

---

### 8. Explain the difference between ROW_NUMBER(), RANK(), and DENSE_RANK().

**Answer:**  
For ties: ROW_NUMBER() assigns consecutive integers arbitrarily (1, 2, 3, 4). RANK() leaves gaps after ties (1, 2, 2, 4). DENSE_RANK() does not leave gaps (1, 2, 2, 3).

---

### 9. What is the difference between ROWS BETWEEN and RANGE BETWEEN in analytical window frames?

**Answer:**  
ROWS defines physical offset row counts (e.g. `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`). RANGE defines logical value ranges based on the ORDER BY value (e.g. `RANGE BETWEEN INTERVAL 7 DAYS PRECEDING AND CURRENT ROW`).

---

### 10. What is the danger of an unbounded window function without framing (e.g. `OVER (ORDER BY val)`)?

**Answer:**  
In ANSI SQL, specifying `ORDER BY` without a frame clause defaults to `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`, which forces the engine to buffer and sort rows dynamically, causing severe performance degradation.

---

### 11. What is a Common Table Expression (CTE), and is it materialized by default?

**Answer:**  
A CTE (`WITH cte AS (...)`) is a readable query modularization tool. In modern optimizers (PostgreSQL 12+, SQL Server, Snowflake), non-recursive CTEs are inlined directly into the outer query rather than materialized into temporary storage, unless specified with `MATERIALIZED`.

---

### 12. What is the termination requirement for a Recursive CTE?

**Answer:**  
A Recursive CTE consists of an Anchor Member, a UNION ALL, and a Recursive Member that references the CTE name with a termination condition (e.g. `WHERE depth < 100` or `WHERE parent_id IS NOT NULL`) to prevent infinite looping.

---

### 13. What is a Clustered Index vs. a Non-Clustered Index?

**Answer:**  
A Clustered Index dictates the physical on-disk sorting order of the actual table data pages (a table can have only one). A Non-Clustered Index is a separate B-Tree structure storing indexed keys and row pointers (clustering keys or RID pointers) back to the base table.

---

### 14. What is an Index Covering Query?

**Answer:**  
A query where all requested columns in SELECT, WHERE, and JOIN exist within the index (as index keys or INCLUDE columns), allowing the engine to satisfy the entire query from the index without performing expensive Key Lookups back to base storage.

---

### 15. What is a Bookmark / Key Lookup in execution plans?

**Answer:**  
When an index seek locates matching rows in a non-clustered index, but the query requests columns not present in that index, the engine must perform random disk I/O to read the data pages of the base table for each matching row.

---

### 16. What is a Filtered / Partial Index?

**Answer:**  
An index that includes a WHERE clause (e.g. `CREATE INDEX idx ON orders(status) WHERE status = 'PENDING'`), indexing only a subset of data to save storage and drastically accelerate targeted queries.

---

### 17. What is the difference between Surrogate Keys and Natural Keys in dimensional modeling?

**Answer:**  
Natural keys are business-domain identifiers (e.g. SSN, Email, ISBN) subject to changes and privacy laws. Surrogate keys are meaningless system-generated integers or hashes (e.g. `customer_sk`) guaranteeing immutability and high-performance joins in star schemas.

---

### 18. What is a Star Schema vs. a Snowflake Schema?

**Answer:**  
A Star Schema features a central fact table joined directly to denormalized dimension tables (1-hop joins, optimal for analytical read performance). A Snowflake Schema normalizes dimension tables into sub-dimensions (multi-hop joins, reducing storage redundancy but increasing join complexity).

---

### 19. What is Slowly Changing Dimension (SCD) Type 1 vs. Type 2?

**Answer:**  
SCD Type 1 overwrites old attribute values with new values, retaining zero historical track record. SCD Type 2 appends a new record with effective dates (`valid_from`, `valid_to`, `is_current = TRUE`), maintaining complete historical audit trails.

---

### 20. What is the difference between an Equi-Join and a Non-Equi Join in execution plans?

**Answer:**  
Equi-joins (`ON a.id = b.id`) can be executed efficiently via Hash Joins or Sort-Merge Joins (O(M+N)). Non-equi joins (`ON a.val < b.val`) force the engine to evaluate Nested Loops or Cartesian Products (O(M*N)).

---

### 21. What is a Hash Join, and what are its Build and Probe phases?

**Answer:**  
In a Hash Join, the engine reads the smaller relation (Build Phase), hashes join keys, and builds an in-memory hash table. It then scans the larger relation (Probe Phase), hashes each row's key, and probes the hash table for matches.

---

### 22. When does a Hash Join degrade into a Grace / Hybrid Hash Join?

**Answer:**  
When the build relation exceeds available memory, the engine partitions both relations into hashed buckets on disk and processes pairs of buckets sequentially, incurring heavy disk I/O spill.

---

### 23. What is a Sort-Merge Join, and when is it preferred over a Hash Join?

**Answer:**  
Both relations are sorted by join key and merged in a single coordinated scan. Preferred when inputs are already pre-sorted (by clustered index or range partitioning) or when relations are too massive to fit in RAM.

---

### 24. What is an MPP (Massively Parallel Processing) architecture in cloud data warehouses?

**Answer:**  
A distributed shared-nothing or decoupled-storage architecture where a coordinator/leader node distributes query plans across dozens or hundreds of independent compute worker nodes, each processing a shard of data in parallel.

---

### 25. What are the primary data distribution styles in MPP databases (Redshift, Azure Synapse, Snowflake)?

**Answer:**  
1. HASH: Rows distributed by hash of a specific key. 2. EVEN / ROUND-ROBIN: Rows distributed uniformly across nodes. 3. REPLICATED / ALL: Complete table copied to every compute node (ideal for small dimension tables).

---

### 26. What is Data Movement in distributed SQL execution?

**Answer:**  
When joining two tables distributed on different hash keys, worker nodes must shuffle rows across the network (Shuffle / Redistribution) or broadcast an entire table (Broadcast Move) so matching keys reside on the same physical node.

---

### 27. What is a Broadcast Move in MPP, and when should it be used?

**Answer:**  
Sending an entire copy of a smaller table to every compute node, completely eliminating network shuffling for the massive fact table. Optimal when dimension table is < 100MB.

---

### 28. What is Data Skew in an MPP cloud warehouse?

**Answer:**  
An uneven distribution of data across worker nodes, causing one node to hold significantly more rows than others. The query duration is dictated by the slowest skewed node while all other nodes sit idle.

---

### 29. How do columnar storage formats (Parquet, ORC, Delta) accelerate analytical queries compared to row-based storage (PostgreSQL, MySQL)?

**Answer:**  
1. Column Projection Pruning: Only reads columns referenced in SELECT/WHERE, eliminating 90%+ of I/O. 2. High Compression: Similar data types in contiguous blocks achieve 70-90% compression ratios. 3. SIMD Vectorization: Modern CPUs evaluate vectorized operators across column arrays.

---

### 30. What is Min/Max Data Skipping (Zone Maps / Parquet Statistics)?

**Answer:**  
Columnar storage formats write minimum and maximum column values into metadata headers for each file or row group. Query engines inspect these statistics to skip reading entire files that cannot match the WHERE filter.

---

### 31. What is the difference between Pessimistic Concurrency Control and Optimistic Concurrency Control (OCC)?

**Answer:**  
Pessimistic: Acquires locks (Shared, Exclusive) before reading/writing, blocking concurrent transactions. Optimistic: Allows transactions to execute without locking; at commit time, verifies whether conflicting writes occurred; if conflict, aborts and retries.

---

### 32. What is Multi-Version Concurrency Control (MVCC)?

**Answer:**  
A concurrency architecture where updates do not overwrite data in place; instead, they create new row versions with transaction timestamps. Readers do not block writers, and writers do not block readers.

---

### 33. What is a Deadlock in SQL transactions, and how does the engine resolve it?

**Answer:**  
A cyclic dependency where Transaction A holds Lock 1 and waits for Lock 2, while Transaction B holds Lock 2 and waits for Lock 1. The database deadlock detector terminates (kills) the transaction with the lowest rollback cost (the victim).

---

### 34. What are the 4 standard ANSI SQL Transaction Isolation Levels?

**Answer:**  
1. Read Uncommitted (allows Dirty Reads). 2. Read Committed (prevents Dirty Reads, allows Non-Repeatable Reads). 3. Repeatable Read (prevents Non-Repeatable Reads, allows Phantom Reads). 4. Serializable (highest isolation, full serializability).

---

### 35. What is a Phantom Read?

**Answer:**  
When Transaction A queries a range of rows (e.g. `WHERE salary > 50000`), and Transaction B inserts a new row satisfying that range and commits. When Transaction A re-runs the query, a new 'phantom' row appears.

---

### 36. What is Write Amplification in database storage?

**Answer:**  
The ratio of bytes written to persistent storage relative to the logical bytes requested. For example, updating a 10-byte field in an immutable Parquet file rewrites the entire 500MB file, causing massive write amplification.

---

### 37. How do Deletion Vectors solve write amplification in Delta Lake and Apache Iceberg?

**Answer:**  
Instead of rewriting the entire Parquet file upon an UPDATE or DELETE, the engine writes a small binary bitmap tracking deleted row offsets, deferring physical compaction until maintenance.

---

### 38. What is the difference between Delta Lake and Apache Iceberg?

**Answer:**  
Both are open-source ACID table formats. Delta Lake uses a JSON-based append-only transaction log (`_delta_log/`) with periodic Parquet checkpoints. Apache Iceberg uses hierarchical snapshot trees with metadata JSON, manifest lists, and manifest files.

---

### 39. What is the purpose of the `MERGE INTO` statement in Lakehouse SQL?

**Answer:**  
A single atomic ANSI SQL command that performs UPSERT (Update existing rows, Insert new rows, and optionally Delete missing rows) in a single ACID transaction.

---

### 40. Why should MERGE statements in Lakehouse tables always include partition predicates in the ON clause?

**Answer:**  
Restricting the ON clause with a partition filter (`ON target.id = source.id AND target.date = source.date`) allows the engine to prune unmodified partitions, reducing I/O and eliminating concurrent write conflicts.

---

### 41. What is Z-Ordering in Lakehouse tables?

**Answer:**  
A space-filling curve algorithm that maps multidimensional data into 1-dimensional order, allowing efficient data skipping along up to 3-4 columns simultaneously.

---

### 42. What is the difference between Snowflake Virtual Warehouses and BigQuery Slots?

**Answer:**  
Snowflake decouples compute into sized EC2/VM clusters (T-shirt sizes: X-Small to 4X-Large) billed by active uptime seconds. BigQuery allocates dynamic compute workers called 'Slots' billed on-demand (per TB scanned) or through reservation capacity.

---

### 43. What is the most effective FinOps strategy for BigQuery on-demand queries?

**Answer:**  
1. Never use `SELECT *`. 2. Partition tables by date/timestamp and cluster by high-cardinality search attributes. 3. Use dry-run query estimators before executing massive scans.

---

### 44. What is the difference between a Materialized View and a Standard View?

**Answer:**  
A Standard View is a saved query definition re-executed on every reference. A Materialized View physically stores pre-computed query results on disk and refreshes incrementally as underlying tables change.

---

### 45. What is Change Data Capture (CDC)?

**Answer:**  
A technique that monitors and captures row-level mutations (`INSERT`, `UPDATE`, `DELETE`) from a transactional database log (e.g. Postgres WAL, SQL Server CDC, MySQL binlog) and streams them to the lakehouse in real time.

---

### 46. What is an Idempotent SQL pipeline?

**Answer:**  
A pipeline that produces the exact same end-state result regardless of how many times it is executed with the same input data (e.g. using `INSERT OVERWRITE` or deterministic `MERGE INTO` rather than blind `INSERT INTO`).

---

### 47. What is the difference between deterministic and non-deterministic SQL functions?

**Answer:**  
Deterministic functions (e.g. `ABS()`, `UPPER()`, `COALESCE()`) always return the exact same output for given inputs. Non-deterministic functions (e.g. `CURRENT_TIMESTAMP()`, `RAND()`, `NEWID()`) return different values on each invocation and prevent query plan caching.

---

### 48. How do you resolve a high-cardinality Cartesian product caused by a many-to-many join trap?

**Answer:**  
Pre-aggregate the child table to the grain of the parent key before joining, or use `EXISTS` / `NOT EXISTS` semi-joins instead of physical inner joins.

---

### 49. What is an Index Seek vs. Index Scan?

**Answer:**  
Index Seek traverses the B-Tree directly to the matching key leaf pages in O(log N) time. Index Scan traverses all leaf pages of the index from start to finish in O(N) time.

---

### 50. What is the single most critical rule for SQL query optimization in enterprise warehouses?

**Answer:**  
Minimize row cardinality and column projection at the earliest possible stage of the execution plan (push down filters, avoid SELECT *, eliminate unnecessary joins).

---
