<!-- SPDX-License-Identifier: BSD-3-Clause -->

# 29. Eccellenza ingegneristica di classe Apple

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-29 |
| Tipo | Capitolo normativo |
| Versione | 0.1.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-18 |
| Approvazione | Non ancora approvato; decisione in ADR-0024 |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 29.1 Finalità e autorità

Questo capitolo fissa la barra di qualità ingegneristica che Glifi Studio adotta
per essere costruito come un'applicazione nativa di primissima qualità sulle
piattaforme Apple: integrata nel sistema, corretta per costruzione, accessibile,
privata, rapida, efficiente, affidabile in campo e manutenibile.

"Classe Apple" indica un livello di mestiere misurabile, non una certificazione né
un'affermazione commerciale. Il capitolo:

- **NON DEVE** indebolire alcuna clausola dei capitoli tematici o dei profili
  GS-APL; in caso di sovrapposizione prevale la clausola più restrittiva;
- raccoglie in 29.2 la copertura già esistente, senza duplicarla;
- aggiunge in 29.3 i criteri che i capitoli tematici non esprimevano ancora;
- fissa in 29.4 soglie quantitative iniziali per le metriche di piattaforma;
- **NON DEVE** produrre un gate che fallisca sulla baseline corrente: ogni criterio
  dichiara uno stato di adozione onesto (29.5) e diventa gate solo quando esiste
  codice che lo soddisfa e un controllo che lo verifica.

## 29.2 Assi di eccellenza e copertura esistente

| Asse | Governato da |
| --- | --- |
| Integrazione nativa e Human Interface Guidelines | [GS-STD-001-15](15-interfaccia-accessibilita-e-localizzazione.md), [GS-APL-001](../apple/01-ciclo-di-vita-e-stato-swiftui.md), [GS-APL-002](../apple/02-interfaccia-adattiva.md), [GS-UI-001](../specifiche-di-design/07-information-architecture-e-interazione.md) |
| Correttezza del linguaggio e API | [GS-STD-001-12](12-implementazione-swift.md), [GS-DEV-002](../loop-di-sviluppo-e-qualita.md), ADR-0015, ADR-0020 |
| Concorrenza, runtime e risorse | [GS-STD-001-12](12-implementazione-swift.md) § 12.6, [GS-RUN-001](../specifiche-di-design/06-runtime-e-risorse.md), [GS-APL-015](../apple/15-sostenibilita-di-sistema-macos.md) |
| Dati, persistenza e integrità | [GS-STD-001-11](11-dati-testo-e-persistenza.md), [GS-DAT-001](../specifiche-di-design/02-dati-lineage-e-persistenza.md) |
| Sicurezza e privacy | [GS-STD-001-14](14-sicurezza-e-privacy.md), [GS-SEC-001](../sicurezza/README.md), [GS-APL-004](../apple/04-privacy-e-sicurezza.md) |
| Accessibilità | [GS-APL-003](../apple/03-accessibilita.md), GS-UX-001-13 e GS-UX-001-15 |
| Internazionalizzazione | [GS-I18N-002](../internazionalizzazione-interfaccia.md), [GS-STD-001-15](15-interfaccia-accessibilita-e-localizzazione.md) |
| Verifica e test | [GS-STD-001-16](16-strategia-di-verifica-e-test.md), [GS-APL-007](../apple/07-test-e-diagnostica.md), [GS-VAL-001](../specifiche-di-design/09-validazione-scientifica.md) |
| Prestazioni ed energia | [GS-STD-001-17](17-benchmark-e-regressioni-prestazionali.md), [GS-APL-006](../apple/06-prestazioni-ed-energia.md) |
| Errori, log e osservabilità | [GS-STD-001-18](18-errori-logging-e-osservabilita.md), [GS-APL-014](../apple/14-osservabilita-e-telemetria-macos.md), ADR-0017 |
| Supply chain e dipendenze | [GS-STD-001-13](13-dipendenze-e-supply-chain.md) |
| Integrazione continua e gate | [GS-STD-001-20](20-integrazione-continua-e-quality-gate.md) |
| Rilascio e distribuzione | [GS-STD-001-21](21-rilascio-e-distribuzione.md), [GS-APL-008](../apple/08-firma-e-distribuzione.md), [piano App Store](../app-store/README.md) |
| Documentazione e decisioni | [GS-STD-001-19](19-documentazione.md), [GS-STD-001-10](10-architettura-e-design.md) |
| Validità scientifica | [GS-MET-001](../metodi-analitici/README.md), [GS-VAL-001](../specifiche-di-design/09-validazione-scientifica.md) |

