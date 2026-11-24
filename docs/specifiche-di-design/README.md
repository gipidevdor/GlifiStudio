<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Specifiche di design implementativo

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DSG-IDX-001 |
| Tipo | Indice delle specifiche di design |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline proposta; da approvare al gate G1 |
| Riferimenti | GS-VIS-001; GS-SRS-001; GS-MET-001; GS-UX-001; GS-SEC-001; GS-API-001; GS-AD-001; ADR-0016; ADR-0019 |

## Scopo

Questa famiglia traduce la visione, i requisiti, i contratti scientifici e il
modello mentale in decisioni implementabili. Non aggiunge un secondo standard di
progetto e non replica formule o regole UX già governate altrove.

Ogni documento è normativo nel proprio ambito. Una modifica che altera un
contratto pubblico, un formato persistente, un risultato scientifico o un flusso
utente **DEVE** aggiornare nello stesso cambiamento requisiti, tracciabilità, ADR e
verifiche interessati.

## Mappa delle autorità

| Famiglia | Domanda a cui risponde | Non governa |
| --- | --- | --- |
| GS-VIS-001 | Perché esiste il prodotto e quale valore offre? | Strutture implementative |
| GS-PROD-001 | Che cosa rende completo il rilascio 0.1? | Semantica interna dei metodi |
| GS-SRS-001 | Quali obblighi deve soddisfare il sistema? | Soluzione tecnica dettagliata |
| GS-UX-001 | Quale modello mentale e progressione informativa offre? | Layout e tipi Swift concreti |
| GS-DOM-001 | Quali oggetti esistono e quali invarianti rispettano? | Formato fisico di salvataggio |
| GS-DAT-001 | Come entrano, si collegano, persistono e migrano i dati? | Significato matematico delle analisi |
| GS-LNG-001 | Che cosa significa elaborare correttamente l'italiano? | Scelta commerciale di un backend |
| GS-QRY-001 | Come si rappresenta ed esegue una ricerca riproducibile? | Ranking editoriale dei findings |
| GS-MET-001 | Che cosa significa scientificamente ogni metodo? | Scheduling e presentazione UI |
| GS-ANA-001 | Come si pianificano, identificano, riusano e interpretano le analisi? | Formule dei metodi |
| GS-RUN-001 | Come si esegue lavoro concorrente entro risorse finite? | Priorità scientifica dei risultati |
| GS-UI-001 | Come si naviga e interagisce concretamente su macOS e iPadOS? | Semantica epistemica |
| GS-VIZ-001 | Come diventano viste interrogabili gli artefatti scientifici? | Calcolo dell'artefatto sorgente |
| GS-VAL-001 | Come si dimostra la correttezza dell'implementazione? | Approvazione scientifica per autorità |
| GS-SEC-001 | Quali asset e trust boundary richiedono controlli e prove? | Semantica scientifica e design interno dei sottosistemi |
| GS-API-001 | Quale contratto condividono app, GlifiKit e CLI? | Formato fisico, formule e layout UI |
| GS-AD-001 | Quali componenti realizzano e collegano i contratti? | Motivazione di prodotto |

## Information item

| ID | Responsabilità | Documento |
| --- | --- | --- |
| GS-DOM-001 | Entità, identità, cardinalità, invarianti e lifecycle | [Modello del dominio](01-modello-del-dominio.md) |
| GS-DAT-001 | Documento, ingestion, lineage tecnico, package e persistenza | [Dati, lineage e persistenza](02-dati-lineage-e-persistenza.md) |
| GS-LNG-001 | Semantica linguistica operativa italiana | [Contratto linguistico italiano](03-contratto-linguistico-italiano.md) |
| GS-QRY-001 | AST, grammatica, semantica e limiti della ricerca | [Ricerca e linguaggio di query](04-ricerca-e-linguaggio-di-query.md) |
| GS-ANA-001 | Planner, DAG, invalidazione, interpretation e ranking | [Sistema analitico](05-sistema-analitico.md) |
| GS-RUN-001 | Task, concorrenza, memoria, I/O e pressione di sistema | [Runtime e risorse](06-runtime-e-risorse.md) |
| GS-UI-001 | Information architecture e interazione Apple-native | [Information architecture e interazione](07-information-architecture-e-interazione.md) |
| GS-VIZ-001 | Encoding, interazione, accessibilità ed export visuale | [Visualizzazione scientifica](08-visualizzazione-scientifica.md) |
| GS-VAL-001 | Oracoli, proprietà, corpus gold e tolleranze | [Validazione scientifica](09-validazione-scientifica.md) |
| GS-PROD-001 | Baseline 0.1, esclusioni e criteri di completezza | [Product baseline e MVP](10-product-baseline-mvp.md) |

## Ordine di implementazione

La dipendenza primaria è:

```text
GS-DOM → GS-DAT → GS-ANA → GS-UI → GS-RUN
    └──── GS-LNG → GS-QRY ─┘    └→ GS-VIZ
              tutti ─────────────→ GS-VAL → GS-PROD
```

L'ordine indica quando stabilizzare i contratti, non autorizza a implementare una
fase senza test. GS-PROD limita fin dall'inizio il sottoinsieme che deve diventare
software completo.

## Regola di conformità

Un'implementazione è conforme a questa famiglia soltanto quando:

- usa identità e invarianti GS-DOM, non tipi UI come modello del dominio;
- persiste esclusivamente attraverso il contratto GS-DAT;
- produce artefatti GS-MET attraverso pianificazione GS-ANA ed esecuzione GS-RUN;
- presenta gli stessi oggetti secondo GS-UX, GS-UI e GS-VIZ;
- attraversa input, log ed export secondo GS-SEC e offre operazioni condivise
  esclusivamente attraverso GS-API;
- supera le evidenze richieste da GS-VAL e i criteri di uscita GS-PROD.

Una parte non ancora implementata **DEVE** restare dichiarata come tale. La
completezza documentale non equivale alla completezza del prodotto.
