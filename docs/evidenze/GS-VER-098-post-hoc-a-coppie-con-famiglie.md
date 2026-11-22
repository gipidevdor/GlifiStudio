<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-098 — Post-hoc a coppie con famiglie multiple dichiarate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-098 |
| Tipo | Evidenza di verifica inferenziale, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-054, TV-056 e TV-073 |

## Ambito

GS-MET-001-21 richiede che post-hoc e famiglia multipla siano **nodi separati**
dall'omnibus e che p grezzi e corretti restino entrambi disponibili. Questa evidenza copre:

- `GlifiPostHocAnalyzer` (`document-metric-pairwise-posthoc-v1`, Artifact
  `studio.glifi.artifact.group-metric-posthoc.v1`), distinto dal confronto omnibus
  `document-metric-group-comparison-v4`: per almeno tre gruppi indipendenti confronta ogni
  coppia non ordinata con `WelchT-v1` e `MannWhitneyU-v1` (metodo esatto senza tie,
  altrimenti asintotico, come nel confronto di gruppo);
- famiglia dichiarata `all-unordered-group-pairs-per-test-v1`: una famiglia per test,
  composta dai soli p-value disponibili (`m` persistito); le coppie che non soddisfano le
  precondizioni restano fuori dalla famiglia con motivo stabile;
- per ogni test disponibile: p grezzo, `Bonferroni-v1` e `BenjaminiHochberg-v1`
  (quest'ultimo finora solo in GlifiCore, GS-VER-095);
- `GlifiEngine.postHocGroupMetric`, `GlifiStudioService.postHocGroupMetric` e comando CLI
  `posthoc --group … --group … --group … [--term]`, con riuso get-or-store.

## Procedura

1. tre gruppi con lunghezze `[3,4]`, `[5,6]`, `[1,2]`: differenze delle medie `−2, 2, 4`;
   Welch con df 2 e p `1−|t|/√(t²+2)`: `a = 1−2/√5` per le prime due coppie
   (`t = ∓2√2`), `b = 1−4/√17` per la terza (`t = 4√2`); Bonferroni `[3a, 3a, 3b]`;
   BH `[a, a, 3b]` (ordinati `b, a, a` → `3b, 3a/2, a`, minimo da destra); Mann–Whitney
   esatto `U₁ = 0, 4, 4`, ogni p `1/3`, Bonferroni `1`, BH `1/3`;
2. due gruppi rifiutati (`group-posthoc.insufficient-groups`); con un gruppo di un solo
   documento la famiglia Welch si riduce a `m = 1` e le p corrette coincidono con la grezza;
3. GlifiKit: gruppi `[3,2]`, `[1]`, `[4]` → famiglia Welch vuota, Mann–Whitney `m = 3`,
   riuso dello stesso `artifactID`/`generation`;
4. `Scripts/verify.sh`: `posthoc` con i due soli gruppi del contract test fallisce con
   exit code 5 e codice `group-posthoc.insufficient-groups`; gate completo `make verify`.

## Limiti

Nessun post-hoc specifico per ANOVA (Tukey HSD, Games–Howell) né Dunn per Kruskal–Wallis:
i confronti a coppie usano Welch e Mann–Whitney con correzioni generiche. La famiglia è
fissata a tutte le coppie; contrasti pianificati o famiglie definite dall'utente restano
aperti. Nessun effect size per coppia; nessuna interfaccia macOS/iPadOS né integrazione nel
planner.

## Esito

**Superato localmente per il post-hoc a coppie persistito come nodo separato, con p grezzi,
Bonferroni e Benjamini–Hochberg per famiglia e parità GlifiCore/Kit/CLI.**
