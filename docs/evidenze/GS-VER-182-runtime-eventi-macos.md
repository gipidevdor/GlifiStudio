<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-182 — Runtime macOS guidato dagli eventi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-182 |
| Tipo | Evidenza di admission, segnali di sistema e confini di esecuzione |
| Versione | 1.0.0 |
| Stato | Superato nativamente nel perimetro automatico dichiarato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Attuazione GS-DOR-182 nel perimetro automatico dichiarato |
| Riferimenti | GS-DOR-182; CMP-182; GS-APL-015; ADR-0018; RQ-052; RQ-053; RQ-054; RQ-063; TV-065; TV-066; TV-067 |

## Ambito e contratto

Sulla base `a86a53b` con il working tree corrente, l'app macOS riceve un
`StudioMacRuntimeMonitor` posseduto dall'oggetto App. Il monitor pubblica un
`GlifiStudioRuntimeEnvironment`, iniettato nel servizio di ciascuna finestra e
nelle sue sessioni. AppKit rimane nel target macOS; GlifiKit espone DTO
`Sendable` e GlifiCore conserva la policy pura di ADR-0018.

Lo snapshot contiene quattro segnali: Low Power Mode, condizione termica,
pressione memoria e attività dell'app. La lettura termica precede la
registrazione delle notifiche. La pressione iniziale è **warning non osservato**,
conservativo, fino a un evento del sistema: non è dichiarata una misura iniziale
nominale. Le notifiche di energia, termica e attività e la sorgente Dispatch
normal/warning/critical sostituiscono il polling. Una termica futura sconosciuta
diventa serious; un evento memoria non riconosciuto diventa warning.

`GlifiStudioSystemConditionsStore` protegge lo snapshot fisso con `Mutex`.
Aggiornamenti di energia/attività e memoria avvengono separatamente sotto la
stessa lock e preservano l'altro segnale: non esiste un read-modify-write
esterno capace di perdere una pressione critica concorrente. Snapshot e
aggiornamento hanno costo O(1), senza coda di eventi o actor-hop per nodo.
Non sono introdotti timer, task permanenti, attività di processo o assertion
che impediscano App Nap o idle system sleep.

Il monitor possiede observer e sorgente, rende start/stop idempotenti e usa
una revisione dell'osservazione per ignorare callback dopo stop o provenienti
da una registrazione precedente. Stop/deinit cancella gli observer e la
sorgente e marca l'environment critical/inattivo se un servizio gli sopravvive.
La cattura del monitor nei callback è debole.

## Admission e failure

Il servizio trasporta l'environment alle sessioni. Un helper comune applica
`GlifiRuntimePolicy` prima dell'importazione, delle query testuali/AST, della
lettura integrale delle fonti, della pianificazione, delle analisi dirette
(compreso il riassunto), degli export e della costruzione di visualizzazioni
che caricano payload analitici. Snapshot, chiusura, apertura/recupero e letture
leggere dei metadati restano disponibili sotto pressione critica.

L'admission negata usa `runtime.admission-denied`, categoria
`insufficientResources`, retry `afterConditionsChange` e argomento privo di
contenuto `operatingProfile`. Le sessioni conservano
`lastCommittedGeneration`; il profiling stateless usa `unchanged`. Anche una
task già cancellata produce la failure Kit tipizzata `operation.cancelled`,
con retry `newRequest`, senza I/O o `CancellationError` grezzi al confine Kit.

La task posseduta dalla sessione per il piano dichiara priorità
`userInitiated`; le altre chiamate asincrone mantengono l'ereditarietà
strutturata. Core rilegge il provider prima di pianificare, fra nodi e prima
della finalizzazione. Il provider è un valore `GlifiSystemConditionsProvider`,
distinto dalla closure asincrona di progresso, per preservare le chiamate
esistenti con trailing closure. Senza provider rimane valido lo snapshot
esplicito del chiamante. Il risultato mantiene il profilo selezionato
all'admission, come nel contratto precedente; gli step restano sequenziali.

