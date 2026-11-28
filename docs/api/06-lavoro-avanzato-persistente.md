<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Lavoro avanzato persistente e trasporto della ricerca

| Campo | Valore |
| --- | --- |
| Identificatore | GS-API-006 |
| Tipo | Contratto applicativo e persistente |
| Versione | 1.0.0 |
| Stato | Implementazione in verifica |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita corrente; ADR-0047 |
| Riferimenti | GS-API-003; GS-API-004; GS-API-005; GS-STD-001-11; GS-UX-001-17 |

## Acquisizione e ripristino

`runSavedAnalysis` esegue il dispatcher esistente e acquisisce l'esito.
`saveCompletedAnalysis` acquisisce un risultato già prodotto dal Kit senza
ricalcolo; il trasporto equivalente `captureSavedAnalysis` riceve i byte della
richiesta e dell'esito e ne verifica identità e corrispondenza. Acquisire un output
fornito da un chiamante esterno non ne certifica indipendentemente la correttezza.

Il payload `studio.glifi.artifact.saved-research-analysis.v1` conserva schema,
versione, nodo, titolo, metodo, momento Unix in millisecondi, richiesta canonica e
digest, risultato completo, revisioni e digest delle fonti nell'ordine effettivo,
revisioni delle righe documentali, preparazione e digest catturati. La vista nativa
opzionale è una proiezione, separata dall'autorità scientifica.

Il descriptor v2 dichiara le fonti effettive. Importazioni indipendenti conservano
il risultato; una preparazione diversa genera un'identità diversa. Il risultato
storico conserva la configurazione originale. Lettura e riapertura verificano
byte, schema, nodo, richiesta, metodo e revisioni senza invocare gli algoritmi.
Un'acquisizione identica riusa l'oggetto. Limiti: richiesta 1 MiB, esito 8 MiB,
vista opzionale 8 MiB, oltre ai limiti del package.

Gli archivi dei sette laboratori (avanzato, matrici KH, linguaggio KH,
statistica, operatori, valutazione e linguistica) ripristinano impostazioni,
input effettivi e risultati completi. Una versione di vista sconosciuta viene rifiutata
preservando il risultato precedente; il dato scientifico resta esportabile.
`deriveResearchVariable` conserva assegnazioni già prodotte da clustering/SOM o
classificazione con corrispondenza esatta alle revisioni documentali e provenienza
per campo. Per HAC documentale, `clusterCount` taglia l'albero esistente tramite il kernel
condiviso, senza ripetere il clustering. Non deduce classi da coordinate,
probabilità o nomi di file.

## Indagine e rapporto

`createSavedAnalysisInvestigation(artifactID:question:)` riusa il planner sullo
scope dichiarato e crea un'interpretazione descrittiva. La regola
`saved-analysis-capture-v1` afferma esclusivamente che un output è stato acquisito:
non attribuisce esecuzione agli altri passi del piano, equivalenza degli input o
validazione scientifica al metodo. Tali limiti accompagnano Evidence e Finding.
La medesima domanda sul medesimo Artifact riusa l'indagine già presente.

L'export del rapporto include `saved-analysis-<digest>.json` soltanto per gli
output acquisiti selezionati. Il companion conserva il payload originale completo
e compare nel manifest con digest e dimensione; la verifica controlla byte,
schema, identità e collegamento ai finding. Una selezione vuota non esporta
companion non selezionati. I rapporti precedenti conservano il proprio contratto.

## Trasporto condiviso

La CLI espone `glifi research-call <progetto.glifi> --request <richiesta.json>`:

```json
{"schema":"studio.glifi.research-command-request","schemaVersion":1,"operation":"state","parameters":{}}
```

| Operazione | Parametri |
| --- | --- |
| `state` | Nessuno |
| `save-state` | `state`, `expectedRevision` |
| `select` | `filter` opzionale: sottoinsieme, uguaglianza tipizzata e query |
| `tabular-preview` | `data` oppure `sourcePath`; `options` opzionale |
| `tabular-map` | `table`, `mapping` |
| `tabular-import` | `data` oppure `sourcePath`; `options`, `mapping` |
| `tabular-source` | `artifactID` dell'originale |
| `saved-list` | Nessuno |
| `saved-read`, `saved-export` | `artifactID` |
| `saved-run` | `requestJSON`, `title`, `sourceRevisionIDs` |
| `workbench-capture` | `command` (`statistics`, `operator`, `evaluation`), `requestJSON`, `resultJSON`, `methodIdentifier`, `title`; scope, vista, preparazione effettiva e momento opzionali |
| `capture` | `requestJSON`, `resultJSON`, `title`, `sourceRevisionIDs`; vista, preparazione, momento e revisioni delle righe opzionali |
| `derive-variable` | `artifactID`, `fieldID`, `label`, `expectedRevision`; `clusterCount` opzionale per HAC |
| `saved-investigation` | `artifactID`, `question` |

