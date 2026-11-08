<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-166 — Riassunto estrattivo `TextRankSentence-v1`

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-166 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | In verifica sul runner remoto |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-08 |
| Approvazione | GS-DOR-013 (1.5.0); richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-DOR-013; GS-MET-001-19 § Variante implementata: `TextRankSentence-v1`; RF-042; TV-036; CMP-165; GS-VER-164 |

## Ambito

Sesta slice di RF-042 sullo stesso Artifact `corpus-extractive-summary-v1`, fissata in
GS-MET-001-19 (versione 1.6.0):

- caso `textRank` (`TextRankSentence-v1`) di `GlifiSummaryScoringMethod` in GlifiCore: nodi le
  frasi con token lessicali, archi `|T(s) ∩ T(u)| / (ln|s| + ln|u|)` senza autoanello e con
  soglia zero, nodi pendenti uniformi (`dangling.uniform-v1`), iterazione delle potenze con
  damping 0,85 condivisa con LexRank (`centralityStationary(_:damping:)`), tolleranza `10⁻¹²`,
  limiti di 1 000 iterazioni e 2 000 nodi con le failure già localizzate, i cui messaggi ora
  citano entrambi i metodi a grafo;
- eleggibilità `eligibility.lexical-tokens-required-v1`; il metodo entra nel descrittore come gli
  altri: Artifact distinto, payload invariato, nessuna migrazione; `MMR-v1` si applica con la
  centralità come rilevanza e la similarità coseno dei vettori frase;
- `--method TextRankSentence-v1` di `glifi summarize` e identificatore in
  `GlifiStudioSummaryScoringMethod.supportedIdentifiers`, senza nuove opzioni.

## Procedura e risultato atteso

1. `textRankSummaryMatchesPython`: sugli stessi due documenti dell'oracolo i punteggi
   (`0,322225312423944`, `0`, `0,292712942260428`, `0,177774687576056`, `0,207287057739572`),
   i rank (`1 5 2 4 3`) e le selezioni con budget di 2 frasi (`0 2`) e 3 token (`0`) coincidono
   con le righe `TEXTRANK_*` di `Tests/Oracles/Python/summary.py` registrate in `expected.txt`
   (40 iterazioni, somma 1); con `MMR-v1`, `λ = 0,5` e 3 frasi l'ordine di accettazione è
   `0 3 2`; uno schema di ponderazione diverso non cambia i punteggi;
2. `textRankDanglingNodesAndBounds`: frase a un token senza tipi comuni come nodo pendente
   (`TEXTRANK_DANGLING_SCORES`: `0,465116279069734`, `0,0697674418605318`,
   `0,465116279069734`, rank `1 3 2`); due frasi identiche a un token senza arco e con
   centralità uniforme `0,5` in un grafo di soli nodi pendenti, frase senza token ineleggibile;
   con una terza frase `a a` che ne condivide il tipo gli unigrammi restano uguali ma non
   uniformi (`TEXTRANK_UNIGRAM_SCORES`: `0,256756756756863`, `0,256756756756863`,
   `0,486486486486274`, rank `2 3 1`); grafo di 2 000 nodi accettato con
   punteggio `1/2 000`, un nodo in più rifiutato con `summary.graph-limit-exceeded`; matrice non
   stocastica rifiutata con `summary.centrality-not-converged`;
3. `textRankSummaryIsPersistedAsDistinctArtifact`: dal testo importato, Artifact distinto da
   `LexRankSentence-v1` con gli stessi intervalli, eleggibilità pari alla presenza di token,
   somma dei punteggi 1, riuso con fonti in ordine inverso, rilettura con `storedDerivedResult`;
4. `summaryPresentationDecodesLegacySelectionOrder` (GlifiKit): identificatori di metodo
   supportati nell'ordine di dichiarazione, `TextRankSentence-v1` compreso;
5. contract test CLI in `verify.sh`: `glifi summarize --sentences 2 --method
   TextRankSentence-v1`: metodo ed eleggibilità dichiarati, stessi intervalli della media
   TF-IDF, eleggibilità pari alla presenza di token, punteggi positivi soltanto per le frasi
   eleggibili con somma 1, rank coerente, budget consumato e Artifact distinto dagli altri.

## Esecuzione locale

Sulla macchina di sviluppo Linux sono superati `make quality-static`, il lint `swift format`
dei file modificati, la localizzazione e l'oracolo Python. GlifiCore non è compilato in locale:
compilazione, test Swift, contract test CLI e gate `make verify` sono affidati al workflow
`Verifica` sul runner `xcode-27`.

## Esecuzione remota

Da registrare: esito dei job `verify` e `app-store-baseline` sulla head definitiva della PR e su
`main` dopo l'integrazione. Fino ad allora CMP-165 resta `implemented`.

## Limiti

- Una sola variante TextRank: soglia zero, nodi pendenti uniformi, pesi sui tipi normalizzati
  del tokenizzatore italiano; soglie o similarità diverse richiedono un nuovo identificatore.
- Grafo denso limitato a 2 000 nodi, come LexRank; la LexRank con soglia resta candidata.
- Nessuna valutazione ROUGE o umana; oracolo Python indipendente, non pacchetto terzo.
- `make verify-app-store` non è eseguito su una macchina locale macOS 27 da questa sessione; il
  gate equivalente è il job remoto `app-store-baseline` e il preflight locale dell'iniziatore.

## Esito

**In verifica**: controlli statici superati localmente; gate nativo da registrare.
