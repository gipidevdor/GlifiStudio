<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-207 — Validazione e codifica esadecimale dei digest

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-207 |
| Tipo | Evidenza di ottimizzazione misurata e verifica contrattuale |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-207; RQ-009; RQ-010; RQ-023; RQ-063 |
| Riferimenti | GS-STD-001-17; GS-DAT-001; GS-MET-001-01; TV-009; TV-012; TV-027; TV-054; TV-076; CMP-207 |

## Perimetro e contratto

La [GS-DOR-207](../pianificazione/dor-ottimizzazione-codifica-digest.md) è
Ready prima del coding. Il cambiamento introduce due funzioni interne pure:
validazione del linguaggio `sha256:` seguito da esattamente 64 simboli ASCII
`0-9a-f`, e codifica dei 32 byte SHA-256 in esadecimale minuscolo.

Il validatore considera i byte UTF-8 senza costruire `Character` per ogni
simbolo. La codifica usa una tabella di 16 byte e un buffer riservato di
71 byte, prefisso incluso, senza accessi unsafe. Conserva tutti i byte
del digest: non salta l'hash e non memorizza risultati in una cache.

`GlifiDigestIdentifier` richiama il validatore interno. Il parsing del
namespace generico conserva `hasPrefix` e `dropFirst` sui Character;
namespace Unicode, UUID, rappresentazione canonica, Codable e failure
restano invariati. JSONEncoder, campi del descrittore e proiezione
dell'identità del nodo non rientrano nella modifica.

Il coordinatore ha integrato le due sostituzioni puntuali in
`GlifiAnalysisGraph`: delega del validatore `isSHA256Digest` e codifica del
risultato di `SHA256.hash`. La fase intermedia GS205/206 mantiene la resa
con formatter per separare il contributo delle strutture dati da quello
GS207. La revisione del diff intermedio/finale conferma esclusivamente
queste due deleghe nel Graph; impostazioni JSON, hash e heap restano invariati.
Il confronto A/B e il gate completo del coordinatore sono superati.

## Identità delle fonti e della baseline

Il coordinatore ha congelato una copia di **279 file** di Package e fixture
dalla copia di lavoro prima delle modifiche produttive del lotto. Il file
`baseline-inventory.json` contiene 279 voci, SHA-256
`5a1a6ad7c86c88749ef1931228fcf2b79a95ae701798c7104c742974f5d3b341`.
La copia deriva dalla baseline repository
`a86a53b512bd777f191c89692e0c573a3d37a3ff` e dagli incrementi locali
concomitanti: non rappresenta un checkout del solo commit.

| Artefatto | SHA-256 |
| --- | --- |
| `GlifiAnalysisGraph.swift`, baseline con formatter e validatore originali | `06e1ebb213c428a2d2ea5f6f5e154d18be4aabcf373a80a448faf8e3693f6c47` |
| `GlifiAnalysisGraph.swift`, fase strutture senza GS207 | `4abe87e72d77fda8b1b07e2597483fddf7b75c606e0dc87e7426600bb2c23595` |
| `GlifiAnalysisGraph.swift`, candidato finale integrato | `7fde3f0ebf3da8e0fce5a832f3f9a1b75622c71ae1428d42605c831c9086c0d9` |
| `GlifiIdentifiers.swift`, baseline | `b85db1d06d29aa4c9f18e125f5b07d78f5814305bb1032211448bc082811940f` |
| `GlifiIdentifiers.swift`, candidato misurato e verificato | `7e518c114fe27a66456a1ad30c0bde383631ce179266b58e7fa0468e1bb935e6` |
| Nuovo `GlifiDigestEncoding.swift`, candidato misurato e verificato | `ec5593b55a10bebe4e2a796f881b2d296b697dce9a0571a1bd5897bb66114c1c` |
| `GlifiDigestOptimizationTests.swift`, harness corretto e congelato | `8a91099b99b3410025de5b982019d43a1539f3d9fba03f07778d6ad91d763362` |
| `GlifiPipelineBenchmarkSupport.swift`, supporto condiviso | `3721ce3314445571bbc5f03163f55a030a3f03c2d09a623f2e976dc98e22dae0` |
| `GlifiDigestEncodingTests.swift`, test diretti aggiunti solo nel workspace | `dbb71597b02141e2e49efc9ae9b88b132f618f0082f6315c9e6dfd56c106e778` |

