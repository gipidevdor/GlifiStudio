<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Benchmark

## Betweenness e cammini estremi (GS-VER-174)

```sh
swift run -c release --package-path Packages/GlifiCore GlifiBenchmark --betweenness-numerics
```

Tre grafi ordinari: sparso e catena da 600 nodi, 160 diamanti concatenati
(481 nodi). Un warm-up e cinque campioni; SHA-256 di tutti gli input e
punteggi fuori timer. La modalità rifiuta Debug. Archiviare la baseline
prima della patch, confrontare senza compilazioni concorrenti e dichiarare
RSS, ambiente e termica. Gli estremi sono verificati separatamente con
formule indipendenti; nessuna soglia o promozione scientifica.

## Layout e visite analitiche (GS-VER-173)

```sh
swift run -c release --package-path Packages/GlifiCore GlifiBenchmark --analysis-storage-optimization
```

Le sezioni opzionali sono
`factorization`, `graph` e `resampling`; la modalità rifiuta Debug.
I nove casi coprono NMF ordinaria/wide/tall, centralità armonica su tre topologie
con nodi in ordine non banale, bootstrap con tre lunghezze di blocco.
Un warm-up e cinque campioni; input/configurazione e ultimo output sono
controllati integralmente fuori timer. Le chiamate precedenti non sono
confrontate singolarmente. Archiviare il binario e i sorgenti di baseline prima
dei kernel; confrontare in processi separati senza build concorrenti.
Registrare tempi, RSS dell'intera sezione, ambiente, termica e alimentazione.
Nessuna soglia locale diventa gate né sostituisce la validazione scientifica.

## Query sparse e silhouette (GS-VER-172)

```sh
swift run -c release --package-path Packages/GlifiCore \
  --scratch-path /tmp/GlifiAlgorithms172/SwiftPM \
  GlifiBenchmark --sparse-analysis-optimization
```

Aggiungere `bm25` o `silhouette` per isolare una sezione; senza sezione vengono
eseguiti dieci casi. Questa modalità rifiuta la configurazione Debug. Il
confronto candidato copre sette distribuzioni di query BM25 e tre partizioni
per silhouette, su generatori sintetici deterministici. Ogni caso prevede un
batch di warm-up e cinque batch misurati; il tempo è normalizzato per chiamata
e la dimensione fissa del batch è registrata nella ricetta. Setup, digest
input/configurazione e controlli completi del risultato restano fuori timer.
Il digest SHA-256 dell'output copre tutti i bit dei punteggi BM25 o delle
silhouette e della loro media, sull'ultima chiamata dell'ultimo batch;
warm-up e chiamate precedenti non sono confrontati singolarmente. Input e
configurazioni sono nei digest o nella ricetta esplicita del caso.

Conservare eseguibile e inventari della baseline prima dei cambi ai kernel,
poi eseguire baseline e candidato in sequenza senza build o misure concorrenti.
Registrare mediana, minimo, massimo, hardware, toolchain e stato termico;
`/usr/bin/time -l` per sezione misura il picco dell'intero processo, inclusi
generatori e digest. GS-VER-172 riporta due passate incontese con tutti i
controlli identici: BM25 per query grandi migliora 5,88–24,44× e silhouette
1,86–15,02× nei casi misurati. Query piccole/OOV non mostrano un beneficio
stabile; picco RSS BM25 +0,734 MiB e silhouette −0,203 MiB. Il primo tentativo
con regressione silhouette è conservato; il gate completo resta in corso.
Nessuna soglia locale diventa gate.

## Raffinamento numerico e memoria (GS-VER-170)

```sh
swift run -c release --package-path Packages/GlifiCore \
  --scratch-path /tmp/GlifiAlgorithms170/SwiftPM \
  GlifiBenchmark --analysis-refinement
```

