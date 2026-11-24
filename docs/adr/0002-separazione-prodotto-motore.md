<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0002 — Separazione tra prodotto e motore

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0002 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-16 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Baseline candidata dagli appunti iniziali; struttura SPM e gate architetturale |
| Sostituisce | Nessuno |

## Contesto

Le stesse capacità computazionali devono servire l'app interattiva, test automatici,
benchmark, elaborazioni batch e la CLI. Incorporare la logica scientifica nella GUI
renderebbe difficile verificarla, riutilizzarla ed evolverla.

La struttura del repository realizza già tre target distinti (`Glifi Studio` →
`GlifiKit` → `GlifiCore`) con product SPM separati e un controllo automatico che
impedisce alle app di importare `GlifiCore` direttamente.

## Decisione

Il prodotto interattivo e il motore computazionale sono componenti distinti:

```text
Glifi Studio → GlifiKit → GlifiCore
```

`Glifi Studio` gestisce presentazione e interazione per macOS e iPadOS. `GlifiKit`
espone un contratto applicativo piccolo, pre-1.0 e progettato per stabilizzarsi
secondo GS-API-001; la visibilità Swift `public` non promette ancora ABI o SDK
binario. `GlifiCore` implementa importazione, trasformazioni, indicizzazione,
ricerca e analisi senza dipendere da SwiftUI, AppKit o UIKit.

La separazione è imposta dalla struttura di target e package e verificata
automaticamente da `Scripts/check-architecture.sh`.

## Alternative considerate

- logica applicativa incorporata nel target GUI;
- motore separato senza livello API stabile;
- separazione a tre livelli Glifi Studio, GlifiKit e GlifiCore.

La terza alternativa è adottata perché sostiene riuso headless e controllo delle
dipendenze.

## Conseguenze

- La GUI è un client del motore e non duplica logica analitica.
- CLI, test headless e benchmark condividono GlifiCore/GlifiKit.
- I modelli esposti richiedono contract test e una politica di compatibilità
  prima della stabilizzazione 1.0.
- Alcuni tipi di presentazione sono adattati ai modelli del dominio al confine
  GlifiKit senza attraversare direttamente i confini interni di GlifiCore.
