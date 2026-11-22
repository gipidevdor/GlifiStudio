#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Compare complete CLI bytes against a frozen executable on synthetic inputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    options = parser.parse_args()
    reference = options.reference.resolve()
    candidate = options.candidate.resolve()
    workspace = options.workspace.resolve()
    records = []

    def run(binary: Path, arguments: list[str]) -> subprocess.CompletedProcess:
        return subprocess.run(
            [str(binary), *arguments], capture_output=True, timeout=60, check=False
        )

    with tempfile.TemporaryDirectory(prefix="GlifiStructureCLI280-") as temporary:
        root = Path(temporary)

        def compare(name: str, arguments: list[str]) -> None:
            before = run(reference, arguments)
            after = run(candidate, arguments)
            same = (
                before.returncode == after.returncode
                and before.stdout == after.stdout
                and before.stderr == after.stderr
            )
            assert str(root).encode() not in before.stdout + before.stderr
            assert str(root).encode() not in after.stdout + after.stderr
            records.append({
                "case": name,
                "equal": same,
                "reference": {
                    "exitCode": before.returncode,
                    "stdoutSHA256": digest(before.stdout),
                    "stderrSHA256": digest(before.stderr),
                },
                "candidate": {
                    "exitCode": after.returncode,
                    "stdoutSHA256": digest(after.stdout),
                    "stderrSHA256": digest(after.stderr),
                },
            })
            assert same, f"CLI compatibility mismatch: {name}"

        for name, arguments in [
            ("status-text", ["status"]),
            ("status-json", ["--format", "json", "status"]),
            ("usage-empty", []),
            ("usage-unknown-command", ["unknown-command"]),
            ("usage-unknown-format", ["--format", "xml", "status"]),
        ]:
            compare(name, arguments)

        cases = json.loads(
            (workspace / "Fixtures/TextAnalysis/v1/cases.json").read_text()
        )["cases"]
        for case in cases:
            request = root / (case["id"] + ".json")
            request.write_text(json.dumps(case["request"], ensure_ascii=False))
            for output_format in ["json", "text"]:
                compare(
                    case["id"] + "-" + output_format,
                    ["--format", output_format, "text-analysis", "--request", str(request)],
                )

        malformed = root / "malformed.json"
        malformed.write_bytes(b"{")
        compare("text-analysis-invalid-json", [
            "--format", "json", "text-analysis", "--request", str(malformed),
        ])

        project = root / "Synthetic.glifi"
        empty = root / "Empty.glifi"
        for destination in [project, empty]:
            result = run(reference, ["--format", "json", "project", "create", str(destination)])
            assert result.returncode == 0, "Synthetic project setup failed"
        imported = run(reference, [
            "--format", "json", "import", str(project),
            str(workspace / "Fixtures/Persistence/v1/basic/source.txt"),
            str(workspace / "Fixtures/Markdown/v1/source.md"),
        ])
        assert imported.returncode == 0, "Synthetic import setup failed"
        sources = json.loads(imported.stdout)["result"]["project"]["sources"]
        source = sources[0]["sourceRevisionID"]
        ast = root / "query.json"
        ast.write_text(json.dumps({
            "schema": "studio.glifi.query-ast", "schemaVersion": 1,
            "grammarVersion": "glifi-query-v1", "root": {"type": "matchAll"},
        }))
        commands = [
            ("project-info", ["project", "info", str(project)]),
            ("project-validate", ["project", "validate", str(project)]),
            ("query-text", ["query", str(project), "--text", "normalized:due"]),
            ("query-ast", ["query", str(project), "--ast", str(ast)]),
            ("query-invalid", ["query", str(project), "--text", "(("]),
            ("investigation-list", ["investigation", "list", str(project)]),
            ("qualitative-state", ["qualitative", "state", str(project)]),
            ("source-segments", ["qualitative", "segments", str(project), "--source", source]),
            ("source-passage", ["qualitative", "passage", str(project), "--source", source,
                                "--sentences", "1-1"]),
            ("source-invalid-id", ["qualitative", "segments", str(project), "--source", "invalid"]),
            ("import-unreadable", ["import", str(project), str(root / "missing.txt")]),
            ("empty-query", ["query", str(empty), "--text", "normalized:due"]),
            ("missing-project", ["project", "info", str(root / "missing.glifi")]),
            ("plan-invalid-json", ["plan", str(project), "--request", str(malformed)]),
            ("execute-invalid-json", ["execute", str(project), "--request", str(malformed)]),
            ("visualize-invalid-json", ["visualize", str(project), "--request", str(malformed)]),
        ]
        for name, arguments in commands:
            for output_format in ["json", "text"]:
                compare(name + "-" + output_format, ["--format", output_format, *arguments])

    result = {
        "schemaIdentifier": "studio.glifi.verification.cli-compatibility.v1",
        "referenceBinarySHA256": digest(reference.read_bytes()),
        "candidateBinarySHA256": digest(candidate.read_bytes()),
        "caseCount": len(records),
        "allBytesEqual": all(record["equal"] for record in records),
        "comparison": "Complete stdout, stderr and exit code; no fields removed or normalized",
        "scope": "Synthetic deterministic requests and read-only/failing project operations; "
                 "owned execution streams and successful writes are covered by the full gate",
        "cases": records,
    }
    options.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(f"CLI compatibility: {len(records)} cases, complete bytes and exit codes identical")


if __name__ == "__main__":
    main()
