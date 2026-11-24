<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Anteprima export macOS fuori dal Main Actor

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-194 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Audit macOS automatico e completamento dei difetti concreti richiesti dall'iniziatore |
| Riferimenti | RQ-013; RQ-044; GS-APL-006; GS-API-001; ADR-0002 |

## Problema e criterio di stop

Dopo l'export autorevole, il modello MainActor legge integralmente `report.md`
con `Data(contentsOf:)` per un'anteprima facoltativa. Spostare soltanto tale
lettura e la decodifica fuori dall'actor, con memoria e I/O bounded e fallimento
best effort coerente con l'attuale anteprima opzionale.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Loader interno app macOS nel file del modello esistente: metodo nonisolated `@concurrent` asincrono che restituisce String opzionale; il modello lo attende dopo receipt e snapshot; iPadOS invariato |
| requisiti | RQ-013, RQ-044; lettura/decodifica fuori dal Main Actor, massimo 1 MiB di Markdown UTF-8 integrale; oltre il limite nessuna anteprima troncata né contenuto parziale |
| dominio/API | Nessuna API Kit/Core o formato nuovo; helper testabile interno, URL di `report.md` della destinazione autorizzata; receipt e generazione dell'export non dipendono dal successo dell'anteprima |
| failure semantics | File assente, non regolare, link simbolico finale, non UTF-8, oltre budget, I/O fallita o task cancellata: nil; nessuna failure dell'export aggiunta o receipt cancellata; nessun retry o rollback scientifico |
| esperienza prevista | Anteprima opzionale come prima, ora integrale soltanto entro budget; receipt e accesso ai file esportati restano validi quando la preview manca; nessun nuovo controllo o testo richiesto |
| verifica | Helper: UTF-8/BOM/Unicode, limite esatto e più un byte, file assente/invalido/directory/symlink/FIFO e pre-cancellazione; modello: export riuscito con receipt e preview uguale al report; review annotazioni di isolamento e profilo macOS/preflight; GS-VER-194 candidata |
| dati e migrazione | Report autorevole, manifest, digest e protocollo di commit invariati; solo copia effimera di anteprima con limite dichiarato, nessuna migrazione |
| sicurezza/privacy | Solo file URL, apertura finale no-follow/nonblocking, fstat su file regolare, letture limitate a chunk e sentinella contro crescita, numero di byte coerente con stat iniziale e finale; security scope della destinazione attivo fino alla fine dell'await, descriptor sempre chiuso; nessun nuovo privilegio o log |
| prestazioni/sistema | Budget 1 048 576 byte; nessuna lettura integrale prima del controllo del limite, controllo di crescita durante la lettura e decodifica UTF-8 fuori actor; nessuna ottimizzazione numerica o benchmark prestazionale millantato |
| tracciabilità | CMP-194 inizialmente `specified`; RQ-013/RQ-044 e TV-018/TV-060, evidenza e CHANGELOG nello stesso incremento |
| decisioni e recupero | GS-APL-006 e preview già facoltativa; nessuna nuova decisione di persistenza; lettura/coordinamento del responsabile dopo B/C prima del codice; revert limitato al ramo macOS |

**Ready** per il contratto circoscritto. La lettura bounded dell'anteprima non
sostituisce la verifica scientifica dell'export, né certifica l'identità del
bundle sotto sostituzioni concorrenti, mutazioni della stessa dimensione o file
provider. Profiling con Instruments,
GUI reale, iPadOS e G4 restano distinti; nessun nuovo controllo EA viene promosso.

## Avanzamento

Quattro nuovi test del loader e dell’export reale superati nella prova integrata: target
macOS con 33 definizioni e 37 esecuzioni, senza failure o skip. CMP-194
`verified` dopo gate/preflight macOS; nessuna chiusura di G4.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