Pressione critica interrompe l'admission della successiva unità sicura; un
nodo già committato resta parte di una generazione completa. Nessun risultato
parziale viene dichiarato completato. Non vengono cambiati parametri
scientifici, formato del progetto, precisione o cap di parallelismo.

## Verifiche osservate Core e Kit

Ambiente locale: macOS 27.2.1 (`26B131`), Xcode 27.2 (`27B52`),
Apple Swift 6.4.2 (`swiftlang-6.4.2.1.9`), Swift Testing 2403.
Comando finale:

```sh
swift test --package-path Packages/GlifiCore \
  --scratch-path /tmp/GlifiStudioComplementary182-cache/SwiftPM \
  --filter 'runtimePressure|runtimeEnvironment|analysisPlanExecution|serviceProjectSessionRoundTrip|serviceMapsFailures'
```

Esito finale: **exit 0, 10 test superati**, 6 Kit e 4 Core. Comprende sei
test nuovi e quattro regressioni esistenti di lifecycle, failure e piano.
Build incrementale 10,25 s; test Kit 0,111 s; test Core 0,554 s. Non sono
benchmark e non attestano prestazioni o energia su hardware di riferimento.

I nuovi test verificano:

- 1.000 aggiornamenti concorrenti per canale e 1.000 letture, senza perdita
  della pressione critica né snapshot misti dei segnali energia/attività;
- cancellazione tipizzata prima del profiling, senza leggere il file canary;
- pressione critica prima di import, query, lettura fonte, riassunto, plan,
  esecuzione e profiling, con failure e retainedState appropriati;
- snapshot e metadati leggeri disponibili, chiusura e riapertura valide, quindi
  query e lettura fonte nuovamente ammesse dopo ritorno nominale;
- Low Power Mode propagato fino al risultato di esecuzione, profilo constrained
  e parallelismo ammesso non superiore a due; caricamento Artifact e
  visualizzazioni rifiutati dopo indisponibilità dell'observer;
- pressione critica iniettata al primo progresso, prima di persistere il piano:
  snapshot e generazione rimangono invariati e il package si riapre;
- pressione critica dopo il primo nodo: soltanto piano e nodo concluso sono
  committati, incremento di due generazioni valide, package riapribile e
  completamento recuperato quando le condizioni tornano nominali.

La prima compilazione ha evidenziato l'ambiguità della closure opzionale del
provider rispetto alle trailing closure esistenti: il valore provider descritto
sopra risolve tale incompatibilità. Un successivo tentativo ha rilevato tre
intenti nella nuova fixture Kit scritti come enum anziché identificatori
String; la fixture finale usa `understand.collection`. Questi tentativi non
sono presentati come verifiche superate. Il comando finale sopra ha completato
build e test senza warning.

Formatter strict e `git diff --check` mirati sono stati eseguiti durante il
lavoro; il gate integrato rimane responsabilità del coordinatore dopo
l'integrazione di tutte le attività parallele.

## Verifica App e limiti aperti

`StudioMacRuntimeMonitorTests` aggiunge tre test con sorgente iniettata:
snapshot iniziale e segnali senza polling; start/stop/restart con callback
vecchi conservati dal fake; deinit senza ciclo di retain e snapshot conservativo
per un environment sopravvissuto. I risultati del coordinatore sono registrati
qui sotto; il gate completo resta distinto dai controlli mirati.

La rivalutazione dinamica riguarda i confini sicuri del piano. Le analisi
indivisibili applicano admission iniziale e cancellazione già presente;
non viene attestato un checkpoint o un controllo di pressione intra-nodo.
Il default headless esplicito mantiene la compatibilità dei client privi di
lifecycle AppKit, con memoria nominale e attività true; l'app macOS usa
l'environment osservato.

TV-066/TV-067 su hardware, Instruments, App Nap, energia, termica reale e
calibrazione di rilascio restano aperti. Nessuna attestazione G4, benchmark applicativo o energetico, recovery
power-loss, rete o trattamento di contenuto diagnostico.
Rollback mediante revert senza migrazione.

La cache dedicata `/tmp/GlifiStudioComplementary182-cache` e i log mirati
restano attivi per il riuso seriale di GS-VER-183 e del gate finale. Non sono
stati rimossi né modificati scratch o cache delle altre attività.

