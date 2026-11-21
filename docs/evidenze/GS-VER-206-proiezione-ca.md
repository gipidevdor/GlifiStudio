<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-206 — Appartenenza nella proiezione CA

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-206 |
| Tipo | Evidenza di equivalenza e confronto prestazionale di un DTO GlifiKit |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | Attuazione GS-DOR-206 nel programma complementare autorizzato |
| Riferimenti | GS-DOR-206; GS-DOR-208; CMP-206; GS-STD-001-17; GS-API-001; RF-033; RQ-009; RQ-028; RQ-063 |

## Perimetro e identità

L'incremento applica la
[GS-DOR-206](../pianificazione/dor-ottimizzazione-proiezione-ca.md) soltanto al
ramo Correspondence Analysis dell'inizializzatore di
`GlifiStudioMultivariateResult`, in `GlifiDerivedAnalysesPresentation.swift`.
Non modifica i kernel numerici o statistici, le formule, gli altri metodi
multivariati, l'interfaccia o il contratto del DTO.

La baseline Release valida precede la patch produttiva. Il lotto usa una copia
congelata di 279 file; le misure della fase strutture confrontano heap DAG e
membership CA mantenendo originali i digest. I contributi di altri incrementi
non sono attribuiti alla proiezione CA. La baseline completa è stata riacquisita
dopo la correzione di un'aspettativa di test sulle failure in un altro incremento;
questa correzione non ha modificato prodotto, fixture, timer o checksum.

| Ingresso | SHA-256 |
| --- | --- |
| `GlifiDerivedAnalysesPresentation.swift` precedente | `a3c9bc8387b5f2edb24cc9d96aabdaf373b028ce7bf73b68e30f700e33992682` |
| `GlifiDerivedAnalysesPresentation.swift`, identico in strutture e candidato completo | `188dc384753de9803ce44927b2facc83efd4205fc7b8e11ff8251ea4e159d60e` |
| `GlifiMultivariateProjectionOptimizationTests.swift`, identico per baseline e candidato | `6c7d205e6ae76e01cc9eaf4e4c4c1f5109421c00ba9bb8dd378ef44680962bff` |
| `GlifiBenchmarkTestSupport/GlifiPipelineBenchmarkSupport.swift` | `3721ce3314445571bbc5f03163f55a030a3f03c2d09a623f2e976dc98e22dae0` |

Il supporto SwiftPM condiviso è riservato ai test Core e Kit secondo la
[GS-DOR-208](../pianificazione/dor-ottimizzazione-supporto-benchmark-test.md).
Non introduce una dipendenza esterna né un nuovo prodotto distribuito.

## Costo precedente e contratto del candidato

Il codice precedente scorre tutti gli indici di documenti e termini e verifica
ogni appartenenza con `Array.contains` su `includedRows` o `includedColumns`.
La ricerca ripetuta richiede O(R·Ir + C·Ic) confronti nel caso peggiore, dove R e
C sono le dimensioni originali e Ir e Ic le lunghezze delle liste di inclusione.

Il candidato materializza due `Set<Int>` locali e usa la loro appartenenza negli
stessi filtri. I filtri continuano a percorrere gli indici originali: non
enumerano i Set e non cambiano l'ordine degli esclusi. Duplicati, riordino,
indici negativi o fuori intervallo nelle liste decodificate conservano la
precedente semantica di appartenenza; non viene introdotta una validazione.
Assi, coordinate, contributi, coseni, lineage e campi opzionali restano invariati.

I Set sono effimeri e richiedono memoria aggiuntiva O(Ir + Ic), con lookup medio
atteso costante; non sono una cache persistente e non riducono per contratto le
allocazioni o la memoria di picco. La preparazione dei Set rientra nella misura
dell'intero inizializzatore. Il candidato non aggiunge operazioni async, I/O o
nuove failure di dominio. Il rollback è un revert puntuale, senza migrazione.

## Protocollo di equivalenza e misura

