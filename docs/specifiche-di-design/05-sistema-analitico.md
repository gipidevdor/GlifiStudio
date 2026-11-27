<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Sistema analitico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ANA-001 |
| Tipo | Specifica di design del sistema analitico |
| Versione | 1.7.3 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-27 |
| Approvazione | Baseline proposta; policy e regole MVP da convalidare |
| Riferimenti | GS-MET-001; GS-UX-001-03–08; GS-DOM-001; GS-DAT-001; ADR-0013; ADR-0016 |

## Scopo e separazione

Questa specifica governa capability, planner, identità del DAG, invalidazione,
esecuzione logica, trasformazione di Artifact in Evidence/Finding/Caveat, ranking
editoriale e spiegazione. GS-MET resta l'autorità su formule e precondizioni;
GS-RUN governa task, memoria e scheduling fisico.

```text
Question + AnalyticalIntent + CorpusVersion + CollectionProfile
                       ↓
               Analysis Planner
                       ↓
       AnalysisPlanRevision / Analysis DAG
                       ↓
        Artifact → Evidence → Finding + Caveat
                       ↓
          ranking editoriale → spiegazione
```

## Capability e applicabilità

Ogni capacità pubblica fornisce un `CapabilityDescriptor` versionato con:

- ID semantico, famiglia, contratto GS-MET e versioni implementate;
- tipi degli input/output, parametri, default e vincoli;
- precondizioni dure, segnali di qualità e motivi di non applicabilità;
- cost model parametrico, strategie streaming/sparse e backend equivalenti;
- classe di determinismo, tolleranze, seed e policy numerica;
- requisiti linguistici, metadati, lineage e visualizzazioni compatibili.

L'applicabilità è `applicable`, `applicableWithCaveats`, `notApplicable` o
`unknown`. Solo i primi due possono entrare nel piano; `unknown` non equivale a
“probabilmente sì”. Motivi ed esclusioni sono persistiti e spiegabili.

## Planner deterministico

Input uguali, catalogo di capability uguale e policy uguale producono lo stesso
piano canonico. Il planner:

1. risolve l'intenzione e gli slot senza rinominare i metodi;
2. interroga CollectionProfile e capability;
3. costruisce candidati e dipendenze;
4. elimina non applicabili e ridondanti con regole versionate;
5. stima costo e applica il budget;
6. ordina con tie-break stabile;
7. registra inclusioni, esclusioni, fallback e domande irrisolte.

La baseline `planner-mvp-v1` ammette soltanto capacità GS-PROD-001. Nessun comando
“Analizza tutto” aggira il budget o promuove automaticamente metodi sperimentali.

## Identità semantica dei nodi

`AnalysisNodeID` è SHA-256 con domain separation di una serializzazione canonica:

```text
glifi.analysis-node.v1 ||
method-id || method-version || input-artifact-digests ||
resolved-parameters || linguistic-profile-versions ||
numeric-policy || seed-policy || output-schema-version
```

Tempo di esecuzione, progresso, UI e percorso temporaneo non entrano nell'identità.
Un backend può essere escluso soltanto se il relativo contratto prova equivalenza
semantica entro tolleranza; altrimenti backend e versione entrano nell'identità.
L'`ExecutionRecord` conserva comunque host class, backend, tempi, risorse e software.

Parametri impliciti sono vietati al momento del commit del piano. Mappe e insiemi
sono ordinati canonicamente; float, NaN, infinito e signed zero usano la codifica
GS-MET/GS-DAT, non la descrizione locale.

## Analysis DAG e riuso

Il grafo è diretto, aciclico e tipizzato. Ogni arco dichiara porta di output/input
e vincolo di schema. Prima del commit si validano cicli, input mancanti, versioni,
applicabilità e budget. Nodi semanticamente identici sono deduplicati nello stesso
progetto e possono condividere Artifact immutabili.

Un Artifact è riusabile se digest, schema, descriptor e tutti gli input sono
validi. Una modifica invalida transitivamente i discendenti effettivi, non i
fratelli. Il grafo conserva stato `valid`, `stale`, `missing`, `running`, `failed`
o `cancelled`; `stale` non viene mostrato come risultato corrente.

Materializzazione e lazy evaluation sono proprietà del piano. Checkpoint includono
ID nodo, partizione, schema, input digest e checksum; una partizione incompatibile
è scartata. Il garbage collector usa raggiungibilità da piani, report e storia.

