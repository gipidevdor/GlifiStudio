<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Invalidazione selettiva alla reimportazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-010 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready con rischio accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | ADR-0028 accettato dall'iniziatore il 2026-09-20 (DA-033 chiusa) |
| Riferimenti | GS-STD-001-07; ADR-0013; ADR-0028; GS-MET-001-02; GS-DAT-001; RF-011; RQ-025 |

## Unità di lavoro

| # | Task | Esito atteso |
| --- | --- | --- |
| A1 | Descrittore v2 | `GlifiAnalysisDescriptor` dichiara `sourceRevisionIDs` ordinati canonicamente; `corpusVersionDigest` è il digest delle sole revisioni dichiarate |
| A2 | Identità e compatibilità | `analysis-descriptor.v2` entra nell'identità dei nodi; un descrittore v1 senza revisioni dichiarate vale come dipendente dall'intera generazione e i package esistenti si aprono invariati |
| B1 | Invariante del package | La verifica sostituisce l'uguaglianza con il digest radice: ogni revisione dichiarata esiste nella generazione e il digest coincide con quello ricalcolato su quelle revisioni |
| B2 | Commit e recovery | Il commit trasporta alla nuova generazione gli Artifact validi e i dipendenti la cui catena regge; i checkpoint di interruzione restano verificati |
| C1 | Riuso osservabile | Dopo l'importazione di una fonte estranea gli Artifact non coinvolti sono riusati, senza ricalcolo |
| C2 | Invalidazione transitiva esatta | Su grafi ramificati sintetici vengono invalidati tutti e soli i discendenti che dipendono dalle revisioni cambiate |
| C3 | Fixture e documenti | Fixture di persistenza v2 accanto alle v1, evidenze, tracciabilità e matrice di conformità |

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Riuso degli Artifact validi dopo un'importazione; nessun cambiamento dell'interfaccia oltre ai tempi | — |
| requisiti | GS-MET-001-02 § invalidazione transitiva; RF-011; GS-DAT-001 | — |
| contratto di dominio/API | Nuovo schema `analysis-descriptor.v2`; GlifiKit e CLI invariati | — |
| failure semantics | L'invariante violato resta una corruzione tipizzata; il codice `project.artifact-corpus-mismatch` cambia significato e va ridichiarato | — |
| esperienza prevista | Nessuna modifica visibile: solo minor tempo di ricalcolo dopo le importazioni | — |
| verifica | Invalidazione transitiva su grafi ramificati, riuso dopo importazione estranea, apertura di fixture v1, recovery SIGKILL | — |
| dati e migrazione | Cambio di identità dei nodi: gli Artifact esistenti sono ricalcolati una volta, senza perdita; lettura dei package v1 invariata | — |
| sicurezza/privacy | Nessun dato nuovo persistito oltre alle identità delle revisioni già presenti nel package | — |
| prestazioni/sistema | Beneficio proporzionale alla dimensione del corpus e alla frequenza delle importazioni; costo una tantum al primo ricalcolo | — |
| tracciabilità | Evidenze per incremento, matrice di conformità, tracciabilità | — |
| decisioni | ADR-0028, opzione 2 | — |

## Rischio accettato

Il cambiamento tocca l'invariante su cui poggiano integrità del package, riuso get-or-store e
recovery. Il rischio è contenuto procedendo in tre incrementi separati, ciascuno con gate verde, e
mantenendo la prova di interruzione SIGKILL su ogni checkpoint del commit.

## Stato DoR

**Ready con rischio accettato**; i tre incrementi A, B e C sono completati con gate verde.

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| A1 | Completato | GS-VER-131 |
| A2 | Completato | GS-VER-131 |
| B1 | Completato | GS-VER-132 |
| B2 | Completato | GS-VER-132 |
| C1 | Completato | GS-VER-133 |
| C2 | Completato | GS-VER-133 |
| C3 | Completato | GS-VER-133 |
