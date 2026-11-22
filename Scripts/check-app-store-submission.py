#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Fail closed until all human and technical App Store submission gates are met."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent


def load(relative_path: str) -> dict[str, Any]:
    with (PROJECT_DIRECTORY / relative_path).open(encoding="utf-8") as source:
        value = json.load(source)
    if not isinstance(value, dict):
        raise ValueError(f"{relative_path} deve contenere un oggetto JSON")
    return value


def main() -> int:
    baseline = subprocess.run(
        [str(PROJECT_DIRECTORY / "Scripts/check-app-store-baseline.py")],
        cwd=PROJECT_DIRECTORY,
        check=False,
    )
    if baseline.returncode != 0:
        return baseline.returncode

    blockers: list[str] = []
    app_store = load("Distribution/AppStore/Configuration/app-store.json")
    for key in (
        "appleDeveloperTeamID",
        "appStoreConnectAppID",
        "sku",
        "privacyPolicyURL",
        "supportURL",
    ):
        if not app_store.get(key):
            blockers.append(f"configurazione App Store incompleta: {key}")
    for key in ("ageRatingCompleted", "contentRightsCompleted", "priceAndAvailabilityCompleted"):
        if app_store.get(key) is not True:
            blockers.append(f"configurazione App Store non approvata: {key}")
    if not app_store.get("regions"):
        blockers.append("nessuna regione di distribuzione approvata")

    readiness = load("Distribution/AppStore/Configuration/release-readiness.json")
    required_readiness_gates = (
        "productMinimumFunctionality",
        "allMustFlowsImplemented",
        "unitAndIntegrationTestsPassing",
        "uiTestsPassing",
        "manualDeviceQACompleted",
        "accessibilityAuditCompleted",
        "performanceAndEnergyAuditCompleted",
        "internalTestFlightCompleted",
        "externalTestFlightCompleted",
        "screenshotsApproved",
        "metadataApproved",
        "privacyPolicyPublished",
        "supportPagePublished",
        "signedArchivesValidated",
        "appReviewSubmitted",
        "unlistedRequestApproved",
    )
    for key in required_readiness_gates:
        if readiness.get(key) is not True:
            blockers.append(f"gate di rilascio non superato: {key}")

    privacy = load("Distribution/AppStore/Configuration/privacy-declaration.json")
    if privacy.get("appStoreAnswersReviewed") is not True:
        blockers.append("risposte App Privacy non riesaminate sulla build candidata")
    if not privacy.get("privacyPolicyURL"):
        blockers.append("privacy policy non associata alla dichiarazione")

    accessibility = load("Distribution/AppStore/Configuration/accessibility-declaration.json")
    if accessibility.get("status") != "verified":
        blockers.append("dichiarazione accessibilità non verificata")
    if not accessibility.get("commonTasks"):
        blockers.append("compiti comuni di accessibilità non definiti")
    if accessibility.get("verifiedOnDevices") is not True:
        blockers.append("accessibilità non verificata su dispositivi")

    review = load("Distribution/AppStore/Review/review-information.json")
    if review.get("status") != "approved":
        blockers.append("informazioni App Review non approvate")
    contact = review.get("contact")
    if not isinstance(contact, dict):
        contact = {}
    for key in ("firstName", "lastName", "email", "phone"):
        if not contact.get(key):
            blockers.append(f"contatto App Review mancante: {key}")
    if review.get("signInRequired") and not review.get("demoAccount"):
        blockers.append("account dimostrativo richiesto ma mancante")

    request = load("Distribution/AppStore/Review/unlisted-request.json")
    for key in (
        "legalEntityName",
        "requesterRole",
        "businessNeed",
        "intendedAudience",
        "distributionPlan",
        "accessControl",
        "appStoreReviewSubmissionID",
    ):
        if not request.get(key):
            blockers.append(f"richiesta unlisted incompleta: {key}")
    if request.get("approved") is not True:
        blockers.append("richiesta unlisted non approvata")

    for locale in ("it-IT", "en-US"):
        metadata = load(f"Distribution/AppStore/Metadata/{locale}/product-page.json")
        if metadata.get("status") != "approved":
            blockers.append(f"metadati {locale} non approvati")
        for key in ("supportURL", "privacyPolicyURL"):
            if not metadata.get(key):
                blockers.append(f"metadati {locale}: {key} mancante")

    for platform in ("iPadOS", "macOS"):
        screenshots = list(
            (PROJECT_DIRECTORY / f"Distribution/AppStore/Screenshots/{platform}").glob("*.png")
        )
        if len(screenshots) < 5:
            blockers.append(f"serie screenshot {platform} incompleta: richiesti 5 interni")

    if blockers:
        print("App Store submission blocked:", file=sys.stderr)
        for blocker in blockers:
            print(f"- {blocker}", file=sys.stderr)
        return 1

    print("App Store submission gate: all recorded conditions satisfied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
