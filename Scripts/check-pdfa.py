#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Validate the PDFs exported by the GlifiCore tests with veraPDF (PDF/A-2u).

The export tests copy every rendered report into the directory named by
GLIFI_ORACLE_PDF_DIRECTORY. With --directory the script validates an existing directory
(used by Scripts/verify.sh after the test run); otherwise it runs the export tests into a
temporary directory first. veraPDF is looked up in VERAPDF, then on PATH, then in
~/Library/Application Support/veraPDF; without it the check is skipped unless --require.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
DEFAULT = Path.home() / "Library/Application Support/veraPDF/verapdf"


def locate() -> str | None:
    candidates = [os.environ.get("VERAPDF"), shutil.which("verapdf"), str(DEFAULT)]
    return next((c for c in candidates if c and Path(c).is_file()), None)


def java_environment() -> dict[str, str]:
    environment = dict(os.environ)
    if "JAVA_HOME" not in environment and Path("/usr/libexec/java_home").exists():
        home = subprocess.run(
            ["/usr/libexec/java_home"], capture_output=True, text=True, check=False
        ).stdout.strip()
        if home:
            environment["JAVA_HOME"] = home
    return environment


def export_pdfs(directory: Path) -> None:
    scratch = Path(tempfile.mkdtemp(prefix="GlifiPDFA-"))
    try:
        subprocess.run(
            [
                "swift", "test", "--package-path", str(PROJECT / "Packages/GlifiCore"),
                "--scratch-path", str(scratch), "--filter", "scientific",
            ],
            env={**os.environ, "GLIFI_ORACLE_PDF_DIRECTORY": str(directory)},
            check=True,
            capture_output=True,
        )
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def main() -> int:
    require = "--require" in sys.argv
    verapdf = locate()
    if verapdf is None:
        print("Validazione PDF/A: veraPDF assente, controllo saltato")
        return 1 if require else 0
    if "--directory" in sys.argv:
        directory = Path(sys.argv[sys.argv.index("--directory") + 1])
        cleanup = None
    else:
        directory = Path(tempfile.mkdtemp(prefix="GlifiPDFAOutput-"))
        cleanup = directory
        export_pdfs(directory)
    try:
        pdfs = sorted(directory.glob("*.pdf"))
        if not pdfs:
            print("Validazione PDF/A: nessun PDF esportato da validare", file=sys.stderr)
            return 1
        result = subprocess.run(
            [verapdf, "--flavour", "2u", "--format", "text", *map(str, pdfs)],
            capture_output=True, text=True, env=java_environment(), check=False,
        )
        lines = [line for line in result.stdout.splitlines() if line.startswith(("PASS", "FAIL"))]
        failed = [line for line in lines if line.startswith("FAIL")]
        if len(lines) != len(pdfs) or failed:
            print(result.stdout[-2000:], file=sys.stderr)
            return 1
        print(f"Validazione PDF/A-2u con veraPDF: {len(pdfs)} PDF conformi")
        return 0
    finally:
        if cleanup is not None:
            shutil.rmtree(cleanup, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