Aggiungere `descriptive`, `temporal`, `factorization` o `weighting` per isolare
una sezione. I quattordici casi coprono descrittive con valori ripetuti,
continui, quasi ordinati e mancanti, aggregazioni temporali sparse/dense,
NMF su tre forme/ranghi e TF-IDF/TF/BM25 su 256.000 celle sparse.
Un warm-up, cinque campioni, mediana/minimo/massimo; setup e controlli fuori
timer. Per caso si controlla l'intero ultimo risultato, inclusi metadati e
storia NMF; warm-up e campioni precedenti non sono confrontati singolarmente.
Input e configurazioni sono nei digest o dichiarati nella ricetta (ponderazioni).
Il comando deve usare Release: l'harness non rifiuta Debug. Le fixture con cardinalità tardiva e mancanti espongono
anche i costi dei fallback. `/usr/bin/time -l` sulla singola sezione osserva
il picco del processo, non le sole allocazioni del kernel.

Conservare l'eseguibile Release di baseline prima delle modifiche; eseguire
baseline e candidato in sequenza, senza misure o build concorrenti. Registrare
inventari SHA-256 dei sorgenti, hardware, toolchain e stato termico. Il rapporto
GS-VER-170 dichiara regressioni, tentativi scartati e limiti; nessuna soglia
locale diventa gate e non vengono misurati energia, UI o I/O fisico.

## Ottimizzazione degli algoritmi (GS-VER-169)

`swift run -c release --package-path Packages/GlifiCore GlifiBenchmark --analysis-optimization`
esegue il confronto dei kernel analitici. Aggiungere `multivariate`, `graph`,
`metadata` o `lexical` per eseguire soltanto una sezione e misurarne separatamente
il picco RSS con `/usr/bin/time -l`.

I tredici casi coprono HAC single/average/Ward (400×12), K-means (4.000×24,
8 gruppi), TextRank/LexRank (480 frasi di 32 token), PageRank (8.000 nodi e
72.000 archi), aggregazione temporale (20.000 fonti), morfologia (50.000 token),
lemmi stratificati (100.000 token), distribuzioni lessicali (500.000 token),
Heaps (100.000 checkpoint) e descrittive (500.000 osservazioni).

Ogni generatore è sintetico, deterministico e identificato con checksum input;
costruzione input e checksum output sono fuori dall'intervallo cronometrato.
Una esecuzione di warm-up precede cinque campioni; il rapporto conserva mediana,
minimo, massimo, hardware, OS e stato termico iniziale. L'evidenza controllata
GS-VER-169 documenta confronto prima/dopo, identità dei risultati, configurazione
Release e limiti. Il picco RSS comprende l'intera sezione, inclusi setup e
checksum: non è una misura isolata delle allocazioni di un singolo kernel.

Nessuna soglia prestazionale diventa gate con questo confronto locale.

Questa cartella conterrà benchmark riproducibili per throughput, latenza, memoria, I/O, energia e selezione dei backend su hardware Apple.

Ogni benchmark deve dichiarare requisito, dataset o generatore, dispositivo, sistema operativo, stato termico, configurazione, warm-up, numero di campioni, statistica, soglia e modalità di confronto. I risultati generati non vanno versionati salvo evidenza controllata esplicitamente approvata.

Non inserire corpus reali, dati personali o dataset con licenza incompatibile. Prima di adottare Accelerate, Metal, Core ML o un backend specializzato come scelta predefinita, collegare qui l'evidenza prevista dallo standard prestazionale.

## Benchmark di scala delle analisi (GS-VER-109)

`swift run -c release --package-path Packages/GlifiCore GlifiBenchmark` esegue quattro misure con dati
generati da `SplitMix64-v1` con seed dichiarati (un warm-up, cinque campioni, mediana, minimo e
massimo in secondi) e stampa un rapporto JSON con dispositivo, sistema, stato termico iniziale,
configurazione e un controllo di correttezza per ciascuna misura:

