<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Codifica qualitativa nelle app

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-008 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready con rischio accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | ADR-0029 accettato dall'iniziatore (estensione documentata) |
| Riferimenti | GS-STD-001-07; ADR-0027; ADR-0029; GS-UX-001-16; RF-043; RF-044 |

## Unità di lavoro

| # | Task | Esito atteso |
| --- | --- | --- |
| U1 | Segmenti selezionabili | GlifiKit espone le frasi del testo estratto con i loro intervalli, come alternativa strutturata alla selezione |
| U2 | Sezione «Codifica» | Codebook, codifica per frase, elenco con ritiro e nota, accordo fra codificatori, secondo GS-UX-001-16 |
| U3 | Verifica e documenti | Test Kit, build macOS/iPadOS, localizzazione it/en, evidenza e tracciabilità |

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Interfaccia sulle operazioni GlifiKit esistenti; nessuna logica di dominio nelle app | — |
| requisiti | RF-043, RF-044, GS-UX-001-16 | — |
| contratto di dominio/API | Nuovo `textSegments(sourceRevisionID:)` in GlifiKit | — |
| failure semantics | Failure di GlifiKit presentate con chiave localizzata; storia cambiata → ricarica | — |
| esperienza prevista | GS-UX-001-16 | — |
| verifica | Test Kit dei segmenti; build delle app; controllo di localizzazione | — |
| dati e migrazione | Nessuna | — |
| sicurezza/privacy | Codificatori pseudonimi; nessun contenuto nei log | — |
| prestazioni/sistema | Segmenti calcolati su richiesta per una fonte | — |
| tracciabilità | Evidenza e aggiornamenti | — |
| decisioni | ADR-0029 | — |

## Stato DoR

**Ready con rischio accettato**: la validazione di accessibilità su dispositivo resta nel gate G4.

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| U1 | Completato | GS-VER-128 |
| U2 | Completato | GS-VER-128 |
| U3 | Completato | GS-VER-128 |
