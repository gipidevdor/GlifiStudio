<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0023 — Proiezioni PDF/A-2u e CSV verificabili

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0023 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-16 |
| Data decisione | 2026-09-16 |
| Approvazione | Deriva da RF-085, RQ-028, RQ-040, RQ-044 e RQ-061 |
| Fonte | GS-DAT-001; GS-SEC-001; GS-PROD-001; ADR-0022 |
| Sostituisce | Nessuno; estende ADR-0022 |

## Contesto

La baseline prodotto richiede un rapporto PDF/Markdown e dati CSV/JSON. PDF e CSV
non possono essere semplici conversioni opache: devono conservare selezione,
leggibilità, accessibilità, identità macchina e protezione da contenuto
interpretabile, restando nello stesso commit transazionale dell'export.

## Decisione

1. Il PDF è una proiezione presentazionale della stessa `ReportRevision` usata da
   JSON e Markdown. È prodotto con Core Graphics/Core Text, profilo PDF/A-2u,
   testo ricercabile, struttura taggata, lingua, gerarchia di titoli, footer e
   paginazione bounded. Si usano le API strutturali di Xcode 27, `ActualText` per
   ogni blocco e metadati XMP `pdfaid` 2/U verificati fail-closed; la normalizzazione
   del singolo indicatore XMP ricomprime lo stream e aggiorna in modo bounded
   `Length`, tabella xref e `startxref`.
2. Il PDF non è autorità semantica e non partecipa a `ReportRevisionID`; byte,
   media type e schema sono comunque inventariati da `ExportManifest`.
3. Il CSV è una coppia indivisibile `findings.csv`/`evidence.csv`, UTF-8 RFC 4180
   con CRLF e intestazione stabile. Ogni riga espone ID e relazioni utili, più il
   payload JSON canonico completo per evitare perdita semantica.
4. Le celle che iniziano con indicatori di formula sono neutralizzate prima
   dell'escaping CSV. I CSV non contengono il testo completo delle fonti.
5. Il verificatore accetta soltanto i cinque nomi/schema/media type approvati,
   richiede entrambi i CSV, apre il PDF, verifica pagine, struttura taggata e XMP
   PDF/A-2u e, quando `report.json` è presente, rigenera i CSV per confronto
   byte-a-byte.
6. I quattro formati condividono staging, limiti, digest, rilettura e singolo rename
   finale di ADR-0022. Una richiesta può scegliere un sottoinsieme non vuoto.

## Alternative considerate

- HTML convertito in PDF: respinto per evitare un secondo motore di layout e una
  superficie attiva non necessaria.
- PDF rasterizzato: respinto perché compromette ricerca, copia e tecnologie
  assistive.
- Un solo CSV eterogeneo: respinto perché riduce interoperabilità tabellare e rende
  ambigua la cardinalità Finding/Evidence.
- Dipendenza PDF/CSV esterna: respinta; i framework Apple e il renderer bounded
  sono sufficienti alla baseline.

## Conseguenze

- Core, GlifiKit e CLI possono produrre PDF/Markdown/CSV/JSON dalla stessa
  selezione senza cambiare il dominio.
- PDF/A-2u e struttura taggata migliorano conservazione e fruizione, ma l'audit
  manuale VoiceOver resta un gate G4 distinto.
- Il payload JSON dentro CSV privilegia round-trip e affidabilità rispetto a un
  foglio esclusivamente editoriale.
- Grafici e tabelle scientifiche future richiederanno blocchi PDF e schema CSV
  versionati, non modifiche silenziose ai contratti v1.

## Verifica

- apertura Core Graphics/PDFKit, presenza di pagine, testo, albero taggato e XMP
  `pdfaid:part=2`/`pdfaid:conformance=U`;
- rendering PNG e ispezione visiva di gerarchia, margini e footer;
- intestazioni, CRLF, relazioni, round-trip e assenza della fonte nei CSV;
- inventario/digest e confronto CSV con `report.json`;
- Core/Kit/CLI, build macOS/iPadOS e preflight App Store.
