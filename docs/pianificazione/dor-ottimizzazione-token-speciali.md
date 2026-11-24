<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riuso dei confini dei token speciali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-203 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di ottimizzare ancora ogni aspetto |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-LNG-001; RF-079; RF-009; RQ-009; RQ-011; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Evitare le scansioni ripetute del suffisso senza spazi per email e URL, conservando integralmente il contratto it-token-v1. |
| requisiti | RF-079, RF-009, RQ-009, RQ-011, RQ-063; correttezza e compatibilità prima delle prestazioni |
| contratto di dominio/API | Metadati locali di fine sequenza e delimitatori finali; nessuna euristica che escluda email o URL legacy, nessun cambiamento di superficie, componenti, coordinate o frasi; checkpoint di cancellazione prima e durante la preparazione lunga. |
| failure semantics | Categorie e stato conservato invariati; nessuna scrittura nuova o risultato parziale; cancellazione applicabile preservata |
| esperienza prevista | Identici risultati e provenienza; componente headless, nessuna modifica UI o a localizzazione/accessibilità |
| verifica | Punteggiatura senza spazi di taglia crescente, controllo di prosa Unicode e token email/URL; riferimento del tokenizer precedente su casi ostili e generati a seed fisso, gold italiano, cancellazione. Baseline prima della patch, Release, un warmup e sette campioni grezzi, input/output confrontati fuori timer; GS-VER-203 candidata e make verify completo |
| dati e migrazione | Nessun nuovo formato, schema, migrazione o modifica di dati esistenti; soltanto strutture effimere locali |
| sicurezza/privacy | Solo dati sintetici deterministici, nessuna rete, privilegio, dipendenza o log di corpus; input avversari nei test |
| prestazioni/sistema | Conservare soltanto il beneficio osservato e dichiarare costo di preparazione, memoria, cache, termica e risparmio energetico; nessuna soglia G4 o promessa end-to-end nuova |
| tracciabilità | CMP-203 inizialmente specified; codice, regressioni, misure, evidenza e registri aggiornati nello stesso lotto |
| decisioni e recupero | Contratto vigente e ADR applicabili conservati; nessuna scelta architetturale nuova, rollback per revert puntuale |

**Ready** prima del coding. Il codice produttivo resta fermo fino alla baseline.
La revisione indipendente verifica anche equivalenza e limiti delle misure.
