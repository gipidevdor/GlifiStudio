<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ottimizzazione delle letture verificate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-200 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di una nuova iterazione di ottimizzazione |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-DAT-001; RQ-009; RQ-043; RQ-044; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Eliminare la doppia lettura/hash dei payload nelle API sourceData normali/recovery e artifactData, soltanto dopo misura Release; nessuna cache di fiducia persistente |
| requisiti | RQ-009, RQ-043, RQ-044 e RQ-063; byte restituiti, identità, budget e failure restano quelli del contratto esistente |
| dominio/API | Separare validazione dei riferimenti canonici da lettura verificata privata; mantenere API pubbliche, formati e percorsi di commit invariati |
| failure semantics | Nessun byte restituito prima del confronto dimensione/digest; no-follow, tipo regolare, nlink, limiti e cancellazione per chunk preservati; errori di riferimento e corruzione invariati |
| esperienza prevista | Stessi dati e risultati dei client Core/Kit; nessun controllo UI nuovo e nessun lavoro trasferito sul Main Actor |
| verifica | Baseline e candidato con stesso benchmark sintetico Release, warm-up e almeno sette campioni; dati e checksum esatti; regressioni di corruzione, link, FIFO, dimensioni, cancellazione e recovery; GS-VER-200 candidata; make verify finale |
| dati e migrazione | Un'unica lettura descriptor-relative con hash e buffer restituito; nessuna migrazione, modifica delle fonti o risultato ricalcolato da dati non verificati |
| sicurezza/privacy | Input package non fidato; nessuna verifica rimossa, nessun URL o payload diagnostico, rete o dipendenza nuova |
| prestazioni/sistema | Atteso 2N→N byte applicativi e due→un hash per payload; beneficio di latenza da misurare, cache OS calda dichiarata; nessuna promessa su disco fisico o app completa |
| tracciabilità | CMP-200 inizialmente specified; codice, test, benchmark, evidenza e registri aggiornati nello stesso cambiamento |
| decisioni e recupero | Applicazione dei contratti DAT/SEC; nessun backend o acceleratore; se il confronto non dimostra beneficio o emerge una regressione, non conservare la modifica; rollback per revert senza migrazione |

**Ready** prima del coding di benchmark e prodotto. La baseline viene acquisita
prima della modifica produttiva. Restano separati i residui di CMP-095 e i gate
su hardware/G4; non si introduce memoizzazione fra verifiche indipendenti.
