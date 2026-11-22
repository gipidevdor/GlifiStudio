<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-014 — Baseline Swift 6.4

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-014 |
| Tipo | Evidenza di verifica della toolchain |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata della baseline ADR-0015 |

## Ambito

- requisito coperto: CV-020;
- verifiche coperte: TV-049 e regressione TV-011/TV-013;
- ambiente: Xcode 27.0 (`27A266a`), Apple Swift 6.4
  (`swiftlang-6.4.0.34.1`), SDK macOS/iOS 27;
- configurazione: Swift 6 language mode, SwiftPM tools 6.4, strict concurrency
  completa e avvisi trattati come errori.

## Procedura

1. rilevazione di Xcode e del compilatore selezionato tramite `xcrun`;
2. verifica automatica della serie Swift 6 e della versione minima 6.4;
3. ispezione del manifest e dei build setting effettivi Release macOS/iPadOS per
   `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`,
   `swift-tools-version: 6.4` e `swiftLanguageModes: [.v6]`;
4. prova negativa che conferma il rifiuto di `-swift-version 6.4` e prova positiva
   della modalità `-swift-version 6`;
5. esecuzione di `make verify` e `make verify-app-store`.

## Risultato osservato

- la toolchain dichiara Apple Swift 6.4;
- manifest e configurazioni effettive di entrambi gli schemi dichiarano
  correttamente i tre livelli di versione;
- lint e test Swift sono superati;
- GlifiCLI restituisce l'output atteso;
- build Debug/Release macOS e iPadOS e packaging senza firma sono superati.

## Limiti

La verifica non prova compatibilità con future toolchain 6.x finché non vengono
eseguite. La CI GitHub non avvia i job a causa del budget Actions già registrato in
GS-WVR-001; firma, dispositivi fisici e submission App Store restano fuori ambito.

## Esito

**Superato localmente.** Compilatore, language mode e SwiftPM tools sono coerenti
con ADR-0015 e vengono ora protetti dal quality gate.
