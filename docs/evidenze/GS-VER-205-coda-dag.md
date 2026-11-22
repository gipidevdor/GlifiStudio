<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-205 — Coda ordinata del DAG analitico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-205 |
| Tipo | Evidenza di ottimizzazione delle strutture di dominio |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-205 Ready prima del coding; richiesta dell'iniziatore |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-ANA-001; RQ-009; RQ-023; RQ-024; RQ-063; CMP-205 |

## Perimetro e contratto

La [GS-DOR-205](../pianificazione/dor-ottimizzazione-coda-dag.md) seleziona
la gestione dei nodi pronti in `GlifiAnalysisGraph.init`. La versione precedente
ordinava inizialmente un array, ne rimuoveva il primo elemento a ogni visita
e riordinava l'intera coda dopo ciascun nodo divenuto pronto. Inoltre ordinava
i figli del nodo corrente prima di aggiornarne i gradi entranti.

La patch sostituisce questa coda con un min-heap privato di `AnalysisNodeID`.
La costruzione iniziale dell'heap è O(V); inserimento ed estrazione sono
O(log V), con memoria O(V). La sola gestione di Kahn diventa O(E + V log V).
Non si attribuisce questa complessità all'intero costruttore: restano
validazione dei descrittori e delle identità, codifica e digest, ordinamento
finale dei nodi e ordinamento degli indici dei figli.

Il minimo pronto rimane esattamente lo stesso. Tutti i figli del nodo corrente
sono aggiornati e, quando pronti, inseriti prima dell'estrazione successiva;
il loro ordine di visita non influenza il minimo estratto. `childrenByID`
conserva l'ordinamento finale preesistente. Il confronto tipizzato usa i
digest memorizzati anziché interpolare `canonicalValue`: per due
`AnalysisNodeID` il namespace è identico e i digest ASCII validati conservano
lo stesso ordine lessicografico.

Restano invariati nodi canonici, ordine topologico e spareggi, deduplicazione,
limiti, collisioni, priorità delle failure, query di antenati, invalidazione
e riuso. La forma Codable conserva il solo campo `nodes` e ricostruisce gli
indici durante la decodifica. Non vengono introdotti API pubbliche, cache
dei digest, formato persistente, dipendenza produttiva o backend.
Il costruttore resta sincrono, senza nuove operazioni async, I/O o checkpoint
di cancellazione.

## Identità e fasi dell'esperimento

La baseline è stata congelata prima delle patch produttive. La copia isolata
contiene **279 file**. La prima fase candidata, denominata `structures`,
conserva **277 file identici** e sostituisce soltanto
`GlifiAnalysisGraph.swift` per GS-VER-205 e
`GlifiDerivedAnalysesPresentation.swift` per GS-VER-206. Identificatori,
validazione dei digest e relativa formattazione restano byte-identici alla
baseline in questa fase. La combinazione finale aggiunge le modifiche
di GS-VER-207: tre sorgenti della baseline sono modificati, un helper
produttivo è aggiunto e **276 file congelati restano identici**. L'inventario
finale contiene quindi 280 file. Le regressioni aggiuntive del workspace
restano esterne alla copia delle misure.

| Ingresso | SHA-256 |
| --- | --- |
| `GlifiAnalysisGraph.swift`, baseline | `06e1ebb213c428a2d2ea5f6f5e154d18be4aabcf373a80a448faf8e3693f6c47` |
| `GlifiAnalysisGraph.swift`, fase strutture misurata | `4abe87e72d77fda8b1b07e2597483fddf7b75c606e0dc87e7426600bb2c23595` |
| `GlifiAnalysisGraph.swift`, combinazione finale misurata | `7fde3f0ebf3da8e0fce5a832f3f9a1b75622c71ae1428d42605c831c9086c0d9` |
| `GlifiAnalysisGraphOptimizationTests.swift`, harness A/B identico | `d4a384cc837e80b8c99cc587e1c49a3c5042cd710af6edb85637ca59ca0d14a5` |
| `GlifiAnalysisGraphOptimizationTests.swift`, regressioni workspace rafforzate | `ec45d7d6e615692536cfa8aaa9929c6258e7d7c6efa4fae438296212e5c585da` |
| `GlifiPipelineBenchmarkSupport.swift`, supporto dei soli test | `3721ce3314445571bbc5f03163f55a030a3f03c2d09a623f2e976dc98e22dae0` |
| Inventario baseline | `5a1a6ad7c86c88749ef1931228fcf2b79a95ae701798c7104c742974f5d3b341` |
| Inventario fase strutture | `abe6b69816b461731bd6c87f978e0c964e3b9cb1546c3e235c2d9d6101b0d6ca` |
| Inventario combinazione finale | `c2b9721df031184aeda16b4791b2403da653008ddfaaa216d2dbc0807b8bedaa` |