| Misura | Requisito | Generatore | Controllo |
| --- | --- | --- | --- |
| SVD troncata 2 000×2 500, rango 10 | RF-038 | seed 1, 50 000 conteggi 1…9 | residuo relativo della prima tripletta |
| Betweenness pesata, 2 000 nodi, 8 000 archi | RF-039 | seed 2, pesi uniformi in [0,1; 5] | somma delle betweenness |
| Louvain, 20 000 nodi, 80 000 archi | RF-039 | seed 3, blocchi da 200 nodi, 90 % archi locali | modularità (attesa circa 0,89) |
| Riuso selettivo dopo importazione estranea | RF-011, ADR-0028 | seed 4, 40 documenti di 400 forme, gruppo di 20 | stesso `ArtifactID`, Artifact conservati, rapporto freddo/riuso |

Nessuna soglia è ancora vincolante: i valori osservati sono una linea di base da confermare su
hardware di riferimento in G4 (ADR-0024). I risultati non vengono versionati; le evidenze
GS-VER-109 e GS-VER-134 riportano le prime osservazioni.

## Operatori delle famiglie KH Coder (GS-VER-160)

Usare `swift run -c release --package-path Packages/GlifiCore GlifiBenchmark --text-operators`
per il confronto scalare/vDSP e le misure MDS, SOM, classificazione e LDA. Il rapporto
riporta checksum/diagnostica, hardware, sistema, stato termico, warm-up e cinque
campioni. L'equivalenza della SOM aggregata è verificata contro la formula diretta;
il campionatore LDA contro l'integrazione esatta su corpus minimo. Nessuna soglia
è introdotta senza baseline e hardware di riferimento.

## Letture verificate e termine query normalizzato (GS-DOR-200/201)

```sh
swift run -c release --package-path Packages/GlifiCore \
  --scratch-path /tmp/GlifiStudioOptimize200-cache/SwiftPM \
  GlifiBenchmark --validated-reads-query
```

Il modo dedicato evita SVD, Louvain e gli altri benchmark del comando predefinito.
Misura soltanto API di GlifiCore, senza dipendenze da GlifiKit o promesse di
prestazioni dell'interfaccia:

- `sourceData` del progetto e del recovery read-only, su fonti UTF-8 sintetiche
  di 1, 8 e 32 MiB;
- `artifactData`, su payload JSON sintetici delle stesse taglie più l'involucro
  canonico;
- valutazione di un termine `normalized` assente su 100.000 token Unicode.

Creazione del package, importazione, Artifact, apertura del recovery,
tokenizzazione e parsing restano fuori dal timer. Ogni misura usa un warm-up e
sette campioni; i risultati vengono consumati e confrontati esattamente dopo
aver fermato il timer. Il rapporto JSON riporta checksum, identità dei sorgenti
produttivi e del benchmark, hardware, sistema, stato termico e Low Power Mode
iniziali/finali, campioni grezzi, mediana, minimo e massimo.

La cache del sistema operativo è dichiaratamente calda; non si misura I/O fisico
a freddo. Eseguire baseline e candidato senza altre build o benchmark concorrenti
e conservare soltanto miglioramenti osservati con risultati identici. Nessuna
soglia diventa vincolante. Le fixture vengono rimosse all'uscita; lo scratch può
essere riusato serialmente per misure, test e gate dello stesso incremento.

## Coordinate, token speciali ed export CSV (GS-DOR-202/203/204)

Le prove di equivalenza in `GlifiCoreTests` comprendono un modo di misura
esplicito, senza esporre API di benchmark nel prodotto. Compilare in Release con
testability abilitata per il renderer interno e invocare **separatamente** i tre
filtri, mantenendo la stessa copia dei sorgenti e lo stesso scratch:

```sh
GLIFI_PIPELINE_BENCHMARK_DIRECTORY=/tmp/GlifiPipelineReports \
swift test -c release -Xswiftc -enable-testing \
  --package-path Packages/GlifiCore \
  --scratch-path /tmp/GlifiPipelineBuild \
  --filter pipelineOptimizationSpanMap
```

Ripetere con `--skip-build` e i filtri `pipelineOptimizationTokenizer` e
`pipelineOptimizationCSV`; non eseguire il filtro comune in parallelo. La
variabile di ambiente attiva i workload grandi e i JSON per scenario; senza
di essa gli stessi test eseguono regressioni piccole contro il riferimento.
La configurazione Debug rifiuta la misura esplicita.

