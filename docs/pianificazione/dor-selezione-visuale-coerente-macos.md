<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Selezione visuale e contesto fonte coerenti su macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-232 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Difetto correlato confermato; policy del mark senza fonti approvata prima del codice |
| Riferimenti | RF-084; RQ-028; RQ-047; RQ-058; GS-UX-001-09; GS-DOR-166; GS-STD-001-07 |

## Problema e criterio di stop

`selectVisualMark` scrive l'identificatore prima dell'admission di `run` e del
caricamento; un mark senza fonti lascia inoltre il contesto Evidence precedente.
Il client macOS deve mostrare soltanto selezione e contesto reciprocamente
coerenti, preservando l'ultimo stato valido quando busy o caricamento fallito
impediscono di pubblicare il nuovo stato.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Solo selettore visuale macOS e contesto fonte Evidence: nessuna selezione anticipata; ID e contesto pubblicati senza await intermedio dopo fetch. Un mark senza fonti, se ammesso da run, viene selezionato e azzera il contesto Evidence senza I/O; iPadOS conserva il ramo precedente |
| requisiti | RF-084 e RQ-028/047/058; origine della selezione e contesto corretti, assenza di falsa precisione, busy/failure conservano selezione, testo, ranges e focus precedenti |
| contratto di dominio/API | DTO e metodo asincrono esistenti; `run` resta owner di admission/busy/cleanup. Con fonte si carica in variabile locale prima di assegnare `selectedVisualMarkID`, `evidenceSourceText`, ranges vuoti e `focusedEvidenceID = nil`; senza fonti si assegnano ID, testo nil, ranges vuoti e focus nil nello stesso turno Main Actor |
| failure semantics | Errori di sessione/caricamento esistenti e tipizzati, nessun nuovo codice o recupero fittizio; nessuna assegnazione parziale su failure. Il mark senza fonti non produce una falsa failure di caricamento, ma non eredita una fonte estranea; busy impedisce anche questo aggiornamento |
| esperienza prevista | Stessa selezione del grafico e dettaglio della fonte intera, senza inventare intervalli esatti dal lineage contributivo; nessuna nuova funzione, destinazione, label o policy di ranking; interazione nativa e accessibile preservata |
| verifica | Test deterministici con due fonti/mark e opener sospeso: RED prima del fix; GREEN per busy e failure con vecchio stato integro, retry e pubblicazione coerente del mark con fonte, mark senza fonti che azzera il contesto soltanto quando ammesso. Test nel target macOS e review del ramo iPad invariato; GS-VER-232 candidata, gate/preflight sul nuovo contenuto |
| dati e migrazione | Soli stati effimeri, nessuna modifica a VisualizationSpec, coordinate, Artifact, package, storia, metodi scientifici o schema; nessuna migrazione |
| sicurezza/privacy | Confini di sessione e fonti autorizzate invariati; nessuna rete, dipendenza, entitlement o dato nuovo nei log; nessun contesto attribuito a un mark privo di quella fonte |
| prestazioni/sistema | Stesso fetch Kit bounded e nessun I/O nel caso senza fonte; nessuna attesa attiva o nuova elaborazione onerosa sul Main Actor. Correzione di stato, senza claim prestazionale |
| tracciabilità | CMP-232 inizialmente `specified`; RF-084 e TV-058/TV-071, evidenza e registri nello stesso incremento; separata dalla selezione KWIC di GS-DOR-230 |
| decisioni e recupero | Invariante di provenienza GS-UX-001-09 già applicabile; policy senza fonte esplicita sopra, nessuna nuova ADR. Revert puntuale macOS senza migrazione, preservando gli altri programmi |

**Ready** prima della patch di produzione. Soltanto prove automatiche:
nessuna attestazione di GUI reale, VoiceOver, iPadOS, autosave, file provider o G4.
