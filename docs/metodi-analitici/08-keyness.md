<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Keyness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-08 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.3.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-19 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Popolazioni e tabella

La keyness confronta un corpus/gruppo target `A` con un riferimento `B`. Per ogni
termine costruisce:

| | termine | altri token | totale |
| --- | ---: | ---: | ---: |
| target | `a` | `N_A-a` | `N_A` |
| riferimento | `c` | `N_B-c` | `N_B` |

Target, riferimento, eventuale sovrapposizione, unità di conteggio, sampling,
preprocessing e vocabolario **DEVONO** essere espliciti. Il confronto token-based
non è intercambiabile con presenza/assenza per documento.

## Significatività

Le frequenze attese sono `E_ij=(totale riga_i × totale colonna_j)/N`.

- `PearsonChiSquare-v1`: `χ²=Σ(O-E)²/E`, senza correzione di Yates; richiede tutte
  le attese positive e segnala l'inadeguatezza dell'approssimazione quando le soglie
  diagnostiche approvate non sono soddisfatte.
- `GTest-v1`: `G²=2Σ O ln(O/E)`, con il contributo di `O=0` definito come zero;
  richiede `E>0`.
- `FisherExactTwoSided-v1`: per una tabella 2×2, condiziona sui margini e somma le
  probabilità ipergeometriche di tutte le tabelle con probabilità minore o uguale a
  quella osservata, entro la tolleranza numerica dichiarata.

Chi-quadrato e G-test sono approssimazioni asintotiche. La selezione di Fisher per
campioni piccoli o celle rare **DEVE** seguire una regola persistita; non può essere
decisa a posteriori osservando il p-value.

## Grandezza e direzione dell'effetto

```text
odds ratio = (a × d) / (b × c)
log ratio  = log2[(a/N_A) / (c/N_B)]
```

Le formule grezze sono definite soltanto con denominatori e tassi positivi.
`OddsRatio-HA-v1` e `LogRatio-HA-v1` applicano, se richiesto, la correzione
Haldane–Anscombe aggiungendo `0,5` a tutte le quattro celle; per il log ratio i
denominatori diventano `N_A+1` e `N_B+1`. Correzione, base logaritmica e intervallo
di confidenza **DEVONO** essere espliciti.

Il segno del log ratio determina la direzione; χ² e G² non hanno segno. Un risultato
**DEVE** conservare almeno conteggi, tassi, effect size, statistica, gradi di libertà,
p-value grezzo, metodo di correzione multipla e p/q-value corretto. Significatività
ed effect size **NON DEVONO** essere fuse in un unico giudizio.

## Confronti multipli

La famiglia comprende tutti i termini sottoposti allo stesso intento inferenziale,
definito prima del calcolo. Bonferroni o Benjamini–Hochberg sono applicati secondo
[GS-MET-001-21](21-fondazione-statistica.md). Filtrare i termini dopo avere visto i
p-value **NON DEVE** ridurre retroattivamente la famiglia.

## Casi limite e verifica

Corpus vuoti, margini nulli e identità sovrapposte non dichiarate sono errori.
Termini assenti in entrambi i gruppi non entrano nella famiglia. Le fixture includono
zero in ciascuna cella, margini sbilanciati, piccoli campioni e confronto con
implementazioni indipendenti. L'ordinamento finale usa una chiave dichiarata e
tie-break stabile su `TermID`.

## Profilo implementato `keyness-gtest-fisher-ha-ci-bh-v2`

Sostituisce `keyness-gtest-ha-bh-v1` (descritto sotto, di cui conserva popolazioni, G-test,
effect size, BH, limiti e ordinamento) e completa i requisiti di questa specifica:

- `FisherSelection-min-expected-5-v1`: per ogni termine `FisherExactTwoSided-v1` sostituisce il
  G-test se almeno una frequenza attesa della sua tabella 2×2 è minore di 5 (Cochran, 1954). La
  regola dipende solo dai margini ed è persistita prima del calcolo; il p del G-test resta
  registrato per ogni termine (`gTestPValue`) e il p selezionato entra nella famiglia BH;
- `FisherExactTwoSided-v1` somma le probabilità delle tabelle con probabilità non superiore a
  quella osservata con tolleranza relativa `1e-7`, come `fisher.test` di R;
- `LogRatioCI-Katz-HA-v1`: intervallo di Wald su `ln` del rapporto fra tassi corretti,
  `SE = √(1/a′ − 1/N_A′ + 1/c′ − 1/N_B′)` con `a′=a+0,5`, `c′=c+0,5`, `N′=N+1`, riportato in base 2;
- `OddsRatioCI-Woolf-HA-v1`: intervallo di Wald su `ln OR` con le quattro celle corrette di `0,5`;
- livello di confidenza nelle opzioni, default `0,95`, parte del digest del confronto.

Il payload persistito è `studio.glifi.artifact.keyness.v2` (GS-VER-118).

## Profilo precedente `keyness-gtest-ha-bh-v1`

La prima variante eseguibile confronta due insiemi espliciti, non vuoti e
disgiunti di `SourceRevisionID` appartenenti alla stessa generazione verificata.
Usa conteggi token-based normalizzati da `it-token-v1` e conserva per l'intera
famiglia:

- frequenze e tassi in target e riferimento;
- `GTest-v1` con un grado di libertà e
  `ChiSquareSurvival-df1-erfc-v1` per il p-value;
- `OddsRatio-HA-v1` e `LogRatio-HA-v1-base2` con direzione separata;
- `BenjaminiHochberg-v1` su tutti i termini osservati in almeno un gruppo;
- minimo conteggio atteso e caveat diagnostico sotto la soglia configurata;
- popolazioni ordinate canonicamente, digest dei profili, digest del confronto,
  policy numerica D1 e tolleranza assoluta `1e-12`.

La famiglia è limitata prima della materializzazione a 100.000 ipotesi per
default. Gruppi sovrapposti o duplicati, revisioni assenti, popolazioni senza
token, margini degeneri e soglie non finite falliscono con codici tipizzati senza
modificare il progetto. L'ordinamento è per valore assoluto del log ratio
decrescente e termine crescente come tie-break.

Il profilo è bounded e viene persistito con `AnalysisDescriptor`, i due profili di
popolazione come dipendenze e un Artifact schema-versioned. Non sostituisce ancora
intervalli di confidenza, selezione pre-registrata di Fisher né review scientifica
esterna.

## Riferimento scientifico

- Dunning, [Accurate Methods for the Statistics of Surprise and Coincidence](https://aclanthology.org/J93-1003/), 1993.
