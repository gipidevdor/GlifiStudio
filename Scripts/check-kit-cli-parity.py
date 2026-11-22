#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check the reviewed public Kit surface and full native/CLI fixture parity."""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / "Config/CLI/kit-api-baseline.json"
SCHEMA = "studio.glifi.kit-cli-api-baseline"
CALLABLE_KINDS = {
    "swift.func", "swift.method", "swift.type.method", "swift.init", "swift.subscript",
}
DEFAULT_FAMILIES = [
    {"command": "statistics", "enum": "GlifiStudioStatisticsOperation"},
    {"command": "operator", "enum": "GlifiStudioCoreOperator"},
    {"command": "evaluation", "enum": "GlifiStudioEvaluationOperation"},
    {"command": "project-call", "enum": "GlifiStudioProjectOperation"},
    {"command": "profile", "enum": "GlifiStudioTextFormat"},
]


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def public_symbols(directory: Path) -> dict[str, dict]:
    """Keep compiler declarations rather than parsing Swift or maintaining an API allowlist."""
    symbols = {}
    found_module = False
    for path in sorted(directory.rglob("*.json")):
        graph = read_json(path)
        if not isinstance(graph, dict) or graph.get("module", {}).get("name") != "GlifiKit":
            continue
        found_module = True
        for symbol in graph["symbols"]:
            if symbol.get("accessLevel") not in {"public", "open"}:
                continue
            identifier = symbol["identifier"]["precise"]
            record = {
                "identifier": identifier,
                "kind": symbol["kind"]["identifier"],
                "path": symbol["pathComponents"],
                "declaration": " ".join(
                    "".join(item["spelling"] for item in symbol["declarationFragments"]).split()
                ),
            }
            for key in ("functionSignature", "swiftGenerics", "availability"):
                if key in symbol:
                    record[key] = symbol[key]
            if identifier in symbols and symbols[identifier] != record:
                raise ValueError(f"Conflicting compiler declarations for {identifier}")
            symbols[identifier] = record
    if not found_module or not symbols:
        raise ValueError("The supplied symbol graph directory has no public GlifiKit module")
    return symbols


