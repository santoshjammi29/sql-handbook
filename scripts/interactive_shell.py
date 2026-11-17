#!/usr/bin/env python3
"""
Interactive SQL Sandbox:
Loads an exercise's schema and seed data into an in-memory database,
prints the problem context, and opens an interactive SQL REPL for practice.

Usage:
    python scripts/interactive_shell.py 038
    python scripts/interactive_shell.py gaps_and_islands
"""

import sys
import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

def find_exercise(query: str):
    files = list(EXERCISES_DIR.glob(f"*/*{query}*.sql"))
    if not files:
        # Try matching numeric prefix e.g. "38" -> "038"
        if query.isdigit():
            padded = f"{int(query):03d}"
            files = list(EXERCISES_DIR.glob(f"*/*{padded}*.sql"))
    return files[0] if files else None

def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/interactive_shell.py <exercise_number_or_name>")
        print("Example: python scripts/interactive_shell.py 038")
        sys.exit(1)

    target_query = sys.argv[1]
    match = find_exercise(target_query)
    if not match:
        print(f"❌ No exercise matching '{target_query}' found in {EXERCISES_DIR}")
        sys.exit(1)

    print(f"\n⚡ Loading Exercise: {match.name}")
    print(f"📂 Module:   {match.parent.name}")
    print("=" * 80)

    content = match.read_text(encoding="utf-8")
    
    # Extract Context and Problem Statement from header
    lines = content.splitlines()
    in_context = False
    in_problem = False
    context_lines = []
    problem_lines = []

    for line in lines:
        if "BUSINESS CONTEXT:" in line:
            in_context = True
            in_problem = False
            continue
        elif "PROBLEM STATEMENT:" in line:
            in_context = False
            in_problem = True
            continue
        elif "PRODUCTION PITFALL:" in line or "=====" in line:
            in_context = False
            in_problem = False

        if in_context and line.strip().startswith("--"):
            context_lines.append(line.replace("--", "").strip())
        elif in_problem and line.strip().startswith("--"):
            problem_lines.append(line.replace("--", "").strip())

    if context_lines:
        print("\n💼 BUSINESS CONTEXT:")
        print("  " + "\n  ".join(context_lines))
    if problem_lines:
        print("\n🎯 PROBLEM STATEMENT:")
        print("  " + "\n  ".join(problem_lines))

    # Initialize in-memory SQLite
    conn = sqlite3.connect(":memory:")
    cur = conn.cursor()

    # Split setup from solution
    parts = content.split("-- --- [SOLUTION QUERY] ---")
    setup_sql = parts[0]
    
    # Execute setup DDL & DML
    clean_setup = "\n".join([
        l for l in setup_sql.splitlines() 
        if not l.strip().startswith("--")
    ])
    if clean_setup.strip():
        cur.executescript(clean_setup)
        print("\n✅ Schema & test seed data loaded into in-memory database.")

    # Inspect available tables
    cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = [r[0] for r in cur.fetchall()]
    print(f"📋 Available Tables: {', '.join(tables)}")
    print("=" * 80)
    print("Type your SQL query below (end with ';' to execute, or 'exit'/'quit' to exit):")
    print("Type '.solution' to view the reference production solution.\n")

    query_buffer = []
    while True:
        try:
            prompt = "sql> " if not query_buffer else "...> "
            line = input(prompt).strip()
            if line.lower() in ("exit", "quit", "\\q"):
                print("Exiting SQL sandbox.")
                break
            if line.lower() == ".solution":
                if len(parts) > 1:
                    print("\n📖 REFERENCE PRODUCTION SOLUTION:")
                    print("-" * 60)
                    print(parts[1].strip())
                    print("-" * 60 + "\n")
                continue

            query_buffer.append(line)
            if line.endswith(";"):
                sql = " ".join(query_buffer)
                query_buffer = []
                try:
                    cur.execute(sql)
                    rows = cur.fetchall()
                    if cur.description:
                        col_names = [d[0] for d in cur.description]
                        print("\n" + " | ".join(f"{col:<18}" for col in col_names))
                        print("-" * (len(col_names) * 21))
                        for r in rows:
                            print(" | ".join(f"{str(v):<18}" for v in r))
                        print(f"({len(rows)} rows)\n")
                    else:
                        print("Query executed successfully (0 rows returned).\n")
                except Exception as e:
                    print(f"❌ SQL Error: {e}\n")
        except (KeyboardInterrupt, EOFError):
            print("\nExiting.")
            break

if __name__ == "__main__":
    main()
