<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Dati, lineage e persistenza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DAT-001 |
| Tipo | Specifica di design di dati e persistenza |
| Versione | 1.12.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-19 |
| Approvazione | Baseline proposta; prototipo e benchmark richiesti al gate G2 |
| Riferimenti | GS-DOM-001; GS-MET-001-01; GS-MET-001-02; GS-SEC-001; GS-API-001; ADR-0016; ADR-0019 |

## Scopo e invarianti

Questa specifica governa acquisizione, document model, offset, lineage tecnico,
formato `.glifi`, transazioni, integrità e migrazioni. GS-MET governa il significato
degli artefatti; GS-UX governa come il lineage viene compreso.

- La fonte originale è immutabile e non viene mai riscritta.
- Ogni trasformazione produce una rappresentazione identificata da digest,
  versione e parametri.
- Lo stato autorevole sopravvive a crash; cache e indici sono ricostruibili.
- Nessun offset è valido senza spazio di coordinate e revisione di riferimento.
- Una lettura non verificata o un recupero parziale non diventa stato valido.

## Documento `.glifi`

Il progetto è un package documentale con estensione `.glifi`, Uniform Type
Identifier `studio.glifi.project`, conforme a `UTType.package`. Le app usano
l'infrastruttura document-based di SwiftUI, file coordination e scritture fuori dal
Main Actor. Il package ha questa struttura logica versionata:

```text
Project.glifi/
├── manifest.json
├── store/project.sqlite
├── sources/objects/sha256/aa/<digest>
├── representations/objects/sha256/aa/<digest>
├── artifacts/objects/sha256/aa/<digest>
├── artifacts/descriptors/sha256/aa/<digest>.json
├── investigations/events/sha256/aa/<digest>.json
├── history/                         # riservato a future proiezioni/versioni
└── transactions/<transaction-id>/
```

`manifest.json` contiene formato, generazione committata, project ID, digest degli
elementi radice e requisiti minimi del lettore. `project.sqlite` contiene identità,
relazioni, metadati e riferimenti agli oggetti. Gli oggetti grandi sono file
immutabili content-addressed; SQLite non contiene blob massivi.

Le cache ricostruibili, i file temporanei, i thumbnail e gli indici di sistema
vivono nel container dell'app, fuori dal package, sotto una chiave derivata dal
ProjectID e dalla generazione. Non fanno parte del backup scientifico.

## Tecnologie persistenti

- SQLite di sistema, usato tramite un adapter interno controllato, è il deposito
  relazionale canonico della baseline 0.1.
- SwiftData non è il formato canonico: può essere rivalutato per proiezioni locali
  non autorevoli, ma non deve vincolare schema, migrazioni o interoperabilità.
- JSON canonico conforme a RFC 8785 è usato per descriptor e manifesti quando il
  dominio rientra in I-JSON. Decimali scientifici e valori non finiti usano una
  codifica tipizzata propria, mai coercizioni JSON implicite.
- SHA-256 tramite CryptoKit identifica byte e serializzazioni canoniche. L'hashing
  di file grandi è incrementale e non richiede il file in memoria.
- Ogni formato binario dichiara magic, versione, endian, schema, dimensioni,
  checksum e limiti prima dell'allocazione.

## Incorporazione e riferimenti esterni

La modalità predefinita copia i byte nel package e crea una `SourceRevision`
incorporata. La modalità `externalReference` è una scelta avanzata ed esplicita:
conserva bookmark security-scoped, URL di presentazione non autoritativo, identità
file disponibile e digest osservato all'importazione.

All'apertura, una fonte esterna mancante, non autorizzata o con digest diverso
diventa `externalUnavailable` o richiede una nuova `SourceRevision`; non viene
sostituita silenziosamente. Cambiare modalità crea una revisione e non altera la
provenienza degli artefatti esistenti.

## Pipeline di ingestion

```text
selezione → staging → sniffing → limiti → digest → deduplica → acquisizione
          → estrazione → normalizzazione → segmentazione → commit → indicizzazione
```

1. Il formato è validato da Uniform Type Identifier, signature e contenuto; non
   soltanto dall'estensione.
2. Lettura, digest ed estrazione sono streaming con limite di byte, profondità,
   espansione, pagine, oggetti e tempo.
3. TXT e Markdown MVP accettano UTF-8 valido, con o senza BOM. Altre codifiche sono
   rifiutate con diagnosi e opzione futura esplicita; non si indovina in silenzio.
