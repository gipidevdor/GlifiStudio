<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ranking BM25 nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-191 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | ADR-0033; GS-PLAN-002, incremento B; richiesta esplicita di completamento analitico macOS |
| Riferimenti | RF-030; RQ-003; RQ-058; GS-MET-001-07; GS-UX-001-17; GS-VER-115 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Classificare i documenti tramite `rankDocumentsBM25` nel laboratorio macOS esistente; scope condiviso tutte/selezionate; nessuna nuova formula o capability planner |
| requisiti | RF-030, RQ-003, RQ-058; richiesta effettiva e risultato Kit concordi, tutti gli ID e ordinamento preservati; punteggi zero visibili, non eliminati come assenza di risultato |
| dominio/API | API Kit esistente con `sourceRevisionIDs`, query lessicale, `k1` e `b`; query distinta dal campo QueryAST/KWIC; normalizzazione e termini unici eseguiti dal motore; richiesta effettiva conservata con il risultato nel modello |
| failure semantics | `k1` finito e positivo, `b` in `[0,1]`, query con token e corpus applicabile secondo API; failure tipizzata senza correzione silenziosa, risultato valido precedente identificato e conservato; nessun ranking parziale marcato completo |
| esperienza prevista | GS-UX-001-17: trovare documenti pertinenti, campi nativi e label it/en, default `k1=1,2` e `b=0,75`, dettagli di metodo/parametri/lineage; punteggio non presentato come probabilità |
| verifica | Modello: confronto integrale con Kit, parametri non predefiniti e scope selezionato, pareggi/score zero/OOV, query lessicale distinta da QueryAST, failure con risultato/sessione conservati, riuso e cambio progetto; gate macOS e preflight; GS-VER-191 candidata |
| dati e migrazione | Artifact `corpus-bm25-ranking-v1` e descriptor invariati, riuso esistente; nessun formato o dato di progetto nuovo; richiesta UI effimera e ripulita al cambio progetto |
| sicurezza/privacy | Solo revisioni del progetto e API Kit; apertura fonte intera senza inventare match/range KWIC; nessuna rete, dipendenza, entitlement o nuovo logging |
| prestazioni/sistema | Calcolo, limiti e admission Kit esistenti fuori dal Main Actor; visualizzazione bounded dei documenti restituiti, nessun ranking o filtro numerico nella view |
| tracciabilità | CMP-191 inizialmente `specified`; RF-030/RQ-003/RQ-058, TV-029/TV-058/TV-071, evidenza, inventario e CHANGELOG nello stesso incremento |
| decisioni e recupero | ADR-0033, GS-MET-001-07; nessuna nuova decisione scientifica; dipendenza da GS-DOR-190 stabilizzato, rollback limitato a B senza migrazione |

## Ordinamento e interpretazione

Il risultato Kit contiene tutti i documenti dello scope, anche con score zero,
ordinati per score decrescente e poi `sourceRevisionID` crescente. La UI conserva
questa sequenza. Termini fuori vocabolario restano dichiarati e contribuiscono
zero; il motore riduce la query ai termini normalizzati unici. Score tutti nulli
non indicano un errore tecnico e non dimostrano assenza di contenuto pertinente.

La fonte si apre intera: BM25 non restituisce intervalli di occorrenza. Metodo,
`k1`, `b`, termini effettivi, document frequency, lunghezza media, numero di
documenti e lineage restano ispezionabili. La query modificata dopo il calcolo non
cambia la richiesta associata al risultato mostrato.

**Ready** per il contratto. Il codice parte soltanto dopo stabilizzazione di
GS-DOR-190 e coordinamento esplicito del responsabile. iPadOS, GUI manuale, G4,
altre varianti di ranking e modifiche a QueryAST sono esclusi.

## Avanzamento

Due nuovi test BM25 superati nella prova integrata: target
macOS con 33 definizioni e 37 esecuzioni, senza failure o skip. CMP-191
`verified` dopo gate/preflight macOS; nessuna chiusura di G4.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
