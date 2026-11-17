#!/usr/bin/env python3
"""
Builds the flagship README.md for The SQL Handbook.
"""

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
CURRICULUM_FILE = BASE_DIR / "scripts" / "curriculum_matrix.md"
README_FILE = BASE_DIR / "README.md"

def build_readme():
    curriculum_md = CURRICULUM_FILE.read_text(encoding="utf-8")

    header = """# ⚡ The SQL Handbook

**105 Production Coding Use Cases, Query Optimization Recipes, MPP Architectures & Incident Runbooks**

[![CI Validation](https://github.com/santoshjammi29/sql-handbook/actions/workflows/ci.yml/badge.svg)](https://github.com/santoshjammi29/sql-handbook/actions)
[![SQL Standard](https://img.shields.io/badge/SQL-ANSI_SQL%3A2023-blue?style=flat-square&logo=postgresql&logoColor=white)](https://www.iso.org/standard/76583.html)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16%2B-336791?style=flat-square&logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![DuckDB](https://img.shields.io/badge/DuckDB-1.0%2B_OLAP-FFF000?style=flat-square&logo=duckdb&logoColor=black)](https://duckdb.org/)
[![Databricks](https://img.shields.io/badge/Databricks-Spark_SQL_3.5%2B-FF3621?style=flat-square&logo=databricks&logoColor=white)](https://www.databricks.com/)
[![Snowflake](https://img.shields.io/badge/Snowflake-Cloud_DWH-29B5E8?style=flat-square&logo=snowflake&logoColor=white)](https://www.snowflake.com/)
[![BigQuery](https://img.shields.io/badge/Google_BigQuery-Serverless_MPP-4285F4?style=flat-square&logo=googlecloud&logoColor=white)](https://cloud.google.com/bigquery)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

*The definitive enterprise reference repository of 105 battle-tested SQL coding exercises, performance tuning recipes, and disaster recovery incident runbooks.*  
*Structured for instant local practice via Python's built-in `sqlite3` and `duckdb`, with zero external infrastructure required.*

[Curriculum Overview](#-curriculum-overview) • [Logical Query Architecture](#-logical-query-architecture) • [Quickstart & Sandbox](#-quickstart--interactive-sandbox) • [Interview Matrix](#-4-tier-interview-preparation-matrix) • [Production Runbooks](#-battle-tested-production-runbooks) • [Incident Postmortems](#-production-incident-postmortems)

---

## 🎯 Overview & Mission

Modern data engineering and analytics engineering demand far more than basic `SELECT * FROM table WHERE condition`. 

Enterprise workloads operate on high-concurrency transactional databases (PostgreSQL, Aurora, SQL Server) and distributed lakehouse MPP engines (Snowflake, Databricks Spark SQL, Google BigQuery) where a single non-SARGable predicate, missing index, or skewed join key can exhaust cluster memory, trigger multi-hour straggler tasks, or cause 10,000 USD cloud billing surprises.

This repository provides **105 end-to-end, runnable, modular SQL coding use cases** covering:
- **Core & Advanced Relational Fundamentals:** Logical execution order, Three-Valued Logic (3VL), SARGability, cascading integrity, and safe numeric precision.
- **Complex Joins & Aggregations:** Semi-joins (`EXISTS`), anti-joins, full outer reconciliations, non-equi joins, multidimensional `ROLLUP`/`CUBE`, and dynamic pivoting.
- **Analytical Window Functions Mastery:** Ranking with ties, lead/lag offsets, sliding frames (`ROWS` vs. `RANGE`), Gaps and Islands (consecutive streaks & sessionization), and portfolio drawdowns.
- **Hierarchical Trees & Graph Traversal:** Recursive Common Table Expressions (`WITH RECURSIVE`) for organizational charts, Bill of Materials (BOM) part explosions, flight path cycle detection, and calendar spines.
- **Data Modeling & Lakehouse Formats:** Kimball star schemas, Slowly Changing Dimensions (SCD Types 1, 2, 3, 4, 6), Data Vault 2.0 (Hubs/Links/Satellites), and deterministic hash surrogate keys.
- **Storage Engines & Physical Optimization:** B-Tree index traversal, composite index left-prefix rule, covering indexes, partial/filtered indexes, join algorithms, and cardinality estimation tuning.
- **Transactions, MVCC & Concurrency Control:** ACID savepoints, isolation levels (Read Committed, Repeatable Read, Serializable), write skew anomalies, MVCC tuple lifecycles, and deadlock-free canonical resource ordering.
- **MPP Distributed Engines & Big Data SQL:** Snowflake micro-partition pruning, table distributions (Hash/Replicated), Liquid Clustering (`CLUSTER BY`), two-phase key salting for join skew, and multi-condition `MERGE INTO`.
- **Production Incidents & Disaster Postmortems:** 10 real-world production postmortems with forensic analysis and surgical recovery queries (the 99% straggler task, deadlock storms, out-of-order CDC corruption, and automated data quality test suites).

---

## 🏛️ Logical Query Architecture

Understanding the discrepancy between **syntax order** and **logical execution order** is the foundation of SQL mastery:

```mermaid
flowchart TD
    Step1["1. FROM & JOINs (Table access, Cartesian products & ON predicates)"] --> Step2["2. WHERE (Row-level predicate filtering before aggregation)"]
    Step2 --> Step3["3. GROUP BY (Hash table bucketing across dimensions)"]
    Step3 --> Step4["4. HAVING (Filtering aggregated summary buckets)"]
    Step4 --> Step5["5. WINDOW FUNCTIONS (ROW_NUMBER, RANK, LAG, LEAD, SUM OVER)"]
    Step5 --> Step6["6. SELECT (Projection, Scalar expressions, Aliasing)"]
    Step6 --> Step7["7. DISTINCT (Duplicate tuple elimination across projected columns)"]
    Step7 --> Step8["8. SET OPERATIONS (UNION, INTERSECT, EXCEPT)"]
    Step8 --> Step9["9. ORDER BY (Sorting output rows using projected columns/aliases)"]
    Step9 --> Step10["10. LIMIT / OFFSET / TOP (Result set truncation & pagination)"]
```

---

## 🚀 Quickstart & Interactive Sandbox

All 105 exercises are **100% self-contained** and executable locally using Python's standard library with zero external dependencies!

### 1. Clone & Verify Installation
```bash
git clone https://github.com/santoshjammi29/sql-handbook.git
cd sql-handbook
```

### 2. Run the Full Automated Test Suite (105 Exercises in < 1 Second)
```bash
python scripts/run_all_exercises.py
```

### 3. Open Any Problem in the Interactive SQL REPL
Practice queries against pre-seeded in-memory databases with instant feedback:

```bash
# Load Exercise 038: Gaps and Islands Login Streaks
python scripts/interactive_shell.py 038

# Load Exercise 090: Distributed Key Salting for Skewed Joins
python scripts/interactive_shell.py 090
```

Inside the interactive shell:
- Inspect schemas and test datasets with standard SQL queries (`SELECT * FROM player_logins;`).
- Type `.solution` to inspect the battle-tested reference answer.
- Type `exit` to return to your terminal.

---

## 📚 Master Curriculum Map

This curriculum spans **10 structured modules** encompassing foundational syntax through Staff Data Architect production triage:

```mermaid
mindmap
  root((The SQL Handbook))
    01 Fundamentals
      Execution Order
      Three-Valued Logic
      SARGability
      Safe Casting
      Idempotent DDL
    02 Joins & Sets
      Semi-Joins EXISTS
      Anti-Joins
      Full Outer Recon
      Non-Equi Ranges
      Lateral / Apply
    03 Aggregations
      Count Semantics
      Filtered Aggregates
      OLAP ROLLUP
      OLAP CUBE
      Dynamic Pivoting
    04 Window Functions
      Ranking with Ties
      Offset LAG / LEAD
      Sliding Frames
      Gaps & Islands
      Cohort Retention
    05 Recursive CTEs
      Org Hierarchies
      BOM Part Explosion
      Graph Shortest Path
      Calendar Spines
      Duplicate Deletion
    06 Data Modeling
      Kimball Star Schema
      SCD Types 1-6
      Data Vault 2.0
      Bridge Tables
      Surrogate Hashes
    07 Query Optimization
      B-Tree Index Seek
      Composite Prefix Rule
      Covering Indexes
      Cardinality Stats
      Join Algorithms
    08 Transactions
      ACID Savepoints
      Isolation Anomalies
      Write Skew
      MVCC Internals
      Deadlock Ordering
    09 MPP Distributed
      Micro-Partitioning
      Hash Distributions
      Liquid Clustering
      Key Salting
      Delta MERGE
    10 Incident Triage
      99% Straggler Skew
      Deadlock Storms
      CDC Timeline Repair
      TempDB Cartesian
      Data Quality Suite
```

---

## 📂 Detailed Exercises & Code Matrix

> **Dialect Portability**: All 105 exercises are written in standard ANSI SQL and verified to execute natively on **PostgreSQL**, **DuckDB**, **Databricks Spark SQL**, **Snowflake**, **Google BigQuery**, and **SQLite**.
"""

    footer = """
---

## 🚨 Battle-Tested Production Runbooks

The repository includes enterprise-grade operational runbooks for production incident response:

| Runbook | Title | Critical Failure Mode Addressed |
| :--- | :--- | :--- |
| **[Runbook 01](runbooks/01_deadlock_and_lock_contention_triage.md)** | **Deadlock & Lock Contention Emergency Triage** | Application 504 pool exhaustion, Error 1205, locking tree identification, canonical key ordering. |
| **[Runbook 02](runbooks/02_query_performance_and_execution_plan_tuning.md)** | **Query Performance & Execution Plan Tuning** | Non-SARGable functions, index scan vs seek, cardinality estimation drift, parameter sniffing. |
| **[Runbook 03](runbooks/03_mpp_skew_spill_and_broadcast_failures.md)** | **MPP Skew, Memory Spill & Broadcast Failures** | 99% straggler tasks, Tungsten disk spill, Snowflake remote storage spill, two-phase key salting. |
| **[Runbook 04](runbooks/04_scd_and_cdc_reconciliation_disaster_recovery.md)** | **SCD Type 2 & CDC Reconciliation Disaster Recovery** | Out-of-order Kafka CDC events, duplicate active records (`is_current = true`), self-healing queries. |
| **[Runbook 05](runbooks/05_cross_engine_rosetta_stone.md)** | **Cross-Engine SQL Rosetta Stone** | Syntax comparison across PostgreSQL, DuckDB, Spark SQL, Snowflake, BigQuery, and T-SQL. |
| **[Runbook 06](runbooks/06_finops_and_warehouse_cost_optimization.md)** | **FinOps & Cloud Warehouse Cost Optimization** | Snowflake auto-suspend, BigQuery scan reduction (6.25 USD per TB), Databricks serverless rightsizing. |

---

## 🎓 4-Tier Interview Preparation Matrix

Prepare for technical coding screens from Junior Analyst to Principal Lakehouse Architect:

1. **[Tier 1: Junior Analyst & Data Engineer (Foundations)](interview/01_junior_analyst_and_data_engineer.md)**: Execution order, `COUNT` semantics, `WHERE` vs `HAVING`, 3VL logic, `UNION` vs `UNION ALL`.
2. **[Tier 2: Mid-Level Data Engineer (Analytical Mastery)](interview/02_mid_level_data_engineer.md)**: Ranking functions, Gaps & Islands streaks, duplicate deletion, binary tree node classification, query SARGability.
3. **[Tier 3: Senior Distributed Data Engineer (Distributed Systems & Performance)](interview/03_senior_distributed_data_engineer.md)**: The 5 S's of Spark SQL tuning, SCD Types 1-6, Snowflake micro-partitions, two-phase key salting, deadlock prevention.
4. **[Tier 4: Staff & Lakehouse Architect (System Design & Governance)](interview/04_staff_and_lakehouse_architect.md)**: Kimball vs Data Vault 2.0, Liquid Clustering internals, Delta Lake transaction log, Power BI Direct Lake mode.
5. **[50-Card Rapid-Fire Technical Flashcard Deck](interview/05_flashcards_deck_50.md)**: Rapid-fire revision covering core SQL, analytical windows, indexes, and distributed engines.

---

## 🏛️ Architectural Deep Dives

In-depth technical architecture whitepapers:

- **[01. Logical vs. Physical Query Execution](architectures/01_logical_vs_physical_query_execution.md)**: Relational algebra, AST parsing, predicate pushdown, and Cost-Based Optimizer physical join selection.
- **[02. MPP Distributed SQL & Data Movement](architectures/02_mpp_distributed_sql_and_data_movement.md)**: Shared-nothing architecture, Colocated vs Broadcast vs Shuffle joins, and network interconnect bottlenecks.
- **[03. Storage Engines — Row-Store, Columnar & Lakehouse Formats](architectures/03_storage_engines_row_columnar_and_lakehouse.md)**: 8KB B-Tree pages vs Parquet columnar row groups, dictionary encoding, Delta Lake ACID logs, and Liquid Clustering.
- **[04. Concurrency Control, MVCC & Distributed Consensus](architectures/04_concurrency_control_mvcc_and_distributed_consensus.md)**: The 5 concurrency anomalies, PostgreSQL tuple visibility (`xmin`/`xmax`), Two-Phase Locking, and Google Spanner TrueTime / HLC consensus.

---

## 🛠️ Repository Structure

```
sql-handbook/
├── README.md                                  # Master repository documentation
├── LICENSE                                    # MIT Open Source License
├── pyproject.toml                             # Python package & pytest configuration
├── requirements.txt                           # Optional development dependencies
├── .github/
│   └── workflows/
│       └── ci.yml                             # Automated GitHub Actions test runner
├── tests/
│   ├── test_sql_integrity.py                 # File structure & metadata assertion tests
│   ├── test_sql_execution.py                 # In-memory SQL execution & validation runner
│   └── conftest.py                            # Pytest configuration
├── scripts/
│   ├── run_all_exercises.py                  # CLI runner benchmarking all 105 exercises
│   ├── interactive_shell.py                  # Interactive in-memory SQL sandbox REPL
│   └── generate_readme_matrix.py             # Dynamic curriculum matrix generator
├── exercises/                                 # 105 Runnable SQL Coding Exercises
│   ├── 01_core_sql_fundamentals/             # 001 - 010 (Execution order, 3VL, SARGability)
│   ├── 02_joins_and_set_operations/          # 011 - 020 (Semi-joins, Anti-joins, Lateral)
│   ├── 03_aggregations_and_grouping/         # 021 - 030 (Conditional sums, ROLLUP, CUBE)
│   ├── 04_window_functions_mastery/          # 031 - 045 (Offsets, Frames, Gaps & Islands)
│   ├── 05_subqueries_and_recursive_ctes/     # 046 - 055 (Hierarchies, BOM, Graph paths)
│   ├── 06_data_modeling_and_scd/             # 056 - 065 (Kimball, SCD 1-6, Data Vault 2.0)
│   ├── 07_indexing_and_query_optimization/   # 066 - 075 (B-Tree, Covering, Join algorithms)
│   ├── 08_transactions_concurrency_and_locks/# 076 - 085 (ACID, MVCC, Deadlocks, Ledgers)
│   ├── 09_mpp_and_cloud_warehouses/          # 086 - 095 (Snowflake, BigQuery, Spark SQL)
│   └── 10_production_incidents_and_triage/   # 096 - 105 (Real-world incident postmortems)
├── runbooks/                                  # 6 Battle-tested production incident playbooks
├── interview/                                 # 4-Tier interview question bank & flashcards
└── architectures/                             # 4 Deep-dive architectural whitepapers
```

---

## 🤝 Contributing & License

Contributions, new production incident postmortems, and dialect optimizations are welcome! Please ensure all submissions include:
1. Standard exercise metadata header.
2. Complete schema DDL and test seed data.
3. Solution query with `-- ASSERT: ROW_COUNT = ...` verification comments.
4. Pass all automated tests: `python scripts/run_all_exercises.py`.

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for details.  
Created and maintained with ❤️ by [Santosh Jammi](https://github.com/santoshjammi29).
"""

    full_readme = header + "\n" + curriculum_md + "\n" + footer
    README_FILE.write_text(full_readme, encoding="utf-8")
    print(f"Successfully generated clean flagship README.md ({len(full_readme)} bytes)!")

if __name__ == "__main__":
    build_readme()
