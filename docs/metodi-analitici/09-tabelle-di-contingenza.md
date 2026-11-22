<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Tabelle e matrici di contingenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-09 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Definizione

Una tabella `O ∈ ℕ₀^(I×J)` incrocia due variabili categoriali semanticamente
definite. Ogni osservazione contribuisce secondo una politica esplicita: singola
appartenenza, appartenenza multipla ponderata o esclusione. Le categorie, il loro
ordine, i mancanti, i pesi e l'universo delle osservazioni **DEVONO** essere
persistiti.

Con totale `n>0`, margini di riga `r_i`, margini di colonna `c_j`:

```text
E_ij = r_i c_j / n
residuo_ij = O_ij - E_ij
residuo Pearson_ij = (O_ij - E_ij) / sqrt(E_ij)
residuo standardizzato_ij =
  (O_ij - E_ij) / sqrt[E_ij(1-r_i/n)(1-c_j/n)]
```

Le ultime due formule richiedono denominatore positivo. Righe o colonne con margine
zero sono conservate nell'artefatto originario ma devono essere escluse, con elenco
esplicito, dall'inferenza e dalla Correspondence Analysis.

## Indipendenza ed effect size

`PearsonChiSquareRxC-v1` usa `χ²=Σ(O-E)²/E`, gradi di libertà
`(I-1)(J-1)` dopo le esclusioni. Attese troppo piccole producono una diagnostica e
possono richiedere aggregazione motivata, test esatto o permutation test
pre-specificato.

Per `I,J≥2`, `CramersV-v1` è:

```text
V = sqrt[χ² / (n × min(I-1, J-1))]
```

È un'effect size non direzionale. Il test esatto di Fisher della baseline si applica
solo a 2×2; un'estensione RxC **DEVE** specificare algoritmo esatto o Monte Carlo,
seed, errore e numero di campioni.

## Provenienza e impieghi

Le dimensioni possono essere termini, corpus, categorie, autori, periodi o campi
utente tipizzati. Ogni cella **DEVE** poter risolvere le unità contribuenti oppure una
query esatta sulla versione del corpus. Una tabella può alimentare test, residui,
keyness e Correspondence Analysis come nodi distinti del DAG.

## Verifica

- margini e totale ricostruibili dalle celle;
- `ΣO=ΣE=n` entro tolleranza;
- somma dei contributi Pearson uguale a `χ²`;
- simmetria dei risultati scalari rispetto alla trasposizione;
- confronto 2×2 e RxC con dataset di riferimento;
- errori espliciti per totale o margini degeneri.
