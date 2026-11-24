<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Richieste analitiche testuali riproducibili

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-002 |
| Tipo | Contratto del trasporto analitico transitorio |
| Versione | 1.3.5 |
| Stato | Profili pubblici implementati; baseline storica GS-VER-300, rifinitura GS-VER-305 verificata localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Prosecuzioni esplicite RF-087 e GUI; ADR-0034 e ADR-0043 |
| Riferimenti | GS-API-001; GS-MET-001-23; RF-087; RQ-060; ADR-0032; ADR-0034; [ADR-0035 headless](../adr/0035-completamento-nativo-kh-coder.md); [ADR-0041 app](../adr/0041-copertura-funzionale-core-nelle-app.md); GS-DOR-162; GS-DOR-222; ADR-0042; ADR-0043; GS-DOR-300; GS-DOR-305; GS-VER-234; GS-VER-300; GS-VER-301; GS-VER-305; [GS-DOR-233 headless](../pianificazione/dor-completamento-kh-coder.md) |

## Contratto

`GlifiStudioTextAnalysisRequest` è un enum Swift `Sendable`, immutabile e tipizzato.
`GlifiStudioTextAnalytics.executeTextAnalysis(_:)` e
`executeTextAnalysis(json:)` eseguono gli stessi operatori GlifiKit fuori dall'actor
chiamante. Gli errori sono `GlifiStudioFailure`; le cancellazioni prima e dopo il
calcolo impediscono la pubblicazione di un risultato.

La request JSON ha `schema = studio.glifi.text-analysis-request`,
`schemaVersion = 1` e `operation`. I parametri appartengono allo stesso oggetto.
Per dati esterni si **DEVE** usare `GlifiStudioTextAnalysisRequest.decode(_:)`
oppure `executeTextAnalysis(json:)`, che applicano i limiti prima del decoder.

```json
{
  "schema": "studio.glifi.text-analysis-request",
  "schemaVersion": 1,
  "operation": "mds",
  "matrix": [[0, 1], [1, 0]],
  "dimensions": 1
}
```

| Operazione | Parametri obbligatori | Default risolti |
| --- | --- | --- |
| `mds` | `matrix` | `dimensions=2, method=classical, seed=0, maximumIterations=300` |
| `som` | `matrix, width, height, seed` | `epochs=100` |
| `clara` | `matrix, clusterCount, seed` | `sampleSize=100` |
| `classify` | `documents, labels, predictionDocuments` | `smoothing=1` |
| `validate-classifier` | `documents, labels, folds, seed` | nessuno |
| `lda` | `documents, topicCount, seed` | `alpha=0.1, beta=0.01, burnIn=100, sampleCount=20, thinning=5` |
| `coding` | `units, rules` | `variables={}` per unità |
| `code-crosstab` | `units, rules, groups` | `variables={}` per unità |
| `dissimilarities` | `matrix, metric` | nessuno |
| `correspondence` | `matrix` | nessuno |
| `hierarchical` | `matrix` di dissimilarità | `linkage=average` |
| `network` | `matrix, labels` | `minimumJaccard=0.1, maximumEdges=10000` |

Le matrici sono array di righe numeriche; i documenti sono array di token espliciti.
Ogni unità di codifica contiene `id`, `text` e `variables` opzionale (stringhe).
In `groups` un valore `null` denota un gruppo mancante, escluso con conteggio
esplicito. `classify` addestra il modello e valuta i documenti sul vocabolario
congelato; non esporta un modello persistente.

Metodi MDS: `classical, metric, kruskal, sammon, ordinal`. Distanze:
`jaccard, dice, simpson, cosine, euclidean, manhattan`. Linkage:
`single, complete, average`; questo tag non ammette Ward. Il profilo algebrico
Ward.D2 ha il tag dedicato `kh-hierarchical-ward-d2`, descritto sotto.
Parametri numerici invalidi conservano le failure dell'operatore; non sono corretti
silenziosamente. LDA riporta perplexity predittiva in-sample, non held-out.

## Operazioni avanzate aggiuntive

Il caso Swift `.advanced(GlifiStudioAdvancedTextAnalysisRequest)` riusa lo stesso
envelope. Nel JSON `operation` e i parametri restano **piatti** nello stesso
oggetto: non viene introdotta una chiave `advanced`, né uno schema/versione nuovo.
Le dodici operazioni precedenti conservano campi e default; `mds` aggiunge la
variante `ordinal`, `dissimilarities` aggiunge `simpson`.

