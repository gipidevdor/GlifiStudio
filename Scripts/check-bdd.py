#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check the BDD inventory and require a complete, successful Cucumber report."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import runpy
import sys
from pathlib import Path
from tempfile import TemporaryDirectory


ROOT = Path(__file__).resolve().parent.parent
INVENTORY = "Config/Testing/bdd-coverage.json"
FEATURES = "Packages/GlifiCore/Tests/GlifiBDDTests/Features"


def validate_inventory(body: object, root: Path) -> dict[str, dict[int, int]]:
    """Validate exact feature coverage without reimplementing the Gherkin parser."""
    if (not isinstance(body, dict) or type(body.get("schemaVersion")) is not int
            or body["schemaVersion"] != 1):
        raise ValueError("schema inventario BDD non valido")
    features = body.get("features")
    if not isinstance(features, list) or not features:
        raise ValueError("inventario BDD vuoto")
    expected = {}
    for entry in features:
        if not isinstance(entry, dict):
            raise ValueError("voce feature non valida")
        name, count = entry.get("file"), entry.get("expandedScenarios")
        if (not isinstance(name, str) or Path(name).name != name
                or not name.endswith(".feature") or name in expected):
            raise ValueError("nome feature duplicato o non valido")
        if type(count) is not int or count < 1:
            raise ValueError(f"{name}: conteggio esempi non valido")
        digest = entry.get("sourceSHA256")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError(f"{name}: digest sorgente non valido")
        path = root / FEATURES / name
        if not path.is_file():
            raise ValueError(f"{name}: feature italiana mancante")
        source = path.read_bytes()
        if hashlib.sha256(source).hexdigest() != digest:
            raise ValueError(f"{name}: sorgente modificato dopo la revisione BDD")
        source_lines = source.decode("utf-8").splitlines()
        if not source_lines or source_lines[0] != "# language: it":
            raise ValueError(f"{name}: dichiarazione di lingua italiana mancante")
        scenarios = entry.get("scenarios")
        if not isinstance(scenarios, list) or len(scenarios) != count:
            raise ValueError(f"{name}: inventario scenari espansi non allineato")
        scenario_steps = {}
        for scenario in scenarios:
            if not isinstance(scenario, dict):
                raise ValueError(f"{name}: posizione scenario non valida")
            line, step_count = scenario.get("line"), scenario.get("stepCount")
            if type(line) is not int or line < 1 or line in scenario_steps:
                raise ValueError(f"{name}: posizione scenario duplicata o non valida")
            if type(step_count) is not int or step_count < 1:
                raise ValueError(f"{name}:{line}: conteggio passaggi non valido")
            scenario_steps[line] = step_count
        expected[name] = scenario_steps
    files = list((root / FEATURES).rglob("*.feature"))
    if any(path.parent != root / FEATURES for path in files):
        raise ValueError("feature annidate non ammesse: usare nomi univoci nella cartella Features")
    actual = {p.name for p in files}
    if actual != set(expected):
        raise ValueError(f"inventario BDD non allineato ai file: {actual ^ set(expected)}")
    return expected


def validate_report(body: object, expected: dict[str, dict[int, int]]) -> int:
    """Reject omitted features, duplicate examples, empty steps and non-passed results."""
    if not isinstance(body, list) or not body:
        raise ValueError("report Cucumber vuoto o non valido")
    seen = set()
    steps = 0
    for feature in body:
        if not isinstance(feature, dict) or not isinstance(feature.get("uri"), str):
            raise ValueError("feature nel report non valida")
        name = Path(feature["uri"]).name
        if name not in expected or name in seen:
            raise ValueError(f"feature inattesa o duplicata: {name}")
        seen.add(name)
        scenarios = feature.get("elements")
        if not isinstance(scenarios, list) or len(scenarios) != len(expected[name]):
            raise ValueError(f"{name}: richiesti {len(expected[name])} scenari espansi")
        lines = set()
        for scenario in scenarios:
            if not isinstance(scenario, dict) or scenario.get("type") != "scenario":
                raise ValueError(f"{name}: scenario non valido")
            line = scenario.get("line")
            if type(line) is not int or line not in expected[name] or line in lines:
                raise ValueError(f"{name}: esempio duplicato o posizione non valida")
            lines.add(line)
            tags = scenario.get("tags")
            if not isinstance(tags, list) or not {"GS-CMP-332", "macos"}.issubset(
                    {tag.get("name") for tag in tags if isinstance(tag, dict)
                     and isinstance(tag.get("name"), str)}):
                raise ValueError(f"{name}:{line}: tracciabilità BDD mancante")
            scenario_steps = scenario.get("steps")
            if (not isinstance(scenario_steps, list)
                    or len(scenario_steps) != expected[name][line]):
                raise ValueError(f"{name}:{line}: passaggi omessi o inattesi")
            for step in scenario_steps:
                if (not isinstance(step, dict) or not isinstance(step.get("result"), dict)
                        or step["result"].get("status") != "passed"):
                    raise ValueError(f"{name}:{line}: passaggio non superato")
                steps += 1
        if lines != set(expected[name]):
            raise ValueError(f"{name}: posizioni degli scenari non allineate")
    if seen != set(expected):
        raise ValueError(f"feature assenti dal report: {set(expected) - seen}")
    return steps


