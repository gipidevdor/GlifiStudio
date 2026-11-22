<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-044 — Confronto keyness diretto in UI Must

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-044 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-PROD-001 G3; GS-API-001; GS-ANA-001; GS-VER-023 |

## Ambito

Esporre `compareKeyness` nella UI Must quando l'intento è `compare.objects`,
con gruppi target/reference disgiunti e anteprima dei termini distintivi.

## Controlli

1. `StudioHomeModel.compareKeynessNow()` valida gruppi non vuoti e disgiunti,
   chiama GlifiKit e memorizza `lastKeyness`.
2. Pulsante `action.compare-keyness` e sezioni `keyness.*` localizzate `it`/`en`.
3. Failure `failure.keyness.missing-groups` e `failure.keyness.overlapping-groups`.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI. Runtime Xcode e validazione scientifica su dispositivo
restano aperti.

## Limiti

Budget Actions: GS-WVR-004. L'esecuzione via piano resta il percorso primario
di interpretazione Findings; il confronto diretto è esplorativo.
