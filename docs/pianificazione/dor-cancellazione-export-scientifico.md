<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Cancellazione dell'export scientifico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-317 |
| Tipo | Correzione del lifecycle di export |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di iterazione |
| Riferimenti | RF-085; RQ-011; RQ-058; RQ-060; RQ-061; RQ-062; RQ-063; GS-API-001 § 7; GS-STD-001-18; GS-VER-317; CMP-317 |

## Problema

Il motore controlla la cancellazione prima del renderer, che poi esegue
rendering, scritture, verifica e rename senza checkpoint. La chiusura del
progetto macOS cancella e attende quel task, che può ancora pubblicare.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Osservare cancellazione fino al commit dell'export; soli exporter scientifico e test correlati, senza modificare renderer numerici, formati o UI |
| requisiti | RF-085, RQ-011/058/060/061 e GS-API-001 § 7: niente export incompleto finale, errori tipizzati e stato valido conservato |
| dominio/API | Rename staging→destinazione è il commit point; API pubbliche, receipt, manifest e payload invariati; metodo singolo di export e fault injection interna esistente |
| failure semantics | Task già cancellato che raggiunge l'exporter o cancellazione osservata prima del rename: CancellationError conservato, staging rimosso, destinazione non creata; Engine e Kit dopo admission preservano cancelled/export/unchanged; cancellazione precedente all'admission Kit conserva lastCommittedGeneration già esistente; dopo rename nessun nuovo check, successo e receipt conservati |
| esperienza prevista | La chiusura macOS può interrompere l'operazione ai checkpoint senza pubblicare un risultato parziale; nessun controllo o messaggio UI nuovo |
| verifica | RED sul vero exporter pre-cancelled; checkpoint deterministici prima/dopo commit; cleanup, file utente preservati e receipt verificabile; suite export/recovery e make verify macOS; GS-VER-317 |
| dati e migrazione | Originali/progetto invariati; stessi renderer, formati e regole di encoding per export non cancellato; nessun formato nuovo o migrazione; nessuna promessa di identità binaria fra PDF generati dal sistema |
| sicurezza/privacy | Nessuna dipendenza, rete o entitlement; cleanup della sola directory staging posseduta, senza rimuovere destinazioni esistenti |
| prestazioni/sistema | Check cooperativi fra unità bounded/formati/scritture e prima del commit; nessuna garanzia di interruzione dentro chiamate framework non cooperative né misura di latenza assoluta |
| tracciabilità | CMP-317 inizialmente specified, questa Ready prima del codice, evidenza e indici nel medesimo lotto |
| decisioni e recupero | Applicazione del contratto GS-API-001 esistente, nessuna ADR nuova; revert dei soli file del lotto preservando gli altri WIP |

Il supporto di interruzione interno può aggiungere un osservatore sincrono
Sendable non throwing che ritorna: consente al test di cancellare il task
al checkpoint già esistente. Non è API pubblica, non aggiunge un punto I/O
artificiale e non permette di lanciare cancellazione dopo commit. I comportamenti
throwFailure/invoke esistenti restano invariati.

L'iniezione di errore I/O dopo commit conserva la tassonomia storica
lastCommittedGeneration; non è il caso di semplice cancellazione dopo commit,
che deve concludere con successo. Nessun mapping condiviso viene modificato.

**Ready** per la correzione delimitata; nessun controllo Task dopo il rename.
