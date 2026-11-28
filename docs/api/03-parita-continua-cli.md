<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Parità continua fra GlifiKit e CLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-003 |
| Tipo | Contratto normativo della parità delle interfacce |
| Versione | 1.0.3 |
| Stato | Implementato; verifiche e limiti registrati in GS-VER-275 |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di mantenere sempre allineate CLI e Kit; ADR-0036 |
| Riferimenti | GS-API-001; GS-API-002; GS-DOR-275; ADR-0036 |

## Regola permanente

Ogni operazione utente pubblica di GlifiKit **DEVE** avere un percorso CLI con
gli stessi input, parametri, risultati e failure. Una modifica del contratto
pubblico **DEVE** aggiornare nello stesso cambiamento trasporto, mapping,
documentazione e verifiche di parità. Il dispatch e la validazione appartengono
a GlifiKit; la CLI adatta file, envelope e stream.

Il perimetro delle operazioni distingue i calcoli e gli accessi ai dati dalle
primitive di costruzione dei DTO, serializzazione, presentazione e lifecycle.
Queste ultime restano inventariate con una motivazione esplicita: chiusura di
una sessione, cancellazione di un handle e gestione delle condizioni di sistema
sono responsabilità del processo che esegue il comando. Non devono essere
usate come esclusione generica di una nuova operazione analitica.

I comandi precedenti conservano sintassi e default. Gli ingressi condivisi
descritti qui espongono anche configurazioni e famiglie prima accessibili
soltanto da Swift. Il trasporto non cambia formule, manifest scientifici,
planner o formato `.glifi`; uno stato `candidate` rimane tale.

## Ingressi condivisi

| Comando | Richiesta e operazione GlifiKit |
| --- | --- |
| `glifi statistics --request <file.json>` | Lo stesso `GlifiStudioStatisticsRequest` Codable di `GlifiStudioStatisticsWorkbench.evaluate` |
| `glifi operator --request <file.json>` | Lo stesso `GlifiStudioCoreOperatorRequest` Codable di `GlifiStudioCoreOperators.execute` |
| `glifi evaluation --request <file.json>` | `GlifiStudioEvaluationCommand.execute(json:)`, per valutazione linguistica, tempo e primitive lessicali |
| `glifi project-call <progetto.glifi> --request <file.json>` | `GlifiStudioProjectCommand.execute(json:session:)`, con la sessione aperta sul progetto indicato |
| `glifi profile --request <file.json>` | `GlifiStudioService.profileText(json:)`, da `GlifiStudioProfileRequest` |

È disponibile anche l'alias diretto
`glifi profile <fonte> --input-format plainText|markdown`. Il formato è esplicito
e non viene dedotto dall'estensione. La richiesta equivalente è:

```json
{
  "sourcePath": "/percorso/autorizzato/fonte.txt",
  "format": "plainText"
}
```

`statistics` e `operator` trasportano i DTO Codable completi, compresi i
parametri dei metodi e i campi che ne conservano i default. La CLI non seleziona
un sottoinsieme dei campi e non ricostruisce una seconda richiesta. Il formato
effettivo dei DTO è parte dell'inventario API controllato.

Anche l'importazione può ricevere un formato indipendente dall'estensione:
`glifi import <progetto.glifi> --input-format plainText|markdown <fonte>...`.
La forma preesistente che deduce il formato da TXT/Markdown rimane disponibile.
Il campo JSON `import.result.lastProfile` trasporta ora il DTO nativo completo:
`contentDigest`, `utf8ByteCount`, `characterCount`, `sentenceCount`,
`surfaceTokenCount`, `lexicalTokenCount`, `typeCount` e `topTerms`. I campi
precedenti sono conservati; byte, token di superficie e termini sono aggiunte
compatibili con i consumer che seguono la regola dei campi sconosciuti di
GS-API-001.

Con `--format json`, il risultato completo di GlifiKit è il campo `result`
dell'envelope GS-API-001 con `cliProtocolVersion = 1`, nome del comando e
`outcome = succeeded`. Le failure
mantengono envelope, categoria, exit status e separazione fra `stdout` e
`stderr` definiti in GS-API-001. `--format text` aggiunge la sintesi umana e
conserva il risultato JSON completo dei nuovi ingressi.

## Ammissione e valori

I file delle richieste **DEVONO** essere file regolari, letti da un descrittore
controllato. La CLI rifiuta link simbolici finali, FIFO e directory. Il limite
del JSON è **1 MiB**, con profondità massima **32**. Si rifiutano UTF-8 e JSON
non validi, chiavi duplicate anche dopo la decodifica degli escape, campi
sconosciuti e versioni incompatibili prima del calcolo. Restano applicabili
anche i limiti specifici dell'operazione nativa.

