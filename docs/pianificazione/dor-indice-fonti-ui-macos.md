<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Lookup delle etichette fonte nelle viste macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-231 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.5.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta di ottimizzazioni misurate; lookup ripetuto confermato nei due client macOS |
| Riferimenti | RQ-009; RQ-013; RQ-047; RQ-063; GS-STD-001-07/17; GS-UX-001-17; ADR-0033 |

## Problema e criterio di stop

`sourceName(revisionID:)` di `StudioTextAnalysisView` e `StudioKeynessView`
cerca ripetutamente la posizione mediante `snapshot.sources.firstIndex`.
La proposta usa un indice effimero costruito una volta per valutazione del body,
misurando anche quel costo. L'ottimizzazione produttiva attende una baseline
Release; se il beneficio non è dimostrato si conserva la ricerca lineare.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Ridurre il solo costo del lookup posizione fonte nei due client macOS, conservando il primo indice e fallback esistenti; nessuna nuova funzionalità, paginazione o modifica scientifica. Helper interno realmente usato dalle viste, non copia indipendente del benchmark |
| requisiti | RQ-009/013/047/063; stesso output completo degli ordinali e stesse etichette/identità accessibili, lookup entro lo snapshot corrente; misure prima/dopo con preparazione inclusa |
| contratto di dominio/API | Baseline dal helper app lineare invariato, su DTO snapshot/fonti Kit effettivi; risultato zero-based Int opzionale, primo match nell'ordine snapshot, nil per ID assente. Candidato interno `@MainActor final class StudioSourceLookup`, una istanza per body con input immutabili: fast path del primo ID prima di mappa/contatore, poi ricerca lineare sull’intero Array mediante firstIndex e accumulo delle visite come indice+1; dopo 64 passate equivalenti sulle fonti, indice first-wins costruito lazy soltanto per un lookup successivo effettivo. Budget 64×N e contatore con aritmetica saturante; nessuna cache globale, persistente o nel modello, nessuna API pubblica Kit/Core nuova |
| failure semantics | Nessun nuovo errore o I/O; ID assente conserva il fallback, duplicati conservano il primo indice; snapshot riordinato o sostituito non riusa un indice obsoleto. Nessun controllo di dominio indebolito |
| esperienza prevista | Identiche label Fonte N e identità, formato/byte, selezione, ordinamento e modificatori di accessibilità; nessun nuovo testo o comportamento iPadOS. La misura del lookup non viene chiamata misura di SwiftUI.body, hitch, energia o interazione GUI |
| verifica | Confronto dell'intero output Int? per snapshot vuoto, ID assenti, duplicati, riordino, sostituzione ed early-hit ripetuti; helper lineare e candidato nelle stesse forme DTO. Test nativo che attraversa fase lineare e indicizzata con output atteso indipendente. Release prima/dopo con due warmup e sette campioni grezzi per scenario, output completo identico fuori timer. Scenari Nfonti×Nlookup: 1 000×0, 1 000×1, 10×3, 100×1 000, 1 000×50, 1 000×10 000; GS-VER-231 candidata, review indipendente e gate/preflight macOS sul contenuto finale |
| dati e migrazione | Indice effimero O(Nfonti) derivato dai DTO; nessuna alterazione del progetto, Artifact, nome originale, ordine o formato persistente; nessuna migrazione |
| sicurezza/privacy | Dati sintetici deterministici, nessun corpus reale o contenuto/path nei log; nessuna rete, dipendenza, entitlement, telemetria o backend nuovo |
| prestazioni/sistema | Misurare il batch completo: costruzione dell'indice una volta più tutti i lookup e materializzazione dell'output, confrontato con il batch lineare. Fixture, risultati attesi e checksum fuori timer; memoria/allocazioni o relativi limiti dichiarati. Nessuna soglia G4/EA nuova |
| tracciabilità | CMP-231 inizialmente `specified`; RQ-009/013/047/063, nuova evidenza con ambiente/input/source hash e sette campioni, registri e CHANGELOG nello stesso incremento |
| decisioni e recupero | Ottimizzazione interna coerente con ADR-0033 e GS-STD-001-17; harness del root in package temporaneo con sola dipendenza locale GlifiKit già esistente, nessun prodotto runtime o dipendenza esterna nuova. Nessuna modifica al manifest Core, architettura, entitlement o gate di produzione; revert puntuale al lookup lineare se parità o beneficio non dimostrati |

