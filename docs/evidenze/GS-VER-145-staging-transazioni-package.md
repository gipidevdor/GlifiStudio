<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Staging privato delle transazioni del package

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-145 |
| Tipo | Evidenza di verifica |
| Versione | 1.1.0 |
| Stato | Parziale; CI macOS 27 superata, confini residui aperti |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-31 |
| Approvazione | Review pendente; non promuove requisiti o clausole |
| Riferimenti | RF-043, RQ-044, RQ-057, TV-060, CMP-095, GS-DOR-011 |

## Ambito

Estensione della [DoR GS-DOR-011](../pianificazione/dor-accessi-file-package.md),
registrata prima del coding su richiesta di prosecuzione dell'iniziatore.
Prosegue [GS-VER-144](GS-VER-144-pubblicazione-oggetti-package.md) senza cambiare
API pubbliche, nomi persistiti, formato, dipendenze o commit point.

- Le directory di transazione sono create con `mkdirat` esclusivo e permessi `0700`;
  una voce preesistente, anche directory valida, non viene adottata.
- `openat` con `O_EXCL`, `O_NOFOLLOW`, `O_CLOEXEC` e permessi `0600` crea i file
  `transaction.json`, oggetti staged e manifest candidato. Scrittura e sincronizzazione
  usano il descriptor del file; nessun chmod di voci preesistenti.
  Anche la scrittura del manifest iniziale riusa lo stesso helper esclusivo.
- Il descriptor della transazione resta lo stesso dalla creazione alla promozione degli
  oggetti. Non viene riaperto il suo percorso per pubblicare gli oggetti.
- I nomi sono componenti singoli validati. Le collisioni sono `corruption` senza retry;
  i fallimenti operativi di creazione mantengono `transientIO`/`transientBackoff`.

## Regressioni predisposte

| Area | Controllo |
| --- | --- |
| Componenti | Path vuoti, assoluti, traversal, separatori alternativi e NUL rifiutati |
| Collisioni | File regolare, symlink, dangling link, hard link, FIFO e directory non sovrascritti né adottati; inode e sentinel conservati |
| Permessi | Nuove directory `0700`, file `0600`; byte vuoti, singoli e oltre un chunk conservati |
| Sostituzioni | Radice, directory transactions e staging già aperte rinominate e sostituite da link: scritture sui descriptor originali, esterno invariato |
| Failure | Directory aperta poi rimossa: errore operativo con backoff e ultima generazione conservata |
| Integrazione | Importazione, Artifact e qualitativo interrotti a staged/manifestPrepared: permessi, inventario dei file, snapshot e manifest precedenti conservati |

Le sostituzioni sono deterministiche, senza sleep. Gli eventi investigation usano gli
stessi helper e restano coperti dai round-trip esistenti; non si aggiunge un checkpoint
di fault injection alla loro API.

## Verifica osservata

Host macOS 26.5.2 arm64, Xcode 27.0 (`27A266a`), Swift 6.4 e Python 3.12.14.
Controlli ripetuti dopo l'integrazione di `main` a `c10d7f1`, preservando l'ingresso
QueryAST. Evidenza rinumerata da GS-VER-144 a GS-VER-145 per mantenere univoci gli
identificatori degli incrementi concorrenti.

| Comando | Esito osservato |
| --- | --- |
| `make quality-static` | Superato, inclusi documenti e matrice |
| `make check-failure-taxonomy check-failure-messages` | Superato |
| `make format-check` | Superato |
| `swift build --build-tests --package-path Packages/GlifiCore` | Package e bundle test compilati |
| `make verify` | Exit 2: statici, failure checks e lint superati; bundle test compilati ma non caricabili su macOS 26.5.2 |
| `make verify-app-store` | Exit 2 allo stesso caricamento; packaging non raggiunto |

Il caricamento fallisce sul simbolo CoreGraphics richiesto da macOS 27: nessuna asserzione
eseguita localmente. Recovery, smoke CLI e build app non raggiunti dal gate locale.
Rscript e veraPDF non disponibili. Nessun target abbassato, nuovo harness o esito runtime
dedotto dalla compilazione. La CI macOS 27 deve completare i gate prima del merge.

### Esecuzione remota del 2026-10-24

Su [4bd5dde](https://github.com/gpicchiarelli/GlifiStudio/commit/4bd5dde26f52f91679e6aa0daf8da2657b36835f)
della [PR #14](https://github.com/gpicchiarelli/GlifiStudio/pull/14) tutti i quattro
check sono passati. Il job `verify` `120883416179` registra macOS 27.0.1,
255 test Swift superati, 22 checkpoint di recovery e smoke QueryAST CLI.
Le regressioni su staging esclusivo, collisioni, permessi e sostituzioni sono
state eseguite sul runner, non soltanto compilate. Anche `app-store-baseline`
`120883351796` passa, inclusi analisi e archivi senza firma.

Rscript e veraPDF assenti: i relativi controlli opzionali restano saltati.
Il riallineamento a `main` `f348553` riguarda evidenze e tracciabilità, senza
nuove modifiche Swift; richiede comunque i gate verdi sulla nuova revisione.
Il risultato non estende la garanzia ai confini residui e non promuove CMP-095.

Il preflight locale richiesto da CONTRIBUTING resta bloccato dal runtime 26.5.2:
CI verde non equivale a una deroga. Il merge resta sospeso fino al superamento
locale o all'approvazione e registrazione di una deroga esplicita applicabile.

## Limiti e recupero

La creazione non è una nuova transazione filesystem atomica. Una directory già aperta
e rinominata conserva la propria identità, non la posizione nominale. La sostituzione
con una directory reale fra `mkdirat` e `openat` e writer non cooperanti non sono esclusi
da questo incremento. La lettura e il replacement del manifest candidato, cleanup,
SQLite e l'identità condivisa fra lock, verifica iniziale e commit restano path-based
o non integralmente ancorati. Nessuna garanzia su ACL, file provider o power-loss
durability. CMP-095 resta `blocked`, TV-060 aperto. Rollback tramite revert senza migrazione.
