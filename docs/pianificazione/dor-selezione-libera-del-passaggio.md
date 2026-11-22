<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Selezione libera del passaggio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-009 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready con rischio accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-UX-001-16 § Accessibilità (ADR-0029 accettato); nessuna nuova decisione di prodotto |
| Riferimenti | GS-STD-001-07; GS-API-001; GS-UX-001-16; ADR-0027; ADR-0029; RF-043 |

## Unità di lavoro

| # | Task | Esito atteso |
| --- | --- | --- |
| U1 | Selezione strutturata nel motore | `GlifiPassageSelection` per frasi, caratteri e byte risolta in un intervallo allineato ai confini di carattere |
| U2 | Parità GlifiKit e CLI | `passage`, `passages`, `extractedCharacterCount`; `glifi qualitative segments|passage` |
| U3 | Sezione «Codifica» nelle app | Scelta della modalità, anteprima del passaggio risolto, testo delle codifiche registrate |
| U4 | Verifica e documenti | Test Kit, contract test CLI, build macOS/iPadOS, localizzazione it/en, evidenza e tracciabilità |

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Risoluzione di una selezione in un intervallo; nessun cambiamento del modello della storia qualitativa | — |
| requisiti | RF-043, GS-UX-001-16 § Flussi e § Accessibilità | — |
| contratto di dominio/API | `passage`, `passages`, `extractedCharacterCount` in GS-API-001 § 9.3 | — |
| failure semantics | `qualitative.invalid-selection` (`invalidInput`, `afterCorrection`, `unchanged`); la forma multipla fallisce per intero | — |
| esperienza prevista | GS-UX-001-16 § Flussi, punto 2 e punto 3 | — |
| verifica | Test Kit della selezione; contract test CLI; build delle app; controllo di localizzazione | — |
| dati e migrazione | Nessuna: gli intervalli registrati non cambiano formato | — |
| sicurezza/privacy | Nessun contenuto nei log; il testo risolto resta nel processo | — |
| prestazioni/sistema | Il testo estratto è letto una volta per elenco di selezioni | — |
| tracciabilità | GS-VER-129, matrice di conformità, tracciabilità | — |
| decisioni | Nessuna nuova: l'alternativa strutturata è già prescritta da GS-UX-001-16 | — |

## Stato DoR

**Ready con rischio accettato**: la selezione diretta sul testo con il puntatore e la validazione
di accessibilità su dispositivo restano fuori perimetro (gate G4).

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| U1 | Completato | GS-VER-129 |
| U2 | Completato | GS-VER-129 |
| U3 | Completato | GS-VER-129 |
| U4 | Completato | GS-VER-129 |