## Verifica del workspace dal coordinatore

`GLIFI_VERIFY_KEEP_CACHE=1 GLIFI_VERIFY_CACHE=<cache-dedicata> make test-macos`
ha eseguito lo schema `GlifiStudio-macOS` da `GlifiStudio.xcworkspace`. Il
riepilogo `xcresulttool get test-results summary` registra **29 test superati**,
33 esecuzioni incluse le parametrizzazioni, zero fallimenti e zero skip. I tre
test del monitor sono inclusi. La prima build ha intercettato `weak var` mai
mutata nel nuovo test: la correzione usa `weak let` previsto da Swift 6.4, senza
indebolire warnings-as-errors; il secondo tentativo è superato.

Xcode segnala CoreSimulator installato 1171.7.0 inferiore a 1174.21.0 e un warning
interno di diagnostica del test runner. I test nativi macOS sono terminati con
exit 0; ciò non attesta esecuzione di test su simulatore iPadOS. Nessun warning
del codice dell'incremento rimane nel risultato finale.

## Misura informativa Release dello snapshot

Probe headless temporaneo con dipendenza locale a GlifiKit, nessuna dipendenza
remota e compilazione Release con Swift 6.4.2. Il probe legge
`GlifiStudioRuntimeEnvironment(store:).snapshot()` e accumula un checksum
verificato: 10.000 letture di warm-up, sette campioni da 1.000.000 letture,
checksum finale 7.010.000. La fixture `explicit-nominal-active-no-content-v1`
contiene energia false, termica nominal, memoria nominal e attività true. Non
include I/O, corpus o notifiche artificiali.

Ambiente osservato: Mac16,3, arm64, 10 processori attivi, 16 GiB RAM, macOS
27.2.1 (26B131), Low Power Mode attivo, stato termico OS 0 (nominale). La fixture
è sintetica ed esplicita: non afferma che la pressione memoria reale sia nominale.

| Campione | Nanosecondi per snapshot |
| --- | --- |
| 1 | 6,040542 |
| 2 | 5,683334 |
| 3 | 6,105167 |
| 4 | 6,022292 |
| 5 | 5,747125 |
| 6 | 5,492208 |
| 7 | 5,646042 |

Mediana **5,747125 ns**, intervallo osservato **5,492208–6,105167 ns**. La build
Release del probe è durata 114,66 s e non fa parte della metrica. SHA-256 dello
store verificato: `7f00221921983e45837b65b0d837aa15d786eb139a26f877e020f9ce043df869`.
SHA-256 del sorgente del probe:
`f198ba41470ff5012f118277568dab284cfa3379debbe81546fbbfd531fe54c7`.

Per ripetere la misura, creare un eseguibile SwiftPM temporaneo con tools 6.4,
macOS 27 e dipendenza al package locale `Packages/GlifiCore`, importare Foundation
e GlifiKit, creare lo store della fixture e il relativo environment. Dopo il
warm-up, per ciascun campione cronometrare con `ContinuousClock` il seguente
corpo, senza stampare durante il ciclo:

```swift
let begin = ContinuousClock.now
for _ in 0..<1_000_000 {
    let snapshot = environment.snapshot()
    checksum += snapshot.isApplicationActive && snapshot.memoryPressure == .nominal ? 1 : 0
}
let elapsed = begin.duration(to: .now).components
let nanosecondsPerSnapshot =
    (Double(elapsed.seconds) * 1e9 + Double(elapsed.attoseconds) / 1e9) / 1_000_000
```

La misura riguarda soltanto lettura dello snapshot, lock, closure e checksum nel
probe headless: non è latenza app, energia, contesa, memoria residente, baseline
di rilascio o promessa per ogni Mac. Non introduce soglie vincolanti e non
giustifica acceleratori o ottimizzazioni numeriche. I test concorrenti separati
verificano l'atomicità dei canali, senza ricavare throughput da questa misura.

## Validazione PDF/A integrativa

