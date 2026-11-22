<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0022 — Export scientifico transazionale e verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0022 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-16 |
| Data decisione | 2026-09-16 |
| Approvazione | Deriva da RF-085, RQ-040, RQ-044, RQ-059 e RQ-061 |
| Fonte | GS-DAT-001; GS-SEC-001; GS-API-001; ADR-0014; ADR-0019 |
| Sostituisce | Nessuno |

## Contesto

Un export scientifico deve essere utilizzabile fuori dal package senza perdere il
legame con indagine, corpus, descriptor, algoritmo, limiti e byte effettivamente
consegnati. Scrivere direttamente nella destinazione renderebbe osservabili file
parziali; esportare l'intera fonte per comodità violerebbe minimizzazione e
selezione esplicita. Il rapporto, inoltre, non può introdurre Finding o Evidence
estranei alla revisione scelta.

## Decisione

1. `ReportRevision` è una proiezione immutabile e content-addressed di un solo head
   Investigation. Contiene soltanto Finding selezionati e la chiusura esatta delle
   Evidence referenziate.
2. L'export iniziale è una directory nuova e non sovrascrive destinazioni esistenti.
   JSON e Markdown vengono prodotti in uno staging fratello con nomi generati.
3. `export-manifest.json` schema 1 registra generazione, corpus, descriptor completo,
   algoritmo, parametri, preprocessing, backend, determinismo, selezione, file,
   lineage, Caveat, validazione e parametri di presentazione.
4. Ogni payload ha byte count e SHA-256. Manifest e file vengono riletti e verificati
   prima del rename atomico dello staging; solo dopo il rename esiste un
   `ExportReceipt`.
5. Path sorgente, nomi file, nome utente/device e testo completo delle fonti non
   entrano nel manifest o nel rapporto. Il Markdown tratta domanda e contenuto
   variabile come testo con escaping.
6. La prima slice supporta locale italiano e inglese; il locale non modifica JSON,
   identità, numeri o lineage.
7. PDF, CSV, sostituzione di una destinazione, preview UI e fonti complete richiedono
   slice e verifiche dedicate; non sono simulate dal contratto corrente.

## Alternative considerate

- Singolo file JSON senza manifest: respinto perché non inventaria Markdown né
  consente di verificare tutti i byte consegnati.
- Scrittura diretta nella destinazione: respinta perché espone stati parziali.
- ZIP proprietario: rinviato; una directory leggibile riduce lock-in e superficie di
  decompressione nella baseline.
- Persistenza del Report nel DAG analitico: respinta per questa slice; il Report è
  una proiezione editoriale, non un risultato ricostruibile del calcolo.

## Conseguenze

- Export JSON/Markdown è disponibile in Core, Kit e CLI con failure tipizzate.
- Un Artifact di interpretazione invalidato impedisce un nuovo export invece di
  ricostruire implicitamente risultati potenzialmente diversi.
- L'assenza di sovrascrittura evita perdita accidentale; versionamento o replace
  sicuro potranno essere aggiunti con una decisione esplicita.
- La validazione è dichiarata `candidate`: il manifest non trasforma prove parziali
  in supporto scientifico completo.

## Verifica

- identità e round-trip di ReportRevision ed ExportManifest;
- digest e inventario di JSON/Markdown;
- assenza di path e fonte completa;
- manomissione rilevata in riapertura;
- tre interruzioni pre-commit senza destinazione parziale;
- contract test GlifiKit/GlifiCLI e gate macOS/iPadOS.
