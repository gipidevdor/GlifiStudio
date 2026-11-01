<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-151 — Riassunto estrattivo con ridondanza `MMR-v1`

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-151 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.1 |
| Stato | CI originaria superata; integrazione con main in verifica |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | GS-DOR-013 (1.2.0); richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-DOR-013; GS-MET-001-19 § Ridondanza implementata: `MMR-v1`; GS-MET-001-07; RF-042; TV-036; CMP-106; GS-VER-146; GS-VER-149 |

## Ambito

Terza slice di RF-042 sullo stesso Artifact `corpus-extractive-summary-v1`, fissata in
GS-MET-001-19 (versione 1.3.0):

- `GlifiSummaryRedundancyPolicy` in GlifiCore (`redundancy.none-v1`, `MMR-v1` con `λ`),
  parametro `redundancy` di `GlifiCorpusExtractiveSummaryAnalysis` e di
  `analyzeExtractiveSummary`; la politica, `λ` e la similarità entrano nei parametri del
  descrittore, quindi politiche o `λ` diversi sono nodi e Artifact distinti;
- `MMR-v1`: a ogni passo entra la frase eleggibile che rientra nel budget residuo con il massimo
  di `λ · rel(s) − (1 − λ) · max_{u∈S} sim(s, u)`, `rel` il punteggio del metodo dichiarato e
  `sim` il coseno tra i vettori frase di `CentroidCosine-v1`
  (`similarity.sentence-vector-cosine-v1`); parità risolta per posizione nella fonte; `λ` fuori
  da `[0, 1]` o non finito rifiutato con `summary.invalid-redundancy`;
- `selectionOrder` persistito per ogni frase scelta, anche con `redundancy.none-v1` (ordine di
  rank tra le scelte); i payload scritti prima del campo decodificano senza ordine, senza `λ` e
  senza similarità;
- `GlifiStudioSummaryRedundancy` in GlifiKit con failure tipizzate `summary.unknown-redundancy`
  e `summary.invalid-redundancy` (`invalidInput`, `afterCorrection`, messaggi localizzati) e
  opzione `--mmr <λ>` di `glifi summarize`; `selectionOrder`, `redundancyLambda` e
  `similarityIdentifier` nei mirror.

## Procedura e risultato

1. `mmrSummaryMatchesPython`: sugli stessi due documenti dell'oracolo, con rilevanza
   `CentroidCosine-v1` e `λ = 0,5`, gli ordini di accettazione con budget di 2 frasi (`0, 3`), 3
   frasi (`0, 3, 2`) e 3 token (`0`) coincidono con le righe `MMR_ORDER_*` di
   `Tests/Oracles/Python/summary.py` registrate in `expected.txt`; `λ = 0` sceglie `0, 3`,
   `λ = 1` riproduce la scansione per rank (`0, 2`) con lo stesso `selectionOrder`; la soglia
   `MMR_THRESHOLD_S2 = 0,562024411171168` separa la seconda scelta (frase 3 sotto, frase 2
   sopra); punteggi e rank identici a quelli senza ridondanza;
2. `mmrPenalizesDuplicatesAndRejectsInvalidLambda`: due frasi identiche dello stesso documento
   entrano entrambe nella scansione per rank e una sola con `MMR-v1` (coseno 1), sostituita
   dalla frase diversa; la stessa sequenza in due documenti con pesi diversi ha coseno
   `0,345806761841798` (`MMR_INFO_CROSS_DOCUMENT_SIMILARITY`) e gli ordini di accettazione con
   budget di 3 frasi, `λ = 0,5` (`1 3 0`) e `λ = 0` (`0 3 1`), coincidono con le righe
   `MMR_CROSS_ORDER_*`;
   `λ ∈ {−0,1; 1,1; NaN; ∞}` rifiutati; payload senza `selectionOrder`, `redundancyLambda` e
   `similarityIdentifier` decodificato; round-trip JSON; il risultato senza ridondanza non
   serializza `λ` né similarità;
