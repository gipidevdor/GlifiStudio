<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Indice locale dei riferimenti Evidence nel CSV

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-204 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di ottimizzare ancora ogni aspetto |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; ADR-0023; RQ-009; RQ-040; RQ-044; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Eliminare la scansione di tutti i Finding per ogni Evidence durante la preparazione del CSV scientifico. |
| requisiti | RQ-009, RQ-040, RQ-044, RQ-063; correttezza e compatibilità prima delle prestazioni |
| contratto di dominio/API | Indice inverso locale EvidenceID verso FindingID in ordine originale; deduplicare esclusivamente riferimenti alla stessa Evidence entro il singolo Finding, conservando la semantica contains. Identici byte CSV, JSON canonico, escape, CRLF, protezione formula e verifica export. |
| failure semantics | Categorie e stato conservato invariati; nessuna scrittura nuova o risultato parziale; cancellazione applicabile preservata |
| esperienza prevista | Identici risultati e provenienza; componente headless, nessuna modifica UI o a localizzazione/accessibilità |
| verifica | Report sintetici con molti Finding/Evidence, riferimento lineare e confronto di tutti i byte; casi riferimenti ripetuti, assenti e condivisi, ordine, Unicode e caratteri CSV; PDF/A e verifica export restano nel gate. Baseline prima della patch, Release, un warmup e sette campioni grezzi, input/output confrontati fuori timer; GS-VER-204 candidata e make verify completo |
| dati e migrazione | Nessun nuovo formato, schema, migrazione o modifica di dati esistenti; soltanto strutture effimere locali |
| sicurezza/privacy | Solo dati sintetici deterministici, nessuna rete, privilegio, dipendenza o log di corpus; input avversari nei test |
| prestazioni/sistema | Conservare soltanto il beneficio osservato e dichiarare costo di preparazione, memoria, cache, termica e risparmio energetico; nessuna soglia G4 o promessa end-to-end nuova |
| tracciabilità | CMP-204 inizialmente specified; codice, regressioni, misure, evidenza e registri aggiornati nello stesso lotto |
| decisioni e recupero | Contratto vigente e ADR applicabili conservati; nessuna scelta architetturale nuova, rollback per revert puntuale |

**Ready** prima del coding. Il codice produttivo resta fermo fino alla baseline.
La revisione indipendente verifica anche equivalenza e limiti delle misure.