## 29.3 Criteri aggiuntivi

Ogni criterio ha identificatore stabile `EA-<area>-<nn>`. La colonna *Verifica*
indica come il criterio è dimostrato; una modifica che lo tocca **DEVE** produrre
tale evidenza.

### Linguaggio e correttezza per costruzione

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-L-01 | Uno `switch` su enum del progetto **NON DEVE** usare `default`: ogni nuovo caso deve costringere a rivedere i punti d'uso. Su enum non congelati di framework Apple **DEVE** usare `@unknown default`. | Revisione; `check-swift-dialect` a regime |
| EA-L-02 | Le API che falliscono con un insieme chiuso di errori di dominio **DOVREBBERO** usare typed throws (`throws(Failure)`), senza cancellare il tipo in `any Error` ai confini Core→Kit. | Revisione API |
| EA-L-03 | I target con codice `unsafe` (SQLite, memory mapping, buffer Accelerate/Metal) **DOVREBBERO** abilitare la modalità di memory safety rigorosa del compilatore; ogni espressione `unsafe` **DEVE** citare l'invariante che la giustifica. Dove disponibili, `Span`, `MutableSpan` e `InlineArray` **DOVREBBERO** essere preferiti a puntatori non sicuri. | Build; revisione |
| EA-L-04 | Risorse a proprietà unica (writer lease, handle di transazione, staging) **DOVREBBERO** essere tipi non copiabili (`~Copyable`) con operazioni `consuming` per commit e rilascio, così che l'uso dopo il commit non compili. | Revisione; test di compilazione |
| EA-L-05 | L'API cross-modulo interna al package **DOVREBBE** usare il livello `package` invece di `public`; `public` **DEVE** designare soltanto contratto verso app, CLI o terzi. | Revisione; diff API (EA-M-01) |
| EA-L-06 | Un'invariante la cui violazione può corrompere dati persistenti **DEVE** arrestare l'operazione in modo fail-closed (`precondition` o errore tipizzato che impedisce il commit) anche in Release; `assert` è ammesso solo per invarianti diagnostiche. | Test di fault injection |
| EA-L-07 | Esistenziali (`any`) in hot path **DEVONO** essere giustificati da misura; si preferiscono generici e `some`. | Benchmark (GS-STD-001-17) |

### Verifica e test

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-T-01 | I target app **DEVONO** avere test plan (`.xctestplan`) versionati con configurazioni: predefinita (esecuzione parallela e ordine casuale), Address Sanitizer + Undefined Behavior Sanitizer, Thread Sanitizer, localizzazione (italiano, inglese, pseudo-lingua a lunghezza doppia, destra-sinistra) e Release per le prestazioni. | Esistenza e esecuzione dei piani |
| EA-T-02 | Le configurazioni con sanitizer **DEVONO** essere eseguite a ogni gate di fase e almeno una volta per ciclo di rilascio; un difetto di sanitizer è bloccante e non si sopprime senza deroga. | Evidenza in `docs/evidenze` |
| EA-T-03 | Ogni schermata del percorso `Must` **DEVE** superare `performAccessibilityAudit` in un test UI su macOS e iPadOS; un problema escluso dall'audit **DEVE** avere deroga registrata. | Test UI |
| EA-T-04 | Le metriche app-level (avvio, hitch, hang, memoria, CPU, I/O, signpost) **DEVONO** essere misurate con le metriche XCTest (`XCTApplicationLaunchMetric`, `XCTHitchMetric`, `XCTClockMetric`, `XCTCPUMetric`, `XCTMemoryMetric`, `XCTStorageMetric`, `XCTOSSignpostMetric`), in Release, con baseline versionate e deviazione massima dichiarata. | Test prestazionali |
| EA-T-05 | Il codice che decide integrità dei dati e risultati numerici **DOVREBBE** essere sottoposto a mutation testing prima di G5; punteggio e mutanti sopravvissuti **DEVONO** essere registrati e ogni mutante sopravvissuto rilevante **DEVE** produrre un test o una motivazione. | Evidenza |
| EA-T-06 | Test di snapshot visivi **DEVONO** fissare dispositivo, sistema, lingua, aspetto (chiaro, scuro, contrasto elevato) e dimensione del testo; non costituiscono oracolo scientifico né sostituiscono l'audit di accessibilità. | Revisione |
| EA-T-07 | Le classi hardware di riferimento (Mac con Apple silicon di fascia minima supportata e iPad di fascia minima supportata) **DEVONO** essere definite prima di G4; le prove prestazionali e di accessibilità **DEVONO** essere eseguite su tali dispositivi reali. | Evidenza su dispositivo |
| EA-T-08 | Prima di ogni rilascio **DEVE** avvenire un ciclo di dogfooding con corpora reali autorizzati, registrando difetti e frizioni; i risultati alimentano i requisiti, non li sostituiscono. | Evidenza |

