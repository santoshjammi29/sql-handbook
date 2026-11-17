"""
Test Suite: SQL File Standards & Integrity Verification
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

EXPECTED_MODULES = [
    ("01_core_sql_fundamentals", 10),
    ("02_joins_and_set_operations", 10),
    ("03_aggregations_and_grouping", 10),
    ("04_window_functions_mastery", 15),
    ("05_subqueries_and_recursive_ctes", 10),
    ("06_data_modeling_and_scd", 10),
    ("07_indexing_and_query_optimization", 10),
    ("08_transactions_concurrency_and_locks", 10),
    ("09_mpp_and_cloud_warehouses", 10),
    ("10_production_incidents_and_triage", 10),
]

def test_exercise_count_and_distribution():
    total_found = 0
    for mod_name, expected_count in EXPECTED_MODULES:
        mod_dir = EXERCISES_DIR / mod_name
        assert mod_dir.exists(), f"Module directory missing: {mod_name}"
        files = list(mod_dir.glob("*.sql"))
        assert len(files) == expected_count, (
            f"Module {mod_name} expected {expected_count} files, found {len(files)}"
        )
        total_found += len(files)
    assert total_found == 105, f"Expected exactly 105 SQL exercises, found {total_found}"

def test_exercise_header_metadata():
    files = sorted(list(EXERCISES_DIR.glob("*/*.sql")))
    missing_metadata = []
    required_tags = [
        "EXERCISE:",
        "MODULE:",
        "LEVEL:",
        "ENGINES:",
        "BUSINESS CONTEXT:",
        "PROBLEM STATEMENT:",
        "-- --- [SOLUTION QUERY] ---"
    ]
    
    for f in files:
        content = f.read_text(encoding="utf-8")
        for tag in required_tags:
            if tag not in content:
                missing_metadata.append(f"{f.name} missing required tag: '{tag}'")
                
    assert not missing_metadata, "\n".join(missing_metadata)

if __name__ == "__main__":
    print("Running SQL Integrity Verification...")
    test_exercise_count_and_distribution()
    test_exercise_header_metadata()
    print("[PASS] SQL integrity and metadata verification passed successfully (105/105 exercises)!")
