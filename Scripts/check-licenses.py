#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the reviewed license inventory, without fetching or judging rights."""

from __future__ import annotations

import json
import hashlib
import sys
from pathlib import Path
from urllib.parse import urlsplit


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
INVENTORY_PATH = "Config/Licenses/materials.json"
CATEGORIES = {
    "project-original", "runtime-system", "algorithm-specification", "test-data",
    "development-tool", "ci-action", "original-asset", "replaced-implementation",
}
DISTRIBUTIONS = {"application", "source-only", "external-tool", "external-reference"}
FIELDS = {
    "id", "category", "paths", "sourceURLs", "revision", "licenseExpression",
    "distribution", "relationship", "noticeFile", "status", "notes",
}


def local_files(root: Path, pattern: object) -> list[Path]:
    """Resolve an inventory pattern without accepting paths outside the root."""
    if not isinstance(pattern, str) or not pattern or "\\" in pattern:
        raise ValueError("percorso vuoto o non valido")
    relative = Path(pattern)
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("percorso esterno al repository")
    matches = sorted(path for path in root.glob(pattern) if path.is_file())
    if not matches:
        raise ValueError(f"nessun file corrisponde a {pattern}")
    if any(not path.resolve().is_relative_to(root.resolve()) for path in matches):
        raise ValueError("symlink esterno al repository")
    return matches


def validate_inventory(body: object, root: Path) -> list[str]:
    """Return structural errors and missing coverage in the supplied inventory."""
    errors: list[str] = []
    if not isinstance(body, dict):
        return ["inventario deve essere un oggetto"]
    if body.get("schema") != "studio.glifi.license-inventory" or body.get("schemaVersion") != 1:
        errors.append("schema inventario non valido")
    try:
        from datetime import date
        date.fromisoformat(body.get("reviewedOn", ""))
    except (TypeError, ValueError):
        errors.append("data di revisione non valida")
    materials = body.get("materials")
    if not isinstance(materials, list) or not materials:
        return errors + ["materials deve essere una lista non vuota"]
    seen: set[str] = set()
    covered: set[Path] = set()
    notice_inputs = {root / "LICENSE", root / "THIRD_PARTY_NOTICES.txt"}
    for index, material in enumerate(materials):
        label = f"materiale {index + 1}"
        if not isinstance(material, dict):
            errors.append(f"{label}: deve essere un oggetto")
            continue
        if set(material) != FIELDS:
            errors.append(f"{label}: campi inventario mancanti o sconosciuti")
        for field in ("id", "revision", "licenseExpression", "relationship", "notes"):
            if not isinstance(material.get(field), str) or not material[field].strip():
                errors.append(f"{label}: {field} obbligatorio")
        identifier = material.get("id")
        if isinstance(identifier, str):
            if identifier in seen:
                errors.append(f"{label}: ID duplicato {identifier}")
            seen.add(identifier)
            label = identifier
        if material.get("category") not in CATEGORIES:
            errors.append(f"{label}: categoria non valida")
        if material.get("distribution") not in DISTRIBUTIONS:
            errors.append(f"{label}: distribuzione non valida")
        if material.get("status") not in {"reviewed", "replaced"}:
            errors.append(f"{label}: revisione non conclusa")
        if material.get("distribution") == "application" and material.get("status") != "reviewed":
            errors.append(f"{label}: materiale applicativo non revisionato")
        patterns = material.get("paths")
        if not isinstance(patterns, list) or not patterns:
            errors.append(f"{label}: paths obbligatorio")
        else:
            for pattern in patterns:
                try:
                    covered.update(local_files(root, pattern))
                except (ValueError, OSError) as error:
                    errors.append(f"{label}: {error}")
        urls = material.get("sourceURLs")
        if not isinstance(urls, list) or any(
            not isinstance(url, str) or urlsplit(url).scheme != "https" or not urlsplit(url).netloc
            for url in urls
        ):
            errors.append(f"{label}: sourceURLs deve contenere URL HTTPS")
        elif not urls and material.get("category") not in {"project-original", "original-asset"}:
            errors.append(f"{label}: fonte primaria obbligatoria")
        notice = material.get("noticeFile")
        if material.get("distribution") == "application" and notice is None:
            errors.append(f"{label}: materiale applicativo privo di avviso distribuito")
        if notice is not None:
            try:
                if not isinstance(notice, str) or any(token in notice for token in "*?["):
                    raise ValueError("noticeFile deve essere un file esplicito")
                notice_paths = local_files(root, notice)
                notice_inputs.update(notice_paths)
                if len(notice_paths) != 1 or not notice_paths[0].read_bytes().strip():
                    raise ValueError("testo dell’avviso vuoto")
            except (ValueError, OSError) as error:
                errors.append(f"{label}: avviso mancante o non valido: {error}")
    critical = set(root.glob("**/Package.swift")) | set(root.glob("**/Package.resolved"))
    for suffix in ("yml", "yaml"):
        critical.update(root.glob(f".github/workflows/*.{suffix}"))
    asset_suffixes = {
        ".png", ".jpg", ".jpeg", ".svg", ".pdf", ".webp", ".gif", ".tif", ".tiff",
        ".ico", ".icns", ".otf", ".ttf", ".ttc", ".otc", ".woff", ".woff2", ".heic", ".heif",
    }
    for prefix in ("Design", "docs/assets", "Apps/Shared/Resources"):
        critical.update(path for path in (root / prefix).rglob("*") if path.is_file() and path.suffix.lower() in asset_suffixes)
    for path in sorted(critical - covered):
        errors.append(f"materiale senza inventario: {path.relative_to(root)}")
    reviewed = body.get("reviewedInputs")
    if not isinstance(reviewed, dict):
        errors.append("reviewedInputs deve registrare i digest degli input controllati")
        reviewed = {}
    for path in sorted(critical | notice_inputs):
        relative = path.relative_to(root).as_posix()
        if relative not in reviewed:
            errors.append(f"input senza digest di revisione: {relative}")
    for pattern, expected in reviewed.items():
        try:
            if not isinstance(pattern, str) or any(token in pattern for token in "*?["):
                raise ValueError("il digest richiede un file esplicito")
            files = local_files(root, pattern)
            if len(files) != 1 or expected != hashlib.sha256(files[0].read_bytes()).hexdigest():
                errors.append(f"input modificato dopo la revisione licenze: {pattern}")
        except (ValueError, OSError) as error:
            errors.append(f"input di revisione non valido: {error}")
    for filename in ("LICENSE", "THIRD_PARTY_NOTICES.txt"):
        path = root / filename
        if not path.is_file() or not path.read_bytes().strip():
            errors.append(f"testo legale assente: {filename}")
    return errors


def main() -> int:
    try:
        body = json.loads((PROJECT_DIRECTORY / INVENTORY_PATH).read_text(encoding="utf-8"))
        errors = validate_inventory(body, PROJECT_DIRECTORY)
    except (OSError, ValueError, TypeError) as error:
        errors = [f"inventario non leggibile: {error}"]
    if errors:
        print("License inventory validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Licenze: {len(body['materials'])} materiali inventariati; verifica strutturale superata")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
