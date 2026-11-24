<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Frequenze, n-grammi e MTLD nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-192 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | ADR-0033; GS-PLAN-002, incremento C; richiesta esplicita di completamento analitico macOS |
| Riferimenti | RF-019; RF-020; RF-027; RQ-003; RQ-058; GS-MET-001-04/05; GS-UX-001-17; GS-VER-116/117 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Due azioni contestuali nello stesso laboratorio macOS: frequenze/ngrammi tramite `analyzeNGramFrequencies`, diversità tramite `analyzeLexicalDiversity`; scope condiviso tutte/selezionate e parametri dichiarati; nessuna formula nuova |
| requisiti | RF-019, RF-020, RF-027, RQ-003, RQ-058; risultati uguali a Kit, intero output restituito esplorabile entro budget, denominatori e limiti distinti, MTLD nullo/infinito distinto dal finito |
| dominio/API | Unità Kit `form`, `word`, `character`, `character-padded`; filtri Kit e soglia MTLD; richieste effettive conservate separatamente dai draft; nessun algoritmo o ordinamento ricostruito nella view |
| failure semantics | Parametri invalidi producono failure Kit senza clamp; stato precedente e sessione conservati; `isTruncated` è limite del calcolo, non paginazione UI; MTLD `nil` non diventa zero e `positiveInfinity` non diventa dato mancante |
| esperienza prevista | GS-UX-001-17: descrivere il lessico con controlli nativi it/en, unità e conteggi leggibili; dettagli di variante/normalizzazione/filtri/soglia/ordine/lineage; nessuna stoplist italiana predefinita |
| verifica | Modello: confronto integrale con Kit, forme/parole/caratteri/padded e Unicode grapheme, filtri/stopword/denominatore, pagine e limite output, MTLD finito/infinito/nullo e scope, failure con risultato preservato, riuso e cambio progetto; gate macOS e preflight; GS-VER-192 candidata |
| dati e migrazione | Artifact `corpus-ngram-frequencies-v1` e `corpus-lexical-diversity-mtld-v1` invariati; richieste/pagine UI effimere; nessun nuovo formato o migrazione |
| sicurezza/privacy | Revisioni del progetto, stopword esplicite della persona e limiti Kit; nessuna rete, dipendenza, entitlement, corpus esterno o divulgazione nelle failure |
| prestazioni/sistema | Admission e calcolo Kit esistenti fuori dal Main Actor; pagina di 50 righe sul risultato immutabile, massimo richiesto esplicito nei limiti API; nessun ricalcolo al cambio pagina |
| tracciabilità | CMP-192 inizialmente `specified`; RF-019/RF-020/RF-027/RQ-003/RQ-058, TV-007/TV-029/TV-058/TV-071, evidenza, inventario e CHANGELOG nello stesso incremento |
| decisioni e recupero | ADR-0033 e varianti GS-MET esistenti; dipendenza da GS-DOR-190 stabilizzato, nessuna nuova decisione scientifica; revert limitato a C senza migrazione |

## Frequenze e filtri

Contratto specifico: GS-MET-001-04, sezione Frequenze filtrate e n-grammi.
Le parole restano nel documento, con punteggiatura esclusa e confini di frase
attraversabili; i caratteri sono grapheme cluster entro una
forma, con `_` di confine nella sola variante padded. Nessun n-gramma di
caratteri attraversa forme diverse.

Forme: `n=1`; parole: `n=1…5`; caratteri: `n=1…10`, con padding soltanto quando
richiesto. Il campo `n` non applicabile alle forme non conserva silenziosamente un
valore di un'altra unità nella richiesta effettiva.

Filtri esposti: stopword esplicite, lunghezza minima in grapheme cluster per le
sole forme, conteggio minimo, document frequency minima e massima proporzione di
documenti. I minimi sono almeno uno, la proporzione è in `(0,1]`; i default sono
`TermFilter-v1` senza esclusioni aggiuntive. Il motore normalizza e segmenta le
unità; la lista di stopword è una lista di forme, non un programma. La UI
accetta una voce per riga, omette righe vuote e rimuove soltanto spazi esterni;
normalizzazione e deduplicazione restano al contratto Core. Nessuna lista
predefinita è aggiunta e resta il limite API di 10 000 voci.

Il massimo di righe richiesto è esplicito, default 1 000, nell'intervallo API
`1…100 000`. Il risultato conserva denominatore e distinti prima dei filtri,
esclusioni attribuite al primo filtro e `isTruncated`. Le righe restituite sono
ordinate per count decrescente e poi valore crescente.

La paginazione da **50 righe** esplora tutte le righe effettivamente restituite
senza ricalcolo. Quantità mostrate, righe restituite, distinti originari e taglio
del calcolo sono distinte. Cambiare risultato o progetto riporta la pagina
iniziale; un output vuoto non espone comandi di pagina impossibili.

## Diversità MTLD

La soglia τ è finita in `(0,1)`, default `0,72`. La API restituisce per documento
e per sequenza concatenata conteggio token, direzione originale, inversa e media,
con ordine canonico dichiarato. La UI presenta tutti e tre gli stati:

- finito: valore scientifico;
- `positiveInfinity`: infinito positivo, con testo accessibile esplicito;
- `nil`: non disponibile per assenza di token, senza zero sostitutivo.

MTLD non è una percentuale, una probabilità o un punteggio universale di qualità.
Soglia e ordine della sequenza restano associati al risultato mostrato.

**Ready** per il contratto. Il codice parte soltanto dopo stabilizzazione di
GS-DOR-190 e coordinamento esplicito del responsabile. iPadOS, GUI manuale,
nuove statistiche descrittive, Zipf/Heaps, annotazione linguistica e G4 sono esclusi.

## Avanzamento

Cinque nuove definizioni e otto esecuzioni lessicali superate nella prova integrata: target
macOS con 33 definizioni e 37 esecuzioni, senza failure o skip. CMP-192
`verified` dopo gate/preflight macOS; nessuna chiusura di G4.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
