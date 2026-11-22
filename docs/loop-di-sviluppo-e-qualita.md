<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Loop di sviluppo e qualità

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DEV-002 |
| Tipo | Guida controllata del loop di sviluppo |
| Versione | 1.5.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
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
| `make check-swift-dialect` | Sempre nel loop e nel gate | Verifica language mode, concurrency, regole e CI |
| `make quality-static` | Iterazione senza toolchain Swift | Docs, compliance, segreti, tassonomia e messaggi delle failure, dialetto e baseline statiche |
| `make quality` | Iterazione locale rapida | `quality-static` + formattazione, senza build Xcode |
| `make check-recovery` | Modifiche a package, SQLite o commit | `SIGKILL` e riapertura su 12 checkpoint import/Artifact |
| `make verify` | Prima di integrare | Gate completo locale macOS/iPadOS, identico al job CI `verify` |
| `make verify-macos` | Focus macOS esplicitamente richiesto | Tutti i controlli condivisi e test/build macOS Debug/Release; omette soltanto build iPadOS |
| `make verify-app-store` | Modifiche ad app o distribuzione | Verifica e packaging senza firma per entrambe le piattaforme |
| `make verify-app-store-macos` | Preflight del focus macOS | `verify-macos`, analisi e archivio macOS senza firma; azioni iPadOS omesse |

Il profilo macOS usa il flag esplicito `--macos-only` negli script di verifica
e packaging. Senza argomenti il gate globale continua a verificare entrambe le
piattaforme. Argomenti sconosciuti, duplicati o combinazioni non ammesse vengono
rifiutati prima della creazione di temporanei e della preparazione della cache.

Per richiesta dell'iniziatore, il lavoro corrente completa prima macOS mediante
soli test automatici; lo sviluppo dedicato iPadOS è rimandato. Il profilo conserva
statici, confini architetturali, Core/Kit, CLI, oracoli, fixture, PDF/A e recovery.
Un esito positivo di `verify-macos` **non equivale** a `make verify`, non certifica
iPadOS e non chiude GUI, VoiceOver, dispositivi o G4. Gli eventuali controlli
opzionali saltati devono essere dichiarati. La verifica globale resta necessaria
quando si dichiara verificata la baseline multipiattaforma.

Non introdurre hook git obbligatori: il loop primario è Makefile + CI, come deciso
in ADR-0020.

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
2. **dopo**: al termine tutto viene rimosso — artefatti della corsa e cache di build — anche
   quando l'esecuzione fallisce, perché la pulizia sta nel `trap EXIT`.

Chi itera molte volte di seguito può conservare la cache con `GLIFI_VERIFY_KEEP_CACHE=1`,
assumendosi il costo in spazio: con la cache conservata la seconda esecuzione dura meno della metà
della prima.

| Comando o variabile | Effetto |
| --- | --- |
| `make cache-size` | Dimensione della cache, se conservata |
| `make clean-cache` | Rimuove la cache conservata |
| `GLIFI_VERIFY_KEEP_CACHE` | `1` conserva la cache al termine; default: rimossa |
| `GLIFI_VERIFY_CACHE` | Percorso della cache (default `~/Library/Caches/GlifiStudio/verify`) |
| `GLIFI_VERIFY_MIN_FREE_GB` | Spazio libero minimo richiesto prima di iniziare (default 15) |
| `GLIFI_VERIFY_MAX_CACHE_GB` | Tetto oltre il quale la cache viene svuotata (default 12) |

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
