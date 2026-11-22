#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Enforce the Glifi Studio Swift dialect and language-mode contract without network access."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
PACKAGE_MANIFEST = PROJECT_DIRECTORY / "Packages/GlifiCore/Package.swift"
BASE_CONFIGURATION = PROJECT_DIRECTORY / "Config/Base.xcconfig"
SWIFT_FORMAT_CONFIG = PROJECT_DIRECTORY / ".swift-format"
MAKEFILE = PROJECT_DIRECTORY / "Makefile"
CI_WORKFLOW = PROJECT_DIRECTORY / ".github/workflows/ci.yml"

REQUIRED_TOOLS_VERSION = "6.4"
REQUIRED_LANGUAGE_MODE = "6.0"
REQUIRED_FORMAT_RULES = (
    "AllPublicDeclarationsHaveDocumentation",
    "AlwaysUseLowerCamelCase",
    "AmbiguousTrailingClosureOverload",
    "AvoidRetroactiveConformances",
    "BeginDocumentationCommentWithOneLineSummary",
    "DoNotUseSemicolons",
    "FileScopedDeclarationPrivacy",
    "IdentifiersMustBeASCII",
    "NeverForceUnwrap",
    "NeverUseForceTry",
    "NeverUseImplicitlyUnwrappedOptionals",
    "NoAssignmentInExpressions",
    "NoBlockComments",
    "NoParensAroundConditions",
    "OneCasePerLine",
    "OneVariableDeclarationPerLine",
    "OrderedImports",
    "UseShorthandTypeNames",
    "UseTripleSlashForDocumentationComments",
    "ValidateDocumentationComments",
)
FORBIDDEN_PACKAGE_PATTERNS = (
    re.compile(r"enableUpcomingFeature\s*\("),
    re.compile(r"enableExperimentalFeature\s*\("),
    re.compile(r"\.unsafeFlags\s*\("),
    re.compile(r"SWIFT_VERSION\s*=\s*6\.4"),
)
XCCONFIG_ASSIGNMENT = re.compile(
    r"^(?P<key>[A-Z0-9_]+)\s*=\s*(?P<value>.+?)\s*$",
    re.MULTILINE,
)


