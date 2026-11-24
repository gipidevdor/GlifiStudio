<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-058 — Ruolo e regione SourceReference in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-058 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-056 |

## Ambito

Esporre ruolo, regione e range byte delle `SourceReference` Evidence prima del
salto alla fonte.

## Controlli

1. UI Evidence: `roleIdentifier`, `regionIdentifier`, range UTF-8.
2. Indentazione Overview `open-project` corretta.
3. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
