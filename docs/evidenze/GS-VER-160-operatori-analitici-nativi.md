<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-160 — Operatori analitici nativi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-160 |
| Tipo | Evidenza di correttezza numerica e prestazioni |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Ambito autorizzato; nessuna promozione scientifica automatica |
| Riferimenti | RF-087; GS-MET-001-23; ADR-0032; TV-087 |

## Ambito

Primitive Core e facciata Kit per le famiglie KH Coder, con test in
`GlifiKHOperatorTests.swift` e `GlifiKHOperatorFacadeTests.swift`.
La matrice di copertura e le formule sono in
[GS-MET-001-23](../metodi-analitici/23-operatori-kh-coder.md).

## Correttezza

- Oracolo R indipendente `Tests/Oracles/R/kh_operators.R`: autovalori MDS
  con segno, SOM a un'unità, posteriori multinomiali, LDA a un topic, integrazione
  esatta su tutti gli stati latenti di un corpus minimo, costo PAM.
- Oracoli aggregati: 114 righe riprodotte e collegate ai letterali dei test.
- Tolleranza dei casi esatti: 1e-12 assoluto; campionatore Gibbs contro
  integrazione esatta: 0,02 assoluto con seed fissato, burn-in e thinning dichiarati.
- Monotonia dell'obiettivo per le MDS iterative, riproducibilità dei seed,
  conservazione dei token, normalizzazione delle distribuzioni, cross-validation
  senza contaminare il vocabolario di training con il test.
- Formula SOM diretta confrontata con l'aggregazione per vincitore; codici
  mai applicati non generano archi.
- Failure tipizzate per dati non finiti/asimmetrici, limiti, variabili/annotazioni
  assenti, divisione per zero, riferimenti ciclici ed espressioni ostili.
- Evidenze di fonte UTF-8, negazioni senza anchor inventati, deduplicazione dei
  riferimenti e budget complessivo delle evidenze.

## Prestazioni riproducibili

Comando: `swift run -c release --package-path Packages/GlifiCore GlifiBenchmark --text-operators`.
Dati sintetici SplitMix64 seed 27, un warm-up e cinque campioni; mediana/minimo/massimo.
Mac16,3, macOS 27.2 (26B123), Apple Swift 6.4, stato termico nominale.
Cache di build isolate dal lavoro delle altre chat.

Prima del raffinamento, mediane osservate:

| Misura | Tempo |
| --- | --- |
| MDS classica, 200 oggetti × 64 caratteristiche | 8,83 ms |
| SOM, 1.000 × 64, griglia 25, 20 epoche | 38,37 ms |
| Naive Bayes, training + scoring, 100.000 token | 26,56 ms |
| LDA, 10.000 token, 10 topic, 30 sweep | 18,56 ms |

Kernel di distanza su dati identici e checksum identico: scalare 0,584 ms,
vDSP 0,478 ms, circa 1,22 volte più rapido nella prima misura.
Sono osservazioni locali, non soglie di rilascio né risultati su tutte le classi hardware.

Dopo il raffinamento, sullo stesso generatore e hardware:

| Misura | Mediana |
| --- | --- |
| MDS classica, 200 oggetti × 64 caratteristiche | 7,42 ms |
| SOM, 1.000 × 64, griglia 25, 20 epoche | 16,05 ms |
| Naive Bayes, training + scoring, 100.000 token | 25,18 ms |
| LDA, 10.000 token, 10 topic, 30 sweep | 18,36 ms |

SOM circa 2,39 volte più rapida; errore di quantizzazione prima
2,1879143867845285, dopo 2,187914386784528, entro la tolleranza.
LDA mantiene lo stesso checksum/perplexity; sul carico misurato il guadagno
temporale è trascurabile e non viene presentato come accelerazione dimostrata.
Una seconda esecuzione con `/usr/bin/time -l` ha osservato RSS massimo
24.690.688 byte e footprint di picco 18.252.400 byte per l'intero benchmark,
senza swap. Le misure sono locali e possono risentire di altri carichi della macchina.

## Esito finale e limiti

`make verify` completato con **exit 0** il 2026-11-01:

- 248 test GlifiCore e 27 test GlifiKit superati, inclusi 23 nuovi test degli operatori;
- 114 righe degli oracoli indipendenti rieseguite e collegate ai test;
- controlli repository, segreti, toolchain, documentazione, conformità, fixture,
  architettura, localizzazione, failure, baseline Apple e dialetto Swift superati;
- 22 checkpoint process-kill/recovery e due PDF/A-2u validati;
- smoke test e contratti CLI esistenti superati;
- test della app macOS e build macOS Release completati;
- build iPadOS Debug e Release su destinazione generica Simulator completate;
- `git diff --check` superato.

Ambiente della verifica: Apple Swift 6.4 / Xcode 27.1, Python Homebrew 3.14.9,
`ZDOTDIR` temporaneo, `TMPDIR=/tmp/glifi-kh-verify-temporaries` e cache dedicata.
Il Python di sistema era troppo vecchio per `zip(strict=True)`: è stato selezionato
l'interprete già installato, senza cambiare i controlli.

Il primo percorso isolato `/private/tmp` ha riprodotto un'incoerenza di alias nella
standardizzazione Foundation dopo NSFileCoordinator: radice standardizzata come
`/tmp` e oggetto ancora sotto `/private/tmp`. Il controllo di contenimento ha
correttamente fallito chiuso. Lo stesso commit sintetico e il gate completo
sono passati con l'alias `/tmp`; nessun controllo o codice di persistenza è stato
indebolito o modificato per questo comportamento.

Xcode ha emesso avvisi non bloccanti: CoreSimulator installato 1171.7.0 rispetto
a 1174.9.2 richiesto e dichiarazione di apertura documentale iPadOS in-place assente.
Non sono stati riavviati servizi, installati componenti o modificati file delle app
per sopprimere gli avvisi. La build generica Simulator non costituisce una prova UI
su runtime iPadOS o dispositivo.
Le capacità nuove restano candidate: le verifiche locali non sostituiscono
la review di ADR-0031. Non è stata verificata la parità di ogni impostazione di
KH Coder né l'integrazione delle nuove famiglie nel planner persistente e nella UI.

## Revisione successiva

Lo stato candidato iniziale è aggiornato per le varianti revisionate da
[GS-VER-161](GS-VER-161-revisione-scientifica-operatori.md), con manifest distinti,
correzioni versionate e review automatica esplicita. Le misure sopra restano la
registrazione storica dell'implementazione iniziale.
