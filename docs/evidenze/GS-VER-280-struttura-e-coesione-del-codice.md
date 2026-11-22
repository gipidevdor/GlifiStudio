<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-280 — Struttura e coesione del codice

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-280 |
| Tipo | Evidenza di refactoring e compatibilità |
| Versione | 1.0.0 |
| Stato | Confronti API/CLI e prove mirate superati; gate completo in corso |
| Responsabile | Iniziatore del progetto, con supporto Codex |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di migliorare struttura e ingegneria del software |
| Riferimenti | [Issue #41](https://github.com/gipidevdor/GlifiStudio/issues/41); GS-DOR-280; CMP-280/281/282; GS-AD-001; GS-STD-001-10/12/29 |

## Baseline e perimetro

Baseline `38bba29`: l’audit distingue dimensione dei file e responsabilità.
I cataloghi di DTO immutabili non sono trattati come oggetti grassi. Gli interventi
riguardano la coesione bootstrap/sessione/modelli Kit, i blocchi duplicati di
staging e generazione del package e l’ownership della sessione CLI.

## Struttura prima e dopo

| Area | Prima | Dopo | Beneficio osservabile nel codice |
| --- | --- | --- | --- |
| Contratti applicativi Kit | Bootstrap, modelli e actor nello stesso file da 1.383 righe | Servizio 92, modelli 281 e sessione 1.004 righe | Ruoli separati, stato e helper privati dell’actor coesi |
| Policy ordinarie della sessione | Nove copie di admission e traduzione errori | Un helper privato, nove callsite | Un punto di manutenzione per la stessa policy; eccezioni preservate |
| Commit del package | Quattro copie di staging e costruzione digest/manifest | Una factory privata per ciascuna responsabilità | Le validazioni e i checkpoint di famiglia restano espliciti |
| Corpi dei quattro commit | 657 righe | 497 righe | Meno coordinamento ripetuto nei singoli casi; helper contati nel totale del file |
| Ownership CLI | 38 sessioni, 42 close distribuite | Owner privato con due close (successo/failure) | Chiusura anche sui percorsi prima non protetti, prima della presentazione |
| Stream execute/visualize | Due loop con la stessa validazione | Un collector privato | Identica gestione di progresso, completamento mancante/duplicato ed errore tardivo |

Il totale dei sorgenti produttivi toccati, includendo entrambi i nuovi file, passa
da 6.369 a 6.303 righe. Il file CLI cresce di sette righe: il beneficio è la
responsabilità condivisa, non un limite di righe. I cataloghi DTO, la GUI, i
workbench e i kernel numerici non sono stati suddivisi per motivi cosmetici.
Il [confronto strutturale](allegati/GS-VER-280/structure-comparison.json) conserva
conteggi e hash dei sorgenti prima/dopo.

## Compatibilità verificata

- Baseline CLI compilata e congelata prima delle patch su `38bba29`.
- `swift-api-digester -dump-sdk` su Core e Kit: interi dump API equivalenti dopo
  ordinamento dei soli nodi di dichiarazione al livello radice. Nessuna firma,
  attributo, parametro, membro o informazione di tipo è rimossa o normalizzata.
  Confronto [API](allegati/GS-VER-280/api-compatibility.json); non è certificazione
  ABI né introduzione di un gate di rilascio globale.
- Confronto completo di stdout, stderr ed exit code in 98 casi sintetici, senza
  eliminare campi: 30 fixture in entrambi i formati, ingressi malformati, status,
  letture e failure del progetto. Tutti i byte coincidono; nessun path temporaneo
  compare nell’output. [Risultati](allegati/GS-VER-280/cli-compatibility.json) e
  [programma riproducibile](allegati/GS-VER-280/compare-cli.py).
- Compilazione congiunta CLI/Core/Kit superata; 28 test Core e 26 Kit mirati
  superati, inclusi writer, interruzione, recovery, storia qualitativa, admission,
  errori, sessione e lease dell’attività.
- Revisione indipendente: API/accessi invariati; mapping distinti del bootstrap e
  della sessione preservati. I/O e checkpoint dei quattro commit restano nel
  medesimo ordine, comprese le asimmetrie qualitative e Investigation. Tutte le
  157 clausole preesistenti conservano stati e metadati; 38 aggiungono soltanto i
  due nuovi riferimenti Kit.

## Gate finale e riproduzione


Il gate completo `make verify-app-store` comprende `verify.sh` e il packaging.
Il suo esito ancora pendente non è dedotto dalle prove mirate. I risultati tardivi
del gate locale e della CI sono registrati nella pull request collegata all’issue
#41, sulla revisione finale, senza anticiparli in questo snapshot.

Per il confronto CLI compilare `GlifiCLI` della baseline e del candidato con la
stessa toolchain, congelare i due eseguibili e invocare:

```sh
python3 docs/evidenze/allegati/GS-VER-280/compare-cli.py \
  --reference /percorso/GlifiCLI-baseline --candidate /percorso/GlifiCLI-candidate \
  --workspace "$PWD" --output /percorso/cli-compatibility.json
```

Il programma genera e rimuove progetti sintetici; i risultati dei comandi di
scrittura e degli stream posseduti sono verificati dal gate completo. Il confronto
API usa `-avoid-location -avoid-tool-args` e lo stesso SDK/triple macOS dei moduli
compilati. I dump integrali restano fra le evidenze locali utili, mentre il
report versionato conserva gli hash normalizzati e l’esito dei due moduli.

Nessun benchmark di velocità, consumo energetico, audit manuale o promozione
scientifica è attestato da questo refactoring.
