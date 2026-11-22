<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Runtime e risorse

| Campo | Valore |
| --- | --- |
| Identificatore | GS-RUN-001 |
| Tipo | Specifica di design del runtime |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline proposta; coefficienti da calibrare con benchmark su dispositivi |
| Riferimenti | GS-ANA-001; GS-DAT-001; GS-MET-001; GS-APL-015; ADR-0008; ADR-0018; GS-STD-001-17 |

## Scopo

Questa specifica governa ownership dei task, isolamento, backpressure, cancellazione,
progresso, parallelismo, memoria, I/O, pressione termica e benchmark di scala. Non
decide quali analisi siano scientificamente applicabili né quale risultato mostrare.

La correttezza prevale sul throughput: pressione di risorse può rallentare,
checkpointare o rifiutare lavoro, ma non produrre un Artifact falsamente completo.

## Modello di concorrenza

- Ogni operazione avviata dall'utente possiede una radice di structured concurrency.
  Task non strutturati sono ammessi solo per servizi di processo con owner,
  shutdown e test espliciti.
- Lo stato di presentazione e le API SwiftUI sono `@MainActor`. Parsing,
  indicizzazione, query e analisi non eseguono lavoro lungo sul Main Actor.
- Aggregate mutabili, catalogo del progetto, scheduler e cache hanno actor dedicati
  o ownership esclusiva documentata. Un actor non protegge I/O bloccante eseguito
  sul suo executor.
- Valori inviati tra domini sono `Sendable`, immutabili o snapshot. Escape
  `@unchecked Sendable` richiede ADR, invariant proof e stress test.
- Le pipeline usano `AsyncSequence` o canali bounded. Un producer non accumula
  batch illimitati se il consumer rallenta.

## Task tree

```text
UserOperation
├── ProjectSnapshot
├── PlanValidation
└── PlanExecution
    ├── Node A / partitions
    ├── Node B / partitions
    └── CommitArtifacts
```

Un nodo può parallelizzare tra documenti o partizioni solo se GS-MET dichiara che
merge e ordine preservano semantica e tolleranze. Il parallelismo intra-documento
non può spezzare sentence, token o contesti senza overlap e merge definiti. Nodi
indipendenti possono concorrere entro il budget globale.

## Cancellazione e progresso

Cancellazione è cooperativa, propagata dalla radice e verificata tra batch, prima
di allocazioni grandi e prima del commit. Una libreria non cancellabile viene
isolata in una unità piccola con timeout; non rende non cancellabile l'intero piano.

Il progresso usa unità di lavoro stimate e poi osservate, non timer. Ogni evento ha
operation ID, node ID, completed, total opzionale, fase e stato. La composizione è
ponderata dal cost model e monotona per revisione; quando il totale cambia, la UI
mostra indeterminatezza o ricalibrazione senza regredire percentuali in silenzio.

Stati terminali: `completed`, `completedWithCaveats`, `cancelled`, `failed` e
`resourceLimited`. La cancellazione non è registrata come errore di integrità.

## `ResourceBudget v1`

All'avvio di un'operazione il runtime fotografa memoria disponibile, thermal state,
low power mode, spazio temporaneo e policy dell'utente. Non identifica il chip dal
nome commerciale. La prima baseline conservativa, da promuovere soltanto dopo
GS-VAL/benchmark, è:

```text
macOS:  B = clamp(0.20 × availableMemory, 256 MiB, 4 GiB)
iPadOS: B = clamp(0.12 × availableMemory, 192 MiB, 1 GiB)

working set       ≤ 50% B
bounded buffers   ≤ 15% B
rebuildable cache ≤ 25% B
runtime reserve   ≥ 10% B
```

`availableMemory` è una stima di pressione osservata, non RAM fisica totale. Se il
minimo non è disponibile, l'operazione viene differita o rifiutata con stima e
rimedio. L'utente può imporre un cap più basso; non può superare i limiti sicuri
della piattaforma senza una modalità di sviluppo non distribuibile.

Il chunk iniziale è `min(8 MiB, B/64)` e si adatta tra 256 KiB e 16 MiB sulla base
di throughput e pressione. La larghezza iniziale è al massimo:

```text
min(activeProcessorCount, floor(workingSetBudget / estimatedPartitionBytes),
    8 su macOS oppure 4 su iPadOS)
```

Questi valori sono policy v1, non promesse prestazionali. Ogni variazione è
versionata e verificata su memoria, energia, termica e latenza interattiva.

## Backpressure, spill e cache

Una coda raggiunge high-water all'80%: sospende admission e riduce concurrency.
Alla soglia hard non alloca altro; checkpointa o restituisce `resourceLimited`.
Lo spill usa file preallocati nel container, blocchi con checksum e quote; il
formato dichiara endian e schema. `mmap` è un dettaglio selezionabile solo dopo
profiling e con accessi bounded.

