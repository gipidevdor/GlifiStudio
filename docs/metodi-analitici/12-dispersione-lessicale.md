<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Dispersione lessicale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-12 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Ambito

La frequenza totale non descrive come un termine è distribuito. La partizione
analitica di `K` unità conserva ordine, dimensione `n_i`, frequenza `f_i`, totale
`N=Σn_i` e `F=Σf_i`. `K`, unità vuote e appartenenze multiple devono essere
espliciti.

## Misure

- `document frequency`: numero di documenti con `f_i>0`.
- `range`: numero di unità della partizione con `f_i>0`; coincide con document
  frequency soltanto se le unità sono documenti.
- `GriesDP-v1`: per `F>0` e `N>0`, con `o_i=f_i/F` ed `e_i=n_i/N`,
  `DP=0,5Σ|o_i-e_i|`. Zero indica distribuzione proporzionale all'opportunità;
  valori maggiori indicano concentrazione.
- `GriesDPnorm-v1`: `DP/(1-min_i e_i)` per `K≥2` e denominatore positivo. Questa
  normalizzazione e il valore grezzo **DEVONO** essere distinguibili.
- `JuillandD-equal-v1`: soltanto per `K≥2` parti con uguale `n_i` e `F>0`, pone
  `m=F/K`, `s=sqrt[Σ(f_i-m)²/K]` e `D=1-(s/m)/sqrt(K-1)`.

Juilland D **NON DEVE** essere applicato a partizioni diseguali sotto l'identificatore
`equal-v1`. DP tiene conto di opportunità diseguali, ma dipende comunque dalla
partizione scelta. Nessuna misura deve essere chiamata genericamente “dispersione”
senza variante.

## Output e interpretazione

Il risultato conserva frequenza, document frequency/range, valore, partizione,
conteggi per unità e unità contribuenti. Valori per termini assenti (`F=0`) sono non
definiti, non zero. Il confronto tra termini o corpus richiede la stessa definizione
di unità e preprocessing oppure un avviso di non comparabilità.

Un dispersion plot visualizza posizioni osservate e non sostituisce la misura.
Analisi temporali usano intervalli espliciti secondo GS-MET-001-17.

## Verifica

Le fixture comprendono distribuzione proporzionale, concentrazione in una sola
parte, parti diseguali, unità vuote e permutazione delle unità. Si verificano
`DP=0` nel caso proporzionale, intervalli attesi, invariance alla scala comune dei
conteggi e confronto con calcolo indipendente.

## Riferimento scientifico

- Gries, [Dispersions and adjusted frequencies in corpora](https://doi.org/10.1075/ijcl.13.4.02gri), 2008.
