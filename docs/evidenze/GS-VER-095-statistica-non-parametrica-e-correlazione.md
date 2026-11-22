<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-095 — Correlazione, test non parametrici e correzioni multiple (GlifiCore/Kit/CLI)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-095 |
| Tipo | Evidenza di verifica inferenziale, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-054, TV-056 e TV-073 |

## Ambito

Completa le famiglie iniziali di GS-MET-001-21 non ancora presenti (GS-VER-087 copriva
`WelchT-v1` e `OneWayANOVA-v1`):

- `PearsonR-v1` e `SpearmanRho-v1` (Pearson sui midranks; p-value asintotico Student-t con
  `n-2` gradi di libertà, `t` infinita e p nullo per correlazione perfetta);
- `MannWhitneyU-v1` con `U₁ = R₁ − n₁(n₁+1)/2` sui midranks pooled e p-value dichiarato:
  **esatto** (enumerazione della distribuzione di `U` con la ricorrenza
  `f(m,n,u) = f(m−1,n,u−n) + f(m,n−1,u)`, solo senza tie e con `n₁+n₂ ≤ 50`) oppure
  **asintotico** con correzione dei tie e di continuità esplicita;
- `KruskalWallis-v1` con midranks pooled, fattore di correzione dei tie
  `C = 1 − Σ(t³−t)/(N³−N)` e coda chi-quadrato;
- `Bonferroni-v1` e `BenjaminiHochberg-v1` (step-up, ordine originale conservato);
- wiring persistente:
  - `document-metric-group-comparison-v2` aggiunge Mann–Whitney (due gruppi; metodo scelto
    dalla regola dichiarata «esatto senza tie, altrimenti asintotico») e Kruskal–Wallis;
  - nuova operazione `correlateMetrics` (`document-metric-correlation-v1`, Artifact
    `studio.glifi.artifact.metric-correlation.v1`) che correla due metriche di documento
    (lunghezza o frequenza relativa di un termine) con Pearson e Spearman su almeno tre
    documenti, con `GlifiStudioService.correlateMetrics` e comando CLI
    `correlate --sources … --x length|term:<parola> --y length|term:<parola>`.

## Procedura

1. verificare ogni test contro valori derivati a mano in forma chiusa:
   - Pearson `x=[1..5], y=[2,4,5,4,5]`: `r = 6/√60`, `t² = 9/2`, df 3, p bilaterale dalla
     forma chiusa della t con 3 gradi di libertà;
   - Spearman con tie `y=[5,6,7,8,7]` (ranghi 1,2,3½,5,3½): `ρ = 8/√95`, `t² = 192/31`;
   - Mann–Whitney esatto `x=[1,3,5], y=[2,4,6,8]`: `U₁=3`, frequenze di `U` 1,1,2,3,
     `P(U≤3)=7/35`, `P(U≥3)=31/35`, bilaterale `0,4`; distribuzione (3,4) somma 35, simmetrica;
   - Mann–Whitney con tie `x=[1,2,2], y=[2,3,4]`: `U₁=1`, `var = 9/12·(7−24/30) = 4,65`,
     `z = −3,5/√4,65` (senza continuità) e `−3/√4,65` (con);
   - Kruskal–Wallis `[1..3],[4..6],[7..9]`: `H = 7,2`, `p = exp(−3,6)`; con tie
     `[1,2],[2,3]`: `H = 1,35`, `C = 0,9`, `H/C = 1,5`, `p = erfc(√0,75)`;
   - Bonferroni `[0,01; 0,04; 0,5] → [0,03; 0,12; 1]`; BH
     `[0,01; 0,04; 0,03; 0,005] → [0,02; 0,04; 0,04; 0,02]`;
   - correlazione fra metriche su tre documenti: `r = −2√(3/13)`, `t = −2√3`, df 1,
     `p = 1 − (2/π)·atan(2√3)`, `ρ = −1` con p nullo;
2. verificare il confronto di gruppo (`[3,4]` vs `[3,5]` con tie → asintotico, `U₁=1,5`,
   `z=0`, `p=1`, Kruskal `H=0,15`; `[3,4]` vs `[5,6]` senza tie → esatto, `U₁=0`, `p=1/3`);
3. verificare via GlifiKit la persistenza e il riuso di `correlateMetrics` (quattro documenti,
   `r = (2/3)√(6/5)`) e il rifiuto con due fonti (`metric-correlation.insufficient-sources`);
4. estendere `Scripts/verify.sh` (assert su Mann–Whitney/Kruskal–Wallis reali del comando
   `group-metric` e contratto di errore di `correlate` con exit code 5) ed eseguire il gate
   completo `make verify`.

## Limiti

Il p-value di Spearman e di Pearson è asintotico (nessun test esatto o permutation), non c'è
intervallo di confidenza né Fisher-z. Mann–Whitney e Kruskal–Wallis non hanno effect size né
post-hoc; Wilcoxon signed-rank, paired/one-sample t, bootstrap e permutation test restano
aperti. Bonferroni e BH sono funzioni GlifiCore non ancora collegate a operazioni
persistite, Kit o CLI. Nessuna interfaccia macOS/iPadOS né integrazione nel planner.

## Esito

**Superato localmente per correlazione, test non parametrici e correzioni multiple in
GlifiCore, con confronto di gruppo v2 e `correlateMetrics` persistiti e con parità
GlifiKit/CLI.** Non promuove RF-045 a feature complete.
