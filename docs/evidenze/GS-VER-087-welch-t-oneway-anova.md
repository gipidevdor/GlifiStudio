<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-087 — Welch t-test e ANOVA one-way con p-value asintotico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-087 |
| Tipo | Evidenza di verifica inferenziale e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza osservata parziale di TV-008 e TV-031 |

## Ambito

- `GlifiStatisticalFoundation.welchTTest`: `WelchT-v1` su due campioni
  indipendenti con `n₁,n₂≥2` e varianze finite positive, statistica e gradi di
  libertà Welch–Satterthwaite secondo le formule dichiarate;
- `GlifiStatisticalFoundation.oneWayANOVA`: `OneWayANOVA-v1` su `k≥2` gruppi
  indipendenti non vuoti, con `F`, gradi di libertà e diagnostica di varianza
  interna nulla;
- `tDistributionPValue`/`fDistributionUpperTailPValue`: p-value asintotico
  tramite funzione beta incompleta regolarizzata (frazione continua di Lentz,
  Numerical Recipes), condivisa con `logΓ` già introdotta per
  `GlifiContingencyAnalysis`;
- alternativa dichiarata esplicitamente (`twoSided`/`less`/`greater`)
  anziché assunta implicitamente.

## Procedura

1. verificare il p-value t a un grado di libertà contro l'identità chiusa
   della distribuzione di Cauchy standard, `P(|T|>t)=1-(2/π)arctan(t)`,
   indipendente dalla funzione beta incompleta in prova, su due valori con
   arcotangente esatta (`t=1` → `p=1/2`; `t=√3` → `p=1/3`);
2. verificare la relazione `F(1,df₂)=t²(df₂)`, confrontando
   `fDistributionUpperTailPValue` con `tDistributionPValue` sullo stesso caso
   attraverso un'identità matematica nota, non lo stesso percorso di codice;
3. verificare Welch t su due campioni con statistica e gradi di libertà
   ricalcolati indipendentemente dalla formula dichiarata (non dal codice in
   prova) a partire da media e varianza campionaria dei due gruppi;
4. verificare `OneWayANOVA-v1` su tre gruppi a margini interi tali che
   `F=12` e, con `df₁=2, df₂=6`, il p-value abbia forma chiusa nota
   `I_{0,2}(3,1)=0,2³=0,008` (poiché `B(a,1)=1/a`);
5. verificare failure tipizzate per campione/gruppo insufficiente, gruppo
   vuoto, varianza campionaria o interna nulla.

## Risultato osservato

- entrambi i punti di forma chiusa Cauchy coincidono entro `1e-9`;
- l'identità `F(1,df₂)=t²(df₂)` coincide entro `1e-9` fra le due funzioni,
  incrociando i due utilizzi della beta incompleta;
- Welch t coincide entro `1e-9` con la statistica e i gradi di libertà
  ricalcolati indipendentemente;
- l'ANOVA sul caso a forma chiusa produce `F=12`, `df₁=2`, `df₂=6` e
  `p=0,008` entro `1e-9`;
- input fuori dominio sono rifiutati con `GlifiFailure` tipizzata senza
  produrre un risultato parziale.

## Limiti

Questa evidenza copre soltanto Welch t e ANOVA one-way bounded in memoria, con
p-value asintotico (non esatto, permutation o bootstrap). Non prova le altre
famiglie elencate da GS-MET-001-21 (Pearson/Spearman, Mann–Whitney/Wilcoxon,
Kruskal–Wallis, one-sample/paired t, intervalli di confidenza, bootstrap,
permutation test, Cohen's d, Bonferroni), né persistenza, wiring Kit/CLI o
corpus/dataset gold. La fondazione concettuale `GlifiMath` più ampia resta un
obiettivo non ancora un target Swift obbligatorio.

## Esito

**Superato localmente per `WelchT-v1` e `OneWayANOVA-v1` con p-value
asintotico in GlifiCore.** Non promuove RF-045 a feature complete né sostituisce
la review scientifica esterna.
