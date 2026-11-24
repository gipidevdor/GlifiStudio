<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-060 — Caveat strutturati e Artifact piano in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-060 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-054 |

## Ambito

Esporre causa/conseguenza/azione/origine/scope dei Caveat e l'`artifactID` del
piano nella UI Must.

## Controlli

1. `caveatRow` mostra severity, scope, cause, consequence, action, origin.
2. Sezione piano: `plan.artifact` selezionabile.
3. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
