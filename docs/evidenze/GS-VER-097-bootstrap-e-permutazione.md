<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-097 — Bootstrap percentile e test di permutazione con PRNG versionato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-097 |
| Tipo | Evidenza di verifica inferenziale, persistenza, API e headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-18 |
| Approvazione | Evidenza osservata parziale di TV-031, TV-054, TV-056 e TV-073 |

## Ambito

Implementa la sezione «Intervalli, bootstrap e permutation test» di GS-MET-001-21:

- `SplitMix64-v1`: PRNG deterministico a 64 bit con seed registrato; indici in `0..<n`
  senza bias per rigetto del blocco finale incompleto;
- `BootstrapPercentile-v1` della media: `B` ricampionamenti con reinserimento dell'unità
  indipendente, quantili `quantile-linear-type7-v1` a `(1−livello)/2` e `(1+livello)/2`;
  generatore, seed, `B` e livello conservati nel risultato;
- `PermutationMeanDifference-v1` fra due campioni indipendenti: strategia dichiarata
  **esatta** (enumerazione lessicografica di tutte le `C(n₁+n₂, n₁)` assegnazioni entro
  200 000, p = `b/m`) o **Monte Carlo** (Fisher–Yates parziale con seed, p = `(b+1)/(m+1)`);
  alternativa bilaterale o unilaterale; l'exchangeability è documentata come precondizione
  del disegno;
- wiring: `document-metric-group-comparison-v4` aggiunge, con regola dichiarata, il test di
  permutazione (esatto entro il limite, altrimenti Monte Carlo con 9 999 rietichettature) e
  l'intervallo bootstrap al 95 % della media di ciascun gruppo con almeno due documenti
  (`B = 2 000`); generatore e seed (`20260918`) sono persistiti nell'Artifact, in GlifiKit e
  nell'output CLI `group-metric`.

## Procedura

1. `SplitMix64-v1` riproduce le sequenze di riferimento per seed 0
   (`E220A8397B1DCDAF`, `6E789E6AA1B965F4`, `06C45D188009454F`) e 42, verificate con
   un'implementazione Python indipendente; indici limitati sempre nel dominio e ripetibili;
2. quantile di tipo 7 su `[1,2,3,4]`: `0 → 1`, `0,25 → 1,75`, `0,5 → 2,5`, `1 → 4`;
3. bootstrap: identico a parità di seed, stima `41/7`, limiti ordinati e nel supporto del
   campione, intervallo degenere `[3,3]` per un campione costante, parametri non validi
   rifiutati;
4. permutazione esatta `[1,2]` vs `[3,4]`: differenze delle sei assegnazioni
   `−2,−1,0,0,1,2`, osservata `−2`, p bilaterale `2/6`, `less` `1/6`, `greater` `1`;
   enumerazione oltre limite rifiutata; Monte Carlo (20 000 rietichettature, seed 7)
   riproducibile, uguale a `(b+1)/20 001` ed entro `0,02` (circa sei errori standard) dal
   valore esatto `1/3`; p Monte Carlo mai inferiore a `1/(m+1)`;
5. confronto di gruppo `[3,4]` vs `[5,6]`: permutazione esatta con `m=6`, p `1/3`,
   intervalli bootstrap che contengono la media e restano nel supporto;
6. `Scripts/verify.sh`: con un documento per gruppo la permutazione è esatta con due
   assegnazioni e p `1`, senza intervalli bootstrap; gate completo `make verify`.

## Limiti

Il bootstrap copre solo la media e solo l'intervallo percentile (nessun BCa né bootstrap a
blocchi per dati dipendenti); il test di permutazione solo la differenza delle medie fra
due gruppi. Seed e numero di ricampionamenti del confronto di gruppo sono costanti
dichiarate, non ancora parametri della richiesta. Nessuna interfaccia macOS/iPadOS né
integrazione nel planner.

## Esito

**Superato localmente per `SplitMix64-v1`, `BootstrapPercentile-v1` e
`PermutationMeanDifference-v1` in GlifiCore e per il confronto di gruppo v4 persistito, con
parità GlifiKit/CLI.** Non promuove RF-045 a feature complete.