`domainOptimizationProjection` esegue sempre un confronto piccolo completo,
anche senza `GLIFI_PIPELINE_BENCHMARK_DIRECTORY`. Quando la variabile è
impostata, prepara sei workload deterministici. Gli identificatori sono fissi;
il risultato Core è già materializzato attraverso il contratto Codable prima
del timer e contiene due assi sintetici. Non viene eseguito un kernel numerico.

Il riferimento riproduce i due filtri originali con `Array.contains` e prepara
tutti i campi del DTO CA o PCA. Le regressioni confrontano il risultato
integralmente con `Equatable`, con i byte JSON canonici e con SHA-256; l'helper
dei campioni usa l'uguaglianza completa e SHA-256 del JSON canonico. Questa
verifica dimostra
l'equivalenza della proiezione; le coordinate sintetiche non sono un oracolo
scientifico indipendente dei metodi multivariati.

L'helper misura un warm-up e sette campioni grezzi. Il timer comprende soltanto
l'intero `GlifiStudioMultivariateResult.init`, inclusi i Set del candidato.
Costruzione delle fixture Core, riferimento, uguaglianza completa, checksum e
codifica dei report restano fuori timer. Il processo è caldo, senza svuotamento
delle cache. La codifica JSON del DTO è verificata fuori timer, non costituisce
il lavoro prestazionale misurato.

I casi di regressione comprendono dimensioni vuote, nessuna o tutte le
appartenenze, ordine diverso da quello degli indici, duplicati, indici negativi,
fuori intervallo, `Int.min` e `Int.max`. Le etichette riordinate verificano che
gli esclusi conservino l'ordine dell'ingresso. Il controllo PCA verifica il
ramo non toccato; tutti i casi confrontano il DTO completo e il round-trip JSON.

## Confronto Release in tre fasi

Ambiente dei sei workload nelle tre fasi: Mac16,3, 10 processori logici,
16 GiB di RAM, macOS 27.2.1 (`26B131`), configurazione SwiftPM Release. Stato
termico nominale e Low Power Mode attivo all'inizio e alla fine di ciascun
workload. Le entry baseline, strutture e candidato completo sono superate:
i rispettivi `Projection.log` registrano un test completato senza errori.

| Workload | Inclusione | Mediana baseline, ms; minimo–massimo | Mediana strutture, ms; minimo–massimo | Mediana completo, ms; minimo–massimo | Rapporto baseline/strutture |
| --- | --- | --- | --- | --- | --- |
| CA 16 righe × 12 colonne | Circa 90% | 0,001458; 0,001334–0,005084 | 0,002125; 0,002083–0,004834 | 0,002250; 0,002041–0,007041 | Costo aggiuntivo di 0,667 µs |
| CA 1.024 righe × 2.000 colonne | Circa 90% | 1,836917; 1,828583–1,838583 | 0,076958; 0,074500–0,095541 | 0,075875; 0,075125–0,097333 | 23,869× |
| CA 4.096 righe × 2.000 colonne | Circa 90% | 7,474417; 7,468000–7,495375 | 0,157417; 0,152083–0,201250 | 0,156500; 0,153625–0,191708 | 47,482× |
| CA 8.192 righe × 2.000 colonne | Circa 90% | 25,473541; 25,423958–25,513333 | 0,301875; 0,268417–0,387000 | 0,272667; 0,265208–0,345833 | 84,384× |
| CA 8.192 righe × 2.000 colonne | Circa 10% | 5,053417; 5,036792–5,084709 | 0,196917; 0,186459–0,296459 | 0,202500; 0,192458–0,305125 | 25,663× |
| PCA 8.192 righe × 2.000 colonne, controllo | Non applicabile | 0,000959; 0,000875–0,001334 | 0,000917; 0,000834–0,001125 | 0,000875; 0,000833–0,001000 | Margine piccolo, senza inferenza statistica |