| Operazione | Parametri obbligatori | Default risolti |
| --- | --- | --- |
| `lda-selection` | `documents, candidateTopicCounts, seed` | `options={criterion:heldOutPerplexity, folds:5, alpha:0.1, beta:0.01, burnIn:100, sampleCount:20, thinning:5}` |
| `communities` | `graph, method` | `resolution=1, walkLength=4, limits=standard` |
| `graph-layout` | `graph, method` | `seed=0, maximumIterations=300, tolerance=1e-6, limits=standard`; `initialPositions` assente |
| `minimum-spanning-forest` | `graph` | `limits=standard` |
| `mds-search` | `matrix, seed` | `dimensions=2, method=ordinal, starts=10, maximumIterations=300, tolerance=1e-8` |
| `som-advanced` | `matrix, width, height, seed` | `epochs=100, topology=rectangular, initialRadius=2, finalRadius=0.5, tolerance=1e-8`; `codebookClusterCount` assente |
| `linguistic` | `text` | `options={languageTag:it, base:normalized-surface, includePartOfSpeech:false}` |
| `linguistic-availability` | nessuno | `languageTag=it` |
| `linguistic-coding` | `units, rules` | `options` linguistico come sopra; `variables={}` per unità |

`graph` contiene `nodes` ordinati e unici e `edges` con `source`, `target` e
`weight` finito non negativo (default uno). Le comunità ammettono
`edgeBetweenness`, `fastGreedy`, `walktrap`; i layout
`fruchtermanReingold`, `kamadaKawai`. `initialPositions`, se presente, è un array
allineato di oggetti `x,y` finiti nel quadrato `[-1,1]²`. Le politiche di peso,
loop, paralleli e componenti sono distinte per operatore in GS-MET-001-23.
Prim interpreta `weight` come costo, senza convertirlo implicitamente da intensità.

Le tre operazioni grafiche trasportano il parametro nativo `limits`, opzionale.
I quattro campi interi sono `maximumNodeCount=2000`, `maximumEdgeCount=100000`,
`maximumPairwiseCells=1000000` e `maximumWork=200000000`; i campi omessi usano
gli stessi default di `GlifiStudioGraphAlgorithmLimits.standard`. Le chiavi
ignote e i `null` espliciti vengono rifiutati. I budget vengono applicati alla
stessa operazione nativa, prima di allocazione o lavoro non ammessi, con le
stesse failure tipizzate. La codifica canonica omette `limits` quando tutti i
valori sono standard: l'identità delle richieste preesistenti rimane invariata.
Un budget personalizzato viene invece codificato con tutti e quattro i valori.

`mds-search` ammette soltanto metodi iterativi e conserva tutti i risultati,
seed, obiettivi e convergenze con `chosenRun`; l’ordinale restituisce coordinate
adimensionali e stress grezzo normalizzato, distinti da Stress-1.
`som-advanced` ammette `rectangular` e `hexagonal` e restituisce `map`, `topology`,
`uMatrix` e opzionale `codebookClustering` con albero, incrementi Ward e assegnazioni.
I campi opzionali di configurazione si omettono; un `null` esplicito non risolve un default.

Per LDA, `criterion` ammette `heldOutPerplexity`, `caoJuan2009`, `arun2010`,
`deveaud2014`, `griffiths2004`. `folds=0` richiede un criterio diagnostico;
la selezione held-out richiede almeno due fold, non più dei documenti.
Il DTO conserva modello scelto, candidati, score/copertura per fold e seed;
metriche non definite hanno valore assente e motivo esplicito. La perplexity
in-sample del fit rimane separata da quella held-out usata nella selezione.

Il profilo linguistico supporta esattamente `it`; `base` ammette
`normalized-surface`, `apple-lemma`, `italian-snowball-3.1.0`. Superficie resta il
default. Lemma/POS Apple dipendono dagli asset installati, non scaricati dal
codice; gli sconosciuti sono `null` con uno stato distinto da `notRequested`.
La codifica annotata fallisce quando richiede un valore sconosciuto. Gli offset
UTF-8 si riferiscono al testo originale; il DTO conserva backend, OS, tagset,
policy single-best e versione modello non esposta, senza attestare accuratezza.

## Profili KH pubblici

`GlifiStudioKHAnalysisRequest` si compone nel caso Swift
`.advanced(.kh(request))`; `GlifiStudioKHAnalysis.execute(_:)` usa lo stesso
percorso. I diciannove nuovi tag sono piatti nel medesimo envelope JSON schema 1
e nel comando `text-analysis`: non introducono un comando, una chiave `kh` o
un formato di progetto. Contratti matematici e fonti primarie sono in
[GS-MET-001-23](../metodi-analitici/23-operatori-kh-coder.md).

