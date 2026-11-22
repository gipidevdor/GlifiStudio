<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-186 — Ownership della cancellazione nel modello macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-186 |
| Tipo | Evidenza di correzione e verifica |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-165; RQ-011; RQ-058 |

## Identità e perimetro

La copia di lavoro parte da `a86a53b512bd777f191c89692e0c573a3d37a3ff` e conserva
l'incremento GS-VER-185. La verifica riguarda il modello reale nel target macOS;
nessuna CI remota o revisione successiva è attestata da questo documento.

Il comando di annullamento rilasciava handle, progresso e stato occupato mentre
il task proprietario consumava ancora gli eventi. La correzione mantiene la
richiesta di annullamento separata dalla pulizia terminale: il task di esecuzione
rilascia handle e progresso, `run` rilascia lo stato occupato.

L'annullamento rimane idempotente e cooperativo. Un esito già completato può
precedere la cancellazione; non viene convertito artificialmente in failure e
non vengono rimossi commit validi.

## Contratto di verifica

Regressione deterministica all'assegnazione dell'handle, senza sleep o polling:
richiedere due annullamenti e verificare che ownership e stato occupato restino
attivi prima dell'esito terminale; verificare poi pulizia e riutilizzabilità.
Registrare RED/GREEN, controlli mirati e gate effettivamente eseguiti prima della
promozione di CMP-109.

## Riproduzione prima della correzione

Il test `cancellationKeepsExecutionOwnershipUntilTheConsumerFinishes` viene
aggiunto prima della correzione. `make test-macos` riproduce il difetto:
**12 test, 11 superati, 1 fallito, 0 saltati**. Le quattro asserzioni del nuovo
scenario mostrano stato occupato rilasciato, handle assente e annullamento non
più disponibile immediatamente dopo la richiesta; il progresso `planning`
rimane invece presente dopo la fine del consumatore.

La API di osservazione deterministica compila su SDK 27; non sono impiegati
sleep o polling. Il modello corretto supera `make test-macos` con **exit 0: 12 test superati,
0 falliti, 0 saltati**. Lint strict dei due file Swift modificati e
`git diff --check` superati; revisione indipendente senza difetti nel perimetro.
Il successivo gate macOS completo è superato; CMP-109 è `verified` nel perimetro automatico dichiarato.

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

## Limiti dell'audit macOS

Il Mac è bloccato durante il tentativo di audit manuale. L'iniziatore sceglie
esplicitamente di proseguire soltanto con test automatici: nessuna interazione
GUI, prova VoiceOver, finestra documentale reale o audit manuale viene dichiarato
eseguito. G4 resta aperto. Lo sviluppo dedicato iPadOS è rimandato; eventuali
verifiche condivise non costituiscono completamento di quella piattaforma.
