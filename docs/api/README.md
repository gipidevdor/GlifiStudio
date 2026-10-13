<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Contratto GlifiKit e GlifiCLI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-001 |
| Tipo | Specifica normativa delle interfacce applicative e headless |
| Versione | 1.25.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-10-06 |
| Approvazione | Baseline pre-1.0 proposta; contract test richiesti prima della stabilizzazione |
| Riferimenti | GS-DOM-001; GS-DAT-001; GS-QRY-001; GS-ANA-001; GS-RUN-001; GS-SEC-001; ADR-0002; ADR-0019 |

## 1. Scopo e livello di stabilità

Questo documento governa il confine presentation-independent usato dalle app e
dalla CLI. Definisce operazioni, lifecycle, concorrenza, progressi, cancellazione,
failure, identificatori, compatibilità e protocollo headless. Non ridefinisce
dominio, semantica scientifica, persistenza o UX.

La baseline è `0.x`: `GlifiKit` è source-visible ai target del repository, ma viene
compilato e distribuito insieme alle app. Non è ancora un SDK di terze parti, non è
distribuito come framework binario e non promette ABI o module stability. Il build
setting per library evolution resta disattivato finché il modulo non viene
distribuito separatamente. Ogni dichiarazione `public` è comunque soggetta a questa
specifica e a contract test, così la stabilizzazione 1.0 non cristallizza dettagli
accidentali.

## 2. Moduli e dipendenze

```text
Glifi Studio macOS/iPadOS ──► GlifiKit ──► GlifiCore
GlifiCLI ───────────────────► GlifiKit ──► GlifiCore
```

- `GlifiKit` espone value type, protocolli e servizi applicativi; non espone SQLite,
  framework UI, URL interne, path, task o actor di implementazione.
- `GlifiCore` realizza dominio e motore headless; non importa SwiftUI/AppKit/UIKit.
- App e CLI traducono input/output, localizzazione e presentation state; non
  duplicano validazione, planner o semantica analitica.
- GUI e CLI devono ottenere stesso piano, ordine, failure e artefatti a parità di
  request, capability e policy.

## 3. Convenzioni Swift

Le API seguono le Swift API Design Guidelines: chiarezza al punto d'uso, nomi
semantici e documentazione di precondizioni, effetti e complessità. Tutti i valori
che attraversano isolation boundary sono `Sendable`; conformità `@unchecked
Sendable` richiede rationale, test di race e approvazione architetturale.

Value type pubblici sono immutabili. Collection e byte buffer massivi vengono
esposti come sequenze asincrone, handle bounded o riferimenti ad artefatti, non
copiati integralmente. Callback escaping non sono il modello primario: le
operazioni usano structured concurrency e `AsyncSequence` per gli eventi.

Il Main Actor appartiene alla presentazione. `GlifiKit` non presume il Main Actor e
non invoca closure del client sotto lock o transazione. Lo stato mutabile di una
sessione è actor-isolated; metodi read-only su value type restano nonisolated.

## 4. Identificatori e versioni

`ProjectID`, `CorpusID`, `InvestigationID`, `SourceRevisionID`, `ArtifactID`,
`AnalysisNodeID` e `OperationID` sono tipi distinti, opachi e `Hashable`, `Codable`,
`Sendable`. La loro rappresentazione testuale canonica è stabile dentro la major
del rispettivo schema; nome, path e posizione in una lista non partecipano
all'identità.

| Asse | Versione indipendente |
| --- | --- |
| API Swift | versione semantica del package `GlifiKit` |
| CLI | `cliProtocolVersion` e versione prodotto |
| Progetto | `formatVersion` GS-DAT |
| Query | `glifi-query-v1` |
| Analisi | ID/versione algoritmo e `AnalysisDescriptor` |
| Output | schema ExportManifest e schema del singolo formato |

Un ID sconosciuto è un errore `invalidInput` o `staleArtifact`, non una richiesta
di cercare un oggetto “simile”. Gli ID nei log vengono omessi o sostituiti con una
correlazione effimera.

## 5. Lifecycle del servizio

### 5.1 Servizio

