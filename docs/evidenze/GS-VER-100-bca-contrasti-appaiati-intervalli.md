<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-100 — BCa, contrasti pianificati, test appaiati persistiti e opzioni di richiesta

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-100 |
| Tipo | Evidenza di verifica inferenziale con oracolo esterno, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-054, TV-056 e TV-073 |

## Ambito

Supera i limiti residui di GS-VER-095…099:

- **BCa** (`BootstrapBCa-v1`): `z₀ = Φ⁻¹(#{θ*<θ̂}/B)`, accelerazione jackknife
  `a = Σ(θ̄−θ₍ᵢ₎)³/(6[Σ(θ̄−θ₍ᵢ₎)²]^{3/2})`, percentili aggiustati `Φ(z₀+(z₀+z)/(1−a(z₀+z)))` e
  quantili di tipo 7 sugli stessi replicati del percentile; rifiutato quando `z₀` non è finito;
- **opzioni di richiesta** (`GlifiGroupComparisonOptions`): livello di confidenza, `B`,
  numero di rietichettature Monte Carlo, seed e famiglia di contrasti diventano parametri
  della richiesta, persistiti nel descriptor (non più costanti);
- **contrasti pianificati** (`PlannedContrast-v1`): coefficienti a somma zero, `MSE` del modello
  a una via, t con `N−k` gradi di libertà, intervallo e Bonferroni/BH sulla famiglia dichiarata;
- `document-metric-group-comparison-v5`: intervalli BCa per gruppo, `ε²` di Kruskal–Wallis,
  Hedges' g con intervallo di d e rank-biserial (due gruppi), contrasti; opzioni esposte in
  GlifiKit e nei flag CLI `--confidence --bootstrap --permutations --seed --contrast`;
- `document-metric-correlation-v2`: intervallo Fisher-z di Pearson e p esatto di Spearman
  (n ≤ 9, senza tie) accanto al p asintotico, ciascuno con motivo stabile se non applicabile;
- **test appaiati collegati**: la sorgente naturale di osservazioni appaiate è la coppia di
  metriche misurate sullo stesso documento (ad esempio la frequenza relativa di due termini).
  La nuova operazione `comparePairedMetrics` (`document-metric-paired-comparison-v1`) applica
  `PairedT-v1` con intervallo della differenza media e `d_z`, e `WilcoxonSignedRank-v1` con
  regola dichiarata (esatto senza zeri né tie, altrimenti asintotico), con parità GlifiKit e
  comando CLI `paired`;
- `tQuantile` per bisezione sulla CDF della t.

## Procedura e risultato

1. `tQuantile` contro `qt` (0,975/7; 0,025/4; 0,9/2,5) entro `1e-10`;
2. BCa sugli stessi 20 replicati calcolato in R (`qnorm`, `pnorm`, `quantile(type=7)`): `z₀`,
   `a`, percentili aggiustati entro `1e-12`, limiti entro `1e-11`; BCa riproducibile dal seed;
   campione costante rifiutato (`statistics.bca-undefined`);
3. contrasti `(1, −½, −½)` e `(0, 1, −1)` contro `lm` di R (stima, SE, t, df 7, p) entro
   `1e-12`, Bonferroni `min(1, 2p)`, intervallo con `qt(0,975; 7)`; contrasti non a somma zero o
   di lunghezza errata rifiutati;
4. t appaiato contro `t.test(paired=TRUE)` (t, df, p, intervallo) e Wilcoxon appaiato esatto
   contro `wilcox.test` (`p = 0,125`), `d_z` = 0,978268544825189;
5. confronto di gruppo v5 su `[3,4]` vs `[3,5]`: `ε² = 1/18`, `J = 1/√π` (ν=2),
   rank-biserial −0,25; contrasto `[1,−1]`: stima −0,5, `t = −1/√5`, `p = 1−1/√11`; seed, `B` e
   livello dichiarati riportati nel risultato;
6. correlazione v2 su tre documenti: Fisher-z indisponibile (n<4) con motivo; p esatto di
   Spearman `1/3`;
7. GlifiKit: confronto appaiato «alfa» vs «beta» su quattro documenti, differenze
   `[0,0,0,½]`, `t = 1` con ν=3, `d_z = ½`, tre zeri scartati, Wilcoxon asintotico con p 1; riuso
   dell'Artifact;
8. `Scripts/verify.sh`: `group-metric --seed 7 --bootstrap 500 --contrast 1,-1` (seed e `B`
   riportati; contrasto non stimabile con un documento per gruppo), `paired` con motivi
   espliciti su differenze tutte nulle; generazione finale 20 con 15 Artifact; gate completo.

## Limiti

Il BCa copre la media. Contrasti ortogonali o polinomiali predefiniti non sono generati
automaticamente: la famiglia è quella dichiarata.

## Esito

**Superato localmente, con oracolo R, per BCa, contrasti pianificati, test appaiati
persistiti, intervalli di correlazione e opzioni di ricampionamento nella richiesta, con
parità GlifiCore/Kit/CLI.**
