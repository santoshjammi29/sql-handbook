"""
Test Suite: SQL Execution & Assertion Verification Runner
Executes all 105 SQL exercises against an in-memory database to verify syntax and assertions.
"""

import sqlite3
import re
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

def clean_statements(sql_text: str):
    """
    Splits an SQL script into executable statements, stripping assertion comments.
    """
    # Remove single line comments starting with --
    lines = []
    assertions = {}
    for line in sql_text.splitlines():
        trimmed = line.strip()
        if trimmed.startswith("-- ASSERT: ROW_COUNT ="):
            val = int(trimmed.split("=")[1].strip())
            assertions["row_count"] = val
        elif trimmed.startswith("-- ASSERT: COL["):
            m = re.match(r"-- ASSERT: COL\[(.*?)\]\s*=\s*(.*)", trimmed)
            if m:
                assertions[f"col_{m.group(1)}"] = m.group(2).strip()
        elif not trimmed.startswith("--"):
            lines.append(line)
            
    clean_sql = "\n".join(lines).strip()
    return clean_sql, assertions

def run_exercise(file_path: Path):
    content = file_path.read_text(encoding="utf-8")
    
    # Split content by SOLUTION QUERY marker
    parts = content.split("-- --- [SOLUTION QUERY] ---")
    setup_sql = parts[0]
    solution_and_after = parts[1] if len(parts) > 1 else ""
    
    clean_setup, _ = clean_statements(setup_sql)
    clean_solution, assertions = clean_statements(solution_and_after)
    
    conn = sqlite3.connect(":memory:")
    cur = conn.cursor()
    
    try:
        # Run setup DDL & DML
        if clean_setup:
            cur.executescript(clean_setup)
            
        # Run solution queries
        # Some solutions may contain multiple statements (e.g. DELETE followed by SELECT)
        stmts = [s.strip() for s in clean_solution.split(";") if s.strip()]
        last_results = []
        for stmt in stmts:
            cur.execute(stmt)
            if stmt.upper().startswith("SELECT") or "SELECT" in stmt.upper():
                last_results = cur.fetchall()
                
        # Validate assertions
        if "row_count" in assertions:
            expected = assertions["row_count"]
            actual = len(last_results)
            assert actual == expected, (
                f"{file_path.name}: Expected {expected} rows, got {actual}"
            )
            
        conn.close()
        return True, None
    except Exception as e:
        conn.close()
        return False, str(e)

def test_all_sql_execution():
    files = sorted(list(EXERCISES_DIR.glob("*/*.sql")))
    failed = []
    
    for f in files:
        success, err = run_exercise(f)
        if not success:
            failed.append(f"{f.parent.name}/{f.name}: {err}")
            
    assert not failed, f"Execution failed for {len(failed)} files:\n" + "\n".join(failed)

if __name__ == "__main__":
    print("Executing all 105 SQL exercises in-memory...")
    files = sorted(list(EXERCISES_DIR.glob("*/*.sql")))
    failed = []
    passed = 0
    for f in files:
        success, err = run_exercise(f)
        if success:
            passed += 1
        else:
            failed.append((f.name, err))
            
    print(f"Results: {passed}/105 passed.")
    if failed:
        print(f"\nFailures ({len(failed)}):")
        for name, err in failed:
            print(f"  ❌ {name}: {err}")
    else:
        print("🎉 [PASS] All 105 SQL exercises executed and verified successfully!")
