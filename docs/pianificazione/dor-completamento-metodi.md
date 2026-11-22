<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Programma di completamento dei metodi specificati

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-003 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Richiesta dell'iniziatore: implementare le specifiche in modo esatto e completo con criterio di produttività |
| Riferimenti | GS-STD-001-07; RQ-063; GS-MET-001-04; GS-MET-001-05; GS-MET-001-07; GS-MET-001-08; RF-019; RF-020; RF-027; RF-030; RF-031 |

## Criterio di selezione

Il backlog deriva dalle parti «aperte» di `docs/requisiti.md` e dalla matrice di conformità.
Sono esclusi dal programma i lavori che richiedono dispositivi, utenti, corpus empirici o decisioni
dell'iniziatore (G4, DA-008, DA-026, ADR-0027). Gli altri sono ordinati per produttività: valore per
il percorso scientifico diviso per sforzo, con precedenza ai metodi la cui formula è già normativa e
verificabile contro un'implementazione indipendente.

| # | Task | Requisito | Formula normativa | Oracolo | Sforzo |
| --- | --- | --- | --- | --- | --- |
| Q1 | Varianti TF, IDF non smussata, normalizzazione di riga e `BM25-v1` | RF-030 | GS-MET-001-07, completa | R, formule indipendenti | basso |
| Q2 | `MTLD-bidirectional-v1` | RF-027 | GS-MET-001-04, completa | R, implementazione indipendente; casi a mano | basso |
| Q3 | Keyness: Fisher con regola di selezione persistita e intervalli di confidenza | RF-031 | GS-MET-001-08, da completare (sotto) | R `fisher.test`, formule di Katz e Woolf | medio |
| Q4 | N-grammi di caratteri e soglie degli n-grammi | RF-020 | GS-MET-001-05 | R | basso |
| Q5 | Frequenze con soglie, stopword e filtri dichiarati | RF-019 | GS-MET-001-05/06 | conteggi a mano | medio |

## Decisioni scientifiche per le parti non fissate

GS-MET-001-08 richiede intervalli di confidenza espliciti e una regola persistita di selezione di
Fisher, senza fissarne la forma. Il programma adotta:

- `FisherSelection-min-expected-5-v1`: il test esatto di Fisher sostituisce il G-test per il termine
  se almeno una frequenza attesa della sua tabella 2×2 è minore di 5 (regola di Cochran, 1954). La
  regola dipende solo dai margini, è registrata nel descrittore prima del calcolo e non usa il
  p-value.
- `LogRatioCI-Katz-HA-v1`: intervallo di Wald sul logaritmo del rapporto fra tassi (Katz et al.,
  1978) con conteggi corretti Haldane–Anscombe, `SE = √(1/a' − 1/N_A' + 1/c' − 1/N_B')` con
  `a'=a+0,5`, `c'=c+0,5`, `N_A'=N_A+1`, `N_B'=N_B+1`, riportato in base 2.
- `OddsRatioCI-Woolf-HA-v1`: intervallo di Wald sul logaritmo dell'odds ratio (Woolf, 1955) con le
  quattro celle corrette di `0,5`, `SE = √(1/a'+1/b'+1/c'+1/d')`.
- Livello di confidenza nella richiesta, default `0,95`, quantile normale da
  `GlifiDistributionFunctions`.

Q4 e Q5 non introducono liste di stopword predefinite: la lista, se presente, è parte della
richiesta e del descrittore. Una lista di default per l'italiano sarebbe una decisione di prodotto.

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Q1–Q5 completano formule già normative; nessuna nuova famiglia né cambio di baseline | — |
| requisiti | RF-019, RF-020, RF-027, RF-030, RF-031; accettazione: valori entro `1e-12` relativo dagli oracoli | — |
| contratto di dominio/API | Primitive in GlifiCore; operazioni persistite con mirror GlifiKit e comando CLI con envelope JSON v1 | — |
| failure semantics | Precondizioni violate (`N=0`, `avgdl=0`, `k1≤0`, `b∉[0,1]`, `τ∉(0,1)`, livello non in `(0,1)`) → `GlifiFailure` tipizzata, nessun valore corretto in silenzio | — |
| esperienza prevista | Nessuna nuova superficie UI obbligatoria; i risultati sono raggiungibili da Kit e CLI | — |
| verifica | Test Swift con letterali collegati a `expected.txt`, `make check-oracles`, `make verify` | — |
| dati e migrazione | Nuovi schemi versionati per gli Artifact modificati; Artifact esistenti restano leggibili | — |
| sicurezza/privacy | Nessuna rete o telemetria; input bounded come le operazioni esistenti | — |
| prestazioni/sistema | Calcoli lineari sulla matrice sparsa o sulla sequenza di token | — |
| tracciabilità | Ogni task aggiorna evidenza, requisiti, tracciabilità, matrice e CHANGELOG nello stesso commit | — |
| decisioni | Varianti Q3 documentate sopra; nessuna decisione riservata all'iniziatore | — |

## Stato DoR

**Ready** per Q1–Q5.

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| Q1 | Completato | GS-VER-115 |
| Q2 | Completato | GS-VER-116 |
| Q3 | Completato | GS-VER-118 |
| Q4 | Completato | GS-VER-117 |
| Q5 | Completato | GS-VER-117 |

## Riferimenti scientifici

- Cochran, [Some Methods for Strengthening the Common χ² Tests](https://doi.org/10.2307/3001666), 1954.
- Katz, Baptista, Azen e Pike, [Obtaining Confidence Intervals for the Risk Ratio in Cohort Studies](https://doi.org/10.2307/2530610), 1978.
- Woolf, [On Estimating the Relation between Blood Group and Disease](https://doi.org/10.1111/j.1469-1809.1955.tb01285.x), 1955.
- Robertson e Zaragoza, [The Probabilistic Relevance Framework: BM25 and Beyond](https://doi.org/10.1561/1500000019), 2009.
- McCarthy e Jarvis, [MTLD, vocd-D, and HD-D](https://doi.org/10.3758/BRM.42.2.381), 2010.
