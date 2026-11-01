<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-161 — Revisione scientifica degli operatori nativi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-161 |
| Tipo | Revisione tecnica numerica automatizzata |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, su richiesta dell'iniziatore |
| Ultima modifica | 2026-11-01 |
| Approvazione | Prosecuzione autorizzata dall'iniziatore; nessuna firma o review umana simulata |
| Riferimenti | RF-087; ADR-0031; ADR-0032; GS-MET-001-23; GS-VER-160 |

## Ambito della review

Revisione automatica interna di formule, diagnostica, invarianti e confronti indipendenti
delle primitive headless. I manifest registrano esplicitamente il responsabile automatico.
Lo stato `supported` riguarda il contratto delle singole varianti entro i limiti dichiarati.
La riproduzione scientifica esterna V6, le prove su dispositivi di riferimento, la parità
completa delle opzioni KH Coder e la promozione delle nuove famiglie nella UI restano distinte.

## Correzioni validate

1. **MDS non metrica**: lo Stress-1 usa le disparità ottenute dalla proiezione isotona
   senza riscalarle alla norma delle distanze. Le parità sono `secondary`, mantenute
   uguali, secondo la terminologia della letteratura; la precedente etichetta primary
   era errata. Il passo usa il gradiente dell'obiettivo normalizzato e il backtracking
   continua a verificare lo stesso Stress-1. Nuova variante
   `MDS-nonmetric-secondary-ties-Stress1-v2`.
2. **Range MDS**: anche autovalori, stress finale e storia riscalati devono rimanere
   finiti; coordinate finite da sole non bastano. Il budget include la diagonalizzazione
   dell'inizializzazione anche per i metodi iterativi. Tutte le varianti rifiutano
   scale il cui quadrato va in underflow/overflow: coordinate azzerate non possono
   accompagnare uno stress apparentemente perfetto. Lo Stress-1 non è definito
   per una configurazione collassata e non viene sostituito da zero.
3. **LDA**: la probabilità predittiva è `E[theta*phi]` sui campioni trattenuti,
   anziché `E[theta]*E[phi]`. Questa predizione è invariante alla permutazione dei
   topic; le medie dei singoli topic etichettati mantengono la limitazione del label
   switching. Nuova variante `LDA-collapsed-Gibbs-predictive-mean-v2`.
4. **Naive Bayes**: calcolo delle log-probabilità come differenza di logaritmi,
   evitando l'underflow del rapporto con pseudoconteggi subnormali.
5. **Codifica**: un riferimento punta al valore binario del codice applicato, anche
   quando la sua regola interna contiene un conteggio maggiore di uno. Le parole
   riservate tra virgolette doppie restano termini; le variabili quotate conservano
   il loro significato esplicito. Contratto `KH-coding-compatible-v2`.

## Oracoli e prove

- R: obiettivi MDS su coordinate fissate, SOM su quattro unità aggiornata riga per
  riga, log-probabilità al limite subnormale, integrazione esatta del posteriore LDA.
- Python: semantica dei codici binari e tavola di verità completa.
- Attese versionate in `Tests/Oracles/expected.txt`; test prodotto collegati ai
  letterali e regressioni che fallivano con l'implementazione precedente.
- Tolleranza dei confronti esatti: 1e-12 assoluto. MDS ricostruita su famiglie
  generate: 1e-10 × max(1,d). LDA Monte Carlo contro integrazione esatta: 0,02
  assoluto, seed 19, burn-in 1.000, 10.000 campioni, thinning 4.
- Per il corpus minimo LDA a due topic, perplexity predittiva esatta
  1,57518577227781. È una misura in-sample e non un risultato held-out.
- Metamorfismi su dieci seed: distanze ricostruite, logica equivalente,
  permutazione dei token e riproducibilità/costo dei medoidi.
- I sette ValidationManifest distinguono algebra MDS classica/iterativa, SOM,
  CLARA, Naive Bayes, LDA e codifica; gli identificatori non revisionati conservano
  il default `candidate` nella facciata.

## Esito finale

Gate completo `make verify` terminato con exit 0. Test Core/Kit, oracoli,
fixture, recovery, PDF/A-2u, contratti CLI, test macOS e build macOS/iPadOS
Debug/Release completati. L'host mantiene gli avvisi CoreSimulator documentati
in GS-VER-160; non è stata eseguita una prova UI su dispositivo iPadOS.
Python 3.14.9 già installato, cache dedicata, temporanei con alias /tmp e priorità
CPU ridotta. Nessun aggiornamento di dipendenze, servizi o piattaforme. Nessuna modifica ai file delle app,
ai servizi di sistema o al lavoro concorrente.

## Fonti primarie

- [Mair, Groenen e de Leeuw, smacof Version 2](https://www.jstatsoft.org/article/view/v102i10):
  definizione di Stress-1 e distinzione fra primary e secondary ties.
- [Blei, Ng e Jordan, Latent Dirichlet Allocation](https://www.jmlr.org/papers/v3/blei03a.html):
  modello probabilistico di riferimento; l'integrazione finita usata nei test è
  calcolata dall'oracolo R indipendente.

Verifica finale dopo il controllo di underflow: **284 test Core/Kit** (256 Core,
28 Kit), **120 righe di oracoli indipendenti**, sette nuovi manifest per nove
varianti. Gate completo nuovamente terminato con exit 0.
