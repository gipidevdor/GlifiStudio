<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-139 — Cache di build riusata e limitata

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-139 |
| Tipo | Evidenza di correzione di difetto |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | GS-DEV-002 § Cache di build e spazio su disco |

## Difetto

`verify.sh` creava una directory temporanea nuova a ogni esecuzione e la passava come
`--scratch-path` e `-derivedDataPath` a una ventina di comandi `swift build`, `swift test` e
`xcodebuild`. Nulla veniva riusato fra un'esecuzione e l'altra: ogni giro ricompilava tutto da zero
e riscriveva per intero la compilation cache di Xcode, misurata in circa **37 GiB per il solo
target iPadOS** (24 GiB `data.v1`, 12 GiB `index.v1`, 1 GiB `actions.v1`).

Con esecuzioni ripetute il disco si è riempito e il gate è morto a metà build con «No space left
on device», lasciando il sistema senza spazio e senza indicazioni. Lo stesso difetto era in
`test.sh`, `check-app-store-packaging.sh` e `check-recovery-kill.sh`.

## Correzione

- **Niente strascichi**: al termine vengono rimossi sia gli artefatti della corsa sia le cache di
  build, anche quando l'esecuzione fallisce, perché la pulizia sta nel `trap EXIT`. Chi itera può
  conservare la cache con `GLIFI_VERIFY_KEEP_CACHE=1`, assumendosi il costo in spazio.
- **Percorso unico e prevedibile**: le cache vivono in `~/Library/Caches/GlifiStudio/verify`,
  non in una directory temporanea nuova a ogni giro; è ciò che rende possibile sia il tetto sia il
  riuso quando viene richiesto.
- **Compilation cache di Xcode disattivata** negli script di qualità: era la parte che cresceva di
  decine di gigabyte, e il riuso incrementale della derived data stabile dà già il beneficio.
- **Due limiti dichiarati**: il gate si ferma prima di iniziare se lo spazio libero è sotto
  `GLIFI_VERIFY_MIN_FREE_GB` (15 GiB), con un messaggio che dice cosa fare; la cache viene svuotata
  se supera `GLIFI_VERIFY_MAX_CACHE_GB` (12 GiB), così non cresce senza fine.
- **Politica in un punto solo**: `Scripts/build-cache.sh`, usata dai quattro script, invece di
  quattro copie che divergono.
- **Bonifica dei residui**: un processo ucciso non esegue il `trap`, quindi la sua directory
  temporanea resterebbe per sempre. All'avvio gli script rimuovono le directory del namespace
  `Glifi` più vecchie di un'ora nella cartella temporanea dell'utente, senza toccare
  un'esecuzione in corso. Vale anche per i test: ne erano rimaste 48 di esecuzioni precedenti.
- `make cache-size` e `make clean-cache` rendono la cache ispezionabile e rimovibile.

## Procedura e risultato

Misure sulla stessa macchina, con campionamento ogni 5 secondi:

| Grandezza | Prima | Dopo, a freddo | Dopo, a caldo |
| --- | --- | --- | --- |
| Picco su disco | ~37 GiB | 1,65 GiB | 1,77 GiB |
| Durata di `make verify` | ~13 min, sempre a freddo | 773 s | 303 s con cache conservata |
| Artefatti temporanei | — | 1 MiB | 1 MiB |
| Esito | — | verde | verde |

Con il comportamento predefinito, dopo un'esecuzione verde da 539 s non resta nulla: né cache né
directory temporanee. Durante la verifica sono stati trovati 48 residui di esecuzioni
precedenti dei test, per 1,4 MiB: sono stati rimossi e la bonifica automatica ne impedisce
l'accumulo.

La seconda esecuzione dura meno della metà della prima quando la cache viene conservata: il riuso
funziona. Con il comportamento predefinito la cache viene rimossa al termine e il disco torna
esattamente allo stato precedente, quindi ogni esecuzione riparte a freddo: è il prezzo scelto per
non lasciare nulla dietro di sé.

## Limiti

Il tetto di 12 GiB è una scelta prudente, non una misura: serve a impedire la crescita illimitata,
non a ottimizzare il riuso. Le misure vengono da una sola macchina e da un solo stato del
repository; su una macchina con più core o SSD diverso i tempi cambiano. La cache è condivisa fra
esecuzioni concorrenti del gate, che non è progettato per girare due volte in parallelo sulla
stessa macchina.

## Esito

**Superato localmente: il picco su disco scende da circa 37 GiB a 1,8 GiB, al termine non resta
nulla, e il gate rifiuta di partire quando lo spazio non basta.**
