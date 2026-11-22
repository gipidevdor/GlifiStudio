# 16. Strategia di verifica e test

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-16 |
| Tipo | Capitolo normativo |
| Versione | 0.5.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 16.1 Livelli

| Livello | Oggetto |
| --- | --- |
| Unit test | Tipi, invarianti, algoritmi e casi limite isolati |
| Property test | Proprietà generali di codec, offset, indici e trasformazioni |
| Integration test | Confini tra importer, pipeline, persistenza, ricerca e framework |
| System test | Flussi completi su progetti e corpus di riferimento |
| Numerical reference test | Confronto con risultati scientifici approvati |
| Scientific property test | Invarianti matematiche, simmetrie, range e casi degeneri |
| Reproducibility test | Ripetizione D0/D1/P1 su processi, scheduling e backend applicabili |
| Migration test | Lettura e trasformazione di ogni versione supportata |
| Robustness/fuzz test | Parser, formati binari, query e input ostili |
| UI/accessibility test | Flussi critici, tastiera e semantica accessibile |
| Usability study | Efficacia, efficienza, errori, recupero e soddisfazione su compiti definiti |
| Comprehension study | Interpretazione di finding, evidenza, caveat, solidità e causalità |
| Planner decision test | Applicabilità e piano rispetto a profilo, intento, capability e policy |
| Epistemic integrity test | Corrispondenza fra evidenze, rule set, findings, caveat e relazione |
| Benchmark | Throughput, latenza, memoria e I/O |
| Kill/recovery test | Interruzione in ogni commit point e recupero della generazione valida |
| Cross-interface contract test | Equivalenza di QueryAST, piano, ordine, errori e output fra GUI, API e CLI |

## 16.2 Regole

- Ogni requisito approvato **DEVE** avere almeno una verifica tracciata.
- Ogni correzione di difetto **DEVE** includere un test che fallisce senza la correzione, quando tecnicamente possibile.
- I test **DEVONO** essere deterministici oppure dichiarare e controllare la fonte di variabilità.
- Test che dipendono da rete, locale, fuso orario, clock o ordine di esecuzione **DEVONO** isolare tale dipendenza.
- Fixture e dataset di riferimento **DEVONO** essere versionati, descritti e legalmente utilizzabili.
- Test disabilitati o quarantinati **DEVONO** avere responsabile, motivazione e scadenza.
- La sola percentuale di coverage **NON DEVE** essere usata come prova di correttezza.
- La concordanza fra due implementazioni che condividono lo stesso difetto **NON
  DEVE** essere l'unico oracolo: servono proprietà, calcolo indipendente o dataset
  pubblicato.

## 16.3 Copertura minima sostanziale

Devono essere coperti almeno:

- percorso nominale e casi limite di ogni API pubblica;
- categorie di errore dichiarate;
- cancellazione delle operazioni lunghe;
- round-trip delle posizioni verso la fonte;
- confini Unicode e dei chunk;
- compatibilità dei formati persistenti;
- invarianti numeriche e tolleranze;
- formule, precondizioni, casi nulli e classi D0/D1/P1/N1 di GS-MET-001;
- p-value, effect size, multiple testing e intervalli conservati separatamente;
- equivalenze strutturali di cluster, fattori e sottospazi;
- input corrotti per ogni parser controllato dal progetto.
- cardinalità e invarianti di Project, Corpus e Investigation;
- determinismo del planner e del motore interpretativo;
- lineage exact/contributive/derivational dalla UI alla fonte;
- parità semantica dei flussi macOS/iPadOS e ripristino del contesto;
- comprensione e calibrazione mediante protocolli e soglie definiti prima dello studio;
- output generativi ostili che tentano di aggiungere findings o rimuovere caveat.
- package `.glifi`, SpanMap, QueryAST, InterpretationRule, VisualizationSpec e
  ValidationManifest secondo GS-DAT/GS-QRY/GS-ANA/GS-VIZ/GS-VAL;
- path traversal, symlink, dimensioni false, nesting, regex DoS, pressione di
  memoria/disco e kill injection.

Le app **DEVONO** applicare anche il profilo Apple per [test e diagnostica](../apple/07-test-e-diagnostica.md).
Il protocollo scientifico trasversale è [GS-VAL-001](../specifiche-di-design/09-validazione-scientifica.md).
