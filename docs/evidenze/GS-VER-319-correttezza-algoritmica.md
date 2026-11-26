<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-319 — Correttezza e provenienza delle distribuzioni

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-319 |
| Tipo | Verifica numerica e della revisione delle cache |
| Versione | 1.0.0 |
| Stato | Controlli mirati superati; gate integrato nell'evidenza del lotto |
| Responsabile | Codex e agenti di revisione |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di perfezionamento e controllo licenze |
| Riferimenti | GS-DOR-319; CMP-319; GS-MET-001-21; GS-VER-318 |

## Difetti riprodotti e correzioni

Tre regressioni Swift producono RED con dieci issue: il quantile normale
restituisce NaN per le probabilità positive più piccole, perde precisione relativa
vicino alla mediana e il quantile t accetta gradi di libertà infiniti alla mediana.
Il controllo delle probabilità t/F individua inoltre cancellazione nel rapporto
vicino a zero e azzeramento prematuro della coda Cauchy a `t=1e200`.

Le nuove implementazioni originali valutano dal fondo le frazioni matematiche
beta/gamma, controllano la convergenza e usano log-odds e complementi stabili.
La normale viene invertita con erf/erfc e coda logaritmica. Il log-gamma usa
`lgamma_r` con segno locale; l'header `math.h` dell'SDK macOS 27.2 dichiara
`lgamma` non thread-safe e rende disponibile la variante reentrante. Tutte le
chiamate dirette preesistenti vengono instradate al wrapper reentrante.
Non sono incorporati sorgenti o coefficienti Numerical Recipes, Acklam o R.
I riferimenti DLMF sono identità matematiche, senza riproduzione di contenuti
editoriali o pretesa che il sito sia sotto BSD.

## Verifica osservata

Il primo GREEN esegue 41 test Core e uno Kit. Il successivo, con wrapper
reentrante e griglie indipendenti, esegue 45 test Core e uno Kit: 72 valori t,
392 F e 63 chi-quadrato da R, forme chiuse Cauchy/erfc/esponenziale, quantili
subnormali, simmetria, monotonia e 32 task concorrenti per 4.096 log-gamma.
Il confronto della griglia è relativo a `1e-9`, senza floor assoluto; un
riferimento zero richiede zero esatto. Le tolleranze precedenti restano intatte.

La revisione selettiva delle cache supera altri 17 test: keyness e cinque
famiglie derivate passano alla revisione algoritmo 2, i vecchi descrittori
restano leggibili e hanno nodo differente, i byte dei risultati storici
riaprono identici e la richiesta corrente riusa il nodo corrente. Tre famiglie
non coinvolte conservano esattamente descrittore e nodo della revisione 1.
La revisione indipendente dell'altro agente non individua ulteriori blocker.

Il confine della coda logaritmica a magnitudine 8 viene provato con quattro
valori R e probabilità adiacenti tramite un probe ottimizzato delle funzioni
estratte; lo stesso caso è incluso come test Swift nel gate integrato del lotto.
L'oracolo continuo aggiunge quattro righe con 537 valori, preservando tutte le
244 righe precedenti. Il checker richiede Python moderno e R: usando Python
3.12.14 e le librerie R configurate supera 248 righe e 64 casi Fraction.
Il primo tentativo con Python 3.9 di sistema falliva per l'assenza preesistente
di `statistics.linear_regression`; non è stato aggirato alcun controllo.

## Costo e limiti

Il [confronto dei kernel](allegati/GS-VER-319-misure-kernel.json), compilato con
`swiftc -O`, usa cinque ripetizioni da 20.000 chiamate per metodo, codice dei
kernel estratto e tipi errore sostitutivi, soltanto input validi. Mediane in µs:

| Kernel | Prima | Dopo |
| --- | ---: | ---: |
| Quantile normale | 0,105 | 4,440 |
| Coda t | 0,094 | 0,451 |
| Coda F | 0,096 | 0,449 |
| Coda chi-quadrato | 0,062 | 0,301 |

La riscrittura bounded ha un costo misurabile, accettato per correttezza e
provenienza indipendente; non viene dichiarata un'ottimizzazione. La macchina
eseguiva anche build concorrenti: queste misure non sono budget o metriche
app-level né una comparazione prestazionale isolata. I quantili vengono usati
per intervalli, non per ogni token. Non si certificano tutti i possibili
parametri binary64; casi fuori dalla capacità numerica bounded falliscono
con errore di dominio invece di restituire un p-value non verificato.

Il [rapporto strutturato](allegati/GS-VER-319-verifica.json) registra i passaggi
mirati. `make verify` macOS, parità Kit/CLI e packaging vengono eseguiti sulla
composizione finale dall'integratore; questa evidenza non dichiara un proprio
sanitizer, un audit manuale GUI o una verifica iPadOS.

## Fonti matematiche

- [DLMF 8.17](https://dlmf.nist.gov/8.17): simmetria e frazione beta.
- [DLMF 8.7](https://dlmf.nist.gov/8.7) e [8.9](https://dlmf.nist.gov/8.9): serie e frazione gamma.
- [DLMF 7.9](https://dlmf.nist.gov/7.9): frazione della coda normale.
- [Condizioni DLMF](https://dlmf.nist.gov/about/notices): consultazione distinta dalla riproduzione.
- [R stats — normale](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/Normal.html): oracolo esterno dei quantili.
