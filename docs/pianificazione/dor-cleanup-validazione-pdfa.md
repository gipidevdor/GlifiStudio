<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Cleanup della validazione PDF/A

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-315 |
| Tipo | Correzione degli strumenti di verifica |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di una nuova iterazione di correzioni |
| Riferimenti | RQ-062; RQ-063; GS-STD-001-16; GS-VER-315; CMP-315 |

## Problema

Sul checkout con i lotti 312–314, un errore di export in check-pdfa.py avviene
prima dell'ingresso nel try/finally che possiede la directory di output.
Un probe sintetico conferma la directory ancora presente dopo CalledProcessError.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Rimuovere l'output temporaneo posseduto dal comando anche quando l'export solleva un'eccezione; soli check-pdfa.py e relativi test |
| requisiti | RQ-062/063 e GS-STD-001-16: esiti corretti, regressioni e tracciabilità; cleanup delle risorse temporanee richiesto dall'utente |
| dominio/API | Opzioni e semantica di conformità PDF/A invariate; nessuna API Core/Kit/CLI di prodotto cambia |
| failure semantics | L'eccezione dell'export resta identica e non diventa successo; cleanup durante l'unwind Python, anche per KeyboardInterrupt; nessuna garanzia su SIGKILL o perdita di alimentazione |
| esperienza prevista | Nessuna modifica alla GUI; tool assente mantiene skip opzionale o failure con require; directory esplicita dell'utente preservata |
| verifica | RED/GREEN su export fallito e interrotto, successo, validator failure e cartella fornita; suite già integrata nei gate; make verify macOS; GS-VER-315 |
| dati e migrazione | Sole fixture sintetiche temporanee, nessuna migrazione o dato persistente modificato |
| sicurezza/privacy | Nessuna dipendenza, rete, permesso o diagnostica nuova; rimozione limitata alla directory creata dall'invocazione |
| prestazioni/sistema | Stesso export e stesso validatore; solo estensione dell'ambito del finally, nessuna accelerazione dichiarata |
| tracciabilità | CMP-315 inizialmente specified; questa Ready precede il codice; evidenza e indici aggiornati nello stesso lotto |
| decisioni e recupero | Correzione locale di ownership, nessuna ADR nuova; revert dei soli file del lotto preservando 312–314 |

**Ready** per la correzione circoscritta.
