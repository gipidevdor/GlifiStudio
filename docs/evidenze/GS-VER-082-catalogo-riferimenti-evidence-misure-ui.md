<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-082 — Catalogo riferimenti Evidence e tipi misura in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-082 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-047; GS-VER-056 |

## Ambito

Esporre l'elenco completo di `GlifiStudioFindingEvidenceReference` del Finding
selezionato e tipizzare le misure Evidence (`type` / `unitIdentifier`).

## Controlli

1. Sezione `finding.evidence-references` con conteggio, ID, disposition e reason.
2. Ogni misura mostra tipo scalare e unità oltre al valore renderizzato.
3. Checklist candidatura G3 aggiornata a GS-VER-035…080.
4. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
