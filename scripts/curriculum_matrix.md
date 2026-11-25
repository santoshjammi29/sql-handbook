### 🗺️ Curriculum Track Overview

| Track & Module | Range | Level | Core Architecture & Skills |
| :--- | :---: | :---: | :--- |
| 📦 **[01. Core SQL Fundamentals](#module-01-core-sql-fundamentals)** | `001 – 010` | 🟢<br>Beginner | Execution order, Three-Valued Logic, SARGability, type casting, idempotent DDL |
| 🔗 **[02. Joins & Set Operations](#module-02-joins-and-set-operations)** | `011 – 020` | 🟡<br>Intermediate | Semi-joins (EXISTS), anti-joins, full outer reconciliations, non-equi joins, set ops |
| 📊 **[03. Aggregations & Grouping](#module-03-aggregations-and-grouping)** | `021 – 030` | 🟡<br>Intermediate | COUNT semantics, conditional sums, multidimensional ROLLUP/CUBE, dynamic pivoting |
| 🪟 **[04. Window Functions Mastery](#module-04-window-functions-mastery)** | `031 – 045` | 🔴<br>Advanced | Ranking ties, value offsets (LAG/LEAD), sliding frames, Gaps & Islands, retention |
| 🌲 **[05. Subqueries & Recursive CTEs](#module-05-subqueries-and-recursive-ctes)** | `046 – 055` | 🔴<br>Advanced | Recursive hierarchies, Bill of Materials (BOM), flight paths, calendar spines, deduplication |
| 📐 **[06. Data Modeling & SCD](#module-06-data-modeling-and-scd)** | `056 – 065` | 🔴<br>Advanced | Kimball star schemas, SCD Types 1-6, Data Vault 2.0, bridge tables, surrogate hashing |
| ⚡ **[07. Indexing & Query Optimization](#module-07-indexing-and-query-optimization)** | `066 – 075` | 🔴<br>Advanced | B-Tree seek vs scan, composite prefix rule, covering indexes, join algorithms, stats |
| 🔒 **[08. Transactions, Concurrency & Locks](#module-08-transactions-concurrency-and-locks)** | `076 – 085` | 🔴<br>Advanced | ACID savepoints, isolation anomalies, write skew, MVCC internals, deadlock ordering |
| ☁️ **[09. MPP & Cloud Warehouses](#module-09-mpp-and-cloud-warehouses)** | `086 – 095` | 🟣<br>Architect | Snowflake micro-partitions, hash distributions, Liquid Clustering, key salting, MERGE |
| 🚨 **[10. Production Incidents & Triage](#module-10-production-incidents-and-triage)** | `096 – 105` | 🟣<br>Architect | 99% straggler skew, deadlock storms, out-of-order CDC recovery, data quality suites |

---

<a id="module-01-core-sql-fundamentals"></a>
### 📦 Module: 01. Core SQL Fundamentals

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `001` | [Logical Query Execution Order](../exercises/01_core_sql_fundamentals/001_logical_query_execution_order.sql) | 🟢<br>Beginner | Enterprise Multi-Tenant SaaS Billing & Margin Reconciliation Engine. |
| `002` | [Three Valued Logic & NULL Traps](../exercises/01_core_sql_fundamentals/002_three_valued_logic_and_null_traps.sql) | 🟢<br>Beginner | Enterprise Compliance & Multi-Jurisdiction Privacy Consent Engine (GDPR & CCPA). |
| `003` | [SARGability & Predicate Rewriting](../exercises/01_core_sql_fundamentals/003_sargability_and_predicate_rewriting.sql) | 🟡<br>Intermediate | An auditing job queries an invoice table with 20 million rows daily to find all invoices generated during the year 2024. |
| `004` | [Relational Constraints & Cascade Rules](../exercises/01_core_sql_fundamentals/004_relational_constraints_and_cascade_rules.sql) | 🟢<br>Beginner | Multi-Tenant Identity & Access Management (IAM) and RBAC Security Boundary. |
| `005` | [Safe Type Casting & Numeric Precision](../exercises/01_core_sql_fundamentals/005_safe_type_casting_and_numeric_precision.sql) | 🟡<br>Intermediate | Cross-Border Foreign Exchange & Digital Asset Settlement Clearinghouse. |
| `006` | [String Manipulation & Pattern Extraction](../exercises/01_core_sql_fundamentals/006_string_manipulation_and_pattern_extraction.sql) | 🟢<br>Beginner | Security Information & Event Management (SIEM) Ingress Pipeline. |
| `007` | [Temporal & Timestamp Arithmetic](../exercises/01_core_sql_fundamentals/007_temporal_and_timestamp_arithmetic.sql) | 🟡<br>Intermediate | Global Supply Chain & Freight Consignment Tracking Engine. |
| `008` | [Conditional CASE Logic & NULLIF COALESCE](../exercises/01_core_sql_fundamentals/008_conditional_case_logic_and_nullif_coalesce.sql) | 🟢<br>Beginner | Direct-to-Consumer (D2C) E-Commerce Promotional Waterfall & Return Analytics. |
| `009` | [Filtering Edge Cases NOT EXISTS vs NOT IN](../exercises/01_core_sql_fundamentals/009_filtering_edge_cases_not_exists_vs_not_in.sql) | 🟢<br>Beginner | International Wire Transfer Anti-Money Laundering (AML) Compliance Engine. |
| `010` | [Idempotent DDL & Safe Schema Migrations](../exercises/01_core_sql_fundamentals/010_idempotent_ddl_and_safe_schema_migrations.sql) | 🟢<br>Beginner | Zero-Downtime Blue/Green Database Schema Migration Engine. |

<a id="module-02-joins-and-set-operations"></a>
### 🔗 Module: 02. Joins & Set Operations

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `011` | [Inner Left Right Full Outer Joins](../exercises/02_joins_and_set_operations/011_inner_left_right_full_outer_joins.sql) | 🟡<br>Intermediate | Enterprise CRM & Revenue Attribution Mart (Salesforce & ERP Integration). |
| `012` | [Semi Joins & Duplicate Multiplier Prevention](../exercises/02_joins_and_set_operations/012_semi_joins_and_duplicate_multiplier_prevention.sql) | 🟡<br>Intermediate | E-Commerce Order Management & Fulfillment Reconciliation Mart. |
| `013` | [Anti Joins For Missing Record Detection](../exercises/02_joins_and_set_operations/013_anti_joins_for_missing_record_detection.sql) | 🟡<br>Intermediate | Enterprise Lakehouse Reconciliation & Pipeline Data Loss Sentinel. |
| `014` | [Full Outer Joins For Reconciliation](../exercises/02_joins_and_set_operations/014_full_outer_joins_for_reconciliation.sql) | 🟡<br>Intermediate | Automated Financial General Ledger & Bank Settlement Reconciliation Engine. |
| `015` | [Cross Joins & Cartesian Grid Generation](../exercises/02_joins_and_set_operations/015_cross_joins_and_cartesian_grid_generation.sql) | 🟢<br>Beginner | Retail Machine Learning Demand Forecasting Feature Store. |
| `016` | [Non Equi Joins & Effective Date Matching](../exercises/02_joins_and_set_operations/016_non_equi_joins_and_effective_date_matching.sql) | 🔴<br>Advanced | Multi-Currency Algorithmic Trading & As-Of Rate Conversion Engine. |
| `017` | [Lateral Joins & Cross Apply Expansions](../exercises/02_joins_and_set_operations/017_lateral_joins_and_cross_apply_expansions.sql) | 🔴<br>Advanced | Customer 360 & Top-N Recent Purchase Attribution Engine. |
| `018` | [UNION vs UNION ALL Internals](../exercises/02_joins_and_set_operations/018_union_vs_union_all_internals.sql) | 🟢<br>Beginner | Omnichannel Event Stream Consolidation (Web, Mobile App & IoT Gateways). |
| `019` | [INTERSECT & EXCEPT Data Audits](../exercises/02_joins_and_set_operations/019_intersect_and_except_data_audits.sql) | 🟡<br>Intermediate | Legacy On-Prem Data Warehouse to Modern Cloud Lakehouse Migration. |
| `020` | [Self Joins For Sequential Event Pairs](../exercises/02_joins_and_set_operations/020_self_joins_for_sequential_event_pairs.sql) | 🔴<br>Advanced | User Clickstream Funnel Pathing & Checkout Drop-Off Velocity Analytics. |

<a id="module-03-aggregations-and-grouping"></a>
### 📊 Module: 03. Aggregations & Grouping

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `021` | [COUNT Semantics Star One Column](../exercises/03_aggregations_and_grouping/021_count_semantics_star_one_column.sql) | 🟢<br>Beginner | Enterprise Customer Master Data Management (MDM) & KYC Profiling Engine. |
| `022` | [Multi Column Group By & Grain Integrity](../exercises/03_aggregations_and_grouping/022_multi_column_group_by_and_grain_integrity.sql) | 🟡<br>Intermediate | Multi-Entity Global General Ledger Financial Consolidation. |
| `023` | [Where Pre Filtering vs Having Post Aggregation](../exercises/03_aggregations_and_grouping/023_where_pre_filtering_vs_having_post_aggregation.sql) | 🟢<br>Beginner | Multi-Cloud FinOps Infrastructure Spend Attribution & Outlier Detection. |
| `024` | [Conditional Aggregation Filtered Metrics](../exercises/03_aggregations_and_grouping/024_conditional_aggregation_filtered_metrics.sql) | 🟡<br>Intermediate | Executive B2B SaaS Recurring Revenue & Retention Metrics Engine. |
| `025` | [Multidimensional Olap ROLLUP Subtotals](../exercises/03_aggregations_and_grouping/025_multidimensional_olap_rollup_subtotals.sql) | 🟡<br>Intermediate | Enterprise Retail Executive Reporting & Hierarchical Rollup Engine. |
| `026` | [Multidimensional Olap CUBE Combinations](../exercises/03_aggregations_and_grouping/026_multidimensional_olap_cube_combinations.sql) | 🟡<br>Intermediate | Multi-Dimensional Inventory Position & Warehouse Logistics Matrix. |
| `027` | [GROUPING SETS For Targeted Cubes](../exercises/03_aggregations_and_grouping/027_grouping_sets_for_targeted_cubes.sql) | 🔴<br>Advanced | High-Performance BI Cube Materialization & Pre-Aggregation Pipeline. |
| `028` | [Relational Pivoting Rows To Columns](../exercises/03_aggregations_and_grouping/028_relational_pivoting_rows_to_columns.sql) | 🟡<br>Intermediate | Quarterly Executive Income Statement & Financial P&L Matrix. |
| `029` | [Relational Unpivoting Columns To Rows](../exercises/03_aggregations_and_grouping/029_relational_unpivoting_columns_to_rows.sql) | 🟡<br>Intermediate | Enterprise Financial Planning & Analysis (FP&A) Ingestion Mart. |
| `030` | [Statistical Aggregations Median & Percentiles](../exercises/03_aggregations_and_grouping/030_statistical_aggregations_median_and_percentiles.sql) | 🔴<br>Advanced | Microservice API Gateway SLA & Latency Percentile Benchmarking. |

<a id="module-04-window-functions-mastery"></a>
### 🪟 Module: 04. Window Functions Mastery

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `031` | [Ranking Functions ROW_NUMBER RANK DENSE_RANK](../exercises/04_window_functions_mastery/031_ranking_functions_row_number_rank_dense_rank.sql) | 🔴<br>Advanced | Enterprise Performance Bonus & Sales Commission Allocation Engine. |
| `032` | [Quantile Distribution NTILE Bucketing](../exercises/04_window_functions_mastery/032_quantile_distribution_ntile_bucketing.sql) | 🔴<br>Advanced | Automated Consumer Lending Underwriting & Risk Decile Segmentation. |
| `033` | [Value Offsets LAG LEAD Period Over Period](../exercises/04_window_functions_mastery/033_value_offsets_lag_lead_period_over_period.sql) | 🔴<br>Advanced | SaaS Monthly Recurring Revenue (MRR) Period-over-Period Variance Engine. |
| `034` | [Navigation Functions FIRST_VALUE, LAST_VALUE & NTH_VALUE](../exercises/04_window_functions_mastery/034_navigation_functions_first_last_nth_value.sql) | 🔴<br>Advanced | Intensive Care Unit (ICU) Patient Vital Signs & Sepsis Progression Monitoring. |
| `035` | [Cumulative & Running Totals](../exercises/04_window_functions_mastery/035_cumulative_and_running_totals.sql) | 🔴<br>Advanced | Core Banking General Ledger & Real-Time Balance Tracker. |
| `036` | [Moving Averages & Rolling Windows](../exercises/04_window_functions_mastery/036_moving_averages_and_rolling_windows.sql) | 🟡<br>Intermediate | Telemetry anomaly detection requires computing a 3-day trailing moving average of server CPU load to filter out transient micro-spikes. |
| `037` | [Physical vs Logical Frames ROWS vs RANGE](../exercises/04_window_functions_mastery/037_physical_vs_logical_frames_rows_vs_range.sql) | 🔴<br>Advanced | When computing running totals over duplicate order dates, the default frame RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW groups peer rows together, producing duplicate running totals on the same date!. |
| `038` | [Gaps & Islands Consecutive Streaks](../exercises/04_window_functions_mastery/038_gaps_and_islands_consecutive_streaks.sql) | 🔴<br>Advanced | SaaS & Gaming Daily Active User (DAU) Engagement Streak Engine. |
| `039` | [Gaps & Islands Threshold Sessionization](../exercises/04_window_functions_mastery/039_gaps_and_islands_threshold_sessionization.sql) | 🔴<br>Advanced | Web & Mobile Clickstream User Sessionization Engine. |
| `040` | [Gaps & Islands Overlapping Interval Merging](../exercises/04_window_functions_mastery/040_gaps_and_islands_overlapping_interval_merging.sql) | 🔴<br>Advanced | Multi-Node Virtual Machine Active Uptime Consolidation. |
| `041` | [Running Peak & Maximum Drawdown](../exercises/04_window_functions_mastery/041_running_peak_and_maximum_drawdown.sql) | 🔴<br>Advanced | Quantitative Hedge Fund Portfolio Risk & Peak Drawdown Engine. |
| `042` | [Year Over Year & Month Over Month Growth](../exercises/04_window_functions_mastery/042_year_over_year_and_month_over_month_growth.sql) | 🔴<br>Advanced | Enterprise Multi-Year Seasonal Revenue Comparison Engine. |
| `043` | [Customer Retention Cohort Curves](../exercises/04_window_functions_mastery/043_customer_retention_cohort_curves.sql) | 🔴<br>Advanced | SaaS Customer Retention Cohort Triangle Engine. |
| `044` | [Top-N Per Category Deterministic Ties](../exercises/04_window_functions_mastery/044_top_n_per_category_deterministic_ties.sql) | 🔴<br>Advanced | Top-N per Category with Strict Determinism & Tie-Breaking. |
| `045` | [Windowed Aggregates Without Group By](../exercises/04_window_functions_mastery/045_windowed_aggregates_without_group_by.sql) | 🟢<br>Beginner | Executive Compensation Transparency & Departmental Proportion Distribution. |

<a id="module-05-subqueries-and-recursive-ctes"></a>
### 🌲 Module: 05. Subqueries & Recursive CTEs

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `046` | [Scalar & Multi Row Subqueries](../exercises/05_subqueries_and_recursive_ctes/046_scalar_and_multi_row_subqueries.sql) | 🟢<br>Beginner | Executive Compensation Governance & Equity Benchmarking Mart. |
| `047` | [Correlated Subqueries & Decorrelation](../exercises/05_subqueries_and_recursive_ctes/047_correlated_subqueries_and_decorrelation.sql) | 🟡<br>Intermediate | E-Commerce Customer Lifetime Value & Order Frequency Engine. |
| `048` | [CTEs vs Temp Tables vs Subqueries](../exercises/05_subqueries_and_recursive_ctes/048_ctes_vs_temp_tables_vs_subqueries.sql) | 🟡<br>Intermediate | Multi-Stage ETL Data Pipeline Architecture. |
| `049` | [Recursive CTE Organizational Hierarchy](../exercises/05_subqueries_and_recursive_ctes/049_recursive_cte_organizational_hierarchy.sql) | 🔴<br>Advanced | Enterprise Human Resources Management (HCM) Management Hierarchy Tree. |
| `050` | [Recursive CTE Bill Of Materials Explosion](../exercises/05_subqueries_and_recursive_ctes/050_recursive_cte_bill_of_materials_explosion.sql) | 🔴<br>Advanced | Automotive & High-Tech Manufacturing Bill of Materials (BOM) Parts Explosion. |
| `051` | [Recursive CTE Graph Shortest Path Cycle Detection](../exercises/05_subqueries_and_recursive_ctes/051_recursive_cte_graph_shortest_path_cycle_detection.sql) | 🔴<br>Advanced | Airline Route Network & Shortest Connection Path Finder with Cycle Detection. |
| `052` | [Recursive CTE Calendar Dimension Spine](../exercises/05_subqueries_and_recursive_ctes/052_recursive_cte_calendar_dimension_spine.sql) | 🔴<br>Advanced | Enterprise Fiscal Calendar Dimension Spine Generation. |
| `053` | [Binary Tree Node Classification](../exercises/05_subqueries_and_recursive_ctes/053_binary_tree_node_classification.sql) | 🔴<br>Advanced | Binary Tree Node Structural Classification. |
| `054` | [Materialized vs Inlined CTEs](../exercises/05_subqueries_and_recursive_ctes/054_materialized_vs_inlined_ctes.sql) | 🔴<br>Advanced | CTE Materialization vs Inlining Optimization. |
| `055` | [Deterministic Duplicate Deletion](../exercises/05_subqueries_and_recursive_ctes/055_deterministic_duplicate_deletion.sql) | 🔴<br>Advanced | Production Streaming Deduplication & Table Cleaning. |

<a id="module-06-data-modeling-and-scd"></a>
### 📐 Module: 06. Data Modeling & SCD

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `056` | [Kimball Star Schema Fact Dimension Design](../exercises/06_data_modeling_and_scd/056_kimball_star_schema_fact_dimension_design.sql) | 🟢<br>Beginner | Enterprise Retail Omnichannel Sales Data Mart. |
| `057` | [Slowly Changing Dimension Type 1 Overwrite](../exercises/06_data_modeling_and_scd/057_slowly_changing_dimension_type_1_overwrite.sql) | 🟡<br>Intermediate | SCD Type 1 (In-Place Overwrite): When correcting spelling errors or non-historical attributes (e.g. |
| `058` | [Slowly Changing Dimension Type 2 Historical](../exercises/06_data_modeling_and_scd/058_slowly_changing_dimension_type_2_historical.sql) | 🔴<br>Advanced | SCD Type 2 (Historical Tracking): When customer address changes, previous address must be preserved for historical sales tax audit compliance. |
| `059` | [Slowly Changing Dimension Type 3 Previous Value](../exercises/06_data_modeling_and_scd/059_slowly_changing_dimension_type_3_previous_value.sql) | 🟡<br>Intermediate | SCD Type 3 (Prior Value Column): Sales territory realignment requires tracking both the Current Sales Territory and the Previous Sales Territory side-by-side without adding new table rows. |
| `060` | [Slowly Changing Dimension Type 4 Mini Dimensions](../exercises/06_data_modeling_and_scd/060_slowly_changing_dimension_type_4_mini_dimensions.sql) | 🔴<br>Advanced | SCD Type 4 (Mini-Dimensions): High-frequency changing customer attributes (credit score band, annual income tier, age group) would cause an SCD Type 2 table to explode to billions of rows. |
| `061` | [Slowly Changing Dimension Type 6 Hybrid Implementation](../exercises/06_data_modeling_and_scd/061_slowly_changing_dimension_type_6_hybrid_implementation.sql) | 🔴<br>Advanced | SCD Type 6 Hybrid Implementation (Type 1 + Type 2 + Type 3). |
| `062` | [Data Vault 2 0 Hubs Links Satellites](../exercises/06_data_modeling_and_scd/062_data_vault_2_0_hubs_links_satellites.sql) | 🔴<br>Advanced | Data Vault 2.0 Core Banking Enterprise Raw Vault. |
| `063` | [Bridge Tables For Many To Many Relationships](../exercises/06_data_modeling_and_scd/063_bridge_tables_for_many_to_many_relationships.sql) | 🔴<br>Advanced | Healthcare & Clinical Outcomes Many-to-Many Bridge Table Architecture. |
| `064` | [Accumulating Snapshot Fact Tables](../exercises/06_data_modeling_and_scd/064_accumulating_snapshot_fact_tables.sql) | 🔴<br>Advanced | E-Commerce Order Fulfillment Accumulating Snapshot Fact Table. |
| `065` | [Deterministic Surrogate Key Generation](../exercises/06_data_modeling_and_scd/065_deterministic_surrogate_key_generation.sql) | 🔴<br>Advanced | Distributed Lakehouse Hash-Based Surrogate Key Generation. |

<a id="module-07-indexing-and-query-optimization"></a>
### ⚡ Module: 07. Indexing & Query Optimization

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `066` | [B-Tree Index Seek vs Index Scan](../exercises/07_indexing_and_query_optimization/066_btree_index_seek_vs_index_scan.sql) | 🔴<br>Advanced | High-Throughput Order Ingestion Engine & Execution Plan Optimization. |
| `067` | [Composite Index Column Ordering Left Prefix](../exercises/07_indexing_and_query_optimization/067_composite_index_column_ordering_left_prefix.sql) | 🔴<br>Advanced | Composite Index Design & The Left-Prefix Rule. |
| `068` | [Covering Indexes & Index Only Scans](../exercises/07_indexing_and_query_optimization/068_covering_indexes_and_index_only_scans.sql) | 🔴<br>Advanced | Microservice High-Throughput Read Path & Index-Only Scans. |
| `069` | [Filtered & Partial Indexes](../exercises/07_indexing_and_query_optimization/069_filtered_and_partial_indexes.sql) | 🔴<br>Advanced | High-Scale Asynchronous Task Dispatch Queue. |
| `070` | [Cardinality Estimation & Statistics](../exercises/07_indexing_and_query_optimization/070_cardinality_estimation_and_statistics.sql) | 🔴<br>Advanced | Cost-Based Optimizer (CBO) Cardinality Estimation & Statistics Drift. |
| `071` | [Clustered vs Non Clustered Index Layout](../exercises/07_indexing_and_query_optimization/071_clustered_vs_non_clustered_index_layout.sql) | 🔴<br>Advanced | Physical Storage Layout: Clustered vs Non-Clustered Indexes. |
| `072` | [Join Algorithms Nested Loop Hash Merge](../exercises/07_indexing_and_query_optimization/072_join_algorithms_nested_loop_hash_merge.sql) | 🔴<br>Advanced | Relational Join Algorithms Deep Dive: 1. |
| `073` | [Preventing Accidental Cartesian Products](../exercises/07_indexing_and_query_optimization/073_preventing_accidental_cartesian_products.sql) | 🟢<br>Beginner | Accidental Cartesian Product Prevention & TempDB Protection. |
| `074` | [Sargable Date Range Predicates](../exercises/07_indexing_and_query_optimization/074_sargable_date_range_predicates.sql) | 🔴<br>Advanced | High-Volume Log Auditing SARGable Date Range Predicates. |
| `075` | [Index Bloat & Fragmentation Maintenance](../exercises/07_indexing_and_query_optimization/075_index_bloat_and_fragmentation_maintenance.sql) | 🔴<br>Advanced | B-Tree Index Page Fragmentation & Bloat Maintenance. |

<a id="module-08-transactions-concurrency-and-locks"></a>
### 🔒 Module: 08. Transactions, Concurrency & Locks

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `076` | [Acid Atomicity & Savepoints](../exercises/08_transactions_concurrency_and_locks/076_acid_atomicity_and_savepoints.sql) | 🟡<br>Intermediate | Distributed E-Commerce Checkout Pipeline & Transaction Boundaries. |
| `077` | [Dirty Read Anomaly Read Uncommitted](../exercises/08_transactions_concurrency_and_locks/077_dirty_read_anomaly_read_uncommitted.sql) | 🔴<br>Advanced | Core Banking Settlement Ledger & ANSI SQL Transaction Isolation Levels. |
| `078` | [Non Repeatable Read Anomaly](../exercises/08_transactions_concurrency_and_locks/078_non_repeatable_read_anomaly.sql) | 🔴<br>Advanced | Multi-Tier Inventory Rebalancing & Warehouse Allocation Service. |
| `079` | [Phantom Read Anomaly Range Locks](../exercises/08_transactions_concurrency_and_locks/079_phantom_read_anomaly_range_locks.sql) | 🔴<br>Advanced | Commercial Underwriting Exposure Management & Range Lock Semantics. |
| `080` | [Write Skew Anomaly Under Snapshot Isolation](../exercises/08_transactions_concurrency_and_locks/080_write_skew_anomaly_under_snapshot_isolation.sql) | 🟣<br>Architect | Hospital Emergency Room On-Call Roster & Snapshot Isolation Invariants. |
| `081` | [MVCC Internals & Version Visibility](../exercises/08_transactions_concurrency_and_locks/081_mvcc_internals_and_version_visibility.sql) | 🔴<br>Advanced | PostgreSQL & Distributed Storage Engine MVCC Internals. |
| `082` | [Optimistic Concurrency Control Version Checks](../exercises/08_transactions_concurrency_and_locks/082_optimistic_concurrency_control_version_checks.sql) | 🟡<br>Intermediate | High-Concurrency Flash-Sale Inventory Engine & Compare-And-Swap (CAS). |
| `083` | [Deadlock Reproduction & Inverse Locking](../exercises/08_transactions_concurrency_and_locks/083_deadlock_reproduction_and_inverse_locking.sql) | 🔴<br>Advanced | Core Banking Multi-Account Wire Settlement & Distributed Lock Graphs. |
| `084` | [Pessimistic Locking FOR UPDATE](../exercises/08_transactions_concurrency_and_locks/084_pessimistic_locking_for_update.sql) | 🔴<br>Advanced | High-Throughput Distributed Task Processing Queue & Pessimistic Locks. |
| `085` | [Double Entry Ledger Atomic Transfer](../exercises/08_transactions_concurrency_and_locks/085_double_entry_ledger_atomic_transfer.sql) | 🟣<br>Architect | Core Banking General Ledger (GL) & Financial Invariant Enforcement. |

<a id="module-09-mpp-and-cloud-warehouses"></a>
### ☁️ Module: 09. MPP & Cloud Warehouses

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `086` | [Snowflake Micropartition Pruning](../exercises/09_mpp_and_cloud_warehouses/086_snowflake_micropartition_pruning.sql) | 🔴<br>Advanced | Petabyte-Scale Cloud Data Warehouse & Micro-Partition Metadata Pruning. |
| `087` | [MPP Table Distribution Hash Replicated Roundrobin](../exercises/09_mpp_and_cloud_warehouses/087_mpp_table_distribution_hash_replicated_roundrobin.sql) | 🟣<br>Architect | Massively Parallel Processing (MPP) Architecture & Storage Topologies. |
| `088` | [Liquid Clustering vs Hive Partitioning](../exercises/09_mpp_and_cloud_warehouses/088_liquid_clustering_vs_hive_partitioning.sql) | 🔴<br>Advanced | Modern Delta Lake Liquid Clustering vs Legacy Hive Physical Directory Layouts. |
| `089` | [Detecting Distribution Skew In Parallel Shards](../exercises/09_mpp_and_cloud_warehouses/089_detecting_distribution_skew_in_parallel_shards.sql) | 🔴<br>Advanced | Distributed Data Shard Telemetry & Straggler Task Diagnostics. |
| `090` | [Distributed Key Salting For Skewed Joins](../exercises/09_mpp_and_cloud_warehouses/090_distributed_key_salting_for_skewed_joins.sql) | 🟣<br>Architect | Distributed Join Skew Mitigation & Two-Phase Key Salting Pattern. |
| `091` | [Broadcast vs Shuffle Join Thresholds](../exercises/09_mpp_and_cloud_warehouses/091_broadcast_vs_shuffle_join_thresholds.sql) | 🟡<br>Intermediate | Distributed Query Planner & Physical Join Strategy Selection. |
| `092` | [Partition Pruning & Dynamic Partition Elimination](../exercises/09_mpp_and_cloud_warehouses/092_partition_pruning_and_dynamic_partition_elimination.sql) | 🔴<br>Advanced | Dynamic Partition Pruning (DPP) & Runtime Partition Elimination in MPP Engines. |
| `093` | [Delta MERGE INTO Multi Condition Matching](../exercises/09_mpp_and_cloud_warehouses/093_delta_merge_into_multi_condition_matching.sql) | 🔴<br>Advanced | Modern Lakehouse ACID Ingestion & ANSI SQL MERGE INTO Mechanics. |
| `094` | [Query Memory Spill Mitigation](../exercises/09_mpp_and_cloud_warehouses/094_query_memory_spill_mitigation.sql) | 🟡<br>Intermediate | Apache Spark Project Tungsten & Cloud DW Memory Management. |
| `095` | [Serverless Sql Querying External Files](../exercises/09_mpp_and_cloud_warehouses/095_serverless_sql_querying_external_files.sql) | 🟡<br>Intermediate | Zero-Copy External Lake Querying & Serverless SQL Query Engines. |

<a id="module-10-production-incidents-and-triage"></a>
### 🚨 Module: 10. Production Incidents & Triage

| # | Exercise Topic & Code | Level | Practical Scenario |
| :---: | :--- | :---: | :--- |
| `096` | [Incident: The 99 Percent Straggler Task Disaster](../exercises/10_production_incidents_and_triage/096_incident_the_99_percent_straggler_task_disaster.sql) | 🟣<br>Architect | PRODUCTION INCIDENT POSTMORTEM: The 99% Complete Straggler Task Disaster. |
| `097` | [Incident: Payment Gateway Deadlock Storm](../exercises/10_production_incidents_and_triage/097_incident_payment_gateway_deadlock_storm.sql) | 🔴<br>Advanced | PRODUCTION INCIDENT POSTMORTEM: Deadlock Storm in Payment Clearing. |
| `098` | [Incident: Out Of Order CDC Timeline Corruption](../exercises/10_production_incidents_and_triage/098_incident_out_of_order_cdc_timeline_corruption.sql) | 🟣<br>Architect | PRODUCTION INCIDENT POSTMORTEM: Out-of-Order CDC Timeline Corruption. |
| `099` | [Incident: Accidental Cartesian TempDB Exhaustion](../exercises/10_production_incidents_and_triage/099_incident_accidental_cartesian_tempdb_exhaustion.sql) | 🔴<br>Advanced | PRODUCTION INCIDENT POSTMORTEM: Accidental Cartesian TempDB Storage Exhaustion. |
| `100` | [Incident: Silent Schema Drift BI Refresh Failure](../exercises/10_production_incidents_and_triage/100_incident_silent_schema_drift_bi_refresh_failure.sql) | 🟡<br>Intermediate | PRODUCTION INCIDENT POSTMORTEM: Silent Schema Drift Breaking Executive BI Dashboards. |
| `101` | [Incident: Parameter Sniffing Query Timeout](../exercises/10_production_incidents_and_triage/101_incident_parameter_sniffing_query_timeout.sql) | 🔴<br>Advanced | PRODUCTION INCIDENT POSTMORTEM: Parameter Sniffing Sudden Query Timeouts. |
| `102` | [Incident: Phantom Read Financial Ledger Double Spend](../exercises/10_production_incidents_and_triage/102_incident_phantom_read_financial_ledger_double_spend.sql) | 🔴<br>Advanced | PRODUCTION INCIDENT POSTMORTEM: Financial Ledger Double-Spend Breach Under Read Committed. |
| `103` | [Incident: Unindexed Foreign Key Table Lock Cascade](../exercises/10_production_incidents_and_triage/103_incident_unindexed_foreign_key_table_lock_cascade.sql) | 🔴<br>Advanced | PRODUCTION INCIDENT POSTMORTEM: Unindexed Foreign Key Table-Lock Cascade. |
| `104` | [Incident: Delta Lake Concurrent Append Conflict](../exercises/10_production_incidents_and_triage/104_incident_delta_lake_concurrent_append_conflict.sql) | 🔴<br>Advanced | PRODUCTION INCIDENT POSTMORTEM: Delta Lake Concurrent Append Write Conflict. |
| `105` | [Master Enterprise Data Quality Reconciliation Suite](../exercises/10_production_incidents_and_triage/105_master_enterprise_data_quality_reconciliation_suite.sql) | 🟣<br>Architect | Enterprise Data Quality & Automated CI/CD Production Gatekeeper. |
