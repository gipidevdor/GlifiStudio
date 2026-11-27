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
                or ":" in name or not name.endswith(".feature") or name in expected):
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


def select_inventory(
        expected: dict[str, dict[int, int]], selection: str) -> dict[str, dict[int, int]]:
    """Select exact expanded scenario IDs already reviewed in the inventory."""
    if not selection.strip():
        raise ValueError("selezione BDD vuota")
    selected: dict[str, dict[int, int]] = {}
    for item in selection.split(","):
        name, separator, line_text = item.strip().partition(":")
        if name not in expected:
            raise ValueError(f"feature BDD assente dall'inventario: {name!r}")
        if separator:
            if not re.fullmatch(r"[1-9][0-9]*", line_text):
                raise ValueError(f"riga BDD non valida: {item!r}")
            line = int(line_text)
            if line not in expected[name]:
                raise ValueError(f"scenario espanso BDD non inventariato: {name}:{line}")
            selected.setdefault(name, {})[line] = expected[name][line]
        else:
            selected.setdefault(name, {}).update(expected[name])
    if not selected:
        raise ValueError("selezione BDD vuota")
    return {name: dict(sorted(lines.items())) for name, lines in sorted(selected.items())}


def runner_selection(expected: dict[str, dict[int, int]]) -> str:
    """Use CucumberSwift's scenario-list transport, without parsing Gherkin or tags."""
    return ",".join(
        f"Features/{name.replace('%', '%25').replace(',', '%2C')}:{line}"
        for name, lines in sorted(expected.items()) for line in sorted(lines))


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


def selection_self_test() -> None:
    """Require the selected scenarios, without accepting omissions or extra execution."""
    complete = {"Contract.feature": {5: 2, 10: 3}, "Other.feature": {7: 1}}
    selected = select_inventory(complete, "Contract.feature:10")
    assert selected == {"Contract.feature": {10: 3}}
    assert select_inventory(complete, "Contract.feature") == {"Contract.feature": complete["Contract.feature"]}
    assert select_inventory(complete, "Other.feature:7,Contract.feature:5") == {
        "Contract.feature": {5: 2}, "Other.feature": {7: 1}}
    assert select_inventory(complete, "Contract.feature,Contract.feature:5") == {
        "Contract.feature": complete["Contract.feature"]}
    assert runner_selection(selected) == "Features/Contract.feature:10"
    assert runner_selection({"Literal #%?, Name.feature": {5: 2}}) == (
        "Features/Literal #%25?%2C Name.feature:5")
    for selection in ("", " ", ",", "Contract.feature,", "Missing.feature", "Contract.feature:0",
                      "Contract.feature:6", "Contract.feature:-1", "Contract.feature:True",
                      "Contract.feature:10:5", "../Contract.feature", "/Contract.feature"):
        try:
            select_inventory(complete, selection)
        except ValueError:
            pass
        else:
            raise AssertionError(f"selezione BDD non valida accettata: {selection!r}")
    scenario = {
        "type": "scenario", "line": 10,
        "tags": [{"name": "GS-CMP-332"}, {"name": "macos"}],
        "steps": [{"result": {"status": "passed"}} for _ in range(3)],
    }
    report = [{"uri": "Features/Contract.feature", "elements": [scenario]}]
    assert validate_report(report, selected) == 3
    extra = copy.deepcopy(report)
    extra[0]["elements"].append({**scenario, "line": 5})
    omitted = copy.deepcopy(report)
    omitted[0]["elements"] = []
    invalid = [extra, omitted, []]
    for status in ("failed", "skipped", "undefined", "pending", "ambiguous"):
        changed = copy.deepcopy(report)
        changed[0]["elements"][0]["steps"][0]["result"]["status"] = status
        invalid.append(changed)
    for changed in invalid:
        try:
            validate_report(changed, selected)
        except ValueError:
            pass
        else:
            raise AssertionError("report di sviluppo incompleto o non superato accettato")
    try:
        validate_report(report, complete)
    except ValueError:
        pass
    else:
        raise AssertionError("report di sviluppo accettato come gate completo")


def self_test() -> None:
    """Exercise the gate against realistic omissions and false success reports."""
    selection_self_test()
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
        unaddressable = feature.with_name("Contract:Example.feature")
        feature.rename(unaddressable)
        invalid_name = copy.deepcopy(inventory)
        invalid_name["features"][0]["file"] = unaddressable.name
        try:
            validate_inventory(invalid_name, root)
        except ValueError:
            pass
        else:
            raise AssertionError("nome feature con separatore scenario riservato accettato")
        finally:
            unaddressable.rename(feature)
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
    parser.add_argument("--select", help="Comma-separated Feature.feature[:expanded-scenario-line] IDs")
    parser.add_argument("--list", action="store_true", help="List inventoried features and scenario IDs")
    parser.add_argument("--runner-selection", action="store_true", help="Print CucumberSwift scenario IDs")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        if sum((args.list, args.runner_selection, args.report is not None)) > 1:
            raise ValueError("scegliere un solo output fra lista, selezione runner e report")
        expected = validate_inventory(json.loads((ROOT / INVENTORY).read_text()), ROOT)
        contracts = None
        contract_checker = None
        # A developer selection is an iteration, not a claim that every public contract is complete.
        if args.select is None and not args.list and not args.runner_selection:
            contract_checker = runpy.run_path(str(ROOT / "Scripts/check-bdd-contracts.py"))
            contracts = json.loads((ROOT / contract_checker["CONTRACTS"]).read_text())
            surface = json.loads((ROOT / contract_checker["SURFACE"]).read_text())
            errors = contract_checker["validate_contracts"](contracts, surface, expected, ROOT)
            if errors:
                raise ValueError("; ".join(errors))
        if args.select is not None:
            expected = select_inventory(expected, args.select)
        if args.runner_selection:
            if args.select is None:
                raise ValueError("la selezione runner richiede --select esplicito")
            print(runner_selection(expected))
        elif args.list:
            for name, scenarios in expected.items():
                print(f"{name}: {len(scenarios)} scenari, {sum(scenarios.values())} passaggi")
                print("  " + ", ".join(f"{name}:{line}" for line in scenarios))
        elif args.report:
            report = json.loads(args.report.read_text())
            steps = validate_report(report, expected)
            if contracts is not None:
                errors = contract_checker["validate_contract_report"](contracts, report)
                if errors:
                    raise ValueError("; ".join(errors))
            count = sum(len(scenarios) for scenarios in expected.values())
            label = "BDD sviluppo (selezione esplicita)" if args.select is not None else "BDD"
            scenario_label = "scenario" if count == 1 else "scenari"
            print(f"{label}: {len(expected)} feature, {count} {scenario_label}, {steps} passaggi superati")
        else:
            print(f"BDD: inventario di {len(expected)} feature e controlli strutturali superati")
        return 0
    except (OSError, ValueError, AssertionError) as error:
        print(f"Verifica BDD fallita: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
