<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-330 — Limiti correnti sul corpus riutilizzato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-330 |
| Tipo | Regressione del contratto di cache e ammissione |
| Versione | 1.0.0 |
| Stato | RED riprodotto, regressioni GREEN e gate macOS integrato superato |
| Responsabile | Codex con verifica serializzata dall'integratore |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di correttezza semantica |
| Riferimenti | GS-DOR-330; GS-ANA-001; GS-API-003; CMP-330 |

## Difetto e riproduzione

Il profilo corpus persistito usa un descriptor scientifico indipendente dai
limiti operativi. I rami di riuso verificavano fonti e byte ma non i limiti
correnti di vocabolario, n-grammi distinti e celle non nulle. Il successo di
una richiesta dipendeva quindi dalla presenza di un precedente Artifact.

La fixture sintetica contiene `casa casa mare` e `casa città`: tre type, tre
bigrammi distinti e quattro celle non nulle. Per ciascuna cardinalità il test
richiede prima un limite inferiore di uno a cache fredda, poi calcola con
limiti sufficienti e ripete la richiesta restrittiva sulla cache calda.
L'integratore ha eseguito i nuovi test prima della modifica produttiva:

- i sei casi a cache fredda hanno prodotto la failure prevista;
- i sei replay a cache calda hanno erroneamente restituito successo,
  confermando il RED nei percorsi diretto e di gruppo per analisi derivate;
- riuso con limiti esatti/più ampi dopo riapertura e vocabolario vuoto con
  limiti zero non hanno mostrato regressioni nella baseline.

I test sono quattro definizioni con otto esecuzioni parametrizzate nella
suite `GlifiCorpusCacheBudgetTests`. Il comando mirato è:

```sh
swift test --package-path Packages/GlifiCore \
  --scratch-path "$HOME/Library/Caches/GlifiStudio/verify-macos-315-root/SwiftPM" \
  --filter GlifiCorpusCacheBudgetTests
```

Il primo RED è stato eseguito dall'integratore in un comando Core combinato;
le altre failure di quel comando appartengono alle regressioni separate
GS-VER-327/328 e non sono attribuite a questa correzione.
Il [rapporto strutturato](allegati/GS-VER-330-verifica.json) conserva conteggi,
hash del log e stato delle verifiche.

## Correzione e invarianti

Il validatore privato del profilo riceve ora le opzioni correnti nei quattro
punti di ammissione del motore, prima del ritorno di un Artifact riutilizzato
e dopo il calcolo nuovo. Confronta le cardinalità complete di termini,
n-grammi e celle con gli stessi limiti del calcolo. Mantiene l'ordine
vocabolario, n-grammi, matrice e i codici esistenti:

| Limite | Failure |
| --- | --- |
| vocabolario | `analysis.vocabulary-limit-exceeded` |
| n-grammi distinti | `analysis.ngram-limit-exceeded` |
| celle non nulle | `analysis.matrix-limit-exceeded` |

La categoria resta `insufficientResources`, il retry `afterConditionsChange`
e lo stato conservato `lastCommittedGeneration`. Il rifiuto non scrive una
nuova generazione. Il test controlla anche che non avvenga una nuova
tokenizzazione sui replay e che i limiti sufficienti conservino risultati,
ArtifactID, AnalysisNodeID e snapshot dopo la riapertura.

I limiti non entrano nel descriptor; formule, payload, identità scientifica,
API pubbliche e trasporto restano invariati. La correzione privata è stata
revisionata indipendentemente da un secondo agente senza blocker rilevati.

## Stato della verifica e limiti

Il secondo comando SwiftPM completo dell'integratore ha eseguito le otto
regressioni di questa suite con successo: nessuna issue, limiti rispettati a
cache fredda e calda, riuso alle soglie esatte/più ampie e vocabolario vuoto
con limiti zero. Nel comando complessivo Core, 779 definizioni, rimangono due
issue separate su zero con segno di GS-VER-328; nel target Kit sono presenti
i RED intenzionali e separati di GS-VER-331. Il successo di questa suite non
viene presentato come successo dell'intero comando. Il rapporto conserva
anche il digest del log `core-stage2.log`.

Nel terzo comando completo la suite è nuovamente GREEN e tutte le 781
definizioni Core passano. I soli due RED di quel comando appartengono
all'admission dell'export di GS-VER-331 nel target Kit.

Il comando finale mirato `core-green.log` passa con 28 definizioni Core e
17 Kit, zero issue. Le otto esecuzioni della suite corpus restano GREEN;
lo stesso comando copre cancellazione dell'export e correzioni algoritmiche
correlate. Il relativo digest e il fingerprint dei 590 input runtime
congelati dall'integratore sono conservati nel rapporto strutturato.

Il gate composito `make verify` macOS è superato nello snapshot isolato:
exit 0 in 589,88 secondi, 782 definizioni Core, 169 Kit, 135 native con
425 esecuzioni e zero failure. Comprende inoltre otto feature BDD, 122
scenari e 697 passaggi, due PDF/A conformi e 132 operazioni Kit/CLI con
264 confronti completi e sei rifiuti indipendenti dei metadati di export.
Il controllo licenze verifica 25 materiali e 21 digest revisionati.

Il fingerprint composito dei 608 input è
`36b05ea14bbeafe91150b84edb8ab74a67a240e75b9430f553797f262714d259`,
invariato dopo il gate; resta distinto dal fingerprint storico del GREEN
mirato. Il rapporto registra log SHA-256
`dccda4c30b675a31188afc0dce651a4aaa3d5c56f2a233bb659f9f6da2e6a28a`
e riepilogo composito separato. Le prove riguardano il profilo automatico
macOS; non attestano iPadOS, firma o verifica manuale della GUI.

Le tre verifiche di cardinalità hanno costo costante sul payload già
decodificato. Non anticipano la verifica al momento precedente alla lettura
del payload, che mantiene il limite Artifact esistente di 64 MiB. Non
introducono benchmark, una nuova strategia di cache, autenticazione di dati
ostili o conformità GUI/iPadOS. Le directory temporanee della fixture vengono
rimosse dai test; la cache di compilazione condivisa resta una toolchain di
verifica attiva.

Le prove specifiche usano l'analisi corpus diretta e il gruppo condiviso
dell'associazione. Gli altri consumatori riusano lo stesso validatore; non
si dichiara una copertura esaustiva di ogni combinazione di gruppi e limiti.
