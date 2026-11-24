<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Layout e visite dei kernel analitici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-173 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita: iterare e ottimizzare nuovamente |
| Riferimenti | GS-VER-172; GS-STD-001-17; GS-MET-001-15; GS-MET-001-16; GS-MET-001-21; RQ-008; RQ-009; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Ridurre buffer delle trasposte X/H in NMF, lookup e allocazioni BFS della centralità armonica, offset inutili nell'ultimo blocco moving-block bootstrap |
| requisiti | Formule, PRNG, seed, ordine delle operazioni e dei risultati invariati; confronti bitwise completi |
| contratto di dominio/API | Nessuna nuova API pubblica, identità, dipendenza, backend o formato; Brandes fuori ambito |
| failure semantics | Validazioni, budget e failure esistenti preservati; nessun risultato parziale per cancellazione e nessun nuovo rifiuto dell'input valido |
| esperienza prevista | Calcoli headless e nessuna modifica UI |
| verifica | Baseline Release archiviata prima dei kernel; nove workload sintetici, un warm-up e cinque campioni; output completi, riferimenti diretti e make verify |
| dati e migrazione | Nessuna migrazione o dato reale |
| sicurezza/privacy | Nessuna rete di prodotto, telemetria o dati personali |
| prestazioni/sistema | Misure tempo/RSS separate e confronti quiet; scartare o affinare regressioni, nessuna nuova soglia di rilascio |
| tracciabilità | GS-VER-173, matrice, specifiche e CHANGELOG nello stesso cambiamento |
| decisioni | Buffer flat solo sulle trasposte NMF selezionate; harmonic conserva anche archi zero e somme in ordine nodi; bootstrap conserva esattamente il consumo casuale |

**Ready** prima di modificare i kernel. Base pubblicata `f6bba3e`, con gli incrementi precedenti già integrati.

## Esito dell'incremento

Implementato e verificato in [GS-VER-173](../evidenze/GS-VER-173-layout-e-visite-analitiche.md):
18 confronti finali identici, 544 test e gate completo macOS/iPadOS superati.
Il primo esperimento è stato affinato dopo regressioni misurate; i costi residui
di tempo NMF alto e RSS bootstrap sono espliciti. CMP-177 resta `implemented`,
senza promozione scientifica né nuove soglie di rilascio.
