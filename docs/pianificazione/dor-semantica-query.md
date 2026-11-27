<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ammissione semantica delle query

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-327 |
| Tipo | Correzione di correttezza |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di perfezionare codice e semantica |
| Riferimenti | GS-QRY-001; GS-STD-001-29; GS-API-003; RF-015; RQ-042; RQ-058; RQ-060; RQ-062; RQ-063; CMP-327 |

## Definition of Ready

La valutazione può interrompere un `AND` falso prima di incontrare un campo o
uno scope non supportato. La stessa richiesta può quindi apparire valida o
fallire a seconda dei dati. Il sottoinsieme regex interpreta inoltre escape
non supportati e intervalli di classe come caratteri letterali, cambiandone il
significato senza una failure.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Ammettere le capability dell'intero AST prima della scansione; rifiutare sintassi regex non implementata invece di reinterpretarla; mantenere i risultati delle query supportate |
| requisiti | RF-015 e RQ-042: semantica riproducibile e limiti; RQ-058/060: failure tipizzate; RQ-062/063: evidenze e tracciabilità |
| dominio/API | Stessa API, grammatica testuale e identità AST; ammissione interna di esecuzione distinta da validazione strutturale e codec, che conservano l’algebra completa; nessun backend nuovo |
| failure semantics | `query.unsupported-field` e `query.unsupported-scope`, categoria `insufficientData`, prima dei dati; `query.regex-rejected` per costrutti non implementati; preservare prima i controlli strutturali e di budget |
| esperienza prevista | Kit e CLI condividono il Core; un input non supportato non viene presentato come risultato vuoto; nessun controllo visivo nuovo |
| verifica | Regressioni rosse sulla baseline e verdi sul candidato per AND, scope, campi, escape e classi; conservare regex ammesse, test Core/Kit e `make verify` macOS; GS-VER-327 |
| dati e migrazione | Nessuna modifica a schema o dati persistenti; non cambia il risultato delle richieste ammesse dal sottoinsieme dichiarato |
| sicurezza/privacy | Solo stringhe sintetiche; nessuna dipendenza, rete, entitlement o diagnostica con contenuto delle fonti |
| prestazioni/sistema | Una visita bounded aggiuntiva dell'AST, limitato a 1.024 nodi/32 livelli; cancellazione durante la visita; nessuna accelerazione o nuova soglia |
| tracciabilità | CMP-327 inizialmente specified; scheda, evidenza e matrice aggiornate nello stesso lotto |
| decisioni e recupero | GS-QRY-001 già impone il rifiuto di capability e regex non supportate; nessuna nuova ADR necessaria; recupero tramite revert del lotto, senza migrazione |

**Ready** prima del primo cambiamento implementativo. Il parser può conservare
un AST sintatticamente valido per una capability futura; la sua esecuzione resta
fail-closed nella slice corrente.
