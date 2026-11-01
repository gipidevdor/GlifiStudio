#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check complete native/CLI parity and bounded request failure contracts."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "Fixtures/TextAnalysis/v1/cases.json"


def compare(actual, expected, context="", subset=False):
    if isinstance(expected, dict):
        assert isinstance(actual, dict), context
        if not subset:
            assert actual.keys() == expected.keys(), context
        for key, value in expected.items():
            assert key in actual, context + "." + key
            compare(actual[key], value, context + "." + key, subset)
    elif isinstance(expected, list):
        assert isinstance(actual, list) and len(actual) == len(expected), context
        for index, (left, right) in enumerate(zip(actual, expected, strict=True)):
            compare(left, right, context + f"[{index}]", subset)
    elif isinstance(expected, bool) or not isinstance(expected, (float, int)):
        assert type(actual) is type(expected) and actual == expected, context
    elif isinstance(expected, int):
        assert isinstance(actual, int) and not isinstance(actual, bool) and actual == expected, context
    else:
        assert isinstance(actual, (float, int)) and not isinstance(actual, bool), context
        assert math.isfinite(actual) and math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12), context


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--parity-directory", type=Path, required=True)
    args = parser.parse_args()
    binary = args.binary.resolve()
    cases = json.loads(FIXTURES.read_text())["cases"]
    assert len(cases) == 15 and len({case["id"] for case in cases}) == len(cases)
    checks = 0
    with tempfile.TemporaryDirectory(prefix="GlifiTextAnalysisCLI-") as temporary:
        directory = Path(temporary)

        def invoke(path, *, text=False, extra=()):
            command = [str(binary), "--format", "text" if text else "json",
                       "text-analysis", "--request", str(path), *extra]
            return subprocess.run(command, capture_output=True, text=True, timeout=30, check=False)

        for case in cases:
            path = directory / (case["id"] + ".json")
            path.write_text(json.dumps(case["request"], ensure_ascii=False))
            completed = invoke(path)
            assert completed.returncode == 0 and completed.stderr == "", case["id"]
            envelope = json.loads(completed.stdout)
            assert envelope.keys() == {"cliProtocolVersion", "command", "outcome", "result"}
            assert envelope["cliProtocolVersion"] == 1
            assert envelope["command"] == "text-analysis" and envelope["outcome"] == "succeeded"
            expected = json.loads((args.parity_directory / (case["id"] + ".json")).read_text())
            canonical = (args.parity_directory / (case["id"] + ".request.json")).read_bytes()
            assert envelope["result"]["requestDigest"] == hashlib.sha256(canonical).hexdigest()
            compare(envelope["result"], expected, case["id"])
            assert envelope["result"]["methodIdentifier"] == case["methodIdentifier"], case["id"]
            assert envelope["result"]["validationStatus"] == case["validationStatus"], case["id"]
            if "expected" in case:
                compare(envelope["result"]["result"], case["expected"], case["id"], subset=True)
            repeated = invoke(path)
            compare(json.loads(repeated.stdout), envelope, case["id"] + ".repeated")
            assert repeated.returncode == 0 and repeated.stderr == ""
            checks += 2

        path = directory / "coding.json"
        human = invoke(path, text=True)
        assert human.returncode == 0 and human.stderr == ""
        assert human.stdout.startswith("Analisi completata · coding · ")
        compare(json.loads(human.stdout.split("\n", 1)[1]), json.loads((args.parity_directory / "coding.json").read_text()))
        checks += 1

        def rejects(raw, code, category):
            nonlocal checks
            path = directory / "secret-canary-request.json"
            path.write_bytes(raw)
            completed = invoke(path)
            assert completed.returncode == code and completed.stdout == "", completed
            envelope = json.loads(completed.stderr)
            assert envelope["command"] == "text-analysis" and envelope["outcome"] == "failed"
            failure = envelope["failure"]
            assert failure["category"] == category and failure["arguments"] == []
            assert "secret-canary" not in completed.stderr and str(directory) not in completed.stderr
            checks += 1

        schema = {"schema": "studio.glifi.text-analysis-request", "schemaVersion": 1}
        def encoded(fields):
            return json.dumps({**schema, **fields}).encode()
        rejects(b"{", 3, "invalidInput")
        rejects(b"\xff", 3, "invalidInput")
        rejects(encoded({"operation": "missing"}), 3, "invalidInput")
        rejects(encoded({"operation": "dissimilarities", "matrix": [[1], [2]], "metric": "unknown"}), 3, "invalidInput")
        rejects(encoded({"operation": "mds", "matrix": [[0, 1], [1, 0]], "method": "unknown"}), 3, "invalidInput")

        rejects(encoded({"operation": "mds", "matrix": [[0, 1], [1, 0]], "seed": None}), 3, "invalidInput")
        rejects(encoded({"operation": "mds", "matrix": [[0, 1], [1, 0]], "secret-canary": 1}), 3, "invalidInput")
        rejects(encoded({"operation": "mds", "matrix": [[0, 1], [1, 0]], "schemaVersion": 2}), 10, "incompatibleVersion")
        rejects(b'{"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"mds","matrix":[[0,1],[1,0]],"seed":1,"\\u0073eed":2}', 3, "invalidInput")
        rejects(b"[" * 33 + b"0" + b"]" * 33, 7, "insufficientResources")
        rejects(b" " * (1_048_576 + 1), 7, "insufficientResources")
        rejects(encoded({"operation": "coding", "units": [{"id": "secret-canary", "text": "secret-canary"}],
                         "rules": "*A\n<>missing-->secret-canary"}), 5, "insufficientData")
        rejects(encoded({"operation": "som", "matrix": [[0], [1]], "width": 0, "height": 1, "seed": 0}), 3, "invalidInput")

        if os.geteuid() != 0:
            protected = directory / "secret-canary-protected.json"
            protected.write_text(json.dumps(cases[0]["request"]))
            protected.chmod(0)
            try:
                completed = invoke(protected)
                assert completed.returncode == 6 and completed.stdout == ""
                failure = json.loads(completed.stderr)["failure"]
                assert failure["category"] == "authorizationDenied"
                assert failure["retryDisposition"] == "afterUserAction"
                assert failure["arguments"] == [] and "secret-canary" not in completed.stderr
                checks += 1
            finally:
                protected.chmod(0o600)

        target = directory / "coding.json"
        symlink = directory / "symbolic.json"
        symlink.symlink_to(target)
        fifo = directory / "pipe.json"
        os.mkfifo(fifo)
        for special in (symlink, fifo, directory, directory / "missing.json"):
            completed = invoke(special)
            assert completed.returncode == 3 and completed.stdout == ""
            failure = json.loads(completed.stderr)["failure"]
            assert failure["category"] == "invalidInput" and str(special) not in completed.stderr
            checks += 1

        for extra in (("--request", str(target)), ("unused",)):
            completed = invoke(target, extra=extra)
            assert completed.returncode == 2 and completed.stdout == ""
            checks += 1

    print(f"Text analysis: {len(cases)} shared fixtures, {checks} CLI checks, native parity within 1e-12")


if __name__ == "__main__":
    main()
