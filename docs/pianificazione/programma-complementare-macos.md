<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Programma complementare al completamento macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-PLAN-180 |
| Tipo | Programma operativo di sviluppo complementare |
| Versione | 1.4.0 |
| Stato | Cinque lotti realizzati e verificati nei confini dichiarati |
| Responsabile | Iniziatore del progetto; coordinamento operativo dell'agente principale |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta dell'iniziatore di individuare attività complementari all'altra chat e impiegare tutti gli agenti disponibili |
| Riferimenti | GS-STD-001-07; GS-DOR-180; GS-DOR-181; GS-DOR-182; GS-DOR-183; GS-VER-184; GS-DEV-002; GS-QRY-001 |

## Scopo e confini

Impiegare i quattro agenti disponibili su un lotto delimitato, con ownership dei
file esplicita e verifiche automatiche. Il programma affianca il completamento
macOS dell'altra chat, il cui lavoro è stato consultato prima della selezione.
I cinque lotti sono **realizzati e verificati nei confini dichiarati**. La verifica
globale `make verify` è superata anche dopo l'ottimizzazione; il preflight macOS
su snapshot identico appartiene alla chiusura dei primi due lotti.
Il programma non assegna durate prive di misurazione.

La richiesta successiva di realizzare il programma attiva il secondo lotto:
runtime, manifest candidato e riconciliazione documentale. Le sue implementazioni
non sono dichiarate verificate prima dei rispettivi test.

Restano riservati all'altra chat:

- ciclo documentale macOS, importazione parziale, cancellazione e riapertura;
- profili dei gate, packaging, cache e relativi comandi;
- presentazione dell'analisi testuale e del riassunto estrattivo nelle app.

Non vengono avviati sviluppo dedicato iPadOS, audit GUI, sessioni manuali con
VoiceOver, studi UX o misure Instruments. Le verifiche automatiche condivise
restano applicabili; nessuna attività del programma chiude G4 o promuove un
criterio ancora «Da introdurre».

## Lotto corrente

Le schede di ingresso sono registrate prima dei cambiamenti implementativi:

