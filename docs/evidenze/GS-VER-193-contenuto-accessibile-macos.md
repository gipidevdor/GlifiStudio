<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-193 — Contenuto accessibile delle fonti e dell’anteprima macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-193 |
| Tipo | Evidenza di correzione e verifica macOS |
| Versione | 1.0.0 |
| Stato | Superato per correzione statica e build macOS; audit VoiceOver aperto |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-193; RQ-012; GS-APL-003 |

## Perimetro e identità

Tre Text preesistenti, fonte KWIC, fonte evidence e anteprima export, ricevono
etichette accessibili generiche che sostituiscono il contenuto. L'incremento
rimuove gli override soltanto nel ramo macOS, conservando Section, testo,
selezionabilità e semantica nativa. Il ramo iPadOS resta invariato.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con gli
incrementi concorrenti preservati. La DoR precede il codice; l'avvio segue il
coordinamento dopo B/C. Nessuna nuova revisione o CI remota è attestata.

## Contratto di verifica

Revisione dei tre siti e delle condizioni di piattaforma, lint e compilazione
nel profilo macOS. Nessun test che replichi la riga di implementazione viene
introdotto per questa correzione locale e reversibile. Il risultato verificabile
è l'assenza dell'override nel ramo macOS, non un audit VoiceOver superato.

## Verifica statica osservata

I tre override sono ora racchiusi in `#if !os(macOS)`: il ramo macOS conserva
Section, testo selezionabile e semantica Text nativa, il ramo iPadOS conserva
il modificatore esistente. Revisione indipendente dei tre siti e controllo di
formattazione superati; `git diff --check` non rileva problemi. La compilazione
integrata Debug/Release e il preflight macOS sono superati; CMP-193 è `verified`
per la sola correzione statica e build, senza audit VoiceOver.

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

## Limiti

Mac bloccato e scelta esplicita di soli controlli automatici: nessuna verifica
GUI manuale, VoiceOver o su dispositivo è eseguita. La correzione circoscritta
non certifica zero problemi di accessibilità, Instruments, iPadOS, G4, firma o
App Review; non promuove un nuovo criterio EA a gate.