`GlifiStudioService` è `Sendable` e rappresenta un ingresso leggero al motore. La
creazione non apre file, non avvia rete, non crea lavoro background persistente e
non acquisisce security scope. `status()` è idempotente, asincrono e non modifica
lo stato scientifico. La superficie corrente implementa `ready`, il profilo
bounded di TXT/Markdown autorizzati, la creazione/apertura di sessioni `.glifi`,
query testuali, planner/esecutore, profilo corpus bounded e confronto keyness sulla
generazione autorevole, storia Investigation ed export scientifico
PDF/Markdown/CSV/JSON.

### 5.2 Sessione di progetto

`GlifiStudioProjectSession` è actor-isolated e viene ottenuta da `createProject` o
`openProject`. Il prototipo corrente possiede il package coordinato, l'import
TXT/Markdown, la query bounded, planner/esecutore, `analyzeCorpus` e
`compareKeyness`, storia Investigation ed `exportInvestigation`; `close` è
idempotente, impedisce nuove operazioni, cancella le
esecuzioni possedute e ne attende la terminazione. Lo snapshot espone gli identificatori
opachi delle revisioni necessari a formare i gruppi senza rivelare path interni.
Cache handle e bookmark entreranno con le rispettive funzioni, senza cambiare la
semantica di chiusura.

Una sessione chiusa rifiuta nuove operazioni con codice stabile. L'eliminazione del
valore client non è un protocollo di chiusura e non autorizza salvataggi impliciti.
Più sessioni scriventi sullo stesso package non sono supportate nella 0.1; la
seconda apertura è read-only o fallisce senza modifiche.

## 6. Modello delle operazioni asincrone

Ogni operazione lunga ha `OperationID`, request immutabile, snapshot di capability
e policy, `startedAt` per audit locale, sequenza di eventi bounded e un solo esito
terminale:

```swift
public enum OperationEvent<Partial: Sendable>: Sendable {
    case progress(OperationProgress)
    case partial(Partial)
    case checkpoint(CheckpointReference)
}

public enum OperationOutcome<Value: Sendable>: Sendable {
    case succeeded(Value)
    case insufficientData(InsufficientDataReport)
    case cancelled(CancellationReport)
    case failed(GlifiFailure)
}
```

I nomi generici sopra restano la forma target per tutte le operazioni. La slice
analitica implementa `GlifiStudioAnalysisExecution`, uno
`AsyncThrowingStream<GlifiStudioAnalysisExecutionEvent, Error>` bounded con eventi
`progress` e un solo `completed`; le failure terminali sono sempre valori
`GlifiStudioFailure`. La ProjectSession ammette una sola esecuzione analitica
attiva e rifiuta l'accodamento implicito. Il contratto normativo è:

- un producer non continua oltre la vita della task/sessione proprietaria;
- gli eventi rispettano l'ordine causale per operazione e applicano backpressure;
- un evento parziale non è committato, completo o esportabile come risultato finale;
- l'esito terminale chiude la sequenza una sola volta;
- il completamento non precede durabilità e verifica del commit applicabile;
- una task Swift cancellata propaga la richiesta al motore e attende un punto
  cooperativo bounded, senza trasformarla in successo parziale.

## 7. Progresso e cancellazione

`OperationProgress` contiene fase tipizzata, unità (`bytes`, `documents`, `nodes` o
`indeterminate`), completati, totale opzionale e qualità della stima. Le percentuali
sono esposte solo con totale stabile; devono essere monotone dentro la fase, non
necessariamente fra fasi. Testo localizzato non attraversa `GlifiKit`.

La cancellazione è idempotente e best effort quanto alla latenza, non alla
correttezza. Dopo l'accettazione:

- import non committato non crea SourceRevision;
- analisi non committata non crea Artifact finale;
- checkpoint completo può restare riusabile ma non è presentato come risultato;
- export incompleto resta nello staging e viene eliminato;
- una transazione che ha già superato il commit point conclude come successo e
  riferisce che la cancellazione è arrivata dopo il commit.

## 8. Tassonomia delle failure

Ogni failure espone almeno `code`, `category`, `operation`, `retryDisposition`,
`retainedState`, `messageKey` e argomenti localizzabili non sensibili. Cause di
Foundation/SQLite/parser restano interne. Le categorie e lo stato valido sono:

