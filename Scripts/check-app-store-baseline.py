#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the versioned App Store baseline without claiming release readiness."""

from __future__ import annotations

import json
import plistlib
import struct
import sys
from pathlib import Path
from typing import Any


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
BUNDLE_IDENTIFIER = "studio.glifi.GlifiStudio"
CONFIGURATIONS = (
    "Config/macOS-Debug.xcconfig",
    "Config/macOS-Release.xcconfig",
    "Config/iPadOS-Debug.xcconfig",
    "Config/iPadOS-Release.xcconfig",
)


def read(relative_path: str) -> str:
    return (PROJECT_DIRECTORY / relative_path).read_text(encoding="utf-8")


def load_json(relative_path: str) -> dict[str, Any]:
    with (PROJECT_DIRECTORY / relative_path).open(encoding="utf-8") as source:
        value = json.load(source)
    if not isinstance(value, dict):
        raise ValueError(f"{relative_path} deve contenere un oggetto JSON")
    return value


def setting(body: str, key: str) -> str | None:
    prefix = f"{key} = "
    for line in body.splitlines():
        if line.startswith(prefix):
            return line.removeprefix(prefix).strip()
    return None


def png_header(path: Path) -> tuple[int, int, int, bool]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"{path.name} non è un PNG valido")
    width, height, _depth, colour_type = struct.unpack(">IIBB", data[16:26])
    return width, height, colour_type, b"tRNS" in data


