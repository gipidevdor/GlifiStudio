<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Percorso produttivo Glifi Studio 0.1

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-001 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Scheda operativa dell'iniziatore del progetto |
| Riferimenti | GS-STD-001-07; RQ-063; GS-PROD-001; ADR-0002 |

## Unità di lavoro

Vertical slice UI Must su GlifiKit per il percorso produttivo 0.1 (progetto →
import → piano/esecuzione → query/KWIC → Findings/Evidence → indagine → export)
con ValidationManifest V0–V4 delle capability Must.

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Percorso Must end-to-end in app Shared DocumentGroup; esclusi PDF/OCR, CA/topic, sync, telemetria | — |
| requisiti | RF/RQ Must di GS-PROD/GS-API/GS-ANA/GS-DAT; accettazione: nessun placeholder nei flussi Must, V0–V4 per capability analitiche | — |
| contratto di dominio/API | Aggregate Project/Investigation via GlifiKit; ownership session; lifecycle create/open/close; package `.glifi` v1 | — |
| failure semantics | `GlifiStudioFailure` con messageKey, retryDisposition, retainedState; cancel esecuzione cooperativa | — |
| esperienza prevista | Sidebar Must, stati busy/failure, progresso import/esecuzione, a11y strutturale; studi VoiceOver dispositivo aperti (G4) | — |
| verifica | Test Core/Kit, `make quality-static`, ValidationManifest, evidenze GS-VER-035…052; `make verify` richiede Xcode | — |
| dati e migrazione | Package generazionale, InvestigationHistory append-only, export manifest; recovery power-loss reale aperta | — |
| sicurezza/privacy | Confini App→Kit→Core (CMP-001); zero rete/telemetria; input non fidati ancora fuzz incompleto (CMP-002) | — |
| prestazioni/sistema | ResourceBudget e admission; soglie hardware DA-011/CMP-021 aperte | — |
| tracciabilità | CMP-001/010/012 e manifesto Validation; matrice aggiornata nello stesso cambiamento | — |
| decisioni | ADR-0002 accettato; DA non bloccanti parcheggiati | — |

## Stato DoR

**Ready** per il coding della slice UI Must e dei ValidationManifest. I rischi G4/G5
(dispositivi, firma, budget Actions) hanno owner sull'iniziatore e non bloccano il
perimetro funzionale G3 candidato.

## Collegamenti

- Roadmap Fase 2: `docs/roadmap.md`
- Baseline prodotto: `docs/specifiche-di-design/10-product-baseline-mvp.md`
- Checklist candidatura G3: `docs/evidenze/GS-VER-057-checklist-candidatura-g3.md`
- Matrice: `Config/Compliance/specification-matrix.json`
- PR di riferimento: percorso produttivo 0.1
