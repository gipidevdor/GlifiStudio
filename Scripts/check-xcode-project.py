#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check Xcode metadata without building, resolving packages, or rewriting files.

The portable profile checks XML and xcconfig contracts. The full macOS profile
additionally uses Apple's plutil parser for the OpenStep project, then checks
its graph, target membership, and repository inventory. These are distinct
profiles; portable success does not imply that the project graph was checked.
"""

from __future__ import annotations

import argparse
import copy
import json
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path


PROJECT = "GlifiStudio.xcodeproj/project.pbxproj"
WORKSPACE = "GlifiStudio.xcworkspace/contents.xcworkspacedata"
TARGETS = ("GlifiStudio-macOS", "GlifiStudio-iPadOS", "GlifiStudioMacTests")
SCHEMES = {
    "GlifiStudio-macOS": "GlifiStudio.xcodeproj/xcshareddata/xcschemes/GlifiStudio-macOS.xcscheme",
    "GlifiStudio-iPadOS": "GlifiStudio.xcodeproj/xcshareddata/xcschemes/GlifiStudio-iPadOS.xcscheme",
}
CONFIGS = {
    TARGETS[0]: {"Debug": "Config/macOS-Debug.xcconfig", "Release": "Config/macOS-Release.xcconfig"},
    TARGETS[1]: {"Debug": "Config/iPadOS-Debug.xcconfig", "Release": "Config/iPadOS-Release.xcconfig"},
    TARGETS[2]: {"Debug": "Config/macOS-Tests.xcconfig", "Release": "Config/macOS-Tests-Release.xcconfig"},
}
NATIVE_FOLDERS = {
    "docs", "Scripts", "Fixtures", "Design", "Distribution", "Benchmarks", ".github",
    "Config/CLI", "Config/Compliance", "Config/GitHub", "Config/Licenses", "Config/Testing", "Packages/GlifiCore",
}
# This is the reviewed hostless support contract from d368285 / capture fdda8209.
# App sources and actual test files are derived independently from the filesystem.
TEST_SUPPORT = {
    "Apps/Shared/StudioHomeModel.swift", "Apps/Shared/StudioWorkspaceNavigation.swift",
    "Apps/Shared/StudioLocalization.swift",
    "Apps/Shared/StudioVisualExportPreparation.swift", "Apps/Shared/StudioFactorAudioGraph.swift",
    "Apps/Shared/StudioPlotSeries.swift", "Apps/macOS/StudioLinguisticModel.swift",
    "Apps/macOS/StudioOperatorsModel.swift", "Apps/macOS/StudioCorpusMethodsModel.swift",
    "Apps/macOS/StudioStatisticsModel.swift", "Apps/macOS/StudioEvaluationModel.swift",
    "Apps/macOS/StudioCoreMethodRoute.swift", "Apps/macOS/StudioAdvancedAnalysisModel.swift",
    "Apps/macOS/StudioSourceLookup.swift", "Apps/macOS/StudioMacRuntimeMonitor.swift",
}
GROUPS = {"PBXGroup", "PBXVariantGroup", "PBXFileSystemSynchronizedRootGroup"}
FILE_KINDS = {"PBXFileReference", "PBXVariantGroup"}
PHASES = {"PBXSourcesBuildPhase", "PBXResourcesBuildPhase", "PBXFrameworksBuildPhase"}
KNOWN_ISAS = GROUPS | PHASES | {
    "PBXBuildFile", "XCBuildConfiguration", "PBXNativeTarget", "XCConfigurationList",
    "XCLocalSwiftPackageReference", "XCSwiftPackageProductDependency", "PBXProject", "PBXFileReference",
}
# Existing Xcode object tokens include I/J/H prefixes, not only hex digits.
ID = re.compile(r"[A-Z0-9]{24}\Z")
INCLUDE = re.compile(r'^#include\s+"([^"\n]+)"\s*(?://.*)?$')
ASSIGNMENT = re.compile(r"^([A-Za-z_][A-Za-z_0-9]*)\s*(\+=|\?=|=)\s*(.*?)\s*$")


class Problems:
    """Collect actionable failures instead of aborting at the first bad edge."""

    def __init__(self) -> None:
        self.errors: list[str] = []

    def require(self, condition: bool, message: str) -> bool:
        if not condition:
            self.errors.append(message)
        return condition


def contained(root: Path, parent: Path, raw: str, issues: Problems, context: str) -> Path | None:
    """Reject lexical and symlink escapes before reading referenced content."""
    path = Path(raw)
    if not issues.require(bool(raw) and not path.is_absolute() and ".." not in path.parts
                          and "$" not in raw, f"{context}: unsafe repository-relative path {raw!r}"):
        return None
    resolved = (parent / path).resolve()
    if not issues.require(resolved.is_relative_to(root), f"{context}: path escapes repository: {raw!r}"):
        return None
    return resolved


def read_xml(root: Path, relative: str, issues: Problems) -> ET.Element | None:
    path = contained(root, root, relative, issues, relative)
    if path is None:
        return None
    try:
        return ET.parse(path).getroot()
    except (OSError, ET.ParseError) as error:
        issues.errors.append(f"{relative}: cannot read XML: {error}")
        return None


def load_config(root: Path, path: Path, issues: Problems, stack: tuple[Path, ...] = ()) -> dict[str, str]:
    try:
        safe = contained(root, root, path.relative_to(root).as_posix(), issues, "xcconfig")
    except ValueError:
        issues.errors.append(f"xcconfig: path is outside the repository: {path}")
        return {}
    if safe is None:
        return {}
    path = safe
    if path in stack:
        issues.errors.append("xcconfig include cycle: " + " -> ".join(str(p.relative_to(root)) for p in (*stack, path)))
        return {}
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        issues.errors.append(f"{path.relative_to(root)}: cannot read xcconfig: {error}")
        return {}
    settings: dict[str, str] = {}
    for number, line in enumerate(lines, 1):
        text = line.strip()
        if not text or text.startswith("//"):
            continue
        context = f"{path.relative_to(root)}:{number}"
        include = INCLUDE.fullmatch(text)
        if include:
            child = contained(root, path.parent, include[1], issues, context)
            if child is not None:
                settings.update(load_config(root, child, issues, (*stack, path)))
            continue
        if text.startswith("#include"):
            issues.errors.append(f"{context}: unsupported include; use a required quoted repository-relative path")
            continue
        assignment = ASSIGNMENT.fullmatch(text)
        if not assignment:
            issues.errors.append(f"{context}: unsupported xcconfig statement: {text}")
            continue
        key, operation, value = assignment.groups()
        previous = settings.get(key, "")
        value = value.replace("$(inherited)", previous)
        if operation == "+=":
            settings[key] = (previous + " " + value).strip()
        elif operation != "?=" or key not in settings:
            settings[key] = value
    return settings


def validate_configs(root: Path, issues: Problems) -> None:
    # Check every file, including Common and future referenced configuration files.
    for path in sorted((root / "Config").rglob("*.xcconfig")):
        safe = contained(root, root, path.relative_to(root).as_posix(), issues, "xcconfig inventory")
        if safe is not None:
            load_config(root, safe, issues)
    for target, configurations in CONFIGS.items():
        for name, relative in configurations.items():
            values = load_config(root, root / relative, issues)
            expected = {
                "SWIFT_VERSION": "6.0", "SWIFT_STRICT_CONCURRENCY": "complete",
                "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor", "SWIFT_TREAT_WARNINGS_AS_ERRORS": "YES",
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if name == "Debug" else "-O",
                "DEBUG_INFORMATION_FORMAT": "dwarf" if name == "Debug" else "dwarf-with-dsym",
                "SDKROOT": "iphoneos" if target == TARGETS[1] else "macosx",
            }
            if name == "Release":
                expected["SWIFT_COMPILATION_MODE"] = "wholemodule"
            if target == TARGETS[2]:
                expected.update({"TEST_HOST": "", "BUNDLE_LOADER": "", "GENERATE_INFOPLIST_FILE": "YES"})
            for key, value in expected.items():
                issues.require(values.get(key) == value, f"{relative}: expected {key}={value!r}, got {values.get(key)!r}")
            conditions = values.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "").split()
            issues.require(("DEBUG" in conditions) == (name == "Debug"), f"{relative}: DEBUG condition must match {name}")


def validate_scheme(element: ET.Element, name: str, issues: Problems, objects: dict | None = None) -> None:
    issues.require(element.tag == "Scheme", f"{name}: root element must be Scheme")
    for action in ("TestAction", "LaunchAction", "ProfileAction", "AnalyzeAction", "ArchiveAction"):
        nodes = element.findall(action)
        if not issues.require(len(nodes) == 1, f"{name}: expected one {action}"):
            continue
        expected = "Debug" if action in {"TestAction", "LaunchAction"} else "Release"
        if name == TARGETS[1] and action == "AnalyzeAction":
            expected = "Debug"  # Preserve the deferred platform's current scheme contract.
        issues.require(nodes[0].get("buildConfiguration") == expected, f"{name}/{action}: expected {expected} configuration")
        allowed = {TARGETS[2]} if action == "TestAction" and name == TARGETS[0] else ({name} if action in {"LaunchAction", "ProfileAction"} else set())
        action_refs = list(nodes[0].iter("BuildableReference"))
        expected_count = 1 if allowed else 0
        issues.require(len(action_refs) == expected_count and all(r.get("BlueprintName") in allowed for r in action_refs), f"{name}/{action}: wrong buildable target for this action")
    build_actions = element.findall("BuildAction")
    issues.require(len(build_actions) == 1, f"{name}: expected one BuildAction")
    entries = element.findall("./BuildAction/BuildActionEntries/BuildActionEntry")
    entry_names = [e.find("BuildableReference").get("BlueprintName") if e.find("BuildableReference") is not None else None for e in entries]
    expected_names = [name, TARGETS[2]] if name == TARGETS[0] else [name]
    issues.require(Counter(entry_names) == Counter(expected_names), f"{name}: BuildAction must contain only its app and applicable native tests")
    for entry in entries:
        reference = entry.find("BuildableReference")
        if reference is not None and reference.get("BlueprintName") == name:
            for flag in ("buildForTesting", "buildForRunning", "buildForProfiling", "buildForArchiving", "buildForAnalyzing"):
                issues.require(entry.get(flag) == "YES", f"{name}: app build entry must retain {flag}=YES")
    for reference in element.iter("BuildableReference"):
        issues.require(reference.get("ReferencedContainer") == "container:GlifiStudio.xcodeproj", f"{name}: unexpected buildable container")
        target_id = reference.get("BlueprintIdentifier", "")
        issues.require(bool(ID.fullmatch(target_id)), f"{name}: invalid BlueprintIdentifier {target_id!r}")
        if objects is not None:
            target = objects.get(target_id, {})
            issues.require(target.get("isa") == "PBXNativeTarget", f"{name}: scheme references missing/wrong target {target_id}")
            issues.require(target.get("name") == reference.get("BlueprintName"), f"{name}: BlueprintName does not match target {target_id}")
            product = objects.get(target.get("productReference"), {})
            issues.require(product.get("path") == reference.get("BuildableName"), f"{name}: BuildableName does not match product {target_id}")
    if name == TARGETS[0]:
        entries = element.findall("./BuildAction/BuildActionEntries/BuildActionEntry")
        tests = [e for e in entries if e.find("BuildableReference") is not None and e.find("BuildableReference").get("BlueprintName") == TARGETS[2]]
        if issues.require(len(tests) == 1, f"{name}: expected one explicit test build entry"):
            for flag in ("buildForTesting", "buildForRunning", "buildForProfiling", "buildForArchiving", "buildForAnalyzing"):
                issues.require(tests[0].get(flag) == ("YES" if flag == "buildForTesting" else "NO"), f"{name}: test entry must enable only buildForTesting ({flag})")
        testables = element.findall("./TestAction/Testables/TestableReference")
        issues.require(len(testables) == 1 and testables[0].get("skipped") == "NO", f"{name}: native tests must be enabled")


def portable(root: Path, issues: Problems, objects: dict | None = None) -> None:
    workspace = read_xml(root, WORKSPACE, issues)
    if workspace is not None:
        issues.require(workspace.tag == "Workspace", "workspace: expected Workspace root")
        locations = [ref.get("location", "") for ref in workspace.iter("FileRef")]
        issues.require(locations == ["group:GlifiStudio.xcodeproj"], "workspace: expected exactly the canonical project reference")
        for location in locations:
            if location.startswith("group:"):
                path = contained(root, root, location[6:], issues, "workspace reference")
                if path is not None:
                    issues.require(path.is_dir(), "workspace: referenced project directory is missing")
    for name, relative in SCHEMES.items():
        scheme = read_xml(root, relative, issues)
        if scheme is not None:
            validate_scheme(scheme, name, issues, objects)
    validate_configs(root, issues)


def inventory(root: Path) -> list[str]:
    result = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root, capture_output=True, check=True)
    return sorted({p.decode("utf-8") for p in result.stdout.split(b"\0") if p})


def reject_duplicate_object_definitions(text: str) -> None:
    """Check immediate objects-map keys before plutil normalizes duplicates.

    This is a supplemental lexical check, not an OpenStep graph parser. Quotes
    and comments must be recognized so nested attributes, labels, and comments
    cannot masquerade as object definitions. plutil still parses every graph.
    """
    tokens: list[tuple[str, str, int]] = []
    index = 0
    symbols = "{}()=;,"
    escapes = {"a": "\a", "b": "\b", "t": "\t", "n": "\n", "v": "\v", "f": "\f", "r": "\r"}
    while index < len(text):
        if text[index].isspace():
            index += 1
        elif text.startswith("//", index):
            end = text.find("\n", index + 2)
            index = len(text) if end < 0 else end + 1
        elif text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("PBX lexical check: unterminated block comment")
            index = end + 2
        elif text[index] == '"':
            start = index
            index += 1
            value = []
            while index < len(text) and text[index] != '"':
                character = text[index]
                index += 1
                if character == "\\":
                    if index >= len(text):
                        raise ValueError("PBX lexical check: unterminated quoted escape")
                    character = text[index]
                    index += 1
                    if character == "\n":
                        continue
                    if character == "U":
                        digits = text[index:index + 4]
                        if len(digits) != 4 or any(c not in "0123456789abcdefABCDEF" for c in digits):
                            raise ValueError("PBX lexical check: invalid quoted Unicode escape")
                        character = chr(int(digits, 16))
                        index += 4
                    elif character in "01234567":
                        digits = character
                        while len(digits) < 3 and index < len(text) and text[index] in "01234567":
                            digits += text[index]
                            index += 1
                        character = chr(int(digits, 8))
                    else:
                        character = escapes.get(character, character)
                value.append(character)
            if index >= len(text):
                raise ValueError("PBX lexical check: unterminated quoted string")
            index += 1
            tokens.append(("atom", "".join(value), start))
        elif text[index] in symbols:
            tokens.append(("symbol", text[index], index))
            index += 1
        else:
            start = index
            while index < len(text) and not text[index].isspace() and text[index] not in symbols + '"':
                if text.startswith("//", index) or text.startswith("/*", index):
                    break
                index += 1
            tokens.append(("atom", text[start:index], start))
    depth = 0
    objects_depth: int | None = None
    objects_opening: int | None = None
    maps = 0
    seen: dict[str, int] = {}
    for position, (kind, value, offset) in enumerate(tokens):
        following = [token[1] for token in tokens[position + 1:position + 3]]
        if kind == "atom" and value == "objects" and depth == 1 and following == ["=", "{"]:
            maps += 1
            if maps != 1:
                raise ValueError("PBX lexical check: repeated top-level objects dictionary")
            objects_opening = position + 2
        if kind == "symbol" and value == "{":
            depth += 1
            if position == objects_opening:
                objects_depth = depth
        elif kind == "symbol" and value == "}":
            if depth == objects_depth:
                objects_depth = None
            depth -= 1
        elif objects_depth is not None and depth == objects_depth and kind == "atom" and following[:1] == ["="]:
            if value in seen:
                first_line = text.count("\n", 0, seen[value]) + 1
                duplicate_line = text.count("\n", 0, offset) + 1
                raise ValueError(f"PBX lexical check: duplicate object definition {value!r} at lines {first_line} and {duplicate_line}")
            seen[value] = offset
    if maps != 1:
        raise ValueError("PBX lexical check: expected one top-level objects dictionary")


def parse_project(root: Path) -> dict:
    if sys.platform != "darwin":
        raise ValueError("full PBX validation requires macOS/plutil; --portable checks only XML and xcconfig")
    issues = Problems()
    path = contained(root, root, PROJECT, issues, PROJECT)
    if path is None:
        raise ValueError("; ".join(issues.errors))
    text = path.read_text(encoding="utf-8")
    reject_duplicate_object_definitions(text)
    # Parse exactly the checked bytes; never replace the native graph parser.
    result = subprocess.run(["plutil", "-convert", "json", "-o", "-", "--", "-"], input=text, capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise ValueError(f"{PROJECT}: plutil could not parse OpenStep project: {result.stderr.strip() or result.stdout.strip()}")
    return json.loads(result.stdout)


def validate_graph(root: Path, graph: dict, paths: list[str], issues: Problems) -> dict[str, int]:
    objects = graph.get("objects", {})
    if not issues.require(isinstance(objects, dict) and bool(objects), "PBX: objects must be a nonempty dictionary"):
        return {}
    for oid, node in objects.items():
        issues.require(bool(ID.fullmatch(oid)), f"PBX: invalid object ID {oid!r}")
        if not isinstance(node, dict):
            issues.errors.append(f"PBX/{oid}: expected object dictionary")
            return {}
        issues.require(node.get("isa") in KNOWN_ISAS, f"PBX/{oid}: unsupported object kind {node.get('isa')!r}; extend its explicit validation contract")

    def edge(owner: str, field: str, kinds: set[str], many: bool = False, required: bool = True) -> None:
        node = objects[owner]
        if field not in node and not required:
            return
        values = node.get(field, [] if many else None)
        if many and not isinstance(values, list):
            issues.errors.append(f"PBX/{owner}/{field}: expected reference array")
            return
        for value in values if many else [values]:
            target = objects.get(value, {}) if isinstance(value, str) else {}
            issues.require(target.get("isa") in kinds, f"PBX/{owner}/{field}: missing or wrong-kind reference {value!r}; expected {sorted(kinds)}")

    # Validate all ID-looking values and keys as well as the typed edges below.
    def references(value: object, owner: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                if ID.fullmatch(str(key)):
                    issues.require(key in objects, f"PBX/{owner}: dangling attribute target {key}")
                references(child, owner)
        elif isinstance(value, list):
            for child in value:
                references(child, owner)
        elif isinstance(value, str) and ID.fullmatch(value):
            issues.require(value in objects, f"PBX/{owner}: dangling reference {value}")
    for oid, node in objects.items():
        references(node, oid)
        isa = node.get("isa")
        if isa in {"PBXGroup", "PBXVariantGroup"}:
            edge(oid, "children", GROUPS | {"PBXFileReference"}, many=True)
        elif isa == "PBXBuildFile":
            issues.require(("fileRef" in node) != ("productRef" in node), f"PBX/{oid}: build file needs exactly one fileRef/productRef")
            edge(oid, "fileRef", FILE_KINDS, required=False)
            edge(oid, "productRef", {"XCSwiftPackageProductDependency"}, required=False)
        elif isa in PHASES:
            edge(oid, "files", {"PBXBuildFile"}, many=True)
        elif isa in {"PBXNativeTarget", "PBXProject"}:
            edge(oid, "buildConfigurationList", {"XCConfigurationList"})
            if isa == "PBXProject":
                edge(oid, "mainGroup", {"PBXGroup"})
                edge(oid, "productRefGroup", {"PBXGroup"})
                edge(oid, "targets", {"PBXNativeTarget"}, many=True)
                edge(oid, "packageReferences", {"XCLocalSwiftPackageReference"}, many=True)
            else:
                edge(oid, "buildPhases", PHASES, many=True)
                edge(oid, "productReference", {"PBXFileReference"})
                edge(oid, "packageProductDependencies", {"XCSwiftPackageProductDependency"}, many=True)
                issues.require(not node.get("dependencies"), f"PBX/{oid}: unexpected target dependency; no new dependencies are authorized")
                issues.require(not node.get("fileSystemSynchronizedGroups"), f"PBX/{oid}: navigator folders must have zero target membership")
        elif isa == "XCConfigurationList":
            edge(oid, "buildConfigurations", {"XCBuildConfiguration"}, many=True)
            names = [objects.get(cid, {}).get("name") for cid in node.get("buildConfigurations", [])]
            issues.require(Counter(names) == Counter({"Debug": 1, "Release": 1}), f"PBX/{oid}: configuration list must contain exactly Debug and Release")
            issues.require(node.get("defaultConfigurationName") in names, f"PBX/{oid}: defaultConfigurationName must reference a declared configuration")
        elif isa == "XCBuildConfiguration":
            edge(oid, "baseConfigurationReference", {"PBXFileReference"}, required=False)
        elif isa == "XCSwiftPackageProductDependency":
            edge(oid, "package", {"XCLocalSwiftPackageReference"})
    project = objects.get(graph.get("rootObject"), {})
    if not issues.require(project.get("isa") == "PBXProject", "PBX: rootObject must reference PBXProject"):
        return {}
    parents: dict[str, str] = {}
    for oid, node in objects.items():
        if node.get("isa") not in GROUPS:
            continue
        for child in node.get("children", []):
            issues.require(child not in parents, f"PBX/{child}: duplicate group parent or duplicate child ({parents.get(child)}, {oid})")
            parents[child] = oid
    active: set[str] = set()
    done: set[str] = set()
    def cycle(oid: str) -> None:
        if oid in active:
            issues.errors.append(f"PBX/{oid}: group cycle")
            return
        if oid in done:
            return
        active.add(oid)
        for child in objects.get(oid, {}).get("children", []):
            if objects.get(child, {}).get("isa") in GROUPS:
                cycle(child)
        active.remove(oid)
        done.add(oid)
    for oid, node in objects.items():
        if node.get("isa") in GROUPS:
            cycle(oid)
    resolved: dict[str, str] = {}
    walked: set[str] = set()
    def walk(oid: str, parent: Path) -> None:
        if oid in walked or oid not in objects:
            return
        walked.add(oid)
        node = objects[oid]
        tree = node.get("sourceTree", "<group>")
        if tree == "BUILT_PRODUCTS_DIR":
            return
        if not issues.require(tree in {"<group>", "SOURCE_ROOT"}, f"PBX/{oid}: unsupported sourceTree {tree!r}"):
            return
        base = root if tree == "SOURCE_ROOT" else parent
        raw = node.get("path", "")
        where = contained(root, base, raw, issues, f"PBX/{oid}") if raw else base
        if where is None:
            return
        resolved[oid] = where.relative_to(root).as_posix()
        if node.get("isa") in GROUPS:
            issues.require(where.is_dir(), f"PBX/{oid}: missing directory {resolved[oid]}")
            if node.get("isa") == "PBXFileSystemSynchronizedRootGroup":
                issues.require(not node.get("exceptions"), f"PBX/{oid}: navigator-only folder must not have membership exceptions")
            for child in node.get("children", []):
                walk(child, where)
        else:
            issues.require(where.exists(), f"PBX/{oid}: missing referenced file {resolved[oid]}")
    walk(project.get("mainGroup", ""), root)
    for oid, node in objects.items():
        if node.get("isa") in GROUPS | {"PBXFileReference"}:
            issues.require(oid in walked, f"PBX/{oid}: navigator reference is unreachable from mainGroup")
    physical_references = Counter(resolved[oid] for oid, node in objects.items() if node.get("isa") == "PBXFileReference" and oid in resolved)
    issues.require(all(count == 1 for count in physical_references.values()), f"PBX: duplicate explicit file references: {sorted(p for p, count in physical_references.items() if count > 1)}")
    folders = {resolved[oid] for oid, node in objects.items() if node.get("isa") == "PBXFileSystemSynchronizedRootGroup" and oid in resolved}
    issues.require(folders == NATIVE_FOLDERS, f"PBX: navigator folder mismatch; missing={sorted(NATIVE_FOLDERS-folders)}, extra={sorted(folders-NATIVE_FOLDERS)}")
    target_ids = project.get("targets", [])
    target_references = Counter(target_ids)
    target_names = Counter(objects.get(oid, {}).get("name") for oid in target_ids)
    issues.require(all(count == 1 for count in target_references.values()), "PBXProject/targets: duplicate target reference")
    issues.require(all(count == 1 for count in target_names.values()), "PBXProject/targets: duplicate target name")
    targets = {objects[oid].get("name"): objects[oid] for oid in target_ids if oid in objects}
    issues.require(set(targets) == set(TARGETS), f"PBX: expected exactly targets {TARGETS}")
    project_configuration_list = objects.get(project.get("buildConfigurationList"), {})
    for cid in project_configuration_list.get("buildConfigurations", []):
        configuration = objects.get(cid, {})
        expected = {"Debug": "Config/Debug.xcconfig", "Release": "Config/Release.xcconfig"}.get(configuration.get("name"))
        issues.require(resolved.get(configuration.get("baseConfigurationReference")) == expected, f"PBXProject/{configuration.get('name')}: wrong base xcconfig; expected {expected}")
        issues.require(not configuration.get("buildSettings"), f"PBXProject/{configuration.get('name')}: inline overrides must not bypass the reviewed xcconfig contract")
    def swift(prefix: str, exclude_tests: bool = False) -> set[str]:
        return {path for path in paths if path.startswith(prefix + "/") and path.endswith(".swift") and (not exclude_tests or not path.startswith("Apps/macOS/Tests/"))}
    shared = swift("Apps/Shared")
    expected_sources = {TARGETS[0]: shared | swift("Apps/macOS", True), TARGETS[1]: shared | swift("Apps/iPadOS"), TARGETS[2]: swift("Apps/macOS/Tests") | TEST_SUPPORT}
    resources = {"Apps/Shared/Resources/" + name for name in ["Assets.xcassets", "PrivacyInfo.xcprivacy", "Localizable.xcstrings", "InfoPlist.xcstrings"]} | {"LICENSE", "THIRD_PARTY_NOTICES.txt"}
    expected_resources = {TARGETS[0]: resources, TARGETS[1]: resources, TARGETS[2]: {"Apps/Shared/Resources/Localizable.xcstrings"}}
    used_build_files: Counter[str] = Counter()
    for name, target in targets.items():
        if name not in CONFIGS:
            continue
        phase_members: dict[str, list[str]] = {}
        product_ids: list[str] = []
        for phase_id in target.get("buildPhases", []):
            phase = objects.get(phase_id, {})
            kind = phase.get("isa", "unknown")
            issues.require(kind not in phase_members, f"{name}: duplicate {kind}")
            members = []
            for bid in phase.get("files", []):
                used_build_files[bid] += 1
                build_file = objects.get(bid, {})
                if "fileRef" in build_file:
                    issues.require(kind != "PBXFrameworksBuildPhase", f"{name}/{kind}: only the approved package product is authorized")
                    members.append(resolved.get(build_file["fileRef"], "<unresolved>"))
                if "productRef" in build_file:
                    issues.require(kind == "PBXFrameworksBuildPhase", f"{name}/{kind}: package product must be in Frameworks, not Sources/Resources")
                    product_ids.append(build_file["productRef"])
            issues.require(len(members) == len(set(members)), f"{name}/{kind}: duplicate file membership")
            phase_members[kind] = members
        for kind, expected in [("PBXSourcesBuildPhase", expected_sources[name]), ("PBXResourcesBuildPhase", expected_resources[name])]:
            actual = set(phase_members.get(kind, []))
            issues.require(actual == expected, f"{name}/{kind}: membership mismatch; missing={sorted(expected-actual)}, extra={sorted(actual-expected)}")
        dependencies = target.get("packageProductDependencies", [])
        issues.require(len(dependencies) == 1 and product_ids == dependencies, f"{name}: GlifiKit must be the single explicit package dependency and framework product")
        for pid in dependencies:
            product = objects.get(pid, {})
            package = objects.get(product.get("package"), {})
            issues.require(product.get("productName") == "GlifiKit" and package.get("relativePath") == "Packages/GlifiCore", f"{name}: expected local GlifiKit from Packages/GlifiCore")
        configuration_list = objects.get(target.get("buildConfigurationList"), {})
        configurations = [objects.get(cid, {}) for cid in configuration_list.get("buildConfigurations", [])]
        issues.require(Counter(c.get("name") for c in configurations) == Counter({"Debug": 1, "Release": 1}), f"{name}: expected exactly Debug and Release configurations")
        for configuration in configurations:
            expected = CONFIGS[name].get(configuration.get("name"))
            issues.require(resolved.get(configuration.get("baseConfigurationReference")) == expected, f"{name}/{configuration.get('name')}: wrong base xcconfig; expected {expected}")
            issues.require(not configuration.get("buildSettings"), f"{name}/{configuration.get('name')}: target overrides must not bypass the reviewed xcconfig contract")
    for oid, node in objects.items():
        if node.get("isa") == "PBXBuildFile":
            issues.require(used_build_files[oid] == 1, f"PBX/{oid}: build file must belong to exactly one phase, got {used_build_files[oid]}")
    packages = []
    for pid in project.get("packageReferences", []):
        node = objects.get(pid, {})
        path = contained(root, root, node.get("relativePath", ""), issues, f"PBX/{pid}/package")
        if path is not None:
            issues.require((path / "Package.swift").is_file(), f"PBX/{pid}: local package has no Package.swift")
            packages.append(path.relative_to(root).as_posix())
    issues.require(packages == ["Packages/GlifiCore"], "PBX: expected the sole local GlifiCore package")
    explicit = set(resolved.values())
    atomic = {p for p in explicit if p.endswith(".xcassets")}
    exclusions = {PROJECT, WORKSPACE, *SCHEMES.values()}
    uncovered = []
    for path in paths:
        safe = contained(root, root, path, issues, "repository inventory")
        if safe is None:
            continue
        if not issues.require(safe.is_file(), f"inventory: tracked file is missing: {path}"):
            continue
        # Xcode's own project/workspace metadata is managed by its containers.
        covered = path in explicit or path in exclusions or any(path.startswith(p + "/") for p in folders | atomic | set(packages))
        if not covered:
            uncovered.append(path)
    issues.require(not uncovered, f"PBX: inventory files missing from navigator/package or documented Xcode-container exclusions: {uncovered}")
    return {"objects": len(objects), "navigatorFolders": len(folders), "inventoryFiles": len(paths), "targets": len(targets)}


def raw_definition_fixtures() -> int:
    """Exercise duplicate definitions before native dictionary normalization."""
    first = "AAAAAAAAAAAAAAAAAAAAAAAA"
    second = "BBBBBBBBBBBBBBBBBBBBBBBB"
    value = '{ isa = PBXGroup; children = (); sourceTree = "<group>"; }'
    declaration = f"{first} = {value};"
    other = f"{second} = {{ isa = PBXProject; attributes = {{ TargetAttributes = {{ {first} = {{}}; }}; }}; }};"
    base = "{ objects = {\n" + declaration + "\n" + other + "\n}; rootObject = " + second + "; }"
    duplicates = {
        "identical definition": declaration,
        "quoted/commented definition": f'"{first}" /* same object */ = {value};',
        "Unicode-escaped quoted definition": '"\\U0041' + first[1:] + f'" = {value};',
    }
    positives = {
        "nested TargetAttributes reference": base,
        "fake definitions in comments": base.replace("objects = {", f'/* {declaration} */\n// "{first}" = {{}};\nobjects = {{', 1),
        "fake definitions in quoted value": base.replace("objects = {", f'probe = "objects = {{ {first} = {{ fake = YES; }}; }};"; objects = {{', 1),
        "quoted objects key": base.replace("objects =", '"objects" =', 1),
        "Unicode-escaped unique key": base.replace(first + " = " + value, '"\\U0041' + first[1:] + '" = ' + value, 1),
    }
    with tempfile.TemporaryDirectory(prefix="glifi-pbx-definitions-") as directory:
        fixture = Path(directory).resolve()
        project = fixture / PROJECT
        project.parent.mkdir()
        for name, text in positives.items():
            project.write_text(text)
            parsed = parse_project(fixture)
            if set(parsed.get("objects", {})) != {first, second}:
                raise ValueError(f"raw definition positive fixture changed native keys: {name}")
        for name, duplicate in duplicates.items():
            project.write_text(base.replace("objects = {", "objects = {\n" + duplicate, 1))
            try:
                parse_project(fixture)
            except ValueError as error:
                if "duplicate object definition" not in str(error):
                    raise ValueError(f"raw duplicate fixture failed for the wrong reason: {name}: {error}") from error
            else:
                raise ValueError(f"raw duplicate definition was incorrectly accepted: {name}")
    return len(duplicates)


def negative_tests(root: Path, graph: dict, paths: list[str]) -> int:
    """Mutate semantic metadata, rather than assert source spelling or PBX text."""
    baseline = Problems()
    validate_graph(root, graph, paths, baseline)
    if baseline.errors:
        raise ValueError("negative tests require a valid full project baseline:\n" + "\n".join(baseline.errors))
    objects = graph["objects"]
    project = objects[graph["rootObject"]]
    target_id = next(k for k, v in objects.items() if v.get("name") == TARGETS[0] and v.get("isa") == "PBXNativeTarget")
    source_phase = next(k for k in objects[target_id]["buildPhases"] if objects[k]["isa"] == "PBXSourcesBuildPhase")
    resource_phase = next(k for k in objects[target_id]["buildPhases"] if objects[k]["isa"] == "PBXResourcesBuildPhase")
    file_id = next(k for k, v in objects.items() if v.get("isa") == "PBXFileReference" and v.get("sourceTree") == "<group>" and str(v.get("path", "")).endswith(".swift"))
    folder_id = next(k for k, v in objects.items() if v.get("isa") == "PBXFileSystemSynchronizedRootGroup")
    project_configurations = objects[project["buildConfigurationList"]]["buildConfigurations"]
    project_debug = next(k for k in project_configurations if objects[k]["name"] == "Debug")
    project_release = next(k for k in project_configurations if objects[k]["name"] == "Release")
    missing_id = "FFFFFFFFFFFFFFFFFFFFFFFF"
    while missing_id in objects:
        missing_id = "E" + missing_id[:-1]
    mutations = {
        "dangling ID": lambda o: o[project["mainGroup"]]["children"].append(missing_id),
        "missing file": lambda o: o[file_id].update(path="missing-fixture.swift"),
        "path escape": lambda o: o[file_id].update(path="../outside.swift"),
        "group cycle": lambda o: o[project["mainGroup"]]["children"].append(project["mainGroup"]),
        "duplicate parent": lambda o: o[project["mainGroup"]]["children"].append(o[project["mainGroup"]]["children"][0]),
        "duplicate phase member": lambda o: o[source_phase]["files"].append(o[source_phase]["files"][0]),
        "wrong platform source": lambda o: o[objects[source_phase]["files"][0]].update(fileRef=next(k for k, v in objects.items() if v.get("path") == "GlifiStudioPadApp.swift")),
        "navigator target membership": lambda o: o[target_id].update(fileSystemSynchronizedGroups=[folder_id]),
        "missing package": lambda o: o[target_id].update(packageProductDependencies=[]),
        "missing project license": lambda o: o[resource_phase]["files"].remove("B32100000000000000000001"),
        "missing third-party notices": lambda o: o[resource_phase]["files"].remove("B32100000000000000000003"),
        "wrong configuration": lambda o: o[next(k for k in o[o[target_id]["buildConfigurationList"]]["buildConfigurations"] if o[k]["name"] == "Release")].update(baseConfigurationReference=next(k for k, v in o.items() if v.get("path") == "macOS-Debug.xcconfig")),
        "duplicate project target": lambda o: o[graph["rootObject"]]["targets"].append(project["targets"][0]),
        "project Release inline DEBUG": lambda o: o[project_release]["buildSettings"].update(SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG"),
        "project Release uses Debug base": lambda o: o[project_release].update(baseConfigurationReference=objects[project_debug]["baseConfigurationReference"]),
    }
    for name, mutate in mutations.items():
        candidate = copy.deepcopy(graph)
        mutate(candidate["objects"])
        issues = Problems()
        validate_graph(root, candidate, paths, issues)
        if not issues.errors:
            raise ValueError(f"negative fixture was incorrectly accepted: {name}")
    candidate = copy.deepcopy(graph)
    candidate["objects"][missing_id] = {"isa": "PBXFileReference", "path": "README.md", "sourceTree": "SOURCE_ROOT"}
    build_id = "DDDDDDDDDDDDDDDDDDDDDDDD"
    if build_id in objects:
        raise ValueError("negative fixture ID collision")
    candidate["objects"][build_id] = {"isa": "PBXBuildFile", "fileRef": missing_id}
    candidate["objects"][project["mainGroup"]]["children"].append(missing_id)
    candidate["objects"][resource_phase]["files"].append(build_id)
    issues = Problems()
    validate_graph(root, candidate, paths, issues)
    if not issues.errors:
        raise ValueError("negative fixture was incorrectly accepted: repository document in Resources")
    scheme = ET.parse(root / SCHEMES[TARGETS[0]]).getroot()
    scheme.find(".//BuildableReference").set("BlueprintIdentifier", missing_id)
    issues = Problems()
    validate_scheme(scheme, TARGETS[0], issues, objects)
    if not issues.errors:
        raise ValueError("negative fixture was incorrectly accepted: wrong scheme target")
    scheme = ET.parse(root / SCHEMES[TARGETS[0]]).getroot()
    launch = scheme.find("./LaunchAction/BuildableProductRunnable/BuildableReference")
    pad_id = next(k for k, v in objects.items() if v.get("name") == TARGETS[1] and v.get("isa") == "PBXNativeTarget")
    launch.set("BlueprintIdentifier", pad_id)
    launch.set("BlueprintName", TARGETS[1])
    issues = Problems()
    validate_scheme(scheme, TARGETS[0], issues, objects)
    if not issues.errors:
        raise ValueError("negative fixture was incorrectly accepted: valid target in wrong scheme role")
    with tempfile.TemporaryDirectory(prefix="glifi-project-fixtures-") as directory:
        fixture = Path(directory).resolve()
        (fixture / "a.xcconfig").write_text('#include "b.xcconfig"\n')
        (fixture / "b.xcconfig").write_text('#include "a.xcconfig"\n')
        issues = Problems()
        load_config(fixture, fixture / "a.xcconfig", issues)
        if not issues.errors:
            raise ValueError("negative fixture was incorrectly accepted: include cycle")
        (fixture / "a.xcconfig").write_text('#include "missing.xcconfig"\n')
        issues = Problems()
        load_config(fixture, fixture / "a.xcconfig", issues)
        if not issues.errors:
            raise ValueError("negative fixture was incorrectly accepted: missing include")
        (fixture / "a.xcconfig").write_text('#include "../outside.xcconfig"\n')
        issues = Problems()
        load_config(fixture, fixture / "a.xcconfig", issues)
        if not issues.errors:
            raise ValueError("negative fixture was incorrectly accepted: escaping include")
        for path in (root / "Config").rglob("*.xcconfig"):
            destination = fixture / path.relative_to(root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(path.read_bytes())
        release = fixture / "Config/Release.xcconfig"
        text = release.read_text()
        if text.count("SWIFT_OPTIMIZATION_LEVEL = -O\n") != 1:
            raise ValueError("Release configuration fixture needs one declared optimization setting")
        release.write_text(text.replace("SWIFT_OPTIMIZATION_LEVEL = -O\n", "SWIFT_OPTIMIZATION_LEVEL = -Onone\n"))
        issues = Problems()
        validate_configs(fixture, issues)
        if not issues.errors:
            raise ValueError("negative fixture was incorrectly accepted: Debug optimization in Release")
    # Confirm that the portable contract never silently invokes a native parser.
    from unittest.mock import patch

    issues = Problems()
    with patch("subprocess.run", side_effect=AssertionError("portable mode called a native tool")):
        portable(root, issues)
    if issues.errors:
        raise ValueError("portable isolation check failed: " + "; ".join(issues.errors))
    return len(mutations) + 7 + raw_definition_fixtures()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--portable", action="store_true", help="check XML and xcconfig only; no PBX graph or inventory claim")
    modes.add_argument("--self-test", action="store_true", help="run semantic negative fixtures and full native validation")
    args = parser.parse_args()
    root = args.root.resolve()
    issues = Problems()
    try:
        if args.portable:
            portable(root, issues)
            summary = {"profile": "portable XML/xcconfig only", "pbxGraphChecked": False, "inventoryChecked": False}
        else:
            graph = parse_project(root)
            paths = inventory(root)
            summary = validate_graph(root, graph, paths, issues)
            portable(root, issues, graph.get("objects", {}))
            summary.update(profile="full native macOS", pbxGraphChecked=True, inventoryChecked=True)
            if args.self_test and not issues.errors:
                summary["negativeFixtures"] = negative_tests(root, graph, paths)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        issues.errors.append(str(error))
    if issues.errors:
        print("Xcode project validation failed:", file=sys.stderr)
        for error in issues.errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Xcode project: " + json.dumps(summary, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
