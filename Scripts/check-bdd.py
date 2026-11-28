#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check the BDD inventory and require a complete, successful Cucumber report."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
import re
import runpy
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import NamedTuple


ROOT = Path(__file__).resolve().parent.parent
INVENTORY = "Config/Testing/bdd-coverage.json"
FEATURES = "Packages/GlifiCore/Tests/GlifiBDDTests/Features"
NOTICE_SOURCE = "Config/Licenses/bdd-tools.txt"
NOTICE_RESOURCE = "Packages/GlifiCore/Tests/GlifiBDDTests/Licenses/THIRD_PARTY_NOTICES.txt"
NOTICE_COPIES = (
    (NOTICE_SOURCE, NOTICE_RESOURCE),
    ("LICENSE", "Packages/GlifiCore/Tests/GlifiBDDTests/Licenses/GlifiStudio-LICENSE.txt"),
    ("THIRD_PARTY_NOTICES.txt",
     "Packages/GlifiCore/Tests/GlifiBDDTests/Licenses/GlifiStudio-THIRD_PARTY_NOTICES.txt"),
)
INVENTORY_SCHEMA = "studio.glifi.bdd-coverage"
INVENTORY_VERSION = 2


class ScenarioExpectation(NamedTuple):
    """Reviewed scenario cardinality and ordered step identity."""

    step_count: int
    steps_sha256: str


def read_json(path: Path) -> object:
    """Reject ambiguous object members and non-finite numbers in gate inputs."""
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("chiave JSON duplicata nell'input BDD")
            result[key] = value
        return result

    def finite_number(token: str) -> float:
        value = float(token)
        if not math.isfinite(value):
            raise ValueError("numero JSON non finito nell'input BDD")
        return value

    def invalid_constant(_: str) -> object:
        raise ValueError("costante non JSON nell'input BDD")

    return json.loads(
        path.read_text(encoding="utf-8"), object_pairs_hook=unique_object,
        parse_float=finite_number, parse_constant=invalid_constant)


