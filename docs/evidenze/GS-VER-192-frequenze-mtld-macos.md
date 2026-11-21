<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-192 — Frequenze, n-grammi e MTLD nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-192 |
| Tipo | Evidenza di integrazione e verifica applicativa |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-192; ADR-0033; GS-UX-001-17; RF-019; RF-020; RF-027; RQ-003; RQ-058 |

## Perimetro e identità

L'incremento C di GS-PLAN-002 usa le API Kit esistenti di frequenza/ngrammi e
MTLD, con ambito esplicito condiviso nel laboratorio macOS. Parametri, filtri,
unità e lineage effettivi restano ispezionabili e separati dai draft.

Il denominatore è precedente ai filtri; le esclusioni seguono il primo filtro
applicabile. `isTruncated` descrive il limite dell'output scientifico e non la
pagina visualizzata. Le pagine da cinquanta righe esplorano tutto il risultato
restituito senza ricalcolo. Forme e lunghezza minima hanno parametri effettivi
coerenti con l'unità, senza riutilizzare campi non applicabili.

MTLD distingue valori finiti, infinito positivo e assenza per mancanza di token;
nessuno degli ultimi due stati diventa zero. Soglia e ordine della sequenza sono
parte del risultato mostrato.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con gli
incrementi macOS e quelli algoritmici concorrenti preservati. Nessuna nuova
revisione o CI remota viene attestata. La DoR precede il codice; l'avvio segue
la stabilizzazione del laboratorio GS-DOR-190 e il coordinamento esplicito.

## Contratto di verifica

Confronto integrale con Kit per forme, parole, caratteri/padding e Unicode,
filtri/stopword, denominatori, limiti e pagine; MTLD finito/infinito/nullo e scope,
failure con risultato precedente e sessione conservati, riuso e cambio progetto.
Compilazione del client, gate e preflight macOS sul contenuto integrato.

## Controlli statici dell'implementazione

Client e modello implementati dopo lettura della DoR e avvio coordinato. Gli
incrementi 191/192 aggiungono complessivamente 94 chiavi it/en, conservando le
64 chiavi del riassunto; i controlli mirati di localizzazione e stile sono
superati. Il gate e i test del modello integrato restano da eseguire; nessun
risultato runtime viene dedotto dai soli controlli statici.

## Verifiche mirate osservate

Cinque nuove definizioni, otto esecuzioni, coprono quattro unità con Unicode e
stopword, denominatori/esclusioni, parità Kit, 125 righe percorse in tre pagine,
limite di calcolo a 60 righe distinto dalle pagine e risultato vuoto, MTLD
finito/infinito/nullo, scope selezionato, riuso, failure e cambio progetto.

Prima del lotto 195, la prova integrata `make test-macos` termina con **exit 0**: target con
**33 definizioni di test, 37 esecuzioni, 0 fallite, 0 saltate**. La suite
`StudioDocumentLifecycleTests` contiene 30 definizioni e 34 esecuzioni; tre test
concomitanti del monitor runtime completano il conteggio del target e non vengono
attribuiti a questo incremento. Lint strict e `git diff --check` sono superati.
Il successivo gate del programma e il preflight macOS sono superati.

## Verifica integrata sullo snapshot

`make verify-macos` e `Scripts/check-app-store-packaging.sh --macos-only`
terminano entrambi con **exit 0** sullo snapshot descritto in
[GS-VER-188](GS-VER-188-gate-macos.md), manifest SHA-256
`07673ac2d88e369010ea0a065192e3c20ffd24c6ce5a8ee73940e3b309870b5f`.
Il gate conferma **36 definizioni / 45 esecuzioni macOS, 0 fallite, 0 saltate**,
build Debug/Release, analisi statica e archivio macOS senza firma; nessun runtime
warning nei risultati nativi. Tutti i controlli condivisi sono eseguiti.
Il profilo non esegue build iPadOS e non è gate globale, CI, prova di finestre
reali, autosave, audit VoiceOver o G4. Le ottimizzazioni successive di Core,
test e benchmark, avviate da altre sessioni, sono escluse da questa attestazione:
non è implicita compatibilità con la working copy successiva allo snapshot.

## Limiti

Nessuna formula, API scientifica o famiglia nuova; Artifact e descriptor
esistenti invariati. Questo incremento non completa tutte le caratteristiche
dell'analisi testuale, il cui inventario resta in GS-PLAN-002. Mac bloccato e
scelta esplicita di soli test automatici: GUI reale, VoiceOver, utenti e G4
restano aperti; lo sviluppo dedicato iPadOS è rimandato. Firma e App Review non
sono dimostrate dal profilo macOS o dagli archivi senza firma.