| Operazione | Parametri obbligatori | Default risolti |
| --- | --- | --- |
| `matrix-zscore` | `matrix, axis` | `constantPolicy=reject` |
| `matrix-per-thousand` | `matrix, exposures` | `zeroExposurePolicy=reject` |
| `word-context` | `levels, targetIDs, contextIDs` | `alpha=1` per livello |
| `correspondence-scaled` | `matrix` | `rowScaling=principal, columnScaling=principal` |
| `mds-ordinal` | `matrix` | `dimensions=2, ties=primary, seed=0, maximumIterations=300, tolerance=1e-8` |
| `mds-ordinal-search` | `matrix` | `dimensions=2, ties=primary, starts=10, seed=0, maximumIterations=300, tolerance=1e-8` |
| `som-pca-initialization` | `matrix, width, height` | nessuno |
| `som-kh` | `matrix, width, height` | fasi come sotto; `topology=hexagonal`; `initialCodebooks, codebookClusterCount` assenti |
| `kh-collocation` | `counts` | nessuno |
| `word-association` | `counts` | nessuno |
| `document-scores` | `counts, exposures, documentFrequencies, corpusDocumentCount` | `mode=tf` |
| `kh-hierarchical-ward-d2` | `dissimilarities` | nessuno |
| `kh-chi-square` | `counts` | `correction=automatic` |
| `code-crosstab-significance` | `units, rules, groups` | `correction=automatic` |
| `term-scores` | `candidates, preprocessingIdentifier` | `adjacencyMode=token, maximumWork=100000000` |
| `term-extraction` | `documents, rule` | `adjacencyMode=token, maximumWork=100000000` |
| `incremental-classifier` | `documents, labels` | `smoothing=1, predictionDocuments=[]` |
| `continue-classifier` | `state, documents, labels` | `predictionDocuments=[]` |
| `validate-classifier-kappa` | `documents, labels, folds, seed` | `smoothing=1` |

`axis` è `rows` o `columns`: ogni vettore usa media e deviazione standard
campionaria con denominatore n−1, almeno due osservazioni e politica per costanti
`reject` oppure `zeros`. `exposures` contiene il denominatore completo per riga;
non è dedotto dalle colonne selezionate. `zeroExposurePolicy=zeros` ammette
esposizione nulla soltanto se tutta la riga è nulla.

Ogni elemento di `levels` contiene `level`, `targetCounts`, `contextCounts` e
`alpha` opzionale. I livelli distinti sono `sentence, paragraph, h5, h4, h3, h2, h1`.
Le righe delle due matrici rappresentano le stesse unità del livello; le colonne
sono allineate rispettivamente a `targetIDs` e `contextIDs`, vocabolari unici per
asse, anche sovrapposti. Il risultato conserva ID, livelli, pesi, supporti e medie
condizionate pesate. Il trasporto non costruisce frasi o gerarchie.

Gli scaling CA sono `principal`, `standard` e `symmetric` biplot, rispettivamente
con potenze di σ pari a 1, 0 e 0.5, indipendenti per righe/colonne. Il biplot
`symmetric` qui definito è distinto dalla mappa omonima del pacchetto R ca.
Per l'ordinale, `ties=primary` ammette disparità diverse nello stesso tie;
`secondary` le uguaglia. I default delle operazioni precedenti rimangono secondary.

`som-kh` riceve dati già preparati. `firstPhase` e `secondPhase`, se fornite,
contengono `steps`, `initialLearningRate`, `initialRadius`. Per U unità della
griglia (`width*height`) i default sono `(1000, 0.05, min(width,height))` e
`(500U, 0.02, min(3,width,height))`; sono aggiornamenti online, non epoche batch.
I codebook proseguono fra le fasi. `initialCodebooks` omesso seleziona PCA lineare
canonica; un array fornito dichiara invece i prototipi iniziali.
L'uscita conserva inizializzazione, fasi, prototipi intermedi/finali, assegnazioni,
diagnostiche e `uMatrix`. `codebookClusterCount`, se presente, aggiunge
`codebookClustering` Ward, con ammissione cumulativa prima del calcolo.
`som-pca-initialization` espone separatamente i codebook PCA senza addestramento.

Per `kh-collocation`, `counts` dichiara `jointCount`, `nodeFrequency`,
`collocateFrequency`, `corpusTokenCount`, `windowSpan`. Le frequenze sono TF
globali di due chiavi distinte; lo span conta le posizioni ammesse escludendo il
nodo. I conteggi sono non negativi, lo span è positivo e la somma delle due TF
non supera il totale dei token. Le coppie osservate rispettano le capacità
TF×span di entrambi i termini e il prodotto delle due TF. Le finestre sovrapposte
possono comunque produrre un `jointCount` superiore a una TF.