| Categoria stabile | Significato | Retry | Stato che rimane valido |
| --- | --- | --- | --- |
| `invalidInput` | request/schema/range non valido | dopo correzione | stato precedente invariato |
| `unsupportedFormat` | tipo o variante non supportata | dopo conversione/update | stato precedente invariato |
| `insufficientData` | dati/qualità non sostengono l'operazione | dopo modifica dati | input e artefatti precedenti validi; nessun nuovo risultato |
| `transientIO` | I/O temporaneo/coordinamento non riuscito | bounded con backoff | ultima generazione committata |
| `authorizationDenied` | scope o permesso assente/revocato | dopo gesto utente | stato precedente; riferimento esterno unavailable |
| `insufficientResources` | memoria/disco/tempo/termica oltre policy | dopo cambio condizioni | commit precedente e checkpoint validati |
| `cancelled` | cancellazione cooperativa | su nuova richiesta | commit precedente; eventuale checkpoint validato |
| `staleArtifact` | input/versione non coincide più | ricalcolo | artefatto storico resta leggibile ma non corrente |
| `incompatibleVersion` | formato/API/schema futuro o non migrabile | update/export | file originale intatto, possibile read-only |
| `corruption` | digest/schema/integrità non verificabile | recovery esplicito | solo ultima generazione verificata, se esiste |
| `invariantViolation` | difetto interno o stato impossibile | mai automatico | validità non presunta; sessione fail-closed |

`insufficientData` e `cancelled` sono esiti di dominio, non eccezioni inattese; le
interfacce che non possono rappresentare outcome tipizzati usano comunque le
categorie omonime. La tabella è eseguibile in `GlifiFailureTaxonomy`: ogni `GlifiFailure` è
controllata in debug e `check-failure-taxonomy.py` controlla nel gate i siti con valori letterali
(GS-VER-119). Il testo UI non è codice d'errore. Nessun messaggio contiene
contenuto, query, path o nomi file.

Ogni `messageKey` **DEVE** risolversi in un testo leggibile. Un codice che non ha un messaggio
proprio ricade sul messaggio della **categoria**, vero per ogni codice della stessa classe:
l'interfaccia non mostra mai l'identificatore grezzo, che resta visibile soltanto nel dettaglio
diagnostico accanto a `code`, `category` e `operation`. `check-failure-messages.py` controlla nel
gate che ogni categoria abbia il proprio messaggio in italiano e inglese, che ogni chiave emessa da
GlifiKit sia tradotta e che le app risolvano il messaggio con il ripiego invece di stampare la
chiave (GS-VER-135).

## 9. Operazioni applicative 0.1

| Operazione semantica | Request minima | Esito | Stato |
| --- | --- | --- | --- |
| stato motore | nessuna | stato capability-neutral | Implementata |
| crea/apri/chiudi progetto | URL autorizzato, modalità | sessione o failure | Implementata e verificata per package locale `.glifi` v1 |
| importa | sessione, sorgenti, policy | SourceRevision e rapporto | TXT/Markdown bounded implementati e verificati; streaming e document model completo aperti |
| profila raccolta | revisioni TXT/Markdown della generazione e limiti | conteggi, distribuzioni e matrice sparsa con digest | Slice `corpus-profile-it-v1` implementata e verificata; metadati, duplicazioni e problemi di qualità del CollectionProfile completo restano aperti |
| pianifica | intent, scope/gruppi espliciti e budget bounded | AnalysisPlan, rationale e Artifact persistito | `planner-v2` (ADR-0025): profilo corpus e keyness più sette capability estese con decisioni e costi dichiarati (GS-VER-106) |
| esegui piano | stessa request pianificabile e condizioni runtime osservate | Artifact ordinati, interpretazione Evidence/Finding/Caveat, stato terminale, profilo operativo e progresso | Profilo corpus, keyness e capability estese con findings secondo le policy ADR-0026 (GS-VER-111); progresso intra-nodo, checkpoint ed ExecutionRecord aperti |
| crea/revisiona indagine | domanda, lingua, Interpretation Artifact; poi head e FindingID ordinati | Investigation, nuovo evento content-addressed e generazione | `created`/`editorialSelectionChanged`, diramazione e riapertura implementati; altri eventi cognitivi aperti |
| elenca indagini | generazione verificata | tutti gli head di ramo in ordine stabile | Implementata in Core, GlifiKit e CLI |
| analizza | generazione corrente e budget bounded nella slice | profilo corpus, AnalysisNodeID e ArtifactID persistiti | Slice descrittiva implementata con riuso dopo riapertura; l'interpretazione è prodotta dall'esecutore del piano, analisi temporale aperta |
| confronta keyness | due insiemi espliciti e disgiunti di SourceRevisionID | profili dipendenza e famiglia G-test/effect/BH persistiti | `keyness-gtest-fisher-ha-ci-bh-v2` bounded implementata con riuso dopo riapertura, selezione di Fisher e intervalli di confidenza (GS-VER-118) |
| interroga | testo `glifi-query-v1` oppure QueryAST v1 JSON, generazione di sessione e limiti | digest QueryAST e KWIC con SourceRevision/offset | Slice bounded TXT/Markdown con `sourceRanges`; ingresso AST in GS-VER-143, verifica nativa pendente; indice, metadati, annotazioni, cursor e streaming aperti |
| carica testo fonte | SourceRevisionID della generazione corrente | testo UTF-8 esatto della revisione incorporata | Implementata in GlifiKit per salto UI KWIC→fonte; non espone path interni |
| esporta | selezione, formato, destinazione | ExportReceipt + manifest | PDF/A-2u, Markdown, CSV e JSON implementati e verificati |