def self_test() -> None:
    """Exercise the gate against realistic omissions and false success reports."""
    report = [{"uri": "Features/Contract.feature", "elements": [{
        "type": "scenario", "line": 5,
        "tags": [{"name": "GS-CMP-332"}, {"name": "macos"}],
        "steps": [{"result": {"status": "passed"}}, {"result": {"status": "passed"}}],
    }]}]
    expected = {"Contract.feature": {5: 2}}
    assert validate_report(report, expected) == 2
    rejected = [[], {}, report + report, [{"uri": "Other.feature"}],
                [{"uri": "Contract.feature", "elements": []}]]
    for status in ("failed", "skipped", "pending", "undefined", "ambiguous", None):
        changed = copy.deepcopy(report)
        changed[0]["elements"][0]["steps"][0]["result"]["status"] = status
        rejected.append(changed)
    for key, value in (("steps", []), ("tags", []), ("line", 0), ("line", 99),
                       ("line", True), ("steps", [{"result": {"status": "passed"}}])):
        changed = copy.deepcopy(report)
        changed[0]["elements"][0][key] = value
        rejected.append(changed)
    for invalid in rejected:
        try:
            validate_report(invalid, expected)
        except ValueError:
            continue
        raise AssertionError(f"report invalido accettato: {invalid}")
    try:
        validate_report(report, {**expected, "Missing.feature": {5: 2}})
    except ValueError:
        pass
    else:
        raise AssertionError("report parziale accettato")
    duplicate = copy.deepcopy(report)
    duplicate[0]["elements"] *= 2
    try:
        validate_report(duplicate, {"Contract.feature": {5: 2, 10: 2}})
    except ValueError:
        pass
    else:
        raise AssertionError("esempio duplicato accettato")
    dependency_check = runpy.run_path(str(ROOT / "Scripts/check-apple-baseline.py"))[
        "validate_test_dependencies"]
    manifest = (ROOT / "Packages/GlifiCore/Package.swift").read_text()
    lock = json.loads((ROOT / "Packages/GlifiCore/Package.resolved").read_text())
    assert not dependency_check(manifest, lock)
    for changed in (
        manifest.replace('exact: "6.9.0"', 'from: "6.9.0"'),
        re.sub(r',\s*traits:\s*\[\s*\]', '', manifest, count=1),
        re.sub(r'traits:\s*\[\s*\]', 'traits: [.defaults]', manifest, count=1),
        re.sub(r'traits:\s*\[\s*\]', 'traits: ["Macros"]', manifest, count=1),
        manifest.replace('name: "GlifiBDDTests"', 'name: "GlifiRuntime"'),
        manifest.replace('.testTarget(\n            name: "GlifiBDDTests"',
                         '.target(\n            name: "GlifiBDDTests"'),
        manifest.replace('dependencies: ["GlifiCore"]',
                         'dependencies: ["GlifiCore", "CucumberSwiftTesting"]'),
        manifest.replace('dependencies: [\n        .package(',
                         'dependencies: [\n        .package(url: "https://example.com/Other.git", exact: "1.0.0"),\n        .package('),
    ):
        assert changed != manifest and dependency_check(changed, lock)
    changed_lock = copy.deepcopy(lock)
    changed_lock["pins"][0]["state"]["revision"] = "0" * 40
    assert dependency_check(manifest, changed_lock)
    changed_lock = copy.deepcopy(lock)
    changed_lock["pins"] *= 2
    assert dependency_check(manifest, changed_lock)
    with TemporaryDirectory(prefix="GlifiBDDGate-") as directory:
        root = Path(directory)
        (root / FEATURES).mkdir(parents=True)
        source = b"# language: it\n"
        feature = root / FEATURES / "Contract.feature"
        feature.write_bytes(source)
        inventory = {"schemaVersion": 1, "features": [
            {"file": "Contract.feature", "expandedScenarios": 1,
             "sourceSHA256": hashlib.sha256(source).hexdigest(),
             "scenarios": [{"line": 5, "stepCount": 2}]}]}
        assert validate_inventory(inventory, root) == expected
        for field, value in (("sourceSHA256", "0" * 64), ("sourceSHA256", "invalid"),
                             ("expandedScenarios", True), ("expandedScenarios", 2),
                             ("scenarios", [{"line": 5, "stepCount": 0}]),
                             ("scenarios", [{"line": True, "stepCount": 2}])):
            invalid = copy.deepcopy(inventory)
            invalid["features"][0][field] = value
            try:
                validate_inventory(invalid, root)
            except ValueError:
                pass
            else:
                raise AssertionError(f"inventario invalido accettato: {invalid}")
        feature.write_bytes(source + b"# changed after review\n")
        try:
            validate_inventory(inventory, root)
        except ValueError:
            pass
        else:
            raise AssertionError("sorgente modificato accettato")
        feature.write_bytes(source)
        nested = root / FEATURES / "Nested"
        nested.mkdir()
        (nested / "Contract.feature").write_bytes(source)
        try:
            validate_inventory(inventory, root)
        except ValueError:
            pass
        else:
            raise AssertionError("feature annidata omonima accettata")
        (nested / "Contract.feature").unlink()
        nested.rmdir()
        (root / FEATURES / "Untracked.feature").write_text("# language: it\n", encoding="utf-8")
        try:
            validate_inventory(inventory, root)
        except ValueError:
            pass
        else:
            raise AssertionError("feature non inventariata accettata")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        expected = validate_inventory(json.loads((ROOT / INVENTORY).read_text()), ROOT)
        if args.report:
            steps = validate_report(json.loads(args.report.read_text()), expected)
            count = sum(len(scenarios) for scenarios in expected.values())
            print(f"BDD: {len(expected)} feature, {count} scenari, {steps} passaggi superati")
        else:
            print(f"BDD: inventario di {len(expected)} feature e controlli strutturali superati")
        return 0
    except (OSError, ValueError, AssertionError) as error:
        print(f"Verifica BDD fallita: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
