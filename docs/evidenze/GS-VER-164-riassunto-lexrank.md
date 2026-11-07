<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-164 — Riassunto estrattivo `LexRankSentence-v1`

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-164 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.1.0 |
| Stato | Superato sulla head `c3f7bab` della PR #29 (CI `xcode-27`); in attesa della CI su `main` |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-06 |
| Approvazione | GS-DOR-013 (1.3.0); richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-DOR-013; GS-MET-001-19 § Variante implementata: `LexRankSentence-v1`; GS-MET-001-07; RF-042; TV-036; CMP-163; GS-VER-146; GS-VER-149; GS-VER-151 |

## Ambito

Quarta slice di RF-042 sullo stesso Artifact `corpus-extractive-summary-v1`, fissata in
GS-MET-001-19 (versione 1.4.0):

- caso `lexRank` (`LexRankSentence-v1`) di `GlifiSummaryScoringMethod` in GlifiCore: nodi le
  frasi con vettore frase non nullo, archi coseno continui con autoanello, righe normalizzate,
  iterazione delle potenze con damping 0,85 dal vettore uniforme fino a variazione L1
  `≤ 10⁻¹²`; punteggio la probabilità stazionaria, eleggibilità
  `eligibility.non-null-vector-v1`;
- limiti fail-closed: oltre 2 000 nodi `summary.graph-limit-exceeded`
  (`insufficientResources`), oltre 1 000 iterazioni `summary.centrality-not-converged`
  (`invariantViolation`), entrambi con messaggi localizzati in italiano e inglese;
- il metodo entra nel descrittore come gli altri: Artifact distinto, payload invariato, nessuna
  migrazione; `MMR-v1` si applica con la centralità come rilevanza;
- `GlifiStudioSummaryScoringMethod.supportedIdentifiers` in GlifiKit e
  `--method LexRankSentence-v1` di `glifi summarize`, senza nuove opzioni.

## Procedura e risultato atteso

1. `lexRankSummaryMatchesPython`: sugli stessi due documenti dell'oracolo i punteggi
   (`0,301767474209051`, `0`, `0,248867874201183`, `0,211108705743267`,
   `0,238255945846499`), i rank (`1 5 2 4 3`) e le selezioni con budget di 2 frasi (`0 2`) e
   3 token (`0`) coincidono con le righe `LEXRANK_*` di `Tests/Oracles/Python/summary.py`
   registrate in `expected.txt` (73 iterazioni, somma 1); con `MMR-v1`, `λ = 0,5` e 3 frasi
   l'ordine di accettazione è `0 3 2` (`LEXRANK_MMR_ORDER_S3_L05`);
2. `lexRankBoundsAndFailsClosed`: grafo vuoto con `IDF-unsmoothed-v1` su un solo documento
   (tutti i punteggi zero, nessuna frase eleggibile); frasi duplicate con la stessa centralità
   ordinate per posizione; grafo uniforme di 2 000 nodi accettato con punteggio `1/2 000`, un
   nodo in più rifiutato con `summary.graph-limit-exceeded`; iterazione su matrice non
   stocastica rifiutata con `summary.centrality-not-converged`;
3. `lexRankSummaryIsPersistedAsDistinctArtifact`: dal testo importato, Artifact distinto da
   `CentroidCosine-v1` con gli stessi intervalli e la stessa eleggibilità, somma dei punteggi
   1, riuso con fonti in ordine inverso, rilettura con `storedDerivedResult`;
4. `summaryPresentationDecodesLegacySelectionOrder` (GlifiKit): identificatori di metodo
   supportati nell'ordine di dichiarazione;
5. contract test CLI in `verify.sh`: `glifi summarize --sentences 2 --method
   LexRankSentence-v1`: metodo ed eleggibilità dichiarati, stessi intervalli ed eleggibilità
   del centroide, punteggi positivi soltanto per le frasi eleggibili con somma 1, rank
   coerente con i punteggi, budget consumato e Artifact distinto dagli altri tre.

## Esecuzione locale

Sulla macchina di sviluppo Linux sono superati `make quality-static` (documentazione, matrice,
fixture, localizzazione, tassonomia delle failure e messaggi), il lint `swift format` dei file
modificati e l'oracolo Python. GlifiCore non è compilato in locale: compilazione, test Swift,
contract test CLI e gate `make verify` sono affidati al workflow `Verifica` sul runner
`xcode-27`.

## Esecuzione remota

Sulla head `c3f7bab` della [PR #29](https://github.com/gipidevdor/GlifiStudio/pull/29) i quattro
controlli CI `xcode-27` (`static-quality`, `format-check`,
[`verify`](https://github.com/gipidevdor/GlifiStudio/actions/runs/42315281725/job/128226356582),
[`app-store-baseline`](https://github.com/gipidevdor/GlifiStudio/actions/runs/42315281726/job/128226259143))
sono superati. Nel log `verify` risultano superati i tre test LexRank delle procedure 1–3
all'interno di 296 test Core e il test GlifiKit della procedura 4 tra 37 test Kit, seguiti dai
contract test CLI di `verify.sh` (procedura 5). Rscript e veraPDF sono assenti sul runner:
oracoli R e validazione PDF/A risultano saltati, senza effetto sulle righe `LEXRANK_*`
dell'oracolo Python, confrontate in locale.

## Limiti

- Una sola variante LexRank, continua e senza soglia; TextRank, LexRank con soglia e budget in
  caratteri restano candidati.
- Grafo denso limitato a 2 000 nodi: gruppi più grandi richiedono una variante sparsa o
  approssimata, con nuovo identificatore.
- Nessuna valutazione ROUGE o umana; oracolo Python indipendente, non pacchetto terzo.
- CMP-163 resta `implemented` fino alla CI su `main` dopo l'integrazione.
