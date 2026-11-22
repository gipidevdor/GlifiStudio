<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-033 — Export PDF/A-2u e CSV verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-033 |
| Tipo | Evidenza di verifica implementativa |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza locale; conferma CI remota richiesta |
| Requisiti | RF-085; RQ-028; RQ-040; RQ-044; RQ-059–RQ-061 |
| Decisione | ADR-0023 |

## Ambito osservato

- renderer Apple-native Core Graphics/Core Text per PDF/A-2u, testo ricercabile,
  API strutturali Xcode 27, `ActualText`, lingua, titoli, liste, tracciabilità,
  footer e paginazione;
- proiezioni `findings.csv` ed `evidence.csv` UTF-8 RFC 4180 con payload canonico,
  ID, relazioni e neutralizzazione delle formule;
- inventario chiuso di nomi, media type e schema nel manifest;
- apertura del PDF, limite di 512 pagine e verifica `StructTreeRoot`/`MarkInfo`
  più XMP `pdfaid` 2/U;
- coppia CSV indivisibile e confronto byte-a-byte con la `ReportRevision` JSON;
- assenza del testo completo della fonte da PDF, CSV, report e manifest;
- stesso staging atomico, digest, receipt e failure semantics di ADR-0022.

## Evidenze automatiche

- `GlifiScientificExportTests`: export dei cinque payload, apertura PDFKit,
  estrazione testo, struttura PDF taggata, CSV CRLF, assenza fonte, digest e tamper;
- `GlifiStudioServiceTests`: richiesta schema-versioned attraverso GlifiKit;
- `Scripts/verify.sh`: export CLI dei quattro formati, nomi, magic PDF, intestazioni
  CSV e ricalcolo SHA-256 indipendente;
- `Scripts/test.sh`: suite Swift completa;
- `make verify` e `make verify-app-store`: gate, build e archive macOS/iPadOS.

## Verifica visiva

Il PDF della fixture end-to-end è renderizzato con Poppler e ispezionato come PNG;
`pdfinfo`, `pdffonts`, `pypdf` e `pdfplumber` ne controllano inoltre apertura,
font incorporati, XMP PDF/A-2u, struttura taggata ed estrazione del testo. Titolo,
gerarchia, righe, margini, footer e tracciabilità risultano leggibili, senza
clipping, sovrapposizioni o glifi sostitutivi.

## Limiti residui

- l'audit manuale VoiceOver su macOS/iPadOS e la prova con persone restano G4;
- visualizzazioni e tabelle complesse non fanno parte del renderer v1;
- il manifest è tamper-evident per consistenza/digest ma non firmato;
- preview/replace UI e kill/power-loss reale restano aperti.

Questa evidenza chiude i formati richiesti da RF-085; non dichiara completo il
percorso Report/UI né la readiness App Store.
