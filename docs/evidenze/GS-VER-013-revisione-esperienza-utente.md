<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-013 — Revisione dell'esperienza utente

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-013 |
| Tipo | Evidenza di verifica documentale, architetturale e UX |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata; validazione con utenti non ancora eseguita |

## Obiettivo

Verificare che il paradigma UX guidato da indagini, intenzioni ed evidenze sia
definito senza duplicare la semantica scientifica e sia integrato in requisiti,
architettura, tracciabilità, profili Apple e preparazione App Store.

## Baseline esaminata

- README, indice, visione, requisiti, architettura, tracciabilità e glossario;
- roadmap, decisioni aperte, standard e piano documentale;
- tutti gli ADR e i profili Apple/App Store pertinenti;
- GS-MET-001, descriptor, DAG, analisi temporale, inferenza e visualizzazioni;
- workspace Xcode, app macOS/iPadOS, GlifiKit, GlifiCore, GlifiCLI e test;
- catalogo di localizzazione e dati operativi App Store.

L'implementazione osservata è uno scaffold SwiftUI con `NavigationStack`,
`StudioHomeModel` sul Main Actor e un contratto GlifiKit di solo stato. Non sono
presenti tipi o flussi di progetto, indagine, planner, evidence/finding o relazione.

## Controlli eseguiti

1. separazione delle responsabilità fra GS-UX, GS-MET, architettura e profili Apple;
2. copertura dei 14 information item UX e indicizzazione automatica;
3. tracciabilità NS-015…23 → RF-047…74/RQ-030…40 → VA-07/ADR-0014 → TV-037…48;
4. coerenza di Evidence, Finding, Caveat e categorie epistemiche;
5. verifica della catena Conclusione → Evidenza → Fonti → Metodo e delle classi di lineage;
6. verifica di adattamento macOS/iPadOS, accessibilità e localizzazione italiana;
7. controllo di link, metadati, identificatori, SPDX e marker normativi;
8. esecuzione di `make verify` e `make verify-app-store` sulla revisione finale.

## Risultato osservato

- GS-UX-001 definisce 14 responsabilità autonome e non un catalogo di schermate;
- Analysis Planner e motore interpretativo restano distinti da DAG e generazione;
- requisiti, view architetturale e verifiche pianificate sono bidirezionalmente tracciati;
- i quality gate documentali riconoscono e controllano la famiglia GS-UX;
- test Swift, smoke test e build Debug/Release macOS/iPadOS sono superati;
- preflight e packaging App Store senza firma sono validi.

## Esito e limiti

**Superato localmente per struttura, coerenza e verificabilità documentale.** Non
dimostra usabilità, comprensione, accessibilità reale o correttezza di componenti
ancora non implementati. Prima di stabilizzare API e UI servono prototipi, persone
rappresentative, tecnologie assistive, corpus, soglie e policy indicati da
DA-026–DA-030. Firma, dispositivi, TestFlight e approvazione Apple restano fuori
dall'ambito; la CI remota dipende dal budget Actions registrato in GS-WVR-001.
