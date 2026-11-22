<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Verifica bounded del manifest candidato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-183 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di realizzare il programma complementare con attenzione massima alle prestazioni |
| Riferimenti | GS-STD-001-07; GS-DAT-001; GS-SEC-001; RQ-043; RQ-044; RQ-063; CMP-095 |

## Problema e criterio di stop

Quattro percorsi di commit scrivono tramite il descriptor della transazione e
poi rileggono il manifest candidato tramite URL e `Data(contentsOf:)`. La verifica
deve riguardare il file regolare nel descriptor già aperto, entro il budget, e i
byte esatti del manifest atteso prima della pubblicazione.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Un helper comune ai commit import, Artifact, qualitativo e Investigation scrive e verifica il candidato tramite transactionDirectory; replacement finale, cleanup, SQLite e identità della radice restano fuori perimetro |
| requisiti | RQ-043, RQ-044, RQ-063; TV-051/TV-060/TV-072; CMP-095 resta blocked per i residui più ampi |
| dominio/API | Nessun formato o API di prodotto nuova; manifest Equatable e JSON canonico esistenti; solo seam interno di test sul candidato preparato, senza modificare nomi o comportamento produttivo dei checkpoint recovery |
| failure semantics | Manifest troppo grande, non regolare, link, dimensione diversa o byte differenti: failure tipizzata prima del publish; radice e fonti precedenti restano validi e successivo commit sano riutilizzabile |
| esperienza prevista | Nessuna UI nuova; failure attraverso tassonomia esistente senza path o contenuto; progetto precedente riapribile |
| verifica | Mutazioni sintetiche deterministiche del candidato: troncato, oltre budget, symlink, hardlink, FIFO e JSON valido ma diverso; verifica mancata pubblicazione, dati invariati e recovery; positivi per i quattro percorsi e `make verify`; GS-VER-183 candidata |
| dati e migrazione | Serializzazione unica canonica, limite prima della scrittura e lettura bounded; confronto esatto e decode/validate del manifest atteso; nessuna migrazione |
| sicurezza/privacy | Apertura no-follow dal descriptor già aperto, fstat tipo regolare/nlink/dimensione prima dell'allocazione e controllo finale; dati sintetici locali, nessun privilegio, rete o nuova dipendenza |
| prestazioni/sistema | Riutilizzo helper sui quattro percorsi, lettura a chunk bounded ai byte attesi più sentinella, massimo manifest esistente 1 MiB; nessun hash o copia del corpus aggiunti |
| tracciabilità | CMP-183 inizialmente specified; evidenza e registri dopo verifica; CMP-095 non viene promosso né si dichiara contenuta l'intera transazione |
| decisioni e recupero | Applicazione dei contratti DAT/SEC già esistenti; nessun backend nuovo; rollback per revert senza modifica dei file persistenti |

**Ready** registrata prima del coding. Non si attesta assenza di corse fra ultima
verifica e replacement URL, protezione degli antenati, cleanup descriptor-relative
o durabilità ai power loss. Il seam dei test non è una superficie pubblica di
prodotto e i checkpoint del recovery harness restano compatibili.
