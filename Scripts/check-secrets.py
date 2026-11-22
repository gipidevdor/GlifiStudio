#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Detect high-confidence secrets and forbidden credential files without printing values."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
FORBIDDEN_NAMES = {".env", ".netrc"}
FORBIDDEN_SUFFIXES = {".cer", ".key", ".mobileprovision", ".p12", ".p8", ".pem"}
PATTERNS = {
    "chiave privata": re.compile(
        rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
    ),
    "token GitHub": re.compile(rb"gh[pousr]_[A-Za-z0-9]{30,}"),
    "access key AWS": re.compile(rb"AKIA[0-9A-Z]{16}"),
    "chiave API OpenAI": re.compile(rb"sk-(?:proj-)?[A-Za-z0-9_-]{20,}"),
}


def candidate_paths() -> list[Path]:
    """Return versionable files, including currently untracked files."""
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=PROJECT_DIRECTORY,
        check=True,
        capture_output=True,
    )
    return [
        PROJECT_DIRECTORY / raw.decode("utf-8")
        for raw in result.stdout.split(b"\0")
        if raw
    ]


def main() -> int:
    """Scan repository candidates and report paths only."""
    errors: list[str] = []

    for path in candidate_paths():
        if not path.is_file():
            continue

        relative_path = path.relative_to(PROJECT_DIRECTORY)
        name = path.name.lower()
        if name in FORBIDDEN_NAMES or (
            name.startswith(".env.") and name != ".env.example"
        ):
            errors.append(f"file di configurazione sensibile: {relative_path}")
            continue
        if path.suffix.lower() in FORBIDDEN_SUFFIXES:
            errors.append(f"materiale di credenziale o firma: {relative_path}")
            continue

        try:
            body = path.read_bytes()
        except OSError as error:
            errors.append(f"file non leggibile: {relative_path} ({error})")
            continue

        if b"\0" in body:
            continue
        for description, pattern in PATTERNS.items():
            if pattern.search(body):
                errors.append(f"possibile {description}: {relative_path}")

    if errors:
        print("Secret validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Secrets: no high-confidence credentials or signing material detected")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
