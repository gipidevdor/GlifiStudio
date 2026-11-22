#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the canonical Glifi Studio naming baseline."""

from __future__ import annotations

import sys
from pathlib import Path


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
SOURCE_RECORDS = {Path("appunti-1.txt"), Path("appunti 2.txt")}
EXCLUDED_PARTS = {".git", ".build"}
LEGACY_STEM = "Gly" + "pha"
LEGACY_STEM_LOWERCASE = LEGACY_STEM.lower()

REQUIRED_FRAGMENTS = {
    Path("README.md"): ("GlifiStudio.xcworkspace",),
    Path("Apps/Shared/Resources/Localizable.xcstrings"): (
        '"value" : "Glifi Studio"',
        '"value" : "GlifiCore pronto"',
    ),
    Path("GlifiStudio.xcodeproj/project.pbxproj"): (
        "GlifiStudio-macOS",
        "GlifiStudio-iPadOS",
        "Packages/GlifiCore",
        "productName = GlifiKit;",
    ),
    Path("Config/macOS-Debug.xcconfig"): (
        "PRODUCT_BUNDLE_IDENTIFIER = studio.glifi.GlifiStudio",
        "INFOPLIST_KEY_CFBundleDisplayName = Glifi Studio",
    ),
    Path("Config/iPadOS-Debug.xcconfig"): (
        "PRODUCT_BUNDLE_IDENTIFIER = studio.glifi.GlifiStudio",
        "INFOPLIST_KEY_CFBundleDisplayName = Glifi Studio",
    ),
}

CANONICAL_README_HEADINGS = (
    "# Glifi Studio",
    '<h1 align="center">Glifi Studio</h1>',
)


def main() -> int:
    """Check controlled paths, legacy tokens, and canonical names."""
    errors: list[str] = []

    for path in sorted(PROJECT_DIRECTORY.rglob("*")):
        relative_path = path.relative_to(PROJECT_DIRECTORY)
        if any(part in EXCLUDED_PARTS for part in relative_path.parts):
            continue
        if relative_path in SOURCE_RECORDS:
            continue
        if LEGACY_STEM in str(relative_path) or LEGACY_STEM_LOWERCASE in str(relative_path):
            errors.append(f"Percorso con denominazione precedente: {relative_path}")
        if not path.is_file():
            continue
        try:
            body = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if LEGACY_STEM in body or LEGACY_STEM_LOWERCASE in body:
            errors.append(f"Contenuto con denominazione precedente: {relative_path}")

    for relative_path, fragments in REQUIRED_FRAGMENTS.items():
        path = PROJECT_DIRECTORY / relative_path
        if not path.is_file():
            errors.append(f"Artefatto canonico mancante: {relative_path}")
            continue
        body = path.read_text(encoding="utf-8")
        for fragment in fragments:
            if fragment not in body:
                errors.append(f"Nome canonico mancante in {relative_path}: {fragment}")

    readme_body = (PROJECT_DIRECTORY / "README.md").read_text(encoding="utf-8")
    if not any(heading in readme_body for heading in CANONICAL_README_HEADINGS):
        errors.append(
            "Titolo canonico mancante in README.md: "
            + " oppure ".join(CANONICAL_README_HEADINGS)
        )

    if errors:
        print("Naming validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Naming: Glifi Studio identity and technical identifiers valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
