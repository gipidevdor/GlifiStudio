<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-190 — Riassunto estrattivo nel laboratorio macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-190 |
| Tipo | Evidenza di integrazione e provenienza |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico macOS dichiarato |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-190; ADR-0033; GS-UX-001-17; RF-042; RF-077; RF-078 |

## Perimetro e identità

Incremento A di GS-PLAN-002: riassunto nel laboratorio macOS come client delle
API GlifiKit esistenti, con ambito esplicito, budget frasi/token, due metodi di
punteggio e ridondanza assente/MMR. L'elenco applicativo dei metodi rimane
esplicito: nuovi algoritmi introdotti da altre unità non compaiono automaticamente.

Copia di lavoro basata su `a86a53b512bd777f191c89692e0c573a3d37a3ff`, con gli
incrementi macOS e le modifiche algoritmiche concorrenti preservati. Nessuna
nuova revisione o CI remota viene attestata.

## Contratto di provenienza

Gli offset della frase e il testo restituito appartengono al testo estratto.
Il resolver Core calcola `sourceRanges` con SpanMap; GlifiKit li espone nella
frase selezionata. La fonte originale usa soltanto questi intervalli, mai gli
offset estratti applicati direttamente ai byte originali. Artifact, descriptor,
formule, score e selezione persistiti non cambiano.

Un DTO precedente senza `sourceRanges` decodifica un elenco vuoto, con significato
di mapping non disponibile: la fonte si apre intera senza highlight e il limite
viene indicato. Non si inventano coordinate per compatibilità.

## Contratto di verifica

- Core/Kit: Markdown, BOM e Unicode multibyte, testo estratto intatto, mapping
  originale da SpanMap, riuso dell'Artifact e decodifica dei DTO precedenti.
- Modello macOS: scope e parametri effettivi, budget, metodo e ridondanza, frasi
  selezionate, apertura della fonte e conservazione del lavoro su failure.
- Cambio progetto: pulizia dello stato del laboratorio precedente.
- Stringhe it/en, whitelist dei due metodi, componenti nativi e build del client.
- Gate esplicito macOS e preflight senza firma sul contenuto integrato.

## Primo tentativo di compilazione

Il primo tentativo mirato del mapping si arresta compilando il test esterno
concomitante `GlifiLexicalStatisticsFacadeTests.swift`: accessi a `category` e
`retainedState` su `any Error`. Non è un risultato positivo dei test del mapping
e non viene attribuito ai sorgenti dell'incremento 190. Il file esterno viene
preservato; occorre una nuova esecuzione sul contenuto stabilizzato.

## Revisione statica del mapping

Revisione indipendente limitata ai quattro file Core/Kit del mapping e ai due
`GlifiSummarySourceMappingTests.swift`, senza attribuire una verifica agli algoritmi
concomitanti: nessun difetto concreto rilevato. Il resolver usa SpanMap e testo
della medesima revisione; il campo non entra nel payload persistito. I test
includono TXT con BOM, Markdown con BOM e Unicode, entità derivazionale la cui
origine differisce dal testo estratto, riuso dell'Artifact senza nuova generazione
e round trip/compatibilità legacy Core e Kit.

La view dichiara due soli metodi e contiene 64 nuove chiavi it/en controllate;
`check-localization` è superato. Questi controlli statici non sostituiscono
compilazione, test e gate del contenuto integrato.

## Verifiche mirate osservate

Dopo la correzione del test esterno, la nuova esecuzione mirata supera **un test
Kit e un test Core** del mapping. Il test Core contiene i tre casi TXT/BOM,
Markdown/BOM/Unicode ed entità derivazionale; quello Kit verifica il confine e
la compatibilità del DTO. Nessuna nuova formula viene verificata da questa prova.

`make test-macos` sul client del laboratorio termina con **exit 0**:
**19 test dichiarati, 20 esecuzioni, 0 fallite, 0 saltate**. La differenza deriva
da un test parametrico eseguito per entrambi i metodi. Le cinque nuove esecuzioni
coprono scope tutte/selezionate, budget/metodo/MMR, parità con Kit e riuso,
fonte Markdown/BOM/Unicode separata da query/evidence, fallback legacy vuoto,
pulizia al cambio progetto, failure con risultato preservato ed esito senza
frasi eleggibili. La suite conserva gli incrementi GS-VER-185…187.

Lint strict dei file del modello e dei test e `git diff --check` superati.
Il successivo gate e il preflight macOS sono superati; CMP-190 è `verified` nel perimetro dichiarato.

## Residuo statico dell'audit macOS

Il codice preesistente dei testi di fonte KWIC ed evidence usa etichette
accessibili sostitutive (`query.source`, `finding.evidence.source`) senza un
valore accessibile del contenuto. Il rilievo è registrato in GS-PLAN-002; non è
una prova VoiceOver né una correzione già verificata da GS-VER-190. La verifica
dell'incremento non equivale a zero problemi di accessibilità.

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

Il riassunto estrattivo non è generazione né un nuovo finding scientifico.
L'incremento non completa BM25, frequenze/MTLD, Zipf/Heaps, metadati o tutte le
famiglie headless. La baseline 0.1 storica resta invariata. Mac bloccato e scelta
esplicita di soli test automatici: GUI reale, VoiceOver, utenti, dispositivi e G4
restano aperti; iPadOS è rimandato.
