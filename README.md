<!-- SPDX-License-Identifier: BSD-3-Clause -->

<p align="center">
  <img src="Design/AppIcon/AppIcon-master-1024.png" width="88" height="88" alt="Icona di Glifi Studio">
</p>

<h1 align="center">Glifi Studio</h1>

<p align="center">
  <strong>Documenti, corpus e analisi testuale. Con rigore, fino alla fonte.</strong>
</p>

<p align="center">
  Ambiente computazionale Apple-native per trasformare grandi collezioni testuali in risultati verificabili, riproducibili e navigabili.
</p>

<p align="center">
  <a href="https://github.com/gpicchiarelli/GlifiStudio/actions/workflows/ci.yml"><img alt="Verifica" src="https://github.com/gpicchiarelli/GlifiStudio/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/gpicchiarelli/GlifiStudio/actions/workflows/app-store.yml"><img alt="App Store preflight" src="https://github.com/gpicchiarelli/GlifiStudio/actions/workflows/app-store.yml/badge.svg"></a>
  <a href="CHANGELOG.md"><img alt="Versione 0.1.0" src="https://img.shields.io/badge/versione-0.1.0-6557d2.svg"></a>
  <a href="#stato-del-progetto"><img alt="Stato: baseline ingegneristica" src="https://img.shields.io/badge/stato-baseline%20ingegneristica-c9835a.svg"></a>
  <a href="Packages/GlifiCore/Package.swift"><img alt="Apple Swift 6.4" src="https://img.shields.io/badge/Swift-6.4-F05138.svg?logo=swift&logoColor=white"></a>
  <a href="docs/ambiente-di-sviluppo.md"><img alt="Xcode 27" src="https://img.shields.io/badge/Xcode-27-147EFB.svg?logo=xcode&logoColor=white"></a>
  <a href="docs/apple/README.md"><img alt="Piattaforme: macOS 27 e iPadOS 27" src="https://img.shields.io/badge/piattaforme-macOS%2027%20%7C%20iPadOS%2027-315CFF.svg?logo=apple&logoColor=white"></a>
  <a href="docs/internazionalizzazione-interfaccia.md"><img alt="Interfaccia: italiano e inglese" src="https://img.shields.io/badge/interfaccia-it%20%7C%20en-6c63d9.svg"></a>
  <a href="docs/app-store/README.md"><img alt="Distribuzione: App Store non in elenco" src="https://img.shields.io/badge/distribuzione-App%20Store%20non%20in%20elenco-4f5eb8.svg?logo=appstore&logoColor=white"></a>
  <a href="docs/repository/README.md"><img alt="Repository privato" src="https://img.shields.io/badge/repository-privato-6e7681.svg?logo=github&logoColor=white"></a>
  <a href="LICENSE"><img alt="Licenza BSD 3-Clause" src="https://img.shields.io/badge/licenza-BSD--3--Clause-214237.svg"></a>
</p>

![Laboratorio di analisi testuale di Glifi Studio](docs/assets/glifistudio-hero.png)

Glifi Studio è un ambiente computazionale professionale Apple-native per
acquisizione, organizzazione, interrogazione, corpus analysis, linguistica
computazionale, text mining, content analysis e studio quantitativo, qualitativo,
statistico e semantico di documenti e grandi collezioni testuali su macOS e iPadOS.

Il **progetto persistente** è il contenitore fondamentale; al suo interno l'utente
sviluppa una o più **indagini** guidate da una domanda e da ciò che desidera
comprendere. Fonti, metadati, trasformazioni, piani, evidenze, findings e risultati
restano collegati in una catena di provenienza ispezionabile: ogni affermazione deve
poter tornare al metodo e al materiale che la sostengono.

```text
acquisizione → estrazione → normalizzazione → segmentazione
            → tokenizzazione → annotazione → indicizzazione
            → analisi → evidenze → findings → esplorazione
                                             ↕
                                      fonte originale
```

Glifi Studio non è un editor generalista con qualche statistica aggiunta e non è una semplice utility per contare parole. Il progetto separa il prodotto interattivo dal motore computazionale, tratta la scalabilità come vincolo architetturale e ammette ottimizzazioni soltanto quando benchmark e profiling ne dimostrano il valore.

