<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Collegamento dei documenti macOS dopo operazioni occupate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-196 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Nuova richiesta di miglioramenti/completamenti macOS; difetto lifecycle confermato |
| Riferimenti | RF-001; RQ-011; RQ-032; RQ-058; GS-APL-001; GS-APL-005; GS-DOR-163/166 |

## Problema e criterio di stop

`attachDocument` attraversa `run`, che scarta l'operazione se il modello è
occupato. Il task SwiftUI identificato dal percorso non riparte quando il busy
termina: un nuovo URL documentale può quindi non essere collegato alla sessione.
Su macOS il collegamento attende idle senza polling, conservando soltanto la richiesta
più recente e rispettando la cancellazione del task proprietario.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Solo macOS: `attachDocument` attende in modo asincrono la disponibilità del modello; tra le richieste in attesa tenta soltanto la più recente; URL superata o task cancellato non avvia una sessione obsoleta |
| requisiti | RF-001, RQ-011, RQ-032, RQ-058; collegamento non perso durante busy, la richiesta più recente prevale, cancellazione invalida soltanto la propria richiesta, stessa URL già attiva resta noop |
| dominio/API | Stato effimero MainActor di richiesta/attesa con identità distinta; continuazioni o segnale equivalente, senza timer/sleep/polling; `run` e task attivo conservano ownership e cleanup esistenti; nessuna API Kit/Core o formato nuovo |
| failure semantics | URL più recente verificata prima del tentativo; cancellazione di una richiesta in attesa non apre sessioni o crea package e non invalida la richiesta successiva; apertura fallita conserva la sessione precedente; candidate non attivabili vengono chiuse e scope bilanciati |
| esperienza prevista | Task documentale SwiftUI per URL, collegamento differito al termine dell'operazione senza scartare la richiesta; nessuna nuova azione o testo UI; sessione precedente utilizzabile finché la candidata non è valida |
| verifica | Test deterministici con opener GS-DOR-166 sospeso tramite continuazione: RED su collegamento perso, rilascio busy e collegamento riuscito, URL A sostituita da B, cancellazione della sola A senza effetto su B, cancellazione in attesa senza creazione package, failure conserva vecchia sessione, stessa URL noop; gate/preflight macOS su nuovo snapshot; GS-VER-196 candidata |
| dati e migrazione | Nessun cambio di package, bookmark, storia o commit; stato di richiesta e continuazioni non persistenti; nessuna rimozione di generazioni valide |
| sicurezza/privacy | URL documentali autorizzati e scope esistenti; cancellazione/obsolescenza non lasciano candidate o attese orfane; nessuna rete, dipendenza, entitlement, log o dato nuovo |
| prestazioni/sistema | Attesa a evento e risveglio alla fine dello scope occupato; nessuna attesa attiva o nuova elaborazione/I/O onerosa sul Main Actor; i confini Kit esistenti restano, gestione dell’attesa bounded alle richieste possedute |
| tracciabilità | CMP-196 inizialmente `specified`; RF-001/RQ-011/RQ-032/RQ-058, TV-001/TV-012/TV-071, evidenza e CHANGELOG nello stesso incremento |
| decisioni e recupero | Contratto documentale GS-APL-005 e isolamento GS-APL-001 già applicabili; nessuna ADR nuova; rollback locale macOS senza migrazione, preservando il lotto precedente e le altre sessioni |

## Ordine e cancellazione

L'identità della nuova richiesta supersede quelle in attesa anche quando l'URL
ritorna a quella già attiva: il noop della stessa URL non deve consentire a una
richiesta intermedia di aprirsi dopo. Il task cancellato invalida soltanto il
proprio token, non quello eventualmente successivo. Le attese terminate o
cancellate rilasciano le proprie continuazioni. La selezione della richiesta
valida viene ricontrollata prima di attivare una candidata dopo un await.

Non si promette rollback di commit già validamente completati. I task attivi
non vengono cancellati soltanto per rendere il modello libero: mantengono i
propri contratti terminali e `run` rimane owner dello stato occupato.

**Ready** prima del fix del modello. Il RED riproduce il difetto prima del fix;
non è attestata retroattivamente una lettura della scheda prima della prova. iPadOS
conserva il comportamento esistente. Il perimetro resta automatico: nessuna
prova di finestre SwiftUI reali, autosave, file provider, VoiceOver o G4 viene
inferita dai test hostless.