### Identità del descrittore e admission del riuso keyness

Per `keyness-gtest-fisher-ha-ci-bh-v2`, il livello di confidenza è un parametro
scientifico risolto del descrittore e **DEVE** corrispondere al risultato anche
nel percorso di riuso. Il limite della famiglia è invece un budget di admission:
**DEVE** essere rispettato anche dagli Artifact già materializzati e resta fuori
dall'identità semantica del nodo. Un budget diverso ma sufficiente consente
quindi il riuso; uno inferiore alla cardinalità fallisce con la failure di limite
esistente, senza ridefinire o troncare la famiglia.

I nuovi descrittori che includono il livello possono produrre un nuovo nodo;
gli Artifact keyness v2 con il descrittore precedente restano leggibili e conservati. GS-DOR-199 corregge
questi metadati e controlli senza modificare formule, schema o formato package.

## Motore interpretativo

Una `InterpretationRule` versionata dichiara famiglia, pattern di Artifact,
precondizioni, trasformazione in Evidence, condizioni di Finding, Caveat e chiavi
localizzabili. A parità di input produce lo stesso risultato e lo stesso ordine.

La regola conserva:

- osservazioni e statistiche effettivamente usate;
- soglie, effect size e correzioni multiple applicabili;
- evidenze favorevoli, contrarie e non disponibili;
- motivi di soppressione, deduplicazione o `insufficientEvidence`;
- grado di supporto secondo una `SupportPolicy` specifica della famiglia.

Non esiste un confidence score universale. Probabilità, p-value, qualità di
rappresentazione, stabilità e copertura non sono convertiti in una percentuale
intercambiabile.

## Ranking editoriale

Il ranking opera dopo un gate di eleggibilità: lineage completo, precondizioni
soddisfatte, supporto minimo della famiglia e assenza di corruzione. Risultati di
famiglie epistemicamente non comparabili non ricevono un singolo punteggio globale.

`editorial-rank-v1` usa confronto lessicografico o fronte di Pareto entro lo stesso
intento e famiglia:

1. rilevanza dichiarata per l'intento;
2. classe di supporto specifica della famiglia;
3. effect size o magnitudine appropriata;
4. copertura e qualità dei dati;
5. stabilità a perturbazioni definite;
6. novità rispetto ai findings già selezionati;
7. non ridondanza e completezza del lineage;
8. FindingID come tie-break.

Le regole di diversificazione tra famiglie sono quote editoriali versionate, non
un confronto numerico fittizio. Una persona può riordinare o includere risultati;
questa scelta entra nella storia e non modifica il supporto scientifico.

## Contratto di spiegazione

Ogni Finding risponde a “Perché lo dici?” con una struttura, non testo libero:

```text
conclusione
├── Evidence usate e relativo supporto
├── osservazioni/fonti navigabili
├── metodo, variante, parametri e limiti
├── alternative considerate o escluse con motivo
└── Caveat, dati mancanti e condizioni di validità
```

La versione compatta e quella tecnica derivano dallo stesso `ExplanationModel`.
Una spiegazione incompleta impedisce la promozione del Finding a report. Un testo
generativo può parafrasare soltanto dopo il modello strutturato e resta marcato non
autoritativo.

## API e stati operativi

GlifiCore espone pianificazione ed esecuzione come operazioni asincrone cancellabili.
GlifiKit e GlifiCLI usano gli stessi `AnalysisPlanRevision`, `QueryAST`, Artifact ed
errori tipizzati. Un errore di un ramo non annulla artefatti validi indipendenti;
lo stato del piano rende visibili completezza e partial failure.

### Slice implementate di analisi bounded

La fondazione `studio.glifi.analysis-descriptor.v1`/`v2` con `analysis-dag-v1` implementa
identità SHA-256 domain-separated, parametri canonici, round-trip fail-closed,
deduplica, validazione aciclica e di schema, ordine topologico, sottografo minimo,
invalidazione transitiva esatta e riuso condizionato dell'intera catena di
Artifact. Il grafo resta bounded a 10.000 nodi e 50.000 archi.