## Stato del progetto

> [!IMPORTANT]
> **Incrementi verticali eseguibili — non ancora un prodotto pronto al rilascio.** Il motore crea e verifica package `.glifi`, incorpora TXT e Markdown UTF-8 bounded con commit generazionale, estrae Markdown tramite `SpanMap`, applica `it-token-v1` e interroga la generazione persistita con `QueryAST`/KWIC. Profilo corpus e keyness G-test/effect/BH producono `AnalysisDescriptor`, DAG e Artifact content-addressed, riaperti fail-closed e riusati senza ricalcolo. `planner-mvp-v1` genera e persiste piani deterministici; l'esecuzione materializza gli step e un Artifact `Evidence → Finding → Caveat` con lineage esatto. Investigation e selezioni editoriali sono eventi content-addressed in una storia append-only ramificabile. Un head può essere proiettato in `ReportRevision` ed esportato in PDF/A-2u, Markdown, CSV e JSON con `ExportManifest`, digest e commit atomico. Core, Kit e CLI condividono admission di sistema, progresso e cancellazione. Le app condividono il percorso Must (progetto, import, indagine, piano/esecuzione, KWIC, findings, export) come client di GlifiKit. G1 leggero e G2 headless sono registrati; G3–G5 richiedono ancora audit dispositivo, validazione UX e App Store. Le [dieci specifiche di design](docs/specifiche-di-design/README.md), il [threat model](docs/sicurezza/README.md), il [contratto API/CLI](docs/api/README.md) e la [baseline 0.1](docs/specifiche-di-design/10-product-baseline-mvp.md) restano l'autorità.

La documentazione è una baseline controllata: requisiti, architettura e decisioni aperte sono tracciati, ma non tutte le scelte di prodotto hanno ancora approvazione definitiva. La presenza di una tecnologia o di un documento non equivale alla disponibilità della relativa funzione.

| Superficie | Baseline attuale |
| --- | --- |
| App macOS | `DocumentGroup` nativo su package `.glifi` + percorso Must GlifiKit |
| App iPadOS | Stesso `DocumentGroup` Shared, adattivo per navigazione e importer di sistema |
| `GlifiKit` | `ProjectSession` actor-isolated con progetto/import, query, planner, analisi persistenti, Investigation ed export scientifico; espone interpretazione, progresso e receipt senza tipi interni |
| `GlifiCore` | Motore actor-based con import strict, `md-extract-v1`/SpanMap, package `.glifi`/SQLite generazionale, tokenizer italiano, `QueryAST`/KWIC, planner/esecutore, AnalysisDescriptor/DAG/Artifact, Evidence/Finding/Caveat, ReportRevision ed ExportManifest content-addressed |
| `GlifiCLI` | Status, create/info/validate/import, query, piano/esecuzione, Investigation create/select/list, analyze, keyness ed export PDF/Markdown/CSV/JSON testuali/JSON v1 |
| Qualità | Gate riproducibile con Apple Swift 6.4, test/build, controlli Apple/App Store, zero telemetria e matrice di conformità automatica; `verify` eseguito sul runner `xcode-27` (GS-VER-141) |
| Design implementativo | GS-DOM/DAT/LNG/QRY/ANA/RUN/UI/VIZ/VAL/PROD definiti come baseline candidata; nessuna funzione è dichiarata implementata per questo solo fatto |
| Distribuzione | Preparazione controllata per App Store non in elenco; firma, dispositivi, materiali e approvazioni reali restano fail-closed |

## Principi di progetto

- **Correttezza prima della convenienza.** Significato, unità, offset e trasformazioni devono essere definiti e verificabili.
- **Provenienza come parte del dato.** Versione del corpus, fonte, parametri e artefatti derivati viaggiano insieme al risultato.
- **Elaborazione incrementale.** La dimensione del corpus può cambiare il costo, non obbligare l’intera collezione a risiedere in memoria.
- **Confini piccoli e sostituibili.** Interfaccia, API, motore, persistenza e backend di calcolo evolvono senza dipendenze inverse.
- **Prestazioni dimostrate.** CPU, Accelerate, Core ML, Metal e altri percorsi vengono promossi soltanto su misure end-to-end riproducibili.
- **Esperienza Apple-native.** SwiftUI, Swift Concurrency e i framework di sistema vengono usati secondo disponibilità, accessibilità e comportamento reale sui dispositivi.
- **Cooperazione con il sistema.** Low Power Mode, termica, memoria, lifecycle,
  QoS e App Nap limitano il lavoro senza alterare la correttezza dei risultati.