Posting list, matrici e aggregati preferiscono rappresentazioni sparse. La cache è
content-addressed, ricostruibile, limitata LRU per costo e mai fonte di verità. La
cache non conserva contenuto sensibile oltre la vita del progetto senza policy
esplicita; l'eviction non invalida Artifact autorevoli.

## Memoria, spazio, energia e termica

Ogni admission usa uno snapshot immutabile di Low Power Mode, thermal state,
memory pressure e attività dell'app. Le variazioni arrivano da notifiche di
sistema e `DispatchSourceMemoryPressure`, mai da polling. `GlifiRuntimePolicy`
costituisce il riferimento eseguibile della decision table GS-APL-015; un flusso
lungo non può entrare nel prodotto prima dell'adattatore macOS event-driven.

In memory warning o pressione critica il runtime, nell'ordine:

1. interrompe nuove admission;
2. elimina cache non pinned e restringe buffer;
3. riduce parallelismo e priorità del lavoro non interattivo;
4. checkpointa partizioni valide;
5. cancella rami a bassa priorità con stato recuperabile.

Spazio temporaneo richiesto è stimato prima dell'esecuzione e riservato per quanto
possibile. Esaurimento disco non sostituisce il manifest di progetto. In stato
termico serious/critical o Low Power Mode, lavoro non richiesto dall'utente è
differito e Accelerate/Metal/Core ML sono usati solo se il profilo ne dimostra il
vantaggio complessivo.

L'app inattiva sospende utility e manutenzione, elimina timer e torna eleggibile
per App Nap. Eventuali attività `ProcessInfo` sono finite, owned e usano una policy
che consente idle system sleep; assertion permanenti o latency-critical sono
vietate.

## Priorità e responsività

Lavoro diretto dell'utente prevale su precomputazione e manutenzione. Priority
inversion è osservata con signpost e code bounded. La UI deve poter navigare
Artifact validi mentre un piano prosegue. Scrittura del progetto, annullamento e
recovery non attendono una coda di analisi a priorità inferiore.

## Matrice di benchmark

| Classe | Dimensione | Scopo | Target |
| --- | --- | --- | --- |
| S | 10 MiB, 100 documenti | Latenza interattiva e regressione CI | macOS/iPadOS |
| M | 1 GiB, 10.000 documenti | Streaming, indice e memoria | macOS/iPadOS capaci |
| L | 10 GiB, 100.000 documenti | Spill, recovery e lavoro prolungato | macOS; subset iPadOS |
| XL | 100 GiB, 1.000.000 documenti | Scalabilità e assenza di assunzioni RAM | stress macOS |
| DOC | PDF grandi/misti/scansionati | Parser, pagina, OCR, espansione | post-MVP |

Ogni fixture ha digest, generatore deterministico, struttura, distribuzione e
licenza. iPadOS usa un sottoinsieme compatibile col dispositivo, ma deve mantenere
gli stessi invarianti di correttezza e rifiuto sicuro. La classe XL non è una
promessa di tempo accettabile finché non esiste una soglia approvata.

Metriche minime: wall/CPU time, peak/resident/dirty memory, byte letti/scritti,
temporary space, energy impact, thermal transitions, first-result latency,
cancellation latency e cache reuse. Si registrano OS, device class, build e piano.

## Slice runtime implementata

L'esecutore MVP fotografa le condizioni e applica `GlifiRuntimePolicy` prima di
persistere il piano o avviare analisi. Un profilo che non ammette nuovo lavoro
produce `insufficientResources` senza modificare il progetto; profili ammessi
registrano nel risultato il profilo operativo e il cap di parallelismo. La slice
esegue intenzionalmente gli step in ordine canonico: il cap non viene scambiato per
parallelismo effettivo prima della prova di equivalenza richiesta da GS-MET.

`GlifiOperationProgress` valida revisioni, unità, totali e stime; la fase
`executing` usa i work unit del piano e non un timer. GlifiKit trasporta gli eventi
con un buffer `bufferingNewest(32)`, conserva sempre il terminale più recente e non
accumula un evento per token o byte. La ProjectSession ammette una sola esecuzione
analitica attiva, senza coda implicita. La task è posseduta dalla ProjectSession;
l'handle e `close()` propagano cancellazione, mentre `close()` attende la fine delle
task registrate prima di restituire.

Sono verificati admission nominale/critica, cancellazione prima del commit,
progressi monotoni, terminale unico, riuso degli Artifact e assenza di nuova
generazione al replay. Restano aperti progresso intra-nodo, checkpoint e
ExecutionRecord persistenti, adattatore event-driven per pressione memoria,
parallelismo provato, benchmark e pressure test su hardware reale.

## Conformità

- stress test con task scheduling variabile, cancellation injection e race tools;
- verifica che le code restino bounded e il Main Actor non esegua lavoro lungo;
- equivalenza degli Artifact tra larghezze, chunk e strategie di spill;
- memory/disk/thermal pressure injection senza corruzione del progetto;
- benchmark S obbligatorio in release; M/L/XL secondo il gate e hardware disponibile.
