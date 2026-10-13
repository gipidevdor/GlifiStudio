<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Pubblicazione degli oggetti del package

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-144 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Parziale; compilazione Apple superata, verifica dinamica pendente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-04 |
| Approvazione | Review pendente; non promuove requisiti o clausole |
| Riferimenti | RF-043, RQ-044, RQ-057, TV-060, CMP-095, GS-DOR-011 |

## Ambito

Estensione della [DoR GS-DOR-011](../pianificazione/dor-accessi-file-package.md),
registrata prima del coding. Prosegue il confine di [GS-VER-142](GS-VER-142-letture-directory-package.md)
senza cambiare API pubbliche, formato, dipendenze o commit point.

- Le directory di destinazione sono create con `mkdirat` e permessi `0700`, poi aperte
  tramite `openat`, `O_DIRECTORY`, `O_CLOEXEC`, `O_NOFOLLOW` per ogni componente.
  Le directory esistenti non vengono chmodificate e devono essere directory reali.
- La directory della transazione e quella di destinazione restano vive fino alla rinomina
  `renameatx_np(..., RENAME_EXCL)`. I nomi finali sono componenti singoli validati.
- La rinomina è esclusiva: nessun controllo `fileExists` seguito da move/copy e nessun
  fallback a overwrite o copia. Una destinazione esistente resta intatta.
- L'oggetto nuovo o già esistente viene letto dal descriptor della stessa directory di
  destinazione: `fstat`, file regolare, unico hard link, dimensione bounded e SHA-256.
- Una collisione non valida fallisce prima di preparare la nuova generazione. Un oggetto
  identico viene riusato; la copia staged resta fino al cleanup della transazione riuscita.
  Le transazioni precedentemente fallite restano soggette alla policy di recovery esistente.
- Directory non valide e collisioni non valide restano `corruption` senza retry. Errori
  operativi di mkdir/rinomina sono `transientIO`, `transientBackoff`, con ultima generazione
  conservata. La disponibilità di `renameatx_np`/`RENAME_EXCL` è stata controllata nel manuale
  Darwin e tramite compilazione con l'SDK Apple; filesystem senza supporto falliscono chiusi.

## Regressioni predisposte

| Area | Controllo |
| --- | --- |
| Componenti | Path anomali, file e FIFO intermedi rifiutati anche durante la creazione |
| Permessi | Nuove directory `0700`; permessi delle directory preesistenti invariati |
| Sostituzione | Radice, sorgente e destinazione rinominate dopo l'apertura e sostituite da link; mkdir e rename restano sui descriptor originali, sentinel esterna invariata |
| Esclusività | File, symlink, dangling link, hard link, FIFO e directory preesistenti conservano inode/tipo e sorgente staged |
| Integrazione | Fonti, Artifact, descriptor, investigation e qualitativo: link a ognuno dei quattro livelli, directory esterna senza nuovi file o directory |
| Conservazione | Snapshot, manifest e database invariati al rifiuto; ripristino directory e successivo commit/riapertura |
| Deduplicazione | Oggetto fonte valido preesistente riusato senza sostituirne l'inode; staging della transazione riuscita ripulito |

I casi sono sintetici e le sostituzioni deterministiche, senza sleep. I file di test sono
[GlifiPackageDirectoryTests.swift](../../Packages/GlifiCore/Tests/GlifiCoreTests/GlifiPackageDirectoryTests.swift)
e [GlifiProjectPackageTests.swift](../../Packages/GlifiCore/Tests/GlifiCoreTests/GlifiProjectPackageTests.swift).

## Verifica osservata

Base `caeda51` con patch locale non pubblicata. Host macOS 26.5.2 arm64, Xcode 27.0
`27A266a`, Swift 6.4, Python 3.12.14; nessun abbassamento di target o gate.

| Comando | Esito osservato |
| --- | --- |
| `make quality-static` | Superato, inclusa documentazione e matrice |
| `make check-failure-taxonomy check-failure-messages` | Superato |
| `make format-check` | Superato |
| `swift build --build-tests --package-path Packages/GlifiCore` | Package e bundle test compilati |
| `make verify` | Exit 2: caricamento dei bundle test impedito dal runtime macOS 26.5.2 |
| `make verify-app-store` | Exit 2 per lo stesso limite; packaging non raggiunto dal gate |
| `xcodebuild build` dal workspace | macOS e iPadOS Simulator, Debug e Release: superati separatamente |
| `Scripts/check-app-store-packaging.sh` | Eseguito separatamente: analisi statiche e archivi senza firma superati |

Nessuna asserzione runtime eseguita: i bundle macOS 27 richiedono un simbolo CoreGraphics
assente sul sistema 26.5.2. Le compilazioni supplementari non equivalgono al superamento
di `verify` o del preflight completo. Recovery kill, smoke CLI e PDF/A non raggiunti.
Rscript e veraPDF assenti; nessun nuovo harness simulator. Resta il warning iPadOS
preesistente sull'apertura dei documenti in-place. La cache dedicata è stata rimossa
con `make clean-cache`. Log e comandi completi sono allegati alla consegna della patch.

## Limiti

Questa evidenza non attesta sicurezza dell'intera transazione. Staging iniziale, lock,
sostituzione del manifest, cleanup e SQLite non diventano descriptor-relative con questa
modifica. Non si garantisce identità della radice fra operazioni separate, né persistenza
della collocazione nominale di una directory già aperta che venga spostata. Mutazioni dei
contenuti da altri writer non cooperanti, ACL, file provider, durabilità ai power loss e
recovery completa richiedono prove ulteriori. CMP-095 resta `blocked`; TV-060 aperto.
