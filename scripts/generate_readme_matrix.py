#!/usr/bin/env python3
"""
Generates the clean, responsive, simple Curriculum Matrix and Track Overview
for README.md, strictly preventing word-wrap blowouts and KaTeX math delimiter collisions.
"""

from pathlib import Path
import re

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

MODULE_CONFIG = {
    "01_core_sql_fundamentals": {
        "icon": "📦",
        "title": "01. Core SQL Fundamentals",
        "anchor": "module-01-core-sql-fundamentals",
        "range": "001 – 010",
        "level": "🟢<br>Beginner",
        "desc": "Execution order, Three-Valued Logic, SARGability, type casting, idempotent DDL"
    },
    "02_joins_and_set_operations": {
        "icon": "🔗",
        "title": "02. Joins & Set Operations",
        "anchor": "module-02-joins-and-set-operations",
        "range": "011 – 020",
        "level": "🟡<br>Intermediate",
        "desc": "Semi-joins (EXISTS), anti-joins, full outer reconciliations, non-equi joins, set ops"
    },
    "03_aggregations_and_grouping": {
        "icon": "📊",
        "title": "03. Aggregations & Grouping",
        "anchor": "module-03-aggregations-and-grouping",
        "range": "021 – 030",
        "level": "🟡<br>Intermediate",
        "desc": "COUNT semantics, conditional sums, multidimensional ROLLUP/CUBE, dynamic pivoting"
    },
    "04_window_functions_mastery": {
        "icon": "🪟",
        "title": "04. Window Functions Mastery",
        "anchor": "module-04-window-functions-mastery",
        "range": "031 – 045",
        "level": "🔴<br>Advanced",
        "desc": "Ranking ties, value offsets (LAG/LEAD), sliding frames, Gaps & Islands, retention"
    },
    "05_subqueries_and_recursive_ctes": {
        "icon": "🌲",
        "title": "05. Subqueries & Recursive CTEs",
        "anchor": "module-05-subqueries-and-recursive-ctes",
        "range": "046 – 055",
        "level": "🔴<br>Advanced",
        "desc": "Recursive hierarchies, Bill of Materials (BOM), flight paths, calendar spines, deduplication"
    },
    "06_data_modeling_and_scd": {
        "icon": "📐",
        "title": "06. Data Modeling & SCD",
        "anchor": "module-06-data-modeling-and-scd",
        "range": "056 – 065",
        "level": "🔴<br>Advanced",
        "desc": "Kimball star schemas, SCD Types 1-6, Data Vault 2.0, bridge tables, surrogate hashing"
    },
    "07_indexing_and_query_optimization": {
        "icon": "⚡",
        "title": "07. Indexing & Query Optimization",
        "anchor": "module-07-indexing-and-query-optimization",
        "range": "066 – 075",
        "level": "🔴<br>Advanced",
        "desc": "B-Tree seek vs scan, composite prefix rule, covering indexes, join algorithms, stats"
    },
    "08_transactions_concurrency_and_locks": {
        "icon": "🔒",
        "title": "08. Transactions, Concurrency & Locks",
        "anchor": "module-08-transactions-concurrency-and-locks",
        "range": "076 – 085",
        "level": "🔴<br>Advanced",
        "desc": "ACID savepoints, isolation anomalies, write skew, MVCC internals, deadlock ordering"
    },
    "09_mpp_and_cloud_warehouses": {
        "icon": "☁️",
        "title": "09. MPP & Cloud Warehouses",
        "anchor": "module-09-mpp-and-cloud-warehouses",
        "range": "086 – 095",
        "level": "🟣<br>Architect",
        "desc": "Snowflake micro-partitions, hash distributions, Liquid Clustering, key salting, MERGE"
    },
    "10_production_incidents_and_triage": {
        "icon": "🚨",
        "title": "10. Production Incidents & Triage",
        "anchor": "module-10-production-incidents-and-triage",
        "range": "096 – 105",
        "level": "🟣<br>Architect",
        "desc": "99% straggler skew, deadlock storms, out-of-order CDC recovery, data quality suites"
    },
}

LEVEL_BADGES = {
    "Beginner": "🟢<br>Beginner",
    "Beginner / Foundation": "🟢<br>Beginner",
    "Intermediate": "🟡<br>Intermediate",
    "Advanced": "🔴<br>Advanced",
    "Principal / Architect": "🟣<br>Architect",
    "Architect": "🟣<br>Architect",
}

