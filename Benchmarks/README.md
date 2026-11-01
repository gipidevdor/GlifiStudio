<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Benchmark

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
