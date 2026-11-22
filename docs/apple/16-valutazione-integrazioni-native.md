<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Valutazione delle integrazioni native Apple

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-016 |
| Tipo | Valutazione applicativa controllata |
| Versione | 1.0.0 |
| Stato | Valutazione completata; non sostituisce i gate dei singoli profili Apple |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di valutare Accelerate, Metal e le altre tecnologie Apple e integrare le adozioni pertinenti |
| Riferimenti | ADR-0008; ADR-0013; ADR-0018; ADR-0024; ADR-0032; GS-DOR-260; GS-STD-001-17 |

## Perimetro e coordinamento

La valutazione copre il portafoglio tecnologico di Glifi Studio, confrontato con
codice e requisiti. La disponibilità nel sistema non costituisce da sola un motivo
per aggiungere un framework. Le decisioni distinguono ciò che è già in uso, il
lavoro delle altre chat, le integrazioni di questo lotto e le adozioni condizionali.
I profili GS-APL-001…015 restano normativi; nessun criterio privo delle prove
richieste viene promosso a conforme.

Sono stati letti gli aggiornamenti delle quattro chat del progetto e inventariati
i loro checkout. GUI/laboratorio avanzato e Swift Charts appartengono alla chat
GUI; completamento KH, MDS/SOM/reti, LDA e tagging italiano alla chat complementare;
NMF/visite/bootstrap GS-VER-173 alla chat algoritmica; selezioni e lookup
GS-VER-230/231/232 alla chat applicativa. Quei cambiamenti non committati non sono
copiati in questo incremento. I benchmark richiedono una finestra senza misure o
compilazioni concorrenti: la lettura degli altri lavori non equivale ad averli
verificati o integrati.

Aggiornamento d’integrazione: `c6fd88e` ha pubblicato il completamento KH
GS-VER-233 ed è incorporato nel candidato finale. Il suo stato scientifico
candidato rimane distinto dai gate software; le ulteriori ottimizzazioni e il
lavoro GUI non committato restano nelle rispettive chat.

## Calcolo e hardware

| Tecnologia o kernel | Valutazione concreta | Adozione e prova necessaria |
| --- | --- | --- |
| Swift 6.4 e structured concurrency | Riferimento scientifico, ownership e cancellazione già presenti | Conservare actor, Sendable e backpressure; nessun task detached per aggirare isolamento o QoS |
| Accelerate/vDSP | MDS, distanze, norme e SOM/CLARA hanno già kernel nativi | Non duplicare il lavoro KH; verificare la formula e il costo complessivo |
| vDSP per ordinamento descrittivo | Valutato e scartato nel lotto: parità quasi totale sui casi grandi e regressioni nei percorsi economici | GS-VER-260 conserva confronto Release della stessa API in due binari, tutti i bit uguali e misure di processo; produzione Swift invariata |
| BLAS/LAPACK Double | MDS usa già dsyev; SVD densa e prodotti NMF sono candidati forti | Per SVD nuova identità e diagnostica del backend; ricostruzione, ortogonalità, segni e sottospazi degeneri. Non sostituire implicitamente Jacobi o cambiare restart/stopping NMF |
| Accelerate Sparse | Possibile SpMV o sparse×dense per SVD/graph grandi | Misurare conversione CSR/CSC, allocazioni, copia e ricostruzione; evitare densificazione dei corpus |
| vForce | vvlog è disponibile in Double e può servire grandi batch IDF/scoring | Profilare TF-IDF end-to-end: hash, ordinamenti e conversioni possono dominare; nessun cambio implicito ai bit o alla precisione |
| SIMD | Utile per blocchi regolari e riuso dei buffer | Non modificare l’ordine di Gibbs, somme, tie-break, PRNG o stopping. Per vettori piccoli il costo di preparazione può superare il beneficio |
| Metal / MPS / MPSGraph | Nessuna adozione produttiva giustificata nei kernel liberi attuali | La baseline usa binary64. MSL non supporta Double; una riduzione a Float32 non soddisfa automaticamente le tolleranze. Prima servono contratto numerico, fallback e misure end-to-end su Mac/iPad |
| GPU per la presentazione | SwiftUI/Canvas/Core Animation gestiscono già il rendering di sistema | Non scrivere una seconda pipeline grafica senza limite misurato e fallback accessibile |
| BNNS / Core ML / Neural Engine | Pertinenti a inferenza di modelli dichiarati, non sostituti universali della statistica | Modello, licenza, checksum, input/output, corpus di valutazione e warm-up necessari; nessun modello nuovo in questo lotto |