Gli scenari includono ricerca e composizione SpanMap, costo di costruzione
della mappa, punteggiatura senza spazi a taglia crescente, controlli Unicode e
email/URL, e report CSV con riferimenti Evidence condivisi. Un warmup e sette
campioni grezzi; preparazione delle fixture, riferimenti, confronto completo e
checksum restano fuori timer. Il tokenizer include la propria preparazione;
la costruzione della mappa è misurata separatamente dal lookup.

Registrare inventari dei sorgenti, hardware, memoria fisica, sistema, toolchain,
stato termico e Low Power Mode. Confrontare gli output completi e gli hash,
senza altre compilazioni o misure concorrenti. L'eventuale `time -l` riguarda
l'intera invocazione di test, inclusi i riferimenti: non misura la memoria del
singolo kernel. Le prove non misurano energia, UI o I/O fisico a freddo e non
introducono soglie di rilascio.

## DAG, proiezione CA e digest (GS-DOR-205/206/207/208)

Il target interno `GlifiBenchmarkTestSupport` mantiene un unico protocollo per
CoreTests e KitTests. Non è un prodotto SwiftPM e non compare nelle dipendenze
dei prodotti dell'app. Il corpo del helper preesistente resta invariato.

Usare Release con `-Xswiftc -enable-testing`, una directory esplicita tramite
`GLIFI_PIPELINE_BENCHMARK_DIRECTORY` e tre invocazioni seriali dei filtri
`domainOptimizationGraph`, `domainOptimizationProjection` e
`domainOptimizationDigest`. Fixture, riferimenti, uguaglianza completa e hash
sono fuori timer; il costruttore del grafo restituisce il valore ancora vivo
prima dello stop. Il timer della proiezione include l'intero init del DTO, con
risultato Core già materializzato.

Il confronto ha tre fasi con Package/Fixtures e harness congelati: baseline,
strutture DAG/CA e candidato completo con digest. La fase intermedia esegue
Graph e Projection, mantenendo validazione e formatter digest precedenti;
permette di distinguere i contributi sovrapposti nel costruttore del grafo.
Non mescolare i tempi delle fasi o attribuire l'intero guadagno a una sola patch.

Conservare tutti i sette campioni, checksum, inventari, configurazione e stato
termico/energetico. Eventuali RSS di `time -l` riguardano l'intera invocazione,
compresi preparazione e riferimento. La guard della misura esplicita in Debug
viene verificata separatamente come controllo negativo; non diventa un nuovo
gate prestazionale del prodotto.

## Stili dei grafici e OCR di sistema

Il benchmark degli stili usa il modello di produzione `StudioPlotSeries` e un
riferimento che replica il calcolo precedente. Controlla l'intero vettore degli
indici e alterna l'ordine di misura su sette passaggi. Si compila dalla radice
con i moduli e gli oggetti prodotti da SwiftPM, in Release.

```sh
swift build -c release --package-path Packages/GlifiCore --target GlifiKit
bin=$(swift build -c release --package-path Packages/GlifiCore --show-bin-path)
out=$(mktemp -d)
swiftc -swift-version 6 -O -parse-as-library -Xcc -DACCELERATE_NEW_LAPACK \
  -I "$bin/Modules" Apps/Shared/StudioPlotSeries.swift Benchmarks/macOS/StudioPlotSeriesBenchmark.swift \
  "$bin"/GlifiKit.build/*.o "$bin"/GlifiCore.build/*.o -lsqlite3 -o "$out/plot-series"
"$out/plot-series"
```

La prova Vision genera due righe sintetiche e produce JSON su stdout. Ogni
configurazione riporta le letture completate e l'eventuale errore. Per
riprodurla e interpretare le misure consultare
[GS-VER-270](../docs/evidenze/GS-VER-270-grafici-comandi-neural-engine.md).
