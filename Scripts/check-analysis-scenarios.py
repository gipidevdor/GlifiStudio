#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check the analysis inventory and test references, without inferring execution."""

from __future__ import annotations

import argparse
import ast
import copy
import functools
import importlib.util
import json
import re
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
MATRIX = ROOT / "Config/Testing/analysis-scenarios.json"
spec = importlib.util.spec_from_file_location("kit_cli_parity", ROOT / "Scripts/check-kit-cli-parity.py")
if spec is None or spec.loader is None:
    raise RuntimeError("The canonical Kit inventory checker is unavailable")
KIT = importlib.util.module_from_spec(spec)
spec.loader.exec_module(KIT)


def expected_operations(symbols: dict[str, dict]) -> dict[str, set[str]]:
    baseline = KIT.read_json(KIT.BASELINE)
    families = {}
    for family in baseline["operationFamilies"]:
        cases = {
            entry["path"][-1] for entry in symbols.values()
            if entry["kind"] == "swift.enum.case" and entry["path"][:-1] == [family["enum"]]
        }
        if not cases:
            raise ValueError(f"Missing compiler cases for {family['enum']}")
        families[family["command"]] = cases
    families["text-analysis"] = KIT.text_operation_inventory(symbols)["all"]
    return families


def referenced_file(relative: str) -> Path:
    if not isinstance(relative, str) or not relative:
        raise ValueError("An evidence reference requires a relative path")
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts or ".git" in path.parts:
        raise ValueError(f"Unsafe evidence reference: {relative}")
    resolved = (ROOT / path).resolve()
    if not resolved.is_relative_to(ROOT) or not resolved.is_file():
        raise ValueError(f"Missing evidence reference: {relative}")
    return resolved


@functools.lru_cache(maxsize=128)
def swift_test_names(source: str) -> frozenset[str]:
    """Recognize test declarations, ignoring comments and quoted fixture text."""
    masked = list(source)
    quoted = re.compile(r'(#+)?("""|")')
    position = 0
    while position < len(source):
        start = position
        if source.startswith("//", position):
            end = source.find("\n", position)
            position = len(source) if end < 0 else end
        elif source.startswith("/*", position):
            position += 2
            depth = 1
            while position < len(source) and depth:
                if source.startswith("/*", position):
                    depth += 1
                    position += 2
                elif source.startswith("*/", position):
                    depth -= 1
                    position += 2
                else:
                    position += 1
        else:
            match = quoted.match(source, position)
            if match is None:
                position += 1
                continue
            hashes, quotes = match.group(1) or "", match.group(2)
            position = match.end()
            delimiter = quotes + hashes
            while position < len(source):
                if source.startswith(delimiter, position):
                    position += len(delimiter)
                    break
                if not hashes and source[position] == "\\":
                    position += 2
                else:
                    position += 1
        for index in range(start, min(position, len(source))):
            if masked[index] != "\n":
                masked[index] = " "
    pending = False
    names = set()
    for token in re.finditer(r"@Test\b|\bfunc\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(", "".join(masked)):
        if token.group(1) is None:
            pending = True
        else:
            if pending:
                names.add(token.group(1))
            pending = False
    return frozenset(names)


def is_python_check_entrypoint(source: str, symbol: str) -> bool:
    if symbol != "main":
        return False
    tree = ast.parse(source)
    defined = any(isinstance(node, ast.FunctionDef) and node.name == symbol for node in tree.body)
    for node in tree.body:
        if not isinstance(node, ast.If) or not isinstance(node.test, ast.Compare):
            continue
        test = node.test
        if not (isinstance(test.left, ast.Name) and test.left.id == "__name__"
                and len(test.ops) == 1 and isinstance(test.ops[0], ast.Eq)
                and len(test.comparators) == 1 and isinstance(test.comparators[0], ast.Constant)
                and test.comparators[0].value == "__main__"):
            continue
        calls_main = any(
            isinstance(child, ast.Call) and isinstance(child.func, ast.Name)
            and child.func.id == symbol for statement in node.body for child in ast.walk(statement)
        )
        if defined and calls_main:
            return True
    return False