### Accessibilità e inclusione

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-A-01 | Ogni azione del percorso `Must` **DEVE** essere raggiungibile con Voice Control e Switch Control; i controlli con etichetta visiva ambigua **DEVONO** esporre etichette di input alternative. | Verifica manuale con checklist |
| EA-A-02 | Il testo **DEVE** scalare fino alle dimensioni di accessibilità più grandi senza troncare contenuto essenziale né sovrapporsi; il layout **DEVE** riorganizzarsi (per esempio da orizzontale a verticale) invece di ridurre il testo. | Test UI con dimensione massima |
| EA-A-03 | Il contrasto del testo **DEVE** essere almeno 4,5:1 e quello di componenti e grafici almeno 3:1, in aspetto chiaro, scuro e con Increase Contrast; si usano colori semantici di sistema. | Audit; test UI |
| EA-A-04 | Gli obiettivi interattivi **DEVONO** rispettare le dimensioni minime della piattaforma (almeno 44×44 pt su iPadOS) e il comportamento del puntatore. | Audit |
| EA-A-05 | Nessun elemento **DEVE** lampeggiare più di tre volte al secondo; movimento, suono e aptica **NON DEVONO** essere l'unico canale di un'informazione. | Revisione |
| EA-A-06 | Le dichiarazioni di accessibilità di App Store Connect **DEVONO** elencare soltanto funzioni verificate dagli audit e dai test manuali dell'ultima build candidata. | Checklist di rilascio |
| EA-A-07 | L'interfaccia **DEVE** restare utilizzabile con pseudo-lingua a lunghezza doppia e con layout destra-sinistra anche se tali lingue non sono distribuite. | Test UI (EA-T-01) |

### Interfaccia e integrazione di piattaforma

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-U-01 | Si **DEVONO** preferire componenti, materiali, tipografia (stili dinamici), colori semantici e SF Symbols di sistema; l'aspetto della piattaforma corrente **NON DEVE** essere imitato con cromature personalizzate. | Revisione HIG |
| EA-U-02 | Su macOS ogni azione **DEVE** essere raggiungibile dalla barra dei menu con le scorciatoie standard (Annulla/Ripeti, Copia, Trova, Impostazioni, Chiudi finestra); su iPadOS **DEVONO** funzionare comandi da tastiera hardware, puntatore e trascinamento. | Test UI; revisione |
| EA-U-03 | Finestre e scene **DEVONO** supportare ridimensionamento fluido, più finestre, Stage Manager e schermo esterno su iPadOS, e ripristino dello stato per scena, senza perdere selezione o contesto. | Test UI |
| EA-U-04 | Il movimento di contenuto **DOVREBBE** usare API di trasferimento (`Transferable`, trascinamento, condivisione) e il sistema Annulla/Ripeti nativo dove la persona manipola oggetti. | Revisione |
| EA-U-05 | Ogni vista **DEVE** avere anteprime SwiftUI che coprono chiaro/scuro, dimensioni del testo estreme, lingua lunga e stati vuoti, di caricamento, di errore e di dati insufficienti. | Build delle anteprime |
| EA-U-06 | Il lavoro sul Main Actor **DOVREBBE** restare entro il budget di un frame alla frequenza massima del display (circa 8 ms a 120 Hz); ciò che lo eccede **DEVE** essere spostato o reso incrementale. | Instruments; EA-T-04 |
| EA-U-07 | Le integrazioni di sistema (Spotlight sul contenuto, Quick Look persistente, App Intents, Handoff, condivisione) **DEVONO** essere introdotte solo con requisito, valutazione privacy e test, coerentemente con GS-APL-004. | ADR + requisito |