4. Markdown conserva byte originali e produce testo visibile più struttura
   documentale; nessun contenuto eseguibile viene valutato.
5. PDF digitale, PDF misto e OCR sono famiglie distinte. Il loro supporto resta
   post-MVP finché non superano corpus, limiti e metriche GS-VAL.
6. Un digest già noto consente deduplicazione dei byte, mai fusione automatica di
   identità, metadati o documenti.
7. Una reimportazione cambiata crea una nuova SourceRevision e invalida soltanto i
   discendenti; una reimportazione identica può riusare le rappresentazioni.

## Document model

Una `DocumentRevision` contiene una radice ordinata di blocchi tipizzati:
`heading`, `paragraph`, `listItem`, `quote`, `code`, `tableCell`, `pageBreak` e
`unknown`. Ogni blocco ha ID stabile nella revisione, ordine, attributi validati e
uno o più riferimenti alla fonte. La perdita di struttura è registrata come
Caveat di estrazione.

PDF aggiungerà `PageSpace(page, mediaBox, cropBox, rotation, origin)` e regioni in
punti PDF; OCR aggiungerà poligono, orientamento, motore, versione e confidenza.
Coordinate normalizzate o pixel sono sempre derivate e dichiarano la trasformazione.

## Spazi di coordinate e `SpanMap`

### Stato implementativo 0.1

La slice corrente implementa `plain-text-v1` e `md-extract-v1`: conserva i byte
originali, produce testo UTF-8 estratto senza valutare destinazioni o HTML e crea
un `SpanMap` totale dall'output ai byte della SourceRevision, incluso lo shift del
BOM. I segmenti `exact`, `derivational` e `synthetic` hanno invarianti verificati;
entità HTML usano relazione derivational e il markup rimosso non acquisisce
coordinate fittizie. Query e KWIC restituiscono sia intervallo estratto sia tutti
gli intervalli sorgente contribuenti.

L'estrattore copre la baseline controllata di heading, quote/liste, enfasi, link e
immagini, autolink, codice inline/fenced, commenti/elementi HTML, entità,
separatori e delimiter table. Applica limite globale, profondità 32,
cancellazione e budget lineare di lookahead. Il document model a blocchi completo,
la suite di compatibilità CommonMark, lo streaming e la persistenza separata della
rappresentazione restano aperti; pertanto la conformità Markdown completa non è
ancora dichiarata.

Gli intervalli sono half-open `[start, end)`. Gli spazi canonici sono:

| Spazio | Unità | Uso |
| --- | --- | --- |
| `sourceBytes` | byte della SourceRevision | Verifica dei byte originari |
| `extractedUTF8` | byte UTF-8 della rappresentazione estratta | Lineage tecnico canonico |
| `normalizedUTF8` | byte UTF-8 NFC della rappresentazione analitica | Token, ricerca e analisi |
| `pdfPage` | punti PDF con pagina e trasformazione | Evidenza spaziale PDF |
| `ocrRegion` | poligono nel PageSpace | Provenienza OCR |

Gli indici Swift `String.Index`, UTF-16 e grapheme cluster sono proiezioni di UI e
non sono persistiti come autorità. Ogni intervallo porta representation ID e digest.

`SpanMap` è una sequenza ordinata di segmenti che associa un intervallo di output a
zero, uno o più intervalli di input, con classe:

- `exact`: corrispondenza uno-a-uno verificabile;
- `contributive`: più regioni contribuiscono al risultato;
- `synthetic`: output inserito senza byte sorgente;
- `derivational`: relazione dimostrabile ma non selezione esatta.

Normalizzazione Unicode, newline, rimozione markup, dehyphenation e OCR producono
un nuovo SpanMap. La composizione deve preservare tutte le origini; non si
approssima al “testo più vicino”. `GlifiSpanMap.composed(after:)` compone `C→B` dopo `B→A`
verificando spazi, lunghezze e revisione; la classe composta è la più debole incontrata
nell'ordine `exact` < `contributive` < `derivational`, un tratto `exact` resta tale solo se le
origini formano un unico intervallo della stessa lunghezza, più intervalli esatti diventano
`contributive` e un segmento senza origini è `synthetic` (GS-VER-122). Un token conserva il proprio span di superficie
e può avere componenti con span distinti.

## Commit, autosave e recovery

