#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Exercise QueryAST CLI parity and hostile inputs against the built executable."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", required=True)
    parser.add_argument("--project", required=True)
    options = parser.parse_args()
    canary = "ZQXCANARY42"

    def run(*arguments: str, status: int = 0, code: str | None = None) -> dict:
        process = subprocess.run(
            [options.executable, "--format", "json", "query", options.project, *arguments],
            capture_output=True, text=True, timeout=30, check=False,
        )
        assert process.returncode == status, (process.returncode, process.stdout, process.stderr)
        assert canary not in process.stdout + process.stderr
        if status == 2:
            return {}
        envelope = json.loads(process.stderr if code is not None else process.stdout)
        assert envelope["cliProtocolVersion"] == 1
        assert envelope["command"] == "query"
        if code is not None:
            assert envelope["outcome"] == "failed"
            assert envelope["failure"]["code"] == code, envelope
            assert envelope["failure"]["operation"] == "query", envelope
            assert envelope["failure"]["arguments"] == [], envelope
        else:
            assert envelope["outcome"] == "succeeded", envelope
        return envelope

    with tempfile.TemporaryDirectory(prefix=f"GlifiAST-{canary}-") as temporary:
        root = Path(temporary)
        path = root / "query.json"

        def write(node: dict, **overrides: object) -> None:
            ast = {
                "schema": "studio.glifi.query-ast", "schemaVersion": 1,
                "grammarVersion": "glifi-query-v1", "root": node, **overrides,
            }
            path.write_text(json.dumps(ast), encoding="utf-8")

        leaf = {"type": "matchAll"}
        term = {"type": "term", "field": "normalized", "value": "due", "matchMode": "exact"}
        write(term)
        baseline = run("--text", "normalized:due")
        assert run("--ast", str(path)) == baseline
        compact = json.dumps(json.loads(path.read_text()), separators=(",", ":"), sort_keys=True)
        path.write_text(compact, encoding="utf-8")
        assert run("--ast", str(path)) == baseline
        path.write_bytes(compact.encode() + b" " * (65_536 - len(compact.encode())))
        assert run("--ast", str(path)) == baseline
        with path.open("ab") as stream:
            stream.write(b" ")
        run("--ast", str(path), status=7, code="query.byte-limit-exceeded")
        for data in [b"", canary.encode(), b"{}", b"\xff"]:
            path.write_bytes(data)
            run("--ast", str(path), status=3, code="query.invalid-ast")
        for key, value in [("schema", canary), ("schemaVersion", 2), ("grammarVersion", canary)]:
            write(leaf, **{key: value})
            run("--ast", str(path), status=10, code="query.incompatible-ast")
        write({"type": "or", "children": [leaf] * 1_024})
        run("--ast", str(path), status=7, code="query.node-limit-exceeded")
        deep = leaf
        for _ in range(33):
            deep = {"type": "not", "child": deep}
        write(deep)
        run("--ast", str(path), status=7, code="query.depth-limit-exceeded")
        write({"type": "regex", "field": "form", "pattern": canary, "flags": 4})
        run("--ast", str(path), status=3, code="query.regex-rejected")
        write(term)
        link = root / "linked.json"
        link.symlink_to(path)
        fifo = root / "fifo.json"
        os.mkfifo(fifo)
        for invalid in [link, root, fifo]:
            run("--ast", str(invalid), status=3, code="query.ast-not-regular-file")
        run("--ast", str(root / "missing.json"), status=6, code="query.ast-unreadable")
        for arguments in [
            (), ("--ast",), ("--text",), ("--ast", str(path), "--text", "due"),
            ("--text", "due", "--ast", str(path)), ("--ast", str(path), "--ast", str(path)),
        ]:
            run(*arguments, status=2)
        assert run("--text", "normalized:due") == baseline
        assert run("--ast", str(path)) == baseline
    print("QueryAST CLI: parità, limiti, file ostili, argomenti e privacy superati")


if __name__ == "__main__":
    main()