### Sicurezza e privacy avanzate

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-S-01 | I file scritti dall'app fuori dai documenti gestiti dal provider **DEVONO** dichiarare la classe di Data Protection; nessun contenuto del corpus **DEVE** risiedere in classe senza protezione. | Test su dispositivo |
| EA-S-02 | La capacità Enhanced Security di Apple (allocatore rinforzato, autenticazione dei puntatori, memory tagging dove disponibile) **DOVREBBE** essere valutata con ADR per ogni piattaforma; se adottata, la suite **DEVE** essere eseguita con essa attiva. | ADR; test |
| EA-S-03 | I parser di formati binari o complessi ostili **DOVREBBERO** girare fuori processo (servizio XPC) con privilegi ridotti prima di entrare nel percorso `Must`. | ADR; test di isolamento |
| EA-S-04 | Le funzioni del percorso `Must` **DOVREBBERO** restare utilizzabili con Lockdown Mode attivo; la dipendenza da funzioni che esso disabilita **DEVE** essere dichiarata. | Verifica manuale |
| EA-S-05 | Il privacy report generato dall'archivio Release **DEVE** coincidere con il privacy manifest e con le dichiarazioni di App Store. | Checklist di rilascio |

### Affidabilità in campo e osservabilità

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-R-01 | Per ogni build distribuita **DEVONO** essere archiviati i dSYM con la mappa UUID→revisione, per l'intera vita del supporto della versione; la simbolicazione di un crash di prova **DEVE** essere verificata prima del rilascio. | Checklist di rilascio |
| EA-R-02 | Le metriche aggregate di Xcode Organizer (crash, hang, avvio, memoria, scritture su disco, energia) **DEVONO** essere esaminate a ogni versione; un peggioramento rispetto alla versione precedente **DEVE** avere causa registrata. | Evidenza per versione |
| EA-R-03 | Un crash o un hang riproducibile di severità alta **DEVE** bloccare il rilascio; ogni crash risolto **DEVE** lasciare un test di regressione quando tecnicamente possibile. | Checklist di rilascio |
| EA-R-04 | Dopo una terminazione anomala l'app **DEVE** riaprire l'ultimo stato valido e informare in modo accessibile di cosa è stato o non è stato recuperato. | Kill/recovery test; test UI |

### Architettura, documentazione e manutenibilità

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-M-01 | Prima di ogni rilascio la superficie pubblica dei prodotti SwiftPM **DEVE** essere confrontata con la versione precedente mediante l'analisi delle rotture di API; ogni rottura **DEVE** comparire in `CHANGELOG.md`. | Gate di rilascio |
| EA-M-02 | Ogni modulo pubblico **DEVE** avere un catalogo DocC con panoramica, articoli sui flussi principali ed esempi compilabili; la compilazione DocC **DEVE** avvenire senza avvisi. | Gate DocC |
| EA-M-03 | Ogni revisione **DEVE** applicare la checklist di 29.6; con un solo maintainer l'autorevisione **DEVE** registrarne l'esito nella pull request. | Pull request |
| EA-M-04 | `TODO`/`FIXME` **DEVONO** citare una decisione aperta, una deroga o un requisito; codice morto e flag di compilazione senza scadenza **NON DEVONO** essere mantenuti. | `check-repository` a regime |
| EA-M-05 | La salute del compilatore **DOVREBBE** essere sorvegliata con soglie sui tempi di type-checking di funzioni ed espressioni e sul tempo di build pulita e incrementale, registrate come baseline. | Evidenza per fase |

### Rilascio e distribuzione

| ID | Criterio | Verifica |
| --- | --- | --- |
| EA-D-01 | L'archivio **DEVE** essere riproducibile da un tag firmato e da una revisione identificata; il numero di build **DEVE** crescere in modo monotono ed essere tracciato alla revisione. | Checklist di rilascio |
| EA-D-02 | Sull'archivio Release (non su Debug) **DEVONO** essere eseguiti: verifica della firma, diff degli entitlement rispetto alla baseline, elenco dei framework collegati (soli framework di sistema o dichiarati), validazione di App Store Connect e smoke test del percorso `Must`. | `verify-app-store` a regime |
| EA-D-03 | Gli aggiornamenti **DEVONO** usare TestFlight interno prima dell'esterno e rilascio a fasi con possibilità di pausa; un piano di ripristino e una politica di hotfix per difetti critici **DEVONO** essere definiti prima del primo rilascio. | Checklist di rilascio |
| EA-D-04 | Note di rilascio e metadati **DEVONO** essere localizzati in italiano e inglese e descrivere solo comportamenti verificati. | Checklist di rilascio |
| EA-D-05 | La dimensione dell'app installata e i tempi di avvio a freddo **DEVONO** avere un budget e una baseline per versione. | Evidenza per versione |

