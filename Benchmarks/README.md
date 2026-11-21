<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Benchmark

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