| Unità | Risultato atteso | Verifica e limite |
| --- | --- | --- |
| [GS-DOR-180 — Feedback statico delle failure](dor-controlli-statici-failure.md) | Eseguire nel loop `quality-static` i controlli esistenti di tassonomia e messaggi delle failure | Controlli positivi e negativi su copie temporanee indipendenti; nessuna nuova regola, modifica al prodotto o al gate globale |
| [GS-DOR-181 — Profondità dell'AST delle query testuali](dor-profondita-query-testuale.md) | Restituire dal parser soltanto AST entro il limite normativo di profondità | Regressioni al limite e oltre, operatori combinati e confronto con il decoder AST; nessuna nuova grammatica o capacità analitica |

## Distribuzione sui quattro agenti

| Agente | Responsabilità | Ownership e consegna |
| --- | --- | --- |
| Principale | Verificare i confini rispetto all'altra chat, registrare DoR e conformità iniziale, integrare evidenze e avviare la verifica finale | Matrice di conformità, registri comuni, tracciabilità e CHANGELOG hanno un solo integratore; gli altri agenti consegnano risultati e limiti senza modificarli |
| Core | Implementare GS-DOR-181 e verificare il contratto del parser | Solo parser delle query e test pertinenti; nessuna modifica a UI, servizi, persistenza o script di build |
| Verifica | Implementare GS-DOR-180 e provarne i controlli negativi | `Scripts/quality-static.sh` e allineamento puntuale di GS-DEV-002, preservando gli aggiornamenti dell'altra chat; nessuna modifica a verify, Makefile, cache o cataloghi |
| Pianificazione e revisione | Registrare il programma e svolgere una revisione indipendente del lotto | Solo questo documento per la scrittura; revisione in sola lettura delle implementazioni e segnalazione di problemi concreti all'integratore |

Gli agenti Core e Verifica possono lavorare in parallelo dopo le rispettive DoR.
La revisione indipendente procede sui diff disponibili. Le modifiche ai registri
comuni sono integrate dall'agente principale dopo la raccolta dei risultati e
la rilettura della versione corrente. Gli inserimenti sono puntuali, senza
riscritture globali, e preservano gli aggiornamenti dell'altra chat. La lettura
dell'altra chat non implica comunicazione diretta né disponibilità esclusiva
dei registri condivisi.

## Dipendenze e verifica

1. Confermare ownership e DoR; mantenere fuori dal lotto i file e le attività
   riservati all'altra chat.
2. Eseguire i controlli più mirati per ciascuna unità. Le prove negative del loop
   statico usano copie temporanee senza hardlink e non alterano i sorgenti attivi.
3. Serializzare build, packaging e gate che condividono directory di lavoro o
   cache. Un test Swift eseguito in parallelo usa una cache distinta e dichiarata;
   non si svuota né si modifica la cache dell'altra chat.
4. Riesaminare i risultati, integrare evidenze e tracciabilità con stato coerente
   con le esecuzioni osservate, quindi eseguire `make verify` sulla composizione
   finale. Un eventuale profilo macOS è identificato separatamente e non equivale
   alla verifica globale.
5. Rimuovere copie temporanee e artefatti rigenerabili non più necessari,
   conservando deliverable, evidenze utili e cache ancora utilizzate.

Se toolchain, runtime o un altro prerequisito impediscono un controllo, registrare
il comando, il prerequisito mancante e la copertura residua. Non abbassare target,
limiti o controlli e non sostituire un controllo non eseguito con una dichiarazione
di successo.

## Criterio di completamento e stop

### Avanzamento osservato il 2026-11-21

- [GS-VER-180](../evidenze/GS-VER-180-feedback-statico-failure.md): loop statico
  superato sullo snapshot e due regressioni sintetiche intercettate; entrambe
  passavano con il loop precedente.
- [GS-VER-181](../evidenze/GS-VER-181-profondita-query-testuale.md): regressione
  riprodotta sul parser precedente; 20 test Core e 1 di parità Kit superati,
  inclusi 3.000 input fuzz query. Revisione indipendente senza problemi concreti
  irrisolti nel lotto.
- `make verify` globale tentato sulla composizione: arresto nel controllo
  documentale per due DoR concomitanti con ID `GS-DOR-168` e marker mancanti nel
  DoR degli algoritmi. Test integrati, oracoli e build di questa esecuzione non
  sono stati raggiunti. La verifica globale va ripetuta dopo la stabilizzazione
  di quei documenti; le evidenze mirate non la sostituiscono.
- Il successivo controllo documentale del primo lotto non segnalava più la
  collisione di ID, ma restavano due marker nel DoR degli algoritmi, poi risolti
  dalla ricognizione GS-VER-184 del secondo lotto. Compliance, tassonomia,
  messaggi delle failure, formattazione dei due file Swift e `git diff --check`
  superati sulla composizione aggiornata. Copie e build temporanee del lotto
  rimosse; circa 459 MiB di scratch Swift misurati prima della pulizia.

### Uscita del lotto

Il lotto termina quando entrambe le unità rispettano i contratti delle DoR, le
regressioni e i controlli negativi sono documentati, la revisione indipendente non
lascia problemi concreti irrisolti e la verifica finale è registrata con i suoi
limiti effettivi. Un controllo non eseguibile mantiene aperta la relativa verifica.

Un conflitto di ownership o una modifica che richieda nuove API, formati,
dipendenze, privilegi o comportamenti fuori DoR arresta soltanto la parte
dipendente: il coordinatore risolve il confine prima di proseguire. Il lotto non
si estende automaticamente a GUI, G4, distribuzione o candidati successivi.

## Secondo lotto — Realizzazione del programma

Le schede Ready del runtime e del manifest candidato precedono il coding. La
riconciliazione documentale applica soltanto evidenze già esistenti e corregge
stati obsoleti, senza modificare requisiti o criteri di accettazione.

| Unità | Risultato e ownership | Dipendenza e limite |
| --- | --- | --- |
| [GS-DOR-182 — Runtime macOS](dor-runtime-eventi-macos.md) | Agente Core: DTO/provider Kit, admission delle sessioni, confini fra nodi e monitor AppKit; coordinatore: iniezione App/View e progetto Xcode | Snapshot O(1), nessun polling, callback e source owned; memoria iniziale conservativa dichiarata; test automatici distinti da Instruments e G4 |
| [GS-DOR-183 — Manifest candidato](dor-manifest-candidato.md) | Agente Verifica: helper comune ai quattro commit e prove avverse deterministiche | Lettura bounded dal descriptor e confronto con byte attesi prima del publish; replacement URL, cleanup e SQLite restano residui, CMP-095 blocked |
| [GS-VER-184 — Riconciliazione documentale](../evidenze/GS-VER-184-riconciliazione-documentale.md) | Agente Documentazione: roadmap e scheda di prosecuzione algoritmi; coordinatore: stati nei registri | Sole evidenze storiche stabili; nessuna promozione degli algoritmi o della UI attualmente in lavorazione nell'altra chat |

Il quarto ruolo è il coordinatore, che integra, misura i controlli pertinenti ed
esegue il gate finale. Completata la documentazione, il relativo agente svolge
revisione indipendente di runtime e persistenza. Le build usano cache isolate e
sono serializzate; le patch sui file condivisi sono puntuali dopo rilettura.
Una nuova capacità o un residuo fuori da queste schede richiede un'altra unità
delimitata: «realizzare il programma» non equivale a dichiarare chiusi G4, ogni
residuo di CMP-095 o le attività riservate all'altra chat.

## Chiusura dei due lotti

Realizzati runtime event-driven, verifica bounded del manifest e riconciliazione
documentale, con schede Ready, regressioni prima/dopo e revisione indipendente.
Il runtime aggiunge anche la regressione della cancellazione durante la lettura
della fonte: failure tipizzata, stato conservato e ripresa riuscita.

`make verify` finale è superato: 399 test Core/Kit, 36 macOS, 152 riscontri degli
oracoli, 51 controlli CLI, 22 checkpoint recovery, due PDF/A-2u e build
Debug/Release macOS/iPadOS. È superato anche il preflight macOS sull'identico
snapshot prodotto/build confrontato, senza duplicare l'archiviazione.
Lo snapshot ha costo O(1), senza actor-hop o polling; la misura informativa
Release registra mediana 5,747125 ns per lettura sul Mac osservato, senza
introdurre soglie o promesse di prestazioni applicative.

GS-VER-182/183/184 documentano risultati e limiti. CMP-182 e CMP-183 sono
verified nei rispettivi confini; CMP-095, Instruments, dispositivi e G4 restano
distinti. Lavori dell'altra chat e promozione scientifica non sono assorbiti
dalla chiusura di questo programma.

Pulizia conclusa sui soli artefatti del lotto: circa 3,33 GiB misurati prima
della rimozione, conservando sorgenti, evidenze compatte e toolchain. Lo snapshot
e le cache dell'altra attività rimangono sotto la responsabilità del loro owner.

## Terzo lotto — Ottimizzazione misurata

La richiesta di iterare attiva due ottimizzazioni candidate, con baseline
Release prima della patch produttiva. Non vengono ottimizzati gli snapshot da
pochi nanosecondi né introdotti acceleratori o cache di fiducia.

| Unità | Responsabilità | Criterio di conservazione |
| --- | --- | --- |
| [GS-DOR-200](dor-ottimizzazione-letture-verificate.md) | Agente Core: letture source/recovery/Artifact a passata unica con tutte le verifiche esistenti | Byte e failure invariati, test avversari e miglioramento misurato su workload sintetico |
| [GS-DOR-201](dor-ottimizzazione-termine-query.md) | Agente Query: normalizzazione costante fuori dal predicato per token | Identici digest/match/intervalli e beneficio misurato su scansione Unicode |
| Misure | Agente Benchmark: nuovo modo dedicato nell'harness headless, baseline/candidato, almeno sette campioni e checksum | Stesso codice di misura e generatore; stato del sistema e cache dichiarati, nessuna soglia vincolante nuova |
| Integrazione | Coordinatore: registri, interpretazione delle misure, gate e pulizia | Revisione incrociata indipendente e make verify sulla composizione finale |

Gli agenti di prodotto scrivono inizialmente soltanto test; la modifica
produttiva attende l'acquisizione della baseline. Le due patch hanno ownership
distinta. Le build condividono una cache dedicata solo in sequenza, rimossa alla
consegna. I risultati riportano il costo delle API misurate, senza attribuirlo
automaticamente alla latenza complessiva dell'applicazione.

### Chiusura del terzo lotto

La baseline precede le modifiche produttive. Le letture source/recovery/Artifact
restituiscono ora i byte verificati dalla stessa passata, conservando controlli
di riferimento, percorso, tipo, link, dimensione e digest. La query normalizza
una sola volta il termine costante; candidati, digest, match e KWIC restano
invariati. Le revisioni incrociate non lasciano problemi concreti irrisolti.

Su snapshot immutabile Release, stesso harness e fixture, sette campioni oltre
al warmup: le nove letture da 1/8/32 MiB riducono la mediana del 47,3–49,7%;
la fonte da 32 MiB passa da 57,140 a 29,193 ms. La scansione preparata di
100.000 token Unicode passa da 187,203 a 88,112 ms (−52,9%). I risultati sono
identici in tutti i campioni. Sono misure dei workload dichiarati, con cache
del sistema calda e modalità risparmio energetico attiva; non misurano latenza
della UI, energia o accessi fisici al disco.

`make verify` completo è superato: 411 test Core/Kit, 36 test macOS distinti
(45 esecuzioni riportate dal runner), 152 riscontri degli oracoli, 51 controlli
CLI su 15 fixture, 22 checkpoint recovery, due PDF/A-2u e build Debug/Release
macOS/iPadOS. Il simulatore non è eseguibile con il CoreSimulator installato;
le build iPadOS non costituiscono test su dispositivo o simulatore.

[GS-VER-200](../evidenze/GS-VER-200-letture-verificate-passata-unica.md) e
[GS-VER-201](../evidenze/GS-VER-201-normalizzazione-query.md) conservano campioni,
checksum, tracciabilità e limiti. CMP-200 e CMP-201 sono verified nel rispettivo
perimetro; CMP-095, G4 e gli audit assistivi rimangono distinti.

Rimossa la sola cache temporanea del terzo lotto, con **2,80 GiB allocati**
misurati prima della rimozione. Restano allegati, log sanificati, riepiloghi dei
test e archivio compatto dei sorgenti congelati; toolchain, dipendenze e cache
delle altre chat sono conservate. Il [record di pulizia](../evidenze/allegati/GS-VER-200-201-pulizia.json)
delimita la misura al percorso, senza attribuirla al delta di spazio libero APFS.

## Quarto lotto — Costi di scala della pipeline

La richiesta di ottimizzare ancora estende la ricognizione a importazione,
coordinate e proiezione dei risultati. Le schede Ready GS-DOR-202/203/204 e le
righe iniziali di conformità precedono il coding; baseline e candidato usano
una copia immutabile di Package/Fixtures e lo stesso harness Release.

I quattro agenti coprono SpanMap, tokenizer, CSV e coordinamento/misure.
Nessuna scrittura sui kernel statistici ottimizzati contemporaneamente
nell'altra chat; nessun cambio a UI, gate, backend o formati persistenti.
Il coordinatore integra i registri e serializza build, misure e verifica finale.

### Chiusura del quarto lotto

Tre sorgenti produttivi modificati su 271 file congelati; stessa fixture,
stesso harness, un warmup e sette campioni per scenario. Tutti i risultati
completi e i checksum coincidono. Host e condizioni sono registrati negli
[allegati di confronto](../evidenze/allegati/GS-VER-202-204-confronto.json).

| Workload Release locale | Mediana prima | Mediana dopo | Riscontro |
| --- | ---: | ---: | --- |
| 1.000 lookup su 20.000 segmenti SpanMap | 19,738 ms | 0,417 ms | 47,31× |
| Composizione 5.000 × 5.000 segmenti | 20,565 ms | 1,066 ms | 19,29× |
| Tokenizer, 8.000 punti e virgola senza spazi | 764,499 ms | 5,236 ms | 146,00× |
| CSV, 2.048 Finding/Evidence con quattro riferimenti | 385,538 ms | 234,297 ms | −39,23% |

Anche costruzione della mappa, taglie inferiori e controlli Unicode/email/URL
sono misurati. I margini piccoli dei controlli sono osservazioni locali, senza
prova di significatività statistica. Il lookup conserva il percorso lineare
per mappe legacy non ordinate; i token mantengono superficie, componenti e frasi;
il CSV mantiene byte, ordine e protezione formule. L'indice CSV usa memoria
locale proporzionale ai riferimenti distinti. Il picco RSS dell'intera invocazione
CSV cresce di circa 5,05 MiB: include runner, fixture e riferimenti e non è
attribuibile al solo indice. Nessuna riduzione universale della memoria è promessa.

Il [gate completo](../evidenze/allegati/GS-VER-202-204-gate.json) termina con
exit 0: 380 test Core, 52 Kit, 46 test macOS distinti (108 esecuzioni), 153 righe
di oracoli, 51 controlli CLI su 15 fixture, 22 checkpoint recovery, due PDF/A-2u
e build Debug/Release macOS/iPadOS. Il [ripasso Core/Kit](../evidenze/allegati/GS-VER-202-204-ripasso-core-kit.json)
sui pesi aggiornati contemporaneamente nell'altra sessione supera 381 test Core
e 52 Kit, con 205 file sorgente/test invariati durante la corsa. Le tre patch
misurate restano identiche. Il limite CoreSimulator e l'avviso in-place iPadOS
sono registrati; non sono attestati test runtime iPadOS o un nuovo packaging.

[GS-VER-202](../evidenze/GS-VER-202-spanmap-indicizzata.md),
[GS-VER-203](../evidenze/GS-VER-203-token-speciali.md) e
[GS-VER-204](../evidenze/GS-VER-204-indice-export-csv.md) chiudono il lotto e
CMP-202/203/204 nel proprio perimetro. G4, misure energetiche e audit assistivi
restano nelle rispettive attività. L'archivio sorgenti compatto, verificato
contro gli inventari, permette di riprodurre baseline e candidato senza
conservare le cache di compilazione.


La pulizia del quarto lotto è completata: **3,28 GiB allocati** nel solo
percorso temporaneo prima della rimozione, senza attribuire la misura allo
spazio libero del volume APFS. Il [record](../evidenze/allegati/GS-VER-202-204-pulizia.json)
conferma gli artefatti rimossi e le evidenze conservate. Nessuna cache delle
altre chat o dipendenza attiva è stata eliminata.

## Quinto lotto — Pianificazione e proiezioni di dominio

GS-DOR-205/206/207/208 sono Ready prima del coding. I quattro agenti coprono
coda DAG, proiezione CA, digest e coordinamento/supporto dei test. I kernel
statistici e il completamento UI restano nelle altre sessioni; i relativi
worktree e cambiamenti sono preservati.

Baseline, fase strutture (DAG/CA) e candidato completo condividono fixture e
harness congelati. La fase intermedia separa l'effetto delle strutture dal
costo digest usato anche dal costruttore del grafo. Build e misure sono seriali.
Il nuovo target di supporto è raggiunto soltanto dai test e non crea un
prodotto SwiftPM o un requisito runtime delle app.

### Risultati misurati del quinto lotto

Baseline e fase strutture hanno 279 file congelati; il candidato ne aggiunge
uno e modifica soltanto Graph, Identifiers e proiezione Kit. Le tre fasi
conservano fixture, generatori, harness, output completi e checksum identici.

| Workload Release locale | Baseline | Strutture | Completo |
| --- | ---: | ---: | ---: |
| DAG a stella, 5.000 nodi | 2.673,178 ms | 349,011 ms | 134,488 ms |
| Proiezione CA, 8.192 × 2.000 | 25,474 ms | 0,302 ms | 0,273 ms |
| 50.000 identificatori da digest | 388,873 ms | Non modificato | 10,805 ms |
| 1.000 descrittori piccoli | 117,039 ms | Non modificato | 40,466 ms |

Il DAG misura 7,66× per il blocco strutturale e 19,88× complessivi; i contributi
restano separati. Il Kit è byte-identico fra fase strutture e completa: le
variazioni di tempo non sono attribuite ai digest. Il caso CA minuscolo passa
da 1,458 a 2,250 microsecondi (+0,792 microsecondi), costo locale dei Set; nessun
miglioramento universale è dichiarato. Set e heap mantengono memoria effimera
esplicita; gli RSS dell'intera invocazione non misurano l'allocazione per API.

I [risultati grezzi e il confronto](../evidenze/allegati/GS-VER-205-207-confronto.json)
conservano tutti i sette campioni per scenario, intervalli, hash e attribuzione.
L'[archivio verificato dei sorgenti](../evidenze/allegati/GS-VER-205-208-archivio-sorgenti.json)
permette di riprodurre tutte le fasi senza conservare le cache di compilazione.
Il gate integrato e il controllo negativo della guard Debug sono superati.

### Chiusura del quinto lotto

`make verify` completo termina con exit 0: 391 test Core e 59 Kit, 55 test macOS
distinti (195 esecuzioni), 153 righe di oracoli, 51 controlli CLI su 15 fixture,
22 checkpoint recovery, due PDF/A-2u e build Debug/Release macOS/iPadOS.
I 376 ingressi runtime e di verifica sono invariati durante la corsa; le quattro
fonti del candidato restano identiche a quelle misurate. Il [record del gate](../evidenze/allegati/GS-VER-205-208-gate.json)
e il [riepilogo nativo](../evidenze/allegati/GS-VER-205-208-test-macos.json)
conservano esiti, hash e conteggi.

Il [controllo negativo Debug](../evidenze/allegati/GS-VER-208-guard-debug.json)
registra il rifiuto atteso con exit 1 e nessun report di misura scritto,
separatamente dalla suite positiva. Il protocollo condiviso mantiene il corpo
del helper precedente e raggiunge soltanto i due target di test; i cinque
prodotti SwiftPM restano invariati.

GS-VER-205/206/207/208 e CMP-205/206/207/208 sono chiuse nel proprio perimetro.
Le build generiche iPadOS non attestano prove runtime; restano documentati
CoreSimulator precedente al requisito Xcode, avviso in-place e destinazioni
con metadati incompleti. Nessuna nuova attestazione di packaging, audit GUI,
energia o G4 deriva dal lotto.


Pulizia del quinto lotto completata: **3,13 GiB allocati** nel solo percorso
temporaneo prima della rimozione. Il [record](../evidenze/allegati/GS-VER-205-208-pulizia.json)
conserva misura e delimitazione; nessuna attribuzione al delta libero APFS,
nessuna dipendenza attiva o cache delle altre chat rimossa. Le prove compatte
restano disponibili insieme all'archivio dei sorgenti.