## Misura e interpretazione

Il controllo del runner copre l'assenza osservata di `xcodebuild` e
`swift-frontend` ai checkpoint prima e dopo il run; non garantisce macchina
inattiva, assenza di altri carichi CPU/I/O o di contesa durante l'intervallo.
Si dichiarano tali limiti e i valori energetici registrati, senza chiamare la
sessione incontesa in senso assoluto.

In tutti e tre i segmenti temporizzati (costruzione, soli lookup e batch
completo), helper e output sono mantenuti esplicitamente vivi oltre la lettura
del clock finale, con uso o garanzia di lifetime dopo tale punto. Il teardown
resta fuori dalla misura, senza affidarsi all'ultimo uso dedotto dall'ottimizzatore.
Il medesimo confine vale per baseline e per entrambi i candidati; l'adeguamento
del harness non cambia il contratto runtime del prodotto.

La famiglia rappresentativa finale usa identificatori canonici
`source-revision:<UUID>` di 52 caratteri. I UUID sono deterministici dal seed
sintetico, in forma esadecimale minuscola 8-4-4-4-12, e validati con Foundation
UUID fuori timer. Anche gli ID assenti nelle richieste mantengono questa forma.
Le precedenti sonde con pseudo-ID SHA più lunghi rimangono soltanto diagnostiche:
non supportano claim prestazionali del client. Baseline, primo candidato e
candidato finale sono rimisurati sulla medesima famiglia UUID, con harness/hash
aggiornati e congelati prima delle passate definitive, sette scenari e campioni.

Le stringhe delle richieste sono decodificate separatamente mediante
JSONEncoder/JSONDecoder fuori timer, mantenendo gli stessi valori e hash ma
senza condividere lo storage delle stringhe source del DTO. Questa condizione
rappresenta snapshot e risultati applicativi distinti; il riuso diretto delle
stringhe può attivare un fast path di identità fisica di String e alterare il
confronto. La condizione di storage è dichiarata nella ricetta e il medesimo
harness aggiornato misura tutti e tre gli stadi prima di qualunque claim finale.

Il confronto finale comprende sette scenari: ai sei della tabella si aggiunge
1 000 fonti × 10 000 richieste tutte al primo ID. Tale early-hit economico
controlla il limite dell'euristica senza presumere un vantaggio dell'indice.
Il settimo scenario è aggiunto al harness prima di misurare il candidato;
baseline e candidato finali usano il medesimo harness aggiornato e congelato.

Il contratto dell'helper app e lo strumento di misura vengono congelati per il confronto;
si registrano separatamente gli hash dell'implementazione lineare e candidata,
con il solo delta di lookup ammesso. La
preparazione del DTO resta fuori timer, mentre la costruzione dell'indice per
il body è dentro il batch: non si presenta come beneficio un costo spostato
fuori dalla misura. Si registrano configurazione Release, revisione/hash di
sorgenti e fixture, hardware, OS/Swift/Xcode, memoria e condizioni energetiche,
metrica/unità, campioni grezzi, mediana e dispersione.

Ogni batch costruisce un indice nuovo; cache calda dopo warmup e costruzione
fredda dell'indice sono condizioni distinte. Non si dichiara una cache hardware
o file-system fredda senza averla controllata. Si riportano anche workload
piccoli o in regressione e il compromesso di memoria O(Nfonti), senza soglie di
rilascio dedotte dai soli microbenchmark. Nessuna formula numerica viene cambiata.

Il budget di 64 passate equivalenti è un'euristica interna di ammortamento,
non una soglia scientifica o di gate. La costruzione resta O(1) finché non è
richiesto l'indice; per nessuno o un solo lookup non si prepara la mappa. La
classe può comunque avere un costo costante diverso dalla struttura lineare:
il vantaggio non è promesso per ogni caso. Molti early-hit possono superare il
budget pur avendo una ricerca lineare breve; parità e compromessi restano
oggetto delle prove. Il fast path del primo ID ritorna zero prima di consultare
la mappa o incrementare il contatore, senza attivare la cache per richieste tutte
al primo elemento. Dopo il fast path fallito si usa l’Array completo e si ripete
intenzionalmente il primo confronto, senza `dropFirst`/ArraySlice; il contatore
aggiunge indice+1 per un match o N per l’assenza. Indici originali e primo match
sono conservati anche in presenza di duplicati. L'indice appartiene soltanto al body e non sopravvive a
snapshot diversi; non si costruisce dopo l'ultima scansione se non arriva una
successiva richiesta.

