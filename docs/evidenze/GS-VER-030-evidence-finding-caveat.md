<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-030 — Evidence, Finding e Caveat persistenti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-030 |
| Tipo | Evidenza di verifica della pipeline epistemica MVP |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata della slice descrittiva e keyness; validazione scientifica/UI completa non implicata |

## Ambito

- requisiti coperti nella slice: RF-057–RF-060, RF-064–RF-065, RF-082,
  RQ-028 e RQ-036;
- verifiche coperte: TV-043 e parte strutturale/deterministica di TV-055;
- ambienti osservati: macOS locale, Xcode 27.0, Apple Swift 6.4, language mode
  Swift 6;
- superfici: GlifiCore, package `.glifi`, GlifiKit, GlifiCLI e build app macOS/
  iPadOS.

## Procedura

1. generare una interpretazione descrittiva da un profilo corpus non vuoto e
   ripeterla sugli stessi input;
2. verificare identità Evidence/Finding, SourceReference, misure, unità, categoria
   epistemica e caveat;
3. applicare la policy keyness a casi `strong`, `moderate`, `caution` e non
   eleggibili, quindi verificare ordine lessicografico e limite materiale;
4. alterare l'identità Evidence nel payload persistito e richiederne la decodifica
   fail-closed;
5. eseguire un piano comparativo senza supporto sufficiente e verificare che il
   risultato contenga `insufficientEvidence` senza Evidence o Finding inventati;
6. ripetere l'esecuzione e verificare riuso dello stesso Artifact di
   interpretazione senza nuova generazione;
7. eseguire `make verify`, inclusi controlli statici, test, smoke CLI JSON e build
   Debug/Release senza firma per macOS e iPadOS.

## Risultato osservato

- 73 test Swift superati: 64 GlifiCore e 9 GlifiKit;
- EvidenceID e FindingID sono content-addressed, tipizzati e ricalcolati durante
  la decodifica;
- `interpretation-rules-mvp-v1` produce lo stesso risultato a parità di piano,
  Artifact e policy;
- `support-policy.descriptive-completeness-v1` e
  `support-policy.keyness-gtest-bh-v1` conservano tutte le dimensioni valutate e
  non producono un confidence score universale;
- `editorial-rank-v1` ordina entro famiglia con FindingID come tie-break e lascia
  assenti stabilità/novità non misurate, accompagnandole con caveat;
- conteggi attesi bassi producono Evidence limitata, supporto `caution` e caveat
  visibile; alternative non eleggibili o oltre limite sono aggregate per motivo;
- il confronto smoke CLI privo di termini eleggibili produce
  `insufficientEvidence`, zero Evidence e zero Findings positivi;
- l'Artifact `studio.glifi.artifact.interpretation.v1` dipende dal piano e da
  tutti gli output, viene committato prima del terminale e riusato
  idempotentemente;
- il JSON GlifiKit/CLI conserva struttura, lineage, assessment, caveat, chiavi
  localizzabili e fattori editoriali senza esporre tipi interni;
- il gate completo e le quattro build applicative sono terminati con codice zero.

## Limiti

La prova non valida empiricamente le soglie della policy keyness e non copre
evidence conflict, stabilità/novità misurate, Investigation, selezione editoriale,
ReportRevision, export, UI progressive disclosure, studi di comprensione,
accessibilità su dispositivo o validazione scientifica esterna. Il supporto è
verificato soltanto per profilo corpus e keyness; le altre famiglie restano
fail-closed.

## Esito

**Superato localmente per la pipeline Evidence/Finding/Caveat bounded,
deterministica, persistente e condivisa da Core, Kit e CLI.**
