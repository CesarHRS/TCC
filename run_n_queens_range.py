#!/usr/bin/env python3
import os
import re
import subprocess
import sys

ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
BUILD_DIR = os.path.join(ROOT_DIR, "build")
CPP_SOURCE = os.path.join(ROOT_DIR, "cpp", "n_queens", "main.cpp")
OUTPUT_FILE = os.path.join(ROOT_DIR, "n_queens_1-75.out")

AVERAGE_RE = re.compile(r"Average time:\s*(\d+)\s*ns")
RESULT_RE = re.compile(r"Overall result:\s*(YES|NO)\b")

os.makedirs(BUILD_DIR, exist_ok=True)

with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
    out.write("# N-Queens average times for N=1..75 (10 runs each)\n")
    out.write("# Format: N average_time_ns status\n")
    for n in range(1, 76):
        bin_path = os.path.join(BUILD_DIR, f"nqueens_{n}")
        compile_cmd = [
            "g++",
            "-O3",
            "-std=c++17",
            f"-DN={n}",
            "-o",
            bin_path,
            CPP_SOURCE,
        ]
        print(f"[{n}] Compiling...")
        compile_proc = subprocess.run(compile_cmd, capture_output=True, text=True)
        if compile_proc.returncode != 0:
            print(f"[{n}] Compilation failed: {compile_proc.stderr.strip()}")
            out.write(f"{n} ERROR_COMPILE\n")
            continue

        print(f"[{n}] Running...")
        run_proc = subprocess.run([bin_path], capture_output=True, text=True)
        stdout = run_proc.stdout
        stderr = run_proc.stderr
        if run_proc.returncode != 0:
            print(f"[{n}] Execution failed (return code {run_proc.returncode})")
            if stderr:
                print(stderr.strip())
            avg_match = AVERAGE_RE.search(stdout)
            result_match = RESULT_RE.search(stdout)
            if avg_match:
                average_ns = avg_match.group(1)
                status = result_match.group(1) if result_match else "NO"
                out.write(f"{n} {average_ns} {status} (EXEC_ERROR)\n")
            else:
                out.write(f"{n} ERROR_RUN\n")
            continue

        avg_match = AVERAGE_RE.search(stdout)
        result_match = RESULT_RE.search(stdout)
        if not avg_match:
            print(f"[{n}] Could not parse average time from output")
            print(stdout)
            out.write(f"{n} ERROR_PARSE\n")
            continue

        average_ns = avg_match.group(1)
        status = result_match.group(1) if result_match else "UNKNOWN"
        out.write(f"{n} {average_ns} {status}\n")
        print(f"[{n}] average={average_ns} ns status={status}")

print(f"Results written to {OUTPUT_FILE}")
