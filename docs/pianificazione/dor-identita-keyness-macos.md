<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Identità e limiti del riuso keyness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-199 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.1.1 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Difetto concreto confermato durante GS-DOR-198; correzione dei metadati e dell'admission al riuso autorizzata |
| Riferimenti | RF-011; RF-031; RQ-003; RQ-024; RQ-058; GS-MET-001-08; GS-ANA-001; GS-DOR-198 |

## Problema

La factory del descrittore keyness registra la soglia diagnostica ma non
`confidenceLevel`; la validazione del risultato riusabile non controlla il
livello né il limite della famiglia. Una richiesta con livello diverso può
quindi riusare intervalli precedenti e un budget ridotto può ammettere una
famiglia già materializzata che lo supera. È una dipendenza di correttezza
dell'incremento E, non un nuovo metodo statistico.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Aggiungere il livello di confidenza risolto all'identità del descrittore keyness e applicare livello e limite della famiglia anche al risultato riusato; solo factory/validazione dell'esecuzione, nessuna formula o migrazione |
| requisiti | RF-011/RF-031 e RQ-003/024/058; richiesta distinta produce nodo distinto, riuso semanticamente compatibile e budget rispettato prima della restituzione |
| dominio/API | `GlifiAnalysisArtifacts.keyness` include `confidenceLevel` nei parametri risolti; `validatePlannedKeyness` confronta livello del risultato con la richiesta e verifica `terms.count <= maximumHypothesisCount` anche sul percorso di riuso |
| failure semantics | Livello difforme usa la failure esistente `keyness.descriptor-result-mismatch`; famiglia oltre budget usa `keyness.hypothesis-limit-exceeded` con categoria `insufficientResources` e tassonomia esistente; nessuna modifica del progetto per il rifiuto di un risultato riusato |
| esperienza prevista | Il client riceve intervalli del livello effettivamente richiesto oppure una failure; nessun riuso silenzioso del livello precedente e nessun bypass del limite richiesto; presentazione e messaggi applicativi appartengono a GS-DOR-198 |
| verifica | Due regressioni Core con RED prima del fix: richiesta 0,95 poi 0,80 deve produrre livello/nodo corretti e ripetizione riusabile; famiglia già calcolata oltre un successivo limite ridotto deve fallire con il codice previsto, mentre un budget maggiore compatibile riusa il risultato. Due ulteriori prove GREEN: payload con livello difforme sotto un vero nodo del livello richiesto rifiutato dal guard senza mutazione della generazione; Artifact con descrittore legacy privo del livello leggibile dopo riapertura e nuova richiesta con nodo corretto senza riscrittura del legacy. Verifica di generazioni e identità; gate/preflight del nuovo lotto macOS, GS-VER-199 candidata |
| dati e migrazione | Nessun cambio dello schema Artifact o del formato package; Artifact keyness v2 con livello nel payload e descrittore precedente privo del parametro restano leggibili e conservati. I descrittori nuovi includono il livello, quindi le analisi precedenti senza quel parametro possono essere ricalcolate con nuovo nodo; nessuna riscrittura retroattiva |
| sicurezza/privacy | Nessuna rete, dipendenza, entitlement, sorgente o dato nei log nuovo; la correzione non indebolisce hash, DAG o controlli delle dipendenze |
| prestazioni/sistema | Controlli costanti sui metadati/cardinalità già disponibili; `maximumHypothesisCount` resta un budget fuori dall'identità semantica del nodo e non causa ricalcoli quando un risultato valido rientra in un budget diverso |
| tracciabilità | CMP-199 inizialmente `specified`; TV-004/TV-005/TV-027/TV-031/TV-071 e GS-VER-199; dipendenza esplicita di GS-DOR-198, nessuna attestazione retroattiva del lotto 196/197 |
| decisioni e recupero | ADR-0033 E registra la necessaria correzione dei metadati, senza riaprire i kernel; rollback locale dei guard/factory senza migrazione, preservando gli Artifact e i programmi concomitanti |

Il limite di ipotesi rimane una condizione di admission, distinta dai parametri
scientifici. Alzarlo per lo stesso confronto valido non deve creare un altro
nodo. Abbassarlo sotto la cardinalità del risultato lo rifiuta anche se il
calcolo era già stato completato con un budget maggiore.

Le due prove aggiunte in Ready 1.1 usano i confini reali del package: nel primo
caso `storeArtifact` associa deliberatamente un payload 0,95 a un descrittore
0,80 costruito dalla factory; il riuso deve produrre
`keyness.descriptor-result-mismatch`, senza nuova generazione. Nel secondo il
descrittore legacy è ottenuto tramite JSON senza il parametro, con payload
keyness v2 che già contiene il livello e storage reale; riapertura e lettura ne conservano i byte, mentre una
nuova richiesta produce il descrittore attuale. Queste prove non sono attribuite
retroattivamente ai due RED storici e non introducono uno schema speciale.
Non è una prova del payload keyness v1 precedente a Fisher e agli intervalli.

**Ready** prima della patch di produzione. I due RED devono essere osservati
sul codice non corretto; la prova della factory e della cache non implica una
nuova validazione degli intervalli numerici o un audit di tutti gli Artifact.
198 può proseguire nei suoi confini, ma la sua chiusura richiede questa
dipendenza verificata. Nessuna prova GUI, iPadOS o G4 viene attribuita al lotto.
