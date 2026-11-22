<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Programma di lineage componibile e parità dei client

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-005 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Richiesta dell'iniziatore: proseguire la progettazione e l'implementazione senza interruzioni |
| Riferimenti | GS-STD-001-07; RF-078; RF-080; RF-084; GS-DAT-001 § SpanMap; GS-QRY-001; GS-VIZ-001 |

## Unità di lavoro

| # | Task | Requisito | Esito atteso |
| --- | --- | --- | --- |
| L1 | SpanMap componibili | RF-078 | Classe `contributive` e composizione `C→B ∘ B→A` che conserva tutte le origini, con spazi di coordinate dichiarati |
| L2 | Parità QueryAST | RF-080 | Contract test: GlifiCore, GlifiKit e CLI producono lo stesso AST canonico, lo stesso digest e lo stesso ordinamento |
| L3 | Viste da VisualizationSpec | RF-084 | Stato del requisito allineato a GS-VER-114 e limiti residui dichiarati |
| L4 | Export delle viste con provenienza | RF-084, GS-VIZ-001 § Export | Bundle `view.csv`, `view-spec.json`, `visual-export-manifest.json` con Artifact, generazione, software, riduzione, cautele e SHA-256 dei file; scrittura atomica |

## Decisioni di progetto

- Composizione: la classe del segmento composto è la più debole fra quelle incontrate nell'ordine
  `exact` < `contributive` < `derivational`; un segmento senza origini è `synthetic`. Un tratto
  `exact` resta `exact` solo se le origini formano un unico intervallo della stessa lunghezza;
  più intervalli `exact` diventano `contributive`. Nessuna origine è scartata né approssimata.
- `contributive` richiede almeno due intervalli di input.

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Nessuna nuova capacità analitica; contratti di lineage e di parità | — |
| requisiti | RF-078, RF-080, RF-084 | — |
| contratto di dominio/API | `GlifiSpanMappingKind.contributive`, `GlifiSpanMap.composed(after:)`; nessun cambio dei client | — |
| failure semantics | Spazi o lunghezze incompatibili → `text.incompatible-span-maps` (`invalidInput`) | — |
| esperienza prevista | Nessun cambiamento di UI | — |
| verifica | Test di proprietà su composizioni casuali a seed fisso, contract test CLI, `make verify` | — |
| dati e migrazione | Il nuovo caso dell'enum è additivo; i payload esistenti restano decodificabili | — |
| sicurezza/privacy | Nessuna | — |
| prestazioni/sistema | Composizione lineare nel numero di segmenti | — |
| tracciabilità | Evidenza, requisiti, tracciabilità, matrice e CHANGELOG per ogni task | — |
| decisioni | Regole di composizione sopra, derivate da GS-DAT-001 | — |

## Stato DoR

**Ready** per L1–L4.

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| L1 | Completato | GS-VER-122 |
| L2 | Completato | GS-VER-123 |
| L4 | Completato | GS-VER-124 |
| L3 | Completato | RF-084 allineato a GS-VER-114; export con manifest e audit su dispositivo restano aperti |
