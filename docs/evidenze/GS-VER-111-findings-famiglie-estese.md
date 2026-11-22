<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-111 — Findings delle famiglie estese con le policy ADR-0026

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-111 |
| Tipo | Evidenza di verifica dell'interpretazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task P1 di GS-DOR-002 |

## Ambito

Supera i limiti di GS-VER-106 e GS-VER-110: gli output delle capability ADR-0025 generano findings.

- l'esecutore decodifica il payload persistito di ogni passo esteso e ne estrae
  `GlifiSupplementaryFacts` tipizzati (associazione, confronto di gruppo, collocazioni, rete,
  Correspondence Analysis, clustering, similarità) insieme alle revisioni sorgente;
- il risultato multivariato del clustering include la silhouette media (schema
  `corpus-multivariate.v2`);
- l'interprete applica le policy di ADR-0026: ogni risultato eleggibile diventa un Evidence e un
  Finding content-addressed con classe, dimensioni e motivi; le cause di `caution` diventano caveat
  localizzati; i non eleggibili e quelli oltre il limite sono contati nelle soppressioni; il
  ranking `editorial-rank-v1` ordina congiuntamente findings MVP ed estesi;
- sette messaggi e sette caveat nuovi in italiano e inglese nel catalogo e in
  `check-localization.py`; GS-ANA-001 e GS-UX-006 aggiornati.

## Procedura e risultato

1. piano `explore.relationships` su tre fonti con fatti di confine: associazione V=0,6 (`strong`),
   collocazioni `strong` e `caution` (bassa frequenza, con caveat `caveat.caution.low-frequency`) e
   una non eleggibile, rete Q=0,35 con 12 nodi (`moderate`), CA con primo asse `moderate` e gli altri
   non eleggibili: cinque findings con i rispettivi Evidence;
2. piano keyness con passi estesi: i findings keyness mantengono ordine e classi; il confronto di
   gruppo senza Hedges' g è soppresso (`interpretation.extended-not-eligible`); il limite conta sia il
   finding keyness sia quello di similarità esclusi;
3. esecuzione reale (`compare.objects` sulle fixture): keyness senza termini eleggibili e un finding
   di similarità `caution` (un solo tipo condiviso); `explore.relationships` su tre fonti con findings
   solo delle policy ADR-0026; contract test CLI aggiornato (finding di similarità disponibile
   nell'indagine);
4. suite GlifiCore di 195 test, GlifiKit 12, gate completo `make verify`.

## Limiti

Le soglie restano da validare empiricamente in G4. La presentazione dei nuovi findings nelle app
(P4) segue in un incremento separato; le app già mostrano findings generici con classe, dimensioni e
caveat.

## Esito

**Superato localmente: le famiglie estese producono findings tracciati con le policy ADR-0026.**
