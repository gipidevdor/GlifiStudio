#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate the initial Italian localization baseline."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
CATALOG_PATH = PROJECT_DIRECTORY / "Apps/Shared/Resources/Localizable.xcstrings"
PROJECT_PATH = PROJECT_DIRECTORY / "GlifiStudio.xcodeproj/project.pbxproj"
VISUALIZATION_SOURCE_PATH = (
    PROJECT_DIRECTORY / "Packages/GlifiCore/Sources/GlifiKit/GlifiVisualizationPresentation.swift"
)
BASE_CONFIGURATION_PATH = PROJECT_DIRECTORY / "Config/Base.xcconfig"
EXPECTED_TRANSLATIONS = {
    "app.name": {"it": "Glifi Studio", "en": "Glifi Studio"},
    "caveat.collection.diversity-window-unavailable": {
        "it": "La raccolta è troppo breve per calcolare tutte le misure di diversità.",
        "en": "The collection is too short to compute every diversity measure.",
    },
    "caveat.insufficient-evidence": {
        "it": "I dati disponibili non sostengono una conclusione positiva.",
        "en": "The available data do not support a positive conclusion.",
    },
    "caveat.keyness.low-expected-count": {
        "it": "Alcuni conteggi attesi sono bassi; interpreta il risultato con cautela.",
        "en": "Some expected counts are low; interpret this result with caution.",
    },
    "caveat.ranking.novelty-not-assessed": {
        "it": "La novità non è stata valutata perché la storia editoriale non è ancora disponibile.",
        "en": "Novelty was not assessed because editorial history is not available yet.",
    },
    "caveat.ranking.stability-not-measured": {
        "it": "La stabilità non è stata misurata.",
        "en": "Stability has not been measured.",
    },
    "engine.status.accessibility-label": {"it": "Stato del motore", "en": "Engine status"},
    "engine.status.checking": {"it": "Verifica di GlifiCore…", "en": "Checking GlifiCore…"},
    "engine.status.ready": {"it": "GlifiCore pronto", "en": "GlifiCore ready"},
    "finding.association.documents-terms": {
        "it": "Documenti e termini risultano associati (V di Cramér {v}).",
        "en": "Documents and terms are associated (Cramér's V {v}).",
    },
    "finding.group-location.difference": {
        "it": "La metrica {metric} differisce fra i gruppi (g di Hedges {g}).",
        "en": "The metric {metric} differs between the groups (Hedges' g {g}).",
    },
    "finding.collocation.pair": {
        "it": "{node} e {collocate} ricorrono vicini più del previsto (NPMI {npmi}).",
        "en": "{node} and {collocate} co-occur more than expected (NPMI {npmi}).",
    },
    "finding.network.communities": {
        "it": "La rete lessicale si articola in {communities} comunità (modularità {q}).",
        "en": "The lexical network splits into {communities} communities (modularity {q}).",
    },
    "finding.correspondence.axis": {
        "it": "L'asse {axis} spiega una quota {share} dell'inerzia.",
        "en": "Axis {axis} accounts for a {share} share of the inertia.",
    },
    "finding.clustering.structure": {
        "it": "I documenti formano {clusters} gruppi (silhouette media {silhouette}).",
        "en": "The documents form {clusters} clusters (average silhouette {silhouette}).",
    },
    "finding.similarity.groups": {
        "it": "I gruppi condividono {shared} forme (coseno {cosine}).",
        "en": "The groups share {shared} forms (cosine {cosine}).",
    },
    "caveat.caution.low-expected-counts": {
        "it": "Oltre il 20 % delle celle ha un conteggio atteso inferiore a 5.",
        "en": "More than 20% of the cells have an expected count below 5.",
    },
    "caveat.caution.small-groups": {
        "it": "Almeno un gruppo ha meno di cinque documenti.",
        "en": "At least one group has fewer than five documents.",
    },
    "caveat.caution.low-frequency": {
        "it": "La coppia ricorre meno di cinque volte.",
        "en": "The pair occurs fewer than five times.",
    },
    "caveat.caution.small-network": {
        "it": "La rete ha meno di dieci nodi.",
        "en": "The network has fewer than ten nodes.",
    },
    "caveat.caution.singleton-cluster": {
        "it": "Almeno un cluster contiene un solo documento.",
        "en": "At least one cluster contains a single document.",
    },
    "caveat.caution.low-total-inertia": {
        "it": "L'inerzia totale è inferiore a 0,05.",
        "en": "The total inertia is below 0.05.",
    },
    "caveat.caution.small-shared-vocabulary": {
        "it": "I gruppi condividono meno di dieci forme.",
        "en": "The groups share fewer than ten forms.",
    },
    "intent.explore-relationships": {"it": "Esplorare le relazioni fra termini e documenti", "en": "Explore relationships between terms and documents"},
    "intent.identify-themes": {"it": "Individuare temi e strutture", "en": "Identify themes and structures"},
    "intent.find-similar": {"it": "Trovare elementi simili", "en": "Find similar items"},
    "finding.collection-profile.summary": {
        "it": "La raccolta contiene {documents} documenti, {tokens} token lessicali e {types} forme distinte.",
        "en": "The collection has {documents} documents, {tokens} lexical tokens, and {types} distinct forms.",
    },
    "finding.insufficient-evidence": {
        "it": "Le evidenze disponibili non sono sufficienti per sostenere una conclusione.",
        "en": "The available evidence is insufficient to support a conclusion.",
    },
    "finding.keyness.reference": {
        "it": "Il termine {term} caratterizza maggiormente il gruppo di riferimento.",
        "en": "The term {term} characterizes the reference group more strongly.",
    },
    "finding.keyness.target": {
        "it": "Il termine {term} caratterizza maggiormente il gruppo obiettivo.",
        "en": "The term {term} characterizes the target group more strongly.",
    },
    "home.description": {
        "it": "Un ambiente nativo per l’analisi computazionale del testo.",
        "en": "A native environment for computational text analysis.",
    },
}