Sul caso CA da 8.192 righe con circa il 90% di inclusione, la riduzione
osservata è 98,815% del tempo dell'intero inizializzatore. Il caso piccolo
mostra invece un aumento della mediana da 1,458 a 2,125 µs, pari a 0,667 µs
e al 45,748%: la preparazione dei Set ha un costo e questo confronto non
dimostra un beneficio universale. La differenza di 0,042 µs sul controllo PCA,
il cui ramo è invariato, non costituisce una dimostrazione di significatività
statistica o un'accelerazione attribuibile alla patch.

Il candidato completo registra 0,272667 ms sul caso CA da 8.192 righe, ma il
sorgente Kit è identico alla fase strutture. L'attribuzione principale rimane
quindi il confronto isolato da 84,384×; la variazione fra strutture e completo
non è attribuita alla modifica dei digest. Sul caso piccolo il candidato
completo registra 2,250 µs, pari a un costo aggiuntivo di 0,792 µs rispetto
alla baseline (+54,321%). Il controllo PCA registra 0,875 µs: i margini piccoli
fra queste esecuzioni non dimostrano significatività statistica.

Ogni JSON registra 8/8 confronti completi di risultato superati. Per tutti i
sei workload i digest della fixture e del DTO coincidono nelle tre fasi;
i sette campioni grezzi, minimo, mediana e massimo sono conservati. Gli
allegati [baseline](allegati/GS-VER-205-207-baseline.json),
[strutture](allegati/GS-VER-205-207-structures.json),
[candidato completo](allegati/GS-VER-205-207-candidate.json) e
[confronto](allegati/GS-VER-205-207-confronto.json) conservano l'evidenza. I
relativi SHA-256 sono:

| Allegato | SHA-256 |
| --- | --- |
| Baseline | `bc7429d810177304a03c5c83cf53116c14d0de224252732d008ae1818d036fd8` |
| Strutture | `7de40b5a1f56e5a2602354da88150238bb59f5d36884c57d8cdfc7c32096e5a0` |
| Candidato completo | `b88488903d71ae32dafb07f9ff5111da7ca95a1b7bfacdb3cf10b2d8206742c8` |
| Confronto | `5a0cc280c7c16ee5815f3a500e59f70425b0eb930db3978edb7d1b7e660b17a3` |

Gli inventari [baseline](allegati/GS-VER-205-207-inventario-baseline.json),
[strutture](allegati/GS-VER-205-207-inventario-structures.json) e
[candidato](allegati/GS-VER-205-207-inventario-candidate.json) documentano
i sorgenti effettivi. I report temporanei sono stati prodotti nelle directory
`baseline/`, `structures/` e `candidate/` sotto
`/tmp/GlifiStudioDomain205-cache/`, con gli stessi identificatori:
`projection-ca-small.json`, `projection-ca-1024.json`,
`projection-ca-4096.json`, `projection-ca-8192.json`,
`projection-ca-8192-sparse.json` e `projection-pca-control.json`.

Il massimo RSS dei tre `Projection.log` è 73.564.160 byte nella baseline,
73.547.776 nella fase strutture e 73.531.392 nel candidato completo; il
footprint di picco è rispettivamente 25.117.560, 25.199.480 e 25.035.592 byte.
Si tratta dell'intera invocazione `swift test`
misurata con `time -l`, inclusi SwiftPM, fixture, riferimento e tutti i sei
workload. Non è una misura delle allocazioni isolate del DTO o per elemento
e non dimostra un risparmio di memoria o di energia.
Il [riepilogo dei processi](allegati/GS-VER-205-207-processi.json) e i log
[baseline](allegati/GS-VER-205-207-baseline-processi.txt),
[strutture](allegati/GS-VER-205-207-structures-processi.txt) e
[candidato](allegati/GS-VER-205-207-candidate-processi.txt) conservano il
perimetro dell'intera invocazione separato dal tratto cronometrato.

