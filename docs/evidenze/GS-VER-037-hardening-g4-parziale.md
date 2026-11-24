<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-037 — Hardening recovery, a11y strutturale e candidatura G4

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-037 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato parzialmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-PROD-001 G4; GS-DAT-001; GS-UX-001-13 |

## Ambito

Estendere le prove di recovery package/export e fissare la checklist a11y
strutturale sul flusso Must.

## Controlli eseguiti

1. Test aggiuntivo di kill/corruption su export incompleto (Core).
2. Label/hint/header accessibilità sulle sezioni Must della UI condivisa.
3. Checklist G4 documentata in `docs/esperienza-utente/15-checklist-g4-accessibilita.md`.

## Risultato

**Parziale**: recovery Artifact/commit già coperta; export incompleto rifiutato in
riapertura; a11y strutturale presente. **Non** eseguiti VoiceOver su dispositivo,
benchmark energia né TestFlight.

## Limiti

- CMP-019 e CMP-021 restano blocked fino a sessioni reali.
- G4 non dichiarato chiuso.