- **Osservabilità senza sorveglianza.** Unified Logging e signpost restano locali e
  tipizzati; la 0.1 non incorpora analytics, crash upload o telemetria remota.
- **Automazione senza GUI.** Il motore deve restare utilizzabile tramite contratto applicativo e strumenti headless.
- **Semantica scientifica esplicita.** Formula, dominio, precondizioni, determinismo,
  provenienza e verifica indipendente precedono backend e visualizzazione.
- **Intenzioni prima degli algoritmi.** L'esperienza parte da ciò che la persona
  studia e vuole comprendere; metodi e parametri emergono per approfondimento.
- **Conclusioni verificabili.** Ogni finding attraversa evidenza, fonti e metodo;
  quando i dati non sostengono una conclusione, Glifi Studio lo dichiara.

## Architettura

```text
┌──────────────────────────────────────────────────────────────┐
│             Glifi Studio · macOS / iPadOS                    │
│        esperienza nativa, navigazione, visualizzazione       │
└────────────────────────────┬─────────────────────────────────┘
                             │
                       ┌─────▼─────┐
                       │ GlifiKit  │  contratto applicativo
                       └─────┬─────┘
                             │
          ┌──────────────────▼──────────────────┐
          │              GlifiCore              │
          │ progetti · corpus · indagini        │
          │ planner · evidenze · provenienza    │
          └──────────────┬───────────┬──────────┘
                         │           │
                 persistenza    calcolo/linguistica
                         │           │
                         └─────┬─────┘
                               │
                 framework e servizi Apple

GlifiCLI ────────────────────► GlifiKit
```

La dipendenza procede dall’esterno verso l’interno: il dominio non dipende da SwiftUI, gli algoritmi non dipendono da una persistenza concreta e la GUI non determina il modello scientifico. La [descrizione dell’architettura](docs/architettura.md) definisce view, invarianti e corrispondenze; le [ADR](docs/adr/README.md) registrano le decisioni senza riscriverne retroattivamente il rationale.

Il formato candidato è un package `.glifi` v1: fonti incorporate per default,
metadati relazionali controllati e artefatti immutabili content-addressed. Il
contratto completo, inclusi SpanMap, recovery e migrazioni, è in
[GS-DAT-001](docs/specifiche-di-design/02-dati-lineage-e-persistenza.md).

Il manifest è l'unico commit point. Fonti, DAG/Artifact e storia dell'indagine
condividono il protocollo generazionale; lo schema 2 migra additivamente allo
schema 3 prima della prima scrittura. Import, Artifact ed export superano
`SIGKILL` in un processo separato ai rispettivi checkpoint del commit. Quando la
generazione corrente fallisce la validazione, `openReadOnlyRecovery` riapre la più
recente generazione precedente interamente verificabile, senza riscrivere il
package. Power-loss, indice, autosave coalesced, migrazione N-1, fault injection
specifica della storia e preview/replace UI dell'export restano da provare.

## Avvio rapido

### Requisiti

- macOS con Xcode 27 e Command Line Tools selezionati;
- SDK macOS 27 e iOS/iPadOS 27;
- Apple Swift 6.4 o successiva compatibile della serie 6, in Swift 6 language mode;
- nessuna dipendenza runtime di terze parti nella baseline corrente.

### Baseline Swift

La versione scelta è **Apple Swift 6.4**. Compilatore, modalità linguistica e
strumenti SwiftPM sono contratti distinti:

| Livello | Baseline |
| --- | --- |
| Compilatore | Apple Swift 6.4, fornito da Xcode 27 |
| Modalità linguistica | Swift 6 |
| Configurazione Xcode | `SWIFT_VERSION = 6.0` |
| Manifest del package | `swift-tools-version: 6.4` e `swiftLanguageModes: [.v6]` |
| Sicurezza del codice concorrente | `SWIFT_STRICT_CONCURRENCY = complete` |
| Diagnostica | warning Swift e Clang trattati come errori |

