<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-202 — Ricerca indicizzata dei segmenti SpanMap

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-202 |
| Tipo | Evidenza di ottimizzazione della provenienza e compatibilità |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-202 Ready prima del coding; richiesta dell'iniziatore |
| Riferimenti | GS-STD-001-17; GS-DAT-001; RF-009; RF-017; RQ-009; RQ-063; CMP-202 |

## Perimetro e contratto

La [GS-DOR-202](../pianificazione/dor-ottimizzazione-spanmap-indicizzata.md)
seleziona le scansioni complete dei segmenti in
`GlifiSpanMap.sourceRanges(for:)` e `composed(after:)`. Il primo metodo visitava
tutti gli S segmenti per ogni intervallo; la composizione ripeteva la visita
di tutti i segmenti interni per ogni intervallo di origine esterno.

Un indicatore privato derivato permette due ricerche binarie soltanto quando
gli intervalli di output sono non vuoti, ordinati e disgiunti. Il metodo
visita poi una `ArraySlice` dei soli segmenti candidati, senza copiarli.
Per i lookup conformi il costo di selezione diventa O(log S), seguito dalle
origini effettivamente visitate. La composizione conserva il costo preesistente
di deduplicazione e coalescenza delle origini: non si dichiara una complessità
lineare dell'intero algoritmo per qualsiasi numero di origini.

Le sette proprietà Codable rimangono `contractIdentifier`, `sourceRevisionID`,
`inputSpace`, `outputSpace`, `inputByteCount`, `outputByteCount` e `segments`.
Il marker è escluso da `CodingKeys` e non è letto dal JSON. La decodifica
conserva campi, accettazione e valori legacy, poi deriva l'invariante locale
dai segmenti. Mappe disordinate, sovrapposte o con intervalli vuoti o invertiti
mantengono la precedente scansione completa; non sono ordinate o corrette
silenziosamente. Anche mappe ordinate con gap conservano gli stessi risultati.

Il costruttore pubblico aggiorna il marker nel ciclo di validazione esistente:
la copertura contigua già verificata, insieme agli intervalli non vuoti,
implica ordine e disgiunzione. Non viene presunto valido un intervallo annidato
solo perché costruito attraverso un decoder. La decodifica deriva invece il
marker con una visita O(S) aggiuntiva. Non esiste cache di fiducia persistente.

Restano invariati ordine delle origini, merge degli intervalli adiacenti,
regole exact/contributive/derivational/synthetic, controllo half-open e failure
di incompatibilità o fuori limite. Nessun formato, API applicativa, parametro
scientifico, backend, rete o operazione sul Main Actor viene introdotto.

## Identità dell'esperimento

La baseline Release è stata acquisita prima della patch produttiva. Una copia
isolata contiene **271 file**; l'inventario candidato conserva **268 file
identici** e sostituisce soltanto i tre sorgenti dei lotti GS-VER-202,
GS-VER-203 e GS-VER-204. Harness, fixture, package e kernel analitici restano
gli stessi nelle due copie. Gli incrementi analitici concomitanti del working
tree non vengono attribuiti a questo confronto.

| Ingresso | SHA-256 |
| --- | --- |
| `GlifiSpanMap.swift`, baseline | `38baad1d31c34dcaf9ea62e953dd950229959c58feee80694dca8731becb5e0d` |
| `GlifiSpanMap.swift`, candidato | `3bda338c6c449ef2a2361091b27605262f2dd802c045158217110b30298c7d03` |
| `GlifiSpanMapOptimizationTests.swift`, harness identico | `0e8a0a9284250cefa7c9b06905bcb8c80b9d190458a4e12795845a6e7eadbf88` |
| Inventario baseline | `60efee04fa6f582259e5ebd6e63c59a4781b889d214d6dbce523fc22a22dd820` |
| Inventario candidato | `60c5841e755db2664ff8264f1bea2a36b6379ce794d59058bbfb29d9fd9fb551` |

Il runner esegue tre processi separati in sequenza, filtrando rispettivamente
`pipelineOptimizationSpanMap`, `pipelineOptimizationTokenizer` e
`pipelineOptimizationCSV`. Ogni scenario usa un warm-up e sette campioni;
uguaglianza completa con il riferimento e SHA-256 sono controllati dopo lo
stop del timer in tutte le otto esecuzioni. Non si confrontano soltanto
conteggi o un checksum scalare parziale.

`pipelineOptimizationSpanMap` confronta sempre lookup e composizione su
fixture piccole con il riferimento lineare. Le misure grandi sono abilitate
soltanto da `GLIFI_PIPELINE_BENCHMARK_DIRECTORY`. Preparazione di fixture e
riferimento, serializzazione dei risultati, hash e scrittura del rapporto
restano fuori dal timer. La misura del costruttore include invece la
validazione completa e la derivazione del marker, su segmenti di input
condivisi tramite COW; questo costo non viene nascosto nel solo setup.

