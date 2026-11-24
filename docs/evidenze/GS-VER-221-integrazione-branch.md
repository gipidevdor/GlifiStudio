<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-221 — Integrazione dei branch e allineamento di main

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-221 |
| Tipo | Evidenza di integrazione e conservazione dei contenuti |
| Versione | 1.0.0 |
| Stato | In verifica; audit dei contenuti e tre test mirati superati, gate completo da eseguire |
| Responsabile | Iniziatore del progetto, con supporto Codex |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di integrare tutto in main, eliminare gli altri branch e allineare il remoto |
| Riferimenti | GS-VER-220; GS-STD-001-08; GS-STD-001-20; RF-028; TV-029; CMP-166 |

## Perimetro

La baseline iniziale locale e remota è `f6bba3e`. I branch remoti della PR #37
(`a8e36fc`, decisioni sul preflight) e della PR #38 (`b937ca2`, leggi lessicali)
contengono lavoro da integrare. Il branch breve di integrazione è
`chore/integrate-all-20261122`; `1a1571c` registra la prima integrazione della PR #37. La pubblicazione
prevista riutilizza la PR #38 come proposta dell’insieme combinato, preservando
il suo tip nella merge head prima dell’integrazione secondo la configurazione
del repository. La verifica del risultato combinato deve precedere
l’allineamento di `main`.

## Conservazione dei branch storici già integrati

Per ogni coppia seguente sono stati confrontati i tree Git con
`git rev-parse <revisione>^{tree}` e `git diff <tip> <squash>`; gli alberi sono
identici e ogni commit squash è antenato della baseline `f6bba3e`, verificato
con `git merge-base --is-ancestor`. I commit dei branch conservano quindi
contenuto già presente nella storia canonica, sebbene i tip non siano antenati
perché le pull request erano state integrate con squash.

| Branch storico | Tip verificato | Commit squash in main | Esito |
| --- | --- | --- | --- |
| `chore/all-local-work-20261101` | `4ef4ba7` | `a86a53b` (#27) | Tree identici |
| `feat/native-kh-analytics` | `c457fd0` | `1bdfaa9` (#26) | Tree identici |
| `fix/integrate-mmr-main-20261101` | `56586e9` | `dfdcdbe` (#24) | Tree identici |
| `fix/pr14-integration-20261101` | `97527ba` | `b37c183` (#14) | Tree identici |
| `fix/pr21-integration-20261101` | `1883af9` | `a8a04dd` (#21) | Tree identici |
| `fix/pr22-integration-20261101` | `73c76a8` | `3fa454f` (#22) | Tree identici |
| `refactor/essential-native-interface` | `98d6978` | `8d24062` (#23) | Tree identici |

I branch locali `codex/analysis-algorithms-20261121` e
`codex/publish-all-20261121` risultano già a `f6bba3e`; il tip remoto del primo,
`4407e7d`, è antenato di quella revisione. L’audit autorizza la successiva
eliminazione dei sette branch già squash-integrati perché i loro contenuti
sono preservati. Il repository consente soltanto squash: non si introducono
nuovi merge in `main` per conservare i commit originali dei branch. Le prove
di identità restano registrate qui senza reintrodurre i vecchi alberi sopra
le modifiche successive.

## Risoluzione dell’integrazione delle leggi lessicali

Le primitive headless `GlifiLexicalDistributionAnalysis` e la facciata
`GlifiStudioLexicalStatistics` restano disponibili con ordine e checkpoint
espliciti. La PR #38 aggiunge il percorso persistito `corpus-lexical-laws-v1`,
`GlifiStudioSession.analyzeLexicalLaws` e il comando CLI `laws`. Le semantiche
del fit fuori dominio sono descritte separatamente in GS-MET-001-05.
Il tipo condiviso dei punti di crescita è conservato una sola volta.
Il calcolo dei checkpoint lineari evita il prodotto intermedio fra indice e
numero di token; la regressione sul limite `Int.max` è compresa nel test edge.

L’evidenza lessicale della PR #38 è rinominata da GS-VER-168 a GS-VER-220 per
eliminare la collisione con il record algoritmico già presente in `main`.
CMP-166 è libero nella matrice esistente e resta invariato. Gli esiti della
CI sulla precedente head `b3e9926` sono conservati come fatti storici e non
sono attribuiti al nuovo risultato combinato. Lo stato scientifico della
nuova capacità resta `candidate` e la clausola resta `implemented`.

## Verifica del risultato combinato

Il 2026-11-22 `make verify` è terminato con exit code 0 sul checkout pulito
`8e2c87a`. Il suo albero è identico alle revisioni pubblicate `5a714c4` e
`73fc6a1`, verificate con `git diff --exit-code`; quest’ultima incorpora il
merge remoto della PR #37. Ambiente: Xcode 27.2 (27B52), Apple Swift 6.4.2,
Python 3.12.14 già installato selezionato nel `PATH`, R disponibile per gli oracoli.
Nessuna dipendenza o impostazione di sistema è stata aggiunta.

Risultati osservati:

- 423 test Core, 59 test Kit e 55 test dell’app macOS superati, senza failure;
- 194 righe degli oracoli numerici riprodotte e collegate ai test Swift;
- parità su 15 fixture condivise e 51 controlli CLI, 22 checkpoint kill/recovery;
- controlli statici, documentali, conformità, localizzazione e formattazione superati;
- smoke e contratti CLI, incluso `laws`, superati;
- test macOS Debug e build Release macOS, build Debug e Release iPadOS senza firma.

I tre test mirati delle leggi lessicali erano già superati separatamente,
inclusa la regressione dei checkpoint con `Int.max`. La revisione indipendente
del diff integrato non ha rilevato altri blocker né modifiche KWIC concorrenti.
Le modifiche non committate delle altre sessioni restano escluse.

Il preflight completo usa la stessa sequenza di `make verify-app-store`:
`make verify`, seguito da `Scripts/check-app-store-packaging.sh` sullo stesso
contenuto applicativo. Il secondo comando analizza e archivia macOS e iPadOS,
senza ripetere il gate di base già concluso. L’esito conclusivo del packaging e
i controlli remoti della head definitiva sono registrati nella
[PR #38](https://github.com/gipidevdor/GlifiStudio/pull/38), che conserva anche
l’autorevisione e il record di integrazione. Questi esiti restano distinti dal
risultato locale sopra riportato; nessun controllo pendente vale come superato.

Limiti osservati: `veraPDF` è assente, quindi il controllo PDF/A è saltato e non
è attestato. Xcode segnala una versione CoreSimulator precedente a quella
attesa: le build generiche iPadOS sono riuscite, ma non costituiscono prove su
simulatore o dispositivo. La build iPadOS segnala inoltre la dichiarazione di
apertura dei documenti in place assente; non viene attestata assenza di warning.
Non sono coperti firma, TestFlight o audit manuali di accessibilità.

La verifica locale copre l’albero applicativo combinato. Le successive modifiche
al presente record e ai riferimenti di verifica non cambiano sorgenti, test o
configurazioni di build e sono sottoposte ai controlli statici e documentali.
Lo stato scientifico `candidate` e CMP-166 `implemented` restano invariati.
