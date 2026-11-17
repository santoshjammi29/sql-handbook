#!/usr/bin/env python3
"""
CLI Runner: Executes all 105 SQL exercises in The SQL Handbook,
benchmarks execution time, and displays a production test scorecard.
"""

import sys
import time
import argparse
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))
from tests.test_sql_execution import run_exercise

EXERCISES_DIR = BASE_DIR / "exercises"

def main():
    parser = argparse.ArgumentParser(description="The SQL Handbook Exercise Runner")
    parser.add_argument("--quiet", action="store_true", help="Minimal output for CI")
    parser.add_argument("--module", type=str, default=None, help="Filter by module name")
    args = parser.parse_args()

    files = sorted(list(EXERCISES_DIR.glob("*/*.sql")))
    if args.module:
        files = [f for f in files if args.module in f.parent.name]

    print("\n" + "=" * 80)
    print("⚡ THE SQL HANDBOOK: 105 PRODUCTION EXERCISE RUNNER & BENCHMARK")
    print("=" * 80)
    print(f"Targeting {len(files)} exercises across modules...\n")

    start_total = time.time()
    passed = 0
    failed = []

    current_mod = ""
    for f in files:
        mod_name = f.parent.name
        if mod_name != current_mod:
            current_mod = mod_name
            if not args.quiet:
                print(f"\n📂 [{current_mod}]")

        t0 = time.time()
        success, err = run_exercise(f)
        elapsed_ms = (time.time() - t0) * 1000

        if success:
            passed += 1
            if not args.quiet:
                print(f"  ✅ {f.name:<60} ({elapsed_ms:5.1f} ms)")
        else:
            failed.append((f.name, err))
            if not args.quiet:
                print(f"  ❌ {f.name:<60} FAILED: {err}")

    total_duration = time.time() - start_total

    print("\n" + "=" * 80)
    print("📊 EXECUTION SUMMARY")
    print("=" * 80)
    print(f"Total Exercises Executed: {len(files)}")
    print(f"Passed:                   {passed} / {len(files)} ({(passed/len(files))*100:.1f}%)")
    print(f"Failed:                   {len(failed)}")
    print(f"Total Wall-Clock Time:    {total_duration:.2f} seconds\n")

    if failed:
        print("❌ FAILURES DETECTED:")
        for name, err in failed:
            print(f"  - {name}: {err}")
        sys.exit(1)
    else:
        print("🎉 All production exercises passed with zero regressions!\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
