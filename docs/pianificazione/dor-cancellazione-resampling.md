<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Cancellazione nelle repliche bootstrap

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-176 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di implementare più milestone complementari |
| Riferimenti | GS-STD-001-12 § 12.6; GS-RUN-001; GS-MET-001-21; GS-VER-173; RQ-011; RQ-041; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| tracciabilità | GS-VER-176; CMP-184; norma 21, test e registri nello stesso incremento. |
| outcome e confini | Milestone e file definiti nelle righe seguenti; esclusioni e contratti restano espliciti |
| milestone | Osservare la cancellazione durante una replica lunga del bootstrap indipendente e moving-block, senza attendere 1024 repliche complete |
| contratto | Al massimo 4096 osservazioni ricampionate fra checkpoint del kernel; budget cumulativo anche per repliche piccole |
| invarianti | API pubbliche, SplitMix64, seed, numero e ordine delle estrazioni, somme binary64, quantili, stime e metadati invariati nei task non cancellati |
| blocchi | Spezzare soltanto la visita degli offset: nessuna nuova estrazione dell'inizio a ogni chunk e stessa coda troncata |
| failure semantics | Guard pubbliche prima della cancellazione come in precedenza; CancellationError e nessun intervallo parziale per task cancellati; delega L=1 preservata |
| verifica | Iniezione interna del checkpoint per cancellazione deterministica a metà replica, senza timer o stato globale; parità bitwise con i riferimenti legacy |
| confini | Bootstrap indipendente e moving-block; riuso del medesimo kernel anche in BCa, senza cambiare la sua formula. Monte Carlo, altri kernel statistici, sort backend, Apple integrations e GUI esclusi |
| ordinamento | Controlli prima e dopo il sort esistente; sort e validazione non diventano preemptive, nessuna promessa di latenza temporale |
| ownership | Solo GlifiResamplingStatistics, nuovo test e norma 21; root integra registri e gate; nessuna modifica alle altre chat |
| uscita | Test mirati, review, riscontri bitwise e make verify finale sulla composizione; nessun nuovo formato o promozione scientifica |

**Ready** prima dell'implementazione. Il contatore del lavoro misura osservazioni
ricampionate, non ogni istruzione del PRNG o il tempo di CPU.

## Esito del lotto

Implementazione e verifiche funzionali concluse nel gate congiunto di
[GS-VER-174](../evidenze/GS-VER-174-betweenness-cammini-estremi.md), con 637 test
e tutte le build previste. Le misure sotto contesa non attestano prestazioni
isolate; i limiti specifici restano nelle rispettive evidenze. Nessuna promozione
scientifica, audit grafico o gate su dispositivo viene chiuso da questo lotto.