Il rafforzamento delle tuple diagnostiche nel solo workspace avviene dopo
il congelamento e non cambia l'entry prestazionale né la copia A/B. Le due
versioni dei test sono conservate distintamente nell'archivio delle prove.
Il supporto di misura è confinato al target `GlifiBenchmarkTestSupport`,
secondo GS-DOR-208; non diventa una dipendenza dei prodotti.

## Protocollo riproducibile

Il runner avvia processi Release separati per `domainOptimizationGraph`,
`domainOptimizationProjection` e `domainOptimizationDigest`. Nella fase
intermedia strutture esegue soltanto Graph e Projection. Ogni scenario
usa un warm-up e sette campioni, con otto verifiche complete del risultato.
L'ambiente `GLIFI_PIPELINE_BENCHMARK_DIRECTORY` abilita le fixture grandi;
senza di esso l'entry Graph verifica soltanto i quattro casi piccoli.
L'helper rifiuta misure abilitate in configurazione Debug.

Il comando del processo Graph è:

```sh
GLIFI_PIPELINE_BENCHMARK_DIRECTORY=/tmp/GlifiStudioDomain205-cache/baseline \
  /usr/bin/time -l swift test -c release -Xswiftc -enable-testing \
  --skip-build \
  --package-path /tmp/GlifiStudioDomain205-cache/Snapshot/Packages/GlifiCore \
  --scratch-path /tmp/GlifiStudioDomain205-cache/SwiftPMRelease \
  --filter domainOptimizationGraph
```

Il timer comprende l'intero `GlifiAnalysisGraph.init`, incluse validazione
dell'identità, indici e ordinamenti finali. Nodi, descrittori, dipendenze,
riferimenti agli artefatti, fixture digest e riferimento scalare sono
preparati prima del timer. Il risultato restituito è il grafo completo,
con indici ancora vivi. Dopo lo stop, l'helper verifica l'uguaglianza del
grafo con l'atteso e il digest dello snapshot completo di nodi, descrittori
e ordine topologico. Serializzazione, checksum e scrittura del rapporto
sono esclusi dal tempo.

Il riferimento conserva l'algoritmo scalare Kahn originario, compresi i
controlli del costruttore e il confronto su `canonicalValue`. È una prova
di equivalenza dell'implementazione, non un oracolo indipendente della
validità scientifica del modello. Il grafo atteso viene confrontato
integralmente con il riferimento prima delle misure.

I cinque workload sono: nodi indipendenti da 1.000 e 5.000 elementi,
stella da 5.000, livelli interleaved da 3.000 e catena da 1.000. Le fixture
usano identificatori e parametri deterministici, ordine dei candidati
invertito e dipendenze valide. I livelli hanno larghezza massima 64 e fino
a tre genitori distinti nel livello precedente. Non vengono eseguiti
kernel numerici né creati corpus reali.

## Confronto delle tre fasi

