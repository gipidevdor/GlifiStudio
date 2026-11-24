<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-032 — Export scientifico JSON/Markdown verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-032 |
| Tipo | Evidenza di verifica implementativa |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza locale; conferma CI remota richiesta |
| Requisiti | RF-085; RQ-028; RQ-040; RQ-044; RQ-059–RQ-061 |
| Decisione | ADR-0022 |

## Ambito osservato

- `ReportRevisionID` SHA-256 e rapporto immutabile derivato da un head preciso;
- selezione ordinata dei soli Finding scelti e chiusura delle Evidence referenziate;
- `ExportManifest` v1 con progetto, corpus, descriptor, algoritmo, parametri,
  preprocessing, backend, determinismo, file, lineage, Caveat e validazione;
- file JSON/Markdown bounded, inventariati per byte count e digest SHA-256;
- staging fratello, verifica completa e rename finale senza sovrascrittura;
- escaping Markdown, assenza di testo sorgente completo e path nel manifest;
- API Core/Kit e comando CLI `export --request --output` coerenti.

## Evidenze automatiche

- `GlifiScientificExportTests`: rapporto reale, digest, round-trip, escaping,
  assenza della fonte, tamper detection e tre interruzioni pre-commit;
- `GlifiStudioServiceTests`: esportazione da una sessione con Investigation reale;
- `Scripts/verify.sh`: smoke CLI, ricalcolo indipendente dei digest e controllo path;
- `Scripts/test.sh`: 80 test Swift superati;
- `make verify`: gate repository, documentazione, API, sicurezza, Swift e build
  macOS/iPadOS superati nella stessa revisione.

## Limiti residui

- il commit point è provato con fault injection in-process, non con kill/power-loss;
- PDF e CSV sono acquisiti da GS-VER-033; preview/replace UI e firma restano aperti;
- una Interpretation invalidata non è esportabile finché non viene ricalcolata;
- il validation status resta `candidate`; V0–V4 completi e review esterna mancano.

Questa evidenza prova la prima slice scientifica interoperabile; non dichiara
completo il percorso Report/export Must né la readiness App Store.
