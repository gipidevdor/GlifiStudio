<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-083 — Chiavi failure e operazione attiva in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-083 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-063; GS-VER-071 |

## Ambito

Rendere verificabili la `messageKey` tipizzata di `GlifiStudioFailure` /
insufficient evidence e l'`operationID` dell'esecuzione attiva cancellabile.

## Controlli

1. Status bar: `failure.message-key` monospaced selezionabile.
2. Insufficient evidence: sezione meta con `messageKey` stabile.
3. Con esecuzione attiva: `execution.active-operation-id` accanto a cancel.
4. Checklist candidatura G3 aggiornata a GS-VER-035…081.
5. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI/Model e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