## Misure A/B osservate

Ambiente registrato: `Mac16,3`, 16 GiB di memoria fisica, dieci processori
logici, macOS `Version 27.2.1 (Build 26B131)`, eseguibile di test SwiftPM
**Release**. I rapporti baseline e candidati registrano stato termico nominale e
Low Power Mode attivo all'inizio e alla fine. Processo caldo, senza cache
flush né modifica dello stato energetico per ottenere il risultato.

Baseline e candidato terminano con exit 0. Valori in millisecondi:
mediana e intervallo minimo–massimo dei sette campioni.

| Scenario | Baseline mediana [min–max] | Candidato mediana [min–max] | Rapporto fra mediane |
| --- | --- | --- | --- |
| Costruzione di 20.000 segmenti | 0,202625 [0,192625–0,212167] | 0,184750 [0,176167–0,272542] | 1,10× |
| 1.000 lookup sparsi su 20.000 segmenti | 19,738333 [19,417458–19,751125] | 0,417208 [0,414708–0,434833] | 47,31× |
| Composizione 5.000 × 5.000 segmenti | 20,565083 [20,522292–20,694000] | 1,066167 [1,059167–1,168917] | 19,29× |

La riduzione osservata della mediana è 97,89% per i lookup e 94,82% per la
composizione. Il costruttore non mostra un aumento della mediana in questa
corsa; gli intervalli di costruzione si sovrappongono e il candidato presenta
un campione massimo superiore. Non si attribuisce significatività statistica
al piccolo scarto del costruttore né si introduce una soglia.

| Scenario | Digest della fixture | Digest del risultato di riferimento |
| --- | --- | --- |
| Costruzione | `sha256:b9023553c77d0aec0659e84199ff600a6bcb1bd3ec8dbd4ea450a82132b64ef1` | `sha256:b9023553c77d0aec0659e84199ff600a6bcb1bd3ec8dbd4ea450a82132b64ef1` |
| Lookup sparsi | `sha256:e5b0a8228a65390aa53097760c5ada6dc4b719f77697cf8ec883d01e46e34810` | `sha256:90185112b75d8a23f667626e26ef959c215729230c0cc80909ae8acf48daf536` |
| Composizione | `sha256:8dde4c93524a0b61318219ad505466ea315d5ca11eb268091f5c63d5adb50064` | `sha256:780839a606d600a27d8f8d3f08b97f64294064f03e81502789fde5809e1cf260` |

I digest di fixture e risultato coincidono fra le due fasi e con il
riferimento completo in tutte le otto esecuzioni di ciascuno scenario.
I rapporti conservano i sette campioni grezzi, ambiente e perimetro del timer:
[baseline](allegati/GS-VER-202-204-baseline.json),
[candidato](allegati/GS-VER-202-204-candidate.json),
[confronto](allegati/GS-VER-202-204-confronto.json),
[inventario baseline](allegati/GS-VER-202-204-inventario-baseline.json) e
[inventario candidato](allegati/GS-VER-202-204-inventario-candidate.json).
I rapporti archiviati conservano le prove oltre la durata della cache di lavoro.

I [riscontri di processo](allegati/GS-VER-202-204-processi.json), con gli output
grezzi [baseline](allegati/GS-VER-202-204-baseline-processi.txt) e
[candidato](allegati/GS-VER-202-204-candidate-processi.txt), riportano RSS massimo
110.673.920 → 88.457.216 byte per l'intera invocazione SpanMap. Il valore
include SwiftPM, fixture, riferimenti e controlli: non misura la memoria del
solo lookup/composizione e non ne dimostra una riduzione attribuibile al marker.

