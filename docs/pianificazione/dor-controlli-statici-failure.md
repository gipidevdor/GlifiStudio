<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Feedback statico delle failure

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-180 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta di attività complementari e programma di piena produttività |
| Riferimenti | GS-STD-001-07; GS-DEV-002; GS-API-001 § 8; ADR-0020; RQ-058; RQ-063; RF-073 |

## Problema e criterio di stop

`make quality-static` omette i controlli di tassonomia e messaggi delle failure
già presenti in `make verify`. Includerli anticipa il feedback nel loop statico
locale e CI senza introdurre nuove regole di conformità.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Aggiungere i due controlli esistenti a `Scripts/quality-static.sh` e aggiornare GS-DEV-002; nessuna modifica a verify, cache, Makefile o prodotto |
| requisiti | RQ-058, RF-073, RQ-063; tutti i controlli preesistenti restano attivi |
| dominio/API | Interfaccia degli script invariata; tassonomia e catalogo non cambiano |
| failure semantics | Il primo controllo fallito termina lo script con esito non zero; nessun retry o stato persistente di prodotto coinvolto |
| esperienza prevista | Diagnostica già esistente visibile prima della toolchain; nessuna UI di prodotto |
| verifica | `make quality-static`, sintassi zsh, controlli negativi su copie temporanee senza hardlink: retry non ammesso e messaggio non tradotto; GS-VER-180 candidata; `make verify` finale |
| dati e migrazione | Nessun dato o formato di prodotto; copie di verifica eliminate a fine prova |
| sicurezza/privacy | Soli sorgenti e fixture sintetiche locali; nessun privilegio, dipendenza o rete nuova |
| prestazioni/sistema | Due controlli Python statici già disponibili, senza build o toolchain; nessuna nuova cache |
| tracciabilità | CMP-180 inizialmente `specified`; TV-071, GS-VER-180 e registri aggiornati dopo la verifica |
| decisioni e recupero | Applicazione di ADR-0020; nessuna scelta architetturale nuova; rollback del solo inserimento nel loop |

**Ready** registrata prima del coding. La verifica statica non attesta il
comportamento delle failure nell'interfaccia o su dispositivo.