def check_references(references: list[dict]) -> None:
    if not isinstance(references, list) or not references:
        raise ValueError("A scenario requires executable test references")
    seen = set()
    for reference in references:
        if not isinstance(reference, dict) or set(reference) != {"path", "symbol"}:
            raise ValueError("A test reference requires path and symbol only")
        path = referenced_file(reference["path"])
        symbol = reference["symbol"]
        if not isinstance(symbol, str) or re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", symbol) is None:
            raise ValueError("Invalid test symbol")
        identity = (reference["path"], symbol)
        if identity in seen:
            raise ValueError("Duplicate test reference")
        seen.add(identity)
        source = path.read_text(encoding="utf-8")
        if path.suffix == ".swift":
            valid = "Tests" in path.parts and symbol in swift_test_names(source)
        elif path.suffix == ".py":
            valid = "Scripts" in path.parts and is_python_check_entrypoint(source, symbol)
        else:
            valid = False
        if not valid:
            raise ValueError(f"Missing executable test or check entrypoint: {reference['path']}::{symbol}")


def nonempty_text(value) -> bool:
    return isinstance(value, str) and bool(value.strip())


def string_list(value, *, allow_empty=False) -> bool:
    return isinstance(value, list) and (allow_empty or bool(value)) and all(nonempty_text(item) for item in value)


def validate(matrix: dict, symbols: dict[str, dict]) -> tuple[int, int]:
    if not isinstance(matrix, dict) or set(matrix) != {"schema", "schemaVersion", "scope", "groups", "workflows", "limitations"}:
        raise ValueError("Unexpected analysis scenario matrix fields")
    if matrix["schema"] != "studio.glifi.analysis-scenarios" or type(matrix["schemaVersion"]) is not int or matrix["schemaVersion"] != 1:
        raise ValueError("Unsupported analysis scenario matrix schema")
    if not nonempty_text(matrix["scope"]) or not string_list(matrix["limitations"]):
        raise ValueError("Scope and open limitations must be explicit")
    if not isinstance(matrix["groups"], list) or not isinstance(matrix["workflows"], list):
        raise ValueError("Groups and workflows must be lists")
    expected = expected_operations(symbols)
    ids = set()
    groups = {}
    count = 0
    for group in matrix["groups"]:
        if not isinstance(group, dict) or set(group) != {"id", "command", "variants", "contracts", "tests", "scientificReferences", "nativeScope", "headlessOnly"}:
            raise ValueError("Unexpected scenario group fields")
        identifier, command = group["id"], group["command"]
        if not isinstance(identifier, str) or re.fullmatch(r"GS-SCN-\d{3}", identifier) is None or not nonempty_text(command):
            raise ValueError("Invalid scenario identifier or command")
        if identifier in ids or command in groups or command not in expected:
            raise ValueError("Duplicate or unknown scenario group")
        ids.add(identifier)
        groups[command] = group
        variants = group["variants"]
        if not string_list(variants) or len(variants) != len(set(variants)) or set(variants) != expected[command]:
            raise ValueError(f"Incomplete or duplicate scenario variants for {command}")
        if not string_list(group["contracts"]) or not nonempty_text(group["nativeScope"]) or not string_list(group["scientificReferences"]):
            raise ValueError("Missing contracts, scientific references or native scope")
        if not string_list(group["headlessOnly"], allow_empty=True) or len(group["headlessOnly"]) != len(set(group["headlessOnly"])):
            raise ValueError("Invalid headless-only declarations")
        for path in group["scientificReferences"]:
            referenced_file(path)
        check_references(group["tests"])
        count += len(variants)
    if set(groups) != set(expected):
        raise ValueError("The scenario matrix omits an operation family")
    kh = KIT.text_operation_inventory(symbols)["kh"]
    if set(groups["text-analysis"]["headlessOnly"]) != kh:
        raise ValueError("KH native coverage requires a separately evidenced GUI implementation")
    for group in matrix["groups"]:
        if group["command"] != "text-analysis" and group["headlessOnly"]:
            raise ValueError("Unexpected headless-only declarations")
    for flow in matrix["workflows"]:
        if not isinstance(flow, dict) or set(flow) != {"id", "description", "contracts", "tests", "limitations"}:
            raise ValueError("Unexpected workflow fields")
        if not isinstance(flow["id"], str) or re.fullmatch(r"GS-SCN-\d{3}", flow["id"]) is None:
            raise ValueError("Invalid workflow identifier")
        if flow["id"] in ids or not string_list(flow["contracts"]) or not nonempty_text(flow["description"]) or not string_list(flow["limitations"], allow_empty=True):
            raise ValueError("Duplicate or incomplete workflow")
        ids.add(flow["id"])
        check_references(flow["tests"])
    if not matrix["workflows"]:
        raise ValueError("Integration workflows must be recorded")
    return count, len(matrix["workflows"])