I cinque rapporti Graph per fase sono conservati negli allegati
[baseline](allegati/GS-VER-205-207-baseline.json),
[strutture](allegati/GS-VER-205-207-structures.json) e
[candidato completo](allegati/GS-VER-205-207-candidate.json), insieme alle
altre misure del lotto. Il [confronto](allegati/GS-VER-205-207-confronto.json)
registra rapporti, intervalli, identità dei risultati e sorgenti.
Ambiente registrato: `Mac16,3`, 16 GiB di memoria fisica, dieci processori
logici, macOS `Version 27.2.1 (Build 26B131)`, eseguibile di test SwiftPM
Release. Tutte le fasi riportano stato termico nominale e Low Power Mode attivo
all'inizio e alla fine. Processo caldo, senza cache flush. Il
[log del gate](allegati/GS-VER-205-208-gate.txt) registra Xcode 27.2,
Apple Swift 6.4.2, language mode 6 e SwiftPM tools 6.4.

Le tre invocazioni Graph terminano con exit 0. I log registrano un
test superato in 43,166 s per la baseline, in 21,223 s per la fase strutture
e in 13,269 s per il candidato completo.
Questi tempi comprendono fixture, riferimenti e controlli e non sono misure
del solo costruttore. I valori seguenti sono
le misure del timer, in millisecondi, con mediana e minimo–massimo dei
sette campioni.

| Scenario | Baseline mediana [min–max] | Strutture mediana [min–max] | Finale mediana [min–max] | Rapporto strutture | Rapporto complessivo |
| --- | --- | --- | --- | --- | --- |
| Indipendenti 1.000 | 79,037209 [78,853875–79,354167] | 66,018208 [65,820750–66,269958] | 22,933958 [22,912084–22,977500] | 1,20× | 3,45× |
| Indipendenti 5.000 | 385,623958 [382,136125–392,400917] | 327,783958 [324,007875–332,146375] | 115,347458 [113,883583–117,257000] | 1,18× | 3,34× |
| Stella 5.000 | 2.673,178208 [2.634,062458–2.737,492500] | 349,011208 [346,940708–354,842666] | 134,487834 [132,476584–136,284208] | 7,66× | 19,88× |
| Livelli interleaved 3.000 | 257,021167 [255,674917–257,303375] | 223,286458 [221,819916–225,931917] | 96,112333 [95,468375–96,449333] | 1,15× | 2,67× |
| Catena 1.000 | 78,303583 [77,521875–80,579875] | 67,340125 [67,293375–67,591083] | 25,895875 [25,859292–26,186791] | 1,16× | 3,02× |

La stella mostra una riduzione dell'86,94% della mediana del costruttore.
Questa fase misura insieme heap, rimozione del sort dei figli durante Kahn
e confronto sul digest memorizzato; non separa il contributo delle tre
modifiche. Anche GS-VER-206 è presente nel pacchetto della fase strutture,
ma il processo Graph non esegue la proiezione DTO Kit. La validazione e la
formattazione dei digest sono ancora quelle originarie: il miglioramento
di questa fase non viene attribuito a GS-VER-207.

Il candidato finale include anche validazione ASCII e codifica esadecimale
condivise di GS-VER-207. Il passaggio strutture → finale riduce ulteriormente
la mediana della stella da 349,011208 a 134,487834 ms, rapporto 2,60×;
il rapporto baseline → finale è 19,88×, riduzione del 94,97%. Gli altri
quattro workload mostrano rapporti complessivi fra 2,67× e 3,45×. Questi
rapporti combinati non vengono attribuiti alla sola coda heap; il
contributo del blocco strutture rimane documentato nella colonna separata.

| Scenario | Digest fixture | Digest risultato completo |
| --- | --- | --- |
| Indipendenti 1.000 | `sha256:862eb9a56365cd0c94cca44af65c0098554a8048b4edecadef1ed417516f5cd4` | `sha256:0298e1bcb1c4288cabb7ed6c8bb49406c01dfa433242581ea6066dd10ed9795a` |
| Indipendenti 5.000 | `sha256:53ea32ff645fc6addc338a9b784843fa5acc3e080cd33b9f5ca3d5b206ce2082` | `sha256:048586588949d9c4338cb3b2cf3384b2911560cdec87e6236a5eeceeddf37b1f` |
| Stella 5.000 | `sha256:97c52f168f54b98f1eaa38be8d3deb437c9b830e001f267be1a0e69fcf1b96ee` | `sha256:72535697c1a5150179267ce2fa42baf2dab035f34cdb5e60880037f7c002c8d3` |
| Livelli interleaved 3.000 | `sha256:1349d78e95bf706d82d1d21353347f15a4e4ccd9787965da854e14dcd3d1dd3b` | `sha256:027137f1901daa8c5592f52c8516b977a70ccff5e107a9d62cba47cce1f2a08a` |
| Catena 1.000 | `sha256:419c42a43284409f40b7d5246e8ca489231d06a571964fd560e8a7b39cc73f33` | `sha256:1a9c0391a7188248dfb6a867d61ebe2e1f123f92e20349dcbf8dd7ba5825dd09` |