## 29.4 Soglie quantitative iniziali

Le soglie seguenti sono iniziali, si misurano in Release sull'hardware di
riferimento (EA-T-07) e **DEVONO** essere confermate o corrette con evidenza in G4.
Una soglia corretta **NON DEVE** essere peggiorata senza deroga.

| Metrica | Soglia iniziale |
| --- | --- |
| Avvio a freddo fino al primo frame utile | ≤ 400 ms |
| Hitch time ratio nei flussi `Must` (scorrimento, selezione, navigazione) | ≤ 5 ms/s |
| Hang del Main Actor superiori a 250 ms nei flussi `Must` | 0 |
| CPU app inattiva dopo l'assestamento | ≈ 0 % persistente |
| Perdita di memoria (Leaks) nei flussi `Must` | 0 |
| Contrasto testo / componenti | ≥ 4,5:1 / ≥ 3:1 |
| Problemi `performAccessibilityAudit` non derogati | 0 |
| Avvisi di compilatore, DocC e analisi statica | 0 |
| Difetti di Address/Thread/Undefined Behavior Sanitizer | 0 |

Hitch, hang e avvio si misurano secondo le definizioni di Xcode e Instruments; i
budget di memoria e risorse per classe di corpus restano quelli di GS-RUN-001.

## 29.5 Stato di adozione e regola di non falsa conformità

Ogni criterio ha uno stato:

- **Verificato**: esiste un controllo automatico o un'evidenza archiviata;
- **Configurato**: la configurazione o il processo esiste ma non è stato osservato;
- **Da introdurre**: il criterio è normativo ma non ancora attuato; l'attuazione è
  legata a una fase o a un gate.

Al 2026-09-18 sono **Verificati o Configurati** i presupposti ereditati dalla
baseline: warning come errori, concorrenza rigorosa completa, isolamento
predefinito sul Main Actor, Swift Testing, regole `swift-format` contro force
unwrap, `try!` e IUO, dSYM in Release, App Sandbox, Hardened Runtime, privacy
manifest, action CI fissate per digest e permessi minimi. Tutti i criteri di 29.3
non citati in questo elenco sono **Da introdurre**; in particolare non esistono
ancora test plan, test UI con `performAccessibilityAudit`, metriche XCTest di
prestazione, catalogo DocC, analisi delle rotture di API, mutation testing, servizio
XPC per i parser né valutazione Enhanced Security.

Un agente o una persona **NON DEVE** dichiarare conforme un criterio senza l'evidenza
prevista dalla colonna *Verifica*, né trasformare un criterio "Da introdurre" in
gate prima che esistano il codice conforme e il controllo che lo verifica. Ogni
criterio attuato **DEVE** aggiornare il capitolo 28 e la tracciabilità nello stesso
cambiamento.

## 29.6 Checklist di revisione

Ogni revisione **DEVE** rispondere, per le aree toccate:

1. **API**: nomi secondo le Swift API Design Guidelines; accesso minimo; contratto ed errori documentati (DocC).
2. **Correttezza**: switch esaustivi, invarianti esplicite, nessun force unwrap, `try!` o cast forzato.
3. **Concorrenza**: isolamento, `Sendable`, ownership dei task, cancellazione e assenza di stato globale mutabile.
4. **Dati**: commit point, migrazione N-1, lineage e determinismo preservati.
5. **Sicurezza e privacy**: input non fidati, segreti, entitlement, contenuto assente da log e diagnostica.
6. **Accessibilità e localizzazione**: VoiceOver, Voice Control, tastiera, testo grande, contrasto, pseudo-lingua e destra-sinistra.
7. **Piattaforma**: HIG, componenti di sistema, menu e scorciatoie, multi-finestra, puntatore.
8. **Prestazioni ed energia**: Main Actor libero, nessuna allocazione per elemento negli hot path, misure allegate.
9. **Test ed evidenza**: test che fallisce senza la modifica, sanitizer, riferimenti scientifici indipendenti, evidenza archiviata.
10. **Documentazione**: DocC, ADR, requisiti, tracciabilità e capitolo 28 aggiornati; `CHANGELOG.md` per ogni rottura.

## Riferimenti

- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Writing and running performance tests](https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests)
- [Diagnosing memory, thread and crash issues early](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early)
- [Accessibility Inspector](https://developer.apple.com/documentation/accessibility/accessibility-inspector)
