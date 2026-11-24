<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-169 — Ottimizzazione misurata degli algoritmi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-169 |
| Tipo | Evidenza di correttezza e prestazioni osservate |
| Versione | 1.0.1 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta dell'iniziatore: massima correttezza ed efficienza; nessuna soglia di rilascio promossa |
| Riferimenti | GS-DOR-169; GS-VER-168; GS-STD-001-17; GS-MET-001-03; ADR-0032; RQ-008; RQ-009; RQ-063 |

## Perimetro storico e integrazione

Questa evidenza conserva i risultati osservati nel working tree sorgente del
2026-11-21, precedente all'integrazione sulla nuova base upstream `fe6f654`.
I conteggi dei test, i gate e le misure riportati appartengono al relativo
snapshot storico. La verifica della nuova integrazione è registrata separatamente
in [GS-VER-171](GS-VER-171-integrazione-algoritmi.md).

## Modifiche

- HAC: cache condensata delle distanze e aggiornamento delle sole relazioni
  modificate. Average conserva la riduzione diretta ordinata originale; Ward
  conserva il calcolo del centroide. Eliminata la materializzazione delle
  coppie di membri per single/complete. Pareggi per identità invariati.
- K-means: minimo delle distanze incrementale in k-means++, una sola distanza
  per centro nella scelta Lloyd e una sola visita per raggruppare i membri.
- PageRank: identità convertite in indici una volta, archi in CSR e due buffer
  riutilizzati. Ordine dei nodi, archi di ogni riga e operazioni aritmetiche invariati.
- Riassunti: strutture di similarità esatte e vettori costruiti soltanto quando
  possono essere usati dal metodo o dalla penalità MMR.
- Tempo e linguistica: chiavi canoniche riutilizzate, accumuli indicizzati,
  eliminati Set/ordinamenti morfologici per token e visite duplicate dei lemmi.
- Lessico e descrittive: conteggio/validazione condividono la visita dei token,
  buffer e valori intermedi ridondanti eliminati, output preallocati bounded.

Nessun nuovo backend, dipendenza, formato persistente o cambiamento di formula,
seed, tolleranza o stato scientifico. Le famiglie candidate restano candidate.

## Protocollo

Host Mac16,3, 16 GiB, 10 CPU logiche, macOS 27.2.1 (26B131), Xcode 27.2 (27B52) e Apple Swift 6.4.2.
Configurazione Release; un warm-up e cinque campioni per ciascuno dei tredici
casi di `GlifiBenchmark --analysis-optimization`. Input sintetici con seed e
checksum; setup e checksum output fuori misura. Nessuna lettura di corpus reale.
Picco RSS osservato con `/usr/bin/time -l` sull'intera sezione, non sul singolo
kernel. Stato termico iniziale nominale nelle esecuzioni confrontate.

La baseline è stata eseguita prima delle modifiche agli algoritmi; i checksum
SHA-256 dei file sorgente sono conservati nel rapporto locale. La revisione
`a86a53b512bd777f191c89692e0c573a3d37a3ff` identifica la base del repository,
con il working tree preesistente preservato. Le misure riguardano i kernel
in memoria: I/O, energia, latenza UI e hardware di riferimento restano separati.

## Misure finali