Il package `.glifi` persiste ora nodo, descriptor e payload degli Artifact come
oggetti SHA-256 immutabili, li lega alla radice della generazione e ricostruisce il
DAG soltanto dopo una validazione fail-closed. Commit identici sono idempotenti;
la sostituzione di un output mantiene i rami indipendenti e rimuove dalla nuova
generazione soltanto il nodo sostituito e i suoi discendenti. Le generazioni
precedenti restano immutate.

La prima slice eseguibile acquisisce una generazione verificata, ordina le
`SourceRevisionID` canonicamente e calcola in memoria entro limiti espliciti:

- `D`, caratteri come extended grapheme cluster, frasi, `N`, `V`, frequenze
  assolute/relative, document frequency e range;
- `TTR-v1`, `MSTTR-v1` con `discard-remainder` e `MATTR-v1` sulla concatenazione
  canonica delle revisioni, con finestra dichiarata;
- n-grammi di parole che non attraversano il confine del documento e
  `GriesDP-v1` sulla partizione per revisione;
- matrice documento-termine sparsa con righe `SourceRevisionID`, colonne
  lessicografiche, `TF-raw-v1`, `IDF-smooth-v1` e `TFIDF-v1`.

L'identità `corpus-profile-it-v1` e il digest SHA-256 includono revisione,
contenuto, contratto di estrazione e parametri analitici. I limiti predefiniti sono
1.000 documenti, 256 MiB sorgente complessivi, 100.000 type, 100.000 n-grammi
distinti e 500.000 celle non-zero. Cancellazione e superamento dei limiti producono
failure tipizzate senza modificare la generazione.

I limiti operativi correnti **DEVONO** valere anche quando il profilo corpus è
riutilizzato da un Artifact, direttamente o come dipendenza di un'analisi derivata.
Un risultato entro i limiti resta riutilizzabile senza ricalcolo: i limiti di
risorse non modificano l'identità scientifica del profilo. Il rifiuto conserva
codice, categoria e stato persistente del corrispondente percorso a cache fredda.

`keyness-gtest-ha-bh-v1` riceve due gruppi espliciti e disgiunti dalla stessa
generazione, costruisce due profili compatibili e produce l'intera famiglia di
confronti con `GTest-v1`, p-value χ² a un grado di libertà, effect size
Haldane–Anscombe, correzione `BenjaminiHochberg-v1` e diagnostica sui conteggi
attesi. Popolazioni, identità dei metodi, soglie, policy numerica, tolleranza,
ordinamento e digest sono parte del risultato. Il limite sul numero di ipotesi è
applicato prima di costruire le righe finali. Il profilo corrente
`keyness-gtest-fisher-ha-ci-bh-v2` aggiunge la selezione pre-registrata di Fisher
per attese minori di 5 e gli intervalli di confidenza di Katz e Woolf (GS-MET-001-08,
GS-VER-118).

`analyzeCorpus` e `compareKeyness` costruiscono il descriptor prima del lavoro,
riusano un payload schema-versioned quando nodo e catena sono validi e committano
il nuovo risultato attraverso lo stesso manifest del progetto. Keyness persiste i
due profili di popolazione come dipendenze tipizzate. Il risultato espone sia la
generazione sorgente sia quella che raggiunge l'Artifact, oltre a ArtifactID e
AnalysisNodeID.

`planner-mvp-v1` implementa la tassonomia completa degli undici intenti e un
catalogo immutabile per le due capability attualmente eseguibili. Il planner puro
risolve lo scope in revisioni esplicite, deriva un CollectionPlanningProfile da
metadati osservati, verifica gruppi e precondizioni, applica un modello di costo
intero con overflow fail-closed e ammette bundle atomici soltanto entro budget.
Il piano canonico contiene step target/riferimento/confronto, dipendenze, backend,
fallback vuoti espliciti, caveat, inclusioni, esclusioni, rinvii e condizioni
irrisolte. Il payload `studio.glifi.artifact.analysis-plan.v1` è legato al proprio
AnalysisNodeID, committato nel package e riusato dopo riapertura. GlifiKit e
GlifiCLI espongono lo stesso contratto tramite una richiesta JSON bounded.

La revisione GS-VER-305 impone un unico residuo di budget per tutti i bundle:
il costo dei profili target/riferimento e di keyness è detratto prima delle
capability successive. La somma dei costi dei passi ammessi non supera il
massimo richiesto. Il produttore corrente di planner-v2 usa algorithmVersion 2:
una richiesta ricalcolata non può collidere con un vecchio DAG prodotto dalla
revisione 1. Planner identifier, catalogo, descriptor schema e payload
analysis-plan.v1 restano invariati; gli Artifact storici non vengono riscritti.

