<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-141 — Prima esecuzione remota dei workflow su runner Xcode 27

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-141 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato su runner remoto; controlli opzionali saltati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-STD-001-20; GS-REP-005; GS-WVR-001…004; GS-VER-038; GS-VER-057; TV-011; TV-013; TV-049 |

## Ambito

Registrare la prima esecuzione effettiva dei workflow `Verifica` e `App Store preflight`
sul runner ospitato `xcode-27` dopo il ripristino del budget Actions, e il perimetro
reale di ciò che il gate remoto ha dimostrato.

## Ambiente osservato

- Runner ospitato GitHub, immagine `xcode-27-arm64` versione `20260928.0222.1`,
  macOS 27.0 (`26A428`), runner `2.337.0`.
- Toolchain rilevata dal gate: Xcode 27.0, Apple Swift 6.4, language mode 6,
  SwiftPM tools 6.4.
- Cache SwiftPM assente alla prima esecuzione; salvata al termine con chiave
  `spm-macOS-ARM64-…`.

## Controlli

1. Merge di [PR #10](https://github.com/gpicchiarelli/GlifiStudio/pull/10) (`494936e`):
   `static-quality` verde; `format-check` e `app-store-baseline` rossi per una sola
   violazione `LineLength` in `GlifiProjectPackageTests.swift:17`; `verify` non avviato
   perché dipendente da `format-check`. Primo segnale che il budget è stato ripristinato:
   i job hanno eseguito step reali, non più annotazione di budget.
2. [PR #11](https://github.com/gpicchiarelli/GlifiStudio/pull/11) (`4463b7e`, merge ref
   `857b49a`): `static-quality` (job `111211240911`), `format-check` (job `111211241064`)
   e `verify` (job `111211298962`) verdi. `verify` ha richiesto circa 8,5 minuti senza
   cache.
3. `App Store preflight` (`app-store-baseline`, job `111211240810`) sulla stessa PR:
   in esecuzione al momento della stesura (avviato alle 13:21 UTC); l'esito va
   registrato qui prima di dichiarare chiuse le deroghe. Sul merge della PR #10 lo stesso
   job ha eseguito i controlli reali e si è fermato alla medesima violazione `LineLength`.

## Risultato di `make verify` sul runner

- Repository: 636 file versionabili, policy e baseline CI valide; nessun segreto rilevato.
- Conformità: 95 clausole; `blocked=8`, `implemented=7`, `specified=0`, `verified=80`.
- Test Swift: `GlifiKitTests` 25 test superati; `GlifiCoreTests` 232 test superati
  (8,475 s), inclusi fuzz TXT/Markdown da 2.000 input, oracoli R precalcolati e
  recovery read-only.
- Recovery con kill del processo: 22 checkpoint di commit validi.
- Smoke CLI e build Debug/Release di `GlifiStudio-macOS` e `GlifiStudio-iPadOS`
  senza firma completati.

## Controlli saltati o degradati sul runner

- `Oracoli numerici: Rscript assente, controllo saltato`: il ricalcolo indipendente
  degli oracoli R non è eseguito dal runner; valgono i valori precalcolati nelle fixture.
- `Validazione PDF/A: veraPDF assente, controllo saltato`: la conformità PDF/A degli
  export non è verificata in remoto.
- Due avvisi di build su `GlifiStudio-iPadOS`: l'app dichiara l'apertura di documenti
  ma non `LSSupportsOpeningDocumentsInPlace` né `UISupportsDocumentBrowser`.
  Nessuna modifica all'`Info.plist` è stata introdotta: la scelta tra apertura in
  place e copia incide su file provider e recovery e richiede decisione dedicata.

## Limiti e non conformità registrate

- Tra il 2026-09-22 (scadenza di GS-WVR-001…004) e il 2026-10-03 sono state integrate le
  PR #10 e #11 senza deroga valida né check remoti verdi al momento del merge. Per
  GS-WVR-001 l'eccezione scaduta è diventata non conformità; questa evidenza la
  registra e ne documenta il rientro tardivo, senza sanarla retroattivamente.
- I run verdi riguardano la revisione corrente di `main`, superinsieme dei commit
  oggetto delle deroghe; non sono state rieseguite le revisioni storiche.
- Il gate remoto non copre dispositivi fisici, VoiceOver, hardware baseline, firma,
  TestFlight né App Review: G3 formale, G4 e G5 restano aperti.
- Il ripristino del budget Actions è osservato, non garantito: una nuova sospensione
  riporterebbe la CI nello stato descritto da GS-VER-038.
