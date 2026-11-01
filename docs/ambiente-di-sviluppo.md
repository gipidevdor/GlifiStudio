# Ambiente di sviluppo

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DEV-001 |
| Tipo | Guida controllata dell'ambiente di sviluppo |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | Non ancora approvato |

## Prerequisiti

- Xcode 27.0 o versione compatibile successiva;
- Apple Swift 6.4 o successiva compatibile della serie 6, fornita da Xcode 27;
- SDK macOS e iOS/iPadOS 27;
- runtime simulatore iPadOS supportato da Xcode.

La baseline di sviluppo rilevata il 2026-09-15 è Xcode 27.0 (`27A266a`) con
Apple Swift 6.4 (`swiftlang-6.4.0.34.1`). Le versioni minime di deployment sono
macOS 27.0 e iPadOS 27.0, come stabilito da ADR-0003 e precisato da ADR-0015.

## Contratto delle versioni Swift

| Livello | Valore | Significato |
| --- | --- | --- |
| Compilatore | Apple Swift 6.4 o successiva compatibile della serie 6 in Xcode 27 | Toolchain minima che compila, testa e formatta il progetto |
| Modalità linguistica | Swift 6 | Semantica del linguaggio e controllo completo della data-race safety |
| Impostazione Xcode | `SWIFT_VERSION = 6.0` | Codifica richiesta da Xcode per selezionare Swift 6; non indica il compilatore 6.0 |
| Manifest SwiftPM | `swift-tools-version: 6.4` | Versione minima degli strumenti e delle API `PackageDescription` usate dal package |
| Package | `swiftLanguageModes: [.v6]` | Dichiarazione esplicita della modalità linguistica Swift 6 |

`SWIFT_VERSION = 6.4` **NON** è valido: il compilatore accetta modalità linguistiche
per generazione (`4`, `4.2`, `5`, `6`), non la propria versione minor. Una futura
toolchain Swift 7 non entra automaticamente nella baseline; richiede una nuova
decisione e l'intero quality gate.

## Apertura

Aprire sempre:

```text
GlifiStudio.xcworkspace
```

Il workspace contiene due schemi condivisi:

- `GlifiStudio-macOS`;
- `GlifiStudio-iPadOS`.

Il package locale `Packages/GlifiCore` contiene `GlifiCore`, `GlifiKit`, `GlifiCLI` e i relativi test.

## Struttura eseguibile

```text
GlifiStudio.xcworkspace
├── GlifiStudio.xcodeproj
│   ├── GlifiStudio-macOS
│   └── GlifiStudio-iPadOS
└── Packages/GlifiCore
    ├── GlifiKit → GlifiCore
    ├── GlifiCLI → GlifiKit
    └── test di GlifiKit e GlifiCore
```

Le applicazioni condividono soltanto viste prive di dipendenze specifiche della piattaforma. Le integrazioni AppKit e UIKit devono rimanere rispettivamente in `Apps/macOS` e `Apps/iPadOS`.

## Lingua iniziale

Il progetto Xcode usa `it` come regione e lingua sorgente. Il catalogo condiviso `Apps/Shared/Resources/Localizable.xcstrings`, incluso in entrambi i target, contiene chiavi semantiche e localizzazioni complete `it`/`en`. La piattaforma seleziona la lingua dell'interfaccia; la lingua analitica resta una configurazione indipendente, inizialmente `it` con locale `it_IT`.

Le regole sono separate in [baseline linguistica italiana](localizzazione-italiana.md) e [internazionalizzazione dell'interfaccia](internazionalizzazione-interfaccia.md).

## Verifica iniziale

Eseguire:

```sh
make bootstrap
make verify
```

La verifica controlla, in ordine:

1. metadati, identificatori e link locali della documentazione;
2. coerenza della baseline di localizzazione italiana;
3. coerenza della baseline applicativa Apple, inclusi privacy e sandbox;
4. coerenza di identità, metadati, icone e dichiarazioni App Store;
5. assenza di dipendenze UI dentro `GlifiCore`;
6. dialetto Swift 6 e regole `.swift-format` obbligatorie;
7. formattazione Swift senza modificare i sorgenti;
8. unit test del package;
9. smoke test dell'accesso headless tramite `GlifiCLI`;
10. build Debug e Release senza firma dell'app macOS;
11. build Debug e Release senza firma dell'app iPadOS per il simulatore.

Gli artefatti temporanei vengono prodotti fuori dalla cartella `Documents`. Questo evita che gli attributi di provenienza applicati dal provider dei file contaminino i bundle firmabili di test e build.

I controlli singoli sono disponibili con `make check-docs`, `make check-localization`,
`make check-apple`, `make check-app-store`, `make check-architecture`,
`make check-swift-dialect`, `make lint` e `make test`. Il loop rapido
`make quality` esegue controlli statici, dialetto e formattazione senza build
Xcode; `make quality-static` omette la formattazione ed è il contratto del job CI
Linux. `make verify` resta il gate completo da eseguire prima di integrare una
modifica. Il contratto operativo è in [GS-DEV-002](loop-di-sviluppo-e-qualita.md).

Per modifiche all'app o alla distribuzione, `make verify-app-store` aggiunge analisi
statica e archivi senza firma. `make app-store-submission-check` verifica invece i
prerequisiti umani ed esterni e deve restare bloccante finché non sono documentati.

## Baseline Apple

- SwiftUI gestisce ciclo di vita e scene.
- Observation e `MainActor` governano lo stato di presentazione.
- Il privacy manifest condiviso dichiara nessun tracking o raccolta dati.
- Il target macOS usa App Sandbox e file selezionati dall'utente; Hardened Runtime è attivo in Release.
- Il target iPadOS resta iPad-only, supporta input indiretto e non presume il full screen.
- Capability ulteriori sono vietate finché non esistono requisito, dichiarazione privacy e test.

Il profilo completo è nell'[indice delle pratiche Apple](apple/README.md).

## Confini

- Le app importano `GlifiKit`.
- `GlifiKit` incapsula l'accesso a `GlifiCore`.
- `GlifiCore` non importa framework UI.
- AppKit e UIKit restano nei rispettivi adattatori o target applicativi.

## Configurazione

Le impostazioni condivise sono in `Config/*.xcconfig`. Bundle identifier, versioni di deployment e signing non devono essere disseminati nel file del progetto.

Le due app usano il bundle identifier multipiattaforma candidato
`studio.glifi.GlifiStudio`, necessario per una singola scheda App Store su macOS e
iPadOS. L'identificatore resta candidato finché non viene registrato nell'Apple
Developer Account; team di firma e profili devono ancora essere assegnati.

## Stato della baseline

La baseline è compilabile e testata localmente e, dal 2026-10-03, sul runner remoto
`xcode-27` ([GS-VER-141](evidenze/GS-VER-141-prima-ci-remota-verde.md)). Signing,
provisioning e matrice dei dispositivi fisici restano da completare prima di una
distribuzione. Gli esiti iniziali sono conservati in
[GS-VER-001](evidenze/GS-VER-001-bootstrap-ambiente.md) e nel
[preflight App Store](evidenze/GS-VER-009-preflight-app-store.md).