Per Metal il confronto deve includere preparazione, precisione, trasferimenti,
residency, sincronizzazione, lettura, memoria e cancellazione. Il nome commerciale
del chip non è una capability. La memoria unificata non annulla questi costi.
La documentazione primaria Apple [MSL, §2](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
esclude il tipo Double; gli header MPS dello SDK 27.2 non espongono un tipo reale
Float64. Questo è un vincolo concreto della sostituzione trasparente corrente,
non un’affermazione che ogni impiego futuro della GPU sia inutile.

## File, documenti e persistenza

| Tecnologia | Stato e scelta |
| --- | --- |
| Foundation, FileHandle e NSFileCoordinator | Package e coordinamento già adottati. Questo lotto applica coordinamento, verifica del descriptor e lettura incrementale bounded al confine delle fonti esterne; byte e SpanMap restano invariati |
| SwiftUI DocumentGroup / FileDocument / FileWrapper | Ciclo documentale attuale; GlifiKit rimane proprietario delle transazioni del package |
| Document API 27 | DocumentReader/DocumentWriter e URLDocumentConfiguration sono nello SDK. Prototipo richiesto da GS-APL-005: snapshot, letture background, autosave, Save As, rinomina, conflitti e multiwindow prima di cambiare protocollo |
| URLDocumentConfiguration.makeFileCoordinator | Da considerare nel prototipo per accessi incrementali fuori dal reader/writer; durante operazioni usare l’URL ricevuto, non una fileURL di configurazione che può cambiare |
| NSFilePresenter | Da includere nel prototipo dei conflitti/multiwindow dove necessario; il coordinatore da solo non osserva ogni mutazione esterna |
| UTI e security-scoped URL/bookmark | Già attivi; non sostituirli con path personali persistenti o concessioni più ampie |
| Core Graphics / Core Text | Export PDF già generato con API native e provenienza; non introdurre un secondo renderer per il solo nome del framework |
| SQLite di sistema | Store canonico esistente; preservare transazioni, journal e sincronizzazione approvati. Nessun passaggio a WAL senza misure e contratto di recovery |
| SwiftData / Core Data | Non risolvono un requisito mancante dello store attuale; evitata una seconda fonte autorevole e una migrazione non necessaria |
| CryptoKit | SHA-256 già adottato per integrità e content addressing; non equivale a cifratura del corpus |
| Compression / Apple Archive | Condizionali a benchmark, versione del formato e compatibilità; nessuna modifica del package in questo lotto |
| File protection e backup | Conservare permessi e protezioni dei provider. Le cache rigenerabili possono essere escluse dai backup; il package scientifico non è una cache |
| Open in place iPadOS | LSSupportsOpeningDocumentsInPlace non è soltanto una soppressione di warning: abilita accesso all’originale del provider. Adozione dopo prove del ciclo documentale e security scope; nessun UIFileSharingEnabled/iCloud implicito |

Il reader esterno rifiuta tipi non regolari esistenti prima del coordinatore per
evitare un’apertura interna di FIFO. Usa l’URL del blocco coordinato, rifiuta file non regolari e
link sul descriptor aperto e limita i dati letti prima di accumularli. Il
coordinamento riguarda scrittori cooperanti. Non garantisce atomicità contro
scritture arbitrarie che lo ignorano; un’attesa sincrona già bloccata nel provider
o nel kernel non è interrotta dai controlli di cancellazione tra i blocchi. Un
writer non cooperante può sostituire il file dopo lstat e prima dell’apertura
interna di Foundation: la guardia preliminare non rende tale attesa immune dalla
race; il descriptor nell’accessor mantiene la verifica autorevole.

## Applicazioni, accessibilità e trasferimento

| Tecnologia | Stato e scelta |
| --- | --- |
| SwiftUI, Observation, NavigationSplitView, toolbar, materiali e SF Symbols | Già presenti; riprogettazione attiva nell’altra chat. Preferire semantica e componenti di sistema |
| SidebarCommands / ToolbarCommands | Integrati in questo lotto nella scena macOS esistente; DocumentGroup conserva i comandi documentali standard |
| InspectorCommands | Non aggiunti senza un inspector reale: il menu deve corrispondere a un’azione disponibile |
| Swift Charts | Già in corso nella chat GUI per le leggi lessicali; non duplicare Canvas e chart nello stesso flusso |
| Accessibility / VoiceOver / Voice Control | Tabelle, azioni e descrizioni già presenti; build e disponibilità delle API non attestano audit assistivi manuali |
| Audio Graph / accessibilityChartDescriptor | Candidato per factor plot con assi metrici e DTO condiviso, mantenendo tabella e lineage; non attribuire significato metrico alle coordinate arbitrarie delle reti |
| String Catalog / Foundation FormatStyle | Internazionalizzazione già attiva. Nessuna nuova stringa per i comandi nativi, localizzati dal sistema |
| Core Transferable / ShareLink | Candidato per export immutabili con manifest e provenienza. Prima fissare export-only/copia, lifetime, bounds, failure e cancellazione; nessun trasferimento implicito dell’intero progetto |
| AppKit / UIKit | Solo adattatori della piattaforma; non portare UI o lifecycle nel motore |
| Quick Look | Condizionale a una preview utile, sicura e non persistente del contenuto; nessun indicizzatore laterale |

Prima di estendere l’export alla condivisione va corretta la gestione degli esiti:
nel codice esaminato i fileExporter di StudioVisualizationView ignorano i Result
e una preparazione usa try?. Si tratta di un punto di failure da trattare nella
chat GUI; non viene attestata una sua correzione da questo lotto.

## Runtime, diagnostica e sicurezza

| Tecnologia | Stato e scelta |
| --- | --- |
| ProcessInfo, notifiche termiche/energia, DispatchSourceMemoryPressure | Monitor event-driven e admission già attivi; nessun polling o variazione di parametri scientifici sotto pressione |
| ProcessInfo.beginActivity/endActivity | Integrazione limitata al piano esplicitamente richiesto: userInitiatedAllowingIdleSystemSleep, reason statica, owner, fine su risultato/failure/cancellazione |
| AsyncSequence / Foundation Progress | Il piano pubblica già progressi bounded via stream e cancellazione esplicita; un ponte NSProgress serve solo a un consumatore di sistema concreto, senza un secondo stato autorevole |
| Combine / Observation | Observation e concorrenza strutturata coprono lo stato corrente; evitare una seconda pipeline reattiva senza requisito |
| QoS e Swift Concurrency | Intento userInitiated già esplicito; nessuna elevazione globale, occupazione di tutti i core o soppressione globale di App Nap |
| BackgroundTasks / BGContinuedProcessingTask | Condizionali a lavoro iPadOS con progressi localizzati, checkpoint, expiration e cancellazione. Un task async non concede tempo illimitato in background |
| OSLog / OSSignposter | Facciata GlifiDiagnostics già presente; non aggiungere logger diretti o metadati di corpus, path o query |
| Instruments, XCTest/Swift Testing, Xcode Organizer | Canali di verifica già previsti; energia, UI e dispositivi richiedono prove proprie, distinte dai test di dominio |
| MetricKit | Subscriber escluso nella 0.1 secondo GS-APL-014; niente telemetria o upload aggiunti |
| Sandbox, Hardened Runtime e Privacy Manifest | Già attivi; nessun entitlement o raccolta dati nuovo |
| Keychain / Secure Enclave / LocalAuthentication | Nessun nuovo segreto o blocco progetto richiesto; non introdurre senza un caso di prodotto e recupero delle chiavi |
| XPC / Enhanced Security | Hardening condizionale a threat model, processo/privilegi e compatibilità; non dichiarato attuato |

## Linguistica, modelli e servizi di sistema

| Tecnologia | Stato e scelta |
| --- | --- |
| Natural Language | Implementazione italiana e provenienza pubblicate con GS-VER-233; ulteriori ottimizzazioni restano nella chat KH. Non duplicare né sostituire automaticamente it-token-v1; capability detection non attesta accuratezza e non autorizza download impliciti |
| PDFKit / Vision / VisionKit | Scelte per importazione/OCR nelle fasi previste: fixture, pagina/regione, lineage, qualità italiana e bounds prima di aggiungere importer |
| Image I/O / Core Image / vImage | Condizionali alla pipeline immagini/OCR; non necessari per i testi già decodificati |
| Core ML / Create ML / Core ML Tools | Modelli specializzati e strumenti offline, con provenienza e valutazione. Nessun pacchetto o runtime aggiuntivo obbligatorio |
| Foundation Models / Core AI | Funzioni assistive condizionali e non autoritative; availability, fallback, contesto bounded e provenienza. Nessuna rete, Private Cloud Compute o conclusione scientifica generativa implicita |
| App Intents / App Entities / Shortcuts / Siri | Post-MVP: identità e permessi stabili, servizi di dominio riusati e azioni sensibili esplicite |
| Core Spotlight | Non sostituisce l’indice scientifico; disclosure, privacy e invalidazione prima di esporre contenuti al sistema |
| CloudKit / iCloud / Handoff / NSUserActivity | Restano condizionali a identità, conflitti e privacy; nessuna sincronizzazione introdotta |
| URLSession / Network | Nessun requisito di rete nella baseline locale; non abilitarla per una generica integrazione Apple |
| PencilKit, camera, widget, Live Activities | Solo con un flusso approvato e fallback accessibile |
| StoreKit, AVFoundation, Speech, ARKit/RealityKit, MapKit, HealthKit, HomeKit | Fuori dal dominio corrente; aggiungerli senza un requisito aumenterebbe permessi e superficie senza valore dimostrato |
| Mac Catalyst / ML Compute | Non fanno parte della baseline; ML Compute è deprecato |

## Prove e stato di adozione

GS-VER-260 registra i risultati del lotto, i comandi, la revisione e i limiti.
Il candidato Accelerate per il sort è stato scartato dopo misure controllate: non
sono introdotti kernel aggiuntivi o soglie di selezione. Il preflight non è
dichiarato superato finché il relativo risultato non è osservato.
Le altre chat mantengono le proprie evidenze. Non viene attestata parità di
prestazioni su iPad, misurazione energetica G4 o audit manuale dell’interfaccia.

## Fonti primarie Apple

- [Accelerate](https://developer.apple.com/documentation/accelerate), [vForce](https://developer.apple.com/documentation/accelerate/vforce) e header vDSP/LAPACK/Sparse dello SDK locale 27.2.
- [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator), [FileHandle.read](https://developer.apple.com/documentation/foundation/filehandle/read(uptocount:)).
- [ProcessInfo.ActivityOptions](https://developer.apple.com/documentation/foundation/processinfo/activityoptions).
- [DocumentReader](https://developer.apple.com/documentation/swiftui/documentreader), [URLDocumentConfiguration](https://developer.apple.com/documentation/swiftui/urldocumentconfiguration).
- [Core Transferable](https://developer.apple.com/documentation/coretransferable), [menu di SwiftUI](https://developer.apple.com/documentation/swiftui/building-and-customizing-the-menu-bar-with-swiftui), [accessibilityChartDescriptor](https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:)).
- Le fonti e i gate dei singoli GS-APL restano applicabili alle adozioni condizionali.
