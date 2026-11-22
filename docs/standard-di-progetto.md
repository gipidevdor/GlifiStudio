# Standard di progetto Glifi Studio

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001 |
| Tipo | Indice normativo e standard interno di ingegneria del software |
| Versione | 0.11.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-18 |
| Autorità di approvazione | Da assegnare |
| Data di emissione | 2026-09-15 |
| Data di efficacia | All'approvazione |
| Riesame | Annuale o a ogni modifica sostanziale del prodotto |
| Approvazione | Non ancora approvato |
| Classificazione | Interno al progetto |
| Sostituisce | Versione monolitica 0.4.0 |

## Funzione dell'indice

Questo documento è il punto di ingresso normativo dello standard Glifi Studio. Ogni argomento è mantenuto in un documento autonomo, con identificatore e stato propri. L'insieme dell'indice e dei documenti elencati costituisce GS-STD-001.

Finché lo stato è `Proposto`, lo standard costituisce una baseline normativa candidata. Dopo l'approvazione, ogni elemento nel campo di applicazione deve rispettarlo oppure disporre di una deroga valida.

## Fondamenti e governo

| ID | Documento |
| --- | --- |
| GS-STD-001-01 | [1. Scopo](standard/01-scopo.md) |
| GS-STD-001-02 | [2. Campo di applicazione](standard/02-campo-di-applicazione.md) |
| GS-STD-001-03 | [3. Stato normativo e conformità](standard/03-stato-normativo-e-conformita.md) |
| GS-STD-001-04 | [4. Linguaggio normativo](standard/04-linguaggio-normativo.md) |
| GS-STD-001-05 | [5. Governo e responsabilità](standard/05-governo-e-responsabilita.md) |
| GS-STD-001-06 | [6. Ciclo di vita e gate](standard/06-ciclo-di-vita-e-gate.md) |
| GS-STD-001-07 | [7. Pianificazione e gestione del lavoro](standard/07-pianificazione-e-gestione-del-lavoro.md) |
| GS-STD-001-08 | [8. Gestione della configurazione](standard/08-gestione-della-configurazione.md) |

## Progettazione e implementazione

| ID | Documento |
| --- | --- |
| GS-STD-001-09 | [9. Ingegneria dei requisiti](standard/09-ingegneria-dei-requisiti.md) |
| GS-STD-001-10 | [10. Architettura e design](standard/10-architettura-e-design.md) |
| GS-STD-001-11 | [11. Dati, testo e persistenza](standard/11-dati-testo-e-persistenza.md) |
| GS-STD-001-12 | [12. Implementazione Swift](standard/12-implementazione-swift.md) |
| GS-STD-001-13 | [13. Dipendenze e supply chain](standard/13-dipendenze-e-supply-chain.md) |
| GS-STD-001-14 | [14. Sicurezza e privacy](standard/14-sicurezza-e-privacy.md) |
| GS-STD-001-15 | [15. Interfaccia, accessibilità e localizzazione](standard/15-interfaccia-accessibilita-e-localizzazione.md) |

## Fondazione scientifica

| ID | Documento |
| --- | --- |
| GS-MET-001 | [Specifica normativa dei metodi analitici](metodi-analitici/README.md) |

GS-MET-001 è normativa per semantica matematica, statistica, linguistica e
algoritmica. I capitoli dello standard disciplinano il processo con cui tali metodi
sono progettati, implementati e verificati.

## Fondazione dell'esperienza

| ID | Documento |
| --- | --- |
| GS-UX-001 | [Specifica dell'esperienza utente](esperienza-utente/README.md) |

GS-UX-001 è normativa per modello mentale, intenzioni, indagine, pianificazione,
catena epistemica, navigazione e validazione human-centred. Non sostituisce GS-MET
né i profili Apple: ne disciplina l'esposizione coerente alle persone.

## Specifiche di design implementativo

| ID | Documento |
| --- | --- |
| GS-DSG-IDX-001 | [Dominio, dati, lingua, query, analisi, runtime, UI, visualizzazione, validazione e prodotto](specifiche-di-design/README.md) |

La famiglia GS-DSG traduce requisiti, GS-MET e GS-UX in contratti implementabili.
La mappa delle autorità dell'indice impedisce che una specifica ridefinisca formule,
modello mentale o regole di processo governate da altri documenti.

## Contratti trasversali

| ID | Documento |
| --- | --- |
| GS-SEC-001 | [Threat model e architettura di sicurezza](sicurezza/README.md) |
| GS-API-001 | [Contratto GlifiKit e GlifiCLI](api/README.md) |

GS-SEC governa asset, trust boundary e trattamento degli input non fidati sopra
ogni sottosistema. GS-API governa il confine presentation-independent e headless;
non sostituisce i contratti di dominio, dati, analisi o runtime.

## Qualità e operazioni

| ID | Documento |
| --- | --- |
| GS-STD-001-16 | [16. Strategia di verifica e test](standard/16-strategia-di-verifica-e-test.md) |
| GS-STD-001-17 | [17. Benchmark e regressioni prestazionali](standard/17-benchmark-e-regressioni-prestazionali.md) |
| GS-STD-001-18 | [18. Errori, logging e osservabilità](standard/18-errori-logging-e-osservabilita.md) |
| GS-STD-001-19 | [19. Documentazione](standard/19-documentazione.md) |
| GS-STD-001-20 | [20. Integrazione continua e quality gate](standard/20-integrazione-continua-e-quality-gate.md) |
| GS-STD-001-21 | [21. Rilascio e distribuzione](standard/21-rilascio-e-distribuzione.md) |
| GS-STD-001-22 | [22. Manutenzione e compatibilità](standard/22-manutenzione-e-compatibilita.md) |
| GS-STD-001-23 | [23. Problemi, rischi e incidenti](standard/23-problemi-rischi-e-incidenti.md) |
| GS-STD-001-24 | [24. Deroghe e non conformità](standard/24-deroghe-e-non-conformita.md) |
| GS-STD-001-25 | [25. Definition of Done](standard/25-definition-of-done.md) |
| GS-STD-001-26 | [26. Misure e audit](standard/26-misure-e-audit.md) |
| GS-STD-001-27 | [27. Struttura del repository](standard/27-struttura-del-repository.md) |
| GS-STD-001-28 | [28. Stato di adozione](standard/28-stato-di-adozione.md) |
| GS-STD-001-29 | [29. Eccellenza ingegneristica di classe Apple](standard/29-eccellenza-ingegneristica-apple.md) |

## Modelli operativi

| ID | Documento |
| --- | --- |
| GS-STD-001-A | [Appendice A — Modello di requisito](standard/appendice-a-modello-di-requisito.md) |
| GS-STD-001-B | [Appendice B — Modello di ADR](standard/appendice-b-modello-di-adr.md) |
| GS-STD-001-C | [Appendice C — Modello di evidenza](standard/appendice-c-modello-di-evidenza.md) |
| GS-STD-001-D | [Appendice D — Modello di deroga](standard/appendice-d-modello-di-deroga.md) |
| GS-STD-001-E | [Appendice E — Checklist di rilascio](standard/appendice-e-checklist-di-rilascio.md) |

## Regola di manutenzione

Una modifica deve interessare soltanto i documenti pertinenti e aggiornare nella stessa unità di cambiamento indice, riferimenti, requisiti, ADR, matrice di conformità ed evidenze coinvolti. Lo spostamento di testo tra documenti non ne modifica da solo il significato normativo.
