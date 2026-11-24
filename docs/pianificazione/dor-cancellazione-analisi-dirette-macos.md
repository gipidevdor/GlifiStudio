<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Cancellazione delle analisi dirette macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-195 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Completamento della cancellazione nei flussi analitici macOS richiesto dall'iniziatore |
| Riferimenti | RQ-011; RQ-058; GS-API-001 §§ 6–8; GS-APL-001; GS-DOR-165; ADR-0033 |

## Problema e criterio di stop

GlifiKit coopera con la cancellazione del task, ma le analisi dirette del client
non possiedono un handle azionabile dalla barra di stato. Integrare la richiesta
di annullamento nei sei flussi: riassunto, BM25, frequenze/ngrammi, MTLD, profilo
corpus e keyness diretti. La pulizia resta del task proprietario, come nel fix
GS-VER-186; non si dichiara terminata un'operazione alla sola pressione di Annulla.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Helper interno `runAnalysis` su macOS con `Task<Void, Error>` posseduto dal modello; sei callback analitiche lo usano; barra di stato esistente espone Annulla; nessuna API Kit/Core nuova |
| requisiti | RQ-011, RQ-058; annullamento ripetibile, propagazione dal chiamante al figlio, handle e busy posseduti fino al terminale; risultati/receipt già validi conservati e retry utilizzabile |
| dominio/API | `run` resta unico owner dello stato occupato; il task figlio è creato dentro lo scope ammesso da `run`, handle liberato soltanto in defer; handler del chiamante cancella il figlio senza modificare stato MainActor |
| failure semantics | `cancelAnalysis` richiede soltanto cancel e non libera handle/busy; esiti Kit tipizzati preservati; un commit già accettato può vincere sulla cancellazione e non è trasformato artificialmente in failure o rimosso; nessun risultato parziale marcato completo |
| esperienza prevista | Un'azione Annulla nella barra esistente per l'analisi attiva; testi it/en e controllo nativo, azioni incompatibili disabilitate fino a fine scope; cancellazione del piano esistente rimane distinta e funzionante |
| verifica | Observer didSet deterministico dell'handle, due richieste cancel e asserzioni immediate di ownership/busy, cleanup terminale, stato valido precedente e retry; cancellazione del task chiamante propagata al figlio; caso tardivo con risultato committato valido senza falsa failure; nessun sleep/polling; profilo macOS e preflight, GS-VER-195 candidata |
| dati e migrazione | Nessun formato o protocollo di commit nuovo; Artifact e receipt validi seguono il contratto Kit, nessun rollback UI dei commit scientifici |
| sicurezza/privacy | Nessuna rete, dipendenza, entitlement, log o dato nuovo; Task/closure sotto isolamento MainActor e handle Sendable per onCancel |
| prestazioni/sistema | Un solo task analitico posseduto per operazione ammessa; I/O/calcolo restano Kit/Core fuori dal Main Actor; niente timer, polling, task detached o lavoro oltre la vita del proprietario |
| tracciabilità | CMP-195 inizialmente `specified`; RQ-011/RQ-058 e TV-012/TV-071, evidenza, laboratorio e CHANGELOG nello stesso cambiamento |
| decisioni e recupero | Contratto asincrono e ownership esistenti, nessuna ADR nuova; ultimo lotto autorizzato prima di freeze e gate; revert limitato al helper e ai sei callsite |

**Ready** prima del codice. Nel ramo iPadOS l'helper delega al `run` originario
senza task aggiuntivo o nuovo controllo UI; lo sviluppo dedicato resta rimandato.
GUI manuale, VoiceOver, G4 e cancellazione di altre operazioni non analitiche non
sono dichiarati completati. Dopo stabilizzazione: freeze dei sorgenti e gate,
senza nuovi ampliamenti spontanei del perimetro.

## Avanzamento

Tre nuove definizioni e otto esecuzioni di cancellazione diretta superate.
Target macOS complessivo: 36 definizioni e 45 esecuzioni, senza failure o skip;
la suite del modello ne contiene rispettivamente 33 e 42. CMP-195 `verified`
dopo il gate integrato macOS. Sorgenti congelati dopo questo ultimo lotto.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
