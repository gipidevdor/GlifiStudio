<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Struttura e coesione del codice

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-280 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di strutturare il codice, evitare codice grasso e migliorare l’ingegneria del software |
| Riferimenti | [Issue #41](https://github.com/gipidevdor/GlifiStudio/issues/41); GS-AD-001; GS-STD-001-10/12/29; GS-API-001; RQ-005/010/011/023/063 |

## Scheda Definition of Ready

| Voce | Contratto dell’incremento |
| --- | --- |
| outcome e confini | Ridurre responsabilità mescolate e duplicazione nei tre confini identificati dall’audit sul commit `38bba29`: bootstrap/sessione/modelli Kit, commit del package e lifecycle CLI. Nessun limite arbitrario alle righe, nuovo modulo o riscrittura generale |
| contratto di dominio/API | API pubbliche e accessi invariati; stato e helper privati restano nello stesso actor/file. Modelli immutabili, bootstrap e sessione hanno collocazioni coese; wrapper equivalenti condividono un solo confine di admission e traduzione errori |
| persistenza | Staging e costruzione del manifest/generazione condivisi da helper privati. Validazioni, chiamate SQLite specifiche, ordine degli I/O, checkpoint, guardia stale qualitativa, commit point e writer lease restano espliciti e invariati |
| failure semantics | La CLI possiede e chiude la sessione su risultato, failure e cancellazione, rilanciando l’errore originale. Parsing, stdout/stderr, exit code e progressi restano invariati. Bootstrap, sessione, analisi derivate e identificatori mantengono i rispettivi namespace e policy |
| esperienza prevista | Nessuna modifica di interfaccia o stringhe; GUI e workbench delle altre chat sono preservati. I cataloghi di DTO legittimi restano tali |
| verifica | Baseline compilata prima delle patch, confronto della superficie API e del comportamento CLI; suite esistenti di sessione/admission/cancellazione/attività, round-trip/interruzione/recovery e privacy, 90 controlli CLI e gate completo `make verify`. Preflight applicativo prima della revisione finale; nessun controllo indebolito |
| sicurezza e dati | Nessun formato, migrazione, backend, privilegio, dipendenza, rete, telemetria o corpus reale nuovo. Protezioni di file e commit conservate |
| prestazioni/sistema | Refactoring di manutenibilità, senza promessa di accelerazione. Nessun nuovo actor, task, esistenziale negli hot path o copia di buffer massivi; conteggi di duplicazione e responsabilità sono indicatori strutturali, non benchmark |
| tracciabilità | CMP-280/281/282 inizialmente specified; GS-VER-280 registra confronto prima/dopo, revisioni, esiti e limiti. Registri, architettura e tracciabilità aggiornati insieme |
| decisioni e recupero | Attuazione interna dei confini esistenti: nessun nuovo ADR necessario secondo GS-STD-001-10 §10.2. Incrementi separabili per revert, senza migrazioni; checkout e cache delle altre chat preservati |

**Ready** prima del coding. Gli identificatori 280…289 sono riservati a questo
lotto. Le aree GUI, visualizzazioni/export e kernel numerici in lavorazione nelle
altre chat non rientrano nel refactoring.

## Riscontro del gate sulla baseline integrata

Il primo gate completo ha trovato due fixture incompatibili con la validazione
già presente in `GlifiUTF8Range.init(from:)` su `38bba29`. Lo snapshot intatto
riproduce entrambe le failure. Il successivo `aec1a00`, pubblicato dalla chat di
revisione, contiene la risoluzione completa con ADR-0042, validazione SpanMap e
test aggiornati: il lotto incorpora tale commit preservandone i contratti.
La prova di baseline resta distinta dal gate finale combinato; nessun controllo
è soppresso o indebolito per far passare il refactoring.
