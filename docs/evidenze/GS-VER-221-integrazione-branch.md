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
`chore/integrate-all-20261122`; `20980f2` registra la prima integrazione della PR #37. La pubblicazione
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

Il flusso principale ha eseguito i tre test mirati delle leggi lessicali con
Apple Swift 6.4.2 e Xcode 27.2: tutti superati, incluso il caso limite dei
checkpoint. Questo risultato copre il calcolo, i casi degeneri e il riuso
persistito verificati da quei test. Il flusso principale ha inoltre riprodotto
194 righe di oracoli selezionando Python 3.12.14 nel `PATH` e conservando il
`PATH` originale per `Rscript`. `make verify` e controlli remoti restano da
registrare sul risultato combinato in un worktree isolato.

L’identità degli alberi storici non costituisce una prova di compilazione o di
correttezza del nuovo percorso persistito. Nessun esito della CI storica viene
attribuito automaticamente a questa integrazione.
