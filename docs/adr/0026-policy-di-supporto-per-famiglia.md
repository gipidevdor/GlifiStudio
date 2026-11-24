<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0026 — Policy di supporto per famiglia (chiusura di DA-029)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0026 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Decisore | Iniziatore del progetto, su proposta motivata dalla letteratura |
| Data proposta | 2026-09-19 |
| Data decisione | 2026-09-19 |
| Approvazione | L'iniziatore ha chiesto una tabella fondata su decisioni scientifiche |
| Integra | ADR-0025, GS-UX-006, GS-ANA-001 |
| Sostituisce | Nessuno |

## Contesto

DA-029 chiedeva quali `SupportPolicy` e soglie per famiglia consentano le categorie `strong`,
`moderate`, `weak`, `caution` e `insufficient`, vietando un confidence score universale. GS-UX-006
richiede che ogni policy dichiari soglie, razionale, dominio e casi in cui non produce categorie, e
che nessuna etichetta venga prodotta senza una policy scientificamente difendibile. Le famiglie
introdotte con ADR-0025 non hanno ancora regole interpretative.

## Decisione

1. Si adottano le policy seguenti, una per famiglia, versionate e persistite nel descriptor. Le
   soglie riprendono convenzioni pubblicate e sono **policy prodotto** revisionabili, non verità
   universali; la categoria conserva sempre le dimensioni che l'hanno determinata.
2. Dove la letteratura non offre una soglia difendibile la famiglia produce soltanto un finding
   `descriptive` o nessun finding, mai un'etichetta di forza.
3. Le policy MVP esistenti (`support-policy.descriptive-completeness-v1`,
   `support-policy.keyness-gtest-bh-v1`) restano invariate.

| Policy | Famiglia | Eleggibilità | `strong` | `moderate` | `weak` | `caution` | Riferimenti |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `support-policy.contingency-cramersv-v1` | associazione documento×termine | p Monte Carlo ≤ 0,05 | V ≥ 0,5/√d* e p ≤ 0,01 | V ≥ 0,3/√d* | V ≥ 0,1/√d* | oltre il 20 % di celle con atteso < 5 | Cohen 1988 (w: 0,1/0,3/0,5; V = w/√d*, d* = min(r,c)−1); Cochran 1954 |
| `support-policy.group-location-hedges-v1` | confronto di gruppo | p Welch ≤ 0,05 (o Mann–Whitney se Welch non è definito) | \|g\| ≥ 0,8 e p ≤ 0,01 | \|g\| ≥ 0,5 | \|g\| ≥ 0,2 | meno di 5 documenti in un gruppo | Cohen 1988 (d: 0,2/0,5/0,8); Hedges 1981 |
| `support-policy.collocation-tscore-npmi-v1` | collocazioni a finestra | a ≥ 3, t-score ≥ 2, NPMI > 0 | NPMI ≥ 0,5 e a ≥ 5 | NPMI ≥ 0,25 | altrimenti eleggibile | a < 5 | Church et al. 1991 (t ≥ 2); Evert 2008 (frequenza minima); Bouma 2009 (NPMI) |
| `support-policy.community-modularity-v1` | rete lessicale (comunità) | Q ≥ 0,3 | Q ≥ 0,5 | 0,3 ≤ Q < 0,5 | — | meno di 10 nodi | Newman e Girvan 2004 (Q oltre ~0,3 indica struttura) |
| `support-policy.clustering-silhouette-v1` | clustering | silhouette media > 0,25 | > 0,7 | > 0,5 | > 0,25 | meno di 2 unità per cluster | Rousseeuw 1987; Kaufman e Rousseeuw 1990 |
| `support-policy.correspondence-axis-v1` | Correspondence Analysis | inerzia dell'asse oltre la media (1/K) | quota ≥ 2/K | quota ≥ 1/K | — | inerzia totale < 0,05 | regola dell'inerzia media (Greenacre 2017, cap. 11; analoga a Kaiser 1960) |
| `support-policy.similarity-descriptive-v1` | similarità fra gruppi | sempre, solo `descriptive` | — | — | — | vocabolario condiviso < 10 tipi | nessuna soglia pubblicata difendibile: nessuna etichetta di forza |

## Conseguenze

- Le regole interpretative delle famiglie estese applicano esclusivamente questa tabella; un
  risultato fuori dall'eleggibilità diventa `insufficient` con motivo esplicito.
- Ogni soglia è un parametro del descriptor: modificarla crea una nuova versione di policy e un
  nuovo nodo DAG, senza riscrivere risultati precedenti.
- La validazione empirica delle soglie (simulazioni, corpus gold, studi di comprensione) resta
  un'attività di G4 e può portare a policy `-v2`.

## Riferimenti scientifici

- Cohen, J. *Statistical Power Analysis for the Behavioral Sciences*, 2ª ed., 1988.
- Cochran, W. G. [Some methods for strengthening the common χ² tests](https://doi.org/10.2307/3001616), 1954.
- Hedges, L. V. [Distribution theory for Glass's estimator of effect size](https://doi.org/10.3102/10769986006002107), 1981.
- Church, K., Gale, W., Hanks, P., Hindle, D. «Using statistics in lexical analysis», in *Lexical Acquisition*, 1991.
- Evert, S. «Corpora and collocations», in *Corpus Linguistics: An International Handbook*, 2008.
- Bouma, G. «Normalized (pointwise) mutual information in collocation extraction», GSCL, 2009.
- Newman, M. E. J., Girvan, M. [Finding and evaluating community structure in networks](https://doi.org/10.1103/PhysRevE.69.026113), 2004.
- Rousseeuw, P. J. [Silhouettes: a graphical aid to the interpretation and validation of cluster analysis](https://doi.org/10.1016/0377-0427(87)90125-7), 1987.
- Kaufman, L., Rousseeuw, P. J. *Finding Groups in Data*, 1990.
- Greenacre, M. *Correspondence Analysis in Practice*, 3ª ed., 2017.
- Kaiser, H. F. [The application of electronic computers to factor analysis](https://doi.org/10.1177/001316446002000116), 1960.