Il `methodIdentifier` è `KH-collocation-global-token-window-v1`. Il risultato
`GlifiStudioKHCollocationScores` espone le sette misure `mutualInformation`,
`mi3`, `tScore`, `zScore`, `jaccard`, `dice`, `logLikelihood`, oltre a
`expectedWindowCount`, `mi3MethodIdentifier` e `zMethodIdentifier`. MI e MI3 usano
logaritmi in base due; la log likelihood del manuale è G²/2 con logaritmi
naturali. Queste convenzioni non sostituiscono le TF globali con i margini delle
opportunità di finestra. I valori non definiti sono omessi: in particolare MI,
MI3 e t per zero coppie; Z per background o varianza nulli; Jaccard per unione
non positiva; Dice per TF entrambe nulle; log likelihood per corpus vuoto o
coppie superiori a una delle TF. Jaccard e Dice non vengono limitati a uno.

Per `word-association`, `counts` è invece `GlifiStudioKHWordAssociationInput`:
`jointCount`, `conditionDocumentCount`, `termDocumentCount` e
`totalDocumentCount`, tutti interi obbligatori. Le marginali sono DF sulla stessa
popolazione di documenti; la condizione e il termine possono sovrapporsi.
I conteggi devono produrre quattro celle 2×2 non negative, senza ricavare
implicitamente i documenti o filtrare quelli fuori condizione. Il metodo
`KH-word-association-document-v1` restituisce `unconditionalProbability`,
`conditionalProbability`, `differential`, `lift`, `jaccard`, `ochiai` e
`isPositiveAssociation`. La probabilità condizionata è anche la misura di
ordinamento Frequency del profilo KH. I denominatori nulli lasciano assente la
misura corrispondente; il segno dell'associazione usa il confronto intero esatto
`jointCount*totalDocumentCount > conditionDocumentCount*termDocumentCount`,
anche quando le probabilità arrotondate coincidono. Non viene applicato un
filtro automatico delle associazioni nulle o negative.

`document-scores` riceve conteggi documento×termine, esposizioni complete positive
per riga e DF del corpus di riferimento dichiarato. `mode` ammette `tf`, `tfIdf`
e `tfDividedByIdf`: TF è conteggio/esposizione, IDF è `log10(N/DF)` senza smoothing.
Soltanto la divisione sostituisce un divisore IDF nullo con uno. Il risultato
conserva esposizioni, DF, numerosità del corpus, IDF originali, contributi e
somme; i conteggi restano nella richiesta canonica.
I rapporti subnormali sono arrotondati una sola volta al più vicino con parità
al pari sui fattori binary64 già risolti; si riservano altre 54 unità di lavoro
per ogni contributo candidato al percorso esatto prima dei buffer di output.
Un contributo positivo non rappresentabile produce `kh-document-score.numeric-range`.

`kh-hierarchical-ward-d2` riceve dissimilarità simmetriche non negative a diagonale
nulla. Esegue la ricorrenza algebrica Ward.D2 sulle distanze quadrate; l'uscita
conserva fusioni e altezze nella scala originale, con `wardIncrement` assente.
È distinto dal Ward euclideo di varianza: una dissimilarità Jaccard non diventa
una distanza euclidea per effetto della ricorrenza.
Quadrati positivi subnormali dopo la scalatura, iniziali o aggiornati, producono
`kh-ward.numeric-range`; i limiti di oggetti, celle e lavoro producono
`kh-ward.resource-limit` con categoria `insufficientResources`.

`kh-chi-square` riceve una tabella rettangolare di conteggi interi non negativi.
`correction` ammette `automatic`, `none`, `yates`: il default applica Yates solo
al 2×2; `none` usa Pearson; Yates esplicito richiede 2×2. Il risultato conserva
correzione richiesta/applicata, stato, gradi di libertà, attese, statistica,
p-value, `pearsonResiduals` e `standardizedResiduals` distinti. Totale o margini
nulli e dimensioni insufficienti producono stato esplicito e valori non definiti,
senza eliminare righe/colonne. Le celle non definite sono `null`.