3. `mmrSummaryIsPersistedAsDistinctArtifact`: dal testo importato con una frase duplicata,
   Artifact distinto da quello senza ridondanza e da quello con `λ = 0,7`, stessi punteggi e rank,
   riuso con fonti in ordine inverso, rilettura con `storedDerivedResult`, testo risolto uguale
   alla fonte, `λ = 1,5` rifiutato dal motore;
4. `summaryPresentationDecodesLegacySelectionOrder` (GlifiKit): messaggio precedente senza
   `selectionOrder` decodificato, valore esplicito conservato nel round-trip, identificatori
   supportati;
5. contract test CLI in `verify.sh`: `glifi summarize --sentences 2 --method CentroidCosine-v1`
   con e senza `--mmr 0.5`: politica, `λ` e similarità dichiarati, stessi punteggi e rank,
   `selectionOrder` uno-based e completo tra le frasi scelte e assente nelle altre, Artifact
   distinti nello stesso progetto; per `redundancy.none-v1` l'ordine segue il rank.

Controlli statici (`make quality-static`, formattazione, documentazione, matrice, fixture,
localizzazione e oracoli Python) superati sulla macchina di sviluppo Linux. Compilazione, test
Swift e contract test CLI sono eseguiti dal workflow `Verifica` sul runner `xcode-27`: l'esito è
registrato nella sezione seguente.

## Esecuzione remota

La head originaria `d636c67` della [PR #24](https://github.com/gipidevdor/GlifiStudio/pull/24)
ha superato `static-quality`, `format-check`,
[`verify`](https://github.com/gipidevdor/GlifiStudio/actions/runs/41303624450/job/124839624335)
e [`app-store-baseline`](https://github.com/gipidevdor/GlifiStudio/actions/runs/41303624451/job/124839549884).

L'integrazione con `main` `380965c` conserva gli operatori KH Coder e la
promozione documentale di CentroidCosine. Le risoluzioni dei conflitti riguardano
manifest, indice delle evidenze, DoR e tracciabilità; il codice è integrato
automaticamente. Il gate nativo locale e il preflight App Store sono eseguiti sul
risultato integrato; gli esiti sulla head pubblicata sono registrati nella PR.
CMP-106 resta `implemented`: questa integrazione non sostituisce la review
scientifica né introduce una promozione implicita a supported.

## Limiti

- La rilevanza è il punteggio del metodo dichiarato, non normalizzato: con `SentenceTFIDFMean-v1`
  `rel` non è in `[0, 1]` e `λ` pesa scale diverse; la scelta è dichiarata nel descrittore.
- La similarità usa i vettori frase sullo stesso schema di ponderazione del punteggio; nessuna
  similarità alternativa, TextRank o LexRank. La penalità è un massimo incrementale (`k · n`
  coseni per `k` frasi scelte): nessun benchmark Swift è attestato.
- L'oracolo è un'implementazione indipendente in Python delle formule dichiarate, non un
  pacchetto terzo; nessuna valutazione ROUGE o umana.
- Il runner remoto non dispone di Rscript: `make check-oracles` è eseguito solo dal gate locale
  (GS-VER-141).

## Esito

**In verifica**: controlli statici superati localmente; gate nativo da registrare.

## Regressione numerica dell'integrazione

Il gate locale completo ha individuato la mancanza del confronto Swift con
`MMR_INFO_CROSS_DOCUMENT_SIMILARITY` (0,345806761841798). La regressione ora
confronta il coseno delle frasi identiche fra documenti, calcolato dagli
operatori nativi sulle ponderazioni TF-IDF, con l'oracolo Python entro 1e-12.
Verifica inoltre il cambio effettivo della seconda frase scelta da MMR ai due
lati della soglia derivata da quel coseno, con scarto 1e-8 sul parametro lambda.
Il controllo lega così il valore numerico al comportamento del selettore.
