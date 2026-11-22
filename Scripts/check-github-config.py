#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the declarative GitHub configuration without network access."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
CONFIGURATION_DIRECTORY = PROJECT_DIRECTORY / "Config/GitHub"
ISSUE_TEMPLATE_DIRECTORY = PROJECT_DIRECTORY / ".github/ISSUE_TEMPLATE"
COLOR_PATTERN = re.compile(r"^[0-9A-F]{6}$")
LABEL_BLOCK_PATTERN = re.compile(r"^labels:\n((?:  - [^\n]+\n)+)", re.MULTILINE)


def load_json(relative_path: str) -> Any:
    """Load a JSON configuration file."""
    path = PROJECT_DIRECTORY / relative_path
    return json.loads(path.read_text(encoding="utf-8"))


def validate_repository_settings(settings: dict[str, Any], errors: list[str]) -> None:
    """Validate the security-sensitive repository defaults."""
    expected_values = {
        ("visibility",): "private",
        ("defaultBranch",): "main",
        ("features", "issues"): True,
        ("features", "projects"): False,
        ("features", "wiki"): False,
        ("features", "discussions"): False,
        ("merge", "squash"): True,
        ("merge", "mergeCommit"): False,
        ("merge", "rebase"): False,
        ("merge", "autoMerge"): "required-if-available",
        ("merge", "deleteBranchOnMerge"): True,
        ("actions", "allowedActions"): "selected",
        ("actions", "shaPinningRequired"): True,
        ("actions", "defaultWorkflowPermissions"): "read",
        ("actions", "canApprovePullRequests"): False,
        ("actions", "externalWorkflowAccess"): "none",
        ("security", "branchRulesets"): "required-if-available",
    }
    for keys, expected in expected_values.items():
        value: Any = settings
        try:
            for key in keys:
                value = value[key]
        except (KeyError, TypeError):
            errors.append(f"repository-settings.json: campo mancante {'.'.join(keys)}")
            continue
        if value != expected:
            errors.append(
                f"repository-settings.json: {'.'.join(keys)} deve valere {expected!r}"
            )

    topics = settings.get("topics", [])
    if not isinstance(topics, list) or topics != sorted(set(topics)):
        errors.append("repository-settings.json: i topic devono essere univoci e ordinati")


def validate_labels(labels: list[dict[str, Any]], errors: list[str]) -> set[str]:
    """Validate label names, colors, descriptions, and uniqueness."""
    names: set[str] = set()
    for index, label in enumerate(labels):
        name = label.get("name")
        color = label.get("color")
        description = label.get("description")
        location = f"labels.json[{index}]"
        if not isinstance(name, str) or not name:
            errors.append(f"{location}: nome mancante")
            continue
        if name in names:
            errors.append(f"{location}: etichetta duplicata {name}")
        names.add(name)
        if not isinstance(color, str) or not COLOR_PATTERN.fullmatch(color):
            errors.append(f"{location}: colore non valido")
        if not isinstance(description, str) or not 1 <= len(description) <= 100:
            errors.append(f"{location}: descrizione assente o oltre 100 caratteri")
    return names


def validate_issue_labels(known_labels: set[str], errors: list[str]) -> None:
    """Require issue forms to reference catalogued labels only."""
    for path in sorted(ISSUE_TEMPLATE_DIRECTORY.glob("*.yml")):
        if path.name == "config.yml":
            continue
        body = path.read_text(encoding="utf-8")
        match = LABEL_BLOCK_PATTERN.search(body)
        if match is None:
            errors.append(f"{path.relative_to(PROJECT_DIRECTORY)}: labels mancanti")
            continue
        referenced = {
            line.removeprefix("  - ").strip()
            for line in match.group(1).splitlines()
            if line.strip()
        }
        unknown = referenced - known_labels
        for label in sorted(unknown):
            errors.append(
                f"{path.relative_to(PROJECT_DIRECTORY)}: etichetta non catalogata {label}"
            )


def rule_by_type(ruleset: dict[str, Any], rule_type: str) -> dict[str, Any] | None:
    """Return a rule from a ruleset by type."""
    return next((rule for rule in ruleset.get("rules", []) if rule.get("type") == rule_type), None)