### Stati e autorità

Sia `Gₙ` la generazione indicata dal manifest autorevole e `Tᵢ` una transazione in
staging. Gli stati ammessi di `Tᵢ` sono `staging`, `prepared`, `committed` e
`discardable`; nessun altro stato è inferito da file presenti. Solo il manifest
radice sostituito con successo rende raggiungibile `Gₙ₊₁`.

| Elemento | Autorità | Regola di recovery |
| --- | --- | --- |
| fonte incorporata e SourceRevision | Autorevole se raggiungibile da `Gₙ` | Mai ricostruita da testo derivato |
| manifest, eventi, identità e metadati | Autorevole | Deve verificare schema, generazione e digest radice |
| Artifact/Findings persistiti | Autorevoli nella revisione che li raggiunge | Non ricalcolati in-place; nuova revisione |
| indice, cache, thumbnail, preview | Rigenerabile | Eliminabile se mancante, stale o corrotta |
| checkpoint analitico | Candidato riusabile | Valido solo con descriptor/input/schema/checksum identici |
| staging e export parziale | Non autorevole | Eliminabile; non viene presentato come risultato |

La presenza nel database o in una directory non conferisce autorità. Le righe e gli
oggetti non raggiungibili dal manifest corrente sono orfani recuperabili o garbage,
mai una generazione implicitamente valida.

### Protocollo di commit

Ogni writer acquisisce file coordination e un lease di generazione; verifica che il
manifest osservato sia ancora `Gₙ` prima del commit. Le righe della nuova generazione
sono append-only rispetto a quelle raggiungibili da `Gₙ`:

1. crea `transactions/<id>` sul volume destinazione con owner, schema, generazione
   base e nonce; nessun nome deriva da input non fidato;
2. scrive nuovi oggetti immutabili, descriptor ed eventi, poi verifica lunghezze,
   digest, schema e invarianti;
3. promuove per digest gli oggetti mancanti senza sovrascrivere un oggetto diverso;
   una collisione di path con byte differenti è corruzione;
4. in una singola transazione SQLite inserisce relazioni, radici ed un record
   `prepared` per `Gₙ₊₁`; il commit SQLite rende il candidato durevole ma non
   autorevole e preserva integralmente `Gₙ`;
5. forza la durabilità prevista dal profilo SQLite approvato e rende consistenti
   database/WAL prima di costruire il manifest candidato;
6. serializza e verifica il manifest candidato, che include generazione base,
   generazione nuova, digest del record prepared e radici; lo scrive in una
   directory di sostituzione sullo stesso volume;
7. ricontrolla lease e `Gₙ`, quindi sostituisce il solo `manifest.json` tramite file
   coordination e primitiva di sostituzione sicura del sistema;
8. marca `Gₙ₊₁` committed e `Tᵢ` discardable in manutenzione post-commit idempotente.

Il manifest è il commit point. La sua sostituzione riuscita al punto 7 è l'unico
evento che cambia la generazione autorevole. Un
crash prima lascia autorevole `Gₙ`; un crash dopo lascia autorevole `Gₙ₊₁`, anche
se cleanup o marcatura post-commit non sono avvenuti. Nessuna UI dichiara successo
prima di aver riaperto o riverificato le radici minime della nuova generazione.

La sostituzione deve avvenire sullo stesso volume. Se filesystem/provider non offre
le precondizioni osservate dal prototipo, il writer interrompe senza modificare il
manifest; non degrada a copia non atomica. La strategia SQLite (`WAL` o rollback
journal, livello `synchronous`, checkpoint e file inclusi nel package) deve essere
fissata dal prototipo G2 e provata con power-loss/kill injection prima di G4.

### Riconoscimento di un progetto incompleto

L'apertura è fail-closed e segue questo ordine:

1. limita dimensione e decodifica del manifest senza seguire link;
2. verifica magic, versione, ProjectID, generazione e digest radice;
3. apre lo store nella modalità minima e verifica schema, foreign key e record della
   generazione indicata;
4. verifica presenza, tipo, lunghezza e digest di ogni oggetto autorevole radice;
5. controlla che nessuna reference esca dal package e che la generazione sia
   semanticamente completa;
6. soltanto allora espone la sessione read-write.

