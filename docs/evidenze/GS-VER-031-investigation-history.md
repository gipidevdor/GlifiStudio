<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-031 — InvestigationHistory append-only e selezione editoriale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-031 |
| Tipo | Evidenza di verifica implementativa |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza locale; conferma CI remota richiesta |
| Requisiti | GS-UX-001-02; GS-UX-001-10; GS-DAT-001; GS-API-001 |
| Decisione | ADR-0021 |

## Ambito osservato

- `InvestigationID` e `InvestigationEventID` distinti e tipizzati;
- eventi canonici `created`/`editorialSelectionChanged` con predecessore, tempo,
  attore e payload bounded;
- replay fail-closed, selezione ordinata, subset dei FindingID e due rami dallo
  stesso predecessore senza mutazione del ramo sorgente;
- root InvestigationHistory distinta dalla radice Artifact in manifest e SQLite;
- commit generazionale, oggetti SHA-256, riapertura con verifica di digest, ID,
  archi, cicli, orfani e raggiungibilità di ogni evento;
- conservazione della storia dopo una nuova importazione che invalida gli Artifact;
- migrazione additiva di manifest/store schema 2 allo schema 3;
- operazioni create/select/list coerenti in GlifiCore, GlifiKit e GlifiCLI.

## Evidenze automatiche

- `GlifiInvestigationTests`: identità content-addressed, round-trip, replay di rami
  e rifiuto di finding non disponibile;
- `GlifiProjectPackageTests`: migrazione 2→3, commit e riapertura della nuova radice;
- `GlifiStudioServiceTests`: Interpretation reale, creazione, due selezioni,
  importazione successiva, riapertura e recupero di entrambi gli head;
- `Scripts/test.sh`: 78 test Swift superati;
- `make verify`: gate repository, documentazione, API, sicurezza, Swift, build
  macOS/iPadOS e preflight App Store superati nella stessa revisione.

## Limiti residui

- la fault injection a sei checkpoint copre import e Artifact, non ancora il commit
  Investigation dedicato;
- eventi di osservazione/navigazione, note, merge, Undo/Redo UI e autosave coalesced
  non sono implementati;
- Report/export non facevano parte di questa slice; JSON/Markdown sono acquisiti
  da GS-VER-032 e PDF/CSV da GS-VER-033, mentre la UI resta aperta;
- kill reale, power-loss e più writer/processi richiedono prove hardware dedicate.

Questa evidenza non dichiara completa InvestigationHistory né rende il prodotto
pronto per App Store; prova la prima slice persistente, ramificabile e migrabile.