I byte nei DTO JSON sono base64. La richiesta resta entro 1 MiB; `sourcePath`
consente dataset più grandi entro i limiti dell'importatore. Si rifiutano chiavi
sconosciute, parametri di altre operazioni e versioni incompatibili. Envelope,
failure ed exit status rimangono quelli di GS-API-001. Validazione e identità dei
DTO sono infrastruttura del contratto, non operazioni utente separate.

## Originali e commit

`studio.glifi.artifact.tabular-source.v1` conserva byte originali, opzioni,
mapping e provenienza di tutte le colonne. Fonti TXT derivate, metadati e
originale diventano raggiungibili nello stesso commit. Rifiuti e cancellazione
non pubblicano uno stato parziale. Le identità delle righe derivano da progetto,
digest del dataset, mapping, riga e identificativo risolto, mantenendo la parità
fra client. I duplicati sono controllati anche nel progetto esistente. Interi non
rappresentabili esattamente nel metadato numerico vengono rifiutati senza
arrotondamento silenzioso.

## Piattaforma e verifiche

Si riusano il lettore ZIP bounded, Foundation e NaturalLanguage italiani.
Disponibilità e comportamento sono controllati sulle API Apple
[XMLParser](https://developer.apple.com/documentation/foundation/xmlparser),
[entità esterne never](https://developer.apple.com/documentation/foundation/xmlparser/externalentityresolvingpolicy-swift.enum/never)
e [NLTagger](https://developer.apple.com/documentation/naturallanguage/nltagger).
Nessun asset è scaricato e ogni annotazione possiede il proprio tagger.
Build e verifiche macOS sono registrate separatamente in GS-VER-336.

## Compatibilità del lettore

Il contenitore e lo schema del manifest rimangono invariati. Il campo esistente
`minimumReaderVersion` richiede il lettore 3 al primo commit di dati di ricerca:
un lettore precedente rifiuta il progetto anziché ignorare preparazione o
metadati autorevoli. Progetti ordinari e documenti PDF/EPUB senza dati di ricerca
mantengono rispettivamente i requisiti 1 e 2. Il nuovo lettore apre entrambi e
non migra automaticamente i byte all'apertura.

## Laboratori su dati espliciti

`captureWorkbenchAnalysis` acquisisce senza ricalcolo i DTO dei dispatcher
`statistics`, `operator` ed `evaluation`. Il trasporto usa
`studio.glifi.workbench-capture-request` e `studio.glifi.workbench-capture-result`,
versione 1, con discriminatore persistente `workbench-capture-v1`. Il trasporto
precedente delle analisi testuali rimane invariato. Le buste contengono i byte
canonici dei DTO nativi in `payloadJSON`; identità, tipi, metodo e richiesta
congelata sono verificati prima della persistenza. I seed UInt64 e lo zero
firmato mantengono il valore esatto.

I dati numerici manuali dichiarano scope vuoto e preparazione non applicata;
non vengono associati automaticamente alle fonti o alle impostazioni linguistiche
del progetto. Il laboratorio linguistico riusa invece il trasporto testuale.
La cattura temporale conserva il contesto e la preparazione effettivi. Anche i
risultati dei laboratori espliciti possono essere ripristinati nelle viste
native senza invocare i kernel.

I limiti dei DTO originali sono richiesta 1 MiB, risultato 8 MiB e vista 8 MiB;
le buste ammettono rispettivamente 2 e 12 MiB per l'overhead base64. Il limite
JSON della richiesta CLI resta 1 MiB: `requestPath`, `resultPath` e
`presentationPath` sono alternative esclusive ai relativi byte inline per
acquisire output più grandi. Le letture controllano il descrittore, il tipo di
file, il limite incrementale e la cancellazione; non seguono link simbolici.

La preparazione assente in una cattura è identitaria, mai dedotta dalle
impostazioni correnti del progetto. I client che hanno preparato input di corpus
passano esplicitamente la configurazione catturata e il relativo digest; ciò vale
anche per la valutazione temporale. Il digest è verificato contro i byte e il
runtime originario quando si usano annotazioni Apple.
