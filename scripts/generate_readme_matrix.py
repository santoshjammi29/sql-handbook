#!/usr/bin/env python3
"""
Generates the comprehensive Markdown Curriculum Matrix for README.md
by inspecting headers across all 105 SQL exercise files.
"""

from pathlib import Path
import re

BASE_DIR = Path(__file__).resolve().parent.parent
EXERCISES_DIR = BASE_DIR / "exercises"

def extract_meta(file_path: Path):
    content = file_path.read_text(encoding="utf-8")
    meta = {
        "id": file_path.name.split("_")[0],
        "file": file_path.name,
        "rel_path": f"exercises/{file_path.parent.name}/{file_path.name}",
        "module": file_path.parent.name,
        "level": "Intermediate",
        "engines": "ANSI / Multi-Engine",
        "scenario": ""
    }

    for line in content.splitlines():
        if "LEVEL:" in line:
            meta["level"] = line.split("LEVEL:")[1].strip()
        elif "BUSINESS CONTEXT:" in line:
            pass
        elif "PROBLEM STATEMENT:" in line:
            pass

    # Extract first sentence of business context
    m_ctx = re.search(r"BUSINESS CONTEXT:\s*--\s*(.*?)(?:\.|\n--\s*PROBLEM)", content, re.DOTALL)
    if m_ctx:
        clean_text = " ".join([l.replace("--", "").strip() for l in m_ctx.group(1).splitlines()])
        meta["scenario"] = clean_text.split(".")[0].strip() + "."
    else:
        meta["scenario"] = file_path.stem.replace("_", " ").title()

    return meta

def generate_markdown_table():
    files = sorted(list(EXERCISES_DIR.glob("*/*.sql")))
    
    current_module = ""
    md_output = []
    
    for f in files:
        meta = extract_meta(f)
        if meta["module"] != current_module:
            current_module = meta["module"]
            pretty_mod = current_module.replace("_", " ").title()
            md_output.append(f"\n### 📂 Module: {pretty_mod}\n")
            md_output.append("| # | Exercise & Code | Difficulty | Real-World Scenario | Engines |")
            md_output.append("| :---: | :--- | :---: | :--- | :---: |")

        ex_link = f"[`{meta['file']}`]({meta['rel_path']})"
        md_output.append(
            f"| **{meta['id']}** | {ex_link} | `{meta['level']}` | {meta['scenario']} | `PG` `Duck` `Spark` `Snow` |"
        )
        
    return "\n".join(md_output)

if __name__ == "__main__":
    table = generate_markdown_table()
    out_file = BASE_DIR / "scripts" / "curriculum_matrix.md"
    out_file.write_text(table, encoding="utf-8")
    print(f"Generated curriculum matrix ({len(list(EXERCISES_DIR.glob('*/*.sql')))} exercises) -> scripts/curriculum_matrix.md")
