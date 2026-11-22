<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-089 — Misure di collocazione su tabella 2×2 esplicita

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-089 |
| Tipo | Evidenza di verifica inferenziale e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-029 e TV-032 |

## Ambito

- `GlifiCooccurrenceCounts`: tabella 2×2 esplicita `(a,b,c,d)` su un universo
  `M=a+b+c+d` di opportunità, validata per non negatività;
- `GlifiCollocationAnalysis.measures`: `PMI-v1`, `NPMI-v1`, `Dice-v1`,
  `Jaccard-v1`, `t-score-v1` e `logDice-v1` secondo le precondizioni
  dichiarate da GS-MET-001-11, ciascuna esplicitamente `nil` (non definita)
  dove la propria precondizione non è soddisfatta, mai un valore fuori
  dominio o uno smoothing implicito;
- valore di continuità di `NPMI-v1` pari a `1` quando `p(x,y)=1`, distinto
  dal ramo generale della formula (che a quel punto dividerebbe per zero).

## Procedura

1. verificare un caso di associazione perfetta (`b=c=0`, `a=1`, `d=3`) dove
   la formula generale produce già `NPMI=1` (perché `p(x,y)²=p(x)p(y)`),
   insieme ai valori esatti attesi di `PMI=ln4`, `Dice=1`, `Jaccard=1`,
   `t-score=0,75` e `logDice=14`, tutti calcolati indipendentemente dalla
   formula dichiarata;
2. verificare separatamente il caso `p(x,y)=1` (`a=M`, `b=c=d=0`), che deve
   attraversare il ramo di continuità esplicito e non quello generale;
3. verificare che `p(x,y)=0` lasci PMI, NPMI, t-score e logDice non
   definiti, mentre Dice e Jaccard restano calcolabili (entrambi zero);
4. verificare che un universo interamente vuoto lasci tutte le sei misure
   non definite, senza calcolare un risultato fuori dominio;
5. verificare che conteggi negativi siano rifiutati con failure tipizzata.

## Risultato osservato

- tutti i valori del caso di associazione perfetta coincidono entro `1e-12`
  con i valori calcolati indipendentemente;
- il valore di continuità `NPMI=1` a `p(x,y)=1` è prodotto correttamente
  senza divisione per zero;
- PMI/NPMI/t-score/logDice sono `nil` quando `a=0`, mentre Dice/Jaccard
  restano definiti quando il loro proprio denominatore è positivo;
- un universo vuoto lascia tutte le misure `nil`;
- conteggi negativi sono rifiutati con `GlifiFailure` tipizzata.

## Limiti

Questa evidenza copre soltanto il calcolo bounded delle sei misure a partire
da una tabella 2×2 già costruita. Non prova l'estrazione del contesto (finestra
simmetrica/asimmetrica, distanza, attraversamento di frasi) dal testo, la
matrice di co-occorrenza con lineage per cella, le reti di co-occorrenza,
persistenza in Artifact/DAG, wiring Kit/CLI o un dataset gold per la review
scientifica esterna. G-test e chi-quadrato sulla stessa tabella restano quelli
già verificati da GS-VER-023/084.

## Esito

**Superato localmente per `PMI-v1`, `NPMI-v1`, `Dice-v1`, `Jaccard-v1`,
`t-score-v1` e `logDice-v1` in GlifiCore.** Non promuove RF-034 a feature
complete né sostituisce la review scientifica esterna.
