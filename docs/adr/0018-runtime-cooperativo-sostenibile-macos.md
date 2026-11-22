<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0018 — Runtime cooperativo e sostenibile su macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0018 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Richiesta esplicita di imporre sostenibilità di sistema e migliori pratiche Apple macOS |
| Sostituisce | Nessuno |

## Contesto

L'analisi locale può saturare CPU, memoria e I/O. Usare tutto l'hardware disponibile
senza distinguere intento e pressione peggiorerebbe responsività, autonomia,
temperatura e convivenza con le altre app. Le scelte devono essere deterministiche,
testabili e non alterare i risultati scientifici.

## Decisione

1. Il runtime fotografa Low Power Mode, thermal state, memory pressure e attività
   dell'app per ogni admission e a ogni evento di variazione.
2. `GlifiRuntimePolicy` mappa intento e condizioni nei profili `responsive`,
   `balanced`, `constrained`, `protective` e `suspended`.
3. Il parallelismo è bounded, non supera otto e viene ridotto prima di consumare
   working set o performance core aggiuntivi.
4. Pressione seria sospende lavoro discrezionale; pressione critica ammette soltanto
   UI minima e impone checkpoint/rifiuto sicuro per il resto.
5. La QoS deriva dall'intento Apple: interactive, user initiated, utility o
   background. Non viene aumentata per ottenere benchmark migliori.
6. L'app torna a idle, usa notifiche invece di polling e resta eleggibile per App
   Nap. Le attività di processo sono finite, owned e permettono idle system sleep.
7. Timer e I/O vengono coalesced; acceleratori entrano solo dopo una misura
   end-to-end che includa energia, memoria e copie.
8. Le condizioni possono cambiare scheduling e tempo, mai semantica, precisione o
   completezza dichiarata del risultato.

## Alternative considerate

- usare sempre tutti i core: respinto per memoria, termica e interferenza;
- scegliere dal modello commerciale del Mac: respinto perché fragile e non
  rappresentativo delle condizioni correnti;
- affidarsi soltanto ad App Nap: respinto perché l'app conosce prima del sistema
  quando il proprio lavoro è discrezionale;
- aggiungere un'impostazione “prestazioni massime” nella 0.1: respinto finché non
  esistono misure, rischi e limiti sicuri.

## Conseguenze

Il comportamento è prevedibile e rispettoso del sistema, con possibile riduzione
del throughput in Low Power Mode o pressione. L'adattatore event-driven per
notifiche e memory pressure diventa prerequisito del primo flusso lungo. Benchmark
che ignorano stato del sistema non sono accettabili.

## Verifica

GS-APL-015 e GS-RUN-001 governano l'implementazione. I test coprono la matrice dei
profili; Instruments, Activity Monitor, App Nap e Organizer verificano il
comportamento reale su hardware. Una regressione energetica superiore alla soglia
richiede correzione o deroga formale.