| Caso | Mediana prima (ms) | Min–max prima (ms) | Mediana dopo (ms) | Min–max dopo (ms) | Rapporto prima/dopo |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hac-single-400x12` | 2517.546 | 2484.634–2528.738 | 28.395 | 28.283–28.515 | 88.66× |
| `hac-average-400x12` | 416.255 | 415.880–417.234 | 30.546 | 30.530–30.585 | 13.63× |
| `hac-ward-400x12` | 95.201 | 95.170–95.216 | 28.852 | 28.848–28.891 | 3.30× |
| `kmeans-4000x24-k8-r2` | 12.368 | 12.330–12.426 | 3.622 | 3.611–3.650 | 3.41× |
| `optimization-textrank-480x32` | 203.000 | 202.743–203.720 | 10.411 | 10.370–10.535 | 19.50× |
| `optimization-lexrank-continuous-480x32` | 59.619 | 59.470–59.736 | 25.274 | 25.061–26.001 | 2.36× |
| `optimization-pagerank-8000-nodes-72000-edges` | 1107.323 | 1104.664–1135.602 | 56.164 | 55.905–56.429 | 19.72× |
| `temporal-civil-months-20000x8` | 273.934 | 271.879–276.564 | 54.677 | 53.600–54.984 | 5.01× |
| `linguistic-morphology-50000x6` | 85.966 | 85.886–86.805 | 45.233 | 44.747–45.962 | 1.90× |
| `linguistic-lemma-stratified-100000` | 15.917 | 15.840–16.026 | 14.669 | 14.641–14.727 | 1.09× |
| `lexical-observe-500000-tokens-20000-types` | 32.607 | 32.345–32.826 | 30.889 | 30.803–31.522 | 1.06× |
| `lexical-heaps-log-ols-100000-points` | 2.386 | 2.358–2.729 | 1.980 | 1.971–2.338 | 1.21× |
| `descriptive-q7-500000-with-missing` | 35.486 | 35.378–36.339 | 36.524 | 36.439–36.663 | 0.97× |

Il rapporto maggiore di uno indica riduzione del tempo. Per le descrittive il
tempo cresce di circa il 3% (circa 1 ms su 500.000 osservazioni); il buffer unico
riduce la memoria. È un compromesso esplicito, non un miglioramento di latenza.

| Sezione | RSS prima (MiB) | RSS dopo (MiB) |
| --- | ---: | ---: |
| multivariate | 21.25 | 19.75 |
| graph | 34.50 | 31.39 |
| metadata | 54.47 | 55.84 |
| lexical | 46.27 | 39.61 |

Il picco della sezione metadata aumenta di circa 1,38 MiB per le strutture
indicizzate e le chiavi riutilizzate, mentre il kernel temporale accelera di
circa 5×. Non è dichiarata una riduzione universale della memoria.

**Tutti i tredici confronti hanno controlli input e output identici**. Grafi e
clustering conservano digest canonici; metadata conserva conteggi e valori
ordinati. I tre casi lessicali usano riepiloghi di conteggi, coefficienti e somme:
sono controlli di regressione, non un confronto esaustivo di ciascuna cella.
I test dedicati verificano invece risultati completi, letterali indipendenti e
bit pattern pertinenti. Non sono state allargate le tolleranze.

## Correttezza e verifiche

Il primo confronto ha verificato l'identità dei checksum input e output per
tutti i tredici casi. Le review incrociate hanno controllato cache HAC, consumo
PRNG, riduzioni, struttura CSR, mancanti, conteggi e budget. Le prove del prodotto
comprendono:

- **42 test Core e 8 test Kit mirati superati**, incluso il confronto esatto HAC
  con definizione diretta su dodici seed e quattro linkage, overlap TextRank
  contro intersezioni dirette su 80 frasi, PageRank con collisioni hash e
  multiarchi, morfologia combinatoria e descrittive in-place con estremi originali.
- Suite completa: **359 test Core e 52 test Kit superati**; oracoli R/Python
  **152 righe** riprodotte; due PDF/A-2u conformi con veraPDF; contratti CLI,
  QueryAST e **22 checkpoint** di recovery superati.
- Test nativi macOS: **36 superati**, zero falliti e zero saltati,
  verificati anche con `xcresulttool`.
- **`make verify` terminato con exit 0 il 2026-11-21 alle 19:46 CET**:
  **447 test totali**, oracoli, CLI, recovery e build Debug/Release
  macOS e iPadOS tramite il workspace. Nessun controllo richiesto saltato.

Il gate non è stato indebolito. Il nome di un helper di checksum conteneva la
sottostringa proibita dal controllo dell'output non strutturato: rinominato il
tipo senza cambiare calcolo, input o report; il controllo è passato invariato.

Il gate mantiene gli avvisi dell'host già registrati in GS-VER-168:
CoreSimulator installato `1171.7.0`, inferiore a `1174.21.0` richiesto da Xcode,
e dichiarazione di apertura in-place dei documenti iPadOS. Le build generiche
sono superate; non è stata eseguita una prova su dispositivo o simulatore iPad.

## Pulizia e conservazione delle prove

Eliminata la cache dedicata al termine del gate: **2.937.144 KiB, circa 2,80 GiB**.
Rimossi i log intermedi ridondanti. Conservati il log finale, il riepilogo
nativo e i report prima/dopo con minimi/massimi, RSS, ambiente e checksum dei
sorgenti in `/tmp/GlifiAlgorithms169Reports`; i risultati generati non sono
aggiunti al repository. Toolchain, dipendenze e file delle altre attività sono
preservati.

## Limiti

Confronto locale informativo, senza soglie prestazionali approvate e senza
garanzia di trasferibilità delle accelerazioni ad altri dataset. Le misure
brevi mostrano variabilità; i confronti dopo la prima revisione sono stati
ripetuti prima di trattenere o affinare le modifiche. Correttezza scientifica
esterna e promozione delle varianti seguono ADR-0031.
