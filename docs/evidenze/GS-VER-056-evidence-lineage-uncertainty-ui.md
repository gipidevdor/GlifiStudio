<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-056 — Lineage Evidence, uncertainty ed effect size in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-056 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-030; GS-VER-055 |

## Ambito

Completare la trasparenza Evidence in UI Must con lineage (nodo/Artifact),
classe epistemica, contratti di uncertainty/effect size e Caveat tipizzati.

## Controlli

1. Dettaglio Evidence: `epistemicCategory`, `analysisNodeID`, `artifactIDs`,
   `uncertaintyIdentifiers`, `effectSizeIdentifiers`.
2. Caveat Evidence con severità (helper condiviso).
3. Finding: `ruleSetIdentifier` nel dettaglio proposizione.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
