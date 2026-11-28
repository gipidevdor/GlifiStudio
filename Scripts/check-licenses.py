#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the reviewed license inventory, without fetching or judging rights."""

from __future__ import annotations

import json
import hashlib
import math
import re
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


def read_json(path: Path) -> object:
    """Reject ambiguous objects and non-JSON constants in legal control inputs."""
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("JSON delle licenze con chiave duplicata")
            result[key] = value
        return result

    def reject_constant(_: str) -> object:
        raise ValueError("costante non JSON negli input delle licenze")

    def finite_float(value: str) -> float:
        number = float(value)
        if not math.isfinite(number):
            raise ValueError("numero non rappresentabile negli input delle licenze")
        return number

    return json.loads(path.read_text(encoding="utf-8"),
                      object_pairs_hook=unique_object, parse_constant=reject_constant,
                      parse_float=finite_float)


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


def github_repository(value: object) -> tuple[str, str] | None:
    """Identify a GitHub HTTPS repository without accepting alternate authorities."""
    if not isinstance(value, str):
        return None
    try:
        url = urlsplit(value)
        if (url.scheme != "https" or url.netloc.lower() != "github.com"
                or url.query or url.fragment):
            return None
    except ValueError:
        return None
    parts = url.path.strip("/").split("/")
    if len(parts) != 2:
        return None
    owner, repository = parts
    if repository.endswith(".git"):
        repository = repository[:-4]
    if any(not re.fullmatch(r"[A-Za-z0-9_.-]+", part) or part in {".", ".."}
           for part in (owner, repository)):
        return None
    return owner.lower(), repository.lower()


def pinned_license_source(value: object, repository: tuple[str, str], revision: str) -> bool:
    """Recognize a same-repository legal source fixed to the resolved commit."""
    if not isinstance(value, str):
        return False
    try:
        url = urlsplit(value)
        if url.scheme != "https" or url.query or url.fragment or url.path.endswith("/"):
            return False
    except ValueError:
        return False
    parts = url.path.strip("/").split("/")
    if any(not part or part in {".", ".."} or "%" in part for part in parts):
        return False
    if url.netloc.lower() == "github.com":
        if len(parts) < 5 or parts[2] != "blob" or parts[3] != revision:
            return False
    elif url.netloc.lower() == "raw.githubusercontent.com":
        if len(parts) < 4 or parts[2] != revision:
            return False
    else:
        return False
    if tuple(part.lower() for part in parts[:2]) != repository:
        return False
    return re.fullmatch(r"(?:LICEN[CS]E|COPYING|NOTICE)(?:[._-][A-Za-z0-9_.-]+)?",
                        parts[-1], re.IGNORECASE) is not None


def revision_mentions(value: object, token: str) -> bool:
    """Match a complete version or commit token in the reviewed revision description."""
    return isinstance(value, str) and re.search(
        r"(?<![A-Za-z0-9.+-])" + re.escape(token) + r"(?![A-Za-z0-9.+-])", value) is not None


def validate_swift_package_licenses(materials: list[object], root: Path) -> list[str]:
    """Link every resolved remote package to one distinct reviewed legal record offline."""
    errors = []
    material_files = {}
    for index, material in enumerate(materials):
        if not isinstance(material, dict) or not isinstance(material.get("paths"), list):
            continue
        files = set()
        for pattern in material["paths"]:
            try:
                files.update(local_files(root, pattern))
            except (ValueError, OSError):
                pass  # The inventory validator reports invalid material paths separately.
        material_files[index] = files
    used_materials = {}
    for path in sorted(root.glob("**/Package.resolved")):
        label = path.relative_to(root).as_posix()
        try:
            lock = read_json(path)
            if (not isinstance(lock, dict) or type(lock.get("version")) is not int
                    or lock["version"] not in {2, 3} or not isinstance(lock.get("pins"), list)):
                raise ValueError("richiesto lockfile SwiftPM versione 2 o 3 con elenco pins")
        except (ValueError, OSError) as error:
            errors.append(f"{label}: lockfile licenze non leggibile: {error}")
            continue
        identities = set()
        for pin in lock["pins"]:
            if not isinstance(pin, dict):
                errors.append(f"{label}: pin non valido")
                continue
            identity, state = pin.get("identity"), pin.get("state")
            if not isinstance(identity, str) or not identity.strip() or identity in identities:
                errors.append(f"{label}: identità del pin vuota o duplicata")
                continue
            identities.add(identity)
            pin_label = f"{label}: {identity}"
            if pin.get("kind") != "remoteSourceControl":
                errors.append(f"{pin_label}: tipo di pin privo di verifica licenze supportata")
                continue
            repository = github_repository(pin.get("location"))
            if repository is None:
                errors.append(f"{pin_label}: repository privo di verifica licenze supportata")
                continue
            if not isinstance(state, dict):
                errors.append(f"{pin_label}: stato del pin non valido")
                continue
            version, revision = state.get("version"), state.get("revision")
            if (not isinstance(version, str)
                    or re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", version) is None
                    or not isinstance(revision, str)
                    or re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", revision) is None
                    or state.get("branch") is not None):
                errors.append(f"{pin_label}: richiesti versione esatta e SHA completo, senza branch")
                continue
            candidates = []
            for index, files in material_files.items():
                material = materials[index]
                urls = material.get("sourceURLs")
                notice = material.get("noticeFile")
                if (path not in files or material.get("status") != "reviewed"
                        or not revision_mentions(material.get("revision"), revision)
                        or not revision_mentions(material.get("revision"), version)
                        or not isinstance(material.get("licenseExpression"), str)
                        or not material["licenseExpression"].strip()
                        or not isinstance(urls, list)
                        or not any(pinned_license_source(url, repository, revision) for url in urls)
                        or not isinstance(notice, str) or any(token in notice for token in "*?[")):
                    continue
                try:
                    notices = local_files(root, notice)
                    if len(notices) != 1 or not notices[0].read_bytes().strip():
                        continue
                except (ValueError, OSError):
                    continue
                candidates.append(index)
            if len(candidates) != 1:
                errors.append(
                    f"{pin_label}: richiesta una sola voce licenze revisionata con versione, SHA, "
                    "fonte legale immutabile dello stesso repository e avviso conservato")
                continue
            index = candidates[0]
            key = (repository, identity, version, revision)
            if index in used_materials and used_materials[index] != key:
                errors.append(f"{pin_label}: una voce licenze non può coprire package o revisioni distinti")
            used_materials[index] = key
    return errors


def validate_inventory(body: object, root: Path) -> list[str]:
    """Return structural errors and missing coverage in the supplied inventory."""
    errors: list[str] = []
    if not isinstance(body, dict):
        return ["inventario deve essere un oggetto"]
    if (body.get("schema") != "studio.glifi.license-inventory"
            or type(body.get("schemaVersion")) is not int or body.get("schemaVersion") != 1):
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
    errors.extend(validate_swift_package_licenses(materials, root))
    return errors


def main() -> int:
    try:
        body = read_json(PROJECT_DIRECTORY / INVENTORY_PATH)
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
