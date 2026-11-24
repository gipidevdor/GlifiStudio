<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0015 — Baseline Swift 6.4 e modalità linguistica Swift 6

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0015 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Scelta esplicita della versione Swift richiesta dall'iniziatore |
| Fonte | Toolchain Xcode 27 installata e requisiti macOS/iPadOS 27 |
| Integra | ADR-0003 |
| Sostituisce | Nessuno |

## Contesto

“Versione Swift” può indicare tre contratti differenti: versione del compilatore,
modalità del linguaggio e versione degli strumenti SwiftPM. Confonderli crea una
baseline falsa: Apple Swift 6.4 compila correttamente in Swift 6 language mode,
mentre `SWIFT_VERSION = 6.4` non è una modalità linguistica valida.

La macchina e il runner previsti dal progetto usano Xcode 27.0 con Apple Swift 6.4.
Il progetto parte da macOS 27 e iPadOS 27 e non ha necessità di conservare la
compatibilità del manifest con una toolchain Swift precedente.

## Decisione

1. Apple Swift 6.4 è il compilatore minimo della baseline.
2. È ammessa una versione successiva compatibile della serie 6 soltanto se fornita
   da Xcode 27 e se supera integralmente i quality gate locali e remoti applicabili.
3. Il codice usa Swift 6 language mode: Xcode dichiara `SWIFT_VERSION = 6.0` e il
   package dichiara `swiftLanguageModes: [.v6]`.
4. Il manifest del package dichiara `swift-tools-version: 6.4`, rendendo esplicita
   la versione minima degli strumenti e delle API `PackageDescription`.
5. Il controllo completo della concorrenza e gli avvisi come errori restano attivi.
6. Swift 7, modalità Swift 5, upcoming feature globali o feature sperimentali
   richiedono una nuova decisione, una revisione d'impatto e prove complete.

## Rationale

Swift 6 language mode rende gli errori di data-race safety diagnostici di
compilazione. La toolchain 6.4 è quella effettivamente distribuita con la baseline
Xcode 27 installata. Allineare anche SwiftPM tools 6.4 elimina un margine di
compatibilità non richiesto, rende il manifest onesto e adotta la semantica degli
strumenti con cui package e test sono realmente verificati.

## Alternative considerate

- `SWIFT_VERSION = 6.4`: respinta perché il language mode accetta `6`, non `6.4`;
- Swift 5 language mode: respinta perché rinuncia alla garanzia completa di
  concorrenza scelta per il nuovo codice;
- `swift-tools-version: 6.0`: tecnicamente compilabile, ma respinta perché dichiara
  una compatibilità del manifest non necessaria e non coincide con la baseline;
- seguire automaticamente qualunque nuova major: respinta perché una major può
  cambiare semantica, diagnostica, dipendenze e riproducibilità.

## Conseguenze

- il significato di ogni numero Swift è univoco nei file Xcode, SwiftPM e nei gate;
- package, test e app usano la data-race safety di Swift 6;
- chi contribuisce deve usare Xcode 27 con Apple Swift 6.4 o una 6.x compatibile;
- una toolchain più vecchia fallisce prima della compilazione;
- l'adozione di una futura major non è accidentale.

## Verifica

`Scripts/check-toolchain.sh` controlla Xcode, compilatore, serie, versione minima,
manifest, language mode e strict concurrency. `make verify` convalida inoltre lint,
test, smoke test e build Debug/Release macOS e iPadOS. L'esito è registrato in
[GS-VER-014](../evidenze/GS-VER-014-baseline-swift-6-4.md).

## Riferimenti

- [Swift 6](https://www.swift.org/blog/announcing-swift-6/)
- [Swift Package Manager — tools version](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html#about-the-swift-tools-version)
- [SwiftLanguageMode.v6](https://docs.swift.org/swiftpm/documentation/packagedescription/swiftlanguagemode/v6/)
- [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)
