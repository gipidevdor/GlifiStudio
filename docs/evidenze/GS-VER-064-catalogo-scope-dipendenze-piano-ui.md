<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-064 — Catalogo, scope e dipendenze del piano in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-064 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-061 |

## Ambito

Completare la trasparenza del piano Must in UI: catalogo capability, nodo di
analisi, generazioni, scope risolto/target/reference, classe di osservazione,
byte per formato, dipendenze e caveat degli step, backend/fallback/caveat delle
decisioni.

## Controlli

1. Sezioni `plan.title` / `plan.scope` / `plan.collection-profile` / `plan.steps`
   / `plan.decisions` aggiornate con i campi Kit sopra.
2. Helper `revisionIDList` per elenchi di `sourceRevisionID` truncati.
3. Chiavi `plan.*` localizzate `it`/`en`.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