`executeAnalysisPlan` applica prima l'admission deterministica di GS-RUN, persiste
o riusa la revisione del piano e verifica nuovamente radice delle fonti, ordine
delle dipendenze e schema di ogni output. Gli step `analyzeCorpus` e
`compareKeyness` materializzano gli Artifact già definiti senza un percorso di
calcolo laterale; una seconda esecuzione riusa le stesse identità e non crea una
generazione. Prima del terminale produce o riusa inoltre un Artifact
`studio.glifi.artifact.interpretation.v1`, dipendente dal piano e da tutti gli
output. Il risultato viene restituito soltanto quando piano, output e
interpretazione sono raggiungibili dalla generazione verificata.

`interpretation-rules-mvp-v1` implementa la prima trasformazione deterministica
in Evidence/Finding/Caveat. Il profilo corpus non vuoto produce un finding
descrittivo con lineage completo; un profilo senza token produce
`insufficientEvidence`. Keyness applica la policy prodotto versionata
`support-policy.keyness-gtest-bh-v1`: sono eleggibili solo direzioni non nulle con
q-value corretto ≤ 0,05 e magnitudine assoluta log2 ≥ 1; q ≤ 0,01 e magnitudine ≥
2 determinano `strong`, gli altri casi eleggibili `moderate`, mentre conteggi
attesi bassi impongono `caution` e un caveat visibile. Le soglie sono parametri del
descriptor e restano una policy prodotto provvisoria, non una verità scientifica
universale.

Con `planner-v2` (ADR-0025) l'interprete riceve anche gli output delle capability estese come
fatti tipizzati estratti dai payload persistiti e applica le policy di
[ADR-0026](../adr/0026-policy-di-supporto-per-famiglia.md) con il rule set
`interpretation-rule.extended-families-adr-0026-v1`: ogni risultato eleggibile diventa un Evidence
e un Finding con classe, dimensioni e motivi della policy; le cause di `caution` diventano caveat
del finding; i risultati non eleggibili sono contati in `interpretation.extended-not-eligible` e
quelli oltre il limite in `interpretation.finding-limit-exceeded`. La similarità resta soltanto
descrittiva. Un piano con sole capability estese e nessun risultato eleggibile produce
`insufficientEvidence` con motivo `interpretation.no-eligible-finding`.

`editorial-rank-v1` ordina lessicograficamente soltanto entro la famiglia usando
intento, supporto, effect size, copertura, stabilità, novità, non-ridondanza,
lineage e FindingID. Dimensioni non misurate restano `nil` e generano caveat:
non vengono sostituite da zero né fuse in un confidence score. La
materializzazione è limitata a 100 findings e aggrega i motivi di soppressione.
Identità Evidence/Finding e payload vengono ricalcolati in decodifica fail-closed.

Il progresso espone `OperationID`, revisione monotona, fase, step, nodo, unità,
completato, totale e qualità della stima. GlifiKit lo consegna mediante uno stream
bounded posseduto dalla ProjectSession; cancellare l'handle o chiudere la sessione
propaga la cancellazione e la chiusura attende le task possedute. GlifiCLI usa lo
stesso percorso con `execute --request` e può sopprimere il progresso testuale con
`--no-progress` senza cambiare l'esito macchina.

Mancano ancora segmenti documentali, spill fuori memoria, analisi temporale,
profilo qualitativo/metadati completo, progresso interno ai singoli nodi,
ExecutionRecord/checkpoint persistenti, conflitto tra evidenze, stabilità e novità
misurate, Investigation/storia editoriale, explanation UI, studi empirici e altre
capability. La slice Evidence/Finding/Caveat è verificata per profilo corpus e
keyness, ma non dimostra ancora conformità completa GS-ANA-001 o l'intero percorso
Must 0.1.

## Conformità

- golden decision table del planner e motivi di esclusione;
- test DAG per cicli, deduplica, invalidazione transitiva e riuso selettivo;
- round-trip dell'identità semantica attraverso processi e scheduling differenti;
- golden test di InterpretationRule, Caveat propagation e explanation contract;
- test metamorfici del ranking e assenza di score universale;
- equivalenza osservabile tra GUI, GlifiKit e GlifiCLI.
