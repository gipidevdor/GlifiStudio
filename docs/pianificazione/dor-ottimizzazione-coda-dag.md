<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Coda ordinata del DAG analitico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-205 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di ottimizzare ancora ogni aspetto |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-ANA-001; RQ-009; RQ-023; RQ-024; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Sostituire removeFirst e ordinamenti ripetuti dei nodi pronti con un min-heap privato; mantenere esattamente Kahn e lo spareggio per AnalysisNodeID. Confrontare i digest già memorizzati anziché interpolare prefissi identici nel solo ordinamento tipizzato. |
| requisiti | RQ-009, RQ-023, RQ-024, RQ-063; correttezza, compatibilità e provenienza invariate |
| contratto di dominio/API | Identici nodi, ordine topologico, Codable, limiti, diagnostica, invalidazione e riuso. Nessuna cache di digest, API o dipendenza produttiva nuova. |
| failure semantics | Nessun controllo indebolito o dato mutato; categorie, codici, retry e stato conservato invariati; nessuna nuova operazione async o I/O produttivo |
| esperienza prevista | Identici risultati e provenienza; nessuna modifica UI, localizzazione o accessibilità |
| verifica | Grafi validi indipendenti, star, multilivello e catena; nodi e descrittori preparati fuori timer; confronto completo con Kahn scalare, permutazioni, round-trip e failure esistenti. Misurare prima senza le modifiche digest GS207, poi la combinazione. Un warmup e sette campioni grezzi, preparazione/riferimenti/checksum fuori timer; GS-VER-205 candidata, revisione indipendente e make verify |
| dati e migrazione | Nessuno schema, backend, formato persistente o migrazione; dati sintetici deterministici |
| sicurezza/privacy | Nessuna rete, telemetria, privilegio o corpus reale; stringhe malformate e limiti nei test applicabili |
| prestazioni/sistema | Baseline Release prima delle patch produttive, fasi intermedie per contributi sovrapposti, hardware/OS/toolchain/termica/Low Power Mode e memoria dichiarati; nessuna soglia G4 nuova |
| tracciabilità | CMP-205 inizialmente specified; codice, test, evidenza e registri aggiornati insieme |
| decisioni e recupero | Decisione interna al lotto: supporto SwiftPM riservato ai test secondo GS-DOR-208, senza prodotto né dipendenza esterna; nessuna scelta architetturale del prodotto nuova. Ripristino per revert puntuale |

**Ready** prima del coding. Le modifiche produttive attendono la baseline.
Il supporto dei test è preparato e congelato prima di tutte le misure.
