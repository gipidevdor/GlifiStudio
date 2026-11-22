<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Supporto condiviso dei benchmark dei test

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-208 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di ottimizzare ancora ogni aspetto |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-STD-001-17; RQ-009; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Riutilizzare lo stesso harness di misura per test Core e Kit attraverso un target interno, evitando copie divergenti del protocollo. |
| requisiti | RQ-009, RQ-063; correttezza, compatibilità e provenienza invariate |
| contratto di dominio/API | Target GlifiBenchmarkTestSupport sotto Tests, senza product; soltanto i due test target dipendono dal supporto. Migrare il helper esistente preservando comportamento e protocolli delle prove GS202/203/204. Nessuna dipendenza esterna o API del prodotto nuova. |
| failure semantics | Nessun controllo indebolito o dato mutato; categorie, codici, retry e stato conservato invariati; nessuna nuova operazione async o I/O produttivo |
| esperienza prevista | Identici risultati e provenienza; nessuna modifica UI, localizzazione o accessibilità |
| verifica | Verificare grafo delle dipendenze SwiftPM e assenza del target nei percorsi dei prodotti, Release con testability e filtro seriale; regressioni precedenti e nuove, guard Debug, make verify completo. Un warmup e sette campioni grezzi, preparazione/riferimenti/checksum fuori timer; GS-VER-208 candidata, revisione indipendente e make verify |
| dati e migrazione | Nessuno schema, backend, formato persistente o migrazione; dati sintetici deterministici |
| sicurezza/privacy | Nessuna rete, telemetria, privilegio o corpus reale; stringhe malformate e limiti nei test applicabili |
| prestazioni/sistema | Baseline Release prima delle patch produttive, fasi intermedie per contributi sovrapposti, hardware/OS/toolchain/termica/Low Power Mode e memoria dichiarati; nessuna soglia G4 nuova |
| tracciabilità | CMP-208 inizialmente specified; codice, test, evidenza e registri aggiornati insieme |
| decisioni e recupero | Decisione interna al lotto: supporto SwiftPM riservato ai test secondo GS-DOR-208, senza prodotto né dipendenza esterna; nessuna scelta architetturale del prodotto nuova. Ripristino per revert puntuale |

**Ready** prima del coding. Le modifiche produttive attendono la baseline.
Il supporto dei test è preparato e congelato prima di tutte le misure.
