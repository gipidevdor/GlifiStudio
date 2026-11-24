#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Check that every failure the application layer can show has a localized message.

GS-API-001 § 8 requires a localizable message for each failure. A code without its own message
falls back to the message of its category, so the interface never shows a raw identifier: this
check enforces both halves of that contract.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
CATALOG_PATH = PROJECT_DIRECTORY / "Apps/Shared/Resources/Localizable.xcstrings"
KIT_DIRECTORY = PROJECT_DIRECTORY / "Packages/GlifiCore/Sources/GlifiKit"
CATEGORY_SOURCE = PROJECT_DIRECTORY / "Packages/GlifiCore/Sources/GlifiCore/GlifiFailure.swift"
APP_SOURCES = (
    PROJECT_DIRECTORY / "Apps/Shared/StudioHomeModel.swift",
    PROJECT_DIRECTORY / "Apps/Shared/StudioHomeView.swift",
)


def translated_keys(catalog: dict) -> set[str]:
    """Keys translated in both Italian and English."""
    keys: set[str] = set()
    for key, entry in catalog.get("strings", {}).items():
        localizations = entry.get("localizations", {})
        if all(
            localizations.get(language, {}).get("stringUnit", {}).get("state") == "translated"
            for language in ("it", "en")
        ):
            keys.add(key)
    return keys


def main() -> int:
    """Validate category fallbacks, GlifiKit message keys, and the fallback wiring."""
    errors: list[str] = []
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    keys = translated_keys(catalog)

    categories = re.findall(
        r"public enum GlifiFailureCategory: String[^{]*\{(.*?)\n\}",
        CATEGORY_SOURCE.read_text(encoding="utf-8"),
        re.DOTALL,
    )
    names = re.findall(r"case (\w+)", categories[0]) if categories else []
    if not names:
        errors.append("categorie di failure non trovate in GlifiFailure.swift")
    for name in names:
        if f"failure.category.{name}" not in keys:
            errors.append(f"categoria senza messaggio di ripiego: failure.category.{name}")

    emitted: set[str] = set()
    for path in sorted(KIT_DIRECTORY.rglob("*.swift")):
        emitted |= set(
            re.findall(r'messageKey:\s*"([a-z0-9.\-]+)"', path.read_text(encoding="utf-8"))
        )
    for key in sorted(emitted - keys):
        errors.append(f"chiave emessa da GlifiKit senza messaggio: {key}")

    wiring = "".join(path.read_text(encoding="utf-8") for path in APP_SOURCES)
    if "localizedFailureMessage(" not in wiring or 'failure.category.\\(category)' not in wiring:
        errors.append("le app devono risolvere il messaggio con il ripiego di categoria")
    if re.search(r"LocalizedStringKey\(failure\.messageKey\)", wiring):
        errors.append("le app non devono mostrare direttamente la chiave della failure")

    if errors:
        print("Failure message validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        "Failure messages: "
        f"{len(names)} categorie con ripiego, {len(emitted)} chiavi di GlifiKit localizzate"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
