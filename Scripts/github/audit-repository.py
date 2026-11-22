#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Audit a configured private GitHub repository against the versioned baseline."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent.parent
API_HEADERS = (
    "-H",
    "Accept: application/vnd.github+json",
    "-H",
    "X-GitHub-Api-Version: 2026-03-10",
)


def api(path: str) -> Any:
    """Return decoded JSON from a GitHub API endpoint."""
    result = subprocess.run(
        ["gh", "api", *API_HEADERS, path],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def optional_rulesets(path: str) -> tuple[Any | None, str | None]:
    """Read rulesets, distinguishing plan unavailability from operational errors."""
    result = subprocess.run(
        ["gh", "api", *API_HEADERS, path],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        return json.loads(result.stdout), None
    if "Upgrade to GitHub Pro" in result.stderr:
        return None, "ruleset non disponibile sul piano del repository privato"
    raise RuntimeError(f"Impossibile leggere {path}: {result.stderr.strip()}")


def enabled_endpoint(path: str) -> bool:
    """Return whether a no-content feature endpoint reports enabled."""
    result = subprocess.run(
        ["gh", "api", *API_HEADERS, "--silent", path],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.returncode == 0


def subset(actual: Any, expected: Any) -> bool:
    """Return whether actual recursively contains expected."""
    if isinstance(expected, dict):
        return isinstance(actual, dict) and all(
            key in actual and subset(actual[key], value) for key, value in expected.items()
        )
    if isinstance(expected, list):
        return isinstance(actual, list) and len(actual) == len(expected) and all(
            subset(actual_value, expected_value)
            for actual_value, expected_value in zip(actual, expected, strict=True)
        )
    return actual == expected


def require_equal(
    errors: list[str], actual: Any, expected: Any, description: str
) -> None:
    """Record a mismatch without exposing sensitive response content."""
    if actual != expected:
        errors.append(f"{description}: atteso {expected!r}, rilevato {actual!r}")


def main() -> int:
    """Audit repository, Actions, security, labels, and main ruleset."""
    if len(sys.argv) not in {2, 3}:
        print(f"Uso: {sys.argv[0]} OWNER/REPOSITORY [solo|team]", file=sys.stderr)
        return 2
    repository = sys.argv[1]
    profile = sys.argv[2] if len(sys.argv) == 3 else "solo"
    if profile not in {"solo", "team"}:
        print("Profilo non valido: usare solo oppure team", file=sys.stderr)
        return 2

    errors: list[str] = []
    warnings: list[str] = []
    settings = json.loads(
        (PROJECT_DIRECTORY / "Config/GitHub/repository-settings.json").read_text(
            encoding="utf-8"
        )
    )
    desired_ruleset = json.loads(
        (
            PROJECT_DIRECTORY
            / f"Config/GitHub/rulesets/main-{profile}.json"
        ).read_text(encoding="utf-8")
    )
    desired_labels = json.loads(
        (PROJECT_DIRECTORY / "Config/GitHub/labels.json").read_text(encoding="utf-8")
    )

    repository_state = api(f"repos/{repository}")
    expected_repository_values = {
        "visibility": settings["visibility"],
        "default_branch": settings["defaultBranch"],
        "has_issues": settings["features"]["issues"],
        "has_projects": settings["features"]["projects"],
        "has_wiki": settings["features"]["wiki"],
        "has_discussions": settings["features"]["discussions"],
        "is_template": settings["features"]["templateRepository"],
        "allow_squash_merge": settings["merge"]["squash"],
        "allow_merge_commit": settings["merge"]["mergeCommit"],
        "allow_rebase_merge": settings["merge"]["rebase"],
        "allow_update_branch": settings["merge"]["allowBranchUpdate"],
        "delete_branch_on_merge": settings["merge"]["deleteBranchOnMerge"],
        "archived": False,
    }
    for key, expected in expected_repository_values.items():
        require_equal(errors, repository_state.get(key), expected, f"repository.{key}")

    actual_topics = sorted(repository_state.get("topics", []))
    require_equal(errors, actual_topics, settings["topics"], "repository.topics")

    actions = api(f"repos/{repository}/actions/permissions")
    require_equal(errors, actions.get("enabled"), True, "actions.enabled")
    require_equal(errors, actions.get("allowed_actions"), "selected", "actions.allowed_actions")
    require_equal(
        errors,
        actions.get("sha_pinning_required"),
        True,
        "actions.sha_pinning_required",
    )

    selected_actions = api(f"repos/{repository}/actions/permissions/selected-actions")
    require_equal(
        errors,
        selected_actions.get("github_owned_allowed"),
        True,
        "actions.github_owned_allowed",
    )
    require_equal(
        errors,
        selected_actions.get("verified_allowed"),
        False,
        "actions.verified_allowed",
    )

    workflow_permissions = api(f"repos/{repository}/actions/permissions/workflow")
    require_equal(
        errors,
        workflow_permissions.get("default_workflow_permissions"),
        "read",
        "actions.default_workflow_permissions",
    )
    require_equal(
        errors,
        workflow_permissions.get("can_approve_pull_request_reviews"),
        False,
        "actions.can_approve_pull_request_reviews",
    )

    access = api(f"repos/{repository}/actions/permissions/access")
    require_equal(errors, access.get("access_level"), "none", "actions.access_level")

    rulesets, ruleset_warning = optional_rulesets(f"repos/{repository}/rulesets")
    if ruleset_warning is not None:
        warnings.append(ruleset_warning)
        if repository_state.get("allow_auto_merge") is not True:
            warnings.append("auto-merge non disponibile senza protezione del branch")
    else:
        require_equal(
            errors,
            repository_state.get("allow_auto_merge"),
            True,
            "repository.allow_auto_merge",
        )
        matching_rulesets = [
            ruleset
            for ruleset in rulesets
            if ruleset.get("name") == desired_ruleset["name"]
        ]
        if len(matching_rulesets) != 1:
            errors.append("ruleset main assente o duplicato")
        else:
            actual_ruleset = api(
                f"repos/{repository}/rulesets/{matching_rulesets[0]['id']}"
            )
            if not subset(actual_ruleset, desired_ruleset):
                errors.append(f"ruleset main non conforme al profilo {profile}")

    actual_labels = {
        label["name"]: (label["color"].upper(), label.get("description") or "")
        for label in api(f"repos/{repository}/labels?per_page=100")
    }
    desired_label_names = {label["name"] for label in desired_labels}
    for label in desired_labels:
        expected = (label["color"], label["description"])
        require_equal(errors, actual_labels.get(label["name"]), expected, f"label.{label['name']}")
    unexpected_labels = sorted(set(actual_labels) - desired_label_names)
    if unexpected_labels:
        errors.append(f"etichette non dichiarate: {', '.join(unexpected_labels)}")

    if not enabled_endpoint(f"repos/{repository}/vulnerability-alerts"):
        errors.append("Dependabot alerts non abilitati")
    if not enabled_endpoint(f"repos/{repository}/automated-security-fixes"):
        errors.append("Aggiornamenti di sicurezza automatici non abilitati")

    security = repository_state.get("security_and_analysis", {})
    secret_scanning = security.get("secret_scanning")
    if secret_scanning is None:
        warnings.append("Secret scanning non disponibile sul piano corrente")
    elif secret_scanning.get("status") != "enabled":
        errors.append("Secret scanning disponibile ma non abilitato")
    push_protection = security.get("secret_scanning_push_protection")
    if push_protection is None:
        warnings.append("push protection non disponibile sul piano corrente")
    elif push_protection.get("status") != "enabled":
        errors.append("Push protection disponibile ma non abilitata")

    if errors:
        print("GitHub remote audit failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"GitHub remote: {repository} conforme al profilo privato disponibile ({profile})")
    for warning in warnings:
        print(f"- Non disponibile: {warning}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
