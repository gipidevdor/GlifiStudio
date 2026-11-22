<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ownership della cancellazione nel modello macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-165 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di completare prima macOS, con audit e tutti gli agenti |
| Riferimenti | GS-STD-001-07; RQ-011; RQ-058; GS-APL-001; GS-API-001 §§ 6–8 |

## Problema e criterio di stop

`cancelExecution` libera handle e stato occupato prima che il consumatore degli
eventi abbia osservato l'esito terminale. Una nuova operazione può quindi entrare
mentre la precedente mantiene ownership ed è ancora in grado di aggiornare il
modello. La richiesta di annullamento deve lasciare al task proprietario la pulizia.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | `cancelExecution` inoltra soltanto `cancel`; il `defer` di esecuzione rilascia handle e progresso; `run` rimane l'unico owner dello stato occupato fino alla fine dell'operazione |
| requisiti | RQ-011, RQ-058; annullamenti ripetuti non rendono il modello disponibile prima dell'esito terminale; al termine handle, progresso e busy sono ripuliti e la sessione resta utilizzabile |
| dominio/API | Correzione interna del modello condiviso, provata sul target macOS; nessuna nuova API GlifiKit o modifica del protocollo di esecuzione |
| failure semantics | Cancellazione cooperativa e idempotente; categoria, retry e retainedState esistenti; un completamento già accettato può precedere la cancellazione, senza forzarlo a failure né cancellare commit validi |
| esperienza prevista | L'azione Annulla non riabilita prematuramente azioni incompatibili; nessun nuovo testo o controllo; stato MainActor e accessibilità strutturale esistenti |
| verifica | Test del modello reale con osservazione deterministica dell'assegnazione dell'handle, cancellazione ripetuta e asserzioni immediate di ownership/busy; nessun sleep o polling; RED/GREEN con `make test-macos`, poi `make verify` e preflight macOS; GS-VER-186 candidata |
| dati e migrazione | Nessun cambio a package, schema o commit; ultima generazione valida e risultati terminali conservati secondo contratto esistente |
| sicurezza/privacy | Nessuna rete, dipendenza, entitlement, logging o nuovo dato; nessuna mutazione di sorgenti esterni |
| prestazioni/sistema | Nessun nuovo task, I/O o ricalcolo; cleanup nello scope dell'esecuzione già esistente, senza bloccare il Main Actor |
| tracciabilità | CMP-109 inizialmente `specified`; RQ-011/RQ-058, TV-012/TV-071, evidenza e CHANGELOG nello stesso cambiamento |
| decisioni e recupero | Ownership e cancellazione già definite da GS-API-001; nessuna nuova ADR; rollback mediante revert, preservando l'incremento GS-VER-185 |

**Ready** prima del coding. Il focus corrente è macOS: lo sviluppo dedicato iPadOS
è rimandato, mentre i controlli di regressione condivisi non vengono indeboliti.
Audit GUI, dispositivi, VoiceOver e G4 restano aperti; il test del modello non li
sostituisce.

## Avanzamento

RED: 12 test, 11 superati e una regressione fallita. GREEN dopo la correzione:
12 test superati senza failure o skip; lint e review indipendente superati.
CMP-109 `verified` dopo il gate macOS, senza chiusura di G4.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
