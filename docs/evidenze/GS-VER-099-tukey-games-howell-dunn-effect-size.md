<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-099 — Tukey HSD, Games–Howell, Dunn ed effect size per coppia verificati contro R

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-099 |
| Tipo | Evidenza di verifica inferenziale con oracolo esterno, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-054, TV-056 e TV-073 |

## Ambito

Supera i limiti dichiarati in GS-VER-095, GS-VER-096 e GS-VER-098 (nessun post-hoc specifico,
nessun effect size per coppia, nessun intervallo per d, nessuna correzione di Hedges,
correlazione solo asintotica senza intervallo), introducendo per la prima volta un **oracolo
numerico esterno**: R 4.6.0 (`stats`), presente nell'ambiente di sviluppo.

- `GlifiDistributionFunctions`: `normalQuantile` (Acklam raffinato con due passi di Halley),
  `studentizedRangeCDF` (doppio integrale `∫f_S(s)W(qs)ds` con Gauss–Legendre a 16 nodi,
  nodi calcolati per iterazione di Newton), quantile del range studentizzato per regula falsi
  di Illinois;
- `TukeyHSD-v1` (Tukey–Kramer, con intervalli simultanei), `GamesHowell-v1` (gradi di libertà
  di Welch per coppia), `Dunn-v1` (midranks pooled con correzione dei tie; Bonferroni e BH
  applicati come passo di famiglia separato);
- `HedgesG-v1` con fattore esatto `J = Γ(ν/2)/(√(ν/2)Γ((ν−1)/2))` e intervallo normale di
  d, `RankBiserial-v1`, `KruskalEpsilonSquared-v1`, `PearsonFisherZ-v1`,
  `SpearmanExactPermutation-v1` (enumerazione di tutte le `n!` permutazioni, `n ≤ 9`, senza
  tie);
- `document-metric-pairwise-posthoc-v2`: ogni coppia riporta Tukey, Games–Howell, Dunn (con
  Bonferroni e BH), Hedges' g con intervallo di d e rank-biserial; le procedure non applicabili
  all'intera famiglia sono segnalate con motivo stabile; parità GlifiKit e CLI `posthoc`.

## Procedura e risultato

1. `studentizedRangeCDF` contro `ptukey`: sette casi (k da 2 a 10, ν da 2 a 1 000) entro
   `5e-9`; oracolo esatto indipendente per k=2 (`P(Q>q) = P(|T_ν|>q/√2)`, calcolato con la
   beta incompleta di GlifiCore) entro `1e-11`, anche con ν non intero;
2. `ptukey` di R ha accuratezza limitata: la quadratura di GlifiCore resta invariata entro
   `1e-15` quadruplicando i pannelli, mentre `ptukey(3, 2, 3,448)` = 0,1122033 differisce
   dall'identità esatta `2·pt(−3/√2, 3,448)` = 0,1122024 calcolata dalla stessa R. Per questo
   Tukey è confrontato con R a `5e-9` (intervalli a `1e-7`) e Games–Howell (ν frazionari) a
   `1e-6`, mentre la precisione è garantita dall'identità esatta;
3. `normalQuantile` contro `qnorm` (0,975; 1e−10; 0,3; 0,999999) entro `1e-12`;
4. su `[3,4,5]`, `[6,7,9]`, `[1,2,2,4]`: Tukey (differenze, intervalli e p di `TukeyHSD`),
   Games–Howell (q, ν di Welch, p), Dunn (z e p; Bonferroni e BH come `p.adjust`),
   Kruskal–Wallis (`H = 7,101993865031`, p di `kruskal.test`) ed `ε² = H/9`;
5. Hedges su `[1,2,3,5]` vs `[4,5,6,8,9]`: d, J, g, SE e intervallo al 95 % entro `1e-12`;
   Fisher-z di `cor.test` (r = 0,828571, IC 0,051929–0,980685) e p esatto di Spearman
   (`42/720` con n=6, `16/120` con n=5) entro `1e-12`;
6. il nodo post-hoc v2 riporta per coppia gli stessi valori delle funzioni verificate
   (Tukey q = 4, 4, 8 con ν=3; rank-biserial −1, 1, 1); con un gruppo di un solo documento
   Tukey resta disponibile e Games–Howell è indisponibile con motivo esplicito;
7. gate completo `make verify`.

## Limiti

La quadratura del range studentizzato è dimensionata per ν ≥ 1 e k ≤ 10 (verificati); per
ν oltre 25 000 R usa ν=∞ e non è un riferimento valido. Contrasti pianificati e famiglie
definite dall'utente restano aperti; effect size e intervalli per i confronti omnibus e per
la correlazione nel nodo persistito sono l'incremento successivo.

## Esito

**Superato localmente, con oracolo esterno R, per post-hoc specifici, effect size per coppia
e intervalli, persistiti nel post-hoc v2 con parità GlifiCore/Kit/CLI.**
