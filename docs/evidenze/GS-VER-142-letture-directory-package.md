<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-142 — Letture relative a directory aperte del package

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-142 |
| Tipo | Evidenza di rafforzamento della persistenza |
| Versione | 1.0.0 |
| Stato | Parziale; compilazione Apple superata, verifica dinamica pendente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-04 |
| Approvazione | Review e verifica del nuovo incremento pendenti |
| Riferimenti | GS-DOR-011; GS-SEC-001 § 8; GS-DAT-001; RF-043; RQ-044; RQ-057; CMP-095; TV-060 |

## Ambito

La protezione `O_NOFOLLOW` del solo file terminale non impediva di leggere un oggetto
attraverso una directory intermedia simbolica, anche con byte e digest validi. Ora
`GlifiPackageDirectory` apre la radice e attraversa un componente alla volta con `openat`,
`O_DIRECTORY`, `O_CLOEXEC` e `O_NOFOLLOW`. Il file è aperto rispetto all'ultimo descriptor,
con `O_NONBLOCK`; `readFile` continua a verificare `fstat`, tipo regolare, numero di link,
dimensione, limite durante la lettura e SHA-256. I descriptor sono chiusi anche in caso di errore.

Il percorso relativo viene passato direttamente dai record canonici al resolver, senza
normalizzazione URL: componenti vuoti, `.`/`..`, assoluti, NUL, backslash e path oltre 256 byte
sono rifiutati. La verifica lessicale precede la suddivisione del percorso.

Le letture interessate sono manifest, fonti, descriptor, payload Artifact e cronologie
Investigation/qualitativa, comprese le letture degli oggetti selezionati in recovery.
Un errore di risoluzione produce `GlifiFailure` di categoria `corruption`, senza retry;
generazione e snapshot in memoria non vengono aggiornati. Nessuna modifica a serializzazione,
digest, schema persistente, API pubbliche, dipendenze, UI o strategia di commit.

## Regressioni sintetiche

- `packageDirectoryRejectsInvalidPaths`: percorsi anomali e rifiuto di più componenti
  nell'apertura di una singola directory.
- `packageDirectoryPinsOpenedDirectory`: sostituzione deterministica della radice o di una
  directory già aperta con un link verso byte diversi. Il descriptor preesistente legge
  l'oggetto originale; una nuova risoluzione attraverso il link fallisce.
- `packageDirectoryRejectsNonDirectories`: file regolare e FIFO al posto di una directory.
- `projectPackageRejectsLinkedObjectDirectories`: link a ognuno dei quattro livelli di
  fonti, Artifact, descriptor e Investigation, anche con payload originale valido fuori
  dal package; apertura rifiutata, manifest/snapshot e file esterno invariati, ripristino.
- `qualitativeHistoryRejectsLinkedDirectories`: stessa copertura a quattro livelli per
  lettura della cronologia già aperta, riapertura e ripristino del package.

Le prove di sostituzione non dipendono da scheduling o sleep; dimostrano l'ancoraggio dei
descriptor, non una copertura esaustiva di tutti gli interleaving filesystem.

## Verifiche osservate

- Linux: `make quality-static`, `make check-failure-taxonomy` e
  `make check-failure-messages` superati sul nuovo codice e sui test.
- Linux: `make format-check` bloccato dall'assenza di Swift; `make verify` e
  `make verify-app-store` si arrestano su `df -g` (opzione BSD/macOS, non GNU/Linux).
- VM Apple: macOS 26.5.2 arm64, Xcode 27.0 RC (`27A266a`), Apple Swift 6.4 e
  Python 3.12.14. `make format-check` superato dopo due correzioni di lunghezza nel
  test delle directory; controlli statici e failure taxonomy/messages superati.
- Compilazione SwiftPM del package e dei bundle test superata, senza errori Swift.
  `make verify` si arresta al caricamento dei test: il simbolo CoreGraphics richiesto
  dal bundle macOS 27 manca sul sistema 26.5.2. Nessuna asserzione nativa eseguita
  localmente; nessun abbassamento del deployment target o dei gate.
- Verifica dinamica completa del nuovo incremento richiesta sulla CI macOS 27.
- `make verify-app-store` si arresta allo stesso caricamento dei test. Eseguite
  separatamente: build macOS/iPadOS Debug e Release, analisi e archivi senza firma,
  tutti superati. Questo non equivale al superamento del preflight completo.
- Warning iPadOS preesistente sull'apertura documenti in-place non modificato.
- La CI verde precedente, registrata in GS-VER-141, non attesta questi nuovi test.

## Limiti e chiusura

La radice è aperta per ciascuna lettura, non mantenuta come identità per l'intera sessione
o transazione. I genitori esterni della radice selezionata non vengono attraversati da questo
resolver. Un descriptor già aperto resta valido anche se la directory viene rinominata
altrove: non si afferma che il suo nuovo nome resti contenuto nella radice.

Scritture, promozioni, sostituzione del manifest, cleanup e accessi SQLite continuano a usare
API basate su URL/path; restano fuori dalla garanzia descriptor-relative. Non si attesta
resistenza a mutazioni arbitrarie di un account locale compromesso, né verifica di ACL,
mount point, file provider o dispositivi. Non sono state misurate prestazioni.

CMP-095 resta `blocked`; nessuna chiusura automatica di TV-060/G2. Non vengono abbassati
deployment target o gate. Rollback con revert, senza migrazione dei dati.