`SWIFT_VERSION = 6.0` è intenzionale: seleziona la modalità linguistica Swift 6 e
non indica l'uso del compilatore 6.0. Una versione successiva della serie 6 entra
nella baseline soltanto con Xcode 27 e dopo il superamento dell'intero quality gate;
Swift 7 richiederà una nuova decisione. Il contratto completo è in
[ADR-0015](docs/adr/0015-baseline-swift-6-4.md) e nella
[guida dell'ambiente](docs/ambiente-di-sviluppo.md).

### Workspace Xcode

```sh
make bootstrap
open GlifiStudio.xcworkspace
```

Usare il workspace, non il solo progetto, e scegliere uno degli schemi condivisi:

- `GlifiStudio-macOS`
- `GlifiStudio-iPadOS`

### Percorso headless

```sh
swift run --package-path Packages/GlifiCore GlifiCLI
```

Output atteso:

```text
GlifiCore pronto
```

Il percorso headless completo crea un package, incorpora fonti e interroga la
generazione autorevole senza accesso laterale allo store:

```sh
swift run --package-path Packages/GlifiCore GlifiCLI project create Studio.glifi
swift run --package-path Packages/GlifiCore GlifiCLI import Studio.glifi fonte.txt
swift run --package-path Packages/GlifiCore GlifiCLI query Studio.glifi --text 'normalized:acqua'
swift run --package-path Packages/GlifiCore GlifiCLI analyze Studio.glifi
```

La [guida dell’ambiente di sviluppo](docs/ambiente-di-sviluppo.md) descrive toolchain, build, schemi e convenzioni operative.

## Verifica

Il quality gate locale e quello CI condividono un unico ingresso:

```sh
make verify
```

Il gate controlla igiene e configurazione del repository, assenza di segreti e materiale di firma, toolchain, naming, documentazione, dipendenze architetturali, localizzazione, requisiti Apple, baseline App Store, dialetto Swift, formattazione, test, process-kill recovery, smoke test CLI e build Debug/Release di entrambe le app senza firma.

Il loop rapido senza build Xcode:

```sh
make format
make quality-static
make quality
```

Contratto operativo: [loop di sviluppo e qualità](docs/loop-di-sviluppo-e-qualita.md).

Controlli mirati:

| Comando | Scopo |
| --- | --- |
| `make check-toolchain` | Verifica Xcode 27, Apple Swift 6.4+, language mode, SwiftPM tools e strict concurrency |
| `make check-swift-dialect` | Verifica dialetto Swift 6, `.swift-format` e coerenza Make/CI |
| `make format` | Autofix di formattazione Swift su `Apps` e `Packages` |
| `make lint` / `make format-check` | Formattazione Swift in modalità strict |
| `make quality-static` | Docs, compliance, segreti, dialetto e baseline senza Swift format |
| `make quality` | Controlli statici + dialetto + formattazione senza build Xcode |
| `make test` | Test dei package Swift |
| `make build-macos` | Build Debug macOS senza firma |
| `make build-ipados` | Build Debug per simulatore iPadOS senza firma |
| `make check-compliance` | Verifica requisito → specifica → codice → test → fixture → evidenza → gate |
| `make check-fixtures` | Ricalcola seed numerici e valida offset UTF-8 e descrittori avversari |
| `make check-recovery` | Esegue 16 terminazioni `SIGKILL` sui commit di import, Artifact ed export |
| `make check-app-store` | Coerenza della baseline App Store |
| `make verify-app-store` | Preflight di packaging e distribuzione |
| `make app-store-submission-check` | Gate fail-closed per una submission reale |

Le prove riproducibili vengono registrate nell’[indice delle evidenze](docs/evidenze/README.md); le eccezioni temporanee richiedono una [deroga controllata](docs/deroghe/README.md).

## Roadmap

Lo sviluppo riduce prima i rischi che possono invalidare l’architettura:

1. **Convalida delle specifiche** — prototipi di `.glifi`, SpanMap, QueryAST, DAG,
   budget runtime e navigazione; corpus e soglie di riferimento.
2. **Vertical slice headless** — dal testo UTF-8 a progetto, indagine, profilo della raccolta, piano spiegabile, evidenze e risultati riproducibili.
3. **Primo flusso interattivo** — domanda iniziale, importazione progressiva, sintesi editoriale, oggetti esplorabili e catena Conclusione → Evidenza → Fonti → Metodo.
4. **Documenti e corpus ricchi** — PDF, OCR tracciato, metadati, confronto, cronologia ramificata e relazione dell'indagine.
5. **Analisi avanzata** — metodi multivariati, grafi, topic, servizi linguistici sostituibili e accelerazioni approvate da correttezza e benchmark.

La sequenza, i criteri di uscita e la natura ancora proposta del piano sono definiti nella [roadmap completa](docs/roadmap.md).

## Struttura del repository

| Percorso | Responsabilità |
| --- | --- |
| [`Apps`](Apps) | App native macOS/iPadOS e risorse condivise |
| [`Packages/GlifiCore`](Packages/GlifiCore) | `GlifiCore`, `GlifiKit`, `GlifiCLI` e relativi test |
| [`Config`](Config) | Build settings, sandbox ed entitlement per piattaforma |
| [`Design`](Design) | Master e provenienza degli asset visivi |
| [`Distribution/AppStore`](Distribution/AppStore) | Metadati, privacy, review e materiali di distribuzione |
| [`Benchmarks`](Benchmarks) | Contratti e futuri risultati prestazionali riproducibili |
| [`Fixtures`](Fixtures) | Corpus e fixture sintetiche controllate |
| [`Scripts`](Scripts) | Bootstrap, controlli e quality gate |
| [`docs`](docs) | Standard, requisiti, architettura, decisioni ed evidenze |

## Documentazione essenziale

- [Indice della documentazione](docs/README.md)
- [Visione e principi](docs/visione-e-principi.md)
- [Specifica dei requisiti](docs/requisiti.md)
- [Specifica normativa dei metodi analitici](docs/metodi-analitici/README.md)
- [Specifica dell'esperienza utente](docs/esperienza-utente/README.md)
- [Specifiche di design implementativo](docs/specifiche-di-design/README.md)
- [Threat model e architettura di sicurezza](docs/sicurezza/README.md)
- [Contratto GlifiKit e GlifiCLI](docs/api/README.md)
- [Product baseline 0.1](docs/specifiche-di-design/10-product-baseline-mvp.md)
- [Architettura](docs/architettura.md)
- [Matrice di tracciabilità](docs/tracciabilita.md)
- [Standard di progetto](docs/standard-di-progetto.md)
- [Tecnologie e pratiche Apple](docs/apple/README.md)
- [Osservabilità e telemetria macOS](docs/apple/14-osservabilita-e-telemetria-macos.md)
- [Sostenibilità di sistema macOS](docs/apple/15-sostenibilita-di-sistema-macos.md)
- [Ambiente Xcode e baseline Swift](docs/ambiente-di-sviluppo.md)
- [Loop di sviluppo e qualità](docs/loop-di-sviluppo-e-qualita.md)
- [Preparazione App Store](docs/app-store/README.md)
- [Decisioni aperte](docs/decisioni-aperte.md)
- [Registro ADR](docs/adr/README.md)

Gli appunti originari restano conservati come provenienza incompleta e non normativa. In caso di divergenza fanno fede documenti controllati, ADR accettate, codice e test, secondo l’ordine definito in [`AGENTS.md`](AGENTS.md).

## Contribuire e sicurezza

Prima di proporre una modifica, leggere le [regole di contribuzione](CONTRIBUTING.md) e le [istruzioni operative](AGENTS.md). Cambiamenti a formati persistenti, dipendenze, entitlement, rete, telemetria, sincronizzazione o backend richiedono requisiti e decisioni applicabili.

Le vulnerabilità non devono essere aperte come issue pubbliche: seguire la [policy di sicurezza](SECURITY.md). Per assistenza generale è disponibile la [policy di supporto](SUPPORT.md); ruoli e processo decisionale sono descritti in [GOVERNANCE.md](GOVERNANCE.md).

## Licenza

Glifi Studio è distribuito secondo la [BSD 3-Clause License](LICENSE), identificatore SPDX `BSD-3-Clause`. La [politica di licenza](docs/licenza.md) ne definisce ambito, attribuzioni e gestione dei materiali di terzi.
