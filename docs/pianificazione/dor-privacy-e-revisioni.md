<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Programma di privacy delle failure e revisioni delle fonti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-006 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Richiesta dell'iniziatore: proseguire senza interruzioni |
| Riferimenti | GS-STD-001-07; RQ-046; RF-077; GS-API-001 § 8; GS-DAT-001 |

## Unità di lavoro

| # | Task | Requisito | Esito atteso |
| --- | --- | --- | --- |
| V1 | Audit dinamico della privacy delle failure | RQ-046 | Canary in contenuto, query, nomi file e cartelle: nessuna failure di GlifiKit né envelope CLI lo riporta |
| V2 | Contract test delle revisioni delle fonti | RF-077 | Aggiornamento = nuova SourceRevision; fonti leggibili dopo la rimozione del file esterno e la riapertura; nessun path esterno persistito |

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Solo verifiche di contratti già specificati | — |
| requisiti | RQ-046, RF-077 | — |
| contratto di dominio/API | Invariato | — |
| failure semantics | Invariata; il test la osserva | — |
| esperienza prevista | Nessun cambiamento | — |
| verifica | Test GlifiKit e controllo CLI in `verify.sh` | — |
| dati e migrazione | Nessuna | — |
| sicurezza/privacy | È l'oggetto di V1 | — |
| prestazioni/sistema | Trascurabile | — |
| tracciabilità | Evidenza, requisiti, tracciabilità, matrice e CHANGELOG | — |
| decisioni | Nessuna | — |

## Stato DoR

**Ready** per V1–V2.

## Avanzamento

| # | Stato | Evidenza o motivo |
| --- | --- | --- |
| V1 | Completato | GS-VER-125 |
| V2 | Completato | GS-VER-125 |
