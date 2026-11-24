<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-170 — Raffinamento di memoria e calcolo analitico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-170 |
| Tipo | Evidenza di correttezza e prestazioni osservate |
| Versione | 1.0.1 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-21 |
| Approvazione | Prosecuzione esplicita dell'iniziatore: correttezza ed efficienza; nessuna soglia promossa |
| Riferimenti | GS-DOR-170; GS-VER-169; GS-STD-001-17; GS-MET-001-04; GS-MET-001-07; GS-MET-001-15; GS-MET-001-17; RQ-008; RQ-009; RQ-063 |

## Perimetro storico e integrazione

Questa evidenza conserva i risultati osservati nel working tree sorgente del
2026-11-21, precedente all'integrazione sulla nuova base upstream `fe6f654`.
I conteggi dei test, i gate e le misure riportati appartengono al relativo
snapshot storico. La verifica della nuova integrazione è registrata separatamente
in [GS-VER-171](GS-VER-171-integrazione-algoritmi.md).

## Modifiche

- Descrittive: ordinamento per conteggi bounded a 256 valori distinti, con
  probe iniziale, fallback nativo sul buffer intatto e trattamento conservativo
  di ±0. Nessuna modifica alle riduzioni, a Q7 o ai bit dei valori ordinati.
- Temporale: ordinamento e partizioni contengono indici dell'input; eliminate
  copie di documenti e strutture per bucket, mantenendo validazione anche sulle
  fonti escluse, lineage e ordine canonico.
- NMF: trasposta di X condivisa fra restart, W/H e rispettive trasposte
  aggiornate con gli stessi valori, prodotti contigui e buffer riusati. Obiettivo
  fuso senza matrice WH, con ordine delle operazioni originario.
- TF-IDF/TF: visita di conteggio condivisa, nessun ordinamento senza norma,
  tuple ordinate per la norma anziché lookup ripetute; cache DF limitata prima
  dell'allocazione e failure tipizzate per conteggi/overflow invalidi.
- BM25: buffer O(N) riusato per DF e score, una lettura del conteggio per coppia
  query/documento, somme nello stesso ordine. Corretto l'overflow intermedio
  per k1 finito estremo con riscalamento sul solo percorso necessario.

Nessun nuovo backend, dipendenza, formato, seed o tolleranza. Identificatori e
stati scientifici invariati; il nuovo limite esplicito della cache DF è
1.000.000 colonne. Non vengono applicate approssimazioni.

## Protocollo

Host Mac16,3, 16 GiB, 10 CPU logiche, macOS 27.2.1 (26B131), Xcode 27.2 (27B52),
Apple Swift 6.4.2. Alimentazione AC con Low Power Mode attivo nella
configurazione osservata (`pmset -g custom`), senza modificare le preferenze.
Release; un warm-up e cinque campioni per ciascuno dei
quattordici casi di `GlifiBenchmark --analysis-refinement`. Input sintetici;
setup e controlli fuori timer. Per ciascun caso viene confrontato l'intero
ultimo risultato: warm-up e primi quattro campioni non sono confrontati
individualmente dall'harness. NMF, descrittive e temporale includono la
configurazione nei digest; ponderazioni hanno SHA-256 di righe/lunghezze/query
e configurazione esplicita nella ricetta, anch'essa confrontata esattamente.
L'harness non impedisce Debug: Release è garantita dal comando di build
registrato, non dall'etichetta del report. L'etichetta del primo generatore NMF
«exact nonnegative rank 3» indica il prodotto sintetico di tre fattori
nonnegativi: la matrice memorizzata include arrotondamento binary64 e non
rivendica rango algebrico esatto dei valori arrotondati. RSS dell'intero processo di ciascuna
sezione con `/usr/bin/time -l`, inclusi fixture e controlli.

