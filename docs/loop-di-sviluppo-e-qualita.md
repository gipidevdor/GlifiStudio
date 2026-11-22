<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Loop di sviluppo e qualità

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DEV-002 |
| Tipo | Guida controllata del loop di sviluppo |
| Versione | 1.8.1 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Non ancora approvato |

## Scopo

Questo documento definisce il loop quotidiano di qualità di **Glifi Studio**:
formattazione Apple `swift-format`, dialetto Swift 6, controlli statici e
equivalenza con la CI. Integra [GS-DEV-001](ambiente-di-sviluppo.md) senza
sostituire il gate completo `make verify`.

## Ingressi canonici

| Comando | Quando | Effetto |
| --- | --- | --- |
| `make format` | Prima di commitare sorgenti Swift | Riscrive `Apps` e `Packages` secondo `.swift-format` |
| `make lint` / `make format-check` | Dopo `format` o in revisione | Controlla lo stile senza modificare i file |
| `make test-macos` | Iterazione sul ciclo documentale dell'app macOS | Compila app e modello reale dal workspace ed esegue i test Swift Testing senza app host |
| `make check-analysis-scenarios` | Modifiche a scenari, test o operazioni pubbliche | Controlla matrice, riferimenti e omissioni; quattordici controlli negativi |
| `make check-swift-dialect` | Sempre nel loop e nel gate | Verifica language mode, concurrency, regole e CI |
| `make quality-static` | Iterazione senza toolchain Swift | Docs, compliance, segreti, tassonomia e messaggi delle failure, dialetto e baseline statiche |
| `make quality` | Iterazione locale rapida | `quality-static` + formattazione, senza build Xcode |
| `make check-recovery` | Modifiche a package, SQLite o commit | `SIGKILL` e riapertura su 12 checkpoint import/Artifact |
| `make verify` / `make verify-macos` | Prima di integrare; priorità corrente macOS | Tutti i controlli condivisi e test/build macOS Debug/Release, identici al job CI `verify` |
| `make verify-all` | Verifica multipiattaforma richiesta esplicitamente | Profilo globale con build macOS e iPadOS |
| `make verify-app-store` / `make verify-app-store-macos` | Preflight corrente macOS | Verifica condivisa, test/build, analisi e archivio macOS senza firma |
| `make verify-app-store-all` | Preflight multipiattaforma richiesto esplicitamente | Include anche le azioni iPadOS |

Per richiesta ribadita dall’iniziatore il 2026-11-22, macOS è il profilo
predefinito del Makefile e di entrambi i workflow CI. Tutti i controlli condivisi
restano attivi: statici, confini architetturali, Core/Kit, CLI, oracoli, fixture,
PDF/A e recovery, oltre a test e build Debug/Release macOS. Il preflight aggiunge
analisi e archivio macOS senza firma. Lo sviluppo e la verifica dedicata iPadOS
sono rinviati; non sono un requisito per chiudere il lavoro macOS.

Gli script mantengono `--macos-only` e, senza argomenti, il profilo globale per
compatibilità. I target `*-all` lo selezionano esplicitamente. Argomenti sconosciuti,
duplicati o combinazioni non ammesse falliscono prima di creare temporanei/cache.
L’esito predefinito certifica soltanto il perimetro macOS e condiviso: non attesta
iPadOS, firma, App Review, audit manuale, dispositivi o G4. Per dichiarare verificata
la baseline multipiattaforma occorre il profilo `*-all` su richiesta esplicita.

Non introdurre hook git obbligatori: il loop primario è Makefile + CI, come deciso
in ADR-0020.

## Progetto Xcode, configurazioni e inventario

`GlifiStudio.xcworkspace` resta l'ingresso canonico. Il progetto mostra il
repository tramite riferimenti espliciti, cartelle native soltanto di
navigazione e package SwiftPM locale; i file di documentazione e verifica non
entrano per questo nei Sources o nelle risorse delle app. Config/Testing e la
matrice degli scenari rimangono elementi di sviluppo.

| Comando e profilo | Ambito verificato |
| --- | --- |
| `make check-xcode-project` su macOS | Equivale a `python3 Scripts/check-xcode-project.py --self-test`: grafo PBX, inventario, XML, xcconfig e fixture negative |
| `python3 Scripts/check-xcode-project.py` su macOS | Validazione completa con parser OpenStep nativo `plutil`, senza build né risoluzione dei package |
| `python3 Scripts/check-xcode-project.py --portable` | XML del workspace/schemi e catene xcconfig; non dichiara verificati grafo PBX, target ID o inventario |