### 9.1 Operazioni analitiche derivate (incremento post-0.1)

Ogni operazione è bounded, persiste un Artifact riusabile con dipendenza esplicita dai profili
corpus o dalla richiesta, espone un risultato GlifiKit indipendente da GlifiCore e ha un comando
CLI con envelope JSON v1.

| Operazione GlifiKit | Comando CLI | Identità del risultato | Evidenza |
| --- | --- | --- | --- |
| `compareSimilarity` | `similarity` | `corpus-term-similarity-v3` | GS-VER-091, GS-VER-104 |
| `analyzeAssociation` | `association` | `corpus-document-term-association-v2` | GS-VER-092, GS-VER-103 |
| `analyzeDispersion` | `dispersion [--part]` | `corpus-term-dispersion-v2` | GS-VER-092, GS-VER-104 |
| `compareGroupMetric` | `group-metric` | `document-metric-group-comparison-v5` | GS-VER-095…100 |
| `postHocGroupMetric` | `posthoc` | `document-metric-pairwise-posthoc-v2` | GS-VER-098, GS-VER-099 |
| `correlateMetrics` | `correlate` | `document-metric-correlation-v2` | GS-VER-095, GS-VER-100 |
| `comparePairedMetrics` | `paired` | `document-metric-paired-comparison-v1` | GS-VER-100 |
| `analyzeCollocations` | `collocations` | `corpus-document-collocation-v1` | GS-VER-092 |
| `analyzeWindowCollocations` | `window-collocations` | `corpus-window-collocation-v2` | GS-VER-094, GS-VER-101 |
| `analyzeLexicalNetwork` | `network` | `corpus-document-cooccurrence-network-v2` | GS-VER-092, GS-VER-101 |
| `analyzeWindowNetwork` | `window-network` | `corpus-window-cooccurrence-network-v1` | GS-VER-101 |
| `analyzeTermWeighting` | `weighting --tf --idf --norm` | `corpus-term-weighting-v1` | GS-VER-115 |
| `analyzeNGramFrequencies` | `ngrams --unit [--n] [filtri]` | `corpus-ngram-frequencies-v1` | GS-VER-117 |
| `analyzeLexicalDiversity` | `diversity [--threshold]` | `corpus-lexical-diversity-mtld-v1` | GS-VER-116 |
| `rankDocumentsBM25` | `bm25 --query [--k1 --b]` | `corpus-bm25-ranking-v1` | GS-VER-115 |
| `analyzeMultivariate` | `multivariate --method` | `corpus-document-term-multivariate-v2` | GS-VER-102, GS-VER-108 |
| `assessCodingAgreement` | `agreement` | `coding-agreement-v2` | GS-VER-092, GS-VER-103 |