Baseline compilata e archiviata prima delle modifiche; eseguibile autonomo con
sole dipendenze di sistema. Confronti baseline/candidato consecutivi per ogni
sezione, senza build o benchmark concorrenti della squadra. Inventari SHA-256
dei sorgenti prima/dopo conservati. La base Git resta
`a86a53b512bd777f191c89692e0c573a3d37a3ff`, con modifiche preesistenti e delle
attività parallele preservate. Le misure sono locali informative: niente
soglie di rilascio, I/O fisico, energia o latenza UI.

## Misure finali

| Caso | Mediana prima (ms) | Min–max prima (ms) | Mediana dopo (ms) | Min–max dopo (ms) | Prima/dopo |
| --- | ---: | ---: | ---: | ---: | ---: |
| `descriptive-refinement-repeated-500000` | 37.544 | 37.472–37.671 | 14.157 | 14.092–14.344 | 2.65× |
| `descriptive-refinement-continuous-500000` | 83.906 | 83.640–84.247 | 83.071 | 82.950–83.509 | 1.01× |
| `descriptive-refinement-late-cardinality-fallback-500000` | 8.660 | 8.644–8.675 | 9.071 | 9.054–9.105 | 0.95× |
| `descriptive-refinement-sparse-and-empty-500000` | 1.019 | 1.011–1.023 | 1.031 | 1.024–1.038 | 0.99× |
| `temporal-refine-sparse-30000x2` | 49.951 | 49.616–50.576 | 44.618 | 43.183–46.506 | 1.12× |
| `temporal-refine-dense-6000x128` | 103.232 | 102.366–105.569 | 100.441 | 98.711–102.044 | 1.03× |
| `temporal-refine-empty-missing-20000` | 23.997 | 23.915–24.360 | 18.885 | 18.841–18.934 | 1.27× |
| `refinement-nmf-lowrank-120x240-k3` | 36.430 | 36.419–36.542 | 14.800 | 14.792–14.820 | 2.46× |
| `refinement-nmf-sparse-240x320-k12` | 163.179 | 162.897–163.473 | 65.662 | 65.618–65.684 | 2.49× |
| `refinement-nmf-rectangular-400x96-k6` | 146.154 | 145.724–146.390 | 67.507 | 67.449–67.674 | 2.17× |
| `tfidf-4000x4096-nnz256000` | 30.849 | 30.810–31.598 | 20.509 | 20.226–20.776 | 1.50× |
| `tf-raw-4000x4096-nnz256000` | 17.493 | 17.326–17.729 | 7.182 | 7.132–7.200 | 2.44× |
| `bm25-4000x4096-query4` | 0.879 | 0.820–1.081 | 0.728 | 0.722–0.760 | 1.21× |
| `bm25-4000x4096-query128` | 34.269 | 34.021–34.421 | 24.565 | 24.315–24.576 | 1.40× |

Tutti i quattordici controlli completi di input/configurazione e ultimo output
coincidono. Il rapporto maggiore di uno indica riduzione del tempo.
Nessuna tolleranza è stata allargata.

Le descrittive con cardinalità tardiva impiegano **0,411 ms in più (+4,75%)**:
il probe non intercetta l'inversione tardiva e resta il sort nativo dopo la
verifica iniziale. Il caso con mancanti cresce di **0,012 ms (+1,18%)**.
I guadagni del caso ripetuto non vengono estesi a tutte le distribuzioni.

| Sezione | RSS prima (MiB) | RSS dopo (MiB) |
| --- | ---: | ---: |
| descriptive | 33.688 | 33.938 |
| temporal | 113.266 | 106.531 |
| factorization | 14.516 | 14.641 |
| weighting | 99.156 | 99.172 |

La sezione temporale riduce il picco di **6,734 MiB (5,95%)**. Descrittive,
NMF e ponderazioni crescono rispettivamente di 0,250, 0,125 e 0,016 MiB;
non è dichiarata una riduzione universale della memoria.

