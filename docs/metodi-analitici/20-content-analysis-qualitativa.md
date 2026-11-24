<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Content analysis qualitativa e affidabilità della codifica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-20 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-19 |
| Approvazione | Content analysis confermata nel perimetro; MVP da selezionare |
| Documento padre | [GS-MET-001](README.md) |

## Modello qualitativo

Glifi Studio mantiene la content analysis nel proprio dominio e **DEVE** quindi
poter rappresentare, anche se non tutto nel primo rilascio:

- codebook versionati con finalità, unità di analisi e istruzioni;
- categorie e tag eventualmente gerarchici, con identità e definizioni;
- codifiche di documenti o segmenti con autore, tempo, versione e posizione;
- annotazioni, memo e relazioni, distinguendo evidenza e interpretazione;
- ricerca delle unità codificate e navigazione bidirezionale alla fonte;
- assegnazioni indipendenti, adjudication e confronto tra codificatori.

La modifica di una categoria **NON DEVE** riscrivere silenziosamente codifiche
storiche. Versioni del codebook, fusioni, split e mapping sono artefatti tracciati.
Annotazioni manuali e automatiche devono restare distinguibili.

## Profilo implementato (ADR-0027)

Codebook, categorie, mapping, codifiche, ritrattazioni e memo sono eventi di una storia
qualitativa append-only del package (GS-VER-126). Una categoria ha un'identità stabile il cui
significato non cambia fra revisioni; fusioni, split e rinomine sono mapping espliciti e non
riscrivono le codifiche storiche, che restano legate alla revisione in vigore. Una codifica non si
modifica: si ritratta e se ne registra una nuova. Le codifiche automatiche sono distinguibili per
origine. L'accordo si calcola dalle codifiche attive di una revisione del codebook: l'unità è la
coppia (revisione di fonte, intervallo) e un'unità codificata più volte dallo stesso codificatore è
esclusa e contata (GS-VER-127).

## CohenKappaNominal-v1

Per due codificatori sulle stesse unità, una sola categoria nominale per unità e
nessun mancante non dichiarato:

```text
p_o = proporzione di accordo osservato
p_e = Σ_c p_1(c)p_2(c)
κ = (p_o-p_e)/(1-p_e)
```

È non definito se `p_e=1`. Pesi ordinali, più etichette per unità o categorie
gerarchiche richiedono varianti differenti. Il risultato conserva tabella di
accordo, numerosità e intervallo d'incertezza se calcolato.

## KrippendorffAlpha-v1

Per più codificatori e dati mancanti ammessi, sia `n_uc` il numero di volte in cui la
categoria `c` appare nell'unità `u` e `n_u=Σ_c n_uc`. Sulle sole unità con `n_u≥2`,
la matrice ordinata delle coincidenze è
`o_ck=Σ_u n_uc(n_uk-I[c=k])/(n_u-1)`. Da margini `n_c=Σ_k o_ck` e totale `n=Σ_ck o_ck`
si definisce l'attesa `e_ck=n_c n_k/(n-1)` per `c≠k` ed
`e_cc=n_c(n_c-1)/(n-1)`. Con funzione di disaccordo `δ²(c,k)`:

```text
D_o = Σ_ck o_ck δ²(c,k) / Σ_ck o_ck
D_e = Σ_ck e_ck δ²(c,k) / Σ_ck e_ck
α = 1 - D_o/D_e
```

Per dati nominali `δ²=0` se `c=k`, altrimenti `1`. Se `D_e=0`, alpha è non
definito. Livelli ordinali, intervallo o rapporto richiedono una funzione di
disaccordo versionata. Costruzione delle coincidenze, mancanti e unità escluse sono
persistiti.

## Interpretazione e verifica

Kappa e alpha misurano accordo oltre un'attesa modellata, non validità del codebook
o verità delle annotazioni. Soglie qualitative **NON DEVONO** essere universali o
implicite. Fixture comprendono accordo perfetto, caso atteso, categorie degeneri,
mancanti e tre o più codificatori; i valori sono confrontati con implementazioni
indipendenti.

## Riferimento scientifico

- Cohen, [A Coefficient of Agreement for Nominal Scales](https://doi.org/10.1177/001316446002000104), 1960.