Gli inventari di [baseline](allegati/GS-VER-205-207-inventario-baseline.json),
[fase strutture](allegati/GS-VER-205-207-inventario-structures.json) e
[candidato](allegati/GS-VER-205-207-inventario-candidate.json) documentano
279 → 279 → **280 file**. La fase strutture modifica soltanto Graph e
proiezione derivata GlifiKit. Il candidato finale modifica gli stessi due
file e `GlifiIdentifiers.swift`, e aggiunge `GlifiDigestEncoding.swift`:
**276 file congelati restano identici**, senza rimozioni o cambi a fixture
e harness. Rispetto alla fase intermedia cambiano esclusivamente Graph,
Identifiers e l'aggiunta dell'helper. Gli inventari intermedio e finale
hanno SHA-256 rispettivamente
`abe6b69816b461731bd6c87f978e0c964e3b9cb1546c3e235c2d9d6101b0d6ca` e
`c2b9721df031184aeda16b4791b2403da653008ddfaaa216d2dbc0807b8bedaa`.

Il [record dell'archivio sorgenti](allegati/GS-VER-205-208-archivio-sorgenti.json)
conserva **729.337 byte**, SHA-256
`a9f0ac28e3799f993f7d5e4c62991c87c1d0231247669ad95f775debb4e85da1`.
La verifica indipendente legge tutti i **293 membri regolari** senza estrarli:
280 file candidati confrontati con l'inventario, tre sorgenti della baseline,
due della fase strutture, sei inventari/record di audit e due test finali
aggiuntivi. I tre inventari sono identici agli allegati; audit e test
aggiuntivi coincidono con i file conservati dal coordinatore. Non risultano
duplicati, link, device, traversal, percorsi assoluti o cache di build.

## Correzione delle aspettative e baseline accettata

Il primo tentativo Digest non è accettato come baseline: il test attribuiva
erroneamente `retainedState = unchanged` anche alle failure di
`GlifiAnalysisDependency` e `GlifiAnalysisArtifactReference`. I **756 issue**
corrispondevano ai 252 input malformati per tre controlli di questi due tipi.

Il prodotto usa `analysisGraphFailure`, che applica la tassonomia esistente:
`invalidInput`, `analyze`, `afterCorrection`, `lastCommittedGeneration`.
Gli identificatori dichiarano invece esplicitamente `unchanged`. Le
aspettative corrette distinguono queste due famiglie con tuple esplicite;
il confronto rimane sull'intero `GlifiFailure`, inclusi codice, categoria,
operazione, retry, stato conservato, chiave del messaggio e argomenti.

La correzione cambia esclusivamente due aspettative e aggiunge il relativo
helper di riferimento. **Nessun prodotto, fixture, generatore, timer o
checksum è stato cambiato per correggere il test.** Il coordinatore ha
ricompilato il test e riacquisito l'intera baseline del lotto: Graph,
Projection e Digest terminano tutti con **exit 0**, con 16 scenari complessivi.
La corsa Digest corretta esegue un test in 28,490 s ed è l'unica baseline
Digest riportata qui.

## Metodo, regressioni e dati sintetici

L'entry `domainOptimizationDigest` esegue sempre una regressione piccola
sulle API esistenti. **301 input** comprendono 16 digest uniformi, 11 casi
di confine, tutti i 128 simboli ASCII sostituiti all'inizio e alla fine del
payload e 18 sostituzioni Unicode. Sono 49 input validi e 252 malformati,
con ripetizioni intenzionali. Il riferimento mantiene la precedente
validazione `count`, `dropFirst` e `Character.contains`.

La prova verifica identificatori, valori canonici, round-trip JSON,
dipendenze e riferimenti Artifact; gli errori sono confrontati integralmente.
Il namespace generico `café.分析:🔎` viene letto sia in forma composta sia
decomposta. Sono coperti prefisso e namespace errati, maiuscole, lunghezze
63/65, whitespace, NUL, newline, caratteri fullwidth, segni combinanti,
emoji e un payload sovradimensionato sintetico.

Descrittori v1/v2 piccoli e grandi sono confrontati con un riferimento
CryptoKit che usa il formatter originale e una proiezione esplicita di
tutti i campi dell'identità del nodo. Dipendenze ordinate, revisioni
opzionali, Unicode, escape e slash sono inclusi. Restano verificati i
valori d'oro v1 preesistenti: digest completo
`sha256:760dd96a1d0cacc83a72dc2e1a9b9662253b74f1af8a93f0c924402efb468e3d`
e nodo
`analysis-node:sha256:4df18da1aebd9326390164965dbdfd2fad9951da7f7d3a4cb5659252ffde168f`.

Soltanto con `GLIFI_PIPELINE_BENCHMARK_DIRECTORY`, in Release, sono misurati
cinque scenari. I 50.000 identificatori validi ciclano 256 digest sintetici
deterministici; il caso malformato cicla i 252 input rifiutati. I due gruppi
da 1.000 descrittori alternano v1/v2: il gruppo piccolo ha un parametro
Unicode, quello grande 32 parametri annidati e otto dipendenze.

Fixture, riferimenti e risultati attesi sono preparati fuori dal timer.
L'intervallo misura gli initializer oppure `canonicalDigest()` e `nodeID()`
completi, inclusi gli hash e l'encoder JSON necessari a quelle API.
Ogni scenario ha **un warm-up e sette campioni**, con uguaglianza completa
e checksum del risultato dopo lo stop: baseline corretta e candidato
superano tutti gli **otto confronti su otto** di ciascuno scenario,
con identici digest delle fixture e dell'intero risultato.

I due test diretti del nuovo helper sono aggiunti **soltanto nel workspace**,
dopo il congelamento dell'harness. Coprono i vettori SHA-256 vuoto/`abc`,
256 hash con confronto al formatter e copertura di tutti i valori byte,
oltre a **415 input** ASCII/Unicode confrontati con il validatore originale,
anche tramite bridge `NSString`. Non modificano la copia A/B; entrambi
passano nel successivo gate completo sul workspace.

## Ambiente e risultati A/B

| Campo | Valore osservato in baseline e candidato |
| --- | --- |
| Hardware | `Mac16,3`, 10 processori logici, 17.179.869.184 byte di memoria fisica |
| Sistema | `Version 27.2.1 (Build 26B131)` |
| Toolchain selezionata e verificata dal gate | Xcode 27.2, Apple Swift 6.4.2, language mode 6, SwiftPM tools 6.4 |
| Configurazione | Eseguibile di test SwiftPM Release, un workload per misura |
| Stato termico iniziale/finale | `nominal` → `nominal` |
| Low Power Mode iniziale/finale | `true` → `true` |
| Cache | Processo caldo, nessun flush della cache del sistema |
| Esecutore e data | Codex, 2026-11-21 |

Valori in millisecondi, mediana e intervallo minimo–massimo dei sette campioni:

| Scenario | Baseline mediana [min–max] | Candidato mediana [min–max] | Riduzione della mediana |
| --- | --- | --- | --- |
| 50.000 `ArtifactID(digest:)` | 388,873 [388,300–390,430] | 10,805 [10,765–10,836] | 97,22% |
| 50.000 `ArtifactID(canonicalValue:)` | 449,999 [396,651–450,831] | 17,687 [17,567–18,709] | 96,07% |
| 50.000 digest malformati, failure complete | 289,153 [288,672–312,278] | 43,599 [43,388–44,366] | 84,92% |
| 1.000 descrittori piccoli, digest completo e nodeID | 117,039 [115,564–117,914] | 40,466 [40,435–40,684] | 65,43% |
| 1.000 descrittori grandi, digest completo e nodeID | 1.459,321 [1.446,422–1.508,419] | 1.370,347 [1.347,464–1.398,667] | 6,10% |

I campioni grezzi sono conservati negli allegati di
[baseline](allegati/GS-VER-205-207-baseline.json),
[fase strutture](allegati/GS-VER-205-207-structures.json) e
[candidato](allegati/GS-VER-205-207-candidate.json), con il
[confronto](allegati/GS-VER-205-207-confronto.json). I cinque scenari Digest
sono presenti nella baseline e nel candidato finale; la fase intermedia
contiene soltanto gli 11 scenari Graph e Projection per isolare GS205/206.
La rilettura indipendente di tutti i 16 + 11 + 16 JSON conferma sette
campioni, mediana/minimo/massimo, otto confronti, identità di fixture e
risultato, configurazione e condizioni macchina equivalenti. Le percentuali
Digest sono ricalcolate sui dati non arrotondati.

La velocità osservata è rispettivamente **35,990**, **25,442**, **6,632**,
**2,892** e **1,065 volte** la baseline. Il beneficio riguarda questi batch
di API e include i costi che restano necessari: il descrittore grande,
che mantiene l'encoder JSON completo, migliora meno del solo identificatore.
Nessun risultato attesta un'accelerazione uniforme dell'intera app o di
tutti i percorsi che producono digest. La maggiore dispersione del caso
canonico baseline resta visibile nell'intervallo e nei campioni grezzi.

Il [riepilogo dei processi](allegati/GS-VER-205-207-processi.json), con i log
di [baseline](allegati/GS-VER-205-207-baseline-processi.txt),
[strutture](allegati/GS-VER-205-207-structures-processi.txt) e
[candidato](allegati/GS-VER-205-207-candidate-processi.txt), conserva RSS
delle intere invocazioni. Quello Digest da `/usr/bin/time -l` passa da
**384.335.872** a **384.466.944 byte**, una differenza di **131.072 byte**
(0,125 MiB). Comprende processo di test, setup, riferimenti e controlli:
non è una misura di memoria per singolo digest, buffer, API o UI e non
attesta una riduzione delle allocazioni. Entrambe le corse Digest terminano
con exit 0; quella candidata esegue un test in 18,378 s.
La preparazione nel workspace supera lint e diff-check; revisione indipendente
del validatore, del buffer e dell'integrazione Graph non ha rilevato difetti
concreti. Dopo le misure, i filtri Release mirati sulla copia congelata
terminano con exit 0: **nove test Core e tre Kit**, 12 complessivi. Il test
Digest e le regressioni Graph passano in questa corsa. I test diretti del
nuovo helper sono separati nel workspace e non fanno parte di questo
conteggio. Il [log mirato conservato](allegati/GS-VER-205-208-test-mirati.txt)
documenta i 12 test Release.

## Gate completo e controllo negativo del supporto

Il coordinatore ha completato **`make verify` con exit 0**, profilo globale
macOS/iPadOS. Il [record del gate](allegati/GS-VER-205-208-gate.json) e il
[log completo sanificato](allegati/GS-VER-205-208-gate.txt) attestano che
i **376 file di ingresso** di runtime e verifica restano invariati durante
la corsa; le quattro fonti produttive del candidato conservano gli hash
misurati.

| Controllo | Esito osservato |
| --- | --- |
| Swift Testing GlifiCore | 391 test superati |
| Swift Testing GlifiKit | 59 test superati |
| Test nativi macOS | 55 distinti, 195 esecuzioni sulla destinazione, zero failure o skip |
| Oracoli indipendenti | 153 righe riprodotte e collegate ai test Swift |
| Operatori testuali CLI | 51 controlli su 15 fixture condivise, parità entro `1e-12` |
| Recovery dopo terminazione del processo | 22 checkpoint di commit validi |
| veraPDF | Due PDF/A-2u conformi |
| macOS | Test/build Debug e build Release senza firma |
| iPadOS | Build Debug e Release senza firma per destinazione generica iOS Simulator |

Il log registra superati entrambi i nuovi test diretti: «La codifica SHA-256
conserva i vettori noti e tutti i valori di byte del formatter» e «Il
validatore UTF-8 accetta esattamente il linguaggio del controllo Character
originale». La copertura comprende i 256 hash e i 415 input aggiuntivi;
il [riepilogo macOS](allegati/GS-VER-205-208-test-macos.json) distingue i
55 test nativi dalle 195 esecuzioni sulla destinazione.

Il [controllo negativo GS208](allegati/GS-VER-208-guard-debug.json), separato
dal gate, verifica la misura richiesta esplicitamente in Debug: exit 1
atteso e osservato, `releaseConfigurationRequired` rilevato, nessun rapporto
benchmark JSON scritto. È un rifiuto controllato superato, non una misura
Debug confrontata con Release.

Xcode segnala CoreSimulator installato `1171.7.0` precedente a `1174.21.0`
e l'avviso sulla dichiarazione di apertura in-place dell'app iPadOS. Le
build generiche superate non attestano esecuzioni runtime del simulatore;
il gate non esegue nuovi archivi o una nuova convalida del packaging
App Store. La versione OS osservata è riportata esattamente e non viene
dedotta dalla versione della toolchain o dal deployment target.

## Limiti e stato della verifica

Il confronto A/B è superato. Le misure sono informative, limitate alla
macchina, agli input sintetici e alle condizioni registrate; non introducono
soglie vincolanti né attestano prestazioni
end-to-end dell'app, memoria per API, energia o cache fredda.

La verifica GS207 è chiusa e la cache di lavoro è disponibile per la pulizia
del coordinatore. Questo incremento non elimina la cache condivisa;
rapporti, inventari, log sanificati e archivio sorgenti restano conservati.


## Pulizia finale

Rimossa la sola cache del lotto dopo tutte le verifiche: **3.277.504 KiB,
circa 3,13 GiB allocati** prima della rimozione. Il
[record di pulizia](allegati/GS-VER-205-208-pulizia.json) conferma l'assenza del
percorso, distinguendo la misura dal delta di spazio libero APFS. Restano
allegati, audit e archivio sorgenti verificato; toolchain, dipendenze e cache
delle altre sessioni sono preservate.
