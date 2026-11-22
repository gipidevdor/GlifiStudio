<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-061 — CollectionPlanningProfile e decisioni piano in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-061 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-027 |

## Ambito

Esporre in UI Must il CollectionPlanningProfile, gli step con costo, le decisioni
di capability e l'Artifact piano anche nel risultato di esecuzione.

## Controlli

1. Sezioni `plan.collection-profile`, `plan.steps`, `plan.decisions`,
   `plan.unresolved`.
2. Execution: `execution.plan-artifact`.
3. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
