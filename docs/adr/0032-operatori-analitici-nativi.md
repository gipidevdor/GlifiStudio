<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0032 — Operatori analitici nativi delle famiglie KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0032 |
| Versione | 1.1.0 |
| Stato | Accettato per ambito e architettura; validazione scientifica separata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Richiesta esplicita: tutte le funzioni analitiche, prestazioni native, correttezza e raffinamento misurabile |
| Riferimenti | RF-087; GS-MET-001-23; ADR-0002; ADR-0008; ADR-0031 |

## Contesto

Il motore dispone già di descrittiva, frequenze, ricerca/KWIC, associazioni,
corrispondenze, clustering, reti, LSA e NMF. Mancano alcune famiglie del catalogo
KH Coder e un percorso comune per le matrici di codici.

L'iniziatore richiede il completamento nella libreria interna senza interferire
con gli sviluppi applicativi paralleli, con massima attenzione a correttezza e
prestazioni native. La richiesta non autorizza a promuovere capacità non validate
nel percorso stabile del prodotto.

## Decisione

Aggiungere primitive bounded in GlifiCore e facciata asincrona in GlifiKit per:
MDS classica/metrica/non metrica/Sammon, SOM batch, CLARA, Naive Bayes,
LDA Gibbs, regole automatiche e operatori comuni su matrici di parole e codici.
I contratti sono fissati in [GS-MET-001-23](../metodi-analitici/23-operatori-kh-coder.md).

Usare Accelerate Apple per algebra e kernel vettoriali dopo confronto misurato.
LAPACK usa gli header correnti `ACCELERATE_NEW_LAPACK`; non si impiegano API
deprecate, dipendenze esterne o runtime R nel prodotto. La SOM aggrega statistiche
sufficienti per unità vincente; LDA mantiene reciproci aggiornati dei conteggi.
Ogni raffinamento deve preservare la formula entro la tolleranza dichiarata.

Mantenere le nuove API in memoria e in file dedicati. Il package del progetto,
il planner registrato e il percorso UI non sono modificati da questa decisione.
Le nuove capacità restano candidate fino alla promozione secondo ADR-0031.

## Conseguenze

La libreria offre le famiglie analitiche richieste con contratti nativi espliciti.
Le varianti non sono una promessa di identità bit a bit con tutti i backend e
tutte le impostazioni KH Coder. Mancanti, overflow, annotazioni assenti e budget
non sono trasformati in risultati plausibili ma errati.

La verifica usa cache isolate, oracoli R/Python di sviluppo, test Swift e benchmark
Release. La review scientifica e le prove su hardware di riferimento restano
separate dall'evidenza locale.

## Trasporto headless della prosecuzione

La prosecuzione autorizzata comprende una request Swift/JSON transitoria
GS-API-002 e il client CLI `text-analysis`. Il dispatcher resta in GlifiKit e
riusa le API native: nessun formato persistente, nuovo backend o percorso
laterale allo store. Default, seed e parametri hanno un digest canonico; lo
stato scientifico conserva l'identità per variante senza promozioni implicite.