Anche gli ingressi legacy con file `--request` (piano/esecuzione/visualizzazione,
indagine, export, codifica e accordo) condividono l'ammissione su un solo
descrittore e il limite incrementale di 1 MiB. Una richiesta assente è
`invalidInput` con exit 3; permessi insufficienti sono `authorizationDenied`
e la richiesta oltre limite è `insufficientResources`, con i retry previsti
dalla tassonomia. GS-VER-302 registra le regressioni di processo di questi
ingressi; il contratto di JSON condiviso dei nuovi comandi rimane invariato.

Un campo opzionale per cui il codec omette il valore `nil` **DEVE** essere
omesso; non si usa `null` per introdurre un campo che il codec eliminerebbe.
`null` conserva invece il proprio significato dove appartiene al DTO, per
esempio nelle osservazioni o nei giudizi mancanti delle matrici statistiche.
I parametri omessi che hanno un default nel trasporto vengono risolti sullo
stesso valore dell'API nativa.

Gli interi, inclusi i seed `UInt64`, mantengono il valore esatto. I risultati
binari64 finiti conservano anche il segno dello zero. Stati infiniti e
indefiniti usano le rappresentazioni tipizzate del DTO; non si emettono `NaN`
o `Infinity` come numeri JSON. Le cancellazioni rimangono failure tipizzate e
impediscono la pubblicazione di un nuovo risultato.

## Valutazione, tempo e primitive lessicali

L'envelope della richiesta `evaluation` contiene:

```json
{
  "schema": "studio.glifi.evaluation-command-request",
  "schemaVersion": 1,
  "operation": "lemmas",
  "parameters": {
    "gold": ["cane", "andare"],
    "predicted": ["cane", "andato"],
    "forms": ["cani", "andavano"],
    "partsOfSpeech": ["N", "V"],
    "zeroPolicy": "zero"
  }
}
```

| Tag `operation` | Parametri |
| --- | --- |
| `classification` | `gold`, `predicted`, `zeroPolicy` opzionale |
| `lemmas` | `gold`, `predicted`, `forms` e `partsOfSpeech` opzionali, `zeroPolicy` opzionale |
| `boundaries` | Matrici `gold` e `predicted`, `utf8Lengths`, `zeroPolicy` opzionale |
| `named-entities` | Matrici di entità `gold` e `predicted`, `utf8Lengths`, `zeroPolicy` opzionale |
| `morphology` | Array di dizionari attributo/valore `gold` e `predicted`, `zeroPolicy` opzionale |
| `boundaries-with-text` | Matrici `gold` e `predicted`, `texts`, `zeroPolicy` opzionale |
| `named-entities-with-text` | Matrici di entità `gold` e `predicted`, `texts`, `zeroPolicy` opzionale |
| `temporal` | `documents` e `configuration`, con i DTO temporali GlifiKit completi |
| `lexical-observe` | `documents`, `checkpoints`, `preprocessingIdentifier` |
| `lexical-zipf` | `observations` con i tre campi lessicali precedenti, `firstRank`, `lastRank` inclusivi |
| `lexical-heaps` | `documents`, `checkpoints`, `preprocessingIdentifier` |
| `lexical-summary` | `observations`, `unitIdentifier`, `variance`, `probabilities` |
| `welch-anova` | Matrice numerica `groups` |

La policy omessa della valutazione è `undefined`. Un'entità conserva
`lowerBound`, `upperBound` e `type`; i confini sono in byte UTF-8. Le varianti
con `texts` applicano anche la verifica dei confini degli scalari Unicode del
Workbench. I documenti lessicali conservano `id`, `tokens` e l'ordine dichiarato;
i fit ricevono l'osservazione calcolata da quegli stessi dati. `variance` vale
`population` oppure `sample` e `probabilities` mantiene l'ordine del chiamante.

Il trasporto temporale usa la rappresentazione Codable dei DTO GlifiKit.
Le date civili hanno `year`, `month` e `day` e vengono validate senza
normalizzazione implicita. Gli enum con valori associati mantengono il nome
del caso e le etichette degli argomenti: per esempio
`{"civilMonth":{"year":2024,"month":2}}` e `{"missing":{}}`.
Un `Date` nativo è un numero binari64 di **secondi dal
2001-01-01T00:00:00Z**, secondo Codable di Foundation: per esempio
`{"instant":{"_0":0}}`. Non si interpreta quel numero come Unix time,
data civile o data ricavata dal nome del file. La configurazione dichiara
basis, granularità, origine, ampiezza e numero dei bucket, trattamento dei
mancanti e valori fuori dominio; una basis di istanti dichiara il fuso.

