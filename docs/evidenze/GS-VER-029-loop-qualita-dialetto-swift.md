<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-029 — Loop di qualità e dialetto Swift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-029 |
| Tipo | Evidenza di verifica del loop di qualità |
| Versione | 1.2.0 |
| Stato | Superato localmente e sui runner GitHub |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata del quality gate locale e remoto completo |

## Ambito

- requisiti coperti: CV-020;
- verifiche coperte: TV-049 e loop GS-DEV-002;
- ambienti osservati: macOS locale e runner GitHub `xcode-27`, con Apple Swift
  6.4 e SDK macOS/iPadOS; runner Ubuntu per i controlli statici;
- artefatti: `Scripts/check-swift-dialect.py`, `Scripts/format.sh`,
  `Scripts/quality.sh`, Makefile, `.github/workflows/ci.yml`, ADR-0020.

## Procedura

1. ispezione di Package.swift, `Config/Base.xcconfig`, `.swift-format`, Makefile e
   workflow CI rispetto al contratto ADR-0015/ADR-0020;
2. esecuzione di `./Scripts/check-swift-dialect.py`;
3. esecuzione di `make quality-static` e `make quality`;
4. esecuzione di `make verify`, inclusi test, smoke CLI e quattro build Xcode;
5. push su `main` e osservazione fino al terminale dei workflow `Verifica` e
   `App Store preflight`.

## Risultato osservato

- il controllo dialettale riconosce tools 6.4, language mode 6, concurrency
  completa, le regole `.swift-format` obbligatorie e i target Make/CI;
- la CI dichiara `static-quality` (Ubuntu), `format-check` e `verify` (Xcode 27),
  più cache SPM su `verify` e `app-store-baseline`;
- `make quality-static` e `make quality` superano controlli documentali, di
  repository, sicurezza, compliance, architettura, localizzazione, baseline
  Apple/App Store, dialetto e formattazione;
- `make verify` supera 69 test Swift, gli smoke CLI e le build Debug/Release
  senza firma per macOS e iPadOS;
- un primo run remoto ha rilevato correttamente la dipendenza non dichiarata da
  `ripgrep` sul runner Xcode; il gate è stato reso portabile e fail-closed con
  fallback a `grep`;
- il run GitHub `35021231632` supera `static-quality`, `format-check` e `verify`;
- il run GitHub `35021231783` supera `app-store-baseline` e il preflight App
  Store completo;
- `actions/cache` 6.1.0 è fissata a SHA immutabile e non produce l'avviso del
  runtime Node 20 osservato sulla revisione precedente.

## Limiti

Non misura l'efficacia della cache tra serie di run né prova dispositivi fisici,
firma di distribuzione, notarizzazione o revisione App Store. La protezione del
branch e i limiti del provider restano evidenze operative separate.

## Esito

**Superato localmente e in CI per loop statico, Swift, Xcode e preflight App
Store.**
