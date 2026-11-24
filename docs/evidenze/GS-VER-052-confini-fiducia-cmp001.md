<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-052 — Confini di fiducia e CMP-001

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-052 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-SEC-001 § 5; GS-API-001; GS-VER-017 |

## Ambito

Promuovere CMP-001 a `implemented` documentando i confini App → GlifiKit →
GlifiCore e il controllo automatico `check-architecture.sh`.

## Controlli

1. App e GlifiCLI non importano `GlifiCore` direttamente.
2. Core/Kit/CLI non importano SwiftUI/AppKit/UIKit.
3. UI Must passa da `GlifiStudioService` / `ProjectSession`.
4. CMP-001 aggiornato; `make quality-static` sul tip.

## Risultato

**Superato** per confini strutturali e gate statico. Fuzz ostile e audit runtime
restano aperti (CMP-002).

## Limiti

Budget Actions: GS-WVR-004. Non prova parser ostili o recovery power-loss.