def check_negative_controls(matrix: dict, symbols: dict[str, dict]) -> None:
    class ScenarioInventoryTests(unittest.TestCase):
        def rejects(self, change):
            altered = copy.deepcopy(matrix)
            change(altered)
            with self.assertRaises(ValueError):
                validate(altered, symbols)

        def test_missing_variant(self):
            self.rejects(lambda value: value["groups"][0]["variants"].pop())

        def test_duplicate_variant(self):
            self.rejects(lambda value: value["groups"][0]["variants"].append(value["groups"][0]["variants"][0]))

        def test_missing_family(self):
            self.rejects(lambda value: value["groups"].pop())

        def test_missing_test(self):
            self.rejects(lambda value: value["groups"][0]["tests"][0].update(symbol="nonexistentScenario"))

        def test_missing_oracle(self):
            self.rejects(lambda value: value["groups"][0].update(scientificReferences=[]))

        def test_unsafe_reference(self):
            self.rejects(lambda value: value["groups"][0]["tests"][0].update(path="../outside.swift"))

        def test_false_native_claim(self):
            self.rejects(lambda value: next(group for group in value["groups"] if group["command"] == "text-analysis")["headlessOnly"].clear())

        def test_new_compiler_case_requires_coverage(self):
            added = copy.deepcopy(symbols)
            added["scenario-injected-case"] = {"kind": "swift.enum.case", "path": ["GlifiStudioStatisticsOperation", "injectedScenario"]}
            with self.assertRaises(ValueError):
                validate(matrix, added)

        def test_swift_helper_is_not_a_test(self):
            self.rejects(lambda value: value["groups"][0]["tests"][0].update(
                path="Apps/macOS/Tests/StudioCorpusMethodsTests.swift", symbol="configuredModel"))

        def test_python_helper_is_not_a_check_entrypoint(self):
            self.rejects(lambda value: value["groups"][0]["tests"][0].update(
                path="Scripts/check-text-analysis-cli.py", symbol="compare"))

        def test_fixture_text_and_comments_are_not_tests(self):
            source = '// @Test func comment() {}\n/* outer /* @Test */ func nested() {} */\n'
            source += 'let raw = #"""@Test func fixture() {}"""#\n'
            source += '@Test("func label()") func actual() {}\nfunc helper() {}\n'
            self.assertEqual(swift_test_names(source), {"actual"})

        def test_boolean_schema_version_is_rejected(self):
            self.rejects(lambda value: value.update(schemaVersion=True))

        def test_numeric_scope_is_rejected(self):
            self.rejects(lambda value: value.update(scope=123))

        def test_object_limitations_are_rejected(self):
            self.rejects(lambda value: value.update(limitations={"unexpected": "shape"}))

    suite = unittest.defaultTestLoader.loadTestsFromTestCase(ScenarioInventoryTests)
    result = unittest.TextTestRunner(verbosity=0).run(suite)
    if not result.wasSuccessful():
        raise ValueError("Scenario inventory negative controls failed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbol-graph", type=Path)
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    try:
        if arguments.symbol_graph is None:
            symbols = {entry["identifier"]: entry for entry in KIT.read_json(KIT.BASELINE)["symbols"]}
        else:
            symbols = KIT.public_symbols(arguments.symbol_graph)
            KIT.check_baseline(KIT.BASELINE, symbols)
        matrix = KIT.read_json(MATRIX)
        count, flows = validate(matrix, symbols)
        if arguments.self_test:
            check_negative_controls(matrix, symbols)
        source = "compiler" if arguments.symbol_graph else "reviewed baseline"
        print(f"Analysis scenarios: {count} operation variants, {flows} integration workflows; {source} and test references valid")
        return 0
    except (ValueError, KeyError, TypeError, OSError, json.JSONDecodeError) as error:
        print(f"Analysis scenario validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
