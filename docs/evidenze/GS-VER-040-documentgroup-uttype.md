<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-040 — DocumentGroup e UTType studio.glifi.project

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-040 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-APL-005; GS-DAT-001; GS-PROD-001 RF-001; GS-VER-035 |

## Ambito

Introdurre il ciclo document-based SwiftUI per package `.glifi` con UTType
`studio.glifi.project`, Info.plist document types e binding a GlifiKit.

## Controlli

1. `GlifiStudioDocument` (`FileDocument`) + `DocumentGroup` su macOS e iPadOS.
2. `Config/GlifiStudio-Info.plist` esporta `studio.glifi.project` conforme a package.
3. `attachDocument` crea o apre il package senza I/O GlifiCore nella View.
4. Entitlement bookmark app-scope per riapertura recente.
5. `make quality-static` sul tip.

## Risultato

**Superato** per dichiarazione e wiring document-based. Autosave/conflict multiwindow
e prove su file provider restano aperti (G4).

## Limiti

CI remota ancora soggetta a GS-WVR-004 (budget Actions).