Parametri non validi falliscono con `GlifiStudioFailure` tipizzata; nessuna operazione corregge
parametri in silenzio. Seed, numero di ricampionamenti e soglie sono parte della richiesta o
costanti dichiarate nel risultato.

### 9.2 Viste dei risultati estesi

`visualizations(for:)` riceve un `GlifiStudioAnalysisExecutionResult` e restituisce una
`GlifiStudioVisualization` per ogni output che ha una vista dedicata (GS-MET-001-22, GS-VIZ-001):
grafico fattoriale per CA/PCA/LSA, dendrogramma per HAC, rete per il grafo a finestra e tabella per
le collocazioni a finestra. Ogni vista rilegge l'Artifact persistito tramite
`GlifiEngine.storedDerivedResult(_:artifactID:in:)`, senza ricalcolo e senza nuovi Artifact; se
l'Artifact non appartiene alla generazione corrente o ha uno schema diverso, l'operazione fallisce con
`derived-analysis.artifact-not-found` o `derived-analysis.artifact-schema-mismatch`. Il client CLI è
`glifi visualize <progetto> --request <richiesta.json>`, con la stessa richiesta di `execute`.
`GlifiStudioVisualizationBuilder.csv(_:)` restituisce la tabella equivalente in CSV RFC 4180 con
valori indipendenti dal locale (GS-VER-114). `exportVisualization(_:to:)` scrive tabella,
specifica e `visual-export-manifest.json` con SHA-256 in una nuova cartella, rifiutando Artifact
non correnti (GS-VER-124).

Le operazioni non implementate non devono essere simulate con placeholder né
esposte come disponibili da app, help CLI o capability discovery.

### 9.3 Storia qualitativa (ADR-0027)

`appendQualitativeChange(_:)` registra un cambiamento (`codebookRevised`, `categoryMapped`,
`segmentCoded`, `codingRetracted`, `memoAttached`) sulla testa corrente e restituisce la
proiezione; `qualitativeState()` la legge; `assessStoredCodingAgreement(codebookID:codebookRevision:coderIDs:)`
calcola e persiste l'accordo dalle codifiche. CLI: `glifi qualitative state|append|agreement`.
Un cambiamento concorrente fallisce con `qualitative.stale-history` (`staleArtifact`) e va
ripetuto (GS-VER-126, GS-VER-127).

`textSegments(sourceRevisionID:)` elenca le frasi del testo estratto con i loro intervalli;
`extractedCharacterCount(sourceRevisionID:)` ne dà la lunghezza in caratteri.
`passage(sourceRevisionID:selection:)` e `passages(sourceRevisionID:selections:)` risolvono una
selezione strutturata — `sentences(first:last:)`, `characters(start:end:)` o `bytes(start:end:)` —
in un intervallo del testo estratto allineato ai confini di carattere e con almeno un carattere
visibile; una selezione non valida fallisce con `qualitative.invalid-selection` (`invalidInput`,
`unchanged`) e la forma multipla fallisce per intero, senza liste parziali. CLI:
`glifi qualitative segments|passage` (GS-VER-129).

## 10. Contratto GlifiCLI

La CLI è un client di `GlifiKit`, non un accesso laterale allo store. Forma target:

```text
glifi [--format text|json] [--locale <tag>] [--no-progress] <command>
glifi status
glifi project create|info|validate <project>
glifi import <project> <source>...
glifi plan <project> --request <json-file>
glifi execute <project> --request <json-file>
glifi visualize <project> --request <json-file>
glifi investigation create <project> --request <json-file>
glifi investigation select <project> --request <json-file>
glifi investigation list <project>
glifi analyze <project>
glifi keyness <project> --target <source-revision-id,...> --reference <source-revision-id,...>
glifi query <project> (--text <query> | --ast <query.json>)
glifi export <project> --request <json-file> --output <path>
glifi qualitative state|append|agreement <project> [opzioni]
glifi qualitative segments <project> --source <source-revision-id>
glifi qualitative passage <project> --source <source-revision-id> --sentences <primo>-<ultimo>|--characters <inizio>-<fine>|--bytes <inizio>-<fine>
```