`code-crosstab-significance` usa le unità di codifica e il testo delle regole
già definiti, con un gruppo opzionale per unità. Restituisce gruppi ordinati,
codici nell'ordine delle regole, conteggi, numerosità ed esclusi; per ogni codice
esegue il test su gruppo×[presenza, assenza], dove assenza è numerosità−presenza.
Gruppi `null` sono esclusi; codici sempre presenti/assenti conservano un test
degenere senza bloccare gli altri. Con meno di due gruppi il test è assente
con motivo `insufficient-groups`. Il lavoro dei test è ammesso cumulativamente.

Le `candidates` di `term-scores` contengono `components` ordinati e `frequency`
indipendente, senza ricontare le occorrenze contenute in candidate più lunghe.
`adjacencyMode` è `token` o `type`; l'uscita conserva f, LR, FLR e statistiche
dei componenti. `preprocessingIdentifier` dichiara la formazione delle candidate.
Per `term-extraction`, ogni documento contiene `id`, `text`, `tokens` e
`linguisticContract`. I token contengono `surface`, `base`, `startUTF8`, `endUTF8`,
`partOfSpeech`, con `sentence=0, paragraph=0` se omessi. L'estrazione richiede
POS presenti; superfici e offset devono coincidere con i byte della fonte.
`rule` contiene `identifier`, `allowedPartsOfSpeech` e opzionalmente
`ignoredKeys=[]`, `minimumComponents=2`, `maximumComponents=64`.
L'uscita conserva regola risolta, ID/contratti linguistici, run indipendenti,
indici dei token, intervalli UTF-8 e ranking. Questi ingressi operano su
preannotazioni esplicite, senza selezionare un tokenizer inglese o giapponese.
Per componenti canonicamente equivalenti in Unicode, la prima occorrenza di
fonte sceglie la grafia restituita. Non si normalizzano i byte della request
o delle occorrenze, né si affida il rappresentante all'ordine di un dizionario.

Lo `state` NB transitorio contiene `classes`, `vocabulary`, `documentCounts`,
`tokenCounts` e `smoothing=1` se omesso. Continuare il training conserva i
conteggi precedenti ed espande classi/vocabolario. L'uscita include stato,
modello ispezionabile e predizioni quando definite. Uno stato a classe unica
può essere continuato; la predizione richiede almeno due classi.
`validate-classifier-kappa` restituisce predizioni fuori fold, matrice di
confusione, accuratezza, κ e accordo osservato/atteso sulle stesse unità.
Batch e stato incrementale condividono il calcolo stabile di likelihood e prior:
i complementi dei conteggi dominanti sono sottratti come interi prima della
conversione, poi valutati con `log1p` quando applicabile. Non cambiano smoothing
o calibrazione. Training e CV ammettono anche byte UTF-8, hashing e ordinamento
di vocabolario/etichette; nella CV questi costi sono riservati per tutti i fold.

## Identità e risultati

`canonicalData()` risolve i default, include schema/versione/operazione e seed dove applicabile e
codifica con JSONEncoder, chiavi ordinate e slash non escaped. Spaziatura e ordine
delle chiavi esterni non partecipano all'identità. Le stringhe non sono
normalizzate dal trasporto; non si dichiara un'implementazione RFC 8785.
`requestDigest` è SHA-256 esadecimale minuscolo di quei byte. La versione del
trasporto governa questa rappresentazione; non cambia le identità scientifiche.

Il risultato ha `schema = studio.glifi.text-analysis-result`,
`schemaVersion = 1`, `operation`, `requestDigest`, `methodIdentifier`,
`validationStatus` e `result` con il DTO GlifiKit dell'operatore.
Ordini, diagnostiche, seed e coordinate UTF-8 sono quelli della facciata.
Il digest della request da solo non identifica la revisione dell'algoritmo:
per confrontare risultati si **DEVONO** conservare anche metodo e versione.

Per `communities` con `method=edgeBetweenness`, l’identificatore restituito è
`GirvanNewman-inverse-strength-exact-binary64-v2`. Le somme dei costi binary64
rappresentati e gli accumuli non negativi sono esatti; normalizzazione, reciproci
e rapporti restano binary64. La variante sostituisce v1 per distinguere cammini
e spareggi che le somme arrotondate potevano fondere o separare. Non introduce
una nuova operazione o uno schema diverso: i risultati v1 e v2 restano
identificati dalla rispettiva versione del metodo.

Il client nativo può ispezionare lo stesso risultato mediante il payload
tipizzato `GlifiStudioTextAnalysisPayload`, senza decodificare o reinterpretare
il JSON. `GlifiStudioCodeCrosstab.codes` conserva le identità delle colonne per
la presentazione nativa; il formato JSON v1 resta quello precedente.

