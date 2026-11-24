<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-314 — Ammissione documentale per gruppi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-314 |
| Tipo | Verifica e misura di ottimizzazione interna |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di ottimizzazioni e correzioni |
| Riferimenti | GS-DOR-314; CMP-314; ADR-0044 |

## Contratto e implementazione

L'helper interno `admissionByteCounts` indicizza soltanto gli Artifact riservati
che dichiarano esattamente una revisione ricca richiesta. Ogni bucket conserva
ordine e duplicati; il conteggio richiama il metodo singolo invariato per ogni
record originale. Sette mappe di ammissione già eager usano il nuovo helper.
I casi singolo e solo testo hanno percorsi dedicati; nessun indice persiste fra
operazioni o generazioni.

Il caricatore `importedSources` conserva il ciclo singolo: il guard sul budget
di un record precede la validazione dello snapshot del successivo. Anche
planAnalysis e altri percorsi singoli restano invariati. Non viene introdotta
una validazione globale di Artifact foreign o multi-revision prima ignorati.
Nessuna API pubblica, formula o rappresentazione persistente cambia.

## Verifica semantica

Sette definizioni mirate passano in Debug e Release. La versione finale Release
include 19 casi differenziali di selezione/failure e otto combinazioni di
candidato valido e malformed in entrambi gli ordini. Sono coperti conteggi
noti completi, ordine e ripetizioni, alias plain/rich con lo stesso ID,
snapshot assenti/ambigui, marcatori parzialmente riservati, conteggi fuori
range, candidati foreign/nil/vuoti/multi-ID e cinque precedenze di cancellazione.
Il loader verifica distintamente budget superato prima dello snapshot mancante
e budget sufficiente seguito da snapshot mancante.

La prima prova Debug è storica rispetto agli ultimi otto casi aggiunti; la
Release finale e il successivo gate Debug completo usano la suite definitiva.
La review indipendente non rileva blocker e conserva i report delle due
generazioni della suite. La suite finale ha SHA-256
`23223851a03dfe3b750bd7742cf3dd6e287409be72828dd5c0b4a4131a8e36a3`.

## Misura sugli helper di prodotto compilati

Ambiente: Apple M4, 10 CPU logiche, 16 GiB RAM, macOS 27.2.1, Xcode 27.2,
Swift 6.4.2, arm64. Il test Release compilato con @testable GlifiCore confronta
l'helper batch reale con il metodo singolo conservato. La corsa `--skip-build`
ha exit 0, dura 3,741 s e non rileva compilatori nei controlli prima/dopo.
Hash di sorgenti e oggetti compilati sono conservati nel dossier locale.

Ogni forma esegue warmup e sette campioni alternando l'ordine dei due metodi.
Ogni array prodotto è confrontato dopo il timer con tutti i conteggi noti,
oltre al checksum. Gli UUID sono deterministici; byte originali e catturati
seguono formule documentate nel generatore della suite. Nessuna soglia di
tempo determina il pass dei test.

| Fonti / ricche / Artifact | Mediana singolo ripetuto, ms | Mediana batch, ms | Variazione |
| --- | --- | --- | --- |
| 1000 / 0 / 1000 | 0,003708 | 0,010625 | +0,006917 ms |
| 25 / 25 / 50 | 0,214875 | 0,070542 | 3,05× |
| 100 / 25 / 500 | 0,465792 | 0,086750 | 5,37× |
| 250 / 125 / 2000 | 9,448500 | 0,402417 | 23,48× |
| 1000 / 500 / 5000 | 118,464083 | 1,509458 | 78,48× |

Nel caso maggiore, intervalli min–max: baseline 118,028459–122,140167 ms,
batch 1,498458–1,532917 ms. I sette campioni di ciascuna forma sono conservati
nel rapporto strutturato. Si accetta il costo aggiuntivo di circa 6,9 µs nel
controllo plain in cambio del beneficio nei gruppi ricchi medi/grandi; non
viene dichiarata un'accelerazione universale.

Lo spike iniziale aveva helper copiati e compilatori concorrenti: resta sola
provenienza della scelta, distinto da queste misure reali. Il caso massimo
10000/10000 non ha una mediana conclusa. I tempi riguardano soli metadati e
helper di ammissione; escludono I/O, decodifica JSON, attesa dell'actor,
estrazione e analisi completa. MemoryLayout.stride non rappresenta RSS;
energia e latenza dell'app non sono misurate.

## Gate integrato

Il make verify macOS della composizione completa è registrato nella chiusura
seguente. Non attesta CI remota, iPadOS, GUI manuale, accessibilità su dispositivo
o gate G4/G5.

## Chiusura della composizione macOS

La composizione congelata ha base `741da2e` e **1284 file**, fingerprint
`345c5f70a0ce4133c1325476a92f08ce40815bdad272ca5d75dc432131474b0e`. Il gate
`make verify` macOS termina con **exit 0** in **515,177 s**: 736 test Core,
161 Kit e 133 definizioni native / 420 esecuzioni Debug, senza failure, skip
o runtimeWarnings nel report nativo; build Release riuscita. La sola suite
Statistics ripete 12 definizioni / 57 esecuzioni in Release, senza errori.

Verificati anche 244 righe di oracoli e 64 casi Fraction, 2 PDF/A reali,
196 controlli CLI testuali, 132 operazioni / 264 confronti Kit-CLI, inventario
pubblico di 2840 dichiarazioni, 172 varianti e 22 checkpoint di recovery.
Il bundle Release ha risorse e lookup it/en corretti, 15 voci ispezionate e
zero corrispondenze nell’ambito vietato dichiarato. Non è un nuovo archivio
App Store e non attesta Finder o restoration.

Tutti i 1284 contenuti e modi coincidono con il manifest alla fine del gate;
archivio sorgente verificato, HEAD e indice invariati. Le sole evidenze e i
metadati di tracciabilità vengono chiusi dopo la verifica, conservando il
manifest del gate e il confronto separato dei file non documentali.
Il [rapporto strutturato](allegati/GS-VER-312-314-verifica.json) conserva
misure, conteggi e limiti. Il dossier locale `macOS-2026-11-24-audit-312`
contiene manifest, archivio, log, JSON sanificati e review indipendenti.

La diagnostica IDELaunchSession DVTAssertions appartiene a Xcode; i report
dei test non contengono runtimeWarnings. Restano esclusi CI remota di questo
lotto, iPadOS, audit visuali/assistivi manuali e G4/G5.