Il confronto finale è stato eseguito una volta, dopo 4,883 secondi consecutivi
senza processi di verifica, compilazione o benchmark concorrenti osservati.
Supervisione durante il confronto e snapshot prima/dopo non hanno rilevato
ricomparse. Esecuzione il 2026-11-21 dalle 21:19:38 alle 21:19:50 CET;
stato termico iniziale nominale in tutte le sezioni e Low Power Mode invariato.

## Tentativi affinati

Il primo tentativo TF-IDF normalizzato impiegava 39,490 ms contro 31,977 ms
(+23,5%): eliminava allocazioni ma aggiungeva lookup ripetute nel dizionario.
È stato sostituito con tuple ordinate e trasformazione dei valori senza
riletture per chiave. Anche il primo BM25 a array IDF mostrava regressioni:
scartato in favore del buffer per colonna, con una sola lettura del conteggio.
I report del primo tentativo sono conservati insieme al confronto finale.

## Correttezza e verifiche

Il primo lotto mirato ha superato 62 test, inclusi NMF contro implementazione
scalare con matrice WH e prodotti strided (36 combinazioni bitwise, restart e
stopping), tutte le 54 combinazioni TF/IDF/norma, descrittive contro sort nativo
e partizioni temporali con mancanti/esclusioni. Il lotto finale delle ponderazioni ha superato cinque test, incluso il
confronto bitwise BM25 contro formula diretta su 20 seed e tre parametri.
Il riferimento BM25 usa Decimal a 400 cifre per parametri estremi; nessuna
tolleranza è stata allargata. Review incrociate separate hanno controllato
le quattro famiglie e i limiti del protocollo.

Il gate sul codice finale ha superato 381 test Core e 52 test Kit,
153 righe di oracoli R/Python, due PDF/A-2u conformi, 51 controlli CLI,
QueryAST e 22 checkpoint di recovery. I test nativi macOS hanno superato
47 test (128 esecuzioni incluse le parametrizzazioni), zero falliti e zero
saltati, confermati con `xcresulttool`.

**`make verify` concluso con exit 0 il 2026-11-21 alle 21:19 CET**:
480 test complessivi, oracoli, PDF/A, CLI, recovery e build Debug/Release
macOS e iPadOS tramite `GlifiStudio.xcworkspace`. Nessun controllo richiesto
saltato e nessun gate indebolito.

Restano gli avvisi dell'host: CoreSimulator installato `1171.7.0`, inferiore a
`1174.21.0` richiesto da Xcode, e dichiarazione di apertura in-place dei documenti
iPadOS. Le build generiche sono passate; non sono state eseguite prove su
dispositivo o simulatore iPad.

## Pulizia e prove conservate

Eliminata soltanto la cache dedicata a questo incremento: **2.949.856 KiB,
circa 2,81 GiB**. Rimossi log intermedi e minimizzati gli snapshot di processo
per escludere l'inventario delle applicazioni non pertinenti, conservando
timestamp e SHA-256 originale. Il riepilogo nativo conservato omette gli
identificatori del dispositivo.

Restano il log finale `/tmp/GlifiAlgorithms170-verify.log`, i log dei test
mirati e finali delle ponderazioni, il riepilogo nativo e **180 KiB** di report
in `/tmp/GlifiAlgorithms170Reports`: prima/dopo, primo tentativo, minimi/massimi,
RSS, ambiente e alimentazione, sorgenti/eseguibili SHA-256 e protocollo di
supervisione. Toolchain, dipendenze e file delle altre attività sono preservati.
I report generati non sono aggiunti al repository.

## Limiti

Il probe iniziale limita la scelta del percorso, ma non garantisce un
guadagno di latenza per ogni distribuzione. La cardinalità tardiva o i dati
quasi ordinati possono richiedere il fallback nativo e aggiungere lavoro.
RSS di processo e hash non sostituiscono test indipendenti o audit
scientifico esterno. NMF conserva una trasposta di X e specchi W/H: le
prestazioni e il picco delle tre forme misurate non garantiscono lo stesso
compromesso su tutte le forme ammesse. Promozione delle varianti e hardware
di riferimento restano separati.