La prima esecuzione globale non aveva `VERAPDF` selezionato e ha dichiarato
esplicitamente il controllo opzionale saltato. Il coordinatore ha poi usato il
launcher veraPDF 1.30.4 già presente nella cache di strumenti documentata da
GS-DEV-001, senza download o installazioni nuove, sui due PDF prodotti da quella
stessa esecuzione. Le copie congelate sono state validate con
`Scripts/check-pdfa.py --require --directory <output-congelato>`: **2 PDF
conformi PDF/A-2u**, exit 0. L'integrazione è distinta dal log del gate e non
riscrive retroattivamente il suo skip.

| File sintetico | SHA-256 |
| --- | --- |
| `report-long.pdf` | `8913abf56c9cebd92142fb06632911b66161344a0f146800483fd840145f4d7c` |
| `report.pdf` | `17b24cfc7d680ba3ce373048d17ec078d36585772d32d1543128c8c1933a337a` |


## Regressione integrativa: cancellazione durante la lettura della fonte

Un controllo mirato del confine modificato ha rilevato una seconda finestra di
cancellazione: dopo il controllo iniziale dell'admission ma prima della lettura
bounded della fonte. `GlifiStudioProjectSession.sourceText` chiama il package
direttamente; il suo lettore può sollevare `CancellationError`, che il mapper
comune della sessione classificava erroneamente come `internal.unexpected`,
`invariantViolation`, retry `never` e stato `validityUnknown`.

`runtimeEnvironmentPreservesCancellationDuringSourceRead` riproduce la finestra
senza timer o gare: dopo l'importazione sintetica, un provider iniettato cancella
la task una sola volta durante lo snapshot dell'admission e restituisce condizioni
nominali. Il controllo del lettore osserva la cancellazione. La regressione
richiede `operation.cancelled`, categoria `cancelled`, operazione `query`, retry
`newRequest`, stato `lastCommittedGeneration`, chiave localizzabile canonica e
argomenti vuoti. Verifica inoltre snapshot invariato e successiva lettura riuscita
in una task non cancellata.

La correzione riguarda soltanto `Self.map` della sessione: preserva una
`GlifiStudioFailure` già classificata, mantiene il mapping di `GlifiFailure` e
converte una `CancellationError` grezza nella failure di cancellazione canonica.
Il fallback degli altri errori resta invariato. Nessuna nuova API o modifica ai
segnali, al monitor App, al formato o ai parametri scientifici.

| Prova | Comando/filtro nello scratch SwiftPM attivo | Esito |
| --- | --- | --- |
| RED, mapper ancora invariato | `--filter runtimeEnvironmentPreservesCancellationDuringSourceRead` | Exit 1 atteso: 1 test fallito, 5 issue sulle classificazioni errate; build 2,57 s, test 0,036 s |
| GREEN, mapper corretto | `--filter 'runtimePressure\|runtimeEnvironment\|analysisPlanExecution\|serviceProjectSessionRoundTrip\|serviceMapsFailures'` | Exit 0: 7 test Kit e 4 Core superati, 11 totali; build 2,20 s, Kit 0,081 s, Core 0,249 s |
| Formattazione e whitespace | Formatter strict e `git diff --check` sui due file Swift modificati | Exit 0 |

Package e scratch sono quelli del comando mirato precedente. RED e GREEN hanno
usato gli stessi nuovi test, senza revert né copia del package; il solo mapper è
stato corretto fra le due esecuzioni. I log dedicati sono
`runtime-source-cancellation-red.log` e `runtime-source-cancellation-green.log`
nella cache attiva. Non sono stati eseguiti benchmark aggiuntivi; il coordinatore
ripete il gate integrato dopo questa correzione. Le sezioni precedenti su App,
misura Release e PDF/A conservano i propri ingressi e risultati dichiarati.

| Ingresso | SHA-256 |
| --- | --- |
| `GlifiStudioService.swift` nel RED | `4eada33d2959b8571d025ca7a745678cd975b57e335aa53f7b3d661e1615316f` |
| `GlifiStudioService.swift` nel GREEN | `7bc9c333dbb45d1724306e733f5f7dc97ab9201700e1de6e5b6ee174c0964551` |
| `GlifiStudioRuntimeEnvironmentTests.swift`, identico nel RED/GREEN | `011d0a461a1c949656e32e43659e25ce048a6740e7f3c88fc19a2798a0794525` |

