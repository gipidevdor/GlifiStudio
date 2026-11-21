<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-168 — Osservazioni lessicali, `ZipfLogOLS-v1` e `HeapsLogOLS-v1`

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-168 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | In verifica: controlli locali superati, CI `xcode-27` in attesa |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta dell'iniziatore di proseguire lo sviluppo |
| Riferimenti | GS-MET-001-05 § Variante implementata: `corpus-lexical-laws-v1`; RF-028; TV-029; CMP-166 |

## Ambito

Prima slice di RF-028 con l'Artifact `corpus-lexical-laws-v1`
(`studio.glifi.artifact.corpus-lexical-laws.v1`), fissata in GS-MET-001-05 (versione 1.1.0):

- `GlifiLexicalLaws` e `GlifiCorpusLexicalLawsAnalysis` in GlifiCore: rank-frequency con
  troncamento dichiarato, spectrum, vocabulary growth `GrowthCheckpoints-linear-v1`, fit
  `ZipfLogOLS-v1` e `HeapsLogOLS-v1` separati dalle osservazioni, con residui, dominio
  dell'esponente e avviso descrittivo;
- `GlifiEngine.analyzeLexicalLaws`, persistito e riusato come Artifact del gruppo;
- `GlifiStudioLexicalLawsResult` e `GlifiStudioSession.analyzeLexicalLaws` in GlifiKit;
- `glifi laws --sources … [--checkpoints K] [--zipf-min-rank r] [--zipf-max-rank r]
  [--max-rows n]`;
- quattro failure `laws.*` tipizzate e localizzate in italiano e inglese.

## Procedura e risultato atteso

1. `lexicalLawsMatchOracle`: sui due documenti di `Tests/Oracles/Python/lexical_laws.py`
   (22 token, 9 type) conteggi per rango `6 5 3 2 2 1 1 1 1`, tie-break `mare`, `sole` e
   `luna`, `notte`, `strada`, `vento`, spectrum `(1,4) (2,2) (3,1) (5,1) (6,1)`, crescita a
   `K = 4` `(6,3) (11,6) (17,8) (22,9)`; `C`, `α`, `R²`, RMSE di Zipf su tutti i ranghi e
   sui ranghi 2–4, `K`, `β`, `R²`, RMSE e residui di Heaps uguali alle righe `LAWS_*` entro
   `10⁻¹²` relativo; l'oracolo usa `statistics.linear_regression` e la correlazione di
   Pearson, formulazione indipendente dalle somme centrate del prodotto;
2. `lexicalLawsEdgeCases`: righe troncate a 3 con fit di Zipf ancora su 9 ranghi; un solo
   type: Zipf assente (`fit.insufficient-points`), Heaps con `β = 0`, `R²` assente e
   esponente fuori dominio; sequenza vuota senza crescita né fit; checkpoint deduplicati;
   `K = 1`, `r_min = 0`, `r_max = r_min`, limite di righe 0 e selezione vuota rifiutati;
3. `lexicalLawsArePersistedAndReused`: dai testi importati la normalizzazione riproduce le
   osservazioni dell'oracolo; Artifact riusato a parità di parametri e distinto con
   parametri diversi; parametri non validi rifiutati dal motore;
4. contract test CLI in `verify.sh`: `glifi laws --checkpoints 5`: identità di analisi e
   metodi, ranghi consecutivi e ordinati, `Σ f = N`, `Σ V_k = V`, `Σ kV_k = N`, ultimo
   checkpoint `(N, V)`, `C = exp(β₀)`, somma dei residui nulla e avviso descrittivo.

## Esecuzione locale

Sulla macchina di sviluppo Linux sono superati `make quality-static`, il lint
`swift format`, `git diff --check`, l'oracolo Python confrontato con `expected.txt` e un
eseguibile Swift 6.2 che compila `GlifiLexicalLawsAnalysis.swift` con stub minimi e
riproduce le righe `LAWS_*`. GlifiCore completo non è compilato in locale: compilazione,
test Swift, contract test CLI e gate `make verify` sono affidati al workflow `Verifica` sul
runner `xcode-27`.

## Limiti

- Il fit OLS in scala logaritmica è diagnostico: non prova una power law né un meccanismo
  e non produce intervalli d'incertezza né estrapolazioni.
- Una sola sequenza concatenata del gruppo; nessuna curva per documento, Zipf–Mandelbrot o
  stima di massima verosimiglianza.
- Calcolo in memoria sulla sequenza del gruppo, non incrementale né esterno.
- Oracolo Python indipendente, non pacchetto terzo; nessuna presentazione nelle app.
- `make verify-app-store` non è stato eseguito su una macchina locale macOS 27.
