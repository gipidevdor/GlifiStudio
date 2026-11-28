<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Studio documentale persistente

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-007 |
| Tipo | Contratto applicativo e persistente |
| Versione | 1.0.0 |
| Stato | Definito prima dell'implementazione; verifica in GS-VER-344 |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita corrente; ADR-0048 |
| Riferimenti | GS-API-003; GS-DOR-344; GS-UX-001-18; GS-STD-001-11 |

## Operazioni pubbliche e trasporto

`GlifiStudioStudyCommand.execute(json:session:)` ammette lo stesso contratto
delle operazioni tipizzate di `GlifiStudioProjectSession`. La CLI espone
`glifi study-call <progetto.glifi> --request <richiesta.json>`.

```json
{"schema":"studio.glifi.study-command-request","schemaVersion":1,"operation":"state","parameters":{}}
```

| Operazione | API Kit | Parametri |
| --- | --- | --- |
| `state` | `studyState()` | Nessuno |
| `save-state` | `saveStudyState(_:expectedRevision:)` | `state` oppure `statePath`, `expectedRevision` |
| `collect` | `collectStudyExcerpt(sourceRevisionID:selection:title:groupID:expectedRevision:)` | Revisione, selezione di passaggio già definita dal Kit, titolo, gruppo opzionale, revisione attesa |
| `resolve` | `resolveStudyExcerpt(excerptID:)` | `excerptID` |
| `export` | `exportStudy(format:)` | `format`: `json` (default) oppure `markdown` |
| `original` | `studyOriginal(sourceRevisionID:)` | `sourceRevisionID` |

Risultati e failure usano gli envelope GS-API-001, senza ulteriori algoritmi nella
CLI. Data è base64 nei DTO JSON. Ammissione JSON rigorosa: 1 MiB, profondità 32,
nessuna chiave duplicata o sconosciuta, versione verificata e parametri esclusivi
per operazione. `statePath` è alternativa esclusiva al DTO inline: file regolare
di massimo 32 MiB aperto con un solo descrittore non-following e non bloccante,
controllato anche dopo lettura. Restano tutti i limiti di dominio.

`selection` usa le tre forme Codable già condivise dal Kit: `sentences`
(indici `first`/`last` zero-based inclusivi), `characters` (`start`/`end`
half-open in grafemi) oppure `bytes` (`start`/`end` half-open UTF-8).
Anche la selezione in byte deve rispettare i confini dei caratteri. Per esempio:

```json
{"schema":"studio.glifi.study-command-request","schemaVersion":1,"operation":"collect","parameters":{"sourceRevisionID":"<revisione>","selection":{"characters":{"start":0,"end":12}},"title":"Passaggio da studiare","expectedRevision":0}}
```

La costruzione e validazione pura dei DTO resta infrastruttura:
`GlifiStudioStudyState.validate()` controlla limiti e riferimenti interni senza
leggere fonti; `GlifiStudioStudyExport.decode(json:)` ammette rigorosamente la
busta esportata entro 32 MiB più 64 KiB di overhead. Il progetto e le anchor
vengono verificati autorevolmente da `save-state`; il decoder non pubblica dati.

La disponibilità nativa è verificata sullo SDK macOS corrente. Per la lettura si
riusano [NSTextView](https://developer.apple.com/documentation/appkit/nstextview)
e [PDFView](https://developer.apple.com/documentation/pdfkit/pdfview), senza
nuovi framework di terzi. La selezione di presentazione UTF-16 viene convertita
esplicitamente nei confini di carattere prima del resolver UTF-8; i confini non
devono dividere grafemi, secondo il contratto Apple di
[setSelectedRange](https://developer.apple.com/documentation/appkit/nstextview/setselectedrange(_:)).

## Stato e provenienza

`GlifiStudioStudyState` contiene `projectID` obbligatorio, revisione, estratti, note, gruppi, ordine misto,
al massimo due identità di estratti nel confronto e un'indagine opzionale.
Le note contengono titolo, testo, gruppo opzionale e identità di più estratti
di supporto. Titoli, testo delle note, gruppi e ordine sono modificabili.
Anche lo stato vuoto identifica il progetto; il writer verifica tale identità
contro il progetto aperto, così il ripristino non può attraversare progetti.

L'anchor di ciascun estratto è immutabile: revisione della fonte, digest del
contenuto originale, identità/digest della rappresentazione estratta, intervallo
UTF-8 half-open e citazione esatta. `collect` usa il resolver di passaggio
esistente; non deduce offset da una ricerca ambigua. `save-state` rifiuta anchor
modificate per identità esistenti. Un'anchor nuova fornita per ripristino è
ammessa soltanto dopo verifica integrale contro revisioni già nel progetto.
L'identità opaca dell'estratto è SHA-256 dell'anchor canonica completa: non può
essere riassegnata a un altro passaggio dopo eliminazione e ripristino. Le anchor
conservano anche il contratto di estrazione e gli intervalli della vera SpanMap.
Gruppi, note, ordine, confronto e indagine non possono avere riferimenti pendenti.

`resolve` verifica nuovamente digest, rappresentazione, confini e quote; restituisce
il testo estratto originale con intervalli e locatori realmente conservati.
Gli offset estratti non sono offset Markdown originali. `original` restituisce
formato, revisione, digest e byte originali verificati, al massimo 64 MiB.
Il lettore PDF può raggiungere una pagina reale; non attribuisce rettangoli
precisi quando l'estrazione digitale ha conservato solo il numero di pagina.
Né lettura né riapertura eseguono OCR o nuove analisi.

## Formato, limiti e recupero

L'Artifact `studio.glifi.artifact.study-state.v1` conserva schema/versione, nodo,
predecessore e stato completo. La catena è append-only, ottimistica e verificata;
il descriptor v2 ha selezione vuota. La revisione attesa e quella proposta devono
corrispondere allo stato corrente. Importazioni indipendenti conservano lo stato.
Reader 4 lazy, compatibilità 1/2/3 e recupero sono governati da ADR-0048.

Limiti: 1.000 estratti, 1.000 note, 200 gruppi, 10.000 revisioni; massimo 1 MiB
per citazione o testo di nota, 32 MiB per stato e 64 MiB per testo risolto/originale.
Titoli entro 512 byte, identità locali ASCII entro 64 byte, al massimo 10.000
intervalli source per anchor e 1.000 riferimenti a passaggi per nota.
Si controllano byte totali e collezioni prima del commit. Il superamento è
`insufficientResources`, dati non validi sono `invalidInput`, conflitto
`staleArtifact`, corruzione persistente `corruption`. I codici di dominio
usano il prefisso `study.`. Cancellazione preventiva o durante la preparazione
non pubblica una generazione; la UI conserva l'ultimo contesto completo valido.

## Esportazione e significato

JSON canonico `studio.glifi.study-export`, versione 1, conserva projectID e stato
completo. Il ripristino usa il DTO `state` nello stesso progetto, con la revisione
corrente esplicitamente attesa; non importa fonti mancanti e non riusa un export
di un altro progetto senza verifica. L'export Markdown presenta passaggi, fonti
e conclusioni leggibili. Esportare due volte lo stesso stato produce gli stessi
byte; riaprire il progetto non esegue calcoli superflui.

Una conclusione è un'annotazione della persona. L'associazione a un'indagine
organizza il lavoro e non genera automaticamente Evidence, Finding o passi del
planner eseguiti. L'export di studio rimane riconoscibile come taccuino manuale,
separato dal rapporto scientifico esistente.
