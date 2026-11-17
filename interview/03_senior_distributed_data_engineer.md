# 🎓 Interview Question Bank — Tier 3: Senior Data Engineer (Distributed Systems & Performance)

> **Focus Areas**: Distributed MPP Engines, Spark SQL & Databricks Tuning, The 5 S's Framework, Data Skew Mitigation, SCD Types 1-6, and Concurrency Control.

---

### Q3.1: Detail the "5 S's" Framework for Distributed Query Engine & Spark Performance Tuning.

**Answer:**  
The 5 S's isolate every major failure mode in distributed query processing:

1. **Storage (Small File Problem)**:
   - *Symptom*: High metadata listing overhead, millions of 100KB files.
   - *Fix*: Run `OPTIMIZE table_name` (Delta Lake bin-packing) or configure autocompaction.
2. **Skew (Straggler Tasks)**:
   - *Symptom*: 199 tasks finish in seconds; 1 task runs for 2 hours.
   - *Fix*: Two-phase key salting with random integer suffix ($0 \dots K-1$) or enable Spark AQE Skew Join (`spark.sql.adaptive.skewJoin.enabled = true`).
3. **Spill (Tungsten RAM $\rightarrow$ Disk)**:
   - *Symptom*: `Spill (Disk)` appears in Spark UI / Snowflake local storage spill.
   - *Fix*: Right-size partition count so each partition is $\approx 150 \text{ MB}$: $\text{partitions} = \frac{\text{shuffle data MB}}{150 \text{ MB}}$.
4. **Shuffle (Network Interconnect Saturation)**:
   - *Symptom*: Huge network I/O during wide transformations (`JOIN`, `GROUP BY`, `DISTINCT`).
   - *Fix*: Pre-filter before joins, use broadcast joins for dimensions $< 100 \text{ MB}$, and co-locate table distributions.
5. **Serialization (JVM $\leftrightarrow$ Python / Driver Bottleneck)**:
   - *Symptom*: PySpark row-by-row Python UDFs bottlenecking CPU cores.
   - *Fix*: Replace standard Python UDFs with PyArrow Vectorized Pandas UDFs (`@pandas_udf`) or native Spark SQL expressions.

---

### Q3.2: Walk through the architectural differences between SCD Type 1, Type 2, and Type 6.

**Answer:**  

| Dimension Property | SCD Type 1 | SCD Type 2 | SCD Type 6 (1 + 2 + 3) |
| :--- | :--- | :--- | :--- |
| **Historical Preservation** | None (Overwrites in-place) | Full Unlimited History | Full History + Fast Current Lookup |
| **Row Multiplicity** | Exactly 1 row per entity | N rows per entity (N-1 expired, 1 active) | N rows per entity |
| **Metadata Columns** | `last_updated_at` | `valid_from`, `valid_to`, `is_current` | `valid_from`, `valid_to`, `is_current`, `current_attribute` |
| **Fact Table Joins** | Simple join on natural/surrogate key | Must join on surrogate key OR timestamp interval range (`txn_date BETWEEN valid_from AND valid_to`) | Join on current attribute directly without filtering |
| **Use Case** | Correcting typo in customer phone number | Tracking customer address history across moves | Sales attribution needing historical territory + current territory |

---

### Q3.3: How does Snowflake manage clustering without physical table partitioning?

**Answer:**  
Snowflake does not use traditional physical directory partitioning (e.g. `/year=2024/month=05/`). Instead, it uses **Micro-Partitions**:
- Tables are automatically divided into contiguous, immutable micro-partitions containing $50 \text{ MB}$ to $500 \text{ MB}$ of uncompressed columnar data.
- Snowflake maintains a global metadata catalog tracking the **Min/Max values** of every single column within each micro-partition.
- **Clustering Keys**: You can define a clustering key (e.g., `CLUSTER BY (tenant_id, event_date)`). Snowflake groups rows with similar values into the same micro-partitions.
- When a query filters `WHERE tenant_id = 42 AND event_date = '2024-05-01'`, the coordinator performs **Metadata Partition Pruning**, skipping 99% of micro-partitions without touching object storage.

---

### Q3.4: Explain how Key Salting mitigates Join Skew in distributed engines.

**Answer:**  
In distributed joins (Spark SQL, Trino, Snowflake), join keys are hashed to determine which executor processes them: `hash(key) % num_executors`. If a specific key (e.g., `customer_id = 0`) has 50 million rows, all 50M rows land on a single executor worker node, creating a straggler.

**The 3-Step Salting Pattern**:
1. Append a random integer (e.g., $0 \dots 9$) to the skewed key in the large fact table.
2. Explode the small dimension table $10\times$ by cross-joining it with a salt array `[0, 1, ..., 9]`, creating matching salted keys.
3. Join on `salted_key`. The 50M rows are now split across 10 distinct executors uniformly, eliminating the bottleneck.

---

### Q3.5: What is a Deadlock (Error 1205), and what architectural rule prevents it?

**Answer:**  
A deadlock occurs when two transactions hold locks that the other requires, creating a cyclic dependency graph ($T_1 \rightarrow T_2 \rightarrow T_1$). The engine detects the cycle in its internal wait-for graph and forcefully terminates one transaction as the deadlock victim.

**The Golden Prevention Rule**: **Canonical Global Resource Ordering**.  
Every transaction must access/lock shared resources in the identical deterministic order (e.g., sorting account IDs in ascending order: `min(id)` then `max(id)`). By establishing a strict partial ordering, cyclic dependencies are mathematically impossible.
