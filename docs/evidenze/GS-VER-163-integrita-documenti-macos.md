<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-163 — Integrità dei documenti macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-163 |
| Tipo | Evidenza di correzione e verifica |
| Versione | 1.1.0 |
| Stato | Superato: modello macOS in locale e gate CI `xcode-27` su `main` `a86a53b` |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-06 |
| Approvazione | GS-DOR-163; RF-001; RQ-043; GS-APL-005 |

## Difetti e correzioni

La creazione rimuoveva ricorsivamente qualsiasi destinazione omonima, compresi package validi
e package incompleti con fonti recuperabili. L'attacco ripetuto di un documento con il flag
iniziale ancora attivo poteva ricreare il progetto e perdere le fonti.

L'inizializzazione ora rimuove con `rmdir` soltanto un placeholder vuoto del sistema, fuori dal
Main Actor; file, link simbolici e directory non vuote restano intatti. Un package con manifest
viene aperto e verificato dal Kit anche se il flag è ancora iniziale. Un attacco ripetuto alla
sessione corrente non modifica generazione, query o fonti.

L'apertura precedente chiudeva subito la sessione corrente: un errore lasciava la vista sul vecchio
snapshot senza una sessione utilizzabile. Ora la candidata deve superare apertura, snapshot e
lettura della storia prima della sostituzione. L'accesso security-scoped resta attivo per tutta
la sessione e viene bilanciato al cambio di progetto o alla distruzione del modello.

Su macOS Nuovo e Apri usano le azioni SwiftUI del sistema documentale. Un documento senza URL
propone il salvataggio nativo prima dell'importazione, con testo italiano e inglese.

## Verifica

`GlifiStudioMacTests` è un target Swift Testing senza app host: compila il modello reale e
GlifiKit con Swift 6, strict concurrency e warning come errori. Otto test verificano placeholder,
attacco ripetuto, flag iniziale obsoleto, package incompleto, file/link, apertura fallita,
inizializzazione fallita e cambio di progetto. `make test-macos` esegue la suite dal workspace;
`make verify` la include nella verifica Debug macOS.

`make test-macos`: superato. Il riepilogo `.xcresult` della successiva esecuzione nel gate del
2026-11-01 conferma **8 test superati, 0 falliti, 0 saltati**, su macOS 27.2 arm64 con Xcode 27.1
e Apple Swift 6.4. L'ultimo scenario verifica anche la pulizia dei passaggi di codifica quando
si passa a un altro progetto.

Il primo `make verify` con Python 3.12 supera 227 test Core/Kit, 22 checkpoint di process-kill
recovery, due PDF/A-2u verificati con veraPDF, gli otto test dell'app e la build Release macOS.
Si arresta nella successiva build iPadOS per accessi `inout` sovrapposti a `n` nelle chiamate
LAPACK di `GlifiExploratoryAnalysis.swift`, aggiunto contemporaneamente da un'altra sessione.
Quel file non appartiene alla correzione documentale. Il controllo degli oracoli, rieseguito
anche con `--require` e `Rscript` nel PATH, riproduce 107 righe.

Dopo la correzione concorrente di LAPACK, `make verify-app-store` viene rieseguito con Python
3.12 e Rscript disponibili. Supera documentazione, conformità, oracoli, fixture, architettura,
localizzazione, tassonomia, baseline Apple/App Store e dialetto Swift. Si arresta al lint sui
nuovi sorgenti analitici ancora in modifica: `GlifiStudioTextAnalytics.swift`,
`GlifiTextMatrixOperators.swift`, `GlifiExploratoryAnalysis.swift` e `GlifiCodingRules.swift`.
I successivi test e controlli di packaging non vengono eseguiti da questo tentativo.

Il gate complessivo resta **non superato**: i risultati macOS descrivono lo stato osservato
prima delle ulteriori modifiche concorrenti al motore. Nessun controllo è stato indebolito.
Le cache dedicate dei due tentativi sono state rimosse dai trap degli script.

## Limiti

I test coprono modello e package sintetici, non interazione GUI, autorizzazioni sandbox reali,
file coordination, autosave del wrapper, conflitti e VoiceOver su dispositivo. G4 resta aperto.

## Identità dell'integrazione

La copia locale completa è conservata nel commit `7b040d1`. In fase di
riallineamento con main questa evidenza è rinumerata da GS-VER-140 a GS-VER-163:
GS-VER-140 identifica già una verifica degli accessi al package pubblicata.
La scheda associata diventa GS-DOR-163 e la clausola CMP-107. La rinumerazione
preserva entrambe le provenienze; gli esiti storici sopra non sono attribuiti
alla nuova integrazione. Gli esiti sulla head consolidata sono registrati nella PR.

## Esecuzione remota su `main`

Il commit integrato `main` `a86a53b` (#27) supera i quattro controlli CI `xcode-27`:
[`verify`](https://github.com/gipidevdor/GlifiStudio/actions/runs/41336171753/job/124936428913) e
[`app-store-baseline`](https://github.com/gipidevdor/GlifiStudio/actions/runs/41336171695/job/124936354278), oltre a `static-quality` e
`format-check`. `verify.sh` (con `set -euo pipefail`) esegue `xcodebuild test` sullo schema
`GlifiStudio-macOS`, il cui unico testable è `GlifiStudioMacTests`, dopo 293 test Core,
37 test Kit, i contract test CLI e i 22 checkpoint di recovery, e prosegue con le build
Release macOS e Debug/Release iPadOS; `verify-app-store.sh` ripete la stessa sequenza con
baseline Apple/App Store e packaging. Con `-quiet` il log non riporta il conteggio dei test
macOS: l'esito è l'uscita con stato 0 del passo, non un riepilogo `.xcresult`. Rscript e
veraPDF sono assenti sul runner e i relativi controlli risultano saltati.

Il gate globale, non superato nei tentativi locali descritti sopra, risulta superato sul
runner remoto per la revisione integrata. CMP-107 passa a `verified` sul gate G3; i limiti
sopra restano aperti e G4 non è dichiarato.
