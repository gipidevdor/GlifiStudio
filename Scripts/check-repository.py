#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the private-repository baseline and CI supply-chain policy."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
MAX_VERSIONED_FILE_SIZE = 5 * 1024 * 1024
REQUIRED_PATHS = (
    ".editorconfig",
    ".gitattributes",
    ".github/ISSUE_TEMPLATE/architecture.yml",
    ".github/ISSUE_TEMPLATE/bug.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    ".github/ISSUE_TEMPLATE/documentation.yml",
    ".github/ISSUE_TEMPLATE/feature.yml",
    ".github/CODEOWNERS.template",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/dependabot.yml",
    ".github/workflows/app-store.yml",
    ".github/workflows/ci.yml",
    ".gitignore",
    ".swift-format",
    "AGENTS.md",
    "Benchmarks/README.md",
    "CHANGELOG.md",
    "CODE_OF_CONDUCT.md",
    "CONTRIBUTING.md",
    "Config/GitHub/labels.json",
    "Config/GitHub/repository-settings.json",
    "Config/GitHub/rulesets/main-solo.json",
    "Config/GitHub/rulesets/main-team.json",
    "Config/Compliance/specification-matrix.json",
    "Distribution/AppStore/Configuration/app-store.json",
    "Distribution/AppStore/Configuration/privacy-declaration.json",
    "Distribution/AppStore/Configuration/release-readiness.json",
    "Distribution/AppStore/README.md",
    "Fixtures/README.md",
    "Fixtures/manifest.json",
    "GOVERNANCE.md",
    "LICENSE",
    "README.md",
    "SECURITY.md",
    "Scripts/check-app-store-baseline.py",
    "Scripts/check-app-store-packaging.sh",
    "Scripts/check-app-store-submission.py",
    "Scripts/check-compliance.py",
    "Scripts/check-fixtures.py",
    "Scripts/check-github-config.py",
    "Scripts/check-recovery-kill.sh",
    "Scripts/check-swift-dialect.py",
    "Scripts/format.sh",
    "Scripts/quality.sh",
    "Scripts/quality-static.sh",
    "Scripts/github/audit-repository.py",
    "Scripts/github/configure-repository.sh",
    "Scripts/github/create-codeowners.sh",
    "SUPPORT.md",
    "docs/app-store/README.md",
    "docs/repository/README.md",
    "docs/loop-di-sviluppo-e-qualita.md",
)
ACTION_REFERENCE = re.compile(r"^\s*-?\s*uses:\s*([^@\s]+)@([^\s#]+)", re.MULTILINE)
IMMUTABLE_REVISION = re.compile(r"^[0-9a-f]{40}$")


def candidate_paths() -> list[Path]:
    """Return all non-ignored files that could enter the next commit."""
    result = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
        cwd=PROJECT_DIRECTORY,
        check=True,
        capture_output=True,
    )
    return [
        PROJECT_DIRECTORY / raw.decode("utf-8")
        for raw in result.stdout.split(b"\0")
        if raw
    ]


def validate_workflows(errors: list[str]) -> None:
    """Require least privilege and immutable third-party action references."""
    workflow_directory = PROJECT_DIRECTORY / ".github/workflows"
    for path in sorted((*workflow_directory.glob("*.yml"), *workflow_directory.glob("*.yaml"))):
        body = path.read_text(encoding="utf-8")
        relative_path = path.relative_to(PROJECT_DIRECTORY)
        if "pull_request_target" in body:
            errors.append(f"trigger vietato pull_request_target: {relative_path}")
        if not re.search(r"^permissions:\s*\n\s+contents:\s*read\s*$", body, re.MULTILINE):
            errors.append(f"permessi minimi contents: read non dichiarati: {relative_path}")
        for action, revision in ACTION_REFERENCE.findall(body):
            if action.startswith("./"):
                continue
            if not IMMUTABLE_REVISION.fullmatch(revision):
                errors.append(
                    f"azione non fissata a commit SHA completo: {relative_path} ({action})"
                )


def main() -> int:
    """Run structural, portability, and workflow checks."""
    errors: list[str] = []
    candidates = candidate_paths()

    for relative_path in REQUIRED_PATHS:
        if not (PROJECT_DIRECTORY / relative_path).is_file():
            errors.append(f"artefatto obbligatorio mancante: {relative_path}")

    folded_paths: dict[str, Path] = {}
    for path in candidates:
        if not path.exists():
            continue
        relative_path = path.relative_to(PROJECT_DIRECTORY)
        folded = str(relative_path).casefold()
        if folded in folded_paths and folded_paths[folded] != relative_path:
            errors.append(
                f"collisione di maiuscole/minuscole: {folded_paths[folded]} e {relative_path}"
            )
        folded_paths[folded] = relative_path

        if path.is_symlink():
            resolved = path.resolve()
            if PROJECT_DIRECTORY not in (resolved, *resolved.parents):
                errors.append(f"symlink esterno al repository: {relative_path}")
            continue
        if path.is_file() and path.stat().st_size > MAX_VERSIONED_FILE_SIZE:
            errors.append(
                f"file oltre 5 MiB senza decisione esplicita di storage: {relative_path}"
            )

    for script in sorted((PROJECT_DIRECTORY / "Scripts").rglob("*")):
        if script.is_file() and script.suffix in {".py", ".sh"} and not os.access(script, os.X_OK):
            errors.append(f"script non eseguibile: {script.relative_to(PROJECT_DIRECTORY)}")

    license_body = (PROJECT_DIRECTORY / "LICENSE").read_text(encoding="utf-8")
    if "BSD 3-Clause License" not in license_body:
        errors.append("LICENSE non contiene la BSD 3-Clause")

    validate_workflows(errors)

    ignored_package_lock = subprocess.run(
        ["git", "check-ignore", "-q", "Package.resolved"],
        cwd=PROJECT_DIRECTORY,
        check=False,
    )
    if ignored_package_lock.returncode == 0:
        errors.append("Package.resolved non deve essere ignorato per un'applicazione")

    if errors:
        print("Repository validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        f"Repository: {len(candidates)} versionable files, policy and CI baseline valid"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