Ready 1.3 registra il tuning prima della patch: il primo candidato con budget
2×N ha output completi identici, ma regredisce nei casi 1 000×50 e first-only.
La nuova soglia conservativa e il fast path sono motivati da tali dati, senza
promozione del candidato intermedio o modifica di soglie scientifiche/gate.
Il nuovo candidato richiede proprie misure e regressioni prima dell'adozione.

Lo strumento riproducibile comprende
`Benchmarks/macOS/StudioSourceLookupBenchmark.swift` e
`Scripts/benchmark-macos-source-lookup.py`. Lo script prepara un package effimero
che dipende soltanto da GlifiKit locale e copia il helper app effettivo e il
harness, registrandone gli hash; non introduce un secondo algoritmo da misurare
al posto del prodotto. Compilazione Release con `-O` e guard che rifiuta DEBUG;
esecuzione sul Main Actor con fixture sintetiche tipizzate sui DTO Kit.

Oltre al batch completo, si registrano separatamente costruzione e soli lookup,
con helper/output mantenuti vivi e preparazione fixture fuori timer. Il JSON
riporta campioni grezzi, interi output degli indici, hash input/output/sorgenti,
OS/CPU, termica e Low Power Mode. I casi senza lookup o con un solo lookup
rendono visibile il costo della costruzione: non si promette che l'indice sia
sempre vantaggioso e non si presenta un costo spostato come eliminato.

`constructionOnly` misura soltanto il costruttore dell'helper. Nell'adattivo la
mappa è lazy: l'eventuale costo di costruzione avviene dentro il ciclo di
`lookupOnly` ed è incluso anche in `endToEnd`. La fase non viene descritta come
lookup puro con indice già preparato né come costo di mappa eliminato.

**Ready** prima dell'estrazione del helper. Baseline prima della patch
ottimizzata; poi candidato, parità, misure e gate. Soltanto macOS e verifiche
automatiche: nessuna prova GUI, VoiceOver, iPadOS o G4 viene inferita.

## Tuning Ready 1.4 prima della patch

Il protocollo UUID e storage distinto respinge anche il candidato 64×N con
ArraySlice: nel caso a cinquanta lookup la mediana passa da 0,253458 a
2,366125 ms; il vantaggio sul caso lungo non compensa tale regressione.
Il successivo candidato conserva budget, fast path, ownership e cache effimera,
ma ripristina la ricerca `Array.firstIndex` completa della baseline. È
un’ipotesi da misurare con lo stesso harness, non un esito già acquisito.
I due candidati precedenti rimangono documentati e non promossi; dopo la patch
servono test, confronto completo e nuovo gate/preflight del sorgente finale.

## Tuning Ready 1.5 prima della patch

Anche il candidato con Array completo regredisce a cinquanta lookup:
1,587333 ms contro 0,253458 ms della baseline. Il disassembly identifica
controlli dinamici MainActor per ogni elemento nella closure pura; il passo
resta respinto e non viene promosso.

Il nuovo candidato conserva Array.firstIndex completo, budget 64×N, fast path
e mutabili dell'helper isolati sul Main Actor. Il solo predicato di confronto
diventa esplicitamente `@Sendable`, catturando soltanto il parametro String
immutabile e leggendo il DTO Sendable: niente self, cache, budget o stato UI
catturato. Non introduce Task, hop, unsafe, async o API pubbliche nuove.
Review di isolamento, disassembly del predicato, parità completa e misure/test
del nuovo sorgente devono confermare l'ipotesi prima dell'adozione; il nuovo
gate/preflight resta necessario. La rimozione del confine dinamico ripetuto
non indebolisce l'ownership MainActor dello stato mutabile.