## Operazioni di progetto

Il progetto è selezionato dal proprietario della sessione, tramite l'argomento
CLI. La richiesta non può scegliere un altro package. Esempio di profilo con
opzioni esplicite:

```json
{
  "schema": "studio.glifi.project-command-request",
  "schemaVersion": 1,
  "operation": "corpus",
  "parameters": {
    "corpusOptions": {
      "diversityWindowSize": 50,
      "ngramSizes": [1, 2, 3]
    }
  }
}
```

```text
glifi --format json project-call progetto.glifi --request richiesta-corpus.json
```

I tag correnti sono `corpus`, `keyness`, `similarity`, `association`,
`dispersion`, `group-metric`, `posthoc`, `collocations`, `correlate`, `paired`,
`multivariate`, `recut-visualization`, `weighting`, `diversity`, `laws`, `summarize`, `ngrams`, `bm25`,
`window-collocations`, `window-network`, `network`, `source-text`, `passages`,
`character-count`, `export-visualization`, `prepare-input` e `temporal`.

Le analisi conservano tutti i parametri delle corrispondenti API di sessione.
`corpusOptions` espone `diversityWindowSize`, `ngramSizes`,
`maximumDocumentCount`, `maximumSourceByteCount`, `maximumVocabularySize`,
`maximumDistinctNGramCount` e `maximumNonZeroCellCount`. `keynessOptions`
espone `maximumHypothesisCount`, `lowExpectedCountThreshold` e
`confidenceLevel`. I membri opzionali omessi usano i default nativi.
I limiti operativi correnti valgono anche quando il profilo corpus è riutilizzato
da un Artifact: una cache calda non autorizza un risultato oltre budget.
Limiti sufficienti conservano l'identità scientifica e il riuso, senza
duplicare nodi per i soli budget (GS-DOR-330).

`source-text` e `character-count` ricevono `sourceRevisionID`; `passages`
aggiunge l'array `selections` delle selezioni tipizzate. `prepare-input`
riceve `sourceRevisionIDs`, `maximumTermCount` e `allowsEmptyLexicon`
opzionali. `temporal` riceve `assignments` con `sourceRevisionID`, `value`
e `provenance`, oltre a `terms` e `configuration` dichiarati.

`export-visualization` riceve `visualization` e `destinationPath`, un percorso
esplicito assoluto oppure relativo alla directory corrente del processo. Riusa il controllo di Artifact corrente,
staging, manifest e rifiuto della sovrascrittura di `exportVisualization`.
La ricevuta conserva conteggio dei file e digest del manifest effettivamente
scritto.
L'export della sessione controlla anche la corrispondenza di nodo, analisi e
metodo dichiarati con l'Artifact autorevole. Una contraddizione produce
`visual-export.source-mismatch`, categoria `invalidInput`, retry
`afterCorrection` e stato `unchanged`, senza pubblicare file. Restano
consentite le scelte di presentazione compatibili, compresi gli assi alternativi;
la verifica offline del bundle conserva il proprio contratto distinto
(GS-DOR-331).

## Unità del clustering gerarchico

`GlifiStudioMultivariateMethod.hierarchicalTerms(linkage:clusterCount:)`
seleziona il profilo `term-document-relative-frequency-v1`; la variante
`hierarchical` mantiene le unità documentali e i propri default. Entrambe
attraversano la medesima operazione `multivariate` di `project-call`.
Nel campo `method` il nuovo caso conserva il Codable completo:

```json
{"hierarchicalTerms":{"linkage":"ward","clusterCount":2}}
```

L'alias diretto equivalente è:

```sh
glifi --format json multivariate progetto.glifi --sources ID1,ID2 --method hac --unit terms --linkage ward --clusters 2
```

`--unit documents` è esplicito e equivalente al default preesistente.
`--unit` con altri valori o con un metodo diverso da `hac` è rifiutato.
Il risultato trasporta identità delle unità, appartenenze, fusioni e
`clusterUnitSourceRevisionIDs` per le foglie termine, senza sostituire
l'elenco documentale `sourceRevisionIDs`.

### Taglio del dendrogramma tramite lo stesso trasporto

