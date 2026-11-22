<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-105 — Suite permanente di oracoli numerici R/Python, igraph e NMF

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-105 |
| Tipo | Evidenza di verifica con oracoli esterni rieseguibili |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-032, TV-034, TV-035, TV-054 e TV-073 |

## Ambito

Rende permanenti e rieseguibili gli oracoli usati da GS-VER-097…104 (finora eseguiti una sola
volta durante lo sviluppo) e supera i limiti di GS-VER-101 e GS-VER-102 sull'assenza di un
oracolo esterno per Louvain e NMF:

- `Packages/GlifiCore/Tests/Oracles/R/`: `distributions.R` (range studentizzato, quantili normale e
  t, dimostrazione dell'imprecisione di `ptukey` con ν frazionari), `posthoc.R`, `inference.R`,
  `multivariate.R` (SVD, CA, PCA, LSA, HAC, Lloyd, NMF), `networks.R` (eigen, igraph),
  `agreement.R` (Fisher, Krippendorff, Fleiss), con `common.R` condiviso; `Python/splitmix64.py`
  (sequenza di riferimento di `SplitMix64-v1`);
- `expected.txt`: 59 righe di riferimento generate dagli oracoli;
- `Scripts/check-oracles.py` (e `make check-oracles`): riesegue ogni oracolo e confronta l'output con
  `expected.txt` (tolleranza relativa `1e-12`, esadecimali esatti); richiede inoltre che ogni valore
  non intero delle chiavi non `INFO_` compaia, in modulo, come letterale nei test Swift, così test e
  oracoli non possono divergere; `--update` rigenera i riferimenti; senza `Rscript` o pacchetti il
  controllo viene saltato con messaggio esplicito, salvo `--require` (usato da `make check-oracles`);
  il controllo fa parte di `Scripts/verify.sh`;
- pacchetti R installati in `~/Library/R/glifi-oracles`: igraph 2.3.3, NMF 0.28 (con Biobase
  2.72.0 da Bioconductor), su autorizzazione esplicita.

## Nuovi confronti esterni

1. **Louvain e modularità** (igraph `make_graph("Zachary")`): la modularità della partizione delle
   due fazioni coincide con `modularity()` (0,37146614069691) entro `1e-12`; `Louvain-v1` raggiunge
   una modularità non inferiore di oltre 0,01 a `cluster_louvain` (0,418803418803419, seed 1),
   poiché le implementazioni differiscono nell'ordine di visita; la modularità ricalcolata sulla
   partizione restituita coincide con quella dichiarata;
2. **cammini pesati** (distanza `1/peso`): betweenness pari al doppio di quella non orientata di
   igraph (il grafo simmetrico conta ogni coppia nelle due direzioni), closeness armonica e
   eigenvector pesata (autovalore 5,28244821900622) come igraph; modularità pesata 0,0977777777777778;
   componenti deboli 3 e forti 4 come `components()`;
3. **NMF**: `NMF::nmf(method = "lee", rescale = FALSE, eps = 1e-12)` dagli stessi `W₀`, `H₀`
   coincide con le 100 iterazioni di Lee–Seung di GlifiCore (fattori entro `1e-9` relativo,
   obiettivo 1,65770396661443); il pacchetto con le impostazioni predefinite (`eps = 1e-9`,
   riscalatura delle colonne di W) è una variante diversa e non è usato come riferimento.

## Risultato

Suite GlifiCore di 187 test verde; `Scripts/check-oracles.py` riproduce 59 righe e le collega ai
test; gate completo `make verify`.

## Limiti

Il controllo richiede R 4.6 con igraph, NMF e Biobase nella libreria dichiarata: sui runner che ne
sono privi viene saltato. La validazione PDF/A completa con veraPDF non è stata autorizzata e resta
limitata al controllo strutturale di GS-VER-104.

## Esito

**Superato localmente: oracoli rieseguibili e collegati ai test, con confronto esterno anche per
Louvain (qualità e modularità) e NMF.**
