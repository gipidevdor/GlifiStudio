<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Correspondence Analysis

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-10 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Input e precondizioni

`CA-SVD-v1` riceve una matrice di frequenze non negative `N ∈ ℝ₊^(I×J)` con totale
`n>0`. Righe e colonne con massa zero sono escluse registrandone l'identità. Dopo
l'esclusione servono almeno due righe e due colonne. Pesi negativi, `NaN` e valori
non finiti sono rifiutati.

La CA ordinaria non è PCA e non è Multiple Correspondence Analysis. MCA è una
possibile estensione con identificatore, codifica indicatrice e correzioni propri.

## Costruzione matematica

```text
P = N / n
r = P 1               masse di riga
c = Pᵀ 1              masse di colonna
S = D_r^(-1/2) (P - r cᵀ) D_c^(-1/2)
S = U Σ Vᵀ            singular value decomposition
λ_k = σ_k²            inerzia principale dell'asse k
F = D_r^(-1/2) U Σ    coordinate principali di riga
G = D_c^(-1/2) V Σ    coordinate principali di colonna
```

Le coordinate standard sono `D_r^(-1/2)U` e `D_c^(-1/2)V`. Il numero massimo di
assi non nulli è `min(I-1,J-1)`. L'inerzia totale è
`Σ_k λ_k = χ²/n`, entro tolleranza.

La distanza chi-quadrato tra profili di riga `p_i` e `p_l` è
`Σ_j (p_ij-p_lj)²/c_j`; la formula duale vale per le colonne. Per l'asse `k`:

```text
contributo riga(i,k) = r_i F_ik² / λ_k
cos² riga(i,k) = F_ik² / d_i²
```

dove `d_i²` è la distanza chi-quadrato del profilo dal centroide. Qualità su un
insieme di assi è la somma dei relativi cos². Formule duali valgono per le colonne.

## Output e interpretazione

L'artefatto **DEVE** contenere masse, profili, valori singolari, inerzie assolute e
relative, coordinate con schema di scaling, contributi, cos², esclusioni,
diagnostica e lineage. Vicinanza tra due punti dello stesso tipo rappresenta
vicinanza dei profili nella metrica dichiarata; distanze dirette riga-colonna in un
biplot **NON DEVONO** essere interpretate senza la regola di scaling adottata.

Punti supplementari, se introdotti, sono proiettati senza contribuire alla
decomposizione e sono marcati come tali.

## Determinismo, backend e scalabilità

Segni degli assi sono canonicalizzati usando il primo loading non nullo
nell'ordinamento stabile; sottospazi degeneri seguono GS-MET-001-03. SVD densa,
sparsa o randomizzata sono backend distinti. Una SVD randomizzata è P1 e registra
seed, oversampling, iterazioni e residuo. L'artefatto matematico precede ogni
correspondence plot.

## Verifica

- masse positive con somma uno;
- centri ponderati delle coordinate uguali a zero;
- contributi per asse con somma uno;
- inerzia totale uguale a `χ²/n`;
- ricostruzione troncata e residuo coerenti;
- confronto con una CA indipendente e invariance alla moltiplicazione uniforme dei
  conteggi;
- navigazione da punti e contributi alle righe, colonne e celle originarie.

## Riferimento scientifico

- Greenacre, [The Geometric Interpretation of Correspondence Analysis](https://hastie.su.domains/Papers/GreenacreCA.pdf).
