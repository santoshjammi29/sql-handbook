#!/usr/bin/env python3
"""
Exercise Builder: Generates all 105 battle-tested production SQL exercises
across the 10 core modules of The SQL Handbook.
"""

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

def write_sql(module_dir: str, filename: str, content: str):
    target_dir = EXERCISES_DIR / module_dir
    target_dir.mkdir(parents=True, exist_ok=True)
    file_path = target_dir / filename
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\n")
    print(f"Generated: {module_dir}/{filename}")

print("Initializing exercise generation pipeline...")
