<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-035 — Vertical slice UI Must sul Kit

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-035 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente (compilazione/statica); runtime Xcode richiesto |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-PROD-001; GS-PLAN-001 Fase 2; ADR-0002; ADR-0014 |

## Ambito

Registrare l'integrazione del percorso Must nella UI condivisa macOS/iPadOS come
client esclusivo di GlifiKit.

## Controlli

1. `Apps/Shared/StudioHomeModel.swift` orchestra create/open, import, plan, execute,
   investigation, query ed export senza importare GlifiCore.
2. `Apps/Shared/StudioHomeView.swift` espone sezioni Progetto, Fonti, Indagine,
   Ricerca, Findings ed Esporta con chiavi localizzate `it`/`en` e trait
   accessibilità di base.
3. Gate architetturale invariato: le app dipendono solo da GlifiKit.

## Risultato

**Superato** per il wiring Must verso il Kit. Non sostituisce audit VoiceOver su
dispositivo, UI test automatici o studi UX (CMP-019 / DA-026).

## Limiti

- Conflict handling multiwindow e provider di file restano da validare su dispositivo (G4).
- `make verify` / xcodebuild non eseguibili in questo ambiente cloud Linux.