def step_metadata_digest(steps: object) -> str:
    """Hash the ordered upstream metadata without parsing Gherkin again."""
    if not isinstance(steps, list) or not steps:
        raise ValueError("elenco dei passaggi vuoto o non valido")
    metadata = []
    for index, step in enumerate(steps, 1):
        if not isinstance(step, dict):
            raise ValueError(f"metadati del passaggio {index} non validi")
        line, keyword, name = step.get("line"), step.get("keyword"), step.get("name")
        if (type(line) is not int or line < 1
                or not isinstance(keyword, str) or not keyword.strip()
                or not isinstance(name, str) or not name.strip()):
            raise ValueError(f"metadati del passaggio {index} non validi")
        metadata.append({"line": line, "keyword": keyword, "name": name})
    canonical = json.dumps(
        metadata, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(canonical).hexdigest()


def validate_notices(root: Path) -> None:
    """Keep the reviewed notices intact in the test product's resource bundle."""
    for source_path, resource_path in NOTICE_COPIES:
        source = (root / source_path).read_bytes()
        if not source.strip() or (root / resource_path).read_bytes() != source:
            raise ValueError(f"avvisi assenti o differenti nel bundle dei test: {resource_path}")


def validate_inventory(body: object, root: Path) -> dict[str, dict[int, ScenarioExpectation]]:
    """Validate exact feature coverage without reimplementing the Gherkin parser."""
    if (not isinstance(body, dict) or set(body) != {"schema", "schemaVersion", "features"}
            or body.get("schema") != INVENTORY_SCHEMA
            or type(body.get("schemaVersion")) is not int
            or body["schemaVersion"] != INVENTORY_VERSION):
        raise ValueError("schema inventario BDD non valido")
    features = body.get("features")
    if not isinstance(features, list) or not features:
        raise ValueError("inventario BDD vuoto")
    expected = {}
    for entry in features:
        if (not isinstance(entry, dict)
                or set(entry) != {"file", "expandedScenarios", "sourceSHA256", "scenarios"}):
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
            if (not isinstance(scenario, dict)
                    or set(scenario) != {"line", "stepCount", "stepsSHA256"}):
                raise ValueError(f"{name}: posizione scenario non valida")
            line, step_count = scenario.get("line"), scenario.get("stepCount")
            if type(line) is not int or line < 1 or line in scenario_steps:
                raise ValueError(f"{name}: posizione scenario duplicata o non valida")
            if type(step_count) is not int or step_count < 1:
                raise ValueError(f"{name}:{line}: conteggio passaggi non valido")
            steps_digest = scenario.get("stepsSHA256")
            if not isinstance(steps_digest, str) or not re.fullmatch(r"[0-9a-f]{64}", steps_digest):
                raise ValueError(f"{name}:{line}: digest dei passaggi non valido")
            scenario_steps[line] = ScenarioExpectation(step_count, steps_digest)
        expected[name] = scenario_steps
    files = list((root / FEATURES).rglob("*.feature"))
    if any(path.parent != root / FEATURES for path in files):
        raise ValueError("feature annidate non ammesse: usare nomi univoci nella cartella Features")
    actual = {p.name for p in files}
    if actual != set(expected):
        raise ValueError(f"inventario BDD non allineato ai file: {actual ^ set(expected)}")
    return expected


def select_inventory(
        expected: dict[str, dict[int, ScenarioExpectation]], selection: str) -> dict[str, dict[int, ScenarioExpectation]]:
    """Select exact expanded scenario IDs already reviewed in the inventory."""
    if not selection.strip():
        raise ValueError("selezione BDD vuota")
    selected: dict[str, dict[int, ScenarioExpectation]] = {}
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


def runner_selection(expected: dict[str, dict[int, ScenarioExpectation]]) -> str:
    """Use CucumberSwift's scenario-list transport, without parsing Gherkin or tags."""
    return ",".join(
        f"Features/{name.replace('%', '%25').replace(',', '%2C')}:{line}"
        for name, lines in sorted(expected.items()) for line in sorted(lines))


def validate_report(body: object, expected: dict[str, dict[int, ScenarioExpectation]]) -> int:
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
                    or len(scenario_steps) != expected[name][line].step_count):
                raise ValueError(f"{name}:{line}: passaggi omessi o inattesi")
            try:
                digest = step_metadata_digest(scenario_steps)
            except ValueError as error:
                raise ValueError(f"{name}:{line}: {error}") from error
            if digest != expected[name][line].steps_sha256:
                raise ValueError(f"{name}:{line}: identità o ordine dei passaggi differenti dalla revisione")
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
    metadata = [
        {"line": 2, "keyword": "Dato", "name": "una città"},
        {"line": 3, "keyword": "Quando", "name": "cerco un termine"},
        {"line": 4, "keyword": "Allora", "name": "il conteggio è 1"},
    ]
    def expectation(count: int) -> ScenarioExpectation:
        return ScenarioExpectation(count, step_metadata_digest(metadata[:count]))
    complete = {"Contract.feature": {5: expectation(2), 10: expectation(3)},
                "Other.feature": {7: expectation(1)}}
    selected = select_inventory(complete, "Contract.feature:10")
    assert selected == {"Contract.feature": {10: expectation(3)}}
    assert select_inventory(complete, "Contract.feature") == {"Contract.feature": complete["Contract.feature"]}
    assert select_inventory(complete, "Other.feature:7,Contract.feature:5") == {
        "Contract.feature": {5: expectation(2)}, "Other.feature": {7: expectation(1)}}
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
        "steps": [{**step, "result": {"status": "passed"}} for step in metadata],
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
    with TemporaryDirectory(prefix="GlifiBDDNotices-") as directory:
        root = Path(directory)
        for name in {name for pair in NOTICE_COPIES for name in pair}:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"synthetic reviewed notices\n")
        validate_notices(root)
        for _, resource_path in NOTICE_COPIES:
            for value in (b"", b"notice with missing copyright\n"):
                (root / resource_path).write_bytes(value)
                try:
                    validate_notices(root)
                except ValueError:
                    pass
                else:
                    raise AssertionError("avviso BDD incompleto accettato")
            (root / resource_path).write_bytes(b"synthetic reviewed notices\n")
        (root / NOTICE_RESOURCE).unlink()
        try:
            validate_notices(root)
        except OSError:
            pass
        else:
            raise AssertionError("risorsa legale BDD mancante accettata")
    report = [{"uri": "Features/Contract.feature", "elements": [{
        "type": "scenario", "line": 5,
        "tags": [{"name": "GS-CMP-332"}, {"name": "macos"}],
        "steps": [
            {"line": 2, "keyword": "Dato", "name": "una città", "result": {"status": "passed"}},
            {"line": 4, "keyword": "Allora", "name": "il conteggio è 1",
             "result": {"status": "passed"}},
        ],
    }]}]
    canonical_steps = (
        '[{"keyword":"Dato","line":2,"name":"una città"},'
        '{"keyword":"Allora","line":4,"name":"il conteggio è 1"}]').encode("utf-8")
    digest = hashlib.sha256(canonical_steps).hexdigest()
    assert step_metadata_digest(report[0]["elements"][0]["steps"]) == digest
    expectation = ScenarioExpectation(2, digest)
    expected = {"Contract.feature": {5: expectation}}
    assert validate_report(report, expected) == 2
    with TemporaryDirectory(prefix="GlifiBDDJSON-") as directory:
        path = Path(directory) / "report.json"
        text = json.dumps(report, ensure_ascii=False)
        path.write_text(text, encoding="utf-8")
        assert validate_report(read_json(path), expected) == 2
        duplicated_status = text.replace(
            '"status": "passed"', '"status": "failed", "status": "passed"', 1)
        assert duplicated_status != text
        for raw in (
            duplicated_status,
            '{"duration": NaN}', '{"duration": Infinity}', '{"duration": -Infinity}',
            '{"duration": 1e999}', '{"duration": -1e999}',
        ):
            path.write_text(raw, encoding="utf-8")
            try:
                read_json(path)
            except ValueError:
                pass
            else:
                raise AssertionError("report JSON ambiguo o non finito accettato")
    rejected = [[], {}, report + report, [{"uri": "Other.feature"}],
                [{"uri": "Contract.feature", "elements": []}]]
    for status in ("failed", "skipped", "pending", "undefined", "ambiguous", None):
        changed = copy.deepcopy(report)
        changed[0]["elements"][0]["steps"][0]["result"]["status"] = status
        rejected.append(changed)
    for key, value in (("steps", []), ("tags", []), ("line", 0), ("line", 99),
                       ("line", True), ("steps", [report[0]["elements"][0]["steps"][0]])):
        changed = copy.deepcopy(report)
        changed[0]["elements"][0][key] = value
        rejected.append(changed)
    duplicated_step = copy.deepcopy(report)
    duplicated_step[0]["elements"][0]["steps"][1] = copy.deepcopy(
        duplicated_step[0]["elements"][0]["steps"][0])
    rejected.append(duplicated_step)
    swapped_steps = copy.deepcopy(report)
    swapped_steps[0]["elements"][0]["steps"].reverse()
    rejected.append(swapped_steps)
    for key, value in (
        ("line", None), ("line", True), ("line", 0), ("line", "2"), ("line", 99),
        ("keyword", None), ("keyword", True), ("keyword", ""), ("keyword", "  "),
        ("keyword", "Quando"), ("name", None), ("name", True), ("name", ""),
        ("name", "  "), ("name", "una città diversa"),
    ):
        changed = copy.deepcopy(report)
        changed[0]["elements"][0]["steps"][0][key] = value
        rejected.append(changed)
    missing_metadata = copy.deepcopy(report)
    del missing_metadata[0]["elements"][0]["steps"][0]["name"]
    rejected.append(missing_metadata)
    for invalid in rejected:
        try:
            validate_report(invalid, expected)
        except ValueError:
            continue
        raise AssertionError(f"report invalido accettato: {invalid}")
    try:
        validate_report(report, {**expected, "Missing.feature": {5: expectation}})
    except ValueError:
        pass
    else:
        raise AssertionError("report parziale accettato")
    duplicate = copy.deepcopy(report)
    duplicate[0]["elements"] *= 2
    try:
        validate_report(duplicate, {"Contract.feature": {5: expectation, 10: expectation}})
    except ValueError:
        pass
    else:
        raise AssertionError("esempio duplicato accettato")
    dependency_check = runpy.run_path(str(ROOT / "Scripts/check-apple-baseline.py"))[
        "validate_test_dependencies"]
    manifest = (ROOT / "Packages/GlifiCore/Package.swift").read_text()
    lock = read_json(ROOT / "Packages/GlifiCore/Package.resolved")
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
        inventory = {"schema": INVENTORY_SCHEMA, "schemaVersion": INVENTORY_VERSION, "features": [
            {"file": "Contract.feature", "expandedScenarios": 1,
             "sourceSHA256": hashlib.sha256(source).hexdigest(),
             "scenarios": [{"line": 5, "stepCount": 2, "stepsSHA256": digest}]}]}
        assert validate_inventory(inventory, root) == expected
        inventory_path = root / "inventory.json"
        inventory_text = json.dumps(inventory, ensure_ascii=False)
        inventory_path.write_text(inventory_text, encoding="utf-8")
        assert validate_inventory(read_json(inventory_path), root) == expected
        duplicate_version = inventory_text.replace(
            '"schemaVersion": 2', '"schemaVersion": 1, "schemaVersion": 2', 1)
        assert duplicate_version != inventory_text
        inventory_path.write_text(duplicate_version, encoding="utf-8")
        try:
            read_json(inventory_path)
        except ValueError:
            pass
        else:
            raise AssertionError("inventario JSON con versione duplicata accettato")
        for field, value in (("schema", None), ("schema", "other-schema"),
                             ("schemaVersion", True), ("schemaVersion", 1),
                             ("schemaVersion", "2"), ("schemaVersion", 3)):
            invalid = copy.deepcopy(inventory)
            invalid[field] = value
            try:
                validate_inventory(invalid, root)
            except ValueError:
                pass
            else:
                raise AssertionError(f"schema inventario invalido accettato: {invalid}")
        for missing in ("schema", "schemaVersion", "features"):
            invalid = copy.deepcopy(inventory)
            del invalid[missing]
            try:
                validate_inventory(invalid, root)
            except ValueError:
                pass
            else:
                raise AssertionError(f"schema inventario incompleto accettato: {missing}")
        for field, value in (("sourceSHA256", "0" * 64), ("sourceSHA256", "invalid"),
                             ("expandedScenarios", True), ("expandedScenarios", 2),
                             ("scenarios", [{"line": 5, "stepCount": 0, "stepsSHA256": digest}]),
                             ("scenarios", [{"line": True, "stepCount": 2, "stepsSHA256": digest}]),
                             ("scenarios", [{"line": 5, "stepCount": True, "stepsSHA256": digest}]),
                             ("scenarios", [{"line": 5, "stepCount": 2}]),
                             ("scenarios", [{"line": 5, "stepCount": 2, "stepsSHA256": True}]),
                             ("scenarios", [{"line": 5, "stepCount": 2, "stepsSHA256": "invalid"}])):
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
        validate_notices(ROOT)
        expected = validate_inventory(read_json(ROOT / INVENTORY), ROOT)
        if args.select is not None:
            expected = select_inventory(expected, args.select)
        if args.runner_selection:
            if args.select is None:
                raise ValueError("la selezione runner richiede --select esplicito")
            print(runner_selection(expected))
        elif args.list:
            for name, scenarios in expected.items():
                print(f"{name}: {len(scenarios)} scenari, {sum(s.step_count for s in scenarios.values())} passaggi")
                print("  " + ", ".join(f"{name}:{line}" for line in scenarios))
        elif args.report:
            steps = validate_report(read_json(args.report), expected)
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