Lo stato è per identificatore esatto secondo GS-VER-161; gli identificatori
ausiliari senza manifest dedicato (distanze, aggregazione, CV, reti, HAC) mantengono
`candidate`. Il trasporto non promuove metodi né completa la revisione esterna V6.
I nuovi identificatori KH restano `candidate`. GS-VER-300 registra il gate
locale pre-merge superato; GS-VER-301 conserva la precedente integrazione
pubblicata. La versione attestata da GS-VER-300 resta storica e non modifica lo
stato dei manifest preesistenti. La successiva rifinitura GS-DOR-305 mantiene
schema 1 e gli stessi identificatori matematici, con risultati corretti e guard
di range/risorse più rigorosi; GS-VER-305 attesta il nuovo gate locale superato.

## Limiti e failure

Input esterno e rappresentazione canonica: massimo 1.048.576 byte.
Profondità JSON: massimo 32 contenitori. Prima della codifica canonica si applicano
250.000 elementi aggregati (righe, celle, token, etichette, gruppi, unità e
variabili) e 1 MiB di contenuti UTF-8 aggregati; matrici, documenti e unità hanno
al massimo 20.000 righe. Restano applicabili i limiti di lavoro e output del Core.
MDS ordinale applica la stessa ammissione di coppie, PAVA, workspace e risultati
conservati a primary e secondary, anche nella ricerca multipla. Le varianti con
backtracking riservano tutti i 32 tentativi; Kruskal include i sort ripetuti.
La facciata SOM avanzata riserva fit, U-matrix e Ward opzionale in un solo budget
prima del fit, senza ripartire dal limite standard di 500.000.000 a ogni fase.

SOM batch applica la gaussiana completa, senza cutoff assoluto. Mantiene pesi
assoluti nel range ordinario e li riscala soltanto quando coefficienti o
prodotti rischiano il range subnormale; il percorso raro combina i fattori prima
dell'esponenziale. Batch e profilo online rifiutano con
`exploratory.numeric-range` un valore fisico rappresentabile che andrebbe perso
nello stato normalizzato, invece di pubblicare zero. Gli identificatori v1
restano quelli della formula dichiarata; non attestano identità bit per bit
con i risultati erronei delle revisioni precedenti.

Chiavi sconosciute, duplicate anche con escape Unicode equivalenti, operazioni
ignote, tipi errati, default esplicitamente `null` e valori non finiti sono
rifiutati. Un futuro `schemaVersion` produce `incompatibleVersion`; limiti di
byte/profondità/collezioni producono `insufficientResources`. Cause del parser,
testo, regole e path non attraversano le failure. L'apertura distingue
`authorizationDenied` per permessi negati, `insufficientResources` per risorse
esaurite, `invalidInput` per path assente/non regolare o link finale e
`transientIO` per gli altri errori temporanei del filesystem.

Il controllo delle chiavi ignote e dei tipi si applica anche a livelli di contesto,
fasi SOM, conteggi KH, candidate, documenti/token/regole e stato NB annidati.
Un campo opzionale assente può risolvere il default dichiarato; un `null`
esplicito non lo sostituisce, inclusi `initialCodebooks` e `codebookClusterCount`.
Resta distinta la convenzione di `groups`, dove `null` rappresenta un mancante.

La decodifica dei DTO contenenti intervalli UTF-8 applica gli invarianti del
costruttore: `0 ≤ start < end` e lunghezza rappresentabile. Range negativi,
vuoti, invertiti o traboccanti sono rifiutati anticipatamente secondo
[ADR-0042](../adr/0042-invarianti-intervalli-utf8-decodificati.md), senza cambiare
il JSON valido. Le span map rifiutano anche segmenti localmente incoerenti;
geometrie legacy valide con gap o sovrapposizioni conservano il fallback.
Le superfici annotate esterne devono coincidere con i byte UTF-8 della fonte:
l’equivalenza canonica fra NFC e NFD non basta a validare un intervallo.

Le regole di `coding` e `linguistic-coding` validano i qualificatori in tutti i
rami e riferimenti prima della valutazione. Frecce ripetute o prive del vincolo,
operandi di prossimità incompleti e letterali numerici non finiti sono rifiutati,
anche se il ramo non sarebbe valutato. Una parola numerica come `1e309` può
restare un termine se racchiusa tra apici. I candidati di prossimità scartati e
le evidenze aggregate consumano i rispettivi budget condivisi; non si pubblica
un risultato parziale al superamento del limite.

L'output scientifico richiesto può contenere vocabolario, nomi dei codici,
etichette, ID e intervalli di evidenza; non è un canale diagnostico anonimizzato.
Il corpo completo delle fonti e le regole non sono copiati nei metadati.