Ciascuno scenario registra otto confronti completi e sette campioni grezzi.
I digest di fixture e risultato della tabella coincidono fra tutte e tre
le fasi, oltre che con il riferimento completo in ogni esecuzione. I sette
campioni grezzi e gli otto controlli per scenario sono conservati negli
allegati delle misure. Gli inventari
[baseline](allegati/GS-VER-205-207-inventario-baseline.json),
[strutture](allegati/GS-VER-205-207-inventario-structures.json) e
[finale](allegati/GS-VER-205-207-inventario-candidate.json) permettono il
riscontro dei file congelati e delle sole modifiche dichiarate.

I [riscontri di processo](allegati/GS-VER-205-207-processi.json), con i log
grezzi [baseline](allegati/GS-VER-205-207-baseline-processi.txt),
[strutture](allegati/GS-VER-205-207-structures-processi.txt) e
[candidato](allegati/GS-VER-205-207-candidate-processi.txt), riportano per
Graph un RSS massimo di 128.139.264 → 131.907.584 → 131.776.512 byte.
Sono valori dell'intera invocazione, inclusi SwiftPM, fixture, riferimenti
e verifiche; non misurano le allocazioni isolate dell'heap e non dimostrano
una riduzione della memoria del componente.

Il [record dell'archivio sorgenti](allegati/GS-VER-205-208-archivio-sorgenti.json)
identifica la copia riproducibile: **729.337 byte**, SHA-256
`a9f0ac28e3799f993f7d5e4c62991c87c1d0231247669ad95f775debb4e85da1`.
Conserva package e fixture congelati finali, tre sorgenti baseline e due
della fase strutture, inventari, audit del supporto e della correzione
del riferimento diagnostico, oltre alle regressioni finali aggiuntive.
La cache di build è esclusa dall'archivio.

## Regressioni e riesame

Il nuovo file comprende tre test. L'entry di misura verifica sempre le
quattro geometrie da 24 nodi. Il test di comportamento confronta quattro
permutazioni, compresa la ripetizione di nodi identici, e sei insiemi di
artefatti: validi, mancanti, stale, descriptor digest errato, artifact digest
modificato e schema errato. Per ogni combinazione confronta nodi e ordine
topologico, antenati richiesti, discendenti invalidati e riuso. Anche il
grafo decodificato deve produrre gli stessi risultati e lo stesso JSON
canonico, limitato al campo `nodes`.

Il test delle failure copre grafo vuoto con budget zero, limiti di nodi
e archi, conteggio dei candidati prima della deduplicazione, dipendenza
mancante, schema incompatibile, collisione, ciclo prima dell'errore di
identità, identità non corrispondente, artefatti duplicati e nodo richiesto
o modificato sconosciuto. Il rafforzamento workspace verifica per ciascuna
failure codice, categoria, operazione, retry, stato conservato, chiave
localizzata e argomenti vuoti, con attese esplicite.

Il riesame indipendente dell'agente incaricato di GS-VER-206 non ha trovato
problemi su heapify, inserimento, estrazione e limiti degli indici per
cardinalità pari, dispari e singola; ha inoltre verificato spareggi,
indipendenza dall'ordine dei figli e diagnostica invariata. È una revisione
in sola lettura. Lint strict e `git diff --check` della patch sono superati.

La [corsa Release mirata](allegati/GS-VER-205-208-test-mirati.txt) termina
con exit 0: **nove test Core e tre Kit, 12 totali**. Comprende i tre
test GS-VER-205 della copia di misura e i due test DAG preesistenti,
la copertura dei digest, i tre test Kit e i tre entry di regressione
SpanMap, tokenizer e CSV con il supporto condiviso migrato.
Il log riporta 0,084 s per Core e 0,005 s per Kit; questi tempi della corsa
non sostituiscono le misure prestazionali dedicate.
Le asserzioni diagnostiche complete aggiunte nel solo workspace sono
successivamente superate nel gate finale: il file dei test conserva SHA-256
`ec45d7d6e615692536cfa8aaa9929c6258e7d7c6efa4fae438296212e5c585da`.

## Gate integrato

`make verify` termina con **exit 0** sul profilo macOS e iPadOS. Il
[record del gate](allegati/GS-VER-205-208-gate.json), il
[log sanificato](allegati/GS-VER-205-208-gate.txt) e il
[riepilogo dei test macOS](allegati/GS-VER-205-208-test-macos.json)
conservano i risultati. I **376 file di ingresso runtime e verifica**
sono rimasti invariati durante il gate. I quattro sorgenti produttivi
del lotto coincidono con quelli del candidato misurato; per il grafo
è `7fde3f0ebf3da8e0fce5a832f3f9a1b75622c71ae1428d42605c831c9086c0d9`.

| Controllo | Esito osservato |
| --- | --- |
| SwiftPM | 391 test Core e 59 Kit superati |
| Test nativi macOS | 55 test distinti, 195 esecuzioni per dispositivo; zero failure e skip |
| Oracoli | 153 righe riprodotte |
| Analisi CLI | 51 controlli su 15 fixture |
| Recovery | 22 checkpoint con interruzione SIGKILL superati |
| Export PDF/A | Due file conformi PDF/A-2u |
| Build del workspace | macOS Debug/Release e iPadOS Debug/Release superate |

Il [controllo negativo del supporto di misura](allegati/GS-VER-208-guard-debug.json),
eseguito separatamente dal gate, rifiuta la misura esplicita in Debug
con exit 1 atteso e non produce rapporti JSON. Le regressioni piccole
restano eseguibili normalmente senza abilitare le misure grandi.

Gli avvisi noti riguardano CoreSimulator installato `1171.7.0` rispetto a
`1174.21.0` richiesto e la dichiarazione iPadOS di apertura documentale in
place. I test macOS sono nativi e superati; non sono stati eseguiti test
su runtime del simulatore iPadOS. Il gate non attesta nuove verifiche di
firma, packaging o distribuzione App Store.

## Limiti e stato delle prove

Le misure riguardano costruzione di grafi sintetici headless, non la latenza
UI, l'esecuzione dei nodi, l'energia o una soglia G4 approvata. La memoria
dei processi, se conservata con `/usr/bin/time -l`, include SwiftPM, fixture,
riferimenti e verifiche; non rappresenta l'allocazione isolata dell'heap.
Nessuna promessa di cancellazione nuova, polling, osservatore o cache globale.
Recupero mediante revert puntuale, senza migrazione.

Confronto A/B a tre fasi, 12 regressioni Release mirate, regressioni
aggiuntive del workspace e `make verify` finale sono superati. Rapporti,
log sanificati, inventari e archivio riproducibile sono conservati.
La pulizia della cache di lavoro è coordinata separatamente, dopo la
chiusura delle evidenze; la cache non è parte della prova riproducibile.


## Pulizia finale

Rimossa la sola cache del lotto dopo tutte le verifiche: **3.277.504 KiB,
circa 3,13 GiB allocati** prima della rimozione. Il
[record di pulizia](allegati/GS-VER-205-208-pulizia.json) conferma l'assenza del
percorso, distinguendo la misura dal delta di spazio libero APFS. Restano
allegati, audit e archivio sorgenti verificato; toolchain, dipendenze e cache
delle altre sessioni sono preservate.
