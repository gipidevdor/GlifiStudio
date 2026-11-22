<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-110 — Policy di supporto per famiglia (ADR-0026) e silhouette

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-110 |
| Tipo | Evidenza di verifica con oracolo esterno |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Evidenza osservata parziale di GS-UX-006 e ADR-0026 |

## Ambito

Rende eseguibile la tabella di [ADR-0026](../adr/0026-policy-di-supporto-per-famiglia.md), che
chiude DA-029:

- `GlifiSupportPolicies`: sette policy versionate (`contingency-cramersv-v1`,
  `group-location-hedges-v1`, `collocation-tscore-npmi-v1`, `community-modularity-v1`,
  `clustering-silhouette-v1`, `correspondence-axis-v1`, `similarity-descriptive-v1`) che
  restituiscono classe, dimensioni determinanti e motivi, inclusa ogni causa di `caution`; nessuno
  score universale e nessuna etichetta di forza per la similarità;
- silhouette di Rousseeuw con distanza euclidea, richiesta dalla policy del clustering.

## Procedura e risultato

1. silhouette sui profili di riferimento con il taglio di Ward a due cluster: larghezze e media
   (0,317973227525493) coincidono con `cluster::silhouette` di R entro `1e-12`; l'oracolo è in
   `multivariate.R` e collegato ai test da `Scripts/check-oracles.py`;
2. per ogni policy i valori di confine della tabella producono la classe attesa (inclusione dei
   limiti come da ADR, `insufficient` fuori eleggibilità, `caution` sulle diagnostiche); le soglie di
   Cramér's V si scalano con `√d*`;
3. suite GlifiCore e gate completo `make verify`.

## Limiti

Le policy non sono ancora applicate dall'interprete ai risultati delle capability estese: gli
output restano nel lineage senza findings finché i payload estesi non vengono passati alle regole
(incremento successivo). La validazione empirica delle soglie resta in G4.

## Esito

**Superato localmente: policy ADR-0026 eseguibili e verificate sui confini, silhouette verificata
contro R.**
