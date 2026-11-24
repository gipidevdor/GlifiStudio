<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-203 — Riuso dei confini dei token speciali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-203 |
| Tipo | Evidenza di equivalenza e confronto prestazionale del tokenizer |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | Attuazione GS-DOR-203 nel programma complementare autorizzato |
| Riferimenti | GS-DOR-203; CMP-203; GS-LNG-001; GS-STD-001-17; RF-079; RF-009; RQ-009; RQ-011; RQ-063 |

## Perimetro e identità

L'incremento applica la
[GS-DOR-203](../pianificazione/dor-ottimizzazione-token-speciali.md) soltanto a
`GlifiItalianTokenizer.swift`. Il contratto rimane `it-token-v1`: nessuna nuova
classificazione linguistica, API, dipendenza, cache persistente o modifica ai
byte della fonte.

La baseline Release è stata misurata dal coordinatore prima della patch
produttiva. I sorgenti di riferimento sono congelati nella copia dedicata del
lotto; codice e misure degli altri incrementi non sono attribuiti a questa
ottimizzazione.

| Ingresso | SHA-256 |
| --- | --- |
| Tokenizer precedente | `bb054f7f60b69bd75f84de0172ee473936d7eb77a37083a11c618cd2b0c67d83` |
| Tokenizer candidato | `536073b18e01d4d853e1a5f4df6a95c799218de4ebb9a746c4a1ad912031f1b5` |
| `GlifiTokenizerOptimizationTests.swift`, identico per baseline e candidato | `8ae54d897469e0061882726dd9cbf6e87ca9e5e63ab82099269d106abada44ec` |
| `GlifiPipelineBenchmarkSupport.swift`, helper delle misure | `9b4b65677c7d34ef2778798bdb83f70efc0772094f36c41e3c39ee4fc278b5bd` |

## Costo precedente e correzione candidata

Per ogni posizione da classificare, il tokenizer precedente ricercava la fine
della sequenza senza whitespace e rimuoveva i delimitatori finali. Una sequenza
di punteggiatura senza spazi ripeteva queste scansioni su suffissi progressivi.

Il candidato conserva soltanto due indici locali all'esecuzione: fine della
sequenza e fine dopo il trim dei delimitatori. I confini vengono calcolati una
volta per sequenza. Per una posizione successiva, la fine del candidato è il
massimo fra la posizione corrente e la fine dopo il trim: anche una sequenza
composta interamente da delimitatori conserva i singoli token precedenti.

La distanza fra cluster conta i `Character` del candidato **dopo il trim**.
Se supera 2.048, email e URL non possono essere accettati dai controlli
precedenti, che ammettono rispettivamente 320 e 2.048 caratteri. Il candidato
può quindi essere scartato prima della materializzazione della String. Non si
applica un limite ai byte né alla lunghezza della sequenza prima del trim.
I classificatori email e URL conservano le condizioni precedenti, comprese
local part con punteggiatura o emoji; non viene introdotta un'euristica che
richieda un carattere alfanumerico iniziale.

## Cancellazione e limiti della preparazione

Per input non vuoti, il candidato controlla la cancellazione prima della
preparazione dei cluster e durante i cicli di costruzione, ricerca del confine
e trim, con checkpoint ogni 4.096 posizioni attraversate. Il comportamento
precedente per input vuoto già cancellato è conservato. I checkpoint già
presenti nel ciclo principale restano attivi.

`text.count`, usato dalla prenotazione di capacità preesistente, può ancora
scorrere la stringa prima dei checkpoint del ciclo di costruzione. Questi
checkpoint non dimostrano una latenza globale di cancellazione entro 4.096
caratteri per qualsiasi input o per tutte le fasi del tokenizer.

## Protocollo di equivalenza e misura

`pipelineOptimizationTokenizer` esegue un confronto completo con una copia
privata del tokenizer precedente, conservata nel file dei test e identificata
dal digest sopra. Questo riferimento verifica l'equivalenza dell'implementazione;
non è un oracolo linguistico indipendente e non sostituisce il gold italiano.

Senza `GLIFI_PIPELINE_BENCHMARK_DIRECTORY`, l'entry esegue una regressione piccola
su 64 punti e virgola e prosa Unicode con forme speciali. Quando la variabile è
impostata, prepara cinque workload deterministici, calcola il risultato legacy
e verifica il risultato produttivo prima di invocare l'helper di misura.

L'helper esegue un warm-up esplicito e sette campioni grezzi. Ogni risultato
viene confrontato integralmente e tramite SHA-256 dopo l'arresto del cronometro.
Il fingerprint codificabile comprende contratto, lingua, locale, lunghezza UTF-8,
token con classe/intervalli/componenti e frasi. Non viene aggiunta una conformità
di produzione al solo scopo di misurare.