Manifest illeggibile, generazione assente, record non prepared/committed, radice
mancante, digest errato, schema incompatibile o reference illegale producono
`corruption`/`incompatibleVersion`. Il recovery può aprire l'ultima generazione
precedente interamente verificabile, read-only, senza riscrivere l'originale. Se non
esiste una generazione verificabile, il file resta intatto e viene rifiutato.

### Matrice di interruzione

| Operazione | Prima del commit point | Dopo il commit point | Ripresa consentita |
| --- | --- | --- | --- |
| import | byte/staging eliminabili; nessuna SourceRevision | nuova revisione completa autorevole | da sorgente o staging solo se digest e scope coincidono |
| indicizzazione | indice parziale eliminabile | generazione dati valida; indice può risultare stale | ricostruzione dall'input autorevole |
| Analysis DAG | nodi parziali non sono Artifact | Artifact raggiungibili restano storici e validi | checkpoint verificato per nodo/descriptor |
| autosave | eventi coalesced non committati possono mancare | tutti gli eventi della generazione sono visibili | nuovo autosave da stato dominio valido |
| migrazione | copia candidata eliminabile; originale intatto | nuova copia verificata; backup conservato | mai continuare una copia di validità ignota |
| export | file parziale resta staging e viene eliminato | receipt e manifest corrispondono ai byte finali | nuova destinazione o replace sicuro |

Cancellazione e crash vengono iniettati dopo ogni passo numerato, prima/dopo commit
SQLite, prima/dopo replace del manifest e durante cleanup. Il test verifica sia
l'apertura sia l'assenza di generazioni “quasi valide”.

### Autosave, concorrenza e manutenzione

Autosave coalesca eventi di dominio e apre una nuova transazione; non si inserisce
in un commit già avviato. Un solo writer per package è ammesso nella 0.1. Un lease
stale non viene rotto finché identità processo, file coordination e generazione non
dimostrano che non esiste un writer attivo.

Garbage collection opera solo su oggetti non raggiungibili da alcuna generazione o
backup trattenuto e soltanto dopo una riapertura verificata. Il cleanup è
interrompibile e non modifica il manifest. Cache e indici dichiarano ProjectID,
generazione, schema e digest degli input; una divergenza causa eliminazione e
ricostruzione, non recovery dell'autorità.

## Schema e compatibilità

La prima versione è `formatVersion = 1`. Ogni cambio incompatibile incrementa la
major del formato; aggiunte ignorabili incrementano la minor. Il lettore deve:

- leggere e scrivere la versione corrente;
- leggere la precedente major `N-1` quando ne esisterà una e migrarla soltanto su
  copia transazionale con backup recuperabile;
- aprire in sola lettura, oppure rifiutare senza modifiche, una versione futura;
- conservare versioni di algoritmi e findings storici; il ricalcolo è una nuova
  revisione, non una riscrittura della storia;
- non promettere downgrade. L'export interoperabile è la via di uscita supportata.

## Integrità, minacce e limiti

Prima di seguire un path del package si rifiutano assoluti, `..`, symlink,
hard-link inattesi e collisioni Unicode/case. Ogni conteggio è validato prima
dell'allocazione. Package, database e oggetti corrotti aprono in modalità di
recupero senza eseguire query o parser su contenuto non validato.

Il controllo integrità verifica manifest, schema, foreign key, digest, oggetti
mancanti e raggiungibilità. La riparazione non inventa dati: può ricostruire cache,
isolare oggetti corrotti, recuperare una generazione precedente e produrre un
rapporto locale privo di contenuto del corpus.

## Export e assenza di lock-in

Ogni export è `humanReadable` o `machineReadable`. Il primo privilegia PDF/Markdown;
il secondo usa UTF-8 CSV/TSV e JSON documentato. Matrici e grafi possono avere
formati sparsi dichiarati. Nessun export contiene fonti complete per default se la
selezione non lo richiede esplicitamente.

### `ExportManifest` v1

Ogni export scientifico include `export-manifest.json`, serializzato come I-JSON
canonico RFC 8785. Campi obbligatori:

