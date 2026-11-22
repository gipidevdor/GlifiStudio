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
    assert len(cases) == 63
    assert cases and len({case["id"] for case in cases}) == len(cases)
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

        def succeeds(fields):
            nonlocal checks
            path = directory / "refinement-request.json"
            path.write_bytes(encoded(fields))
            completed = invoke(path)
            assert completed.returncode == 0 and completed.stderr == "", completed
            checks += 1
            return json.loads(completed.stdout)["result"]["result"]

        # Exact underflow boundaries must not be hidden by the general 1e-12 tolerance.
        count = float.fromhex("0x1.8000000000001p-1022")
        exposure = 4_503_599_627_370_497
        for mode, value, length, corpus in (
            ("tf", count, exposure, 1),
            ("tfIdf", count, 2 * exposure, 100),
            ("tfDividedByIdf", 2 * count, exposure, 100),
        ):
            body = succeeds({"operation": "document-scores", "counts": [[value]],
                             "exposures": [length], "documentFrequencies": [1],
                             "corpusDocumentCount": corpus, "mode": mode})
            assert body["scores"] == [math.ulp(0.0)], mode
            assert body["termContributions"] == [[math.ulp(0.0)]], mode

        def annotated(identifier, first, last):
            offset = len(first.encode("utf-8"))
            return {"id": identifier, "text": first + " " + last,
                    "linguisticContract": "synthetic-exact-pos-v1", "tokens": [
                        {"surface": first, "base": first, "partOfSpeech": "N",
                         "startUTF8": 0, "endUTF8": offset},
                        {"surface": last, "base": last, "partOfSpeech": "N",
                         "startUTF8": offset + 1, "endUTF8": offset + 2}]}

        first = annotated("NFC", "é", "a")
        second = annotated("NFD", "e\u0301", "b")
        for documents in ([first, second], [second, first]):
            body = succeeds({"operation": "term-extraction", "documents": documents,
                             "rule": {"identifier": "synthetic-noun-runs-v1",
                                      "allowedPartsOfSpeech": ["N"]}})
            common = next(item["component"] for item in body["scores"]["components"]
                          if item["component"] in {"é", "e\u0301"})
            assert common.encode("utf-8") == documents[0]["tokens"][0]["base"].encode("utf-8")

        total = 10**15
        body = succeeds({"operation": "continue-classifier", "documents": [], "labels": [],
                         "state": {"classes": ["A", "B"], "vocabulary": ["x", "y"],
                                   "documentCounts": [1, 1],
                                   "tokenCounts": [[total - 2, 2], [total - 1, 1]], "smoothing": 1},
                         "predictionDocuments": [["x"] * 100]})
        assert body["predictions"]["labels"] == ["B"]
        assert body["model"]["logLikelihoods"][0][0] < body["model"]["logLikelihoods"][1][0] < 0

        closer = math.ldexp(1.0, -537)
        farther = math.nextafter(closer, math.inf)
        rejects(encoded({"operation": "kh-hierarchical-ward-d2", "dissimilarities": [
            [0, farther, closer, 1], [farther, 0, closer + farther, 1],
            [closer, closer + farther, 0, 1], [1, 1, 1, 0]]}), 3, "invalidInput")

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
        graph = {"nodes": ["a", "b"], "edges": [{"source": "a", "target": "b"}]}
        rejects(encoded({"operation": "communities", "graph": {**graph, "secret-canary": 1},
                         "method": "walktrap"}), 3, "invalidInput")
        rejects(encoded({"operation": "communities", "graph": {
            "nodes": ["a", "b"], "edges": [{"source": "a", "target": "b", "weight": None}]},
                         "method": "fastGreedy"}), 3, "invalidInput")
        rejects(encoded({"operation": "graph-layout", "graph": graph, "method": "kamadaKawai",
                         "initialPositions": [{"x": 0, "y": 0, "secret-canary": 1}, {"x": 1, "y": 1}]}), 3, "invalidInput")
        rejects(encoded({"operation": "communities", "graph": graph, "method": "walktrap",
                         "limits": {"secret-canary": 1}}), 3, "invalidInput")
        rejects(encoded({"operation": "graph-layout", "graph": graph, "method": "kamadaKawai",
                         "limits": None}), 3, "invalidInput")
        rejects(encoded({"operation": "minimum-spanning-forest", "graph": graph,
                         "limits": {"maximumEdgeCount": None}}), 3, "invalidInput")
        rejects(encoded({"operation": "communities", "graph": graph, "method": "fastGreedy",
                         "limits": {"maximumNodeCount": 1}}), 7, "insufficientResources")
        rejects(encoded({"operation": "minimum-spanning-forest", "graph": graph,
                         "limits": {"maximumEdgeCount": 0}}), 7, "insufficientResources")
        rejects(encoded({"operation": "graph-layout", "graph": graph, "method": "kamadaKawai",
                         "limits": {"maximumPairwiseCells": 0}}), 7, "insufficientResources")
        rejects(encoded({"operation": "communities", "graph": graph, "method": "walktrap",
                         "limits": {"maximumWork": 0}}), 7, "insufficientResources")
        rejects(encoded({"operation": "linguistic", "text": "secret-canary",
                         "options": {"base": None}}), 3, "invalidInput")
        rejects(encoded({"operation": "linguistic", "text": "secret-canary",
                         "options": {"secret-canary": 1}}), 3, "invalidInput")
        rejects(encoded({"operation": "lda-selection", "documents": [["a"], ["a"]],
                         "candidateTopicCounts": [1], "seed": 0, "options": {"folds": None}}), 3, "invalidInput")
        rejects(encoded({"operation": "lda-selection", "documents": [["secret-canary"], ["a"]],
                         "candidateTopicCounts": [1], "seed": 0, "options": {"folds": 1}}), 3, "invalidInput")
        rejects(encoded({"operation": "lda-selection", "documents": [["a"], ["a"]],
                         "candidateTopicCounts": list(range(1, 34)), "seed": 0}), 7, "insufficientResources")
        rejects(encoded({"operation": "linguistic-coding", "units": [{"id": "1", "text": "secret-canary", "extra": 1}],
                         "rules": "*A\\na"}), 3, "invalidInput")

        rejects(encoded({"operation": "coding", "units": [{"id": "1", "text": "casa"}],
                         "rules": "*A\ncasa->V->ignored"}), 3, "invalidInput")
        rejects(encoded({"operation": "coding", "units": [{"id": "1", "text": "casa"}],
                         "rules": "*A\n1e309 == 0"}), 3, "invalidInput")
        rejects(encoded({"operation": "coding", "units": [{"id": "1", "text": " ".join(["a"] * 2_000 + ["b"] * 2_000)}],
                         "rules": "*A\nnear(a-b)[1]"}), 7, "insufficientResources")
        rejects(encoded({"operation": "classify", "documents": [["x"]] * 3_000,
                         "labels": [f"c{i}" for i in range(3_000)],
                         "predictionDocuments": [["x"]] * 2_000}), 7, "insufficientResources")
        rejects(encoded({"operation": "validate-classifier", "documents": [["x"]] * 4_500,
                         "labels": [f"c{i}" for i in range(2_250) for _ in range(2)],
                         "folds": 2, "seed": 0}), 7, "insufficientResources")

        rejects(encoded({"operation": "som-kh", "matrix": [[0], [1]], "width": 1, "height": 1,
                         "initialCodebooks": None}), 3, "invalidInput")
        rejects(encoded({"operation": "som-kh", "matrix": [[0], [1]], "width": 1, "height": 1,
                         "codebookClusterCount": None}), 3, "invalidInput")
        rejects(encoded({"operation": "som-kh", "matrix": [[0], [1]], "width": 1, "height": 1,
                         "firstPhase": {"steps": 1, "initialLearningRate": .05,
                                        "initialRadius": 1, "secret-canary": 1}}), 3, "invalidInput")
        rejects(encoded({"operation": "matrix-per-thousand", "matrix": [[1]], "exposures": [0]}), 5, "insufficientData")
        rejects(encoded({"operation": "matrix-zscore", "matrix": [[2, 2]], "axis": "rows"}), 5, "insufficientData")
        rejects(encoded({"operation": "word-context", "targetIDs": ["a"], "contextIDs": ["b"],
                         "levels": [{"level": "sentence", "targetCounts": [[1]],
                                     "contextCounts": [[1], [2]]}]}), 3, "invalidInput")
        rejects(encoded({"operation": "mds-ordinal", "matrix": [[0, 1], [1, 0]],
                         "dimensions": 1, "ties": "tertiary"}), 3, "invalidInput")
        rejects(encoded({"operation": "kh-collocation", "counts": {"jointCount": 1,
                         "nodeFrequency": 10, "collocateFrequency": 20,
                         "corpusTokenCount": 15, "windowSpan": 10}}), 3, "invalidInput")
        rejects(encoded({"operation": "term-scores", "candidates": [{"components": ["a"], "frequency": 0}],
                         "preprocessingIdentifier": "synthetic-v1"}), 3, "invalidInput")
        rejects(encoded({"operation": "term-scores", "candidates": [{"components": ["a", "b"], "frequency": 1}],
                         "preprocessingIdentifier": "synthetic-v1", "maximumWork": 1}), 7, "insufficientResources")
        rejects(encoded({"operation": "incremental-classifier", "documents": [["a"]], "labels": ["A"],
                         "predictionDocuments": [["a"]]}), 5, "insufficientData")
        rejects(encoded({"operation": "continue-classifier", "documents": [], "labels": [],
                         "state": {"classes": ["A", "B"], "vocabulary": ["a"],
                                   "documentCounts": [1, 1], "tokenCounts": [[-1], [1]], "smoothing": 1}}), 3, "invalidInput")
        rejects(encoded({"operation": "validate-classifier-kappa", "documents": [["a"], ["b"]],
                         "labels": ["A", "B"], "folds": 2, "seed": 0}), 5, "insufficientData")

        rejects(encoded({"operation": "word-association", "counts": {"jointCount": 0,
                         "conditionDocumentCount": 8, "termDocumentCount": 8,
                         "totalDocumentCount": 10}}), 3, "invalidInput")
        rejects(encoded({"operation": "word-association", "counts": {"jointCount": 1,
                         "conditionDocumentCount": 2, "termDocumentCount": 3,
                         "totalDocumentCount": 10, "secret-canary": 1}}), 3, "invalidInput")

        rejects(encoded({"operation": "document-scores", "counts": [[1]], "exposures": [10],
                         "documentFrequencies": [0], "corpusDocumentCount": 10}), 3, "invalidInput")
        rejects(encoded({"operation": "document-scores", "counts": [[1]], "exposures": [10],
                         "documentFrequencies": [1], "corpusDocumentCount": 10,
                         "mode": "secret-canary"}), 3, "invalidInput")
        rejects(encoded({"operation": "kh-hierarchical-ward-d2", "dissimilarities": [[0, 1], [2, 0]]}), 3, "invalidInput")
        rejects(encoded({"operation": "kh-chi-square", "counts": [[1, 0], [0, -1]]}), 3, "invalidInput")
        rejects(encoded({"operation": "kh-chi-square", "counts": [[1, 2, 3], [4, 5, 6]],
                         "correction": "yates"}), 3, "invalidInput")
        rejects(encoded({"operation": "code-crosstab-significance", "units": [{"id": "1", "text": "casa"}],
                         "rules": "*Home\ncasa", "groups": []}), 3, "invalidInput")

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
