<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-149 — Riassunto estrattivo `CentroidCosine-v1`

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-149 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | In verifica sul runner remoto |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-16 |
| Approvazione | GS-DOR-013 (1.1.0); richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-DOR-013; GS-MET-001-19 § Variante implementata: `CentroidCosine-v1`; GS-MET-001-07; RF-042; TV-036; CMP-097; GS-VER-146 |

## Ambito

Seconda variante di RF-042 sullo stesso Artifact `corpus-extractive-summary-v1`, fissata in
GS-MET-001-19 (versione 1.2.0):

- `GlifiSummaryScoringMethod` in GlifiCore (`SentenceTFIDFMean-v1`, `CentroidCosine-v1`),
  parametro `method` di `GlifiCorpusExtractiveSummaryAnalysis` e di `analyzeExtractiveSummary`;
  il metodo è la rappresentazione del descrittore e la sua eleggibilità entra tra i parametri,
  quindi metodi diversi sono nodi e Artifact distinti;
- `CentroidCosine-v1`: vettore frase `conteggio × peso (documento, tipo)` sullo schema
  GS-MET-001-07 dichiarato, centroide come media dei vettori non nulli, punteggio come coseno col
  centroide, somme in ordine lessicografico del vocabolario; vettore nullo o centroide nullo:
  punteggio zero, `isEligible = false`, mai selezionato (`eligibility.non-null-vector-v1`);
- `isEligible` persistito per ogni frase candidata; i payload scritti prima del campo lo
  derivano dalla presenza di token lessicali (`eligibility.lexical-tokens-required-v1`);
- `GlifiStudioSummaryScoringMethod` in GlifiKit con failure tipizzata
  `summary.unknown-method` (`invalidInput`, `afterCorrection`, messaggio localizzato) e opzione
  `--method` di `glifi summarize`; `isEligible` nel mirror della frase.

## Procedura e risultato

1. `centroidCosineSummaryMatchesPython`: sugli stessi due documenti dell'oracolo i coseni
   (`0.914241630436781`, `0`, `0.746180682988278`, `0.333113335182715`, `0.63399246745524`),
   i rank (`1 5 2 4 3`), le selezioni con budget di 2 frasi (`0, 2`) e di 3 token (`0`)
   coincidono con le righe `CENTROID_*` di `Tests/Oracles/Python/summary.py` registrate in
   `expected.txt`; unità, intervalli e conteggi dei token identici alla media TF-IDF;
2. `centroidCosineExcludesNullVectors`: `IDF-unsmoothed-v1` su un solo documento rende ogni
   vettore nullo: punteggi zero, nessuna frase eleggibile né scelta, `consumedBudget = 0`,
   mentre la media TF-IDF seleziona ancora per posizione; coseni in `(0, 1]` per le frasi
   eleggibili; payload senza `isEligible` decodificato con il flag derivato dai token;
   round-trip JSON;
3. `centroidCosineSummaryIsPersistedAsDistinctArtifact`: dal testo importato, Artifact distinto
   da quello della media TF-IDF con gli stessi intervalli, riuso con fonti in ordine inverso,
   rilettura con `storedDerivedResult`, testo risolto uguale alla fonte;
4. contract test CLI in `verify.sh`: `glifi summarize --sentences 2` con e senza
   `--method CentroidCosine-v1`: metodo ed eleggibilità dichiarati, rank completi e monotoni,
   `isEligible` coerente con i token, nessuna frase scelta ineleggibile, stessi intervalli tra i
   due metodi, coseni in `[0, 1]`, stessa generazione di lineage.

Controlli statici (`make quality-static`, formattazione, documentazione e matrice) superati
sulla macchina di sviluppo Linux. Compilazione, test Swift e contract test CLI sono eseguiti
dal workflow `Verifica` sul runner `xcode-27`: l'esito è registrato nella sezione seguente.

## Esecuzione remota

Da registrare al termine del workflow `Verifica` della PR.

## Limiti

- Il centroide è calcolato sulle frasi del gruppo, non su un corpus esterno; TextRank, LexRank e
  MMR restano candidate, così come il budget in caratteri.
- L'oracolo è un'implementazione indipendente in Python delle formule dichiarate, non un
  pacchetto terzo; nessuna valutazione ROUGE o umana.
- Il runner remoto non dispone di Rscript: `make check-oracles` è eseguito solo dal gate locale
  (GS-VER-141).

## Esito

**In verifica: controlli statici superati; test e contract test in esecuzione sul runner remoto.**