`quality-static` usa il profilo completo con self-test su macOS e il profilo
portabile sul job Ubuntu. Il gate `make verify` richiede la validazione completa
macOS con self-test. Il checker non riscrive il progetto. Un controllo lessicale
supplementare rifiuta definizioni duplicate nella mappa objects, anche quotate o
commentate; `plutil` rimane l'unico parser del grafo e riceve il testo già
controllato. Il self-test copre 23 fixture negative e cinque positive lessicali;
verifica anche l’unicità di ID/nomi target e le configurazioni del PBXProject.
ID, percorsi, membership, package, schemi e configurazioni hanno
controlli distinti; commenti, stringhe e TargetAttributes annidati non sono
interpretati come nuove definizioni di oggetti.

I test hostless hanno ingressi distinti: macOS-Tests.xcconfig eredita Debug;
macOS-Tests-Release.xcconfig eredita Release; Common contiene le impostazioni
neutre condivise. La verifica delle sei configurazioni risolte distingue
-Onone/DEBUG da -O/wholemodule senza DEBUG. La chiusura del lotto richiede
esecuzioni native reali in entrambe le configurazioni, non la sola compilazione
del target test. Lo schema macOS analizza in Release e include il target test
soltanto per la BuildAction di testing.

Queste configurazioni non sono test plan: EA-T-01, sanitizer pianificati,
localizzazione UI, prestazioni e audit assistivi conservano i rispettivi stati.
Il catalogo InfoPlist it/en localizza la chiave descrittiva già presente; il
lookup nel bundle compilato non dimostra la presentazione di Finder o
LaunchServices. La verifica iPadOS del lotto è soltanto strutturale, senza build.

[GS-DOR-306](pianificazione/dor-progetto-xcode-completo.md) delimita il contratto;
[GS-VER-306](evidenze/GS-VER-306-progetto-xcode-completo.md) distingue le prove
mirate e la chiusura automatica del checkpoint 328169f7: gate, nativi Debug e
Release indipendenti e preflight macOS superati, con 125 definizioni e 409
esecuzioni in ciascuna configurazione. La prova resta legata a base d368285 con
overlay 302/303/304; non certifica il nuovo Core 305 integrato successivamente
nel checkout principale. Un nuovo controllo dell'inventario dopo l'integrazione
non estende questi esiti a sorgenti differenti.

## Dialetto Swift

Il progetto usa esclusivamente:

- Apple Swift 6.4 o successiva compatibile della serie 6 in Xcode 27;
- Swift 6 language mode (`SWIFT_VERSION = 6.0`, `swiftLanguageModes: [.v6]`);
- `swift-tools-version: 6.4`;
- `SWIFT_STRICT_CONCURRENCY = complete`;
- avvisi trattati come errori;
- formattazione tramite `swift format` e `.swift-format` versionato.

Non si adotta SwiftLint come autorità stilistica: le regole linguistiche e di
stile vivono in `.swift-format` e nei controlli `check-toolchain` /
`check-swift-dialect`. Feature upcoming o sperimentali globali richiedono ADR.

## Sequenza consigliata

```sh
make bootstrap
make format
make quality
make verify
```

Durante lo sviluppo di un package, `make quality` riduce il ciclo di feedback.
Prima della pull request, `make verify` resta obbligatorio. Per modifiche ad app,
privacy, packaging o metadati App Store eseguire anche `make verify-app-store`.

Il loop statico include `check-failure-taxonomy.py` e
`check-failure-messages.py`, già presenti nel gate completo: una combinazione
non ammessa di categoria, retry e stato conservato oppure un messaggio di
failure privo di traduzione interrompe subito `quality-static` con la
diagnostica del controllo. La stessa verifica anticipata si applica a
`make quality` e al job CI `static-quality`, senza richiedere Swift o Xcode.

## Cache di build e spazio su disco

Uno strumento **NON DEVE** lasciare strascichi sul disco di chi lo usa, né durante l'esecuzione né
dopo. Gli script di qualità rispettano due obblighi distinti:

1. **durante**: il picco su disco resta limitato, perché la compilation cache di Xcode è
   disattivata e le cache di build hanno un tetto dichiarato;