| Campo | Contratto |
| --- | --- |
| `schema`, `schemaVersion` | `studio.glifi.export-manifest`, intero `1` |
| `exportID`, `createdAt` | UUID e RFC 3339 UTC per audit; esclusi dall'identità scientifica |
| `software` | nome, versione prodotto, build e revisione sorgente se disponibile |
| `platform` | sistema, versione, architettura e toolchain; nessun nome utente/device |
| `project` | ProjectID pseudonimizzabile, generazione e digest del manifest sorgente |
| `corpus` | CorpusID, digest canonico, algoritmo digest e SourceRevision digest ordinati |
| `analysis` | ArtifactID, descriptor completo/digest, algoritmo/versione e parametri canonici |
| `preprocessing` | sequenza ordinata di trasformazioni con ID, versione, parametri e digest |
| `backend` | ID/versione, politica numerica, modello/digest e seed quando applicabili |
| `determinism` | classe D0/D1/P1/N1, tolleranze e fonti di variabilità |
| `selection` | scope e filtri canonici dell'export, senza path di presentazione |
| `files` | path relativo generato, media type, schema, byte count e SHA-256 di ogni file |
| `provenance` | Artifact/input ID, digest del lineage e Caveat applicabili |
| `validation` | ValidationManifest ID/digest, stato ed evidenze GS-VER applicabili |
| `presentation` | locale e fuso usati soltanto per formattazione umana |

Il `corpus.digest` è SHA-256 del JSON canonico della lista ordinata per
SourceRevisionID di coppie `{id, contentDigest}` più la versione del criterio di
selezione del corpus. Path, ordine di importazione accidentale e nomi visualizzati
non partecipano. `analysis.descriptorDigest` è calcolato sul descriptor canonico;
timestamp, durata, OperationID, backend timing e path di output non vi entrano.

Esempio strutturale ridotto, non fixture numerica:

```json
{
  "schema": "studio.glifi.export-manifest",
  "schemaVersion": 1,
  "exportID": "00000000-0000-0000-0000-000000000000",
  "createdAt": "2026-09-15T00:00:00Z",
  "software": {"name": "Glifi Studio", "version": "0.1.0", "build": "1"},
  "project": {"id": "project:…", "generation": 1, "manifestDigest": "sha256:…"},
  "corpus": {"id": "corpus:…", "digest": "sha256:…", "digestVersion": 1, "sources": []},
  "analysis": {"artifactID": "artifact:…", "descriptorDigest": "sha256:…", "algorithm": {"id": "Frequency-v1", "version": 1}, "parameters": {}},
  "preprocessing": [],
  "backend": {"id": "swift-reference", "version": "1", "numericPolicy": "binary64"},
  "determinism": {"class": "D0", "seed": null, "tolerances": null},
  "selection": {"kind": "artifact", "filters": []},
  "files": [],
  "provenance": {"inputs": [], "lineageDigest": "sha256:…", "caveats": []},
  "validation": {"manifestID": "validation:…", "manifestDigest": "sha256:…", "status": "candidate", "evidence": []},
  "presentation": {"locale": "it-IT", "timeZone": "Europe/Rome"}
}
```

Il manifest e i file vengono scritti nello stesso staging; ogni digest viene
ricalcolato prima della sostituzione finale. Formula injection CSV, escaping
Markdown/JSON, selezione e dati sensibili seguono GS-SEC-001. Un export privo di
manifest valido è incompleto e non riceve `ExportReceipt`.

## Criteri di conformità

- round-trip del package e migrazione con kill injection a ogni commit point;
- test Unicode su ogni trasformazione e composizione SpanMap;
- fuzzing di manifest, package, Markdown e futuri parser PDF/OCR;
- apertura sicura di oggetti mancanti, corrotti, futuri e riferimenti esterni;
- identità di risultato tra esecuzione in-memory, streaming e riaperta;
- nessun blob massivo nel database e nessuna lettura integrale obbligatoria.
- validazione dello schema ExportManifest, digest di ogni file e assenza di path o
  contenuto non selezionato;

## Stato implementativo iniziale

Il primo confine TXT accetta soltanto UTF-8 valido con BOM opzionale, applica il
limite prima della decodifica, conserva i byte immutati e calcola SHA-256 tramite
CryptoKit. File non regolari, link simbolici, input malformati e superamento del
limite producono failure tipizzate senza path o contenuto nei messaggi macchina.

La slice è intenzionalmente bounded a 64 MiB per singola fonte e per singolo
Artifact durante ingestion e commit. Il prototipo G2 crea e riapre package
`.glifi` v1, incorpora gli
originali come oggetti SHA-256, usa SQLite di sistema per generazioni append-only e
adotta la sostituzione del solo manifest radice come commit point. Riapertura,
corruzione dei byte, writer stale e sei checkpoint di interruzione sono coperti da
test; import e Artifact ripetono inoltre tutti i checkpoint in processi separati
terminati con `SIGKILL`, seguiti da riapertura e retry pre-commit. L'harness è un
prodotto SwiftPM diagnostico isolato da GlifiKit e dalle app; GlifiKit e GlifiCLI
attraversano il percorso di produzione privo degli hook SPI.