La misura comprende l'intera `tokenize`, inclusa la preparazione dei cluster,
e usa un processo caldo senza svuotamento delle cache. Costruzione della fixture,
preparazione del riferimento, confronti, hashing e codifica del report sono
fuori dal tratto cronometrato. Le entry del lotto sono eseguite separatamente
dal coordinatore.

## Confronto Release osservato

Ambiente registrato: Mac16,3, 10 processori logici, 16 GiB di RAM, macOS 27.2.1
(`26B131`), Xcode 27.2 (`27B52`), Apple Swift 6.4.2
(`swiftlang-6.4.2.1.9`). Il target Swift riportato è
`arm64-apple-macosx27.2.0`. Stato termico nominale e Low Power Mode attivo
all'inizio e alla fine di ciascuno dei cinque workload.

| Workload | Mediana baseline, ms; minimo–massimo | Mediana candidato, ms; minimo–massimo | Rapporto fra mediane |
| --- | --- | --- | --- |
| 1.000 punti e virgola senza spazi | 12,497083; 12,479917–12,540667 | 0,653250; 0,642667–0,720750 | 19,131× |
| 4.000 punti e virgola senza spazi | 191,901625; 191,581542–193,235333 | 2,610791; 2,576791–2,809125 | 73,503× |
| 8.000 punti e virgola senza spazi | 764,499292; 763,124667–773,829459 | 5,236375; 5,050875–5,312875 | 145,998× |
| Prosa italiana Unicode, 128 ripetizioni | 3,232625; 3,226208–3,248292 | 3,157250; 3,128041–3,178917 | 1,024×, osservazione locale |
| Controllo email/URL legacy, 128 ripetizioni | 1,420500; 1,414208–1,424166 | 1,409792; 1,401292–1,418083 | 1,008×, osservazione locale |

La riduzione osservata per 8.000 punti e virgola è 99,315% sul tempo della sola
tokenizzazione dichiarata. La crescita fra 4.000 e 8.000 elementi è circa 3,98×
nella baseline e 2,01× nel candidato: osservazione coerente con l'eliminazione
delle scansioni ripetute, senza dedurre una soglia di latenza per qualunque testo.
I piccoli margini dei due controlli non costituiscono una dimostrazione di
significatività statistica o un'accelerazione generalizzabile della prosa.

Su entrambi i lati, l'helper verifica 8/8 risultati identici per ciascuno dei
cinque workload. Digest di fixture e fingerprint completo coincidono. Gli
[allegati baseline](allegati/GS-VER-202-204-baseline.json),
[candidato](allegati/GS-VER-202-204-candidate.json) e
[confronto](allegati/GS-VER-202-204-confronto.json) conservano campioni grezzi,
digest, ambiente e perimetro. I relativi SHA-256 sono:

| Allegato | SHA-256 |
| --- | --- |
| Baseline | `2fa078c64e09761f5f3f5878d80e4f3fc1a7d40e9aea3ef55baad949753d07b8` |
| Candidato | `eefcf18e055aba5791dc553f82bf9894accb56502d97aaaded7c1f69dd4922c3` |
| Confronto | `83bcf5dcdc80f351895f8bcbef4aa5b933ac9f43b8e3ebdef11e11f3ba5574c5` |

L'inventario congelato cambia soltanto i tre sorgenti produttivi dei rispettivi
incrementi del lotto; il tokenizer è l'unico dei tre usato da questi workload.
I dati delle altre famiglie non sono attribuiti a GS-VER-203.

I cinque JSON per lato sono stati prodotti sotto
`/tmp/GlifiStudioPipeline202-cache/baseline/` e `candidate/`, con identificatori
`tokenizer-punctuation-1000`, `tokenizer-punctuation-4000`,
`tokenizer-punctuation-8000`, `tokenizer-unicode-prose-control` e
`tokenizer-email-url-control`. L'entry risulta superata in entrambe le esecuzioni;
i rispettivi log `Tokenizer.log` riportano un test completato senza errori.
Il massimo RSS dell'intera invocazione `swift test` misurata con `time -l` è
73.564.160 byte per entrambi i lati; il footprint
di picco riportato è 24.838.960 byte nella baseline e 25.117.512 nel candidato.
Queste misure comprendono SwiftPM, harness, fixture, riferimento e tutti i
cinque workload: non misurano l'allocazione per token o l'allocazione isolata
del tokenizer e non dimostrano un risparmio di memoria o di energia.
Il [riepilogo dei processi](allegati/GS-VER-202-204-processi.json) e i log
[baseline](allegati/GS-VER-202-204-baseline-processi.txt) e
[candidato](allegati/GS-VER-202-204-candidate-processi.txt) conservano questi
risultati separati dai tempi del tratto cronometrato.

