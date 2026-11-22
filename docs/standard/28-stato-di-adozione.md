# 28. Stato di adozione iniziale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-28 |
| Tipo | Capitolo normativo |
| Versione | 1.13.11 |
| Stato | Attivo |
| Responsabile | Amministratore del repository, provvisorio |
| Ultima modifica | 2026-11-22 |
| Approvazione | Registro operativo; baseline normativa ancora proposta |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

| Area | Stato documentato al 2026-11-21 | Azione necessaria |
| --- | --- | --- |
| Standard interno | Completo, proposto | Assegnare responsabili e approvare la baseline |
| Documentazione controllata | Strutturata e verificata automaticamente | Approvare gli information item sostanziali |
| Requisiti | Baseline candidata | Assegnare priorità, metriche e validazione stakeholder |
| Architettura | Separazione prodotto/motore accettata (ADR-0002) | Mantenere il gate `check-architecture` e la superficie Kit |
| Fondazione scientifica | GS-MET-001 e ADR-0013 definiti; nucleo Must con ValidationManifest V0–V4 | Mantenere oracoli; review scientifica esterna e dataset ranking aperti |
| Esperienza utente | GS-UX-001 e UI Must su GlifiKit (G3 candidato, GS-VER-035…071, GS-VER-074…083) | VoiceOver dispositivo, studi UX e soglie G4 |
| Design implementativo | Dieci specifiche GS-DOM–GS-PROD; G1 leggero chiuso; G2 headless chiuso | Chiudere G4/G5 su dispositivi e distribuzione |
| Tracciabilità | Matrice machine-readable; DoR operativa (GS-DOR-001, CMP-014) | Aggiungere scheda DoR a ogni nuova vertical slice |
| Controllo versione | Primo commit pubblicato su `main` nel remote privato canonico | Applicare protezioni server-side quando disponibili |
| Codice e test | Baseline eseguibile macOS/iPadOS, package condiviso, facciata diagnostica e policy runtime coperte da test | Evolvere per vertical slice guidate dai requisiti |
| Ciclo documentale macOS | GS-VER-230/231/232 superate per automatici sul checkpoint ffbfb431: 486 test Core/Kit, 67 definizioni/224 esecuzioni native, gate e preflight macOS; lookup misurato con compromessi espliciti. Generazione 4d6969dd conservata separatamente | Verificare separatamente WIP 223 e layout successivi; GUI, file coordination e autorizzazioni sandbox reali restano da validare, G4 aperto |
| Toolchain Swift | Apple Swift 6.4, Swift 6 language mode, SwiftPM tools 6.4 e strict concurrency verificati | Rivalutare solo con una toolchain Xcode 27 compatibile o nuova ADR |
| Sicurezza e privacy | GS-SEC-001 completo per asset, trust boundary e THR-001–THR-020; zero telemetria e logging tipizzato | Assegnare responsabile ed eseguire corpus avversario, fuzz, kill test e audit build |
| API e CLI | Lifecycle, failure, progressi, cancellazione e operazioni di progetto/analisi/indagine/export implementati; contratti Core/Kit/CLI verificati nelle rispettive evidenze, inclusa GS-VER-162 | Mantenere i contract test; completare copertura delle altre operazioni lunghe, diff API e verifica GUI senza promettere ABI prematura |
| Eccellenza ingegneristica Apple | GS-STD-001-29 e ADR-0024 definiscono criteri EA-* e soglie iniziali; presupposti ereditati verificati o configurati, nessun nuovo gate | Introdurre per fase test plan con sanitizer, test UI con `performAccessibilityAudit`, metriche XCTest, DocC, diff API e classi hardware di riferimento (EA-T-01…07, EA-M-01/02) |
| Sostenibilità macOS | Policy pura e adattatore event-driven con snapshot atomici, admission delle sessioni e controllo fra nodi; test Core/Kit e monitor nel workspace superati (GS-VER-182) | Acquisire idle reale, energia, App Nap, Instruments e calibrazione hardware; il microbenchmark dello snapshot non sostituisce la verifica applicativa |
| GitHub | Remote privato, impostazioni, 20 etichette, Dependabot e audit attivi | Abilitare piano per ruleset, Secret Scanning e push protection |
| CI | Workflow static-quality, format-check, verify e app-store-baseline; esecuzione remota storica documentata in GS-VER-141 con Rscript e veraPDF assenti sul runner | Mantenere evidenze riferite alla revisione verificata e controlli obbligatori/opzionali espliciti; lo stato remoto corrente richiede nuova osservazione |
| Coverage e benchmark | Benchmark Release riproducibili disponibili (GS-VER-109, GS-VER-134, GS-VER-160); soglie e classi hardware ancora da approvare | Acquisire baseline Instruments, energia e hardware di riferimento; mantenere separati benchmark informativi e soglie vincolanti |
| App Store | Distribuzione non in elenco approvata; identità, metadati, privacy, icona e gate versionati | Completare prodotto, account Apple, URL, screenshot, dispositivi e TestFlight |
| Rilascio | Preflight e packaging senza firma predisposti; pubblicazione intenzionalmente assente | Assegnare identità di firma e superare ogni gate di submission |
| Licenza | BSD-3-Clause attiva | Definire titolarità e modello contributivo |
| Piattaforme iniziali | macOS 27 e iPadOS 27 approvate | Definire classi hardware e parità |
| Backup | Remote primario attivo; piano definito | Configurare copia indipendente e provare il ripristino |

