<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Appartenenza indicizzata nella proiezione CA

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-206 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di ottimizzare ancora ogni aspetto |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-API-001; RF-033; RQ-009; RQ-028; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Evitare Array.contains per ogni riga/colonna durante la sola proiezione CA; due Set locali conservano appartenenza e ordine degli esclusi. |
| requisiti | RF-033, RQ-009, RQ-028, RQ-063; correttezza, compatibilità e provenienza invariate |
| contratto di dominio/API | Identico DTO completo e serializzazione; nessuna formula, asse, ordinamento, validazione, UI o stato scientifico nuovo. Set effimeri O(Ir+Ic), nessun dato persistente. |
| failure semantics | Nessun controllo indebolito o dato mutato; categorie, codici, retry e stato conservato invariati; nessuna nuova operazione async o I/O produttivo |
| esperienza prevista | Identici risultati e provenienza; nessuna modifica UI, localizzazione o accessibilità |
| verifica | Risultato Core preparato prima del timer, init Kit completo nella misura; forme piccole/grandi con densità diverse, inclusi riordinati/duplicati e controllo non-CA; uguaglianza completa e JSON canonico. Un warmup e sette campioni grezzi, preparazione/riferimenti/checksum fuori timer; GS-VER-206 candidata, revisione indipendente e make verify |
| dati e migrazione | Nessuno schema, backend, formato persistente o migrazione; dati sintetici deterministici |
| sicurezza/privacy | Nessuna rete, telemetria, privilegio o corpus reale; stringhe malformate e limiti nei test applicabili |
| prestazioni/sistema | Baseline Release prima delle patch produttive, fasi intermedie per contributi sovrapposti, hardware/OS/toolchain/termica/Low Power Mode e memoria dichiarati; nessuna soglia G4 nuova |
| tracciabilità | CMP-206 inizialmente specified; codice, test, evidenza e registri aggiornati insieme |
| decisioni e recupero | Decisione interna al lotto: supporto SwiftPM riservato ai test secondo GS-DOR-208, senza prodotto né dipendenza esterna; nessuna scelta architetturale del prodotto nuova. Ripristino per revert puntuale |

**Ready** prima del coding. Le modifiche produttive attendono la baseline.
Il supporto dei test è preparato e congelato prima di tutte le misure.
