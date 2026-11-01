<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-150 — Interfaccia essenziale e presentazione progressiva

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-150 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente; audit UI aperti |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Non applicabile; registro operativo |
| Riferimenti | GS-UI-001; GS-STD-001-15; GS-STD-001-29; ADR-0014; ADR-0024 |

## Ambito

Panoramica con prossima azione contestuale, sidebar ordinata per percorso di
ricerca, toolbar con menu di progetto, metadati espandibili, barra di stato
contestuale e risultati sequenziali nelle finestre strette o con testo di
accessibilità. I limiti scientifici restano visibili. Le selezioni dei gruppi
usano simboli e valori accessibili; le tabelle accettano Invio e Spazio.

La presentazione delle conclusioni sostituisce i segnaposto con gli argomenti
senza reinterpretare il contenuto degli argomenti. Nome iniziale e domanda
iniziale passano dal catalogo italiano/inglese. Le azioni sullo stato vuoto
creano effettivamente il progetto e i controlli di codifica sono disabilitati
in assenza di progetto o durante operazioni in corso.

## Consegna e controlli osservati

La consegna è isolata nel branch `refactor/essential-native-interface`, basato su
`origin/main` alla revisione `f348553`, nel worktree
`/private/tmp/GlifiStudio-ui-commit`. Include soltanto la revisione UI; il ciclo
documentale macOS e la modifica preesistente allo schema iPadOS restano nella
copia di lavoro originale dell'altra sessione.

1. `make verify`, con Xcode 27.1, Apple Swift 6.4, Python 3.12 e cache separata
   `/private/tmp/GlifiStudioUICommitVerify`: **superato**, codice di uscita 0.
   La verifica comprende controlli statici e documentali, lint Swift, **246 test**,
   validazione veraPDF di **2 PDF/A-2u**, recovery su **22 checkpoint**, smoke test
   CLI e QueryAST, build **Debug e Release macOS e iPadOS** dal workspace con
   firma disabilitata.
2. `Scripts/check-oracles.py --require`, con il percorso di Rscript già installato
   incluso nel PATH: **superato**, **111 righe** riprodotte e collegate ai test
   Swift. La verifica è esplicita perché il PATH ristretto della prima invocazione
   di `make verify` non individuava Rscript.
3. `git diff --check`: **superato**. I soli documenti di esito vengono aggiornati
   dopo la verifica; controllo documentale e di conformità sono ripetuti prima
   del commit.

I tentativi iniziali nella copia condivisa erano stati fermati da una scheda DoR
in lavorazione e da un `deinit` del modello aggiunto dall'altra sessione. Nessuno
di questi problemi appartiene al branch UI isolato; non sono stati aggirati
controlli né incluse modifiche documentali concorrenti per ottenere l'esito.

L'ispezione visiva tramite automazione nativa non è stata eseguita perché il Mac
è bloccato. Xcode segnala CoreSimulator 1171.7.0 precedente alla versione
1174.9.2 richiesta: le build generiche riescono, ma non costituiscono prove
interattive nel simulatore. Le build iPadOS segnalano inoltre il warning già
presente sulla dichiarazione di apertura dei documenti in place.

## Limiti

Questa revisione non dichiara chiusi G4, EA-T-03, EA-A-01, EA-A-03 o EA-A-07.
Audit VoiceOver e Voice Control, contrasto misurato, pseudolocalizzazione,
restoration e prove su dispositivi fisici richiedono evidenze dedicate.
La modifica preesistente allo schema iPadOS non fa parte della revisione.
