<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-WVR-003 — Merge della policy macOS con CI bloccata dal budget

| Campo | Valore |
| --- | --- |
| Identificatore | GS-WVR-003 |
| Tipo | Deroga controllata |
| Versione | 1.1.0 |
| Stato | Scaduta il 2026-09-22; rientro in corso, chiusura dopo entrambi i workflow verdi |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | Richiesta esplicita dell'iniziatore di unire i branch verso `main`, eliminare i branch non `main` e allineare il repository |
| Regole interessate | GS-REP-002; GS-STD-001-20; merge soltanto con check remoti verdi |
| Ambito | PR #4, commit `bb5201c` e `5a3a0be`, più il commit documentale che registra questa deroga |
| Scadenza | 2026-09-22 o ripristino del budget Actions, se precedente |

## Motivazione

La PR #4 è mergeable e la revisione automatica ha identificato una lacuna P2 nel
gate delle dipendenze. La lacuna è stata corretta sostituendo la denylist come
prova con una allowlist esterna vuota. I workflow GitHub sul commit corretto sono
stati creati ma non hanno avviato alcuno step: il budget Actions impedisce
ulteriore utilizzo. L'iniziatore ha richiesto esplicitamente il merge e la pulizia
dei branch senza attendere il ripristino del provider.

## Rischio e impatto

- manca una ripetizione indipendente su runner Xcode 27 del gate finale;
- il cambiamento introduce codice prodotto per policy runtime e diagnostica, oltre
  a test, documentazione e controlli statici;
- le prove locali non sostituiscono profiling energetico, App Nap, pressione reale
  o dati Organizer su hardware;
- un errore specifico del runner o del checkout remoto potrebbe emergere al
  ripristino del budget.

## Alternative considerate

- attendere o aumentare il budget Actions: conserva il gate ordinario ma non
  soddisfa la richiesta di allineamento immediato;
- usare un runner self-hosted: introduce infrastruttura e segreti non approvati;
- unire senza registrare il limite: respinto perché falsificherebbe lo stato della
  CI e la tracciabilità.

## Mitigazione

- `make verify` e `make verify-app-store` sono superati sul contenuto finale della
  PR con Xcode 27.0 e Apple Swift 6.4;
- test unitari coprono la matrice completa della policy e il wrapper signpost;
- build Debug/Release e archivi senza firma sono superati su macOS e iPadOS;
- privacy manifest, entitlement, documentazione, App Store baseline, segreti e
  confini architetturali sono verificati automaticamente;
- la review P2 è stata corretta con allowlist vuota di package/framework esterni;
- la PR e il merge commit consentono revert e audit puntuali.

## Verifica compensativa

GS-VER-016 registra ambiente, risultati e limiti. Sul commit `5a3a0be` i run
`34970030640` (`Verifica`) e `34970030598` (`App Store preflight`) hanno concluso
con zero step eseguiti e annotazione GitHub “Actions budget is preventing further
use”. Il fallimento remoto è quindi infrastrutturale, non un esito dei test.

## Piano di rientro

1. ripristinare il budget Actions entro la scadenza;
2. rieseguire entrambi i workflow sul merge commit di `main`;
3. correggere o revertire il merge se emerge una divergenza reale;
4. marcare questa deroga chiusa soltanto dopo entrambi i workflow verdi;
5. non usare questa deroga per cambiamenti successivi.

Se il budget non viene ripristinato entro la scadenza, la deroga diventa una non
conformità da riesaminare prima della successiva integrazione.

## Rientro

Il budget Actions è stato ripristinato dopo la scadenza. Il 2026-10-03 i workflow sono stati
eseguiti sul runner `xcode-27` per la [PR #11](https://github.com/gpicchiarelli/GlifiStudio/pull/11)
(`main` a `4463b7e`, superinsieme dei commit in ambito): `Verifica` verde,
`App Store preflight` ancora in esecuzione al momento della stesura ([GS-VER-141](../evidenze/GS-VER-141-prima-ci-remota-verde.md)).
Le revisioni storiche non sono state rieseguite singolarmente. Il periodo tra la
scadenza e il rientro resta registrato come non conformità in GS-VER-141.

## Riferimenti

- [PR #4](https://github.com/gpicchiarelli/GlifiStudio/pull/4)
- [Workflow Verifica](https://github.com/gpicchiarelli/GlifiStudio/actions/runs/34970030640)
- [Workflow App Store preflight](https://github.com/gpicchiarelli/GlifiStudio/actions/runs/34970030598)
- [GS-VER-016](../evidenze/GS-VER-016-osservabilita-e-sostenibilita-macos.md)
