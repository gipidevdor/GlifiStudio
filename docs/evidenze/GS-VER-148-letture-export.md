<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-148 — Letture bounded nella verifica export

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-148 |
| Tipo | Evidenza di rafforzamento della verifica export |
| Versione | 1.2.0 |
| Stato | Superato su runner remoto nel perimetro dichiarato; preflight locale bloccato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-31 |
| Approvazione | Richiesta di prosecuzione dell'iniziatore; review pendente |
| Riferimenti | GS-DOR-004 S4; GS-SEC-001 §§ 7–8, 11; RQ-044; RQ-061; TV-060; TV-074; CMP-095; ADR-0022; ADR-0023 |

## Ambito

`GlifiScientificExporter.verifyExport` apre una volta la radice tramite
`GlifiPackageDirectory` e legge manifest e payload con `openat`, `O_NOFOLLOW` e
`O_NONBLOCK`. Il controllo riguarda il descriptor effettivamente letto: file regolare,
singolo hard link, dimensione non negativa e bounded, byte count atteso per i payload.
Ogni chunk contiene al massimo 64 KiB; un byte oltre la dimensione iniziale è sufficiente
per rifiutare il file, senza trattenere dati oltre il budget. Dimensione e link count
vengono ricontrollati dopo la lettura. Digest, forma canonica, inventario e validazioni
JSON/CSV/PDF già presenti restano attivi. Non vengono introdotte API pubbliche.

Gli errori di apertura/lettura vengono tradotti nei codici esistenti
`export.invalid-directory`, `export.invalid-manifest` e `export.invalid-file`, senza
path o contenuto. Un manifest JSON troncato non lascia uscire `DecodingError`.
Le categorie esistenti restano `invalidInput` per la radice e `invariantViolation`
per file/manifest non validi; retry e retained state seguono la tassonomia vigente.

## Regressioni aggiunte

- Matrice manifest/report JSON × symlink, hard link, directory, FIFO, sparse file oltre
  il limite e contenuto troncato; failure tipizzata, file esterno invariato, ripristino
  e nuova verifica uguale alla precedente. Il progetto si riapre con snapshot invariato.
- Lettura esatta di 0, 1, 65.535, 65.536, 65.537 e 131.073 byte; rifiuto di budget
  insufficiente o dimensione attesa diversa. I file fuori budget sono sparse, senza
  allocare in memoria payload grandi per produrre le fixture.
- Sostituzione deterministica della radice dopo l'apertura: il lettore mantiene i byte
  originali; una nuova verifica rifiuta la radice simbolica. File esterno invariato.
- Il round-trip esistente continua a coprire tutti i cinque payload e la manomissione.

Le fixture sono sintetiche e isolate. Non viene dichiarata una riproduzione esaustiva
delle corse concorrenti fra `fstat` e ogni singola lettura.

## Verifiche osservate

- Linux: `make quality-static`, `make check-failure-taxonomy`,
  `make check-failure-messages` e `git diff --check` superati.
- Linux: `make format-check` tentato, exit 2 perché Swift non è disponibile.
- Linux: `make verify` e `make verify-app-store` tentati, exit 2 su `df -g`
  (opzione BSD/macOS non disponibile). Nessun gate modificato per aggirare il limite.
- Apple (2026-10-24): sulla base `c0b472f` con la patch export e due correzioni di
  formato, Xcode 27.0 (`27A266a`), Swift 6.4 e Python 3.12.14 completano statici,
  failure checks, `make format-check` e `swift build --build-tests`.
- Apple: `swift test --filter scientificExport` termina con exit 1 prima delle
  asserzioni. `make verify` e `make verify-app-store` terminano con exit 2 allo stesso
  caricamento: host macOS 26.5.2, simbolo CoreGraphics del target macOS 27 assente.
  **Test compilati, non eseguiti**; recovery, smoke CLI, build app e packaging non
  raggiunti. Rscript assente. Nessun target o controllo abbassato.
- Il riallineamento con `main` integra soltanto le evidenze delle PR #19 e #20 e mantiene
  inalterato il codice Swift compilato sopra.

### Verifica remota del 2026-10-31

La [PR #21](https://github.com/gipidevdor/GlifiStudio/pull/21), head `158db49`, è stata
verificata come merge di prova `5309973` con `main` `f348553`. Tutti i quattro check
sono verdi: `static-quality`, `format-check`, `verify` e `app-store-baseline`.

- Runner `xcode-27-arm64`, host macOS 27.0.1; nessuna riduzione dei target.
- `verify` (job `124563989886`): 25 test GlifiKit e 249 test GlifiCore superati,
  22 checkpoint process-kill recovery, contratti CLI e build macOS/iPadOS.
- Le nuove regressioni export sono effettivamente eseguite: 12 combinazioni
  file/danno, sei confini di chunk e sostituzione deterministica della radice.
- `app-store-baseline` (job `124563923326`): gate completo e packaging superati.
- Oracoli numerici R e validazione PDF/A esterna saltati: Rscript e veraPDF assenti
  sul runner. La CI verde non attesta questi controlli opzionali.

Il risultato remoto non sostituisce il preflight **locale** richiesto da
`CONTRIBUTING.md`. La PR resta in bozza: nessuna deroga vigente, review o merge
autorizzati da questa evidenza. La compilazione sul vecchio host resta distinta
dall'esecuzione sul runner macOS 27.

## Limiti e recupero

La lettura è ancorata alla radice aperta, non alla sua collocazione nominale. Gli antenati
della radice, l'enumerazione dei nomi tramite `FileManager`, le scritture dello staging e
il rename finale non sono convertiti a descriptor-relative. L'inventario materializza
tutti i nomi: il limite sui byte letti non limita il numero delle voci nella directory.
Non si garantisce uno snapshot
atomico dell'intero bundle contro writer non cooperanti; manifest e digest non sono firme.
ACL, mount point, file provider, power-loss, preview UI e audit su dispositivo restano esclusi.
CMP-095 resta `blocked`; questa evidenza non promuove clausole e non chiude TV-060.
La conformità già registrata per ExportManifest v1 è invariata. Nessuna dipendenza o modifica ai gate.
Rollback tramite revert, senza migrazione di dati; PR in bozza fino al preflight richiesto.
