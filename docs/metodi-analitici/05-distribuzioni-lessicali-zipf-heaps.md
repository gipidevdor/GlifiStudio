<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Distribuzioni lessicali, Zipf e Heaps

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-05 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-22 |
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

Variante persistita sull’insieme di documenti selezionato (GS-VER-220):

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

## Primitive headless, scalabilità e verifica

Il contratto headless seguente resta distinto dalla variante persistita descritta
sopra: l’ordine dei documenti e i checkpoint sono espliciti; un fit fuori dominio
è rifiutato, mentre `corpus-lexical-laws-v1` lo conserva con l’indicatore di
appartenenza al dominio. Le rispettive superfici e identità restano separate.

`GlifiLexicalDistributionAnalysis` implementa le osservazioni
`LexicalDistribution-ordered-v1` e i fitting `ZipfLogOLS-v1` e `HeapsLogOLS-v1`.
L'input è una sequenza ordinata di documenti con identità univoca e chiavi lessicali
già preprocessate; l'identificatore di preprocessing è obbligatorio. Il risultato
serializzabile conserva ordine, lunghezze dei documenti, ranghi, spectrum e tutti
i checkpoint richiesti. La parità di conteggio non implica parità della crescita
quando cambia l'ordine dei documenti.

I checkpoint sono positivi, strettamente crescenti e interni al numero di token.
Il fitting Heaps rifiuta curve impossibili (type decrescenti, più type che token,
o incrementi dei type superiori ai nuovi token). Il fitting Zipf richiede un
intervallo inclusivo esplicito di ranghi. Entrambi richiedono almeno due punti;
una stima fuori dal dominio del modello produce una failure di dati insufficienti,
senza alterare le osservazioni. RMSE usa denominatore `n`; i residui sono
`log(osservato) - log(previsto)`. Il risultato resta diagnostico e non contiene
estrapolazioni o intervalli d'incertezza impliciti.
Numericamente OLS usa logaritmi dei rapporti rispetto al primo punto e ricostruisce
l'intercetta nella scala originale: è la stessa regressione con una traslazione
degli assi logaritmici, senza clipping di stime al bordo `β=1`.

Il profilo in memoria ammette al massimo 100.000 documenti, 1.000.000 token e
checkpoint, e 64 MiB aggregati per identità, chiavi e identificatore di
preprocessing. I conteggi e la crescita sono incrementali; solo il riepilogo per
type viene ordinato alla fine. GlifiKit esegue il calcolo fuori dall'actor chiamante.
Queste API non estendono il planner o il formato persistente. Le varianti di
Zipf–Mandelbrot e crescita media su permutazioni richiedono ancora contratti propri.

I test di GS-VER-168 confrontano OLS con `stats::lm` di R, verificano spectrum,
tie, ordine, dominio, cancellazione e parità della facciata.

La struttura ottimizzata valida ogni chiave e aggiorna conteggi e crescita nello
stesso passaggio sui token, nell'ordine dichiarato, senza pubblicare un risultato
prima del completamento di tutte le verifiche. Il riepilogo per type e lo spectrum
mantengono gli ordinamenti canonici. La capacità iniziale della crescita è
riservata entro un limite contenuto; il fitting riserva l'output noto e riutilizza
il logaritmo invariato dell'origine. Formule OLS, ordine delle riduzioni, supporto,
checkpoint, budget, failure e cancellazione restano invariati. GS-VER-169 raccoglie
le misure riproducibili e il confronto dei risultati prima e dopo l'ottimizzazione.

Frequenze, spectrum e crescita ai checkpoint **DEVONO** essere calcolabili in modo
incrementale; l'ordinamento finale può operare esternamente alla memoria. Le fixture
verificano legami `Σ_k V_k = V` e `Σ_k kV_k = N`, stabilità dei tie, curve note e
fitting su dati sintetici con parametri noti e rumore controllato.

## Riferimento scientifico

- Lü, Zhang e Zhou, [Deviation of Zipf's and Heaps' Laws in Human Languages with Limited Dictionary Sizes](https://doi.org/10.1038/srep01082), 2013.
