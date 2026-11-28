#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Bind reviewed BDD contracts to certified scenario positions and report witnesses."""

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
CONTRACTS = "Config/Testing/bdd-contracts.json"
SURFACE = "Config/Testing/analysis-scenarios.json"
INVENTORY = "Config/Testing/bdd-coverage.json"
FIXTURES = "Fixtures/TextAnalysis/v1/cases.json"
FEATURES = "Packages/GlifiCore/Tests/GlifiBDDTests/Features"
PHASES = {"nominal", "invalid-input", "pre-cancelled"}
COMMON = {
    "caseID", "feature", "line", "sourceLineSHA256", "oracle", "dataOrigin", "references", "witnesses",
}
CASE_FIELDS = COMMON | {"command", "variant", "phase"}
SUPPLEMENTAL_FIELDS = COMMON | {"domain"}
# Reviewed alongside GlifiPlannerScenarioTests.publicIntentInventoryMatchesTheDeclaredScenarios.
# That native test checks this declared inventory against GlifiAnalyticalIntent.allCases.
PLANNER_INTENTS = {
    "understand.collection", "discover.contents", "identify.themes", "characterize.group",
    "compare.objects", "trace.change", "explore.relationships", "find.similar",
    "explore.object", "search.sources", "review.completely",
}


def require(condition: bool, message: str) -> None:
    """Reject incomplete declarations without interpreting their scientific meaning."""
    if not condition:
        raise ValueError(message)