def visualization_keys() -> set[str]:
    """Collect every localization key a view specification can emit (GS-VIZ-001)."""
    source = VISUALIZATION_SOURCE_PATH.read_text(encoding="utf-8")
    keys = set(re.findall(r'"((?:visual|caveat\.visual)\.[a-z0-9.\-]+)"', source))
    keys |= {f"visual.column.{name}" for name in re.findall(r'column\("([a-z0-9\-]+)"\)', source)}
    series = re.findall(r'series: "([a-z]+)"', source) + re.findall(
        r'series: [^\n]*?"([a-z]+)\.\\\(', source
    )
    for name in series:
        keys.add(f"visual.series.{name}")
    return keys


def main() -> int:
    """Run localization consistency checks."""
    errors: list[str] = []
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    project = PROJECT_PATH.read_text(encoding="utf-8")
    base_configuration = BASE_CONFIGURATION_PATH.read_text(encoding="utf-8")

    if catalog.get("sourceLanguage") != "it":
        errors.append("Il catalogo deve dichiarare sourceLanguage = it.")

    strings = catalog.get("strings", {})
    missing_strings = EXPECTED_TRANSLATIONS.keys() - strings.keys()
    if missing_strings:
        errors.append(f"Stringhe italiane mancanti: {sorted(missing_strings)}")

    for key in sorted(visualization_keys()):
        units = {
            language: strings.get(key, {}).get("localizations", {}).get(language, {})
            for language in ("it", "en")
        }
        for language, unit in units.items():
            if unit.get("stringUnit", {}).get("state") != "translated":
                errors.append(f"Chiave di visualizzazione non tradotta ({language}): {key}")

    for key in EXPECTED_TRANSLATIONS.keys() & strings.keys():
        localizations = strings[key].get("localizations", {})
        for language, expected_value in EXPECTED_TRANSLATIONS[key].items():
            unit = localizations.get(language, {}).get("stringUnit", {})
            if unit.get("state") != "translated" or unit.get("value") != expected_value:
                errors.append(f"Localizzazione {language} incompleta o non valida: {key}")

    if "developmentRegion = it;" not in project:
        errors.append("La development region del progetto Xcode deve essere it.")

    if "\n\t\t\t\ten,\n" not in project:
        errors.append("Il progetto Xcode deve dichiarare en tra le regioni supportate.")

    if project.count("Localizable.xcstrings in Resources") != 4:
        errors.append("Il catalogo deve essere incluso nelle due build phase Resources.")

    required_settings = (
        "DEVELOPMENT_LANGUAGE = it",
        "LOCALIZATION_PREFERS_STRING_CATALOGS = YES",
        "SWIFT_EMIT_LOC_STRINGS = YES",
        "INFOPLIST_KEY_CFBundleDevelopmentRegion = it",
    )
    for setting in required_settings:
        if setting not in base_configuration:
            errors.append(f"Impostazione mancante in Base.xcconfig: {setting}")

    if errors:
        print("Localization validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Localization: Italian source language, semantic keys, and it/en catalogs valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
