<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Buffer indicizzati della betweenness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-177 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta di ottimizzare evitando sovrapposizioni alle altre chat |
| Riferimenti | GS-MET-001-16; GS-STD-001-12; GS-STD-001-17; GS-STD-001-29; GS-VER-174; RF-039; RQ-008; RQ-009; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Ridurre lookup di identità e allocazioni nelle visite Brandes mediante CSR già disponibile e scratch riusabile; sola betweenness e helper privati. |
| contratto scientifico | Stesso ordine di sorgenti, vicini, predecessori e riduzioni binary64; stessi pesi zero, paralleli e self-loop; fallback dei contatori estremi invariato. |
| failure semantics | API non throwing, identità Betweenness-v1, valori e fallimenti invariati; nessun nuovo formato, backend, dipendenza o operazione pubblica Kit/CLI. |
| verifica | Otto regressioni numeriche esistenti; ulteriori componenti, sink, isolati e permutazioni; riferimento legacy bitwise e oracolo indipendente. |
| prestazioni | Harness congelato e baseline Release prima della patch produttiva; tre grafi esistenti e un quarto con componenti e isolati; input/output SHA completi, campioni grezzi, RSS e contesa dichiarati; nessuna soglia nuova. |
| ownership | Agente grafi: kernel; agente verifica: test e benchmark; coordinatore: documenti, misure e gate. GUI, CLI, sessioni, operatori e refactoring delle altre chat esclusi. |
| tracciabilità | CMP-185; GS-VER-177; norma metodologica, test ed evidenze aggiornati nello stesso lotto. |
| uscita | Conservare soltanto cambiamenti corretti e misurati; revisione indipendente, make verify completo e pulizia dei soli artefatti del lotto. |

**Ready** sulla base pubblicata `38bba29`, nel worktree isolato
`codex/indexed-optimization-20261122`, prima di modifiche a test, harness e
kernel. Predecessori in blocchi contigui dimensionati con il grado entrante:
append nell'ordine originale, memoria O(V+E); reset limitato ai nodi visitati.
Nessuna promozione scientifica o attestazione G4.
