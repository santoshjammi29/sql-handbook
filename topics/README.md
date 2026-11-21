# 🧠 Relational SQL, Query Optimization & Database Architecture — Curriculum Topics Directory

> **Curriculum Scope**: **170 Production Topics** verified against real-world lakehouse internals, query engines, and distributed architectures.
> **Live Web Hub**: Explore interactive search and full visual graph at [moderndataengineer.uk/concepts](https://moderndataengineer.uk/concepts).

---

## 📖 Overview & Learning Path

The SQL curriculum covers query execution engines, physical operator plans, B-Tree and Columnstore indexing, transaction isolation levels, distributed sharding, and analytical window functions.

### 🎯 Difficulty Progression
- `🟢 Easy`: Foundational primitives, syntax, and operational core concepts.
- `🟡 Intermediate`: Production configuration, optimization patterns, and pipeline resiliency.
- `🔴 Advanced`: Engine internals, memory management, shuffle mechanics, and fault recovery.
- `🟣 Architect`: Cross-region distributed systems, enterprise governance, high-availability, and FinOps.

---

## 📑 Topics Directory at a Glance

| Module / Pillar | Topics | Key Primitives Covered | Reference Links |
|:---|:---:|:---|:---|
| ⚡ **[Relational SQL, Query Optimization & Transaction Engine](#relational-sql-query-optimization--transaction-engine)** | **91** | Aggregate Semantics: COUNT(*) vs. COUNT(1), B-Tree Indexes & Leaf Node Traversal, Clustered Index, and 88 more | [Jump to Section](#relational-sql-query-optimization--transaction-engine) |
| 🏛️ **[Database Architecture, Distributed Sharding & Cloud MPP](#database-architecture-distributed-sharding--cloud-mpp)** | **79** | Database Sharding Topologies & Live Dynamic Re-sharding, High Cardinality, Low Cardinality, and 76 more | [Jump to Section](#database-architecture-distributed-sharding--cloud-mpp) |

---

## 📚 Comprehensive Topic Specifications

### ⚡ Relational SQL, Query Optimization & Transaction Engine
*T-SQL execution plans, index tuning, locking/blocking, and analytical windowing.*

**Total Topics**: 91

| # | Topic / Concept | Difficulty | Architectural Definition & Core Principle |
|:---:|---|:---:|---|
| 1 | **Aggregate Semantics: COUNT(*) vs. COUNT(1)** | `🟢 Easy` | Aggregate counting semantics define how the database engine evaluates relational cardinality across row counts, constant literals, and nullable column expressions. |
| 2 | **B-Tree Indexes & Leaf Node Traversal** | `🟢 Easy` | Balanced multi-way search tree structures that maintain sorted key orders to facilitate logarithmic O(log N) point seeks and range scans. |
| 3 | **Clustered Index** | `🟢 Easy` | A database index that determines the physical storage order of rows inside a table. |
| 4 | **Common Table Expression (CTE)** | `🟢 Easy` | A temporary named result set defined within the execution scope of a single SELECT, INSERT, UPDATE, or DELETE query. |
| 5 | **CREATE TABLE: Schema Metadata & Page Slot Layout** | `🟢 Easy` | The foundational DDL command that provisions table metadata in system catalogs and allocates initial extent/page structures on disk. |
| 6 | **CRUD Lifecycle & Write-Ahead Logging (WAL)** | `🟢 Easy` | The end-to-end execution lifecycle of DML statements governed by ACID write-ahead logging protocols and buffer pool caching. |
| 7 | **FOREIGN KEY** | `🟢 Easy` | A constraint that links key columns in one table to key columns in another, enforcing referential integrity. |
| 8 | **Foreign Keys: Referential Actions & Lock Cascades** | `🟢 Easy` | Relational integrity constraints that enforce cross-table referential relationships and define automated cascade behaviors on mutations. |
| 9 | **GROUP BY: Stream Aggregate vs Hash Aggregate** | `🟢 Easy` | A relational aggregation operator that collapses rows sharing identical key values into single summary rows via physical Stream or Hash algorithms. |
| 10 | **High-Throughput SQL Ingestion via COPY INTO** | `🟢 Easy` | The standard high-performance T-SQL declarative command for parallel, distributed bulk ingestion from cloud storage into relational SQL tables. |
| 11 | **LIMIT & OFFSET Scanning Penalty** | `🟢 Easy` | A common pagination pattern that suffers from linear performance degradation due to mandatory scanning and discarding of preceding offset rows. |
| 12 | **Logical Query Processing Order (S-F-W-G-H-O)** | `🟢 Easy` | Logical Query Processing Order defines the strict conceptual sequence in which the relational database engine evaluates SQL clauses during query execution. |
| 13 | **NULL & Three-Valued Logic (3VL)** | `🟢 Easy` | The foundational relational logic system where boolean expressions evaluate to TRUE, FALSE, or UNKNOWN (NULL). |
| 14 | **Object-Relational Mapping (ORM) & Impedance Mismatch** | `🟢 Easy` | An abstraction layer that maps relational database tables and foreign keys to object-oriented domain classes and in-memory object graphs. |
| 15 | **ORDER BY: Quicksort vs External Merge Sort** | `🟢 Easy` | The physical sorting operator applied to an intermediate rowset to guarantee deterministic ordering across returned records. |
| 16 | **PolyBase Distributed Query & External Tables** | `🟢 Easy` | A database virtualization and scale-out ingestion technology that maps non-relational storage files into SQL relational external tables. |
| 17 | **Relational Data Types & Page Byte Alignment** | `🟢 Easy` | The logical specifications (e.g. INT, VARCHAR, DECIMAL) and underlying physical byte packing schemes used to store column values on 8KB database data pages. |
| 18 | **Relational JOIN Algorithms: Nested Loops, Hash & Merge** | `🟢 Easy` | The three fundamental physical algorithms employed by query engines to combine tuples from two distinct relational inputs. |
| 19 | **ROW_NUMBER() vs. RANK() vs. DENSE_RANK()** | `🟢 Easy` | The three primary SQL ranking window functions that assign integer ordinals to rows based on an ORDER BY specification within a partition. |
| 20 | **T-SQL OPENROWSET Serverless Data Lake Querying** | `🟢 Easy` | A built-in T-SQL table-valued function that enables instant, serverless querying of data lake files without provisioning managed tables. |
| 21 | **Always On Listener & Read Routing** | `🟡 Intermediate` | A virtual network name and IP address that routes application client connections to the active primary replica or read-scale replicas. |
| 22 | **Common Table Expressions: Optimization Fences vs Inlining** | `🟡 Intermediate` | Named temporary result sets defined via WITH clauses that act as logical subqueries, subject to engine-specific inlining or materialization fences. |
| 23 | **Computed Columns: Virtual vs Persisted** | `🟡 Intermediate` | Columns defined via deterministic expressions whose values are either calculated on-the-fly during query evaluation or physically written to disk. |
| 24 | **Covering Indexes & Stored Columns (INCLUDE)** | `🟡 Intermediate` | Non-key column payloads appended directly to the leaf nodes of a B-Tree index to satisfy queries without visiting the primary data table. |
| 25 | **Database Cursors: Row-by-Row Penalty & Tempdb Spooling** | `🟡 Intermediate` | A database control structure that enables procedural, iterative traversal of individual query result set rows, incurring severe performance penalties. |
| 26 | **Database Statistics & Histograms** | `🟡 Intermediate` | System tables storing data distribution histograms used by the query optimizer to estimate rows and build execution plans. |
| 27 | **Decimal Precision & Scale Mismatch Pitfalls** | `🟡 Intermediate` | Incompatibilities between Spark/Parquet 128-bit decimal implementations and SQL relational decimal scale constraints. |
| 28 | **Ingestion Rejection Limits & Error File Quarantining** | `🟡 Intermediate` | Error tolerance thresholds and automated bad-record logging mechanisms in SQL bulk loading commands. |
| 29 | **Keyset Pagination (Seek Method)** | `🟡 Intermediate` | An optimal pagination strategy that uses the values of the last retrieved row within an inequality filter to seek directly to the next page via indexes. |
| 30 | **LATERAL Joins & CROSS APPLY** | `🟡 Intermediate` | A correlated join mechanism that allows an inline subquery or table-valued function to reference column values provided by preceding outer rows. |
| 31 | **Logical Query Execution Order** | `🟡 Intermediate` | The formal sequential order in which a relational database engine processes SQL query clauses, independent of written lexical order. |
| 32 | **Non-Clustered Index** | `🟡 Intermediate` | A separate B-tree structure that maps index keys to clustered index keys or heap row identifiers. |
| 33 | **ORDER BY in Aggregates: Deterministic String & Array Folding** | `🟡 Intermediate` | SQL syntax that enforces explicit internal sorting of values prior to reduction by array, JSON, or string accumulation functions. |
| 34 | **Outer Joins & Where Predicate Null-Suppression** | `🟡 Intermediate` | Relational joins that preserve unmatched tuples from one or both relations by padding missing attributes with NULLs, and the pitfalls of downstream filtering. |
| 35 | **Query Store** | `🟡 Intermediate` | A database feature that automatically captures history of queries, execution plans, and runtime statistics to simplify performance tuning. |
| 36 | **Read Replicas & Read-Scale Out** | `🟡 Intermediate` | An availability group design that offloads read-only workloads (like reports or backups) to secondary database nodes. |
| 37 | **Recursive Common Table Expressions (WITH RECURSIVE)** | `🟡 Intermediate` | A Recursive CTE is a Common Table Expression that references itself iteratively to traverse hierarchical structures, graph trees, or generate sequential interval series. |
| 38 | **Recursive CTEs: Anchor, Working Tables & Cycle Traps** | `🟡 Intermediate` | A hierarchical query structure that repeatedly executes an iterative subquery over intermediate working tables until an empty rowset is returned. |
| 39 | **SARGable Predicates and Index Seek Optimization** | `🟡 Intermediate` | SARGability refers to query predicates written in a structure that allows relational query optimizers to utilize B-tree index seeks rather than forcing full table or clustered index scans. |
| 40 | **Schema Drift & Type Coercion during SQL Loading** | `🟡 Intermediate` | Structural and type discrepancies between source file formats and relational SQL target tables that cause ingest failures or data corruption. |
| 41 | **SQL Server Query Store Regressions** | `🟡 Intermediate` | An internal flight recorder capturing execution plan history, runtime statistics, and forced plan pinning. |
| 42 | **Stored Procedures & Execution Plan Caching** | `🟡 Intermediate` | Precompiled collections of procedural and relational statements stored in the database catalog that reuse cached execution plans. |
| 43 | **The QUALIFY Clause in Modern SQL** | `🟡 Intermediate` | A specialized filtering clause in modern analytical engines (Snowflake, BigQuery, Databricks) that filters the results of window functions directly without wrapping queries in subqueries or CTEs. |
| 44 | **Three-Valued Logic & NULL Propagation** | `🟡 Intermediate` | SQL evaluates boolean expressions using three-valued logic (3VL): TRUE, FALSE, and UNKNOWN, where any direct comparison against NULL yields UNKNOWN. |
| 45 | **Three-Valued Logic (3VL) & The NULL In NOT IN Trap** | `🟡 Intermediate` | The SQL logic standard where boolean expressions evaluate to TRUE, FALSE, or UNKNOWN, and the critical failure pattern where subqueries containing NULL in NOT IN return zero rows. |
| 46 | **Transaction Isolation Levels** | `🟡 Intermediate` | Database settings that control how data modifications are locked and isolated from concurrent transactions. |
| 47 | **Window Frame Specifications: ROWS vs RANGE** | `🟡 Intermediate` | The explicit sliding boundary configuration (e.g. ROWS vs RANGE) that dictates which partition rows are included in a window function's accumulator. |
| 48 | **Window Functions** | `🟡 Intermediate` | Analytical functions that perform calculations across a partition of rows relative to the current row, without collapsing them. |
| 49 | **Always On Availability Groups** | `🔴 Advanced` | A high-availability and disaster recovery solution providing multi-database failover capabilities. |
| 50 | **Azure SQL Optimized Locking** | `🔴 Advanced` | Optimized Locking is a database engine capability in Azure SQL that replaces traditional multi-granularity page/row locks with Transaction-ID (XACT) locking and Lock-After-Qualification (LAQ). |
| 51 | **Clustered vs. Non-Clustered B-Tree Indexes** | `🔴 Advanced` | The two fundamental indexing physical storage structures in relational database engines that govern how data rows are stored and retrieved. |
| 52 | **Columnstore Indexes** | `🔴 Advanced` | An index technology that stores and compresses data in a column-oriented format on disk. |
| 53 | **COUNT(*) vs COUNT(1): Optimizer Equivalence & Semantics** | `🔴 Advanced` | The comparison between full-table tuple counting and scalar expression counting in SQL query engines. |
| 54 | **Covering Indexes & Included Columns (INCLUDE)** | `🔴 Advanced` | An indexing design pattern where a non-clustered index contains all columns referenced by a query, completely eliminating Key/Bookmark Lookups. |
| 55 | **Database Triggers & Hidden Transaction Side Effects** | `🔴 Advanced` | Event-driven procedural routines executed automatically by the database engine in response to DML operations on a table. |
| 56 | **Deadlocks** | `🔴 Advanced` | A locking contention scenario where two transactions block each other by holding locks on resources the other requires. |
| 57 | **Deadlocks, Blocking & Concurrency Control** | `🔴 Advanced` | A concurrency collision where two or more database sessions hold locks on separate resources while each requests an exclusive lock on the resource held by the other, forming a cyclic dependency. |
| 58 | **Gaps & Islands Consecutive Sequence Analysis** | `🔴 Advanced` | The Gaps and Islands problem is a classical SQL analytical challenge that involves identifying contiguous sequences of records (islands) and missing intervals (gaps) in sequential data. |
| 59 | **GROUPING SETS, CUBE & ROLLUP Multidimensional Aggregations** | `🔴 Advanced` | Advanced aggregation extensions that compute multiple distinct group-by sub-aggregations across multiple dimensional levels in a single scan of the source data. |
| 60 | **MERGE Statement Concurrency Pitfalls & Atomic Upserts** | `🔴 Advanced` | A standard SQL DML command that synchronizes target tables with source data by combining INSERT, UPDATE, and DELETE logic into a single statement. |
| 61 | **Non-Splittable Compression & Multiline Record Bottlenecks** | `🔴 Advanced` | The serialization choke point where compressed text files cannot be split, forcing a distributed cluster down to a single core. |
| 62 | **NULLs in CHECK Constraints Are Truthy** | `🔴 Advanced` | The surprising relational behavior where a CHECK constraint allows an insert or update if the constraint expression evaluates to UNKNOWN (NULL). |
| 63 | **Parameter Sniffing** | `🔴 Advanced` | A database engine compilation behavior where a query plan is optimized based on the parameters passed during first execution. |
| 64 | **Parameter Sniffing & OPTIMIZE FOR Query Hints** | `🔴 Advanced` | Query plan cache degradation where a plan compiled for an outlier parameter value causes catastrophic performance on normal values. |
| 65 | **Parameter Sniffing & Query Plan Cache Mechanics** | `🔴 Advanced` | A database optimizer behavior where a query plan is compiled and cached using parameter values from its initial invocation, leading to severe performance degradation on subsequent runs with different data distributions. |
| 66 | **Partial & Filtered Indexes** | `🔴 Advanced` | A B-Tree index built over a subset of a table's rows defined by an explicit predicate (e.g. WHERE active = true or WHERE status != 'ARCHIVED'). |
| 67 | **Query Optimizer Plan Hints: Force Order & Index Directives** | `🔴 Advanced` | Explicit syntax directives embedded in SQL queries that override cost-based optimizer choices regarding joins, indexes, or parallelism. |
| 68 | **Read Committed Snapshot Isolation** | `🔴 Advanced` | A database setting that uses row versioning in TempDB to prevent read operations from blocking write operations. |
| 69 | **Read Committed Snapshot Isolation (RCSI)** | `🔴 Advanced` | RCSI is an optimistic concurrency model in Microsoft SQL Server that uses row versioning in TempDB to allow readers to access committed row versions without acquiring shared locks. |
| 70 | **Sargability & Search Argument Able Predicates** | `🔴 Advanced` | The property of a query predicate that allows the query optimizer to utilize a B-Tree index seek rather than an index scan or table scan. |
| 71 | **SARGability (Search Argument Able)** | `🔴 Advanced` | The property of a query predicate that enables the optimizer to execute an index seek across a B-Tree rather than falling back to an exhaustive index or table scan. |
| 72 | **SELECT FOR UPDATE & Concurrency Control (SKIP LOCKED / NOWAIT)** | `🔴 Advanced` | A pessimistic locking clause that acquires exclusive or update row locks on selected records to prevent concurrent modification until transaction commit. |
| 73 | **SQL Dynamic Management Views: sys.dm_exec_sessions and queryinsights** | `🔴 Advanced` | Real-time system catalog views and Fabric performance schemas used by DBAs and data architects to isolate active user sessions, running query statements, and resource bottlenecks. |
| 74 | **SQL Server Columnstore Batch Mode Execution** | `🔴 Advanced` | A relational database execution engine that processes rows in columnar batches of ~900 rows at a time using CPU hardware registers rather than row-by-row iteration. |
| 75 | **SQL Server Error 1205 Deadlock Resolution** | `🔴 Advanced` | A SQL Server Error 1205 deadlock occurs when two or more concurrent transactions hold locks on separate resources and each requests a lock on the other's resource, creating a cyclic dependency. |
| 76 | **SQL Window Frame Specifications (ROWS vs. RANGE)** | `🔴 Advanced` | Window frame specifications define the exact subset of rows within a partition evaluated by an analytic or aggregate window function using physical row counts (ROWS) or logical value offsets (RANGE). |
| 77 | **Synapse MPP Resource Classes & Columnstore Compression RAM** | `🔴 Advanced` | Workload management memory allocations required to prevent Clustered Columnstore row group spilling to TempDB during bulk loads. |
| 78 | **TempDB Allocation Map Contention** | `🔴 Advanced` | Concurrency bottlenecks on PFS and SGAM pages in TempDB caused by simultaneous table creation across multiple threads. |
| 79 | **TempDB Contention** | `🔴 Advanced` | A performance bottleneck caused by allocation page concurrency bottlenecks inside the TempDB database files. |
| 80 | **UTF-8 Byte Order Mark (BOM) & Header Alignment Corruption** | `🔴 Advanced` | Hidden 3-byte prefixes (0xEF, 0xBB, 0xBF) in Windows-generated text files that break column 1 mapping in relational bulk loaders. |
| 81 | **Window Frame Specification: ROWS vs. RANGE** | `🔴 Advanced` | The sub-clause within OVER() that defines the physical or logical boundary of rows evaluated relative to the current row. |
| 82 | **Always On Availability Groups Multi-Subnet Disaster Recovery** | `🟣 Architect` | Enterprise database clustering architecture providing zero-data-loss synchronous local commit and cross-region asynchronous disaster recovery with automated client failover. |
| 83 | **Always On Availability Groups Quorum** | `🟣 Architect` | High-availability and disaster recovery architecture using Windows Server Failover Clustering quorum and synchronous replication. |
| 84 | **Cardinality Estimation Feedback & IQP** | `🟣 Architect` | Cardinality Estimation (CE) Feedback is an Intelligent Query Processing (IQP) mechanism in SQL Server 2022 that automatically identifies and corrects plan regressions caused by modern CE assumptions. |
| 85 | **Columnstore Segment Elimination & Memory Grant Governance** | `🟣 Architect` | Low-level columnar storage engine optimization governing rowgroup health, min/max metadata dictionary pruning, and query memory grants. |
| 86 | **Fabric Direct Lake Mode: Zero-ETL VertiPaq Paging** | `🟣 Architect` | A semantic layer breakthrough where Power BI's in-memory VertiPaq engine directly memory-maps Delta Parquet columns from OneLake. |
| 87 | **Partition Switching & Staging Architecture for High-Volume Ingestion** | `🟣 Architect` | Metadata-only table partition modification enabling millions of ingested rows to be swapped into a production table in under 10 milliseconds with zero write locks. |
| 88 | **Petabyte-Scale Staged Ingestion & Partition Switching** | `🟣 Architect` | An enterprise MPP ingestion architecture utilizing unindexed round-robin heap staging, CTAS, and atomic partition metadata swaps. |
| 89 | **Physical Join Algorithms: Nested Loops, Merge, and Hash Joins** | `🟣 Architect` | The three physical execution operators employed by cost-based query optimizers to combine two data streams. |
| 90 | **Temporal Tables & Point-In-Time Bi-Temporal Auditing** | `🟣 Architect` | System-versioned relational table architecture automatically recording the full history of data modifications with UTC period start/end timestamps. |
| 91 | **The Halloween Problem & Mutation Spooling** | `🟣 Architect` | The Halloween Problem is a relational engine anomaly where an UPDATE operation modifies an indexed column used to locate qualifying rows, causing the query to repeatedly visit and update the same rows. |

### 🏛️ Database Architecture, Distributed Sharding & Cloud MPP
*B-Tree vs LSM trees, MVCC, distributed consensus (Raft/Paxos), and cloud MPP engines.*

**Total Topics**: 79

| # | Topic / Concept | Difficulty | Architectural Definition & Core Principle |
|:---:|---|:---:|---|
| 1 | **Database Sharding Topologies & Live Dynamic Re-sharding** | `🟢 Easy` | Techniques for horizontally partitioning database tables across independent physical nodes and dynamically splitting shards in production with zero application downtime. |
| 2 | **High Cardinality** | `🟢 Easy` | Column with many distinct values (like CustomerID with millions of unique customers). |
| 3 | **Low Cardinality** | `🟢 Easy` | Column with few distinct values (like ProductCategory with only 15 categories). |
| 4 | **OLAP (Online Analytical Processing)** | `🟢 Easy` | Workload pattern focused on complex queries, aggregations, and read-heavy analytics. |
| 5 | **OLTP (Online Transaction Processing)** | `🟢 Easy` | Workload pattern focused on transactional operations with frequent inserts, updates, and deletes. |
| 6 | **Rowstore Index** | `🟢 Easy` | Traditional row-based storage optimized for OLTP workloads with frequent inserts, updates, and single-row lookups. |
| 7 | **ACID Properties & Physical Engine Enforcements** | `🟡 Intermediate` | The four foundational guarantees—Atomicity, Consistency, Isolation, and Durability—enforced via low-level engine subsystems. |
| 8 | **Attribute-Based Dynamic Column Masking (ABAC)** | `🟡 Intermediate` | A runtime security policy engine that evaluates user attributes (role, department, clearance) to conditionally mask, hash, or redact sensitive column values without duplicating tables. |
| 9 | **Columnstore Index** | `🟡 Intermediate` | A storage structure that organizes data by columns rather than rows, optimized for analytical queries that scan large datasets. |
| 10 | **Connection Pools & Thread/Process Multiplexing** | `🟡 Intermediate` | A persistent cache of open database connections that multiplexes high-volume client application requests over a fixed pool of server backends. |
| 11 | **Database Backpressure & Concurrency Admission Control** | `🟡 Intermediate` | Flow-control and overload-shedding mechanisms that regulate query ingress, enforcing Little's Law to prevent database CPU thrashing, memory exhaustion, and cascading collapse. |
| 12 | **Database Branching & Copy-on-Write CoW Virtual Forks** | `🟡 Intermediate` | A Git-like database lifecycle capability that instantly provisions isolated, fully functional database clones in seconds using Copy-on-Write pointer manipulation without duplicating physical data. |
| 13 | **Database Connection Pooling (PgBouncer)** | `🟡 Intermediate` | Maintaining an in-memory pool of reusable database connections to eliminate per-request connection handshake latency. |
| 14 | **Database Transactions & Two-Phase Commit (2PC)** | `🟡 Intermediate` | A consensus protocol ensuring atomic commit or rollback across multiple distributed database instances or heterogeneous resources. |
| 15 | **Dictionary Encoding** | `🟡 Intermediate` | Compression technique that replaces repeating values with smaller numeric identifiers and stores a lookup dictionary. |
| 16 | **Inverted Indexes (GIN & Full-Text Search)** | `🟡 Intermediate` | An indexing structure that maps discrete elements (such as tokens, tags, or JSON keys) to sorted posting lists of containing document/row IDs. |
| 17 | **ORM Query Degradation & N+1 Cascade Problem** | `🟡 Intermediate` | The systemic performance degradation that occurs when object-relational mapping frameworks generate chatty, unindexed, or Cartesian queries. |
| 18 | **Query Plans & EXPLAIN ANALYZE Mechanics** | `🟡 Intermediate` | The tree of relational operators generated by the cost-based optimizer detailing physical access paths, join algorithms, and actual execution metrics. |
| 19 | **Relational Normal Forms (1NF through 5NF & BCNF)** | `🟡 Intermediate` | A mathematical progression of design rules based on functional dependencies designed to eliminate data redundancy and update anomalies. |
| 20 | **Run-Length Encoding (RLE)** | `🟡 Intermediate` | Compression method that stores consecutive identical values as a single value with a count. |
| 21 | **Segment Elimination** | `🟡 Intermediate` | Performance optimization where columnstore skips reading irrelevant data segments based on min/max statistics. |
| 22 | **Storage Engine Trade-offs: LSM-Trees vs B+Trees & Compaction Dynamics** | `🟡 Intermediate` | The foundational architectural trade-offs between write-optimized Log-Structured Merge Trees (LSM) and read-optimized B+Tree storage engines in modern database design. |
| 23 | **The DUAL Table & Relational Projection Semantics** | `🟡 Intermediate` | A special single-row dummy table used in SQL engines (historically Oracle and MySQL) to evaluate scalar expressions within relational SELECT syntax. |
| 24 | **Ambiguous Network Errors & Two-Generals Commit Dilemma** | `🔴 Advanced` | The distributed systems dilemma where a network socket drops during a COMMIT operation, leaving the client in an indeterminate transactional state. |
| 25 | **Ascending Key Problem in B-Trees** | `🔴 Advanced` | The severe concurrency and optimizer degradation that occurs when high-volume inserts target monotonically increasing primary keys. |
| 26 | **Batch Mode Processing** | `🔴 Advanced` | Query execution method that processes multiple rows simultaneously, available with columnstore indexes. |
| 27 | **Bit-Packing** | `🔴 Advanced` | Compression technique that uses minimum number of bits required to represent numerical values. |
| 28 | **Cost-Based Optimizers & Table Statistics Histograms** | `🔴 Advanced` | Statistical metadata describing column value distributions, null fractions, and density vectors used by optimizers to estimate query plan costs. |
| 29 | **Database Sharding & Distributed Hash Routing** | `🔴 Advanced` | A shared-nothing horizontal scaling architecture where a large relational dataset is partitioned across independent physical database instances via a shard key. |
| 30 | **Database Traffic Control: Read-After-Write Consistency & GTID Pinning** | `🔴 Advanced` | Routing architectures that decouple reads and writes across replicas while tracking Global Transaction Identifiers (GTIDs) to eliminate replication lag anomalies. |
| 31 | **Deploy Requests & Zero-Downtime Online Schema Migrations with gh-ost** | `🔴 Advanced` | An asynchronous schema migration methodology that modifies large tables without locking DDL, using shadow tables, continuous CDC binlog stream catchup, and atomic cutovers. |
| 32 | **MVCC Garbage Collection & Table Bloat (VACUUM / Undo Purge)** | `🔴 Advanced` | The internal storage engine processes responsible for reclaiming physical disk space occupied by obsolete, dead row versions under MVCC. |
| 33 | **MySQL utf8 Truncation Bug vs utf8mb4** | `🔴 Advanced` | The notorious legacy encoding issue in MySQL where the 'utf8' charset supported only 3 bytes, causing silent data truncation on modern 4-byte Unicode characters. |
| 34 | **PAGE Compression** | `🔴 Advanced` | Row-level compression technique that removes repetitive data within database pages, used in rowstore scenarios. |
| 35 | **Phantom Reads & Next-Key Locking** | `🔴 Advanced` | A concurrency anomaly where a transaction reads a set of rows satisfying a predicate, but a concurrent committed transaction inserts a new row matching that predicate. |
| 36 | **PostgreSQL BRIN (Block Range Index)** | `🔴 Advanced` | An index storing minimum and maximum values for physical disk block ranges, delivering compact indexing on ordered tables. |
| 37 | **PostgreSQL MVCC Table Bloat & VACUUM** | `🔴 Advanced` | Multi-Version Concurrency Control dead tuple accumulation and automated background vacuuming mechanics. |
| 38 | **Quorum Consensus & Redundancy: Multi-Raft, Paxos & Witness Nodes** | `🔴 Advanced` | Distributed consensus algorithms that guarantee fault-tolerant state machine replication across independent nodes through majority voting quorums. |
| 39 | **Read-Replica Replication Lag Mitigation** | `🔴 Advanced` | Architectural patterns preventing stale reads when distributing read traffic across asynchronous database replicas. |
| 40 | **Relational Denormalization Strategies** | `🔴 Advanced` | The intentional reintroduction of redundant data into a relational schema to optimize read latency and eliminate expensive multi-table joins. |
| 41 | **Serializable Restarts & SQLSTATE 40001 Retry Loops** | `🔴 Advanced` | The architectural requirement that applications executing under Serializable Snapshot Isolation must wrap all transactions in retry loops to handle serialization failures. |
| 42 | **Set-Returning Generator Functions & Cross Join Alignment** | `🔴 Advanced` | The distinct behavior of set-returning functions (SRFs) in SQL engines, contrasting row-wise zipping with Cartesian expansion. |
| 43 | **Star Schema vs Normalized 3NF Relational Engines** | `🔴 Advanced` | The architectural contrast between highly normalized 3NF schemas optimized for transactional write isolation and denormalized star schemas optimized for analytical OLAP scans. |
| 44 | **There Are No Non-Nullable Types in SQL** | `🔴 Advanced` | The relational truth that column-level NOT NULL constraints do not guarantee non-nullability across expressions, outer joins, and aggregations. |
| 45 | **TIMESTAMPTZ Does Not Store a Time Zone** | `🔴 Advanced` | The common misconception in PostgreSQL and relational standards regarding how timezone-aware timestamps are physically stored on disk. |
| 46 | **Transaction Contention, Latch Waits & Hotspots** | `🔴 Advanced` | The serialization bottleneck caused by concurrent sessions competing for identical logical row locks or physical in-memory page latches. |
| 47 | **Transaction Isolation Levels & Concurrency Anomalies** | `🔴 Advanced` | The formal ANSI/ISO standards defining transaction boundary guarantees and the specific concurrency anomalies each level permits or prohibits. |
| 48 | **Write Skew Anomaly in Snapshot Isolation** | `🔴 Advanced` | A subtle concurrency anomaly occurring under Snapshot Isolation where two concurrent transactions read overlapping data but modify disjoint rows, violating an invariant. |
| 49 | **Zigzag Join (Multi-Index Merge Intersection)** | `🔴 Advanced` | An advanced physical query optimization algorithm that finds matching rows across multiple B-Tree indexes by jumping back and forth across sorted leaf keys. |
| 50 | **'null'::jsonb IS NULL Evaluates to False** | `🟣 Architect` | The semantic distinction in PostgreSQL between a JSON-encoded null primitive and a relational SQL NULL value. |
| 51 | **Azure Data Explorer (ADX) vs Azure Synapse Analytics Workload Selection** | `🟣 Architect` | Architectural decision criteria for selecting between indexing-optimized real-time telemetry exploration (ADX/KQL) and massively parallel relational data warehousing (Synapse/Fabric Warehouse). |
| 52 | **Azure Synapse Resource Classes (Static vs. Dynamic)** | `🟣 Architect` | Pre-determined resource limits and memory allocation governance profiles assigned to database roles in Azure Synapse to control query memory grants and concurrency. |
| 53 | **Azure Synapse Table Distributions (Hash, Round-Robin, Replicated)** | `🟣 Architect` | The architectural data distribution strategies across 60 fixed storage buckets that govern data movement and query parallelization in Azure Synapse dedicated SQL pools. |
| 54 | **Causal Reverse Anomaly in Asynchronous Replication** | `🟣 Architect` | A distributed consistency anomaly where an effect appears to precede its cause in replica read logs due to asynchronous replication delays or clock skew. |
| 55 | **Compute & Storage Decoupling: Log-is-the-Database Paradigm** | `🟣 Architect` | A cloud-native database architecture where stateless SQL execution engines are separated from a distributed, purpose-built write-ahead log (WAL) storage tier. |
| 56 | **Cost Models vs Physical Hardware Reality** | `🟣 Architect` | The systemic divergence between static relational query optimizer cost formulas and the physical realities of modern hardware (NVMe SSDs, tiered memory, and CPU caches). |
| 57 | **Database Cracking & Self-Organizing Adaptive Indexing** | `🟣 Architect` | An autonomous physical indexing architecture where queries adaptively partition and sort columns on-the-fly as a side-effect of query execution. |
| 58 | **DEFERRABLE INITIALLY IMMEDIATE Constraints** | `🟣 Architect` | A relational constraint configuration that allows integrity checks (such as foreign keys or unique constraints) to be postponed until transaction commit. |
| 59 | **Distributed Two-Phase Commit & Cross-Shard Transaction Latency** | `🟣 Architect` | The distributed consensus protocol used to guarantee atomic transactions across multiple database shards, and the inherent latency and locking bottlenecks it introduces. |
| 60 | **Every SQL Operator as a Relational Join** | `🟣 Architect` | The theoretical mathematical proof in relational algebra demonstrating that Selection, Projection, Union, and Intersection can be expressed as joins. |
| 61 | **EXPLAIN Catalog Approximations for Row Counts** | `🟣 Architect` | A technique that retrieves sub-millisecond approximate table row counts by inspecting system catalog metadata instead of executing full table scans. |
| 62 | **Fsyncgate: Linux Kernel Page Cache Error Dropping** | `🟣 Architect` | The critical 2018 discovery where the Linux kernel cleared dirty page flags upon writeback I/O error, causing subsequent fsync calls to falsely report success. |
| 63 | **Join Ordering Complexity (NP-Hard Search Space)** | `🟣 Architect` | The combinatorial explosion of possible join order permutations that makes finding the mathematically optimal query plan an NP-hard problem. |
| 64 | **Learned Index Structures (Recursive Model Indexes / RMI)** | `🟣 Architect` | The machine learning paradigm pioneered by Kraska et al. that replaces traditional B-Trees with recursive functional regression models to predict key positions. |
| 65 | **MATCH PARTIAL Composite Foreign Key Semantics** | `🟣 Architect` | An esoteric SQL standard rule for composite foreign keys that specifies validation behavior when only a subset of composite key columns contain NULL. |
| 66 | **NULL Equality in DISTINCT vs UNIQUE Constraints** | `🟣 Architect` | The formal divergence in SQL standard specifications where DISTINCT treats NULLs as identical duplicates, while UNIQUE constraints treat them as distinct. |
| 67 | **Relational NULL & Codd's Missing Information Foundations** | `🟣 Architect` | The formal mathematical critique of NULL in relational theory and E.F. Codd's distinction between 'Value Unknown' and 'Value Inapplicable'. |
| 68 | **SERIAL & Sequence Generation Non-Transactional Gaps** | `🟣 Architect` | The deliberate non-transactional design of database sequence generators (SERIAL, IDENTITY, SEQUENCE) that produce permanent gaps upon rollback. |
| 69 | **Slowly Changing Dimension (SCD) Type 2 in Microsoft Fabric** | `🟣 Architect` | The dimensional modeling pattern that maintains a complete history of attribute modifications by creating versioned records with validity timestamps and active flags using Delta Lake MERGE. |
| 70 | **TABLE_DEE and TABLE_DUM Relational Identities** | `🟣 Architect` | The two fundamental identity relations in formal relational theory (Date & Darwen) possessing zero attributes, representing boolean TRUE and FALSE. |
| 71 | **The 'allballs' Time Literal in PostgreSQL** | `🟣 Architect` | A historical, quirky reserved string literal in PostgreSQL that parses into '00:00:00.00' UTC time (all zeroes). |
| 72 | **The Halloween Problem & Update Mutation Scanning** | `🟣 Architect` | A database mutation phenomenon where an UPDATE operation modifies an indexed column, causing modified rows to advance forward and be mutated repeatedly. |
| 73 | **TPC-C Benchmark Specification & Artificial Keying Times** | `🟣 Architect` | The mandatory simulation of human interactive delay (keying and think times) codified in the TPC-C benchmark standard. |
| 74 | **Transaction ID (XTID) Exhaustion & Wraparound Emergency** | `🟣 Architect` | The catastrophic scenario in 32-bit MVCC engines where transaction counter limits threaten to treat all historical data as invisible, forcing database shutdown. |
| 75 | **Transaction Isolation Levels: Snapshot Isolation, SSI & Linearizability** | `🟣 Architect` | The spectrum of transactional safety guarantees in distributed databases, spanning Read Committed, Snapshot Isolation, Serializable SSI, and External Consistency (Linearizability). |
| 76 | **Vectorized Execution vs Hardware SIMD Vectorization** | `🟣 Architect` | The distinction between block-oriented tuple-at-a-time engine pipelines and hardware-level CPU SIMD vector register instructions. |
| 77 | **Vitess Architecture & VSchema Declarative Sharding** | `🟣 Architect` | A cloud-native horizontal database scaling engine for MySQL that abstracts sharded storage behind stateless query proxies (VTGate) governed by declarative JSON schemas (VSchema). |
| 78 | **Volcano Iterator Execution Model & Cache Misses** | `🟣 Architect` | The classical demand-driven query execution model where operators implement an open()-next()-close() iterator interface pulling one tuple at a time. |
| 79 | **Worst-Case Optimal Joins (WCOJ) & Leapfrog Triejoin** | `🟣 Architect` | A class of multiway join algorithms whose runtime is asymptotically bounded by the Atserias-Grohe-Marx (AGM) bound, bypassing binary join bottlenecks. |

---

## 📐 Related Whiteboard Blueprints
For deep visual architecture walkthroughs of these topics, consult:
- 🖼️ [Master Whiteboard Blueprints](../docs/whiteboard_diagrams/handbook_whiteboard_blueprints.md)
- 📊 [Spark Catalyst & Architecture Cheatsheet](../assets/whiteboards/spark_architecture_catalyst_cheatsheet.jpg)
- 🔀 [Join Strategies Decision Matrix](../assets/whiteboards/spark_join_strategies_decision_matrix.jpg)
- ⚡ [Skew & Spill Memory Triage](../assets/whiteboards/spark_performance_skew_spill_triage.jpg)

---

## 🌐 Ecosystem Interlinking
All curriculum topics are synchronized across the 14-repository Modern Data Engineering ecosystem:
- [Modern Data Engineer Hub](https://github.com/santoshjammi29/moderndataengineer) — Central edge web platform and 921-topic encyclopedia
- [PySpark Handbook](https://github.com/santoshjammi29/pyspark-handbook) — Distributed compute & PySpark internals
- [Databricks Handbook](https://github.com/santoshjammi29/databricks-handbook) — Unity Catalog, Delta Lake 3.x, and Lakeflow
- [SQL Handbook](https://github.com/santoshjammi29/sql-handbook) — Query engine optimization & relational internals
- [Streaming Handbook](https://github.com/santoshjammi29/streaming-handbook) — Event streaming, Kafka, and Flink
- [Security Handbook](https://github.com/santoshjammi29/security-handbook) — Zero-trust, IAM, and lakehouse governance
- [Data System Design Handbook](https://github.com/santoshjammi29/data-system-design-handbook) — Distributed architecture and scalability
- [DataOps & CI/CD Handbook](https://github.com/santoshjammi29/dataops-cicd-handbook) — Airflow, orchestration, and infrastructure
- [dbt Handbook](https://github.com/santoshjammi29/dbt-handbook) — Analytics engineering, contracts, and modeling
- [Azure Cheat Sheet](https://github.com/santoshjammi29/azure-cheat-sheet) — Fabric, OneLake, and ADF enterprise blueprints
- [Data Engineering Interview Handbook](https://github.com/santoshjammi29/data-engineering-interview-handbook) — 20 Knowledge Pillars & architectural defense