def write_baseline(path: Path, symbols: dict[str, dict]) -> None:
    """Prepare a reviewable snapshot; new operational callables stay unclassified."""
    previous = read_json(path) if path.exists() else {}
    previous_symbols = {entry["identifier"]: entry for entry in previous.get("symbols", [])}
    entries = []
    for identifier, symbol in sorted(symbols.items(), key=lambda item: item[1]["path"]):
        entry = dict(symbol)
        prior = previous_symbols.get(identifier)
        if prior is not None:
            for key in ("role", "commands", "reason"):
                if key in prior:
                    entry[key] = prior[key]
        elif symbol["kind"] == "swift.init":
            entry.update(role="infrastructure", reason="Data or runtime object construction.")
        elif symbol["kind"] in CALLABLE_KINDS and symbol["path"][-1] == "encode(to:)":
            entry.update(role="infrastructure", reason="Codable output transport implementation.")
        elif symbol["kind"] in CALLABLE_KINDS:
            entry.update(role="reviewRequired", reason="Assign a CLI binding or an explicit infrastructure reason.")
        else:
            entry["role"] = "data"
        entries.append(entry)
    baseline = {
        "schema": SCHEMA,
        "schemaVersion": 1,
        "operationFamilies": previous.get("operationFamilies", DEFAULT_FAMILIES),
        "symbols": entries,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(baseline, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    unclassified = sum(entry["role"] == "reviewRequired" for entry in entries)
    print(f"Prepared {len(entries)} public declarations; {unclassified} callables require review")


def check_baseline(path: Path, symbols: dict[str, dict]) -> list[dict]:
    baseline = read_json(path)
    if baseline.get("schema") != SCHEMA or baseline.get("schemaVersion") != 1:
        raise ValueError("Invalid Kit/CLI API baseline schema")
    recorded = {}
    for entry in baseline["symbols"]:
        identifier = entry["identifier"]
        if identifier in recorded:
            raise ValueError(f"Duplicate baseline declaration: {identifier}")
        record = {key: value for key, value in entry.items() if key not in {"role", "commands", "reason"}}
        recorded[identifier] = record
        role = entry.get("role")
        if entry["kind"] in CALLABLE_KINDS:
            if role == "operation":
                if not entry.get("commands") or not all(isinstance(item, str) and item for item in entry["commands"]):
                    raise ValueError(f"Missing CLI binding: {'.'.join(entry['path'])}")
            elif role == "infrastructure":
                if not isinstance(entry.get("reason"), str) or not entry["reason"].strip():
                    raise ValueError(f"Missing infrastructure reason: {'.'.join(entry['path'])}")
            else:
                raise ValueError(f"Unclassified public callable: {'.'.join(entry['path'])}")
        elif role != "data":
            raise ValueError(f"Unexpected classification for {'.'.join(entry['path'])}")
    changes = []
    for identifier in sorted(symbols.keys() - recorded.keys()):
        changes.append("added " + ".".join(symbols[identifier]["path"]))
    for identifier in sorted(recorded.keys() - symbols.keys()):
        changes.append("removed " + ".".join(recorded[identifier]["path"]))
    for identifier in sorted(symbols.keys() & recorded.keys()):
        if symbols[identifier] != recorded[identifier]:
            changes.append("changed " + ".".join(symbols[identifier]["path"]))
    if changes:
        raise ValueError("Unreviewed public Kit API drift:\n" + "\n".join(changes))
    families = baseline["operationFamilies"]
    commands = [family["command"] for family in families]
    if not families or len(commands) != len(set(commands)):
        raise ValueError("Empty or duplicate operation families")
    print(f"Kit API: {len(symbols)} reviewed public declarations, signatures and DTO members")
    return families


def compare(actual, expected, context: str = "") -> None:
    if isinstance(expected, dict):
        if not isinstance(actual, dict) or actual.keys() != expected.keys():
            raise ValueError(f"Object keys differ at {context}")
        for key in expected:
            compare(actual[key], expected[key], context + "." + key)
    elif isinstance(expected, list):
        if not isinstance(actual, list) or len(actual) != len(expected):
            raise ValueError(f"Array length differs at {context}")
        for index, (left, right) in enumerate(zip(actual, expected)):
            compare(left, right, context + f"[{index}]")
    elif isinstance(expected, float):
        if isinstance(actual, bool) or not isinstance(actual, (float, int)):
            raise ValueError(f"Numeric type differs at {context}")
        if not math.isfinite(actual) or not math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError(f"Numeric value differs at {context}")
        if actual == expected == 0 and math.copysign(1, actual) != math.copysign(1, expected):
            raise ValueError(f"Signed zero differs at {context}")
    elif type(actual) is not type(expected) or actual != expected:
        raise ValueError(f"Exact value or type differs at {context}")


def visual_export(directory: Path, receipt: dict) -> tuple[dict, dict[str, bytes]]:
    """Verify each receipt against its own bytes before comparing scientific content."""
    manifest_path = directory / "visual-export-manifest.json"
    data = manifest_path.read_bytes()
    compare(receipt, {"manifestDigest": "sha256:" + hashlib.sha256(data).hexdigest(),
                      "fileCount": len(list(directory.iterdir()))}, "visual-export.receipt")
    manifest = json.loads(data)
    if manifest["schema"] != "studio.glifi.visual-export-manifest" or manifest["schemaVersion"] != 1:
        raise ValueError("Invalid visual export manifest schema")
    created = datetime.datetime.fromisoformat(manifest["createdAt"].replace("Z", "+00:00"))
    if created.utcoffset() != datetime.timedelta(0):
        raise ValueError("Visual export creation time is not RFC 3339 UTC")
    payloads = {}
    for record in manifest["files"]:
        name = record["path"]
        if not isinstance(name, str) or Path(name).name != name or name in payloads:
            raise ValueError("Unsafe or duplicate visual export payload")
        payload = (directory / name).read_bytes()
        if len(payload) != record["byteCount"] or "sha256:" + hashlib.sha256(payload).hexdigest() != record["sha256"]:
            raise ValueError("Visual export payload integrity failed")
        payloads[name] = payload
    if {path.name for path in directory.iterdir()} != set(payloads) | {manifest_path.name}:
        raise ValueError("Unexpected visual export files")
    # The existing contract explicitly excludes only creation time from scientific identity.
    del manifest["createdAt"]
    return manifest, payloads


def check_fixtures(binary: Path, directory: Path, families: list[dict], symbols: dict[str, dict]) -> None:
    expected = {}
    for family in families:
        cases = {
            symbol["path"][-1]
            for symbol in symbols.values()
            if symbol["kind"] == "swift.enum.case" and symbol["path"][:-1] == [family["enum"]]
        }
        if not cases:
            raise ValueError(f"Missing compiler enum cases for {family['enum']}")
        expected[family["command"]] = cases
    fixtures = [read_json(path) for path in sorted(directory.glob("*.json"))]
    observed = {command: set() for command in expected}
    if not fixtures:
        raise ValueError("No native Kit parity fixtures were exported")
    with tempfile.TemporaryDirectory(prefix="GlifiKitCLIParity-") as temporary:
        request_path = Path(temporary) / "request.json"
        checks = 0
        for fixture in fixtures:
            required = {"schemaVersion", "command", "operation", "request", "result"}
            if not required <= fixture.keys() or fixture.keys() - required - {"projectPath", "visualExportPath"} or fixture["schemaVersion"] != 1:
                raise ValueError("Invalid native Kit parity fixture schema")
            command, operation = fixture["command"], fixture["operation"]
            if command not in observed or operation in observed[command]:
                raise ValueError(f"Unexpected or duplicate fixture: {command}/{operation}")
            observed[command].add(operation)
            for repeat in range(2):
                request = json.loads(json.dumps(fixture["request"]))
                expected_result = fixture["result"]
                arguments = [str(binary), "--format", "json", command]
                if "projectPath" in fixture:
                    source = Path(fixture["projectPath"]).resolve()
                    if not source.is_dir() or not source.is_relative_to(directory.resolve()):
                        raise ValueError("Project parity snapshots must live inside the parity directory")
                    copied = Path(temporary) / f"project-{checks}-{repeat}.glifi"
                    shutil.copytree(source, copied)
                    arguments.append(str(copied))
                destination = None
                if "visualExportPath" in fixture:
                    if command != "project-call" or operation != "exportVisualization":
                        raise ValueError("Visual export comparison is restricted to its declared project operation")
                    destination = Path(temporary) / f"visual-export-{checks}-{repeat}"
                    request["parameters"]["destinationPath"] = str(destination)
                request_path.write_text(json.dumps(request, ensure_ascii=False), encoding="utf-8")
                arguments.extend(["--request", str(request_path)])
                result = subprocess.run(
                    arguments,
                    capture_output=True, text=True, timeout=60, check=False,
                )
                if result.returncode != 0 or result.stderr:
                    raise ValueError(f"CLI invocation failed for {command}/{operation}: {result.returncode} {result.stderr}")
                envelope = json.loads(result.stdout)
                if destination is not None:
                    native_path = Path(fixture["visualExportPath"]).resolve()
                    if not native_path.is_relative_to(directory.resolve()):
                        raise ValueError("Native export evidence must live inside the parity directory")
                    native_manifest, native_payloads = visual_export(native_path, expected_result)
                    actual_manifest, actual_payloads = visual_export(destination, envelope["result"])
                    compare(actual_manifest, native_manifest, "visual-export.manifest-except-createdAt")
                    if actual_payloads != native_payloads:
                        raise ValueError("Native and CLI visual export payload bytes differ")
                    expected_result = {**expected_result, "manifestDigest": envelope["result"]["manifestDigest"]}
                compare(envelope, {
                    "cliProtocolVersion": 1, "command": command, "outcome": "succeeded",
                    "result": expected_result,
                }, command + "/" + operation)
                checks += 1
        if observed != expected:
            differences = []
            for command in expected:
                differences.append(f"{command}: missing={sorted(expected[command] - observed[command])}, extra={sorted(observed[command] - expected[command])}")
            raise ValueError("Compiler-enumerated operation parity failed:\n" + "\n".join(differences))
    print(f"Kit/CLI: {len(fixtures)} compiler-enumerated operations, {checks} complete-result parity checks")


def check_text_operation_inventory(symbols: dict[str, dict]) -> None:
    def enum_cases(name: str) -> set[str]:
        return {
            symbol["path"][-1].split("(", 1)[0]
            for symbol in symbols.values()
            if symbol["kind"] == "swift.enum.case" and symbol["path"][:-1] == [name]
        }

    outer = enum_cases("GlifiStudioTextAnalysisRequest")
    advanced = enum_cases("GlifiStudioAdvancedTextAnalysisRequest")
    kh = enum_cases("GlifiStudioKHAnalysisRequest")
    if "advanced" not in outer or "kh" not in advanced or not kh:
        raise ValueError("Missing compiler declarations for the nested advanced or KH text requests")
    # These stable transport aliases differ from the Swift case names; all other
    # cases are still discovered from the compiler, including future additions.
    kh_aliases = {
        "sampleZScores": "matrix-zscore",
        "perThousand": "matrix-per-thousand",
        "ordinalMDS": "mds-ordinal",
        "ordinalMDSSearch": "mds-ordinal-search",
        "somPCAInitialization": "som-pca-initialization",
        "collocationScores": "kh-collocation",
        "validateClassifierWithAgreement": "validate-classifier-kappa",
    }
    stale_aliases = kh_aliases.keys() - kh
    if stale_aliases:
        raise ValueError(f"KH transport aliases have no compiler case: {sorted(stale_aliases)}")
    tags = []
    for cases, aliases in ((outer - {"advanced"}, {}), (advanced - {"kh"}, {}), (kh, kh_aliases)):
        tags.extend(
            aliases.get(case, re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "-", case).lower())
            for case in cases
        )
    expected = set(tags)
    if len(expected) != len(tags):
        raise ValueError("Duplicate flat operation tags in ordinary, advanced or KH text requests")
    fixture = read_json(ROOT / "Fixtures/TextAnalysis/v1/cases.json")
    observed = {case["request"]["operation"] for case in fixture["cases"]}
    if not expected or expected != observed:
        raise ValueError(f"Text analysis compiler/fixture drift: missing={sorted(expected - observed)}, extra={sorted(observed - expected)}")
    print(f"Text analysis: all {len(expected)} compiler-enumerated request cases have CLI fixtures")


def check_rejections(binary: Path, directory: Path) -> None:
    """Exercise shared file admission and JSON failures through each standalone command."""
    fixtures = [read_json(path) for path in sorted(directory.glob("*.json"))]
    checks = 0
    with tempfile.TemporaryDirectory(prefix="GlifiKitCLINegative-") as temporary:
        root = Path(temporary)
        request_path = root / "secret-canary-request.json"
        for command in ("statistics", "operator", "evaluation"):
            fixture = next((fixture for fixture in fixtures if fixture["command"] == command), None)
            if fixture is None:
                raise ValueError(f"No nominal request for negative tests of {command}")
            request = fixture["request"]

            def invoke(path: Path, extra: tuple[str, ...] = ()):
                return subprocess.run(
                    [str(binary), "--format", "json", command, "--request", str(path), *extra],
                    capture_output=True, text=True, timeout=30, check=False,
                )

            def rejects(raw: bytes, status: int = 3, category: str = "invalidInput") -> None:
                request_path.write_bytes(raw)
                check_failure(invoke(request_path), status, category)

            def check_failure(completed, status: int, category: str) -> None:
                nonlocal checks
                if completed.returncode != status or completed.stdout:
                    raise ValueError(f"Wrong failure streams/status for {command}: {completed.returncode}")
                envelope = json.loads(completed.stderr)
                failure = envelope["failure"]
                if envelope["cliProtocolVersion"] != 1 or envelope["command"] != command or envelope["outcome"] != "failed":
                    raise ValueError(f"Wrong failure envelope for {command}")
                if failure["category"] != category or failure["arguments"] != []:
                    raise ValueError(f"Wrong failure category/arguments for {command}")
                if "secret-canary" in completed.stderr or str(root) in completed.stderr:
                    raise ValueError(f"Private input leaked from {command}")
                checks += 1

            def encoded(value) -> bytes:
                return json.dumps(value, ensure_ascii=False).encode()

            for raw in (b"{", b"\xff", b"null", b"[]"):
                rejects(raw)
            rejects(encoded({**request, "operation": "secret-canary-unknown"}))
            rejects(encoded({**request, "secret-canary-field": 1}))
            canonical = encoded(request)
            rejects(canonical[:-1] + b',"\\u006fperation":"secret-canary-duplicate"}')
            for key, value in request.items():
                if isinstance(value, dict):
                    rejects(encoded({**request, key: {**value, "secret-canary-nested": 1}}))
                    break
            rejects(b" " * (1_048_576 + 1), 7, "insufficientResources")
            rejects(b"[" * 33 + b"0" + b"]" * 33, 7, "insufficientResources")
            if "schemaVersion" in request:
                rejects(encoded({**request, "schemaVersion": request["schemaVersion"] + 1}), 10, "incompatibleVersion")
            request_path.write_bytes(canonical)
            link = root / f"{command}-link.json"
            link.symlink_to(request_path)
            fifo = root / f"{command}-pipe.json"
            os.mkfifo(fifo)
            for path in (link, fifo, root, root / "secret-canary-missing.json"):
                check_failure(invoke(path), 3, "invalidInput")
            if os.geteuid() != 0:
                request_path.chmod(0)
                try:
                    check_failure(invoke(request_path), 6, "authorizationDenied")
                finally:
                    request_path.chmod(0o600)
            for extra in (("--request", str(request_path)), ("unused",)):
                completed = invoke(request_path, extra)
                if completed.returncode != 2 or completed.stdout or not completed.stderr:
                    raise ValueError(f"Invalid arguments were accepted by {command}")
                checks += 1
    print(f"Kit/CLI: {checks} JSON, version, resource, file, permission, argument and privacy rejection checks")


def check_explicit_imports(binary: Path, directory: Path) -> None:
    fixtures = [read_json(path) for path in sorted(directory.glob("*.json"))]
    profiles = [fixture for fixture in fixtures if fixture["command"] == "profile"]
    if not profiles:
        raise ValueError("No native profiles were exported for the explicit-format import contract")

    def invoke(arguments: list[str], command: str) -> dict:
        completed = subprocess.run(
            [str(binary), "--format", "json", *arguments],
            capture_output=True, text=True, timeout=30, check=False,
        )
        if completed.returncode != 0 or completed.stderr:
            raise ValueError(f"Explicit-format import invocation failed: {completed.returncode} {completed.stderr}")
        envelope = json.loads(completed.stdout)
        compare({key: value for key, value in envelope.items() if key != "result"},
                {"cliProtocolVersion": 1, "command": command, "outcome": "succeeded"})
        return envelope["result"]

    def identifier(value: str, namespace: str) -> None:
        if not isinstance(value, str) or not value.startswith(namespace + ":"):
            raise ValueError(f"Invalid {namespace} namespace")
        opaque = value.removeprefix(namespace + ":")
        if str(uuid.UUID(opaque)) != opaque:
            raise ValueError(f"Invalid canonical {namespace} UUID")

    with tempfile.TemporaryDirectory(prefix="GlifiExplicitImportParity-") as temporary:
        for fixture in profiles:
            request = fixture["request"]
            source = Path(request["sourcePath"]).resolve()
            if not source.is_relative_to(directory.resolve()) or source.suffix != ".data":
                raise ValueError("Explicit-format import needs a synthetic .data source in the parity directory")
            project = Path(temporary) / (fixture["operation"] + ".glifi")
            created = invoke(["project", "create", str(project)], "project.create")["project"]
            identifier(created["projectID"], "project")
            if created["generation"] != 0 or created["sourceCount"] != 0:
                raise ValueError("New import parity project is not empty")
            imported = invoke(["import", str(project), "--input-format", request["format"], str(source)], "import")
            compare(imported["lastProfile"], fixture["result"], "import.lastProfile")
            snapshot = imported["project"]
            if imported["importedSourceCount"] != 1 or snapshot["projectID"] != created["projectID"]:
                raise ValueError("Import changed project identity or reported a wrong source count")
            if snapshot["generation"] != 1 or snapshot["sourceCount"] != 1 or snapshot["artifactCount"] != 0:
                raise ValueError("Import committed an unexpected generation or source/artifact count")
            if len(snapshot["sources"]) != 1:
                raise ValueError("Import did not preserve the source record")
            record = snapshot["sources"][0]
            identifier(record["sourceID"], "source")
            identifier(record["sourceRevisionID"], "source-revision")
            if record["format"] != request["format"] or record["byteCount"] != source.stat().st_size:
                raise ValueError("Import ignored the explicit input format or byte count")
            if not re.fullmatch(r"sha256:[0-9a-f]{64}", record["contentDigest"]):
                raise ValueError("Import produced an invalid content digest")
    print(f"Import: {len(profiles)} explicit formats on .data sources preserve the complete native profile")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path)
    parser.add_argument("--parity-directory", type=Path)
    parser.add_argument("--symbol-graph", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, default=BASELINE)
    parser.add_argument("--write-baseline", type=Path, help="Prepare a snapshot for explicit API review; does not run the gate")
    args = parser.parse_args()
    try:
        symbols = public_symbols(args.symbol_graph)
        if args.write_baseline:
            write_baseline(args.write_baseline, symbols)
            return 0
        if args.binary is None or args.parity_directory is None:
            parser.error("--binary and --parity-directory are required when running the gate")
        families = check_baseline(args.baseline, symbols)
        check_text_operation_inventory(symbols)
        check_fixtures(args.binary.resolve(), args.parity_directory, families, symbols)
        check_rejections(args.binary.resolve(), args.parity_directory)
        check_explicit_imports(args.binary.resolve(), args.parity_directory)
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
        print(f"Kit/CLI parity failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
