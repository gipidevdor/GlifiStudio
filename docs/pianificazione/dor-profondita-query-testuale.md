<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Profondità dell'AST delle query testuali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-181 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta di attività complementari e programma di piena produttività |
| Riferimenti | GS-STD-001-07; GS-QRY-001; RQ-042; RQ-063; TV-053; TV-060 |

## Problema e criterio di stop

Il parser limita parentesi e NOT, ma non la profondità dell'AST prodotto da
AND, OR e catene NEAR/BEFORE. Una catena di 34 termini genera profondità 33,
accettata dal parser con limite 32 e rifiutata dal valutatore.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | `GlifiQueryParser.parse` restituisce soltanto AST entro `maximumDepth`; radice a zero e incremento di uno per arco; ownership limitata a parser e suoi test |
| requisiti | RQ-042, RQ-063; GS-QRY-001 definisce profondità, limiti e failure tipizzate |
| dominio/API | Nessuna API, grammatica, schema, ordinamento o algoritmo analitico nuovo; validazione semantica del valutatore invariata |
| failure semantics | Oltre soglia: `query.depth-limit-exceeded`, categoria `insufficientResources`, diagnostica senza contenuto; i limiti sintattici e di byte/nodi restano attivi prima di lavoro non limitato |
| esperienza prevista | Il medesimo input non viene prima accettato dal parser e poi rifiutato per profondità dal valutatore; nessuna modifica UI |
| verifica | Regressioni NEAR/BEFORE al limite 32 e oltre, AND/OR/NOT misti, radice a zero e parità con decoder AST; confronto prima/dopo, test query e `make verify`; GS-VER-181 candidata |
| dati e migrazione | Nessuna scrittura o migrazione; gli input oltre il budget già normativo sono rifiutati prima di restituire l'AST |
| sicurezza/privacy | Query non fidata; visita bounded e non ricorsiva del risultato, byte/nodi e guardie sintattiche preservati; nessun dato reale o rete |
| prestazioni/sistema | Visita lineare nei nodi ammessi, senza ricorsione aggiuntiva; nessuna ottimizzazione o promessa di benchmark |
| tracciabilità | CMP-181 inizialmente `specified`; TV-053/TV-060, GS-VER-181 e registri aggiornati dopo la verifica |
| decisioni e recupero | Applicazione di GS-QRY-001, nessuna nuova ADR; rollback della correzione senza formato persistente coinvolto |

**Ready** registrata prima del coding. Nessuna promozione della query streaming,
dell'indice o dell'audit G4 deriva da questo incremento.