Il manifest schema 3 e lo store schema 3 mantengono radici distinte per Artifact e
InvestigationHistory nella stessa generazione. Payload e descriptor analitici sono
oggetti distinti content-addressed;
la riapertura verifica path, limiti, digest, ArtifactID, AnalysisNodeID, schema,
dipendenze e riusabilità dell'intera catena prima di esporre il DAG. Il commit è
idempotente per lo stesso nodo/risultato; una sostituzione invalida i discendenti
esatti. L'import di una nuova SourceRevision applica temporaneamente una policy
conservativa e invalida tutti gli Artifact della proiezione corrente, mantenendoli
raggiungibili soltanto dalle generazioni storiche.

Gli eventi cognitivi `studio.glifi.investigation-event` v1 sono invece autorevoli,
content-addressed e append-only. La tabella generazionale conserva ID dell'evento,
InvestigationID, predecessore, digest, byte count e path generato; il root digest
copre la lista canonica completa. Una nuova importazione copia questa radice mentre
azzera gli Artifact ricostruibili. L'apertura ricalcola ID/digest, verifica ogni
arco, rifiuta cicli/orfani e ricostruisce tutti gli head. Lo schema 2, che non aveva
eventi di indagine, migra additivamente allo schema 3 prima della scrittura e resta
apribile durante la transizione.

L'export scientifico PDF/Markdown/CSV/JSON usa una directory di staging sorella della
destinazione, accetta soltanto una destinazione nuova e pubblica il risultato con
un rename dopo aver riletto manifest e payload. `ReportRevisionID`, file e
`ExportManifest` vengono ricalcolati; byte count, SHA-256, descriptor, corpus,
lineage e selezione devono coincidere. Tre checkpoint pre-commit provano che una
failure non rende visibile una directory parziale. La verifica rifiuta link,
entry inattese, path non relativi e byte manomessi. Manifest e report non includono
path o testo completo delle fonti.

Il PDF usa Core Graphics/Core Text in profilo PDF/A-2u, conserva testo ricercabile
e struttura taggata e limita la paginazione. I dati tabellari sono due CSV RFC 4180
UTF-8, `findings.csv` ed `evidence.csv`, con ID/relazioni e payload JSON canonico;
la coppia è indivisibile e le celle formula-like sono neutralizzate. Il verificatore
apre il PDF, controlla l'albero taggato e rigenera i CSV quando è presente il report
JSON. Nomi, media type e schema accettati formano un inventario chiuso.

Il piano, gli output analitici e `studio.glifi.artifact.interpretation.v1` formano
ora una catena DAG persistita. L'interpretazione usa EvidenceID/FindingID
content-addressed, conserva revisioni fonte esatte e viene decodificata
ricalcolando struttura e identità; una seconda esecuzione riusa lo stesso Artifact
senza avanzare la generazione.

Non sono ancora soddisfatti streaming di corpus, power-loss, kill reale degli
altri writer (indice, autosave, migrazione), migrazione di una futura major N-1,
autosave cognitivo completo, replace/preview UI dell'export, indice e
persistenza separata degli SpanMap.
Profilo corpus e keyness attraversano
il deposito e riusano Artifact verificati; la policy d'invalidazione su reimport
diventerà selettiva solo con una mappa autorevole SourceRevision→AnalysisNode. I
dettagli osservati e i rischi residui sono registrati in GS-VER-019, GS-VER-025,
GS-VER-026 e GS-VER-072; pipeline epistemica, storia ed export sono registrati in
GS-VER-030–033.

## Riferimenti tecnici

- [Unicode Normalization Forms, UAX #15](https://www.unicode.org/reports/tr15/)
- [Unicode Text Segmentation, UAX #29](https://www.unicode.org/reports/tr29/)
- [RFC 8785 — JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785.html)
- [CryptoKit SHA256](https://developer.apple.com/documentation/cryptokit/sha256)
- [SwiftUI FileDocument](https://developer.apple.com/documentation/swiftui/filedocument)
