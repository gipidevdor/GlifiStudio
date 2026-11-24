<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-070 — Popolazioni e frequenze relative keyness in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-070 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-044; GS-VER-067 |

## Ambito

Esporre le revisioni delle popolazioni target/reference, generazioni, diagnostica,
tolleranza assoluta e frequenze relative dei termini keyness nella UI Must.

## Controlli

1. Liste `targetSourceRevisionIDs` / `referenceSourceRevisionIDs` e
   `projectID`/`sourceGeneration` nella sezione keyness.
2. `diagnosticIdentifier`, `referenceAbsoluteTolerance`,
   `targetRelativeFrequency` / `referenceRelativeFrequency` visibili.
3. Checklist candidatura G3 aggiornata a GS-VER-035…070.
4. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
