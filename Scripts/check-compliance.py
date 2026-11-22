#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the machine-readable specification compliance matrix."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
MATRIX_PATH = PROJECT_DIRECTORY / "Config/Compliance/specification-matrix.json"
REQUIREMENTS_PATH = PROJECT_DIRECTORY / "docs/requisiti.md"
ALLOWED_STATUSES = {"specified", "implemented", "verified", "blocked"}
ALLOWED_GATES = {f"G{number}" for number in range(7)}
ENTRY_FIELDS = {
    "id",
    "clause",
    "specification",
    "requirements",
    "code",
    "tests",
    "fixtures",
    "evidence",
    "gate",
    "status",
    "blockingReason",
}
PATH_FIELDS = ("specification", "code", "tests", "fixtures", "evidence")


def validate_path(raw_path: str, entry_id: str, field: str, errors: list[str]) -> None:
    """Require a repository-relative, existing regular file."""
    path = Path(raw_path)
    if path.is_absolute() or ".." in path.parts:
        errors.append(f"{entry_id}: {field} non è un path relativo sicuro: {raw_path}")
        return
    resolved = PROJECT_DIRECTORY / path
    if not resolved.is_file():
        errors.append(f"{entry_id}: {field} inesistente: {raw_path}")


def evidence_is_positive(raw_path: str) -> bool:
    """Return whether a controlled evidence item records a successful status."""
    path = PROJECT_DIRECTORY / raw_path
    if path.parent != PROJECT_DIRECTORY / "docs/evidenze" or not path.is_file():
        return False
    body = path.read_text(encoding="utf-8")
    match = re.search(r"^\| Stato \| ([^|]+) \|$", body, re.MULTILINE)
    return match is not None and match.group(1).strip().startswith("Superato")


def main() -> int:
    """Validate schema, references, and evidence-promotion rules."""
    errors: list[str] = []
    try:
        matrix = json.loads(MATRIX_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"Compliance matrix non leggibile: {error}", file=sys.stderr)
        return 1

    if matrix.get("schema") != "studio.glifi.specification-compliance-matrix":
        errors.append("schema matrice non valido")
    if matrix.get("schemaVersion") != 1:
        errors.append("schemaVersion matrice deve essere 1")

    requirements_body = REQUIREMENTS_PATH.read_text(encoding="utf-8")
    known_requirements = set(re.findall(r"\| (R[QF]-\d{3}) \|", requirements_body))
    required_coverage = matrix.get("requiredRequirementCoverage", [])
    if not isinstance(required_coverage, list) or not all(
        isinstance(item, str) for item in required_coverage
    ):
        errors.append("requiredRequirementCoverage deve essere una lista di ID")
        required_coverage = []

    entries = matrix.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append("entries deve essere una lista non vuota")
        entries = []

    seen_ids: set[str] = set()
    seen_clauses: set[str] = set()
    covered_requirements: set[str] = set()
    counts = {status: 0 for status in ALLOWED_STATUSES}

    for index, entry in enumerate(entries, start=1):
        if not isinstance(entry, dict):
            errors.append(f"entry {index}: deve essere un oggetto")
            continue
        missing = ENTRY_FIELDS - set(entry)
        extra = set(entry) - ENTRY_FIELDS
        entry_id = entry.get("id", f"entry {index}")
        if missing:
            errors.append(f"{entry_id}: campi mancanti: {', '.join(sorted(missing))}")
        if extra:
            errors.append(f"{entry_id}: campi non ammessi: {', '.join(sorted(extra))}")

        if not isinstance(entry_id, str) or not re.fullmatch(r"CMP-\d{3}", entry_id):
            errors.append(f"entry {index}: id non valido: {entry_id}")
        elif entry_id in seen_ids:
            errors.append(f"{entry_id}: id duplicato")
        else:
            seen_ids.add(entry_id)

        clause = entry.get("clause")
        if not isinstance(clause, str) or " § " not in clause:
            errors.append(f"{entry_id}: clausola non canonica")
        elif clause in seen_clauses:
            errors.append(f"{entry_id}: clausola duplicata: {clause}")
        else:
            seen_clauses.add(clause)

        status = entry.get("status")
        if status not in ALLOWED_STATUSES:
            errors.append(f"{entry_id}: stato non ammesso: {status}")
        else:
            counts[status] += 1
        if entry.get("gate") not in ALLOWED_GATES:
            errors.append(f"{entry_id}: gate non ammesso: {entry.get('gate')}")

        requirements = entry.get("requirements")
        if not isinstance(requirements, list) or not requirements:
            errors.append(f"{entry_id}: almeno un requisito è obbligatorio")
            requirements = []
        for requirement in requirements:
            if requirement not in known_requirements:
                errors.append(f"{entry_id}: requisito sconosciuto: {requirement}")
            covered_requirements.add(requirement)

        specification = entry.get("specification")
        if isinstance(specification, str):
            validate_path(specification, entry_id, "specification", errors)
        else:
            errors.append(f"{entry_id}: specification deve essere un path")

        for field in PATH_FIELDS[1:]:
            paths = entry.get(field)
            if not isinstance(paths, list) or not all(isinstance(path, str) for path in paths):
                errors.append(f"{entry_id}: {field} deve essere una lista di path")
                continue
            if len(paths) != len(set(paths)):
                errors.append(f"{entry_id}: {field} contiene duplicati")
            for raw_path in paths:
                validate_path(raw_path, entry_id, field, errors)

        code = entry.get("code", [])
        tests = entry.get("tests", [])
        evidence = entry.get("evidence", [])
        blocker = entry.get("blockingReason")
        if status == "implemented" and not code:
            errors.append(f"{entry_id}: implemented richiede almeno un riferimento code")
        if status == "verified" and (not code or not tests or not evidence):
            errors.append(f"{entry_id}: verified richiede code, tests ed evidence")
        if status == "verified":
            for raw_path in evidence:
                if not evidence_is_positive(raw_path):
                    errors.append(
                        f"{entry_id}: verified richiede evidenza GS-VER con stato Superato: "
                        f"{raw_path}"
                    )
        if status == "blocked" and not isinstance(blocker, str):
            errors.append(f"{entry_id}: blocked richiede blockingReason")
        if status != "blocked" and blocker is not None:
            errors.append(f"{entry_id}: blockingReason ammesso soltanto per blocked")

    for requirement in required_coverage:
        if requirement not in known_requirements:
            errors.append(f"copertura obbligatoria sconosciuta: {requirement}")
        if requirement not in covered_requirements:
            errors.append(f"requisito obbligatorio non coperto: {requirement}")

    if errors:
        print("Specification compliance validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        "Specification compliance: "
        f"{len(entries)} clauses; "
        + ", ".join(f"{status}={counts[status]}" for status in sorted(counts))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
