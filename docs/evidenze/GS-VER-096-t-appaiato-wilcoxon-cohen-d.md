<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-096 — t a un campione e appaiato, Wilcoxon signed-rank e Cohen's d

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-096 |
| Tipo | Evidenza di verifica inferenziale, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-054, TV-056 e TV-073 |

## Ambito

Completa le «varianti candidate completamente identificate» di GS-MET-001-21:

- `OneSampleT-v1`: `t = (x̄−μ₀)/(s/√n)`, `df = n−1`, `n ≥ 2`, `s > 0`; ipotesi `μ₀` e
  alternativa conservate nel risultato;
- `PairedT-v1`: `OneSampleT-v1` sulle differenze `x−y`; coppie di lunghezza diversa sono
  rifiutate (`statistics.paired-length-mismatch`), mai troncate;
- `WilcoxonSignedRank-v1`: policy degli zeri dichiarata `drop-zero-differences-v1`, midranks
  di `|d|`, `W⁺` somma dei ranghi positivi; p-value **esatto** (legge di `W⁺` enumerata come
  conteggio dei sottoinsiemi di `{1,…,n}` per somma, solo senza tie e con `n ≤ 50`) oppure
  **asintotico** con varianza `n(n+1)(2n+1)/24 − Σ(t³−t)/48` e correzione di continuità
  esplicita;
- `CohenD-pooled-v1`: `s_p = √{[(n₁−1)s₁²+(n₂−1)s₂²]/(n₁+n₂−2)}`, `d = (x̄₁−x̄₂)/s_p`, con
  `n₁,n₂ ≥ 2` e `s_p > 0`;
- wiring: `document-metric-group-comparison-v3` aggiunge `CohenD-pooled-v1` (solo con due
  gruppi) come campo distinto da test e p-value, con motivo stabile di indisponibilità, in
  GlifiCore, GlifiKit e nel comando CLI `group-metric`.

## Procedura

1. valori attesi in forma chiusa:
   - `OneSampleT-v1` su `[1..5]`, `μ₀=2`: `t=√2`, df 4, `p = 1 − 4/(3√3)` (forma chiusa della t
     con 4 gradi di libertà); alternativa `greater` pari a metà del bilaterale;
   - `PairedT-v1` su `[3,5,7]` e `[1,2,3]`: `d=[2,3,4]`, `t = 3√3`, df 2, `p = 1 − 3√3/√29`;
   - Wilcoxon esatto su `d=[1,−2,3,4,0]`: uno zero scartato, `W⁺=8`, `W⁻=2`, legge di `W⁺`
     per `n=4` `1,1,1,2,2,2,2,2,1,1,1`, `P(W⁺≥8)=3/16`, `P(W⁺≤8)=14/16`, bilaterale `6/16`;
     legge per `n=10` somma a `2¹⁰` ed è simmetrica;
   - Wilcoxon asintotico con tie `d=[1,1,−2,3]`: `W⁺=7`, `var = 7,5 − 6/48 = 7,375`,
     `z = 2/√7,375` senza e `1,5/√7,375` con correzione di continuità;
   - `CohenD-pooled-v1` su `[1,2,3]` e `[4,5,6]`: `s_p=1`, `d=−3`; nel confronto di gruppo
     GS-VER-092 (`[3,4]` vs `[3,5]`): `s_p²=1,25`, `d=−1/√5`;
2. verificare i rifiuti tipizzati (lunghezze diverse, varianza nulla, tutte differenze zero,
   esatto con tie);
3. estendere `Scripts/verify.sh`: con un documento per gruppo `d` è indisponibile con motivo
   `statistics.insufficient-sample-size`; eseguire il gate completo `make verify`.

## Limiti

`OneSampleT-v1`, `PairedT-v1` e `WilcoxonSignedRank-v1` sono funzioni GlifiCore bounded non
ancora collegate a un'operazione persistita: nel modello dati corrente non esiste una
sorgente naturale di osservazioni appaiate (ad esempio due revisioni della stessa fonte o
due codifiche dello stesso documento). Nessun intervallo di confidenza per `d` né
correzione per piccoli campioni (Hedges' g); nessuna interfaccia macOS/iPadOS né
integrazione nel planner.

## Esito

**Superato localmente per le quattro varianti in GlifiCore e per `CohenD-pooled-v1` nel
confronto di gruppo v3 persistito, con parità GlifiKit/CLI.** Non promuove RF-045 a
feature complete.