def nonempty(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def referenced_file(root: Path, relative: object) -> Path:
    """Accept only existing repository files, including safe internal symlinks."""
    require(isinstance(relative, str) and bool(relative), "riferimento file mancante")
    require("\\" not in relative and ":" not in relative, "riferimento file non relativo")
    path = Path(relative)
    require(not path.is_absolute() and not {"..", ".git"}.intersection(path.parts),
            f"riferimento file non sicuro: {relative!r}")
    resolved = (root / path).resolve()
    require(resolved.is_relative_to(root.resolve()) and resolved.is_file(),
            f"riferimento file assente o esterno: {relative!r}")
    return resolved


def feature_name(value: object) -> str:
    require(isinstance(value, str) and Path(value).name == value
            and "\\" not in value and ":" not in value and value.endswith(".feature"),
            "nome feature non valido")
    return value


def certified_inventory(inventory: object, root: Path) -> dict[str, dict[int, object]]:
    """Accept the raw inventory or the map already certified by check-bdd.py."""
    require(isinstance(inventory, dict) and bool(inventory), "inventario BDD assente")
    if "features" in inventory:
        checker = runpy.run_path(str(ROOT / "Scripts/check-bdd.py"))
        return checker["validate_inventory"](inventory, root)
    result = {}
    for name, positions in inventory.items():
        name = feature_name(name)
        require(isinstance(positions, dict) and bool(positions), f"{name}: posizioni assenti")
        for line, expectation in positions.items():
            require(type(line) is int and line > 0, f"{name}: posizione non valida")
            # runpy creates a fresh NamedTuple class; preserve its reviewed fields and digest.
            require(isinstance(expectation, tuple)
                    and getattr(expectation, "_fields", None) == ("step_count", "steps_sha256"),
                    f"{name}: attesa V2 non certificata")
            count, steps_digest = expectation
            require(type(count) is int and count > 0
                    and isinstance(steps_digest, str)
                    and re.fullmatch(r"[0-9a-f]{64}", steps_digest) is not None,
                    f"{name}: numero di passi o digest V2 non valido")
        result[name] = dict(positions)
    return result


def surface_variants(surface: object) -> set[tuple[str, str]]:
    require(isinstance(surface, dict)
            and surface.get("schema") == "studio.glifi.analysis-scenarios"
            and type(surface.get("schemaVersion")) is int and surface["schemaVersion"] == 1,
            "matrice pubblica non valida")
    groups = surface.get("groups")
    require(isinstance(groups, list) and bool(groups), "matrice pubblica vuota")
    variants = set()
    commands = set()
    for group in groups:
        require(isinstance(group, dict), "gruppo della matrice non valido")
        command = group.get("command")
        values = group.get("variants")
        require(nonempty(command) and command not in commands, "comando pubblico duplicato o vuoto")
        commands.add(command)
        require(isinstance(values, list) and bool(values) and all(nonempty(x) for x in values),
                f"{command}: varianti pubbliche assenti")
        require(len(values) == len(set(values)), f"{command}: variante pubblica duplicata")
        variants.update((command, value) for value in values)
    return variants


def all_entries(body: object) -> list[tuple[dict, bool]]:
    require(isinstance(body, dict)
            and body.get("schema") == "studio.glifi.bdd-contracts"
            and type(body.get("schemaVersion")) is int and body["schemaVersion"] == 1,
            "schema contratti BDD non valido")
    require(set(body) == {"schema", "schemaVersion", "sourceMatrixSHA256", "cases", "supplementalCases", "workflowCoverage"},
            "campi del registro contratti mancanti o sconosciuti")
    cases, supplemental = body.get("cases"), body.get("supplementalCases")
    require(isinstance(cases, list) and bool(cases), "casi pubblici BDD assenti")
    require(isinstance(supplemental, list), "casi supplementari BDD non validi")
    require(all(isinstance(case, dict) for case in cases + supplemental), "caso BDD non valido")
    return [(case, False) for case in cases] + [(case, True) for case in supplemental]


def validate_workflows(body: dict, surface: dict, addresses: set[tuple[str, int]], root: Path) -> None:
    """Keep native model coverage distinct from declarations of actual BDD scenarios."""
    contracts = {(case["feature"], case["line"]): case for case, _ in all_entries(body)}
    workflows = surface.get("workflows")
    require(isinstance(workflows, list) and bool(workflows), "workflow pubblici assenti")
    identifiers = [item.get("id") for item in workflows if isinstance(item, dict)]
    require(len(identifiers) == len(workflows) and all(nonempty(value) for value in identifiers)
            and len(identifiers) == len(set(identifiers)), "ID workflow pubblici non validi")
    coverage = body.get("workflowCoverage")
    require(isinstance(coverage, list) and bool(coverage), "copertura workflow assente")
    seen = set()
    for entry in coverage:
        require(isinstance(entry, dict), "voce workflow non valida")
        identifier = entry.get("id")
        require(nonempty(identifier) and identifier in identifiers and identifier not in seen,
                "ID copertura workflow inatteso o duplicato")
        seen.add(identifier)
        mode = entry.get("mode")
        require(mode == ("native-model" if identifier == "GS-SCN-009" else "bdd"),
                f"{identifier}: modalità workflow non ammessa; distinguere modelli nativi e BDD")
        if mode == "native-model":
            require(set(entry) == {"id", "mode", "tests", "limitation"}
                    and nonempty(entry["limitation"]), f"{identifier}: limite della prova nativa assente")
            tests = entry["tests"]
            require(isinstance(tests, list) and bool(tests) and all(nonempty(value) for value in tests)
                    and len(tests) == len(set(tests)), f"{identifier}: test nativi non validi")
            for relative in tests:
                require("Tests" in Path(relative).parts and relative.endswith(".swift"),
                        f"{identifier}: riferimento non appartenente ai test Swift")
                referenced_file(root, relative)
        else:
            required = {"id", "mode", "cases"} | (
                {"intents", "intentCases"} if identifier == "GS-SCN-011" else set())
            require(required.issubset(entry) and not set(entry).difference(required | {"limitation"}),
                    f"{identifier}: campi workflow BDD mancanti o sconosciuti")
            if "limitation" in entry:
                require(nonempty(entry["limitation"]), f"{identifier}: limite workflow vuoto")
            cases = entry["cases"]
            require(isinstance(cases, list) and bool(cases), f"{identifier}: scenari BDD workflow assenti")
            locations = set()
            for case in cases:
                require(isinstance(case, dict) and set(case) == {"feature", "line"},
                        f"{identifier}: indirizzo workflow non valido")
                name, line = feature_name(case["feature"]), case["line"]
                require(type(line) is int and (name, line) in addresses
                        and (name, line) not in locations, f"{identifier}: scenario workflow non inventariato o duplicato")
                locations.add((name, line))
            if identifier == "GS-SCN-011":
                intents = entry["intents"]
                require(isinstance(intents, list) and all(nonempty(value) for value in intents)
                        and len(intents) == len(set(intents)) and set(intents) == PLANNER_INTENTS,
                        f"{identifier}: gli undici intenti del planner non sono coperti")
                intent_cases = entry["intentCases"]
                require(isinstance(intent_cases, list) and len(intent_cases) == len(PLANNER_INTENTS),
                        f"{identifier}: mappa degli undici intenti assente o incompleta")
                mapped_intents = set()
                mapped_locations = set()
                for intent_case in intent_cases:
                    require(isinstance(intent_case, dict)
                            and set(intent_case) == {"intent", "feature", "line"},
                            f"{identifier}: associazione intento-scenario non valida")
                    intent = intent_case["intent"]
                    require(nonempty(intent) and intent in PLANNER_INTENTS and intent not in mapped_intents,
                            f"{identifier}: intento inatteso o duplicato nella mappa")
                    name, line = feature_name(intent_case["feature"]), intent_case["line"]
                    require(type(line) is int and (name, line) in locations
                            and (name, line) not in mapped_locations,
                            f"{identifier}: scenario intento non associato al workflow o duplicato")
                    contract = contracts.get((name, line))
                    witness = f'il planner riceve l\'intento "{intent}"'
                    witnesses = contract.get("witnesses") if contract is not None else None
                    require(isinstance(witnesses, list) and witness in witnesses,
                            f"{identifier}: witness dell'intento assente nel contratto associato: {intent}")
                    mapped_intents.add(intent)
                    mapped_locations.add((name, line))
                require(mapped_intents == PLANNER_INTENTS,
                        f"{identifier}: mappa degli intenti del planner incompleta")
    require(set(identifiers) == seen, f"workflow non coperti: {sorted(set(identifiers) - seen)}")


def _validate_contracts(body: object, surface: object, inventory: object, root: Path) -> None:
    entries = all_entries(body)
    source = referenced_file(root, SURFACE).read_bytes()
    require(runpy.run_path(str(ROOT / "Scripts/check-bdd.py"))["read_json"](root / SURFACE) == surface, "la matrice fornita non corrisponde al file controllato")
    require(body["sourceMatrixSHA256"] == digest(source), "digest della matrice pubblica non allineato")
    variants = surface_variants(surface)
    expected = certified_inventory(inventory, root)
    addresses = {(name, line) for name, positions in expected.items() for line in positions}
    fixture_body = runpy.run_path(str(ROOT / "Scripts/check-bdd.py"))["read_json"](referenced_file(root, FIXTURES))
    fixture_cases = fixture_body.get("cases") if isinstance(fixture_body, dict) else None
    require(isinstance(fixture_cases, list) and bool(fixture_cases), "catalogo fixture testuali assente")
    fixture_ids = [case.get("id") for case in fixture_cases if isinstance(case, dict)]
    require(len(fixture_ids) == len(fixture_cases) and all(nonempty(x) for x in fixture_ids)
            and len(fixture_ids) == len(set(fixture_ids)), "ID delle fixture testuali non validi")
    required_fixture_ids = set(fixture_ids)
    covered_fixture_ids = set()
    seen_ids = set()
    seen_addresses = set()
    coverage = {}
    source_lines = {}
    checked_references = set()
    for case, supplemental in entries:
        required = SUPPLEMENTAL_FIELDS if supplemental else CASE_FIELDS
        optional = set() if supplemental else {"fixtureID", "fixtureUnmodified"}
        require(required.issubset(case) and not set(case).difference(required | optional),
                "campi del caso BDD mancanti o sconosciuti")
        case_id = case["caseID"]
        require(nonempty(case_id) and case_id not in seen_ids, "caseID BDD duplicato o vuoto")
        seen_ids.add(case_id)
        name, line = feature_name(case["feature"]), case["line"]
        require(type(line) is int and line > 0, f"{case_id}: riga non valida")
        address = (name, line)
        require(address in addresses, f"{case_id}: indirizzo non certificato dall'inventario: {address}")
        require(address not in seen_addresses, f"{case_id}: indirizzo BDD duplicato: {address}")
        seen_addresses.add(address)
        if name not in source_lines:
            source_lines[name] = referenced_file(root, f"{FEATURES}/{name}").read_bytes().splitlines()
        lines = source_lines[name]
        require(line <= len(lines) and case["sourceLineSHA256"] == digest(lines[line - 1]),
                f"{case_id}: hash della riga sorgente non allineato")
        require(nonempty(case["oracle"]), f"{case_id}: oracolo non dichiarato")
        require(case["dataOrigin"] == "original-synthetic", f"{case_id}: provenienza dati non ammessa")
        references = case["references"]
        require(isinstance(references, list) and bool(references)
                and all(nonempty(value) for value in references), f"{case_id}: fonti assenti")
        require(len(references) == len(set(references)), f"{case_id}: fonte duplicata")
        for reference in references:
            if reference not in checked_references:
                referenced_file(root, reference)
                checked_references.add(reference)
        witnesses = case["witnesses"]
        require(isinstance(witnesses, list) and bool(witnesses)
                and all(nonempty(value) for value in witnesses), f"{case_id}: witness non validi")
        if supplemental:
            require(nonempty(case["domain"]), f"{case_id}: dominio supplementare assente")
            continue
        command, variant, phase = case["command"], case["variant"], case["phase"]
        require(nonempty(command) and nonempty(variant) and (command, variant) in variants,
                f"{case_id}: variante estranea alla matrice pubblica")
        require(isinstance(phase, str) and phase in PHASES, f"{case_id}: fase non valida")
        key = (command, variant, phase)
        coverage[key] = coverage.get(key, 0) + 1
        has_fixture = "fixtureID" in case or "fixtureUnmodified" in case
        if has_fixture:
            require(command == "text-analysis" and phase == "nominal"
                    and nonempty(case.get("fixtureID")) and type(case.get("fixtureUnmodified")) is bool,
                    f"{case_id}: dichiarazione fixture non valida")
            if case["fixtureUnmodified"]:
                require(case["fixtureID"] in required_fixture_ids,
                        f"{case_id}: fixture originale non presente nel catalogo")
                covered_fixture_ids.add(case["fixtureID"])
    required_coverage = {(command, variant, phase) for command, variant in variants for phase in PHASES}
    require(set(coverage) == required_coverage,
            f"varianti o fasi BDD mancanti: {sorted(required_coverage.difference(coverage))}")
    require(seen_addresses == addresses,
            f"scenari BDD non associati a un contratto: {sorted(addresses.difference(seen_addresses))}")
    require(covered_fixture_ids == required_fixture_ids,
            f"fixture testuali originali non coperte: {sorted(required_fixture_ids - covered_fixture_ids)}")
    validate_workflows(body, surface, addresses, root)


def validate_contracts(body: object, surface: object, inventory: object, root: Path) -> list[str]:
    """Return errors; a supplied position map must already be certified by check-bdd.py.

    This validates reviewed declarations, not the truth of an oracle or implementation provenance.
    Source-line digests exclude their line terminator; no Gherkin grammar is parsed here.
    """
    try:
        _validate_contracts(body, surface, inventory, root)
    except (ValueError, OSError, UnicodeError) as error:
        return [str(error)]
    return []


def _validate_contract_report(body: object, report: object, selected: object) -> None:
    entries = all_entries(body)
    cases = {}
    for case, _ in entries:
        witnesses = case.get("witnesses")
        require(isinstance(witnesses, list) and bool(witnesses)
                and all(nonempty(value) for value in witnesses), "witness del contratto assenti o non validi")
        name, line = feature_name(case.get("feature")), case.get("line")
        require(type(line) is int and line > 0, "riga del contratto non valida")
        address = (name, line)
        require(address not in cases, f"indirizzo contrattuale duplicato: {address}")
        cases[address] = case
    expected = set(cases)
    if selected is not None:
        require(isinstance(selected, (set, frozenset)) and bool(selected), "selezione contratti vuota o non valida")
        for address in selected:
            require(isinstance(address, tuple) and len(address) == 2
                    and isinstance(address[0], str) and type(address[1]) is int and address in cases,
                    "selezione contratti non inventariata")
        expected = set(selected)
    require(isinstance(report, list) and bool(report), "report contrattuale vuoto o non valido")
    observed = {}
    features = set()
    for feature in report:
        require(isinstance(feature, dict) and isinstance(feature.get("uri"), str), "feature report non valida")
        name = feature_name(Path(feature["uri"]).name)
        require(name not in features, f"feature report duplicata: {name}")
        features.add(name)
        scenarios = feature.get("elements")
        require(isinstance(scenarios, list) and bool(scenarios), f"{name}: report senza scenari")
        for scenario in scenarios:
            require(isinstance(scenario, dict) and scenario.get("type") == "scenario", "scenario report non valido")
            line = scenario.get("line")
            require(type(line) is int and line > 0, "riga report non valida")
            address = (name, line)
            require(address in expected and address not in observed, f"scenario inatteso o duplicato: {address}")
            steps = scenario.get("steps")
            require(isinstance(steps, list) and bool(steps)
                    and all(isinstance(step, dict) and nonempty(step.get("name")) for step in steps),
                    f"{name}:{line}: nomi dei passi assenti")
            observed[address] = [step["name"] for step in steps]
    require(set(observed) == expected, f"report contrattuale parziale: {sorted(expected - set(observed))}")
    for address in expected:
        case = cases[address]
        witnesses = case.get("witnesses")
        require(isinstance(witnesses, list) and bool(witnesses) and all(nonempty(value) for value in witnesses),
                f"{address}: witness non validi")
        position = 0
        names = observed[address]
        for witness in witnesses:
            while position < len(names) and names[position] != witness:
                position += 1
            require(position < len(names), f"{address}: witness assente o fuori ordine: {witness!r}")
            position += 1


def validate_contract_report(body: object, report: object, selected=None) -> list[str]:
    """Check exact addresses and ordered step-name witnesses; check-bdd.py checks outcomes."""
    try:
        _validate_contract_report(body, report, selected)
    except (ValueError, OSError, UnicodeError) as error:
        return [str(error)]
    return []


def self_test() -> None:
    """Use real files and complete phase coverage, then reject independent corruptions."""
    require(__debug__, "il self-test richiede Python senza ottimizzazione degli assert")
    with TemporaryDirectory(prefix="glifi-bdd-contracts-") as directory:
        root = Path(directory)
        matrix = {"schema": "studio.glifi.analysis-scenarios", "schemaVersion": 1, "groups": [
            {"command": "statistics", "variants": ["normalCDF"]},
            {"command": "text-analysis", "variants": ["dissimilarities"]},
        ], "workflows": [{"id": f"GS-SCN-{index:03}"} for index in range(7, 12)]}
        for relative, value in ((SURFACE, matrix), (FIXTURES, {"cases": [{"id": "a"}, {"id": "b"}]})):
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value), encoding="utf-8")
        reference = root / "docs/reference.md"
        reference.parent.mkdir(parents=True)
        reference.write_text("Original reference\n", encoding="utf-8")
        native_test = root / "Apps/macOS/Tests/ModelTests.swift"
        native_test.parent.mkdir(parents=True)
        native_test.write_text("// SPDX-License-Identifier: BSD-3-Clause\nimport Testing\n", encoding="utf-8")
        body = {"schema": "studio.glifi.bdd-contracts", "schemaVersion": 1,
                "sourceMatrixSHA256": digest((root / SURFACE).read_bytes()), "cases": [],
                "supplementalCases": [], "workflowCoverage": []}
        lines = ["# language: it", "# SPDX-License-Identifier: BSD-3-Clause", "Funzionalità: Contratti originali"]
        positions = []
        elements = []

        def add(command="statistics", variant="normalCDF", phase="nominal", fixture=None,
                supplemental=False, intent=None):
            case_id = f"case-{len(positions)}"
            line = len(lines) + 1
            names = [f'la variante "{variant}" del caso "{case_id}"', f'eseguo la fase "{phase}"', "il risultato coincide"]
            if intent is not None:
                names[0] = f'il planner riceve l\'intento "{intent}"'
            lines.extend([f"  Scenario: {case_id}", f"    Dato {names[0]}", f"    Quando {names[1]}", f"    Allora {names[2]}"])
            case = {"caseID": case_id, "feature": "Contracts.feature", "line": line,
                    "sourceLineSHA256": digest(lines[line - 1].encode()), "oracle": "Original closed-form expectation",
                    "dataOrigin": "original-synthetic", "references": ["docs/reference.md"], "witnesses": names}
            if supplemental:
                case["domain"] = "planner-intents" if intent is not None else "unicode-boundaries"
            else:
                case.update(command=command, variant=variant, phase=phase)
                if fixture is not None:
                    case.update(fixtureID=fixture, fixtureUnmodified=True)
            body["supplementalCases" if supplemental else "cases"].append(case)
            step_metadata = [{"line": line + index + 1, "keyword": keyword, "name": name}
                             for index, (keyword, name) in enumerate(zip(("Dato", "Quando", "Allora"), names))]
            checker = runpy.run_path(str(ROOT / "Scripts/check-bdd.py"))
            positions.append({"line": line, "stepCount": len(names),
                              "stepsSHA256": checker["step_metadata_digest"](step_metadata)})
            elements.append({"type": "scenario", "line": line, "tags": [{"name": "GS-CMP-332"}, {"name": "macos"}],
                             "steps": [{**metadata, "result": {"status": "passed"}} for metadata in step_metadata]})
            return {"feature": "Contracts.feature", "line": line}

        for command, variant in (("statistics", "normalCDF"), ("text-analysis", "dissimilarities")):
            for phase in sorted(PHASES):
                add(command, variant, phase, "a" if command == "text-analysis" and phase == "nominal" else None)
        add("text-analysis", "dissimilarities", fixture="b")
        # Domain-specific failures may supplement the transport rejection in the same phase.
        add(phase="invalid-input")
        add(phase="pre-cancelled")
        general_case = add(supplemental=True)
        intent_cases = [{"intent": intent, **add(supplemental=True, intent=intent)}
                        for intent in sorted(PLANNER_INTENTS)]
        for index in range(7, 12):
            entry = {"id": f"GS-SCN-{index:03}", "mode": "bdd",
                     "cases": [dict(general_case)]}
            if index == 9:
                entry = {"id": "GS-SCN-009", "mode": "native-model",
                         "tests": ["Apps/macOS/Tests/ModelTests.swift"],
                         "limitation": "Native model tests do not automate the visible interface."}
            if index == 11:
                entry["intents"] = sorted(PLANNER_INTENTS)
                entry["intentCases"] = intent_cases
                entry["cases"] = [{"feature": case["feature"], "line": case["line"]}
                                  for case in intent_cases]
            body["workflowCoverage"].append(entry)
        feature = root / FEATURES / "Contracts.feature"
        feature.parent.mkdir(parents=True)
        feature.write_text("\n".join(lines) + "\n", encoding="utf-8")
        inventory = {"schema": "studio.glifi.bdd-coverage", "schemaVersion": 2, "features": [{"file": feature.name, "expandedScenarios": len(positions),
                     "sourceSHA256": digest(feature.read_bytes()), "scenarios": positions}]}
        report = [{"uri": "Features/Contracts.feature", "elements": elements}]
        assert not validate_contracts(body, matrix, inventory, root)
        assert not validate_contract_report(body, report)
        checker = runpy.run_path(str(ROOT / "Scripts/check-bdd.py"))
        certified = checker["validate_inventory"](inventory, root)
        assert certified_inventory(certified, root) == certified
        assert checker["validate_report"](report, certified) == len(positions) * 3
        assert not validate_contracts(body, matrix, certified, root)
        first_line = positions[0]["line"]
        expectation_type = type(certified[feature.name][first_line])
        for invalid in (True, 3, (3, "0" * 64), expectation_type(True, "0" * 64),
                        expectation_type(3, "invalid"), expectation_type(0, "0" * 64)):
            changed_inventory = copy.deepcopy(certified)
            changed_inventory[feature.name][first_line] = invalid
            assert validate_contracts(body, matrix, changed_inventory, root)
        mutations = []
        changed = copy.deepcopy(body); changed["cases"][0]["variant"] = "missing"; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"].pop(0); mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["phase"] = "missing"; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["line"] = changed["cases"][1]["line"]; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["line"] = 999; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["line"] = True; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["sourceLineSHA256"] = "0" * 64; mutations.append(changed)
        changed = copy.deepcopy(body); changed["sourceMatrixSHA256"] = "0" * 64; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["references"] = ["docs/missing.md"]; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["references"] = ["../outside.md"]; mutations.append(changed)
        changed = copy.deepcopy(body); changed["cases"][0]["oracle"] = " "; mutations.append(changed)
        changed = copy.deepcopy(body); changed["supplementalCases"] = []; mutations.append(changed)
        changed = copy.deepcopy(body)
        del next(case for case in changed["cases"] if case.get("fixtureID") == "a")["fixtureID"]
        mutations.append(changed)
        changed = copy.deepcopy(body)
        next(case for case in changed["cases"] if case.get("fixtureID") == "a")["fixtureUnmodified"] = False
        mutations.append(changed)
        changed = copy.deepcopy(body); changed["workflowCoverage"].pop(); mutations.append(changed)
        changed = copy.deepcopy(body); changed["workflowCoverage"][2]["mode"] = "bdd"; mutations.append(changed)
        changed = copy.deepcopy(body); changed["workflowCoverage"][2]["limitation"] = ""; mutations.append(changed)
        changed = copy.deepcopy(body); changed["workflowCoverage"][0]["cases"][0]["line"] = 999; mutations.append(changed)
        changed = copy.deepcopy(body); changed["workflowCoverage"][-1]["intents"].pop(); mutations.append(changed)
        for collection in ("cases", "supplementalCases"):
            for value in (None, [], [" "]):
                changed = copy.deepcopy(body)
                if value is None:
                    del changed[collection][0]["witnesses"]
                else:
                    changed[collection][0]["witnesses"] = value
                mutations.append(changed)
                assert validate_contract_report(changed, report), "Report accepted without valid witnesses"
        changed = copy.deepcopy(body)
        del changed["workflowCoverage"][-1]["intentCases"]
        mutations.append(changed)
        changed = copy.deepcopy(body); changed["workflowCoverage"][-1]["intentCases"].pop(); mutations.append(changed)
        changed = copy.deepcopy(body)
        changed["workflowCoverage"][-1]["intentCases"][1]["intent"] = intent_cases[0]["intent"]
        mutations.append(changed)
        changed = copy.deepcopy(body)
        changed["workflowCoverage"][-1]["intentCases"][1]["line"] = intent_cases[0]["line"]
        mutations.append(changed)
        changed = copy.deepcopy(body); changed["workflowCoverage"][-1]["intentCases"][0]["line"] = 999; mutations.append(changed)
        changed = copy.deepcopy(body)
        changed["workflowCoverage"][-1]["intentCases"][0]["line"] = general_case["line"]
        mutations.append(changed)
        changed = copy.deepcopy(body)
        changed["workflowCoverage"][-1]["intentCases"][0]["line"] = intent_cases[1]["line"]
        changed["workflowCoverage"][-1]["intentCases"][1]["line"] = intent_cases[0]["line"]
        mutations.append(changed)
        changed = copy.deepcopy(body)
        next(case for case in changed["supplementalCases"]
             if case["line"] == intent_cases[0]["line"])["witnesses"].pop(0)
        mutations.append(changed)
        changed = copy.deepcopy(body)
        changed["workflowCoverage"][-1]["cases"] = [changed["workflowCoverage"][-1]["cases"][0]]
        mutations.append(changed)
        for index, changed in enumerate(mutations):
            assert validate_contracts(changed, matrix, inventory, root), f"Invalid contract accepted: {index}"
        partial = copy.deepcopy(report); partial[0]["elements"].pop()
        assert validate_contract_report(body, partial)
        wrong = copy.deepcopy(report); wrong[0]["elements"][0]["steps"][0]["name"] = "un altro caso"
        assert validate_contract_report(body, wrong)
        swapped = copy.deepcopy(report)
        swapped[0]["elements"][0]["steps"], swapped[0]["elements"][1]["steps"] = (
            swapped[0]["elements"][1]["steps"], swapped[0]["elements"][0]["steps"])
        assert validate_contract_report(body, swapped)
        duplicate = copy.deepcopy(report); duplicate[0]["elements"].append(copy.deepcopy(elements[0]))
        assert validate_contract_report(body, duplicate)
        selected = {(feature.name, positions[0]["line"])}
        selected_report = [{"uri": "Features/Contracts.feature", "elements": [elements[0]]}]
        assert not validate_contract_report(body, selected_report, selected)
        changed = copy.deepcopy(body); del changed["cases"][0]["witnesses"]
        assert validate_contract_report(changed, selected_report, selected)
        changed = copy.deepcopy(body); changed["supplementalCases"][-1]["witnesses"] = []
        assert validate_contract_report(changed, selected_report, selected)
        assert validate_contract_report(body, selected_report)
        assert validate_contract_report(body, report, selected)
        assert validate_contract_report(body, report, set())
        assert validate_contract_report(body, report, {(feature.name, 999)})
        assert validate_contract_report(body, [])
    print(f"BDD contracts self-test: complete mapping, {len(mutations)} invalid declarations and report controls passed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--report", type=Path, help="Cucumber JSON report to bind to reviewed contracts")
    parser.add_argument("--select", help="Exact developer selection accepted by check-bdd.py")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
            return 0
        checker = runpy.run_path(str(ROOT / "Scripts/check-bdd.py"))
        body = checker["read_json"](ROOT / CONTRACTS)
        surface = checker["read_json"](ROOT / SURFACE)
        inventory = checker["validate_inventory"](checker["read_json"](ROOT / INVENTORY), ROOT)
        errors = validate_contracts(body, surface, inventory, ROOT)
        if errors:
            raise ValueError("; ".join(errors))
        selected = checker["select_inventory"](inventory, args.select) if args.select is not None else inventory
        if args.report is not None:
            report = checker["read_json"](args.report)
            checker["validate_report"](report, selected)
            addresses = {(name, line) for name, positions in selected.items() for line in positions}
            errors = validate_contract_report(body, report, addresses if args.select is not None else None)
            if errors:
                raise ValueError("; ".join(errors))
        print(f"BDD contracts: {len(surface_variants(surface))} variants in three phases; "
              f"{len(body['cases'])} public cases, {len(body['supplementalCases'])} supplemental cases")
        return 0
    except (ValueError, OSError, UnicodeError) as error:
        print(f"BDD contract validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
