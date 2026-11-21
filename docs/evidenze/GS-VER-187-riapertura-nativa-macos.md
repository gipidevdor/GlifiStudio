<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-187 — Riapertura attraverso il ciclo documentale macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-187 |
| Tipo | Evidenza di correzione e verifica |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-166; RF-001; RQ-004 |

## Perimetro e identità

Il comando Riapri deve risolvere il bookmark e inoltrare l’URL all’azione
documentale nativa senza sostituire la sessione del modello chiamante.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con
l’incremento GS-VER-185 preservato e gli incrementi macOS concomitanti. Nessuna
CI remota o revisione successiva viene attestata.

## Contratto di verifica

Test hostless con opener iniettato: URL corretto e singola invocazione,
snapshot/query/profilo/piano conservati, bookmark assente e failure non distruttiva.
I tre callsite macOS devono attraversare il confine nativo; iPadOS resta invariato.

Gli esiti effettivi sotto precedono la promozione della clausola; la sola
presenza dei test non ne attesta il superamento.

## Prima riproduzione: bookmark assente

Il primo RED comprende **13 test, 12 superati, 1 fallito, 0 saltati** e fallisce
sulla precondizione bookmark non nullo. Una prova Foundation indipendente mostra
`NSCocoaErrorDomain` 256 per `[.withSecurityScope, .minimalBookmark]`; la sola
`.withSecurityScope` crea il bookmark. La documentazione Apple di
[`withSecurityScope`](https://developer.apple.com/documentation/foundation/nsurl/bookmarkcreationoptions/withsecurityscope)
vieta la combinazione con `.minimalBookmark` o `.suitableForBookmarkFile`.

Questo RED non viene attribuito al difetto di routing: un secondo RED dopo la
sola correzione delle opzioni dimostra poi il comportamento di Riapri.
L'estensione Ready di GS-DOR-166 precede la modifica delle opzioni.

## Secondo RED e correzione del routing

Dopo la sola correzione della creazione del bookmark macOS, il secondo RED
comprende **13 test, 12 superati, 1 fallito, 0 saltati**. Cinque asserzioni
riproducono la sostituzione di URL, snapshot, profilo, piano e query nel modello
chiamante. Questo esito riguarda il routing originale, separatamente dal primo
RED del bookmark.

Il confine macOS corretto inoltra l'URL all'opener iniettato; le tre azioni della
view passano l'azione nativa `openDocument`. L'overload senza argomenti resta solo
su iPadOS. Le opzioni di risoluzione e il formato dei bookmark non cambiano.

## GREEN del modello

`make test-macos` termina con **exit 0: 15 test superati, 0 falliti, 0 saltati**.
I tre nuovi test verificano singola invocazione e stato preservato, bookmark
assente senza invocazioni, failure dell'opener con sessione ancora interrogabile.
La suite include gli incrementi GS-VER-185/186. Il controllo strict della view e
`git diff --check` sono superati; gate e preflight del programma macOS sono superati; CMP-110 è
`verified` nel perimetro del routing e del modello testati.

## Verifica integrata sullo snapshot

`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
terminano entrambi con **exit 0** sullo snapshot descritto in
[GS-VER-188](GS-VER-188-gate-macos.md), manifest SHA-256
`07673ac2d88e369010ea0a065192e3c20ffd24c6ce5a8ee73940e3b309870b5f`.
Il gate conferma **36 definizioni / 45 esecuzioni macOS, 0 fallite, 0 saltate**,
build Debug/Release, analisi statica e archivio macOS senza firma; nessun runtime
warning nei risultati nativi. Tutti i controlli condivisi sono eseguiti.
Il profilo non esegue build iPadOS e non è gate globale, CI, prova di finestre
reali, autosave, audit VoiceOver o G4. Le ottimizzazioni successive di Core,
test e benchmark, avviate da altre sessioni, sono escluse da questa attestazione:
non è implicita compatibilità con la working copy successiva allo snapshot.

## Limiti dell’audit

Mac bloccato e scelta esplicita dell’iniziatore di proseguire soltanto con test
automatici: nessuna verifica GUI manuale, VoiceOver, finestre SwiftUI reali,
autosave o G4. Lo sviluppo dedicato iPadOS è rimandato. Firma, App Review e
completamento della piattaforma non sono dimostrati dai controlli hostless.
