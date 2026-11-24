<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-094 — Collocazioni a finestra di token persistite (GlifiCore/Kit/CLI)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-094 |
| Tipo | Evidenza di verifica inferenziale, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-008, TV-029, TV-032, TV-054, TV-056 e TV-073 |

## Ambito

Implementa il contesto «finestra» di GS-MET-001-11, finora disponibile solo come
contesto «documento» (GS-VER-092):

- `GlifiWindowCooccurrenceOptions`: ampiezza sinistra e destra (0–20, almeno un token),
  attraversamento di frase esplicito, autocoppie esplicite, soglia sul conteggio congiunto e
  limite di coppie; parametri non validi sono rifiutati con `window-cooccurrence.invalid-options`
  e mai corretti in silenzio. Finestra simmetrica (`left == right`) e asimmetrica sono
  semanticamente distinte;
- `GlifiWindowCollocationAnalyzer` (`corpus-window-collocation-v1`): per ogni token nodo si
  contano le coppie ordinate nodo→collocato nella finestra, dentro il documento e, se non
  richiesto diversamente, dentro la frase; token normalizzati come nel profilo corpus
  (NFC + minuscolo `it_IT`, solo token lessicali). L'universo `M` è il numero di coppie
  ordinate (`ordered-node-collocate-pairs-v1`); per ogni coppia `a` = coppie nodo→collocato,
  `b` = coppie con lo stesso nodo e altro collocato, `c` = altro nodo e stesso collocato,
  `d` = resto; misure `PMI-v1`, `NPMI-v1`, `Dice-v1`, `Jaccard-v1`, `t-score-v1`, `logDice-v1`
  di GS-VER-089. Una finestra simmetrica conta ogni coppia in entrambi gli ordini e riporta
  una sola riga per coppia non ordinata;
- `GlifiEngine.analyzeWindowCollocations`, `GlifiStudioService.analyzeWindowCollocations`
  e comando CLI `window-collocations --sources … [--left --right --cross-sentences
  --self-pairs --min-joint --max-pairs]` con riuso get-or-store dell'Artifact
  (`studio.glifi.artifact.window-collocation.v1`) e dipendenza dal profilo corpus; le fonti
  sono rilette solo se l'Artifact non è già nella generazione.

## Procedura

1. verificare l'analizzatore su «alfa beta alfa gamma» con finestra ±1: `M=6`, totali di
   riga alfa=3, beta=2, gamma=1; per (alfa, beta) `a=2, b=1, c=0, d=3`, Dice `4/5`, Jaccard
   `2/3`, PMI `ln 2`, t-score `1/√2`, logDice `14+log2(4/5)`; per (alfa, gamma) `a=1, b=2`,
   Dice `1/2` (test `symmetricWindowMatchesHandDerivedTables`);
2. verificare la direzione con la finestra «solo a destra» (`M=3`, coppie
   alfa→beta, beta→alfa, alfa→gamma, tabella di beta→alfa `a=1, b=0, c=0, d=2`);
3. verificare confini di frase (`M=4` senza attraversamento, `M=6` con), autocoppie
   («alfa alfa»: nessuna coppia senza, `a=2` con), finestra vuota rifiutata, mancato
   attraversamento dei documenti e determinismo rispetto all'ordine delle fonti;
4. verificare via GlifiKit (due fonti, `M=6`, tabella di (alfa, beta) `2/0/1/3`) persistenza
   e riuso dello stesso `artifactID`/`generation`;
5. estendere `Scripts/verify.sh` con due invocazioni CLI (riuso senza avanzare la generazione)
   e le asserzioni `a+b+c+d = M` su ogni coppia; il gate completo termina con exit 0 con
   `generation=19` e `artifactCount=14`.

## Limiti

Il contesto è una finestra di token lessicali: non c'è pesatura per distanza, né misura di
distanza media per coppia, né lista delle posizioni per cella (lineage per cella non
persistito); i confini di frase sono quelli del tokenizzatore italiano di riferimento. Le
soglie sono applicate dopo la misura; la matrice non è ancora fornita come grafo (la rete
resta quella a livello di documento, GS-VER-092). Nessuna interfaccia macOS/iPadOS né
integrazione nel planner.

## Esito

**Superato localmente per `corpus-window-collocation-v1` persistito e riusabile con parità
GlifiCore/Kit/CLI.** Non promuove RF-021 e RF-034 a feature complete.