Il [record dell'archivio sorgenti](allegati/GS-VER-202-204-archivio-sorgenti.json)
conserva la posizione della copia riproducibile: 664.425 byte, SHA-256
`3ef945ed177466487e25ddd997e48ca027b175285f677de53919a15fdf628a15`.
L'archivio contiene i 271 file congelati, i tre sorgenti produttivi baseline,
i due inventari e la regressione CSV finale aggiuntiva; esclude la cache di build.

## Regressioni e riesame

I tre test nuovi comprendono il riferimento completo di lookup/composizione,
half-open, coalescenza anche attraverso segmenti synthetic, codifica canonica
identica alla rappresentazione legacy a sette campi, round-trip e failure
fuori limite. Cinque rappresentazioni JSON legacy verificano disordine,
sovrapposizione, intervallo invertito, intervallo vuoto e gap. Per ciascuna
si confrontano cinque lookup e una composizione con la scansione lineare.
Un ulteriore caso esercita il costruttore pubblico con intervallo annidato
invertito precedentemente decodificato.

Il riesame indipendente dell'agente incaricato di GS-VER-203 non ha rilevato
problemi nel marker, nei campi Codable, nella geometria legacy, nel fallback,
nei limiti o nel merge. È una revisione in sola lettura e non sostituisce
build e test. Formatter strict e `git diff --check` del cambiamento produttivo
sono superati; la baseline ha eseguito il solo entry di riferimento e misura.

La successiva corsa Release mirata comune contiene **12 test superati**, inclusi
i tre nuovi test GS-VER-202 e i due test di composizione preesistenti. I tre
nuovi test sono eseguiti, compresi decoder legacy e round-trip, oltre al confronto
sintetico piccolo. Il controllo preesistente attraversa 500 trasformazioni
con seed `0x5EED_0078`, verifica tutte le origini e i byte dei tratti exact.
Il log riporta 0,129 s per la corsa comune; non è una misura prestazionale del
componente. Le misure A/B descritte sopra provengono dai processi dedicati.

## Gate integrato

`make verify` termina con **exit 0** sul profilo macOS e iPadOS. I tre sorgenti
produttivi di questo lotto mantengono gli hash candidati; per SpanMap è
`3bda338c6c449ef2a2361091b27605262f2dd802c045158217110b30298c7d03`.
I risultati sono conservati nel [record del gate](allegati/GS-VER-202-204-gate.json),
nel [log](allegati/GS-VER-202-204-gate.txt), nei
[test mirati Release](allegati/GS-VER-202-204-test-mirati.txt) e nel
[riepilogo dei test macOS](allegati/GS-VER-202-204-test-macos.json).

| Controllo | Esito osservato |
| --- | --- |
| SwiftPM | 380 test Core e 52 test Kit superati |
| Test nativi macOS | 46 test distinti, 108 esecuzioni per dispositivo; zero failure e skip |
| Oracoli | 153 righe riprodotte |
| Analisi CLI | 51 controlli su 15 fixture |
| Recovery | 22 checkpoint con interruzione SIGKILL superati |
| Export PDF/A | Due file conformi PDF/A-2u |
| Build del workspace | macOS Debug/Release e iPadOS Debug/Release superate |

Il gate registra i propri ingressi. Il successivo
[ripasso Core/Kit](allegati/GS-VER-202-204-ripasso-core-kit.json), con
[log conservato](allegati/GS-VER-202-204-ripasso-core-kit.txt), include le
modifiche concomitanti ai pesi dei termini e ai relativi test: **exit 0,
381 test Core e 52 Kit superati**, con 205 file sorgente/test invariati durante
l'esecuzione. I tre sorgenti di questo lotto restano quelli del candidato.

Gli avvisi noti riguardano CoreSimulator installato `1171.7.0` rispetto a
`1174.21.0` richiesto e la dichiarazione iPadOS di apertura documentale in
place. I test macOS sono nativi e superati; non sono stati eseguiti test su
runtime del simulatore iPadOS. Il gate non attesta una nuova verifica di firma,
packaging o distribuzione App Store.

## Limiti e recupero

I risultati riguardano questi workload sintetici headless. Non misurano
latenza della UI, energia, file provider, memoria residente del componente o una baseline
approvata G4. La costruzione pubblica mantiene O(S); la decodifica aggiunge
una verifica O(S) prima di poter riusare le ricerche indicizzate. Le mappe
legacy non conformi conservano il costo lineare e l'accettazione precedente:
non si attesta una nuova validazione degli input decodificati.

Nessun timer, osservatore, polling o cache globale. Nessuna nuova soglia di
rilascio. Recupero mediante revert puntuale, senza migrazione. Gli archivi
sorgente e i rapporti sono conservati; la cache di build non è parte della
prova riproducibile.


## Pulizia finale

Rimossa la sola cache di lavoro del coordinatore dopo la chiusura delle prove:
**3.443.576 KiB, circa 3,28 GiB allocati** prima della rimozione. Il
[record di pulizia](allegati/GS-VER-202-204-pulizia.json) conferma l'assenza del
percorso e distingue la dimensione allocata dal delta di spazio libero APFS.
Allegati, log sanificati, inventari e archivio sorgenti verificato restano
conservati; toolchain, dipendenze e cache delle altre sessioni sono preservate.

## Riesame successivo degli intervalli

[ADR-0042](../adr/0042-invarianti-intervalli-utf8-decodificati.md) e
[GS-VER-234](GS-VER-234-riverifica-correttezza-completezza.md) superano la scelta
storica di accettare intervalli vuoti/invertiti: tali input ora falliscono prima
del consumo. Il fallback delle geometrie legacy con intervalli validi resta
confrontato con il percorso lineare. Gli esiti sopra sono storici, non una
richiesta di mantenere decoder che aggirano l’invariante del tipo.