2. **dopo**: il `trap EXIT` rimuove gli artefatti della corsa e la cache posseduta,
   anche quando la verifica fallisce. Una terminazione non intercettabile può
   lasciare residui: non si eliminano directory altrui basandosi sul nome o sull'età.

Ogni cache ha un marcatore di proprietà e un lock esclusivo gestito dal kernel.
Un'altra esecuzione sulla stessa cache fallisce prima di modificarla; il suo
trap non può rimuovere la cache occupata. Il piccolo file di lock adiacente
resta stabile: eliminarlo permetterebbe lock distinti sullo stesso percorso.
La pulizia, compreso `make clean-cache`, usa la stessa esclusione reciproca.
Una directory non vuota senza marcatore o un symlink finale è rifiutato,
conservando i file. Una corsa interrotta lascia un marcatore di attività:
non si adotta la cache neppure quando il lock è libero, perché un compilatore
figlio può essere ancora vivo. In questi casi scegliere un percorso vuoto
con `GLIFI_VERIFY_CACHE`. `Scripts/check-build-cache.py` verifica questi
comportamenti in directory sintetiche isolate, senza compilare Swift.

Chi itera molte volte di seguito può conservare la cache con `GLIFI_VERIFY_KEEP_CACHE=1`,
assumendosi il costo in spazio: con la cache conservata la seconda esecuzione dura meno della metà
della prima.

| Comando o variabile | Effetto |
| --- | --- |
| `make cache-size` | Dimensione della cache, se conservata |
| `make clean-cache` | Rimuove la cache riconosciuta e inattiva, con lock esclusivo |
| `GLIFI_VERIFY_KEEP_CACHE` | `1` conserva la cache al termine; default: rimossa |
| `GLIFI_VERIFY_CACHE` | Percorso della cache (default `~/Library/Caches/GlifiStudio/verify`) |
| `GLIFI_VERIFY_MIN_FREE_GB` | Intero non negativo, massimo sei cifre; spazio libero minimo prima di iniziare (default 15) |
| `GLIFI_VERIFY_MAX_CACHE_GB` | Intero non negativo, massimo sei cifre; tetto senza arrotondamento al GiB, controllato all'avvio (default 12) |

Il gate si ferma subito, con un messaggio esplicito, quando lo spazio libero è sotto il minimo:
morire a metà build con «No space left on device» lascia il disco pieno e non dice che cosa fare.
La compilation cache di Xcode (`COMPILATION_CACHE_ENABLE_CACHING`) resta disattivata negli script
di qualità: il riuso incrementale della derived data stabile dà già il beneficio, mentre quella
cache cresceva di decine di gigabyte per esecuzione (GS-VER-139).

## CI

`.github/workflows/ci.yml` esegue:

1. `static-quality` (Ubuntu) — docs, tracciabilità/compliance, segreti, naming,
   repository, GitHub config, fixture, architettura, localizzazione, tassonomia
   e messaggi delle failure, baseline
   Apple/App Store e dialetto Swift, senza Xcode;
2. `format-check` (Xcode 27) — dialetto machine-readable e `swift format` strict;
3. `verify` (Xcode 27) — `Scripts/verify.sh` con cache SPM, process-kill recovery
   in processi separati e build Xcode, dopo i due early-fail.

`.github/workflows/app-store.yml` esegue `app-store-baseline` (Xcode 27) con cache
SPM e `Scripts/verify-app-store.sh`.

I check richiesti dalla ruleset restano `verify` e `app-store-baseline`. Un
fallimento statico, di stile o dialetto blocca l'integrazione; indebolire un
controllo per ottenere verde è non conformità.

## Riferimenti

- [Ambiente di sviluppo](ambiente-di-sviluppo.md)
- [Implementazione Swift](standard/12-implementazione-swift.md)
- [Integrazione continua e quality gate](standard/20-integrazione-continua-e-quality-gate.md)
- [CI e runner Xcode 27](repository/05-ci-e-runner-xcode.md)
- [ADR-0020](adr/0020-loop-di-qualita-e-dialetto-swift.md)

La copertura degli scenari analitici è definita in [GS-TST-001](pianificazione/scenari-di-analisi.md). `make verify` ne confronta l’inventario anche con il compilatore; esiti e limiti sono in [GS-VER-303](evidenze/GS-VER-303-scenari-di-analisi.md).