Il [record dell'archivio sorgenti](allegati/GS-VER-205-208-archivio-sorgenti.json)
identifica `verified-benchmark-source.tar.gz`, 729.337 byte, SHA-256
`a9f0ac28e3799f993f7d5e4c62991c87c1d0231247669ad95f775debb4e85da1`,
conservato in
`~/Library/Caches/GlifiStudio/evidence/domain-205-208-2026-11-21/`.
Contiene Package/Fixtures finali congelati, tre sorgenti baseline, due sorgenti
della fase strutture, tre inventari, audit del supporto e della correzione e
test finali aggiuntivi; non contiene cache di compilazione. L'archivio e gli
allegati sono evidenze da conservare dopo la rimozione della copia temporanea.

## Revisione e stato della verifica

Formatter strict e controllo whitespace dei file dell'incremento sono superati.
La revisione indipendente dell'agente Core non segnala problemi concreti nel
harness o nel candidato: membership, ordine degli esclusi, campi del DTO e
rami non CA risultano preservati alla lettura del diff.

Il filtro Release mirato del lotto sullo snapshot congelato ha completato
12 test senza errori: nove Core e tre Kit. I tre test Kit comprendono il
confronto completo di membership CA, il controllo non CA e l'entry con
riferimento piccolo sempre attivo. Il
[log dei test mirati](allegati/GS-VER-205-208-test-mirati.txt) conserva l'esito
sullo snapshot; il gate successivo ha eseguito anche i test completi del
workspace.

Il confronto A/B della fase strutture e del candidato completo, con le loro
verifiche di risultato, sono superati. Il sorgente Kit conserva il digest
candidato `188dc384…` riportato sopra nelle due fasi; i digest produttivi sono
originali nella fase strutture e ottimizzati nel candidato completo. Le
regressioni Release mirate sullo snapshot sono superate.

Il gate integrato `make verify` del 2026-11-21 è terminato con exit 0:
391 test Core, 59 Kit, 153 righe di oracoli riprodotte, 51 controlli CLI su
15 fixture, 22 checkpoint di recupero con interruzione del processo e due
PDF/A-2u validati. Sono completate le build Debug e Release macOS e iPadOS.
Il [riepilogo del gate](allegati/GS-VER-205-208-gate.json) e il
[log conservato](allegati/GS-VER-205-208-gate.txt) documentano i 376 ingressi
runtime e di verifica rimasti invariati durante la corsa, insieme ai digest
immutati dei quattro sorgenti produttivi del candidato completo. La prova
negativa della [guardia Debug del supporto](allegati/GS-VER-208-guard-debug.json)
è superata: una richiesta di misura in Debug viene rifiutata come previsto.

I [risultati nativi macOS](allegati/GS-VER-205-208-test-macos.json) riportano
55 test distinti superati e 195 esecuzioni complessive, senza failure,
test saltati o runtime warning. I warning del log riguardano il CoreSimulator
locale meno recente di quello richiesto da Xcode e la dichiarazione iPadOS
di apertura dei documenti in place. Non sono stati eseguiti test runtime
iPadOS; questo lotto non introduce né attesta un nuovo packaging di
distribuzione.

Le prove del lotto sono concluse. La cache di lavoro temporanea non è più
necessaria a questa evidenza e può essere rimossa dal coordinatore,
conservando tutti gli allegati e l'archivio sorgenti sopra identificato.

Non derivano da questi workload misure di energia, latenza UI, comportamento
sotto pressione reale o nuove soglie di rilascio. I gate scientifici, empirici,
su dispositivo, accessibilità e G4 mantengono i propri requisiti.


## Pulizia finale

Rimossa la sola cache del lotto dopo tutte le verifiche: **3.277.504 KiB,
circa 3,13 GiB allocati** prima della rimozione. Il
[record di pulizia](allegati/GS-VER-205-208-pulizia.json) conferma l'assenza del
percorso, distinguendo la misura dal delta di spazio libero APFS. Restano
allegati, audit e archivio sorgenti verificato; toolchain, dipendenze e cache
delle altre sessioni sono preservate.