TITLE_REPLACEMENTS = [
    (r"\bSargability\b", "SARGability"),
    (r"\bNull\b", "NULL"),
    (r"\bNulls\b", "NULLs"),
    (r"\bNullif\b", "NULLIF"),
    (r"\bCoalesce\b", "COALESCE"),
    (r"\bCase\b", "CASE"),
    (r"\bRollup\b", "ROLLUP"),
    (r"\bCube\b", "CUBE"),
    (r"\bGrouping Sets\b", "GROUPING SETS"),
    (r"\bCount\b", "COUNT"),
    (r"\bBtree\b", "B-Tree"),
    (r"\bRow Number\b", "ROW_NUMBER"),
    (r"\bRank\b", "RANK"),
    (r"\bDense Rank\b", "DENSE_RANK"),
    (r"\bNtile\b", "NTILE"),
    (r"\bLag\b", "LAG"),
    (r"\bLead\b", "LEAD"),
    (r"\bFirst Last Nth Value\b", "FIRST_VALUE, LAST_VALUE & NTH_VALUE"),
    (r"\bRows Vs Range\b", "ROWS vs RANGE"),
    (r"\bYoy\b", "YoY"),
    (r"\bMom\b", "MoM"),
    (r"\bMrr\b", "MRR"),
    (r"\bTop N\b", "Top-N"),
    (r"\bCte\b", "CTE"),
    (r"\bCtes\b", "CTEs"),
    (r"\bDdl\b", "DDL"),
    (r"\bScd\b", "SCD"),
    (r"\bMpp\b", "MPP"),
    (r"\bMvcc\b", "MVCC"),
    (r"\bCdc\b", "CDC"),
    (r"\bBi\b", "BI"),
    (r"\bDq\b", "DQ"),
    (r"\bPk\b", "PK"),
    (r"\bFk\b", "FK"),
    (r"\bOom\b", "OOM"),
    (r"\bTempdb\b", "TempDB"),
    (r"\b3vl\b", "3VL"),
    (r"\bNot Exists Vs Not In\b", "NOT EXISTS vs NOT IN"),
    (r"\bExists\b", "EXISTS"),
    (r"\bUnion Vs Union All\b", "UNION vs UNION ALL"),
    (r"\bIntersect And Except\b", "INTERSECT & EXCEPT"),
    (r"\bMerge Into\b", "MERGE INTO"),
    (r"\bFor Update\b", "FOR UPDATE"),
    (r"\bAnd\b", "&"),
    (r"\bVs\b", "vs"),
]

def clean_title(filename: str) -> str:
    raw = re.sub(r"^\d+_", "", filename).replace(".sql", "")
    words = raw.replace("_", " ").title()
    for pattern, repl in TITLE_REPLACEMENTS:
        words = re.sub(pattern, repl, words, flags=re.IGNORECASE)
    words = words.replace("Incident The ", "Incident: The ")
    words = words.replace("Incident ", "Incident: ")
    return words.strip()

def extract_meta(file_path: Path):
    content = file_path.read_text(encoding="utf-8")
    num_str = file_path.name.split("_")[0]
    
    level_raw = "Intermediate"
    for line in content.splitlines():
        if "LEVEL:" in line:
            level_raw = line.split("LEVEL:")[1].strip()
            break
            
    badge = LEVEL_BADGES.get(level_raw, f"`{level_raw}`")

    scenario = ""
    m_ctx = re.search(r"BUSINESS CONTEXT:\s*--\s*(.*?)(?:\.|\n--\s*PROBLEM|\n--\s*SURGICAL)", content, re.DOTALL)
    if m_ctx:
        clean_text = " ".join([l.replace("--", "").strip() for l in m_ctx.group(1).splitlines()])
        scenario = clean_text.split(".")[0].strip() + "."
    else:
        scenario = clean_title(file_path.name)

    scenario = re.sub(r"\$(\d+)", r"USD \1", scenario)
    scenario = scenario.replace("$", "")

    return {
        "id": num_str,
        "title": clean_title(file_path.name),
        "rel_path": f"exercises/{file_path.parent.name}/{file_path.name}",
        "module": file_path.parent.name,
        "badge": badge,
        "scenario": scenario
    }

def generate_curriculum_markdown() -> str:
    files = sorted(list(EXERCISES_DIR.glob("*/*.sql")))
    
    out = []
    
    # 1. High-level track overview table
    out.append("### 🗺️ Curriculum Track Overview\n")
    out.append("| Track & Module | Range | Level | Core Architecture & Skills |")
    out.append("| :--- | :---: | :---: | :--- |")
    
    for mod_dir in sorted(list(MODULE_CONFIG.keys())):
        cfg = MODULE_CONFIG[mod_dir]
        out.append(f"| {cfg['icon']} **[{cfg['title']}](#{cfg['anchor']})** | `{cfg['range']}` | {cfg['level']} | {cfg['desc']} |")
        
    out.append("\n---\n")

    # 2. Detailed per-module tables (simple, clean 4-column layout)
    current_module = ""
    for f in files:
        meta = extract_meta(f)
        if meta["module"] != current_module:
            current_module = meta["module"]
            cfg = MODULE_CONFIG[current_module]
            
            out.append(f"\n<a id=\"{cfg['anchor']}\"></a>")
            out.append(f"### {cfg['icon']} Module: {cfg['title']}\n")
            out.append("| # | Exercise Topic & Code | Level | Practical Scenario |")
            out.append("| :---: | :--- | :---: | :--- |")

        ex_link = f"[{meta['title']}]({meta['rel_path']})"
        out.append(
            f"| `{meta['id']}` | {ex_link} | {meta['badge']} | {meta['scenario']} |"
        )
        
    return "\n".join(out)

if __name__ == "__main__":
    md = generate_curriculum_markdown()
    out_file = BASE_DIR / "scripts" / "curriculum_matrix.md"
    out_file.write_text(md, encoding="utf-8")
    print(f"Generated clean curriculum matrix with track overview -> {out_file}")