Il metodo pubblico `GlifiStudioVisualizationBuilder.recutDendrogram`
ha il binding operativo `recut-visualization` di `project-call`
(caso Swift `recutVisualization`). Il parametro `visualization` contiene
la specifica visuale completa con `dendrogramTree`; il chiamante **DEVE**
fornire esattamente uno tra `clusterCount` e `maximumHeight`. Il secondo
campo corrisponde all'argomento Swift `height`. Fornire entrambi, nessuno,
un numero di gruppi fuori dominio o un'altezza non finita/negativa produce
la stessa failure del metodo nativo.

| Parametro di `project-call` | Argomento nativo | Effetto |
| --- | --- | --- |
| `visualization` | Primo argomento di `recutDendrogram` | Albero e specifica completi da validare |
| `clusterCount` | `clusterCount` | Partizione per numero di gruppi |
| `maximumHeight` | `height` | Include tutte le fusioni alla soglia, comprese le parità |

Una richiesta con schema `studio.glifi.project-command-request`, versione
1, operazione `recut-visualization` e questi parametri viene eseguita con:

```sh
glifi --format json project-call progetto.glifi --request taglio-dendrogramma.json
```

Il risultato è la stessa `GlifiStudioVisualization` ottenuta dalla chiamata
nativa: serie e sintesi aggiornate, albero, identità e lineage conservati.
L'operazione non modifica il progetto e non riesegue il corpus. Non è
esclusa dalla parità perché modifica la presentazione: richiesta, risultato
e failure attraversano il trasporto e le fixture di confronto.
La specifica risultante usa l'export esistente, con le verifiche autorevoli
del produttore quando si scrive tramite la sessione. GS-VER-342 registra le
nuove prove di parità e i loro esiti.

## Verifica continua

`make verify` estrae il symbol graph pubblico di GlifiKit dal compilatore e
lo confronta con la baseline controllata in
`Config/CLI/kit-api-baseline.json`. L'inventario comprende simboli pubblici,
firme, casi degli enum e membri dei DTO. Una nuova dichiarazione, rimozione o
firma modificata **DEVE** essere revisionata insieme al binding CLI; il gate
non aggiorna automaticamente la baseline.

Ogni funzione pubblica è classificata come operazione con binding CLI oppure
infrastruttura con motivo. Le esclusioni per costruzione, serializzazione,
presentazione e lifecycle **DEVONO** essere specifiche e revisionabili. Un
nuovo metodo operativo non può essere promosso a infrastruttura per evitare
una richiesta o una prova.

I test GlifiKit esportano richiesta effettiva e risultato completo. Il controllo
CLI esegue un processo indipendente per ciascuna fixture e confronta struttura,
parametri, valori, identificatori, digest e diagnostici; gli interi e le stringhe
sono esatti, i numeri binari64 usano tolleranza assoluta e relativa `1e-12`.
Le famiglie operative sono enumerate dai casi presenti nel symbol graph e
devono coincidere con le fixture, senza un conteggio fisso che possa omettere
una nuova operazione. Anche i casi di `text-analysis` sono confrontati con
l'inventario del compilatore. Il caso contenitore Swift `.advanced` viene
espanso nei casi di `GlifiStudioAdvancedTextAnalysisRequest`: il confronto
richiede l'uguaglianza fra tutti i tag piatti compilati e quelli delle fixture,
senza introdurre un'operazione JSON `advanced` o escludere casi nuovi.

Per l'export delle viste, ogni ricevuta viene verificata contro i propri byte
e manifest prima del confronto fra Kit e CLI. I payload devono coincidere
integralmente; nel confronto dei manifest si esclude soltanto `createdAt`,
che appartiene a due scritture distinte. Non si escludono contenuto scientifico,
digest dei payload o verifica della ricevuta.

I controlli negativi comprendono ammissione dei file, sintassi, versioni,
profondità, byte, chiavi duplicate/sconosciute, permessi e assenza di contenuti
sensibili nella diagnostica. Il superamento dimostra la parità dei contratti
e dei casi verificati; non costituisce una prova per ogni possibile input né
una nuova approvazione scientifica. Gli esiti osservati sono registrati in
[GS-VER-275](../evidenze/GS-VER-275-parita-continua-kit-cli.md).

## Flusso di ricerca persistente

`research-call` trasporta il catalogo `GlifiStudioResearchOperation` con gli
stessi DTO e failure delle API native: dataset, stato tipizzato, selezioni,
acquisizione, ripristino, variabili derivate e indagini descrittive. Il contratto
completo è [GS-API-006](06-lavoro-avanzato-persistente.md). L'inventario compilato
e le fixture native sono inclusi nello stesso gate permanente, senza escludere
le nuove operazioni dal controllo.