## CLI

```text
glifi --format json text-analysis --request richiesta.json
```

La CLI legge un file regolare da un singolo descrittore controllato, senza seguire
il link simbolico finale e senza bloccarsi su FIFO. Rifiuta directory e file oltre
il limite, quindi chiama esclusivamente GlifiKit. I link negli antenati del path
seguono la normale risoluzione del filesystem.

Con `--format json`, stdout contiene un solo envelope GS-API-001 versione 1,
comando `text-analysis` e risultato sopra; stderr è vuoto al successo. Le failure
producono solo l'envelope su stderr e l'exit status della categoria. La modalità
testuale premette una riga italiana e stampa lo stesso risultato strutturato.
Non c'è commit in progetto, progress stream o nuovo stato persistente.

## Ponte delle revisioni del progetto per il laboratorio

`GlifiStudioTextAnalytics.prepareProjectInput(session:sourceRevisionIDs:maximumTermCount:)`
legge revisioni immutabili del progetto e prepara gli input del nuovo client GUI
fuori dall'actor chiamante. Le fonti richieste devono essere uniche, non vuote e
presenti nello snapshot verificato. Si usano importer TXT/Markdown e
tokenizzazione italiana del prodotto, senza backend linguistico alternativo.

Il DTO `GlifiStudioProjectTextAnalysisInput` conserva ProjectID, generazione,
revisioni, digest di contenuto, documenti tokenizzati, unità per regole,
vocabolario selezionato, matrice e conteggio dei token. L'ordine delle fonti è
quello canonico di `sourceRevisionID`; righe, documenti e unità di codifica
seguono lo stesso ordine. Nessun nome di file è usato come etichetta di classe.

I limiti espliciti del ponte sono: **200 fonti**, **8 MiB** di byte originali
complessivi, **100 000 token lessicali** e **1 000 termini** per la matrice. Il
default di `maximumTermCount` è **200**. Si selezionano i termini per frequenza
globale decrescente, con spareggio lessicografico; il vocabolario selezionato è
quindi ordinato lessicograficamente. La matrice contiene conteggi grezzi.
Documenti tokenizzati e unità di codifica conservano invece il contenuto completo:
la selezione del vocabolario non tronca silenziosamente LDA, classificazione o
testi delle regole. I limiti della request canonica e del singolo operatore
restano applicabili dopo quelli del ponte.

L'esecuzione produce il risultato di sessione di GS-API-002. La GUI può esportare
separatamente **richiesta canonica JSON** e **risultato JSON**, nei formati già
definiti; non introduce un envelope di laboratorio. Progetto, generazione,
revisioni e digest restano ispezionabili nel contesto GUI, ma non sono aggiunti
automaticamente al file JSON del risultato: quel file da solo non è un export
completo della provenienza del progetto né un Artifact `.glifi`.

Il ponte non persiste nuovi oggetti, non cambia planner, formule o manifest
scientifici e non completa l'annotazione lemma/POS. Il suo contratto applicativo
segue ADR-0034 e GS-UX-001-17; le verifiche sono distinte da quelle storiche del
trasporto in GS-VER-162 e registrate in GS-VER-222.

## Verifica

[Fixture sintetiche condivise](../../Fixtures/TextAnalysis/v1/cases.json):
63 casi presenti e 40 tag distinti: 12 operazioni iniziali, nove avanzate e
19 profili KH. Le fixture comprendono preparazioni/scaling, contesti, tie
ordinali, PCA e SOM a due fasi, sette punteggi globali e associazione su DF,
scoring TF/IDF, Ward.D2 algebrico, Pearson/Yates e significatività per codice,
LR/FLR e preannotazioni, stato incrementale e κ.
La baseline a 15 casi resta registrata in GS-VER-162 e quella a 30 in
GS-VER-233/234, ciascuna sulla propria revisione. GS-VER-300 registra il gate
locale pre-merge superato del lotto a 19 profili KH, 63 fixture e 236 righe di
oracolo. GS-VER-301 conserva la precedente integrazione pubblicata fino a
`32b06f7`, con 54 fixture e 36 tag: non attesta le modifiche successive.
La versione integrata documentata in GS-VER-300 ha superato 771 test Core/Kit, 113 nativi,
63 fixture/189 controlli CLI e 2.816 dichiarazioni pubbliche controllate.
I gate precedenti restano circoscritti ai rispettivi checkpoint.
La successiva rifinitura è verificata localmente in
[GS-VER-305](../evidenze/GS-VER-305-rifinitura-kh.md): 795 test Core/Kit per
Debug, Release e ciascun sanitizzatore, 113 test nativi e 196 controlli CLI.
I conteggi storici restano riferiti ai rispettivi checkpoint. Non cambiano schema 1, i 40 tag o lo stato dei manifest.
Test Swift per identità canonica/default/UInt64, cancellazione e input ostili;
confronto integrale CLI/Kit entro 1e-12 assoluto e relativo, con controlli golden
indipendenti per i casi minimi, exit status, stdout/stderr e file speciali.
Evidenza storica in [GS-VER-162](../evidenze/GS-VER-162-parita-operatori-kit-cli.md);
nuovi profili e limiti effettivi in [GS-VER-300](../evidenze/GS-VER-300-completezza-funzionale-kh.md).

