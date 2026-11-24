# 6. Ciclo di vita e gate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-06 |
| Tipo | Capitolo normativo |
| Versione | 0.2.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

Il progetto usa sviluppo iterativo. I gate non impongono un modello a cascata: stabiliscono le evidenze minime necessarie per procedere consapevolmente.

| Gate | Obiettivo | Evidenze minime | Autorità |
| --- | --- | --- | --- |
| G0 — Avvio | Autorizzare l'esplorazione | Visione, stakeholder candidati, rischi iniziali, responsabili | Product owner |
| G1 — Baseline requisiti | Definire ciò che una slice deve ottenere | Requisiti verificabili, GS-PROD, dieci specifiche GS-DSG, priorità, tracciabilità e criteri | Product owner e responsabile requisiti |
| G2 — Baseline architettura | Autorizzare l'implementazione strutturale | View, ADR, vertical prototype `.glifi`/SpanMap/QueryAST/DAG/runtime, scenari di qualità | Responsabile architettura |
| G3 — Ready for integration | Integrare una modifica | Code review, test, documentazione, controlli automatici verdi | Maintainer e responsabile qualità |
| G4 — Release candidate | Congelare il candidato | Tracciabilità completa, test di sistema, benchmark, security review, note bozza | Responsabile qualità |
| G5 — Release | Pubblicare | Artefatto firmato, checklist, note, migrazioni, rollback, approvazione | Responsabile rilascio e product owner |
| G6 — Ritiro | Terminare supporto o formato | Piano dati, compatibilità, comunicazione e archiviazione | Product owner e maintainer |

Un gate fallito **NON DEVE** essere aggirato modificando o eliminando l'evidenza. Il rilascio può procedere soltanto con non conformità risolta o deroga approvata.
