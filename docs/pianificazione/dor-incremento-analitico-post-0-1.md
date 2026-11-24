<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Programma dell'incremento analitico post-0.1

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-002 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.0 |
| Stato | Ready con rischio accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Programma richiesto dall'iniziatore del progetto |
| Riferimenti | GS-STD-001-07; ADR-0025; ADR-0026; GS-UX-004; GS-UX-006; RF-043 |

## Unità di lavoro

Programma che porta le famiglie ADR-0025 dal calcolo verificato all'uso completo: findings
interpretati con le policy ADR-0026, documentazione normativa allineata, backend scalabili per CA
e PCA, presentazione nelle app e decisione sul codebook. Ogni task è un incremento con evidenza
GS-VER propria, `make verify` verde e commit separato.

| # | Task | Esito atteso | Dipendenze |
| --- | --- | --- | --- |
| P1 | Findings delle famiglie estese | payload estesi passati all'interprete; Evidence e Finding content-addressed con classe ADR-0026 | ADR-0026 |
| P2 | Allineamento documentale | GS-ANA-001, GS-UX-006, GS-API-001 e roadmap descrivono planner-v2, policy e operazioni estese | P1 |
| P3 | CA e PCA oltre il limite denso | SVD troncata per CA/PCA con backend dichiarato, verificata contro R | GS-VER-108 |
| P4 | Presentazione nelle app | viste GlifiKit→SwiftUI per risultati e findings estesi secondo GS-UX-004 | P1 |
| P5 | Codebook e codifiche (RF-043) | ADR dedicato prima di qualunque modello persistito | decisione dell'iniziatore |

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | P1–P4 implementabili; P5 limitato alla proposta di ADR; baseline 0.1 invariata (ADR-0025) | — |
| requisiti | RF-032…RF-045, RF-055, GS-UX-006; accettazione: nessuna etichetta senza policy ADR-0026 | — |
| contratto di dominio/API | Operazioni persistite esistenti e interprete `interpretation-rules`; parità GlifiKit/CLI mantenuta | — |
| failure semantics | Risultati non eleggibili → `insufficient` con motivo; famiglie senza regole → `interpretation.family-without-rules` | — |
| esperienza prevista | Findings con classe, dimensioni e motivi apribili (GS-UX-006); viste P4 accessibili | — |
| verifica | Test Core/Kit con valori a mano e oracoli (`make check-oracles`, `make check-pdfa`), `make verify` | — |
| dati e migrazione | Nuovi nodi DAG versionati; nessuna migrazione del package per P1–P3 | — |
| sicurezza/privacy | Nessuna rete o telemetria; confini App→Kit→Core invariati | — |
| prestazioni/sistema | Backend scalabili (GS-VER-108/109); limiti bounded dichiarati | — |
| tracciabilità | Ogni task aggiorna evidenze, requisiti, tracciabilità, matrice e CHANGELOG nello stesso commit | — |
| decisioni | ADR-0025 e ADR-0026 accettati; P5 richiede un nuovo ADR | — |

## Stato DoR

**Ready con rischio accettato** per P1–P4: il rischio è la validazione empirica delle soglie
ADR-0026, rinviata a G4. P5 non è Ready per il coding finché il suo ADR non è accettato.

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| P1 | Completato | GS-VER-111 |
| P2 | Completato | GS-API-001 1.14.0, GS-ANA-001 1.7.0, GS-UX-006 1.2.0, roadmap |
| P3 | Completato | GS-VER-112 |
| P4 | Completato | GS-VER-113 (intenzioni e findings nelle app); GS-VER-114 (viste dedicate); audit su dispositivo in G4 |
| P5 | Decisione presa | [ADR-0027](../adr/0027-codebook-e-codifiche-persistite.md) accettato (opzione 2); implementazione in GS-DOR-007 |

## Collegamenti

- Decisioni: [ADR-0025](../adr/0025-estensione-analitica-planner-v2.md),
  [ADR-0026](../adr/0026-policy-di-supporto-per-famiglia.md)
- Evidenze di partenza: `docs/evidenze/GS-VER-106-planner-v2-capability-estese.md`,
  `docs/evidenze/GS-VER-110-policy-di-supporto-adr-0026.md`
- Matrice: `Config/Compliance/specification-matrix.json`
