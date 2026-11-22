# Pratiche Apple per le applicazioni

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-IDX-001 |
| Tipo | Indice delle pratiche Apple |
| Versione | 1.6.0 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |

Questo indice applica le indicazioni Apple pertinenti alle app Glifi Studio per macOS 27 e iPadOS 27. Il progetto sfrutta i componenti hardware e i servizi di sistema che producono un beneficio verificabile, senza aggiungere preventivamente capability, permessi o dipendenze.

La [specifica dei metodi analitici](../metodi-analitici/README.md) definisce la
semantica scientifica. I framework Apple sono backend o strumenti di presentazione:
non sostituiscono formule, precondizioni, provenance o reference test.

La [specifica dell'esperienza](../esperienza-utente/README.md) definisce indagine,
intenzioni, planner, findings e progressive disclosure. I componenti Apple ne
forniscono l'espressione nativa e accessibile senza spostare regole di dominio nelle
view.

Le specifiche implementative [GS-DAT-001](../specifiche-di-design/02-dati-lineage-e-persistenza.md),
[GS-RUN-001](../specifiche-di-design/06-runtime-e-risorse.md) e
[GS-UI-001](../specifiche-di-design/07-information-architecture-e-interazione.md)
rendono vincolanti package, risorse e interazione; questo profilo seleziona le API
Apple con cui realizzarli.

La strategia distingue:

- **baseline attiva**: configurata e verificata nello scaffold corrente;
- **da adottare**: tecnologia preferita quando viene implementato il requisito associato;
- **da valutare**: richiede spike, correttezza e benchmark su hardware reale;
- **condizionale**: entra nel prodotto soltanto dopo una decisione o un flusso esplicito;
- **esclusa**: non deve essere introdotta nella nuova implementazione.

## Argomenti

| ID | Documento | Stato di adozione |
| --- | --- | --- |
| GS-APL-001 | [Ciclo di vita e stato SwiftUI](01-ciclo-di-vita-e-stato-swiftui.md) | Baseline attiva |
| GS-APL-002 | [Interfaccia adattiva](02-interfaccia-adattiva.md) | Regole attive; flussi da progettare |
| GS-APL-003 | [Accessibilità](03-accessibilita.md) | Baseline attiva; audit UI progressivi |
| GS-APL-004 | [Privacy e sicurezza](04-privacy-e-sicurezza.md) | Manifest e sandbox attivi |
| GS-APL-005 | [Documenti e accesso ai file](05-documenti-e-accesso-ai-file.md) | Package documentale definito; prototipo da realizzare |
| GS-APL-006 | [Prestazioni ed energia](06-prestazioni-ed-energia.md) | Regole attive; baseline da misurare |
| GS-APL-007 | [Test e diagnostica](07-test-e-diagnostica.md) | Gate locale attivo; test UI da aggiungere |
| GS-APL-008 | [Firma e distribuzione](08-firma-e-distribuzione.md) | Da completare prima del rilascio |
| GS-APL-009 | [Pipeline documentale e OCR](09-pipeline-documentale-e-ocr.md) | Tecnologie assegnate; implementazione per fasi |
| GS-APL-010 | [Linguistica e intelligenza on-device](10-linguistica-e-intelligenza-on-device.md) | Natural Language prioritario; ML e generazione condizionali |
| GS-APL-011 | [Calcolo accelerato su Apple silicon](11-calcolo-accelerato-apple-silicon.md) | Strategia CPU/Accelerate/GPU/Neural Engine approvata |
| GS-APL-012 | [Persistenza e indicizzazione di sistema](12-persistenza-e-indicizzazione-di-sistema.md) | SQLite/formati Foundation adottati; Spotlight post-MVP |
| GS-APL-013 | [Integrazione di sistema e lavoro prolungato](13-integrazione-di-sistema-e-lavoro-prolungato.md) | App Intents, trasferimento e background pianificati |
| GS-APL-014 | [Osservabilità e telemetria macOS](14-osservabilita-e-telemetria-macos.md) | Policy e facciata attive; nessuna telemetria applicativa |
| GS-APL-015 | [Sostenibilità di sistema macOS](15-sostenibilita-di-sistema-macos.md) | Policy runtime attiva; adattatore eventi richiesto col primo lavoro lungo |

## Mappa sintetica delle tecnologie

| Area | Tecnologie Apple principali | Posizione corrente |
| --- | --- | --- |
| Linguaggio e concorrenza | Apple Swift 6.4, Swift 6 language mode, Swift Concurrency, Foundation | Baseline attiva; ADR-0015 |
| Applicazioni native | SwiftUI, Observation, AppKit/UIKit confinati | Baseline attiva |
| Interazione | NavigationSplitView, Accessibility, SF Symbols, Swift Charts, Core Transferable | GS-UX definita; componenti da adottare per flusso |
| Documenti | Uniform Type Identifiers, PDFKit, Vision, VisionKit, Image I/O, Core Image, Quick Look | Assegnate alle fasi di importazione e OCR |
| Linguistica | Natural Language | Primo backend da validare sull'italiano |
| Calcolo CPU | Accelerate: vDSP, vForce, BLAS/LAPACK, BNNS, vImage | Prima accelerazione da valutare |
| Fondazione scientifica | Swift numerico, Accelerate/BLAS/LAPACK, sparse storage e PRNG controllato | Semantica GS-MET backend-neutral; `GlifiMath` concettuale |
| GPU | Metal, Metal Performance Shaders | Solo con vantaggio end-to-end misurato |
| Machine learning | Core ML su CPU, GPU e Neural Engine | Per modelli specializzati e versionati |
| Generative AI | Foundation Models e Core AI | Assistiva, condizionale, con fallback |
| Dati | SQLite di sistema, FileWrapper/Foundation, CryptoKit, formati versionati | Package `.glifi` GS-DAT; SwiftData non canonico |
| Ricerca di sistema | Core Spotlight, App Entities | Per entità utente, non per l'indice scientifico |
| Automazione | App Intents, Shortcuts, Siri, Apple Intelligence | Dopo la stabilizzazione dei contratti di dominio |
| Lavoro prolungato | BackgroundTasks su iPadOS; task controllati su macOS | Attivazione per operazioni approvate |
| Sicurezza | App Sandbox, Hardened Runtime, Privacy Manifest, Keychain, CryptoKit | Minimo privilegio; estensione per requisito |
| Protezione hardware | Secure Enclave e LocalAuthentication tramite API supportate | Condizionale a chiavi o blocco locale del progetto |
| Rete | URLSession e Network | Disabilitata finché importazione remota o servizi approvati non la richiedono |
| Qualità | Swift Testing, XCTest/XCUITest, Instruments, Logger, OSSignposter, Xcode Organizer | Gate attivo; eventi tipizzati e nessuna telemetria remota |
| Sostenibilità macOS | Low Power Mode, thermal state, DispatchSourceMemoryPressure, App Nap, QoS | Policy deterministica attiva; sorgenti event-driven col primo flusso lungo |
| Sincronizzazione | CloudKit/iCloud, Handoff | Non adottata finché identità, privacy e conflitti non sono decisi |

Mac Catalyst, ML Compute deprecato, polling perpetuo e dipendenze necessarie da servizi remoti non fanno parte della baseline.

StoreKit, AVFoundation, Speech, ARKit/RealityKit, MapKit, HealthKit, HomeKit e altri framework verticali non sono attualmente necessari: vengono aggiunti al portafoglio soltanto se un requisito di prodotto ne introduce il dominio. Questa esclusione evita permessi, superficie di test e coupling privi di valore per l'analisi testuale.

Le decisioni sono registrate in [ADR-0006](../adr/0006-baseline-applicativa-apple.md),
[ADR-0008](../adr/0008-portafoglio-tecnologico-apple-silicon.md) e
[ADR-0016](../adr/0016-specifiche-di-design-e-baseline-prodotto.md),
[ADR-0017](../adr/0017-osservabilita-locale-senza-telemetria.md) e
[ADR-0018](../adr/0018-runtime-cooperativo-sostenibile-macos.md).
