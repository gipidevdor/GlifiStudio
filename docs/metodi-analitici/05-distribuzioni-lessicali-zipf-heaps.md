<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Distribuzioni lessicali, Zipf e Heaps

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-05 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Osservazioni empiriche

Glifi Studio distingue tre artefatti osservati:

- distribuzione di frequenza: coppie `(TermID, f)` con ordinamento dichiarato;
- rank-frequency: coppie `(r, f_r)` ordinate per frequenza decrescente e tie-break
  stabile su `TermID`;
- frequency spectrum: coppie `(k, V_k)`, dove `V_k` è il numero di type osservati
  esattamente `k` volte.

La curva di crescita del vocabolario è la sequenza `V(n)` dei type distinti dopo i
primi `n` token. Dipende dall'ordine dei token: concatenazione dei documenti,
ordinamento e checkpoint **DEVONO** essere persistiti. Una media su permutazioni è
un artefatto differente e, se campionato, registra PRNG e seed.

## Modelli di Zipf

Il modello non traslato candidato è `f(r) = C r^(-α)` per `C > 0`, `α > 0`; la
variante Zipf–Mandelbrot è `f(r) = C(r + b)^(-α)` con dominio e vincoli di `b`
dichiarati. I conteggi osservati restano separati dai valori previsti.

`ZipfLogOLS-v1` è una procedura diagnostica completamente definita: su un intervallo
persistito di ranghi con frequenze positive pone `x=ln(r)`, `y=ln(f)`, stima
`y=β₀+β₁x` mediante minimi quadrati ordinari e restituisce `C=exp(β₀)`, `α=-β₁`.
Registra numerosità, `R²` e RMSE nello spazio logaritmico, residui e intervallo dei
ranghi. **NON DEVE** essere presentata come prova che i dati seguano una power law.
Altri estimator, troncamenti o smoothing richiedono identificatore distinto.

## Modello di Heaps

Il modello candidato è `V(n)=K n^β` per `K>0`, `0<β≤1`. `HeapsLogOLS-v1` applica
OLS a `ln V(n)=ln K+β ln n` sui checkpoint positivi esplicitamente registrati e
restituisce `K`, `β`, `R²`, RMSE logaritmico e residui. Non autorizza estrapolazioni
oltre l'intervallo osservato senza intervallo d'incertezza e avviso.

## Variante implementata: `corpus-lexical-laws-v1`

Prima variante completamente fissata, sull'insieme di documenti selezionato (GS-VER-168):

- **sequenza**: token lessicali `it-token-v1` in forma NFC minuscola, concatenati
  nell'ordine canonico delle `SourceRevisionID` (`source-revision-order-concatenation-v1`);
  `N` token e `V` type;
- **rank-frequency**: righe `(r, type, f_r)` per frequenza decrescente, tie-break per ordine
  crescente dei byte UTF-8 del type (equivalente all'ordine dei code point); sono persistite
  le prime `L` righe (`rankRowLimit`, default 1 000, ammesso 1…100 000) con indicatore di
  troncamento;
- **spectrum**: coppie `(k, V_k)` complete in ordine crescente di `k`, con
  `Σ_k V_k = V` e `Σ_k kV_k = N`;
- **vocabulary growth**: `GrowthCheckpoints-linear-v1` pone `n_i = ⌈i·N/K⌉` per
  `i = 1…K` senza duplicati (`K` default 20, ammesso 2…10 000) e registra `V(n_i)`;
  l'ultimo checkpoint coincide con `(N, V)`;
- **`ZipfLogOLS-v1`**: tutti i ranghi osservati nell'intervallo dichiarato
  `[r_min, r_max]` (default `[1, V]`), anche oltre le righe persistite;
- **`HeapsLogOLS-v1`**: tutti i checkpoint registrati;
- **OLS**: somme centrate su `x = ln(predittore)` e `y = ln(conteggio)`; il risultato
  registra numerosità, primo e ultimo predittore, `β₀`, `β₁`, coefficiente `exp(β₀)`,
  esponente (`α = -β₁` per Zipf, `β = β₁` per Heaps), `R² = 1 - SSE/SST` (assente se
  `SST = 0`), RMSE logaritmico `√(SSE/n)`, residui `y - ŷ` nell'ordine del predittore e
  l'appartenenza dell'esponente al dominio della famiglia (`α > 0`; `0 < β ≤ 1`); con meno
  di due predittori distinti il fit è assente con motivo `fit.insufficient-points`;
- ogni risultato porta l'avviso `caveat.lexical-law-fit-is-descriptive-v1`; nessuna
  estrapolazione né intervallo d'incertezza è prodotto.

Parametri fuori dominio falliscono con `laws.invalid-checkpoints`,
`laws.invalid-rank-range` (`r_min < 1` o `r_max ≤ r_min`) e `laws.invalid-row-limit`
(`invalidInput`); una selezione vuota con `laws.insufficient-sources`. Restano candidati
Zipf–Mandelbrot, estimator di massima verosimiglianza, curve per documento e
l'incertezza dei parametri.

## Separazione obbligatoria

Ogni analisi di legge empirica **DEVE** mostrare separatamente:

1. osservazioni e regole di conteggio;
2. famiglia e formula del modello;
3. procedura di fitting, supporto, esclusioni e inizializzazione;
4. bontà dell'adattamento nello spazio in cui è ottimizzata;
5. residui e incertezza applicabile;
6. avviso che l'adattamento non stabilisce una legge esatta o un meccanismo causale.

## Scalabilità e verifica

Frequenze, spectrum e crescita ai checkpoint **DEVONO** essere calcolabili in modo
incrementale; l'ordinamento finale può operare esternamente alla memoria. Le fixture
verificano legami `Σ_k V_k = V` e `Σ_k kV_k = N`, stabilità dei tie, curve note e
fitting su dati sintetici con parametri noti e rumore controllato.

## Riferimento scientifico

- Lü, Zhang e Zhou, [Deviation of Zipf's and Heaps' Laws in Human Languages with Limited Dictionary Sizes](https://doi.org/10.1038/srep01082), 2013.
