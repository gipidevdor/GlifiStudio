<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-150 — Interfaccia essenziale e presentazione progressiva

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-150 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Verifica parziale |
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

## Controlli osservati

1. `make check-localization check-apple check-failure-messages
   check-swift-dialect check-compliance format-check`, con Python 3.12:
   **superato**. Il lint Swift completo è passato.
2. Build Debug macOS dal workspace con Xcode 27.1, Swift 6.4,
   `CODE_SIGNING_ALLOWED=NO` e cache isolata in
   `/private/tmp/GlifiStudioUIBuild/macOS`: **superata** dopo l'estrazione di
   `StudioDetailsSection` e l'aggiornamento di localizzazione e RTL.
3. Build Debug iPadOS, destinazione generica iOS Simulator, dal medesimo workspace
   e cache isolata in `/private/tmp/GlifiStudioUIBuild/iPadOS`: **superata**.
   Xcode emette un warning relativo alla dichiarazione di apertura dei documenti
   in place, pertinente al ciclo documentale seguito dall'altra sessione.
4. `make verify`, con Python 3.12 e cache separata
   `/private/tmp/GlifiStudioUIVerify`: **non superato**, arrestato dal controllo
   documentale sulla scheda `GS-DOR-011` aggiunta contemporaneamente dall'altra
   sessione; manca il marker di stato `**Ready`. I controlli successivi del
   comando, inclusi i test completi, non sono quindi eseguiti da questa revisione.
5. `git diff --check`: superato prima della registrazione finale.

Il primo tentativo con Python di sistema si è arrestato perché `zip(strict=)`
richiede Python 3.10 o successivo; i controlli sopra usano il Python 3.12 già
presente nell'ambiente. Un primo tentativo iPadOS era stato bloccato dal `deinit`
non isolato del modello condiviso; l'altra sessione lo ha corretto prima delle
build finali sopra riportate.

L'ispezione visiva tramite automazione nativa non è eseguibile perché il Mac è
bloccato. Xcode segnala inoltre CoreSimulator 1171.7.0 precedente alla versione
1174.9.2 richiesta: la build generica riesce, ma non costituisce prova
interattiva nel simulatore.

## Limiti

Questa revisione non dichiara chiusi G4, EA-T-03, EA-A-01, EA-A-03 o EA-A-07.
Audit VoiceOver e Voice Control, contrasto misurato, pseudolocalizzazione,
restoration e prove su dispositivi fisici richiedono evidenze dedicate.
La modifica preesistente allo schema iPadOS non fa parte della revisione.
