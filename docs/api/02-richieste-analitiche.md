<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Richieste analitiche testuali riproducibili

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-002 |
| Tipo | Contratto del trasporto analitico transitorio |
| Versione | 1.1.0 |
| Stato | Trasporto e ponte di progetto verificati automaticamente; limiti in GS-VER-162 e GS-VER-222 |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Prosecuzioni esplicite RF-087 e GUI; ADR-0034 |
| Riferimenti | GS-API-001; GS-MET-001-23; RF-087; RQ-060; ADR-0032; ADR-0034; GS-DOR-162; GS-DOR-222 |

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

Metodi MDS: `classical, metric, kruskal, sammon`. Distanze:
`jaccard, dice, cosine, euclidean, manhattan`. Linkage:
`single, complete, average`; Ward non è ammesso su dissimilarità generiche.
Parametri numerici invalidi conservano le failure dell'operatore; non sono corretti
silenziosamente. LDA riporta perplexity predittiva in-sample, non held-out.

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

Il client nativo può ispezionare lo stesso risultato mediante il payload
tipizzato `GlifiStudioTextAnalysisPayload`, senza decodificare o reinterpretare
il JSON. `GlifiStudioCodeCrosstab.codes` conserva le identità delle colonne per
la presentazione nativa; il formato JSON v1 resta quello precedente.

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
15 casi, comprese le quattro varianti MDS.
Test Swift per identità canonica/default/UInt64, cancellazione e input ostili;
confronto integrale CLI/Kit entro 1e-12 assoluto e relativo, con controlli golden
indipendenti per i casi minimi, exit status, stdout/stderr e file speciali.
Evidenza e limiti effettivi in [GS-VER-162](../evidenze/GS-VER-162-parita-operatori-kit-cli.md).

## Facciate dei laboratori espliciti (ADR-0035)

`GlifiStudioStatisticsWorkbench`, `GlifiStudioCoreOperators` e
`GlifiStudioEvaluationWorkbench` espongono gli operatori esistenti tramite DTO
Sendable e failure GlifiKit. Le richieste mantengono i parametri effettivi;
gli esiti JSON di sessione non cambiano il protocollo CLI, il formato `.glifi`
o il trasporto canonico delle richieste analitiche già definite.
Gli input tabellari usano spazi/TAB fra numeri, virgola oppure punto decimale
e nessun separatore delle migliaia; forma e domini sono validati prima del
calcolo. Gli evaluator ricevono annotazioni dichiarate. Il ponte di progetto
può conservare fonti senza token lessicali nel solo percorso temporale esplicito,
senza allentare le precondizioni delle analisi testuali.

Le analisi dirette del corpus riusano le API della sessione e i tipi persistiti
esistenti. La presentazione multivariata aggiunge metadati opzionali di
silhouette, selezione dei termini e digest del corpus, compatibili con la
decodifica dei DTO precedenti. Evidenza: [GS-VER-223](../evidenze/GS-VER-223-copertura-core-app.md).
