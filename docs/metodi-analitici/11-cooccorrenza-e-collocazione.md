<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Co-occorrenza e collocazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-11 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da revisionare |
| Documento padre | [GS-MET-001](README.md) |

## Distinzioni

Una **co-occorrenza** è un'osservazione congiunta entro un contesto definito. Una
**collocazione** è una coppia co-occorrente valutata mediante una misura di
associazione. Una **rete di co-occorrenza** è un grafo derivato da osservazioni e
misure; nessuno dei tre termini è sinonimo degli altri.

## Modello di contesto

Il descrittore **DEVE** scegliere documento, segmento, frase, finestra o altra unità.
Per una finestra dichiara ampiezza a sinistra/destra, inclusione dei confini,
direzionalità, distanza, eventuale peso per distanza, attraversamento di frasi,
autocoppie e conteggio di coppie ripetute. Finestre simmetriche e asimmetriche sono
algoritmi semanticamente distinti.

Per ogni coppia si costruisce un universo di `M` opportunità e una tabella 2×2 con
`a` osservazioni congiunte, `b` solo primo evento, `c` solo secondo, `d` nessuno.
La definizione di opportunità **DEVE** essere riproducibile; frequenze token e
presenza per contesto non possono essere mescolate.

## Misure iniziali

Con probabilità empiriche coerenti nello stesso universo:

```text
PMI-v1       = ln[p(x,y)/(p(x)p(y))]               se p(x,y)>0
NPMI-v1      = PMI / -ln p(x,y)                    se 0<p(x,y)<1
Dice-v1      = 2a / (2a+b+c)                       denominatore >0
Jaccard-v1   = a / (a+b+c)                         denominatore >0
t-score-v1   = (a-E_a) / sqrt(a)                   se a>0
logDice-v1   = 14 + log2[2a/(2a+b+c)]              se a>0
```

Per `p(x,y)=0`, PMI e logDice valgono `-∞` soltanto se il formato del risultato lo
supporta esplicitamente; altrimenti sono non definiti. Per `p(x,y)=1`, NPMI è
definito per continuità come `1` soltanto quando entrambe le marginali valgono uno.
Smoothing **NON DEVE** essere implicito.

`t-score-v1` usa l'attesa di indipendenza `E_a=(a+b)(a+c)/M`. G-test e chi-quadrato
usano le formule di GS-MET-001-08 sulla stessa tabella. PMI privilegia spesso eventi
rari; t-score dipende dalla scala; Dice/Jaccard non sono test di significatività;
questi limiti **DEVONO** accompagnare l'interpretazione.

## Matrice e lineage

La matrice di co-occorrenza conserva `TermID` su entrambi gli assi, simmetria o
direzionalità, conteggio, contesto e provenienza. Ogni cella non-zero **DEVE** poter
risolvere i contesti e le posizioni che l'hanno generata. Soglie applicate prima o
dopo la misura sono trasformazioni distinte e persistite.

## Verifica

Fixture manuali verificano conteggi su confini, finestre direzionali, token ripetuti,
zeri e identità marginali. Per finestre simmetriche senza peso la matrice deve essere
simmetrica; per quelle direzionali non deve esserlo necessariamente. Misure e test
sono confrontati con calcolo indipendente.
