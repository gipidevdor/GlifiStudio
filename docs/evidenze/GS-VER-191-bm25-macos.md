<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-191 — Ranking BM25 nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-191 |
| Tipo | Evidenza di integrazione e verifica applicativa |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-191; ADR-0033; GS-UX-001-17; RF-030; RQ-003; RQ-058 |

## Perimetro e identità

L'incremento B di GS-PLAN-002 usa `rankDocumentsBM25` nel laboratorio macOS
con ambito tutte/selezionate e query lessicale distinta da QueryAST/KWIC.
Metodo, `k1`, `b`, termini effettivi e lineage restano ispezionabili. La richiesta
effettiva è conservata separatamente dal draft.

Tutti i documenti restituiti da Kit restano visibili nell'ordine score decrescente
e ID crescente, inclusi i punteggi zero. I termini fuori vocabolario sono
dichiarati con contributo nullo; score zero non diventa assenza di risultato.
La fonte si apre intera senza inventare intervalli di occorrenza.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con gli
incrementi macOS e quelli algoritmici concorrenti preservati. Nessuna nuova
revisione o CI remota viene attestata. La DoR precede il codice; l'avvio segue
la stabilizzazione del laboratorio GS-DOR-190 e il coordinamento esplicito.

## Contratto di verifica

Parità integrale con Kit, parametri non predefiniti e ambito selezionato,
pareggi/punteggi zero/OOV, failure con risultato precedente e sessione conservati,
riuso dell'Artifact, richiesta effettiva distinta dal draft e pulizia al cambio
progetto. Compilazione del client, gate e preflight macOS sul contenuto integrato.

## Controlli statici dell'implementazione

Client e modello implementati dopo lettura della DoR e avvio coordinato. Gli
incrementi 191/192 aggiungono complessivamente 94 chiavi it/en, conservando le
64 chiavi del riassunto; i controlli mirati di localizzazione e stile sono
superati. Il gate e i test del modello integrato restano da eseguire; nessun
risultato runtime viene dedotto dai soli controlli statici.

## Verifiche mirate osservate

I due nuovi test BM25 verificano confronto integrale con Kit, ambito selezionato,
parametri non predefiniti, termini unici e OOV, ranking completo con score zero e
pareggi per ID, query/KWIC separati, riuso, apertura fonte, failure che conserva
risultato/opzioni e pulizia al cambio progetto.

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