Il lotto originario dell’ampliamento è headless e transitorio secondo
[ADR-0035](../adr/0035-completamento-nativo-kh-coder.md);
nessuna promozione V6 esterna, nuova lingua, GUI, persistenza o dipendenza runtime
segue dall’aggiunta delle operazioni. Il gate completo è superato localmente nel perimetro dichiarato
in [GS-VER-233](../evidenze/GS-VER-233-completamento-kh-coder.md).

La riverifica storica GS-VER-234 ha eseguito 30 fixture e 95 controlli CLI,
inclusi rifiuti di grammatica e risorse, mantenendo schema/versione 1 e parità
numerica entro 1e-12. Quei test verificano anche identità canonica, byte sorgenti
e offset distinti per NFC/NFD. Esiti e limiti di quella revisione rimangono in
[GS-VER-234](../evidenze/GS-VER-234-riverifica-correttezza-completezza.md).
La verifica del nuovo incremento è distinta; una prova CLI non chiude il gate
complessivo né promuove gli operatori.

## Facciate dei laboratori espliciti (ADR-0041)

`GlifiStudioStatisticsWorkbench`, `GlifiStudioCoreOperators` e
`GlifiStudioEvaluationWorkbench` espongono gli operatori esistenti tramite DTO
Sendable e failure GlifiKit. Le richieste mantengono i parametri effettivi.
I comandi `statistics --request`, `operator --request`, `evaluation --request`
e `project-call --request` condividono il dispatch GlifiKit e ne mantengono
la parità continua secondo [GS-API-003](03-parita-continua-cli.md) e ADR-0036.
Conservano l'envelope CLI v1, il formato `.glifi` e il trasporto canonico
delle richieste `text-analysis` già definite.
Gli input tabellari usano spazi/TAB fra numeri, virgola oppure punto decimale
e nessun separatore delle migliaia; forma e domini sono validati prima del
calcolo. Gli evaluator ricevono annotazioni dichiarate. Il ponte di progetto
può conservare fonti senza token lessicali nel solo percorso temporale esplicito,
senza allentare le precondizioni delle analisi testuali.

Le analisi dirette del corpus riusano le API della sessione e i tipi persistiti
esistenti. La presentazione multivariata aggiunge metadati opzionali di
silhouette, selezione dei termini e digest del corpus, compatibili con la
decodifica dei DTO precedenti. Evidenza: [GS-VER-223](../evidenze/GS-VER-223-copertura-core-app.md).

Le app macOS espongono anche i nove tag di
`GlifiStudioAdvancedTextAnalysisRequest`: selezione LDA, comunità, layout,
foresta minima, ricerca MDS, SOM avanzata e i tre percorsi linguistici. Le viste
riusano il trasporto canonico e le facciate esistenti; disponibilità e provenienza
appartengono alla pipeline, distinta dal confronto con annotazioni gold. Simpson
e MDS ordinale sono scelte esplicite. Il laboratorio operatori acquisisce solo
campi/parametri applicabili: i controlli inattivi non influenzano l'ammissione
o l'identità del risultato.

L'ampliamento KH è headless e transitorio secondo
[ADR-0043](../adr/0043-completezza-funzionale-kh-pubblico.md); l'aggiunta delle
operazioni non promuove V6, nuove lingue automatiche, GUI o persistenza.
Il gate locale di [GS-VER-233](../evidenze/GS-VER-233-completamento-kh-coder.md)
resta riferito al suo perimetro storico. Anche GS-VER-234 e GS-VER-300 mantengono
revisioni, conteggi e limiti dei rispettivi checkpoint. GS-VER-300 attesta il
lotto pre-merge a 19 profili KH; GS-VER-301 la precedente unione pubblicata fino
a `32b06f7`. La verifica combinata allora eseguita è superata nel perimetro
GS-VER-300; la rifinitura successiva è verificata localmente in GS-VER-305.
