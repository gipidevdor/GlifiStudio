#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause

"""Validate controlled Markdown metadata, identifiers, and local links."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


PROJECT_DIRECTORY = Path(__file__).resolve().parent.parent
DOCS_DIRECTORY = PROJECT_DIRECTORY / "docs"
METHODS_DIRECTORY = DOCS_DIRECTORY / "metodi-analitici"
UX_DIRECTORY = DOCS_DIRECTORY / "esperienza-utente"
DESIGN_SPEC_DIRECTORY = DOCS_DIRECTORY / "specifiche-di-design"
REQUIRED_FIELDS = (
    "Identificatore",
    "Versione",
    "Stato",
    "Responsabile",
    "Ultima modifica",
    "Approvazione",
)
FIELD_PATTERN = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$", re.MULTILINE)
LINK_PATTERN = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
METHOD_FILE_PATTERN = re.compile(r"^(\d{2})-[a-z0-9-]+\.md$")
UX_FILE_PATTERN = re.compile(r"^(\d{2})-[a-z0-9-]+\.md$")
METHOD_REQUIRED_MARKERS = {
    "01": ("AnalysisDescriptor", "Lineage analitico"),
    "02": ("Analysis DAG", "invalidazione"),
    "03": ("D0", "D1", "P1", "N1"),
    "04": ("TTR-v1", "MSTTR-v1", "MATTR-v1", "MTLD-bidirectional-v1"),
    "05": ("frequency spectrum", "ZipfLogOLS-v1", "HeapsLogOLS-v1"),
    "06": ("matrice unità-termine", "rappresentazione logica", "lineage"),
    "07": ("TFIDF-v1", "BM25-v1", "IDF-smooth-v1"),
    "08": ("PearsonChiSquare-v1", "GTest-v1", "FisherExactTwoSided-v1"),
    "09": ("residuo standardizzato", "CramersV-v1"),
    "10": ("CA-SVD-v1", "inerzia", "contributo"),
    "11": ("PMI-v1", "NPMI-v1", "logDice-v1"),
    "12": ("GriesDP-v1", "JuillandD-equal-v1"),
    "13": ("Cosine-v1", "JSdist-v1", "Hellinger-v1", "KL-v1"),
    "14": ("HAC-v1", "Ward-v1", "KMeans-Lloyd-v1"),
    "15": ("PCA-SVD-v1", "LSA-SVD-v1", "NMF-Frobenius-v1", "LDA"),
    "16": ("PageRank-v1", "Betweenness-v1", "lineage"),
    "17": ("metadata-first", "discretizzazione", "temporale"),
    "18": ("precision", "recall", "F1", "accuracy"),
    "19": ("TextRankSentence-v1", "LexRankSentence-v1", "MMR-v1"),
    "20": ("codebook", "CohenKappaNominal-v1", "KrippendorffAlpha-v1"),
    "21": ("WelchT-v1", "OneWayANOVA-v1", "BenjaminiHochberg-v1"),
    "22": ("Visualizzazioni scientifiche", "Navigazione bidirezionale"),
}
SCIENTIFIC_INTEGRATION_MARKERS = {
    "docs/README.md": ("GS-MET-001",),
    "docs/standard-di-progetto.md": ("GS-MET-001",),
    "docs/visione-e-principi.md": ("NS-009", "NS-014"),
    "docs/requisiti.md": ("RF-026", "RF-046", "RQ-023", "RQ-029"),
    "docs/architettura.md": ("AnalysisDescriptor", "VA-06", "GlifiMath"),
    "docs/tracciabilita.md": ("TV-026", "TV-036"),
    "docs/glossario.md": ("Analysis DAG", "Effect size"),
}
UX_REQUIRED_MARKERS = {
    "01": ("AnalyticalIntent", "review.completely", "algoritmo"),
    "02": ("Project", "Corpus", "Investigation", "Question", "Report"),
    "03": ("CollectionProfile", "partiallyReady", "needsAttention"),
    "04": ("Analysis Planner", "notApplicable", "CapabilitySnapshot"),
    "05": ("Evidence", "Finding", "Caveat", "motore interpretativo"),
    "06": ("Conclusione", "EvidenceAssessment", "SupportPolicy"),
    "07": ("L'oggetto è esplorabile", "Confronto come primitive UX"),
    "08": ("sintesi editoriale", "FollowUpAction", "dati insufficienti"),
    "09": ("exact", "contributive", "derivational", "VoiceOver"),
    "10": ("InvestigationHistory", "Undo/Redo", "Report"),
    "11": ("QuestionInterpretation", "domanda naturale", "needsClarification"),
    "12": ("NavigationSplitView", "Parità semantica", "stato per-scena"),
    "13": ("VoiceOver", "ISO 9241-210", "Comprensione"),
    "14": ("messageKey", "Confidenza", "chiavi"),
    "15": ("VoiceOver", "Dynamic Type", "G4"),
}
UX_INTEGRATION_MARKERS = {
    "docs/README.md": ("GS-UX-001",),
    "docs/standard-di-progetto.md": ("GS-UX-001",),
    "docs/visione-e-principi.md": ("NS-015", "NS-023"),
    "docs/requisiti.md": ("RF-047", "RF-074", "RQ-030", "RQ-040"),
    "docs/architettura.md": ("VA-07", "GlifiInvestigation", "CR-20"),
    "docs/tracciabilita.md": ("TV-037", "TV-048"),
    "docs/glossario.md": ("AnalyticalIntent", "EvidenceAssessment"),
    "docs/roadmap.md": ("CollectionProfile", "insufficientEvidence"),
    "docs/internazionalizzazione-interfaccia.md": ("GS-UX-001-14",),
    "docs/apple/README.md": ("GS-UX",),
    "docs/app-store/README.md": ("GS-UX-001",),
    "docs/metodi-analitici/README.md": ("GS-UX-001",),
}
DESIGN_SPEC_FILES = {
    "01-modello-del-dominio.md": (
        "GS-DOM-001",
        ("Project", "SourceRevision", "Aggregate", "Invarianti epistemiche"),
    ),
    "02-dati-lineage-e-persistenza.md": (
        "GS-DAT-001",
        (".glifi", "SpanMap", "SHA-256", "manifest è il commit point"),
    ),
    "03-contratto-linguistico-italiano.md": (
        "GS-LNG-001",
        ("it-token-v1", "SurfaceToken", "apostrofi", "Corpus gold italiano"),
    ),
    "04-ricerca-e-linguaggio-di-query.md": (
        "GS-QRY-001",
        ("QueryAST", "glifi-query-v1", "EBNF", "budgetExceeded"),
    ),
    "05-sistema-analitico.md": (
        "GS-ANA-001",
        (
            "CapabilityDescriptor",
            "AnalysisNodeID",
            "Ranking editoriale",
            "Contratto di spiegazione",
        ),
    ),
    "06-runtime-e-risorse.md": (
        "GS-RUN-001",
        ("structured concurrency", "ResourceBudget v1", "Backpressure", "Matrice di benchmark"),
    ),
    "07-information-architecture-e-interazione.md": (
        "GS-UI-001",
        ("NavigationSplitView", "Selection", "Design system nativo", "VoiceOver"),
    ),
    "08-visualizzazione-scientifica.md": (
        "GS-VIZ-001",
        ("VisualizationSpec", "interactive lineage", "tabella equivalente", "Export"),
    ),
    "09-validazione-scientifica.md": (
        "GS-VAL-001",
        ("Oracoli indipendenti", "Property-based", "metamorphic", "ValidationManifest"),
    ),
    "10-product-baseline-mvp.md": (
        "GS-PROD-001",
        ("Product baseline", "Percorso Must end-to-end", "Fuori dal prodotto 0.1", "G5 Release"),
    ),
}
DESIGN_INTEGRATION_MARKERS = {
    "docs/README.md": ("GS-DOM-001", "GS-PROD-001"),
    "docs/standard-di-progetto.md": ("GS-DSG-IDX-001",),
    "docs/requisiti.md": ("GS-DAT-001", "GS-QRY-001", "GS-VAL-001"),
    "docs/architettura.md": ("GS-DOM-001", "GS-RUN-001", "GS-UI-001"),
    "docs/tracciabilita.md": ("TV-050", "TV-061"),
    "docs/glossario.md": ("SpanMap", "QueryAST", "VisualizationSpec"),
    "docs/roadmap.md": ("GS-PROD-001",),
    "docs/decisioni-aperte.md": ("ADR-0016",),
    "docs/adr/README.md": ("ADR-0016",),
    "docs/evidenze/README.md": ("GS-VER-015",),
    "docs/standard/11-dati-testo-e-persistenza.md": ("GS-DAT-001",),
    "docs/standard/14-sicurezza-e-privacy.md": ("regex DoS", "path traversal"),
    "docs/standard/18-errori-logging-e-osservabilita.md": ("GS-RUN-001",),
    "docs/standard/22-manutenzione-e-compatibilita.md": ("N-1",),
    "docs/apple/README.md": ("GS-DAT-001", "GS-UI-001"),
}
CROSS_CUTTING_SPEC_FILES = {
    "docs/sicurezza/README.md": (
        "GS-SEC-001",
        ("TB-01", "THR-020", "Decompression bomb", "App Sandbox", "ExportManifest"),
    ),
    "docs/api/README.md": (
        "GS-API-001",
        (
            "ProjectSession",
            "OperationOutcome",
            "invariantViolation",
            "GlifiCLI",
            "cliProtocolVersion",
            "library evolution",
        ),
    ),
}
CROSS_CUTTING_INTEGRATION_MARKERS = {
    "docs/README.md": ("GS-SEC-001", "GS-API-001"),
    "docs/standard-di-progetto.md": ("GS-SEC-001", "GS-API-001"),
    "docs/requisiti.md": ("RQ-057", "RQ-060", "RQ-063"),
    "docs/architettura.md": ("CR-29", "CR-30"),
    "docs/tracciabilita.md": ("TV-070", "TV-073", "check-compliance"),
    "docs/standard/07-pianificazione-e-gestione-del-lavoro.md": (
        "Definition of Ready",
        "failure semantics",
    ),
    "docs/standard/14-sicurezza-e-privacy.md": ("GS-SEC-001",),
    "docs/standard/18-errori-logging-e-osservabilita.md": (
        "insufficientData",
        "retainedState",
    ),
    "docs/specifiche-di-design/02-dati-lineage-e-persistenza.md": (
        "Protocollo di commit",
        "ExportManifest",
    ),
    "docs/adr/README.md": ("ADR-0019",),
    "docs/evidenze/README.md": ("GS-VER-017",),
    "docs/roadmap.md": ("GS-SEC/GS-API",),
    "docs/decisioni-aperte.md": ("DA-031",),
}

DOR_DIRECTORY = DOCS_DIRECTORY / "pianificazione"
DOR_REQUIRED_MARKERS = (
    "Definition of Ready",
    "outcome e confini",
    "failure semantics",
    "tracciabilità",
    "**Ready",
)
PR_TEMPLATE_PATH = PROJECT_DIRECTORY / ".github/PULL_REQUEST_TEMPLATE.md"


def metadata(text: str) -> dict[str, str]:
    """Return metadata fields found in a Markdown table."""
    return {key.strip(): value.strip() for key, value in FIELD_PATTERN.findall(text)}


def validate_definition_of_ready(errors: list[str]) -> int:
    """Require at least one Ready DoR sheet and a PR template DoR section."""
    if not DOR_DIRECTORY.is_dir():
        errors.append("docs/pianificazione: directory Definition of Ready mancante")
        return 0
    sheets = sorted(DOR_DIRECTORY.glob("dor-*.md"))
    if not sheets:
        errors.append("docs/pianificazione: nessuna scheda dor-*.md")
        return 0
    ready_count = 0
    for path in sheets:
        body = path.read_text(encoding="utf-8")
        relative = path.relative_to(PROJECT_DIRECTORY)
        fields = metadata(body)
        stato = fields.get("Stato", "")
        if not stato.startswith("Ready"):
            errors.append(f"{relative}: Stato DoR deve essere Ready o Ready con rischio accettato")
        else:
            ready_count += 1
        for marker in DOR_REQUIRED_MARKERS:
            if marker not in body:
                errors.append(f"{relative}: marker DoR mancante: {marker}")
    if ready_count < 1:
        errors.append("docs/pianificazione: serve almeno una scheda Ready")
    if not PR_TEMPLATE_PATH.is_file():
        errors.append(".github/PULL_REQUEST_TEMPLATE.md mancante")
    else:
        template = PR_TEMPLATE_PATH.read_text(encoding="utf-8")
        if "Definition of Ready" not in template or "Stato DoR" not in template:
            errors.append(
                ".github/PULL_REQUEST_TEMPLATE.md: sezione Definition of Ready mancante"
            )
    return len(sheets)

def local_link_target(source: Path, raw_target: str) -> Path | None:
    """Resolve a local Markdown link, or return None for external/anchor links."""
    target = raw_target.strip()
    if target.startswith("<") and target.endswith(">"):
        target = target[1:-1]
    target = unquote(target.split("#", maxsplit=1)[0])
    if not target or target.startswith(("#", "http://", "https://", "mailto:")):
        return None
    return (source.parent / target).resolve()


def validate_scientific_specification(errors: list[str]) -> int:
    """Validate coverage and integration of the analytical method family."""
    index_path = METHODS_DIRECTORY / "README.md"
    if not index_path.is_file():
        errors.append("docs/metodi-analitici/README.md: indice scientifico mancante")
        return 0

    index_text = index_path.read_text(encoding="utf-8")
    method_paths = sorted(
        path for path in METHODS_DIRECTORY.glob("*.md") if path.name != "README.md"
    )
    indexed_paths: set[Path] = set()
    for raw_target in LINK_PATTERN.findall(index_text):
        target = local_link_target(index_path, raw_target)
        if target is not None and target.parent == METHODS_DIRECTORY:
            indexed_paths.add(target)

    expected_paths = set(method_paths)
    for path in sorted(expected_paths - indexed_paths):
        errors.append(f"{path.relative_to(PROJECT_DIRECTORY)}: non indicizzato")
    for path in sorted(indexed_paths - expected_paths):
        errors.append(
            f"docs/metodi-analitici/README.md: riferimento estraneo o mancante: "
            f"{path.name}"
        )

    for path in method_paths:
        relative_path = path.relative_to(PROJECT_DIRECTORY)
        match = METHOD_FILE_PATTERN.fullmatch(path.name)
        if match is None:
            errors.append(f"{relative_path}: nome non conforme NN-argomento.md")
            continue

        sequence = match.group(1)
        body = path.read_text(encoding="utf-8")
        fields = metadata(body)
        expected_identifier = f"GS-MET-001-{sequence}"
        if fields.get("Identificatore") != expected_identifier:
            errors.append(
                f"{relative_path}: atteso identificatore {expected_identifier}"
            )
        if "GS-MET-001" not in fields.get("Documento padre", ""):
            errors.append(f"{relative_path}: documento padre GS-MET-001 mancante")
        if not body.startswith("<!-- SPDX-License-Identifier: BSD-3-Clause -->"):
            errors.append(f"{relative_path}: intestazione SPDX mancante")
        for marker in METHOD_REQUIRED_MARKERS.get(sequence, ()):
            if marker not in body:
                errors.append(f"{relative_path}: copertura obbligatoria mancante: {marker}")

    actual_sequences = {path.name[:2] for path in method_paths}
    expected_sequences = set(METHOD_REQUIRED_MARKERS)
    for sequence in sorted(expected_sequences - actual_sequences):
        errors.append(f"GS-MET-001-{sequence}: documento obbligatorio mancante")

    for relative, markers in SCIENTIFIC_INTEGRATION_MARKERS.items():
        path = PROJECT_DIRECTORY / relative
        if not path.is_file():
            errors.append(f"{relative}: documento di integrazione mancante")
            continue
        body = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in body:
                errors.append(f"{relative}: integrazione scientifica mancante: {marker}")

    return len(method_paths)


def validate_ux_specification(errors: list[str]) -> int:
    """Validate coverage and integration of the user experience family."""
    index_path = UX_DIRECTORY / "README.md"
    if not index_path.is_file():
        errors.append("docs/esperienza-utente/README.md: indice UX mancante")
        return 0

    index_text = index_path.read_text(encoding="utf-8")
    ux_paths = sorted(
        path for path in UX_DIRECTORY.glob("*.md") if path.name != "README.md"
    )
    indexed_paths: set[Path] = set()
    for raw_target in LINK_PATTERN.findall(index_text):
        target = local_link_target(index_path, raw_target)
        if target is not None and target.parent == UX_DIRECTORY:
            indexed_paths.add(target)

    expected_paths = set(ux_paths)
    for path in sorted(expected_paths - indexed_paths):
        errors.append(f"{path.relative_to(PROJECT_DIRECTORY)}: non indicizzato")
    for path in sorted(indexed_paths - expected_paths):
        errors.append(
            f"docs/esperienza-utente/README.md: riferimento estraneo o mancante: "
            f"{path.name}"
        )

    for path in ux_paths:
        relative_path = path.relative_to(PROJECT_DIRECTORY)
        match = UX_FILE_PATTERN.fullmatch(path.name)
        if match is None:
            errors.append(f"{relative_path}: nome non conforme NN-argomento.md")
            continue

        sequence = match.group(1)
        body = path.read_text(encoding="utf-8")
        fields = metadata(body)
        expected_identifier = f"GS-UX-001-{sequence}"
        if fields.get("Identificatore") != expected_identifier:
            errors.append(
                f"{relative_path}: atteso identificatore {expected_identifier}"
            )
        if "GS-UX-001" not in fields.get("Documento padre", ""):
            errors.append(f"{relative_path}: documento padre GS-UX-001 mancante")
        if not body.startswith("<!-- SPDX-License-Identifier: BSD-3-Clause -->"):
            errors.append(f"{relative_path}: intestazione SPDX mancante")
        for marker in UX_REQUIRED_MARKERS.get(sequence, ()):
            if marker not in body:
                errors.append(f"{relative_path}: copertura UX mancante: {marker}")

    actual_sequences = {path.name[:2] for path in ux_paths}
    expected_sequences = set(UX_REQUIRED_MARKERS)
    for sequence in sorted(expected_sequences - actual_sequences):
        errors.append(f"GS-UX-001-{sequence}: documento obbligatorio mancante")

    for relative, markers in UX_INTEGRATION_MARKERS.items():
        path = PROJECT_DIRECTORY / relative
        if not path.is_file():
            errors.append(f"{relative}: documento di integrazione UX mancante")
            continue
        body = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in body:
                errors.append(f"{relative}: integrazione UX mancante: {marker}")

    return len(ux_paths)


def validate_design_specifications(errors: list[str]) -> int:
    """Validate the complete implementable-design family and its integration."""
    index_path = DESIGN_SPEC_DIRECTORY / "README.md"
    if not index_path.is_file():
        errors.append("docs/specifiche-di-design/README.md: indice di design mancante")
        return 0

    index_text = index_path.read_text(encoding="utf-8")
    actual_paths = {
        path.name: path
        for path in DESIGN_SPEC_DIRECTORY.glob("*.md")
        if path.name != "README.md"
    }
    expected_names = set(DESIGN_SPEC_FILES)
    for name in sorted(expected_names - set(actual_paths)):
        errors.append(f"docs/specifiche-di-design/{name}: specifica obbligatoria mancante")
    for name in sorted(set(actual_paths) - expected_names):
        errors.append(f"docs/specifiche-di-design/{name}: specifica non registrata")

    indexed_paths: set[Path] = set()
    for raw_target in LINK_PATTERN.findall(index_text):
        target = local_link_target(index_path, raw_target)
        if target is not None and target.parent == DESIGN_SPEC_DIRECTORY:
            indexed_paths.add(target)

    for name, (identifier, markers) in DESIGN_SPEC_FILES.items():
        path = actual_paths.get(name)
        if path is None:
            continue
        relative_path = path.relative_to(PROJECT_DIRECTORY)
        if path not in indexed_paths:
            errors.append(f"{relative_path}: non indicizzato")
        body = path.read_text(encoding="utf-8")
        fields = metadata(body)
        if fields.get("Identificatore") != identifier:
            errors.append(f"{relative_path}: atteso identificatore {identifier}")
        if not body.startswith("<!-- SPDX-License-Identifier: BSD-3-Clause -->"):
            errors.append(f"{relative_path}: intestazione SPDX mancante")
        for marker in markers:
            if marker not in body:
                errors.append(f"{relative_path}: copertura design mancante: {marker}")

    for relative, markers in DESIGN_INTEGRATION_MARKERS.items():
        path = PROJECT_DIRECTORY / relative
        if not path.is_file():
            errors.append(f"{relative}: documento di integrazione mancante")
            continue
        body = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in body:
                errors.append(f"{relative}: integrazione design mancante: {marker}")

    return len(actual_paths)


def validate_cross_cutting_specifications(errors: list[str]) -> int:
    """Validate security/API contracts and their normative integration."""
    for relative, (identifier, markers) in CROSS_CUTTING_SPEC_FILES.items():
        path = PROJECT_DIRECTORY / relative
        if not path.is_file():
            errors.append(f"{relative}: specifica trasversale mancante")
            continue
        body = path.read_text(encoding="utf-8")
        fields = metadata(body)
        if fields.get("Identificatore") != identifier:
            errors.append(f"{relative}: atteso identificatore {identifier}")
        if not body.startswith("<!-- SPDX-License-Identifier: BSD-3-Clause -->"):
            errors.append(f"{relative}: intestazione SPDX mancante")
        for marker in markers:
            if marker not in body:
                errors.append(f"{relative}: copertura trasversale mancante: {marker}")

    for relative, markers in CROSS_CUTTING_INTEGRATION_MARKERS.items():
        path = PROJECT_DIRECTORY / relative
        if not path.is_file():
            errors.append(f"{relative}: integrazione trasversale mancante")
            continue
        body = path.read_text(encoding="utf-8")
        for marker in markers:
            if marker not in body:
                errors.append(f"{relative}: integrazione trasversale mancante: {marker}")

    return sum(
        (PROJECT_DIRECTORY / relative).is_file()
        for relative in CROSS_CUTTING_SPEC_FILES
    )


def main() -> int:
    """Run all documentation checks."""
    errors: list[str] = []
    identifiers: dict[str, Path] = {}
    controlled_files = sorted(DOCS_DIRECTORY.rglob("*.md"))
    markdown_files = [PROJECT_DIRECTORY / "README.md", *controlled_files]

    for path in markdown_files:
        text = path.read_text(encoding="utf-8")
        relative_path = path.relative_to(PROJECT_DIRECTORY)

        if path in controlled_files:
            fields = metadata(text)
            for field in REQUIRED_FIELDS:
                if field not in fields:
                    errors.append(f"{relative_path}: metadato mancante: {field}")

            identifier = fields.get("Identificatore")
            if identifier:
                if identifier in identifiers:
                    previous = identifiers[identifier].relative_to(PROJECT_DIRECTORY)
                    errors.append(
                        f"{relative_path}: identificatore duplicato {identifier} "
                        f"(già in {previous})"
                    )
                identifiers[identifier] = path

        for raw_target in LINK_PATTERN.findall(text):
            target = local_link_target(path, raw_target)
            if target is not None and not target.exists():
                errors.append(f"{relative_path}: collegamento locale non valido: {raw_target}")

    method_count = validate_scientific_specification(errors)
    ux_count = validate_ux_specification(errors)
    design_count = validate_design_specifications(errors)
    cross_cutting_count = validate_cross_cutting_specifications(errors)
    dor_count = validate_definition_of_ready(errors)

    if errors:
        print("Documentation validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        f"Documentation: {len(markdown_files)} files, "
        f"{len(identifiers)} unique identifiers, valid local links, "
        f"{method_count} scientific method specifications, "
        f"{ux_count} UX specifications, "
        f"{design_count} implementation design specifications, "
        f"{cross_cutting_count} cross-cutting specifications, "
        f"{dor_count} Definition of Ready sheets"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