## Riferimenti delle API native

Disponibilità verificata sulla toolchain Xcode 27.2 e sulle pagine Apple:

- [thermalStateDidChangeNotification](https://developer.apple.com/documentation/foundation/processinfo/thermalstatedidchangenotification): leggere la termica prima di registrare l'observer;
- [NSProcessInfoPowerStateDidChange](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/nsprocessinfopowerstatedidchange): rileggere lo stato di Low Power Mode dopo l'evento;
- [DispatchSource.MemoryPressureEvent](https://developer.apple.com/documentation/dispatch/dispatchsource/memorypressureevent): eventi di variazione normal/warning/critical.

L'avvio con memoria warning è una decisione conservativa dell'adattatore finché
non è arrivato un evento; non è una misura iniziale fornita da quelle API.

## Chiusura della verifica integrata

Il coordinatore ha eseguito `make verify` sul workspace condiviso, con cache
dedicata, Python 3.12.14 e `VERAPDF` selezionato sul validatore già installato.
L'esecuzione finale, successiva alla correzione della cancellazione durante
la lettura, termina con **exit 0**:

- **347 test Core e 52 test Kit**, inclusa la nuova regressione di cancellazione;
- **36 test macOS**, 45 esecuzioni con parametrizzazioni, zero fallimenti e skip;
- **152 righe di oracoli**, 51 controlli CLI sulle 15 fixture condivise e parità QueryAST;
- **22 checkpoint** di process-kill recovery e **due PDF conformi PDF/A-2u**;
- build Debug/Release macOS e iPadOS. Le build iPadOS sono regressione condivisa,
  non sviluppo dedicato né esecuzione di test su simulatore.

Il preflight macOS è stato osservato nell'altra attività sullo snapshot
immutabile: `Scripts/check-app-store-packaging.sh --macos-only`, exit 0, analisi
statica e archivio senza firma validi. Il confronto indipendente e poi quello
del coordinatore verificano **245 file prodotto/build più 36 file di strumenti,
Makefile e workspace identici**, senza differenze di contenuto o modalità.
Comprendono l'ultima correzione di `GlifiStudioService` e GS-VER-183: il
preflight non è attribuito a uno snapshot precedente. Non sono stati duplicati
l'archivio o le cache dell'altra attività.

Restano segnalazioni della toolchain su CoreSimulator non aggiornato e sul runner
nativo; le build iPadOS segnalano inoltre la dichiarazione di apertura documenti
in place assente. Non sono stati abbassati warning, target o gate. La correzione
della metadata iPadOS e gli audit su simulatore/dispositivo restano distinti dal
focus macOS. Questi esiti non costituiscono firma, submission, G4 o misure
energetiche su hardware di riferimento.

Allegati conservati: [risultati nativi senza identificatori del dispositivo](allegati/GS-VER-182-test-macos.json),
[misura Release e fixture](allegati/GS-VER-182-snapshot-release.json),
[confronto con lo snapshot del preflight](allegati/GS-VER-182-confronto-snapshot.json).
I conteggi della composizione comprendono lavori paralleli e non sono attribuiti
interamente a GS-VER-182.

## Pulizia conclusiva

Terminati i processi, il coordinatore ha rimosso la sola cache dedicata del
lotto, il probe Release e il log red temporaneo: 2.984.760 KiB
allocati prima della rimozione. Con i 509.064 KiB della copia red già rimossa,
sono circa **3,33 GiB di artefatti non più attivi eliminati**. La misura è
`du -sk` sui percorsi interessati, non un delta garantito dello spazio libero
del volume. Il [riepilogo della pulizia](allegati/GS-VER-182-pulizia.json) conserva
i conteggi; sorgenti, test, evidenze utili e toolchain esistenti sono preservati.
Snapshot e cache dell'altra attività non sono stati modificati. I riferimenti
precedenti alla cache attiva descrivono il riuso durante il lavoro, non un
residuo lasciato alla consegna.
