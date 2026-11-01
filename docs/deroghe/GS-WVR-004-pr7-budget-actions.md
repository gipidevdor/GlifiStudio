<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-WVR-004 — PR percorso 0.1 con CI bloccata dal budget

| Campo | Valore |
| --- | --- |
| Identificatore | GS-WVR-004 |
| Tipo | Deroga controllata |
| Versione | 1.1.0 |
| Stato | Scaduta il 2026-09-22; rientro in corso, chiusura dopo entrambi i workflow verdi |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Regole interessate | GS-STD-001-20; integrazione con check remoti verdi |
| Ambito | PR #7 `cursor/percorso-produttivita-0-1-a9b8` |
| Scadenza | 2026-09-22 o ripristino del budget Actions, se precedente |

## Motivazione

I workflow `Verifica` e `App Store preflight` sulla PR #7 creano i check
`static-quality`, `format-check`, `verify` e `app-store-baseline` ma non avviano
alcuno step. Annotazione GitHub: “The job was not started because an Actions
budget is preventing further use.” Il fallimento è infrastrutturale, non un esito
dei controlli di prodotto.

## Rischio e impatto

- manca ripetizione indipendente su runner Ubuntu/`xcode-27`;
- la PR introduce UI Must, fixture gold/ValidationManifest e documentazione di gate;
- un errore specifico del runner potrebbe emergere al ripristino del budget.

## Alternative considerate

- attendere il budget: blocca il percorso produttivo già verificato localmente;
- runner self-hosted: non approvato (segreti/infrastruttura);
- indebolire i workflow: respinto.

## Mitigazione

- `make quality-static` superato sul tip della PR;
- confini architetturali, localizzazione, compliance, fixture e dialetto Swift
  verificati automaticamente;
- smoke CLI/`make verify` restano obbligatori su Mac con Xcode 27 prima del claim
  G3 runtime;
- deroga limitata a questa PR; non estendibile senza nuova registrazione.

## Verifica compensativa

GS-VER-038. Run GitHub `35082180669` e `35082180605` conclusi senza step con
annotazione di budget.

## Piano di rientro

1. ripristinare il budget Actions;
2. rieseguire entrambi i workflow sul tip (o sul merge commit);
3. correggere o revertire se emerge una divergenza reale;
4. chiudere questa deroga soltanto dopo check verdi.

## Rientro

Il budget Actions è stato ripristinato dopo la scadenza. Il 2026-10-03 i workflow sono stati
eseguiti sul runner `xcode-27` per la [PR #11](https://github.com/gpicchiarelli/GlifiStudio/pull/11)
(`main` a `4463b7e`, superinsieme dei commit in ambito): `Verifica` verde,
`App Store preflight` ancora in esecuzione al momento della stesura ([GS-VER-141](../evidenze/GS-VER-141-prima-ci-remota-verde.md)).
Le revisioni storiche non sono state rieseguite singolarmente. Il periodo tra la
scadenza e il rientro resta registrato come non conformità in GS-VER-141.

## Riferimenti

- [PR #7](https://github.com/gpicchiarelli/GlifiStudio/pull/7)
- [Workflow Verifica](https://github.com/gpicchiarelli/GlifiStudio/actions/runs/35082180669)
- [Workflow App Store preflight](https://github.com/gpicchiarelli/GlifiStudio/actions/runs/35082180605)
- [GS-VER-038](../evidenze/GS-VER-038-pr7-budget-actions.md)