def main() -> int:
    errors: list[str] = []
    configuration_bodies = {path: read(path) for path in CONFIGURATIONS}

    for path, body in configuration_bodies.items():
        expected = {
            "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_IDENTIFIER,
            "MARKETING_VERSION": "0.1.0",
            "CURRENT_PROJECT_VERSION": "1",
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        }
        for key, value in expected.items():
            if setting(body, key) != value:
                errors.append(f"{path}: {key} deve essere {value}")

    if any(
        setting(body, "MACOSX_DEPLOYMENT_TARGET") != "27.0"
        for path, body in configuration_bodies.items()
        if "macOS" in path
    ):
        errors.append("Il deployment target macOS deve essere 27.0.")
    if any(
        setting(body, "IPHONEOS_DEPLOYMENT_TARGET") != "27.0"
        for path, body in configuration_bodies.items()
        if "iPadOS" in path
    ):
        errors.append("Il deployment target iPadOS deve essere 27.0.")

    base = read("Config/Base.xcconfig")
    if setting(base, "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption") != "NO":
        errors.append("La baseline export compliance deve dichiarare NO esplicitamente.")

    mac_release = configuration_bodies["Config/macOS-Release.xcconfig"]
    for key, expected in {
        "ENABLE_APP_SANDBOX": "YES",
        "ENABLE_HARDENED_RUNTIME": "YES",
        "CODE_SIGN_ENTITLEMENTS": "Config/GlifiStudio-macOS.entitlements",
    }.items():
        if setting(mac_release, key) != expected:
            errors.append(f"macOS Release: {key} deve essere {expected}")

    app_store = load_json("Distribution/AppStore/Configuration/app-store.json")
    expected_store_values = {
        "productName": "Glifi Studio",
        "bundleIdentifier": BUNDLE_IDENTIFIER,
        "primaryLocale": "it-IT",
        "distributionMethod": "unlisted",
        "releaseMode": "manual",
        "marketingVersion": "0.1.0",
        "buildNumber": "1",
    }
    for key, value in expected_store_values.items():
        if app_store.get(key) != value:
            errors.append(f"app-store.json: {key} deve essere {value!r}")
    if app_store.get("platforms") != ["iPadOS", "macOS"]:
        errors.append("app-store.json: piattaforme attese iPadOS e macOS.")

    privacy = load_json("Distribution/AppStore/Configuration/privacy-declaration.json")
    if privacy.get("tracking") is not False:
        errors.append("La baseline App Store non deve dichiarare tracking.")
    for key in ("collectedDataTypes", "requiredReasonAPIs", "thirdPartySDKs"):
        if privacy.get(key) != []:
            errors.append(f"La baseline corrente richiede {key} vuoto.")

    with (PROJECT_DIRECTORY / "Apps/Shared/Resources/PrivacyInfo.xcprivacy").open("rb") as source:
        manifest = plistlib.load(source)
    if manifest != {
        "NSPrivacyAccessedAPITypes": [],
        "NSPrivacyCollectedDataTypes": [],
        "NSPrivacyTracking": False,
    }:
        errors.append("PrivacyInfo.xcprivacy non coincide con la dichiarazione App Store.")

    for locale in ("it-IT", "en-US"):
        relative = f"Distribution/AppStore/Metadata/{locale}/product-page.json"
        metadata = load_json(relative)
        if metadata.get("locale") != locale:
            errors.append(f"{relative}: locale incoerente.")
        for key in ("name", "subtitle"):
            value = metadata.get(key)
            if not isinstance(value, str) or not 2 <= len(value) <= 30:
                errors.append(f"{relative}: {key} deve contenere 2–30 caratteri.")
        keywords = metadata.get("keywords")
        if not isinstance(keywords, str) or len(keywords) > 100:
            errors.append(f"{relative}: keywords deve contenere al massimo 100 caratteri.")
        if metadata.get("status") not in {"draft", "approved"}:
            errors.append(f"{relative}: status non valido.")

    unlisted = load_json("Distribution/AppStore/Review/unlisted-request.json")
    if unlisted.get("acknowledgesLinkIsShareable") is not True:
        errors.append("La richiesta unlisted deve riconoscere che il link è inoltrabile.")

    assets_directory = PROJECT_DIRECTORY / "Apps/Shared/Resources/Assets.xcassets"
    icon_set = assets_directory / "AppIcon.appiconset"
    icon_manifest = load_json(
        "Apps/Shared/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json"
    )
    for image in icon_manifest.get("images", []):
        filename = image.get("filename")
        if not filename:
            errors.append("AppIcon: voce priva di filename.")
            continue
        path = icon_set / filename
        if not path.is_file():
            errors.append(f"AppIcon: file mancante {filename}.")
            continue
        size = float(str(image["size"]).split("x", maxsplit=1)[0])
        scale = int(str(image.get("scale", "1x")).removesuffix("x"))
        expected_pixels = int(size * scale)
        try:
            width, height, colour_type, has_transparency = png_header(path)
        except ValueError as error:
            errors.append(str(error))
            continue
        if (width, height) != (expected_pixels, expected_pixels):
            errors.append(
                f"AppIcon: {filename} è {width}x{height}, atteso {expected_pixels}x{expected_pixels}."
            )
        if colour_type in {4, 6} or has_transparency:
            errors.append(f"AppIcon: {filename} contiene trasparenza.")

    master = PROJECT_DIRECTORY / "Design/AppIcon/AppIcon-master-1024.png"
    if not master.is_file():
        errors.append("Master dell'icona candidato mancante.")
    else:
        width, height, colour_type, has_transparency = png_header(master)
        if (width, height) != (1024, 1024) or colour_type in {4, 6} or has_transparency:
            errors.append("Il master dell'icona deve essere un PNG 1024x1024 opaco.")

    project = read("GlifiStudio.xcodeproj/project.pbxproj")
    if project.count("Assets.xcassets in Resources") != 4:
        errors.append("Il catalogo asset deve essere una risorsa di entrambe le app.")

    required_documents = (
        "docs/app-store/README.md",
        "docs/app-store/01-distribuzione-unlisted.md",
        "docs/app-store/02-identita-e-record-app.md",
        "docs/app-store/03-metadati-e-materiali.md",
        "docs/app-store/04-privacy-e-conformita.md",
        "docs/app-store/05-accessibilita.md",
        "docs/app-store/06-strategia-testflight.md",
        "docs/app-store/07-matrice-qualita-e-dispositivi.md",
        "docs/app-store/08-app-review.md",
        "docs/app-store/09-rilascio-e-monitoraggio.md",
        "docs/app-store/10-gate-di-submission.md",
    )
    for relative in required_documents:
        if not (PROJECT_DIRECTORY / relative).is_file():
            errors.append(f"Documento App Store mancante: {relative}")

    if errors:
        print("App Store baseline validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("App Store baseline: identity, metadata, privacy and icon assets valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
