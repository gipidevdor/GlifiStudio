<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Richieste analitiche testuali riproducibili

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-002 |
| Tipo | Contratto del trasporto analitico transitorio |
| Versione | 1.1.0 |
| Stato | Verificato localmente: baseline GS-VER-162 e ampliamento GS-VER-233 |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Prosecuzione esplicita RF-087 |
| Riferimenti | GS-API-001; GS-MET-001-23; RF-087; RQ-060; ADR-0032; ADR-0035; GS-DOR-162; GS-DOR-233 |

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
`single, complete, average`; Ward non è ammesso su dissimilarità generiche.
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
| `communities` | `graph, method` | `resolution=1, walkLength=4` |
| `graph-layout` | `graph, method` | `seed=0, maximumIterations=300, tolerance=1e-6`; `initialPositions` assente |
| `minimum-spanning-forest` | `graph` | nessuno |
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

## Identità e risultati

`canonicalData()` risolve i default, include schema/versione/operazione/seed e
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

Lo stato è per identificatore esatto secondo GS-VER-161; gli identificatori
ausiliari senza manifest dedicato (distanze, aggregazione, CV, reti, HAC) mantengono
`candidate`. Il trasporto non promuove metodi né completa la revisione esterna V6.

## Limiti e failure

Input esterno e rappresentazione canonica: massimo 1.048.576 byte.
Profondità JSON: massimo 32 contenitori. Prima della codifica canonica si applicano
250.000 elementi aggregati (righe, celle, token, etichette, gruppi, unità e
variabili) e 1 MiB di contenuti UTF-8 aggregati; matrici, documenti e unità hanno
al massimo 20.000 righe. Restano applicabili i limiti di lavoro e output del Core.

Chiavi sconosciute, duplicate anche con escape Unicode equivalenti, operazioni
ignote, tipi errati, default esplicitamente `null` e valori non finiti sono
rifiutati. Un futuro `schemaVersion` produce `incompatibleVersion`; limiti di
byte/profondità/collezioni producono `insufficientResources`. Cause del parser,
testo, regole e path non attraversano le failure. L'apertura distingue
`authorizationDenied` per permessi negati, `insufficientResources` per risorse
esaurite, `invalidInput` per path assente/non regolare o link finale e
`transientIO` per gli altri errori temporanei del filesystem.

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

## Verifica

[Fixture sintetiche condivise](../../Fixtures/TextAnalysis/v1/cases.json):
30 casi presenti: i 15 storici e 15 aggiuntivi per comunità, layout, Prim,
Simpson, ordinale/ricerca MDS, SOM esagonale, selezione LDA e pipeline linguistica.
La baseline storica a 15 casi resta registrata in GS-VER-162; l’esecuzione del
lotto ampliato e il nuovo gate sono registrati separatamente in GS-VER-233.
Test Swift per identità canonica/default/UInt64, cancellazione e input ostili;
confronto integrale CLI/Kit entro 1e-12 assoluto e relativo, con controlli golden
indipendenti per i casi minimi, exit status, stdout/stderr e file speciali.
Evidenza e limiti effettivi in [GS-VER-162](../evidenze/GS-VER-162-parita-operatori-kit-cli.md).

L’ampliamento è headless e transitorio secondo [ADR-0035](../adr/0035-completamento-nativo-kh-coder.md);
nessuna promozione V6 esterna, nuova lingua, GUI, persistenza o dipendenza runtime
segue dall’aggiunta delle operazioni. Il gate completo è superato localmente nel perimetro dichiarato
in [GS-VER-233](../evidenze/GS-VER-233-completamento-kh-coder.md).