def validate_rulesets(solo: dict[str, Any], team: dict[str, Any], errors: list[str]) -> None:
    """Validate the solo and team protection profiles."""
    required_types = {
        "deletion",
        "non_fast_forward",
        "pull_request",
        "required_linear_history",
        "required_status_checks",
    }
    for profile, ruleset in (("solo", solo), ("team", team)):
        prefix = f"rulesets/main-{profile}.json"
        if ruleset.get("target") != "branch" or ruleset.get("enforcement") != "active":
            errors.append(f"{prefix}: target branch e enforcement active sono obbligatori")
        include = ruleset.get("conditions", {}).get("ref_name", {}).get("include")
        if include != ["~DEFAULT_BRANCH"]:
            errors.append(f"{prefix}: deve proteggere il branch predefinito")
        actual_types = {rule.get("type") for rule in ruleset.get("rules", [])}
        if actual_types != required_types:
            errors.append(f"{prefix}: insieme di regole incompleto")

        status_rule = rule_by_type(ruleset, "required_status_checks") or {}
        status_parameters = status_rule.get("parameters", {})
        if status_parameters.get("strict_required_status_checks_policy") is not True:
            errors.append(f"{prefix}: status check strict obbligatorio")
        checks = status_parameters.get("required_status_checks", [])
        if checks != [
            {"context": "verify"},
            {"context": "app-store-baseline"},
        ]:
            errors.append(
                f"{prefix}: deve richiedere i check verify e app-store-baseline"
            )

    if solo.get("name") != team.get("name"):
        errors.append("I profili solo e team devono aggiornare lo stesso ruleset")

    solo_pull = (rule_by_type(solo, "pull_request") or {}).get("parameters", {})
    team_pull = (rule_by_type(team, "pull_request") or {}).get("parameters", {})
    if solo_pull.get("required_approving_review_count") != 0:
        errors.append("Il profilo solo non deve richiedere auto-approvazione")
    if solo_pull.get("require_code_owner_review") is not False:
        errors.append("Il profilo solo non deve richiedere CODEOWNERS")
    if team_pull.get("required_approving_review_count") != 1:
        errors.append("Il profilo team deve richiedere un'approvazione")
    if team_pull.get("require_code_owner_review") is not True:
        errors.append("Il profilo team deve richiedere la revisione CODEOWNERS")
    if team_pull.get("require_last_push_approval") is not True:
        errors.append("Il profilo team deve separare autore dell'ultimo push e approvatore")


def validate_codeowners(errors: list[str]) -> None:
    """Validate the inert template and any active CODEOWNERS file."""
    template = PROJECT_DIRECTORY / ".github/CODEOWNERS.template"
    template_body = template.read_text(encoding="utf-8")
    placeholders = {
        "@PROJECT_OWNER",
        "@REPOSITORY_MAINTAINERS",
        "@APPLE_BUILD_MAINTAINERS",
        "@ARCHITECTURE_MAINTAINERS",
        "@SECURITY_MAINTAINERS",
    }
    missing = placeholders - set(re.findall(r"@[A-Z_]+", template_body))
    for placeholder in sorted(missing):
        errors.append(f"CODEOWNERS.template: segnaposto mancante {placeholder}")

    active = PROJECT_DIRECTORY / ".github/CODEOWNERS"
    if active.is_file():
        body = active.read_text(encoding="utf-8")
        if re.search(r"@[A-Z_]+", body):
            errors.append(".github/CODEOWNERS contiene segnaposto non risolti")


def main() -> int:
    """Run all local GitHub configuration checks."""
    errors: list[str] = []
    settings = load_json("Config/GitHub/repository-settings.json")
    labels = load_json("Config/GitHub/labels.json")
    solo = load_json("Config/GitHub/rulesets/main-solo.json")
    team = load_json("Config/GitHub/rulesets/main-team.json")

    validate_repository_settings(settings, errors)
    known_labels = validate_labels(labels, errors)
    validate_issue_labels(known_labels, errors)
    validate_rulesets(solo, team, errors)
    validate_codeowners(errors)

    if errors:
        print("GitHub configuration validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        f"GitHub configuration: {len(known_labels)} labels, solo/team rulesets, "
        "issue forms, and ownership template valid"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