Sono disponibili `status`, `project create`, `project info`, `project validate`,
`import` per TXT/Markdown, `query --text|--ast`, `plan --request`, `execute --request`,
`investigation create|select|list`, `analyze`, `keyness` ed `export`. Accettano
`--format text|json`;
l'envelope JSON ha `cliProtocolVersion = 1`. La query JSON include generazione,
digest canonico, coordinate `extractedUTF8`, intervalli `sourceBytes`, conteggio
degli scope selezionati, righe KWIC e troncatura. `analyze` restituisce identità
dei metodi, digest del corpus, conteggi, diversità, termini, n-grammi e matrice
sparsa della generazione. `keyness` richiede revisioni target/riferimento separate
da virgola e restituisce popolazioni, identità G-test/p-value/effect/BH,
diagnostica, valori completi, digest, generazione sorgente/generazione committata,
`ArtifactID` e `AnalysisNodeID`. `plan --request` ed `execute --request` leggono al massimo 1 MiB di JSON,
risolvono lo scope, persistono decisioni/step e restituiscono costi, dipendenze,
caveat, fallback ed esclusioni con identificatori stabili. `execute` materializza
gli step ammessi, emette progresso testuale su `stderr` salvo `--no-progress` e
restituisce un solo risultato JSON su `stdout`. Il risultato include ArtifactID e
AnalysisNodeID dell'interpretazione, Evidence, Findings, Caveat, assessment per
famiglia, fattori di ranking, soppressioni e l'eventuale esito strutturato
`insufficientEvidence`; chiavi semantiche e argomenti attraversano il confine al
posto del testo localizzato. Le request Investigation sono schema-versioned,
bounded a 1 MiB e usano soltanto ID canonici; `list` restituisce ogni head di ramo.
`export` riceve head, formati, locale e fuso in una request bounded, crea una nuova
directory con il sottoinsieme richiesto di `report.json`, `report.md`, `report.pdf`,
`findings.csv`/`evidence.csv` ed `export-manifest.json` e restituisce un receipt
soltanto dopo la verifica dei digest. File QueryAST, streaming generale e
sovrascrittura di export restano fail-closed. L'invocazione senza
argomenti resta alias temporaneo dello smoke test e stampa `GlifiCore pronto`;
prima del protocollo CLI 1.0 deve diventare `help` o essere rimossa con nota di
migrazione.

### 10.1 Stream

- `stdout` contiene soltanto il risultato richiesto; in JSON esattamente un
  documento UTF-8 terminato da newline.
- `stderr` contiene diagnostica e, solo se richiesta, progressi; mai contenuto del
  corpus. In modalità JSON una failure produce un solo envelope JSON su `stderr`.
- prompt interattivi sono vietati quando stdin non è un TTY o `--format json` è
  attivo; autorizzazioni e conferme mancanti causano failure esplicita.
- ordine di array e righe è definito dal contratto del comando; locale e terminale
  non cambiano numeri, ID, date o chiavi macchina.

Envelope minimo:

```json
{
  "cliProtocolVersion": 1,
  "command": "status",
  "outcome": "succeeded",
  "result": { "status": "ready" }
}
```

### 10.2 Exit status

| Codice | Categoria |
| ---: | --- |
| 0 | successo |
| 2 | uso/sintassi CLI non valida |
| 3 | `invalidInput` |
| 4 | `unsupportedFormat` |
| 5 | `insufficientData` |
| 6 | `transientIO` o `authorizationDenied` |
| 7 | `insufficientResources` |
| 8 | `cancelled` |
| 9 | `staleArtifact` |
| 10 | `incompatibleVersion` |
| 11 | `corruption` |
| 70 | `invariantViolation` o difetto interno |

I codici 12–69 sono riservati. Una pipe chiusa non converte un'operazione già
committata in failure scientifica, ma la CLI termina con errore di output.

## 11. Determinismo e riproducibilità

### Ingresso QueryAST

`GlifiStudioProjectSession.query(canonicalAST: Data)` e `query --ast <file.json>`
riusano il QueryAST `studio.glifi.query-ast`, versione 1, grammatica
`glifi-query-v1`. `--ast` e `--text` sono alternative esclusive; nessuna delle due
modifica la generazione del progetto. L'input JSON può avere spazi o chiavi in
ordine diverso: il digest deriva sempre dalla ricodifica canonica del Core.

