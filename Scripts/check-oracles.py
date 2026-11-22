#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Rerun the independent numerical oracles of GlifiCore and check them.

Each R script under Packages/GlifiCore/Tests/Oracles/R and each Python script under
Packages/GlifiCore/Tests/Oracles/Python prints lines «KEY value…». The check:

1. reruns every oracle and compares its output with expected.txt (relative 1e-12, hexadecimal
   values exactly), so a change of R, of its packages or of the scripts is detected;
2. requires every non-integer value of a non-INFO key to appear, in absolute value, as a numeric
   literal of the Swift tests (tolerance 1e-12 relative), so tests and oracles cannot diverge.

Without Rscript or the required R packages the check is skipped (exit 0) unless --require is
given; --update rewrites expected.txt from a fresh run.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
ORACLES = PROJECT / "Packages/GlifiCore/Tests/Oracles"
EXPECTED = ORACLES / "expected.txt"
SWIFT_TESTS = PROJECT / "Packages/GlifiCore/Tests/GlifiCoreTests"
LITERAL = re.compile(r"(?<![\w.])-?\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][-+]?\d+)?")


def run_oracles() -> list[str]:
    lines: list[str] = []
    for script in sorted((ORACLES / "R").glob("*.R")):
        if script.name == "common.R":
            continue
        result = subprocess.run(
            ["Rscript", str(script)], capture_output=True, text=True, check=False
        )
        if result.returncode != 0:
            raise RuntimeError(f"{script.name}: {result.stderr.strip()[-400:]}")
        lines += [f"{script.stem}:{line.strip()}" for line in result.stdout.splitlines() if line.strip()]
    for script in sorted((ORACLES / "Python").glob("*.py")):
        result = subprocess.run(
            [sys.executable, str(script)], capture_output=True, text=True, check=True
        )
        lines += [f"{script.stem}:{line.strip()}" for line in result.stdout.splitlines() if line.strip()]
    return lines


def parse(line: str) -> tuple[str, list[str]]:
    key, *values = line.split()
    return key, values


def close(left: float, right: float) -> bool:
    return abs(left - right) <= max(1e-12 * max(abs(left), abs(right)), 1e-15)


def compare(expected: list[str], actual: list[str]) -> list[str]:
    errors: list[str] = []
    if len(expected) != len(actual):
        return [f"righe attese {len(expected)}, ottenute {len(actual)}"]
    for want, got in zip(expected, actual):
        want_key, want_values = parse(want)
        got_key, got_values = parse(got)
        if want_key != got_key or len(want_values) != len(got_values):
            errors.append(f"struttura diversa: {want_key} / {got_key}")
            continue
        for a, b in zip(want_values, got_values):
            if a.startswith("0x") or b.startswith("0x"):
                ok = a == b
            else:
                ok = close(float(a), float(b))
            if not ok:
                errors.append(f"{want_key}: atteso {a}, ottenuto {b}")
    return errors


def swift_literals() -> list[float]:
    values: list[float] = []
    for path in SWIFT_TESTS.glob("*.swift"):
        for token in LITERAL.findall(path.read_text(encoding="utf-8")):
            try:
                values.append(abs(float(token.replace("_", ""))))
            except ValueError:
                continue
    return sorted(values)


def check_links(lines: list[str]) -> list[str]:
    literals = swift_literals()
    hexadecimal = {
        int(token.replace("_", ""), 16)
        for path in SWIFT_TESTS.glob("*.swift")
        for token in re.findall(r"0x[0-9A-Fa-f_]+", path.read_text(encoding="utf-8"))
    }
    errors: list[str] = []
    for line in lines:
        key, values = parse(line)
        if key.split(":", 1)[1].startswith("INFO_"):
            continue
        for value in values:
            if value.startswith("0x"):
                if int(value, 16) not in hexadecimal:
                    errors.append(f"{key}: {value} assente dai test Swift")
                continue
            number = abs(float(value))
            if number < 1e-9 or number == round(number):
                continue
            if not any(close(number, literal) for literal in literals):
                errors.append(f"{key}: {value} assente dai test Swift")
    return errors


def main() -> int:
    require = "--require" in sys.argv
    if shutil.which("Rscript") is None:
        print("Oracoli numerici: Rscript assente, controllo saltato")
        return 1 if require else 0
    try:
        actual = run_oracles()
    except RuntimeError as error:
        if "there is no package" in str(error) or "nessun pacchetto" in str(error):
            print(f"Oracoli numerici: pacchetti R mancanti, controllo saltato ({error})")
            return 1 if require else 0
        print(f"Oracoli numerici: esecuzione fallita: {error}", file=sys.stderr)
        return 1
    if "--update" in sys.argv:
        EXPECTED.write_text("\n".join(actual) + "\n", encoding="utf-8")
        print(f"Oracoli numerici: {len(actual)} righe scritte in {EXPECTED.relative_to(PROJECT)}")
        return 0
    expected = EXPECTED.read_text(encoding="utf-8").splitlines()
    errors = compare(expected, actual) + check_links(actual)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    print(f"Oracoli numerici: {len(actual)} righe riprodotte e collegate ai test Swift")
    return 0


if __name__ == "__main__":
    sys.exit(main())
