<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-146 — Riassunto estrattivo deterministico `SentenceTFIDFMean-v1`

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-146 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | In verifica sul runner remoto |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | GS-DOR-013; richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-DOR-013; GS-MET-001-19 § Variante implementata; GS-MET-001-07; RF-042; TV-036; CMP-096 |

## Ambito

Prima realizzazione di RF-042: un riassunto estrattivo riproducibile che seleziona frasi
esistenti senza generare testo, con la variante `SentenceTFIDFMean-v1` fissata in GS-MET-001-19
(versione 1.1.0):

- primitiva `GlifiCorpusExtractiveSummaryAnalysis` in GlifiCore: frasi del tokenizzatore
  italiano come unità, token lessicali normalizzati come il profilo corpus, pesi documento-termine
  con schema GS-MET-001-07 dichiarato (default `TF-sublinear-v1`, `IDF-smooth-v1`,
  `RowNorm-none-v1`), punteggio come media dei pesi dei token, zero senza token;
- rank per punteggio decrescente con tie-break `tie-break.source-position-v1`; budget
  `Budget-sentences-v1` o `Budget-lexical-tokens-v1` in `1…10 000`; eleggibilità
  `eligibility.lexical-tokens-required-v1`; nessuna ridondanza; output in ordine della fonte con
  ogni frase candidata che conserva `SentenceID`, intervallo UTF-8, punteggio, rank e selezione;
- Artifact `corpus-extractive-summary-v1` persistito con descrittore che dichiara budget, schema
  e politiche; riuso get-or-store; `storedDerivedResult` rilegge senza ricalcolo;
- `resolveSummarySentences` risolve il testo delle frasi scelte dalle fonti della generazione
  corrente: l'Artifact conserva soltanto gli intervalli;
- `analyzeExtractiveSummary` in GlifiKit (`GlifiStudioExtractiveSummaryResult`, con testo delle
  frasi scelte) e comando `glifi summarize --sources … [--sentences n | --tokens n] [--tf --idf
  --norm]`, con envelope JSON e vista testuale.

## Procedura e risultato

1. `extractiveSummaryMatchesPython`: su due documenti con cinque frasi di token normalizzati i
   punteggi (`1.92198454876287`, `0`, `1.68982964258436`, `1.20273255405408`, `1`), i rank
   (`1 5 2 3 4`) e le selezioni con budget di 2 frasi (`0, 2`) e di 3 token (`0`) coincidono con
   l'oracolo indipendente `Tests/Oracles/Python/summary.py`, registrato in `expected.txt`;
2. `extractiveSummaryEdgeCases`: frasi duplicate con lo stesso punteggio e rank per posizione,
   frase senza token a punteggio zero ultima e mai scelta, un solo documento con IDF liscio
   positivo, budget `0`, negativo o oltre il limite rifiutati, gruppo vuoto e fonte duplicata
   rifiutati, documento senza frasi con riassunto vuoto, round-trip JSON;
3. `extractiveSummaryIsPersistedFromText`: dal testo importato (maiuscole, punteggiatura, frase
   «Sì.» con un token) quattro frasi candidate con i conteggi attesi, Artifact riusato anche con
   fonti in ordine inverso, budget diversi come nodi distinti con punteggi identici, rilettura
   dall'Artifact, testo risolto uguale alla fonte, budget non valido e gruppo vuoto rifiutati;
4. contract test CLI in `verify.sh` per `glifi summarize --sentences 2`: metodo, budget, rank
   completi e monotoni nel punteggio, selezione coerente con `consumedBudget`, frasi scelte con
   testo e intervallo validi.

Controlli statici (`make quality-static`, tassonomia e messaggi delle failure, formattazione)
superati sulla macchina di sviluppo Linux. Compilazione, test Swift e contract test CLI sono
eseguiti dal workflow `Verifica` sul runner `xcode-27`: l'esito è registrato nella sezione
seguente.

## Esecuzione remota

Da registrare al termine del workflow `Verifica` della PR.

## Limiti

- Un'unica famiglia (`SentenceTFIDFMean-v1`); centroide, TextRank, LexRank e MMR restano
  candidate, così come il budget in caratteri.
- L'oracolo è un'implementazione indipendente in Python delle formule dichiarate, non un
  pacchetto terzo; nessuna valutazione ROUGE o umana.
- Il runner remoto non dispone di Rscript: `make check-oracles` è eseguito solo dal gate locale
  (GS-VER-141).

## Esito

**In verifica: controlli statici superati; test e contract test in esecuzione sul runner remoto.**