Un elemento `Configurato` non è `Verificato` finché non esiste un'esecuzione osservata nell'ambiente dichiarato. La baseline locale viene verificata da `make verify`; protezioni, backup e CI remote richiedono evidenze successive.

## Incrementi complementari del 2026-11-21

- Feedback delle failure anticipato in `make quality-static`: tassonomia e
  messaggi già verificati dal gate completo ora eseguiti anche nel loop rapido,
  con controlli positivi e negativi (GS-VER-180, CMP-180). Nessun nuovo criterio
  EA diventa gate; audit GUI e G4 restano separati.
- Query testuali: profondità dell’AST controllata con visita iterativa, radice a
  zero e incremento per arco anche per AND/OR e NEAR/BEFORE; regressioni prima
  e dopo, parità decoder/Kit e fuzz superati (GS-VER-181, CMP-181). Limiti
  sintattici, byte/nodi e semantica regex restano invariati; indice e streaming
  non sono promossi.

- Manifest candidato: quattro percorsi di commit usano un helper descriptor-relative
  bounded e confrontano i byte attesi prima della pubblicazione. Sono superati
  32 casi mirati e il confronto con un mutante senza uguaglianza esatta
  (GS-VER-183). Replacement, cleanup, SQLite e identità della radice mantengono
  CMP-095 blocked.

- Ottimizzazione misurata di letture payload e termine query (GS-VER-200/201):
  confronto Release con fixture e risultati identici, nove scenari I/O e una
  scansione normalizzata Unicode; verifiche e budget preservati. Misure
  informative nel perimetro delle API, senza promozione di soglie di rilascio,
  performance UI, energia o G4.

- Costi di scala della pipeline (GS-VER-202/203/204): lookup/composizione SpanMap,
  riconoscimento dei token speciali e riferimenti CSV ottimizzati dopo baseline
  Release; dieci workload con output completo identico e gate integrato superati.
  Restano espliciti costo di preparazione, memoria locale e RSS dell'intera
  invocazione; nessuna soglia G4, garanzia energetica o certificazione UI nuova.

- Pianificazione, proiezioni e identità (GS-VER-205/206/207/208): coda DAG con
  heap, appartenenza indicizzata CA e codifica/validazione SHA-256 verificati
  su tre fasi Release con output completi identici; costi piccoli e RSS espliciti.
  Supporto dei benchmark condiviso dai soli test, senza prodotto runtime;
  guard Debug e gate integrato superati, nessuna soglia G4 nuova.

L'incremento ADR-0035 espone le capacità analitiche utente del core nei laboratori
macOS e completa l'editor qualitativo condiviso. La verifica è registrata in
[GS-VER-223](../evidenze/GS-VER-223-copertura-core-app.md); CMP-223 resta implemented.
Questo stato non promuove i criteri assistivi o prestazionali di GS-STD-001-29.