def fail(errors: list[str]) -> int:
    """Print validation errors and return a failing exit code."""
    print("Swift dialect validation failed:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    return 1


def validate_package_manifest(errors: list[str]) -> None:
    """Require Swift 6 language mode and reject experimental dialect escapes."""
    if not PACKAGE_MANIFEST.is_file():
        errors.append("Packages/GlifiCore/Package.swift mancante")
        return

    body = PACKAGE_MANIFEST.read_text(encoding="utf-8")
    tools_match = re.match(
        r"//\s*swift-tools-version:\s*([0-9]+\.[0-9]+)",
        body,
    )
    tools_version = tools_match.group(1) if tools_match else None
    if tools_version != REQUIRED_TOOLS_VERSION:
        errors.append(
            "Package.swift: richiesto swift-tools-version "
            f"{REQUIRED_TOOLS_VERSION}, rilevato {tools_version or 'sconosciuto'}"
        )
    if "swiftLanguageModes: [.v6]" not in body:
        errors.append("Package.swift: Swift 6 language mode non dichiarato")
    for pattern in FORBIDDEN_PACKAGE_PATTERNS:
        if pattern.search(body):
            errors.append(
                "Package.swift: impostazione dialettale non autorizzata "
                f"({pattern.pattern})"
            )


def validate_xcconfigs(errors: list[str]) -> None:
    """Require Swift 6 mode and complete concurrency across shared configs."""
    if not BASE_CONFIGURATION.is_file():
        errors.append("Config/Base.xcconfig mancante")
        return

    base_body = BASE_CONFIGURATION.read_text(encoding="utf-8")
    language_mode = re.search(
        r"^SWIFT_VERSION\s*=\s*([0-9]+\.[0-9]+)",
        base_body,
        re.MULTILINE,
    )
    if language_mode is None or language_mode.group(1) != REQUIRED_LANGUAGE_MODE:
        errors.append(
            "Config/Base.xcconfig: richiesto SWIFT_VERSION "
            f"{REQUIRED_LANGUAGE_MODE}, rilevato "
            f"{language_mode.group(1) if language_mode else 'sconosciuto'}"
        )
    if "SWIFT_STRICT_CONCURRENCY = complete" not in base_body:
        errors.append(
            "Config/Base.xcconfig: SWIFT_STRICT_CONCURRENCY = complete mancante"
        )
    if "SWIFT_TREAT_WARNINGS_AS_ERRORS = YES" not in base_body:
        errors.append(
            "Config/Base.xcconfig: SWIFT_TREAT_WARNINGS_AS_ERRORS = YES mancante"
        )
    if "SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor" not in base_body:
        errors.append(
            "Config/Base.xcconfig: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor mancante"
        )

    for path in sorted((PROJECT_DIRECTORY / "Config").rglob("*.xcconfig")):
        body = path.read_text(encoding="utf-8")
        relative = path.relative_to(PROJECT_DIRECTORY)
        for match in XCCONFIG_ASSIGNMENT.finditer(body):
            key = match.group("key")
            value = match.group("value")
            if key == "SWIFT_VERSION" and value != REQUIRED_LANGUAGE_MODE:
                errors.append(
                    f"{relative}: SWIFT_VERSION deve valere {REQUIRED_LANGUAGE_MODE}, "
                    f"rilevato {value}"
                )
            if key == "SWIFT_STRICT_CONCURRENCY" and value != "complete":
                errors.append(
                    f"{relative}: SWIFT_STRICT_CONCURRENCY deve valere complete, "
                    f"rilevato {value}"
                )
            if key == "SWIFT_TREAT_WARNINGS_AS_ERRORS" and value != "YES":
                errors.append(
                    f"{relative}: SWIFT_TREAT_WARNINGS_AS_ERRORS deve valere YES, "
                    f"rilevato {value}"
                )


def validate_swift_format(errors: list[str]) -> None:
    """Require the versioned Apple swift-format dialect used by Glifi Studio."""
    if not SWIFT_FORMAT_CONFIG.is_file():
        errors.append(".swift-format mancante")
        return

    try:
        configuration = json.loads(SWIFT_FORMAT_CONFIG.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        errors.append(f".swift-format: JSON non valido ({error})")
        return

    if configuration.get("version") != 1:
        errors.append(".swift-format: version deve valere 1")
    if configuration.get("lineLength") != 100:
        errors.append(".swift-format: lineLength deve valere 100")
    indentation = configuration.get("indentation")
    if not isinstance(indentation, dict) or indentation.get("spaces") != 4:
        errors.append(".swift-format: indentation.spaces deve valere 4")

    rules = configuration.get("rules")
    if not isinstance(rules, dict):
        errors.append(".swift-format: sezione rules mancante")
        return

    for rule in REQUIRED_FORMAT_RULES:
        if rules.get(rule) is not True:
            errors.append(f".swift-format: regola obbligatoria assente o disattiva: {rule}")


def validate_developer_loop(errors: list[str]) -> None:
    """Require Makefile and CI entry points for the quality loop."""
    if not MAKEFILE.is_file():
        errors.append("Makefile mancante")
        return

    makefile = MAKEFILE.read_text(encoding="utf-8")
    for target in (
        "format:",
        "format-check",
        "quality:",
        "quality-static:",
        "check-swift-dialect:",
        "verify:",
    ):
        if target not in makefile:
            errors.append(f"Makefile: target {target.rstrip(':')} mancante")
    if "lint:" not in makefile and "format-check lint:" not in makefile:
        errors.append("Makefile: target lint mancante")
    if ".PHONY:" not in makefile or "check-swift-dialect" not in makefile:
        errors.append("Makefile: target di qualità non esposti in .PHONY")
    if "quality-static" not in makefile:
        errors.append("Makefile: target quality-static mancante")

    if not CI_WORKFLOW.is_file():
        errors.append(".github/workflows/ci.yml mancante")
        return

    workflow = CI_WORKFLOW.read_text(encoding="utf-8")
    if re.search(r"^\s+name:\s*verify\s*$", workflow, re.MULTILINE) is None:
        errors.append("ci.yml: job obbligatorio verify non dichiarato")
    if "./Scripts/verify.sh" not in workflow and "Scripts/verify.sh" not in workflow:
        errors.append("ci.yml: deve invocare Scripts/verify.sh")
    if "static-quality" not in workflow:
        errors.append("ci.yml: job early-fail static-quality mancante")
    if "format-check" not in workflow:
        errors.append("ci.yml: job early-fail format-check mancante")
    if "quality-static.sh" not in workflow:
        errors.append("ci.yml: deve invocare Scripts/quality-static.sh")
    if "org.swift.swiftpm" not in workflow:
        errors.append("ci.yml: cache SPM deterministica mancante")

    app_store_workflow = PROJECT_DIRECTORY / ".github/workflows/app-store.yml"
    if not app_store_workflow.is_file():
        errors.append(".github/workflows/app-store.yml mancante")
    else:
        app_store_body = app_store_workflow.read_text(encoding="utf-8")
        if "app-store-baseline" not in app_store_body:
            errors.append("app-store.yml: job app-store-baseline mancante")
        if "org.swift.swiftpm" not in app_store_body:
            errors.append("app-store.yml: cache SPM deterministica mancante")
        if "verify-app-store.sh" not in app_store_body:
            errors.append("app-store.yml: deve invocare Scripts/verify-app-store.sh")


def main() -> int:
    """Validate the Swift dialect contract for Glifi Studio."""
    errors: list[str] = []
    validate_package_manifest(errors)
    validate_xcconfigs(errors)
    validate_swift_format(errors)
    validate_developer_loop(errors)

    if errors:
        return fail(errors)

    print(
        "Swift dialect: tools 6.4, language mode 6, strict concurrency complete, "
        f"{len(REQUIRED_FORMAT_RULES)} regole swift-format e loop make/CI coerenti"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