Il limite è 64 KiB di JSON, 1.024 nodi e profondità 32 (radice a zero). La CLI
richiede un file regolare, rifiuta symlink terminali e FIFO e limita la lettura
anche se il file cresce. JSON malformato/struttura non decodificabile produce
`query.invalid-ast` (exit 3); schema/versioni incompatibili
`query.incompatible-ast` (10); budget ecceduto mantiene la failure specifica
`query.*-limit-exceeded` (7). File non regolare produce
`query.ast-not-regular-file` (3), errore I/O `query.ast-unreadable` (6).
Queste failure non riportano path, contenuto né dettagli del decoder.
Vedere [GS-VER-143](../evidenze/GS-VER-143-ingresso-queryast.md) per copertura e
limiti della verifica.

Esempio equivalente a `--text normalized:due`:

```json
{"schema":"studio.glifi.query-ast","schemaVersion":1,"grammarVersion":"glifi-query-v1","root":{"type":"term","field":"normalized","value":"due","matchMode":"exact"}}
```

### Identità dei risultati

Ogni comando macchina accetta request versionata e può emettere il piano canonico
prima dell'esecuzione. A parità di input, capability e policy, piano, ordine e
descriptor sono identici; timestamp, durata, OperationID e path non partecipano
all'identità semantica. Un backend D1/P1 dichiara tolleranze e seed secondo GS-MET.

Le slice `analyze`, `keyness` ed `execute` producono payload schema-versioned,
descriptor e Artifact persistiti. Prima del calcolo ricostruiscono lo stesso nodo
semantico e, se la catena è valida, decodificano il payload content-addressed senza
ripetere tokenizzazione o interpretazione. EvidenceID e FindingID dipendono
soltanto dalla struttura canonica, non da locale o OperationID. `export` incorpora
AnalysisDescriptor e riferimenti ValidationManifest/ExportManifest; `query` dovrà
ancora referenziare un descriptor quando diventerà un Artifact. `--format json` usa
chiavi inglesi stabili;
la lingua UI/CLI modifica solo messaggi umani, non protocollo o analisi.

## 12. Evoluzione e compatibilità

- Durante `0.x`, una modifica incompatibile richiede changelog, contract test e
  aggiornamento coordinato di tutti i client del repository.
- Dopo 1.0, SemVer governa la compatibilità sorgente dell'API pubblica; rimozioni
  richiedono deprecazione e major salvo vulnerabilità motivata.
- La distribuzione binaria separata richiede ADR, `BUILD_LIBRARY_FOR_DISTRIBUTION`,
  module interface test e politica ABI prima della prima release interessata.
- Enum resilienti destinati a client esterni prevedono casi sconosciuti; tipi
  persistiti non riusano automaticamente la versione dell'API.
- CLI mantiene exit code, envelope e semantica dentro `cliProtocolVersion`; nuovi
  campi JSON sono additivi e i consumer devono ignorare quelli sconosciuti.

## 13. Sicurezza e limiti

Request, path e file seguono GS-SEC-001. API e CLI non restituiscono bookmark,
token sandbox, path interni, stack trace o cause sensibili. Ogni operazione accetta
o deriva un ResourceBudget; assenza di budget non significa illimitato. La CLI non
abilita rete, entitlement o bypass del sandbox della build applicativa.

## 14. Verifica e gate

- API surface diff e documentazione simboli per ogni dichiarazione pubblica;
- compile-time contract test `Sendable` e isolation con strict concurrency;
- equivalenza API/CLI/GUI per request, piano, ordine, failure e manifest;
- cancellazione a ogni checkpoint e nessun task orfano;
- golden test di exit code, stdout/stderr ed envelope JSON;
- compatibilità fra versione corrente e precedente dichiarata;
- fuzz di decoder request e limiti su ogni collection/stringa;
- matrice di conformità aggiornata senza promuovere operazioni non implementate.

## 15. Riferimenti tecnici

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Swift — Library Evolution](https://www.swift.org/blog/library-evolution/)
- [Swift — ABI Stability and More](https://www.swift.org/blog/abi-stability-and-more/)