Il [record dell'archivio sorgenti](allegati/GS-VER-202-204-archivio-sorgenti.json)
identifica `verified-benchmark-source.tar.gz`, 664.425 byte, SHA-256
`3ef945ed177466487e25ddd997e48ca027b175285f677de53919a15fdf628a15`,
conservato in
`~/Library/Caches/GlifiStudio/evidence/pipeline-202-204-2026-11-21/`.
Contiene i 271 file congelati Package/Fixtures, i tre sorgenti produttivi
precedenti, i due inventari e l'ulteriore regressione CSV finale; non contiene
cache di compilazione. I report e l'archivio costituiscono l'evidenza da
conservare anche dopo la rimozione della copia temporanea di lavoro.

## Regressioni e revisione

Sono superati i test di confronto completo sui limiti 320/321 e 2.048/2.049,
Unicode composto/decomposto, whitespace Unicode, punteggiatura intermedia e
finale, sequenze interamente costituite da delimitatori, email con local part
particolari e URL con emoji. Un generatore a seed `0x2035EED1` produce 256 casi;
un ulteriore test confronta la cancellazione già richiesta con il riferimento.
Il filtro Release mirato del lotto ha completato 12 test senza errori, exit 0,
in 0,129 secondi; comprende questi confronti, i 256 casi a seed fisso, la
cancellazione e l'entry con riferimento legacy. Questo esito non costituisce
un nuovo gold linguistico indipendente. Il
[log dei test mirati](allegati/GS-VER-202-204-test-mirati.txt) conserva l'esito.

Formatter strict e controllo whitespace dei file modificati sono superati.
La revisione indipendente dell'agente Core non segnala problemi concreti in
riuso dei confini, trim, limiti in Character o preservazione del caso vuoto;
registra il limite preesistente di `text.count` indicato sopra.

## Stato della verifica

Il confronto A/B, le sue verifiche complete di risultato e la suite di
regressione Release mirata sono superati. L'esecuzione integrata `make verify`
del 2026-11-21 è terminata con exit 0: 380 test Core, 52 Kit, 153 righe di
oracoli riprodotte, 51 controlli CLI su 15 fixture, 22 checkpoint di recupero
con interruzione del processo e due PDF/A-2u validati. Sono completate le build
Debug e Release macOS e iPadOS. Il
[riepilogo del gate](allegati/GS-VER-202-204-gate.json) e il
[log integrale conservato](allegati/GS-VER-202-204-gate.txt) ne registrano il
perimetro e i digest dei tre sorgenti produttivi, invariati rispetto al
candidato misurato.

I [risultati nativi macOS](allegati/GS-VER-202-204-test-macos.json) riportano
46 test distinti superati, zero failure e 108 esecuzioni complessive,
senza runtime warning. I warning del log riguardano il CoreSimulator locale
meno recente di quello richiesto da Xcode e la dichiarazione iPadOS di
apertura dei documenti in place. Non attestano esecuzione sul runtime
simulatore: non sono stati eseguiti test runtime iPadOS. Questo lotto non
introduce né attesta un nuovo packaging di distribuzione.

Il controllo aggiuntivo Core/Kit successivo alle modifiche concomitanti
dell'altra sessione ai pesi dei termini e ai relativi test è terminato con
exit 0: 381 test Core e 52 Kit superati, con 205 file inventariati invariati
durante la corsa. Il [record del ripasso](allegati/GS-VER-202-204-ripasso-core-kit.json)
e il [relativo log](allegati/GS-VER-202-204-ripasso-core-kit.txt) conservano
l'esito separato dal gate precedente. Le modifiche ai pesi dei termini non
sono attribuite a questa ottimizzazione; i tre sorgenti del lotto restano
invariati.

Nessuna misura di energia, latenza UI, comportamento sotto pressione reale o
soglia prestazionale di rilascio deriva da questi workload. Gold linguistico,
validazione empirica, VoiceOver, dispositivi e G4 mantengono i propri gate.
Rollback tramite revert puntuale, senza migrazione.


## Pulizia finale

Rimossa la sola cache di lavoro del coordinatore dopo la chiusura delle prove:
**3.443.576 KiB, circa 3,28 GiB allocati** prima della rimozione. Il
[record di pulizia](allegati/GS-VER-202-204-pulizia.json) conferma l'assenza del
percorso e distingue la dimensione allocata dal delta di spazio libero APFS.
Allegati, log sanificati, inventari e archivio sorgenti verificato restano
conservati; toolchain, dipendenze e cache delle altre sessioni sono preservate.
