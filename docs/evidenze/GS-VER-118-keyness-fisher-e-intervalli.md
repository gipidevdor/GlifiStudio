<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-118 — Keyness con selezione di Fisher e intervalli di confidenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-118 |
| Tipo | Evidenza di verifica numerica e di integrazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task Q3 di GS-DOR-003 |

## Ambito

Completa RF-031 con il profilo `keyness-gtest-fisher-ha-ci-bh-v2` di GS-MET-001-08 (versione
1.3.0), con le varianti decise in GS-DOR-003:

- `FisherSelection-min-expected-5-v1` (Cochran, 1954): Fisher sostituisce il G-test per il termine
  se un'attesa della sua 2×2 è minore di 5; la regola usa solo i margini ed è registrata nel
  risultato e nel digest; `gTestPValue` e `selectedTestIdentifier` sono conservati per ogni
  termine; BH usa i p selezionati;
- `LogRatioCI-Katz-HA-v1` e `OddsRatioCI-Woolf-HA-v1` al livello delle opzioni (default 0,95);
- payload `studio.glifi.artifact.keyness.v2`; mirror GlifiKit e output CLI `keyness` con i nuovi
  campi.

## Procedura e risultato

1. `keynessProducesSpecifiedValues`: sul caso di riferimento (tre token per gruppo) G, p del
   G-test, OR e log ratio restano quelli della v1; Fisher è selezionato per ogni termine; p, q e i
   quattro estremi degli intervalli coincidono con `Tests/Oracles/R/keyness.R` (`fisher.test`,
   `qnorm`, `p.adjust`) entro `1e-12`;
2. `keynessKeepsGTestForLargeExpectedCounts`: con attese ≥ 5 (30/1000 contro 10/1000) resta il
   G-test e gli intervalli coincidono con R; un livello di confidenza pari a 1 è rifiutato;
3. `check-fixtures.py` ricalcola in Python, indipendentemente da Swift e da R (coefficienti
   binomiali esatti, `NormalDist`), il nuovo reference case `keyness-gtest-fisher-ha-ci-bh-v2`; il
   ValidationManifest v2 è registrato nel catalogo e quello v1 dichiara la sostituzione;
4. contract test CLI in `verify.sh`: identità del profilo, regola di selezione coerente con
   `minimumExpectedCount` per ogni termine, stima puntuale dentro entrambi gli intervalli;
5. i test d'interpretazione e del planner restano verdi: le policy di supporto usano q-value e
   log ratio con la stessa semantica.

## Limiti

Con conteggi molto piccoli Fisher è conservativo e i q-value aumentano rispetto alla v1: è il
comportamento atteso della regola. Le soglie delle policy di supporto restano da validare
empiricamente in G4. Gli intervalli di Wald possono essere ampi per celle rare.

## Esito

**Superato localmente: RF-031 è completo per GS-MET-001-08.**
