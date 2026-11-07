<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Riassunto estrattivo deterministico (GS-MET-001-19)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-013 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.4.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-07 |
| Approvazione | Richiesta dell'iniziatore di proseguire lo sviluppo; prima slice verificata (GS-VER-146), seconda slice verificata localmente e in CI (GS-VER-149), terza slice verificata in CI sulla head definitiva e su `main` (GS-VER-151); quarta slice verificata in CI sulla head della PR #29 e su `main` (GS-VER-164); quinta slice verificata in CI sulla head della PR #31 (GS-VER-165) |
| Riferimenti | GS-MET-001-19; GS-MET-001-07; GS-API-001 § 9; RF-042; RQ-025; RQ-027; TV-036; ADR-0013 |

## Confini e criteri di accettazione

**Ready** per l'implementazione, non per la chiusura della verifica.

| Voce | Evidenza |
| --- | --- |
| outcome e confini | Tre famiglie sullo stesso Artifact, `SentenceTFIDFMean-v1`, `CentroidCosine-v1` e `LexRankSentence-v1`, scelte con `method`, con budget in frasi, token o caratteri; ridondanza assente per default o `MMR-v1` con `λ` dichiarato, scelta con `redundancy`; nessuna generazione di testo, nessun modello linguistico |
| failure semantics | Budget non valido, `λ` fuori da `[0, 1]`, politica di ridondanza sconosciuta, gruppo vuoto o fonte duplicata: `invalidInput`/`insufficientData` con codici `summary.*` tipizzati; grafo LexRank oltre 2 000 nodi: `insufficientResources`; intervallo non risolvibile o centralità non convergente: `invariantViolation` |

- Fissare in GS-MET-001-19 unità, token inclusi, pesi, rank, budget, eleggibilità,
  ridondanza e ordine di output della variante, prima del codice.
- Primitiva pura in GlifiCore sulle frasi del tokenizzatore italiano con pesi
  GS-MET-001-07 dichiarati; Artifact `corpus-extractive-summary-v1` con descrittore completo
  e riuso get-or-store; l'Artifact conserva intervalli, non testo.
- Mirror in GlifiKit (`analyzeExtractiveSummary`, con testo risolto delle frasi scelte) e
  CLI (`glifi summarize`), con parità dei parametri e delle failure.
- Oracolo indipendente in Python, `expected.txt`, test Swift su oracolo, casi limite e
  persistenza, contract test CLI in `verify.sh`.
- Nessuna dipendenza, rete, telemetria o formato persistente alternativo.
- Seconda slice (`CentroidCosine-v1`): metodo come parametro del descrittore, vettore frase e
  centroide fissati in GS-MET-001-19 prima del codice, flag `isEligible` persistito per frase
  con decodifica dei payload precedenti, oracolo esteso con righe `CENTROID_*`, `--method` in
  CLI; nessuna migrazione.
- Terza slice (`MMR-v1`): politica di ridondanza come parametro del descrittore con `λ` e
  similarità dichiarate, fissata in GS-MET-001-19 prima del codice; `selectionOrder` persistito
  per frase scelta con decodifica dei payload precedenti; oracolo esteso con righe `MMR_*`;
  `--mmr <λ>` in CLI; nessuna migrazione.
- Quarta slice (`LexRankSentence-v1`): variante continua con autoanello, damping, tolleranza e
  limiti fissati in GS-MET-001-19 prima del codice; stessi vettori frase di
  `CentroidCosine-v1`; limiti fail-closed su nodi e iterazioni con failure localizzate; oracolo
  esteso con righe `LEXRANK_*`; nessuna nuova opzione CLI né migrazione.
- Quinta slice (`Budget-characters-v1`): costo in scalari Unicode del testo sorgente esatto
  fissato in GS-MET-001-19 prima del codice; stessa selezione delle altre unità; oracolo esteso
  con righe `*_SELECTED_C40` e `MMR_ORDER_C40_L05`; `--characters <n>` in CLI; nessuna
  migrazione.

## Verifica e tracciabilità

Controlli statici e formattazione sulla macchina di sviluppo; compilazione, test e
`make verify` sul runner `xcode-27` tramite il workflow `Verifica`. Risultati e limiti
sono registrati in [GS-VER-146](../evidenze/GS-VER-146-riassunto-estrattivo.md) (prima
slice, superata sul runner remoto, CMP-096 `verified`) e in
[GS-VER-149](../evidenze/GS-VER-149-riassunto-centroide.md) (seconda slice, gate locale e CI
su `main` superati, CMP-097 `verified`) e in
[GS-VER-151](../evidenze/GS-VER-151-riassunto-mmr.md) (terza slice, CI su `main` `dfdcdbe` e `a86a53b`
superata, CMP-106 `verified`) e in
[GS-VER-164](../evidenze/GS-VER-164-riassunto-lexrank.md) (quarta slice, CI su `main` `aaf8ff3`
superata, CMP-163 `verified`) e in
[GS-VER-165](../evidenze/GS-VER-165-riassunto-budget-caratteri.md) (quinta slice, CI della PR #31 superata,
CMP-164 `implemented`), nella matrice di tracciabilità (RF-042, TV-036). Nessuna nuova decisione architetturale: la variante era
già candidata in GS-MET-001-19.

## Rischi e recupero

Il segmentatore di frasi è quello del contratto linguistico italiano: errori di confine si
riflettono nel riassunto e sono misurati da GS-VER-137/138, non qui. Con un solo documento
l'IDF liscio resta definito; con `IDF-unsmoothed-v1` i punteggi sono tutti nulli: la media
TF-IDF seleziona per posizione, il centroide esclude ogni frase come vettore nullo
(`isEligible = false`), comportamenti dichiarati e non corretti in silenzio. Con `MMR-v1`
la similarità fra vettori nulli vale zero: una frase con vettore nullo non è penalizzata ma
resta ineleggibile se il metodo la esclude; frasi identiche in documenti diversi hanno pesi
diversi e similarità minore di 1, come dichiarato in GS-MET-001-19. Rollback tramite revert; nessuna migrazione dei
package.

## Integrazione autorizzata in main

La richiesta del 2026-11-01 comprende l'integrazione dei branch remoti e la loro
eliminazione dopo la verifica. La scheda resta **Ready** per riconciliare MMR con
la base `380965c`, che contiene gli operatori KH Coder e la verifica di
CentroidCosine. Le evidenze dei metodi restano distinte; CMP-106 resta implemented
durante la verifica dell'integrazione. Eseguire il gate nativo e il preflight
App Store sul risultato, pubblicare il commit e attendere i controlli remoti.

Esito: l'integrazione è in `main` con `dfdcdbe` (#24) e i quattro controlli CI `xcode-27`
sono superati su quel commit e su `a86a53b`; CMP-106 è `verified` (GS-VER-151).
