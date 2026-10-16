# Matrice di tracciabilità

| Campo | Valore |
| --- | --- |
| Identificatore | GS-TRC-001 |
| Tipo | Requirements traceability matrix |
| Versione | 0.84.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-06 |
| Approvazione | Non ancora approvato |

## Scopo

La matrice collega le fonti iniziali alle necessità degli stakeholder, ai requisiti software, alle parti dell'architettura e alle evidenze di verifica pianificate. Gli identificatori fanno riferimento a [Requisiti](requisiti.md) e [Architettura](architettura.md).

## Tracciabilità end-to-end

| Necessità | Requisiti derivati | View/decisioni architetturali | Verifica pianificata | Stato |
| --- | --- | --- | --- | --- |
| NS-001 Analizzare documenti e corpus | RF-001–RF-004, RF-015–RF-030, RF-034–RF-035, RF-050–RF-056, RF-079–RF-081, CV-006 | VA-01, VA-02, VA-06, VA-07, GS-LNG-001, GS-QRY-001, GS-ANA-001, ADR-0013–ADR-0016 | TV-001, TV-002, TV-007, TV-008, TV-014, TV-026, TV-029–TV-030, TV-039–TV-041, TV-052–TV-054 | Slice TXT/Markdown, query/KWIC, profilo corpus, DAG, planner ed esecutore MVP persistenti verificati; indice e analisi complete aperti |
| NS-002 Verificare risultati sulla fonte | RF-005, RF-009, RF-014, RF-029, RF-039, RF-043, RF-046, RF-077–RF-078, RF-084, RQ-003, RQ-023, RQ-028 | VA-03, VA-06, GS-DAT-001, GS-VIZ-001, ADR-0013, ADR-0016 | TV-003, TV-004, TV-006, TV-027, TV-035, TV-051, TV-058 | SourceRevision, SpanMap e salto UI KWIC→fonte (GS-VER-039); audit dispositivo aperto |
| NS-003 Elaborare corpus massivi | RF-014, RQ-001, RQ-002, RQ-006, RQ-009, RQ-015, RQ-016, RQ-018, RQ-041, RQ-048, RQ-052–RQ-055, CV-013, CV-016 | VA-03, VA-04, GS-RUN-001, GS-APL-015, ADR-0008, ADR-0016, ADR-0018 | TV-009, TV-010, TV-019, TV-056–TV-057, TV-065–TV-068 | Admission e stream bounded attivi; progresso intra-nodo, baseline hardware e soglie da misurare |
| NS-004 Riprendere il lavoro senza ricalcolo inutile | RF-001, RF-011, RF-047–RF-048, RF-070–RF-071, RF-075–RF-077, RF-081, RQ-004, RQ-033, RQ-043, RQ-059 | VA-03, VA-07, GS-DOM-001, GS-DAT-001, GS-ANA-001, ADR-0014, ADR-0016, ADR-0019, ADR-0021 | TV-001, TV-005, TV-037, TV-047, TV-050–TV-051, TV-054, TV-060, TV-072 | Artifact riusabili e storia dell'indagine sopravvivono alla riapertura; recovery read-only verso la generazione precedente verificata; indice, autosave e migrazione N-1 aperti |
| NS-005 Confrontare sottoinsiemi tramite metadati | RF-012, RF-013, RF-018–RF-021, RF-031, RF-040 | VA-02, VA-03, VA-06 | TV-007, TV-008, TV-027, TV-031 | Keyness fra revisioni esplicite verificata; selezione metadata-first incompleta |
| NS-006 Usare capacità headless e automatizzabili | RF-023, RF-080, RF-083, RQ-058, RQ-060, CV-003 | VA-01, VA-02, GS-QRY-001, GS-ANA-001, GS-API-001, ADR-0002, ADR-0016, ADR-0019, ADR-0022–ADR-0023 | TV-011, TV-053, TV-056, TV-071, TV-073 | Progetto/import, query, planner, esecuzione, Investigation ed export PDF/Markdown/CSV/JSON verificati in GlifiKit/CLI |
| NS-007 Ottenere risultati corretti e riproducibili | RF-022, RF-041, RF-045, RF-076, RF-081–RF-083, RQ-003, RQ-007–RQ-018, RQ-023–RQ-029, RQ-043–RQ-062, CV-014, CV-016 | VA-03–VA-06, GS-DAT-001, GS-ANA-001, GS-VAL-001, GS-SEC-001, GS-API-001, GS-APL-014–GS-APL-015, ADR-0006, ADR-0008, ADR-0013, ADR-0016–ADR-0019 | TV-004, TV-008, TV-009, TV-012, TV-016, TV-018–TV-020, TV-026–TV-033, TV-051, TV-054–TV-075 | Descriptor/DAG e prime analisi hanno prove riproducibili; validazione completa, hardware e studi restano incompleti |
| NS-008 Lavorare in app native macOS e iPadOS | RF-024, RF-072–RF-073, RF-083, RF-086, RQ-012, RQ-019–RQ-022, RQ-032, RQ-034, RQ-037–RQ-039, RQ-047, RQ-049–RQ-056, CV-001–CV-020 | VA-01, VA-02, VA-04, VA-05, VA-07, GS-UI-001, GS-PROD-001, GS-APL-014–GS-APL-015, ADR-0001, ADR-0003, ADR-0005, ADR-0006, ADR-0008, ADR-0011, ADR-0014–ADR-0018 | TV-013, TV-015–TV-025, TV-044, TV-048–TV-049, TV-058, TV-061–TV-069 | Percorso Must UI condiviso su Kit (GS-VER-035); audit dispositivo e App Store aperti |
| NS-009 Comprendere metodi e limiti | RF-026–RF-038, RF-042, RF-044–RF-046, RQ-023, RQ-025–RQ-028 | VA-06, ADR-0013, GS-MET-001 | TV-026–TV-032, TV-034–TV-036 | Profilo corpus e keyness bounded verificati; restanti metodi e review scientifica esterna aperti |
| NS-010 Analizzare metadati e tempo | RF-029, RF-031, RF-032, RF-035, RF-040 | VA-03, VA-06, GS-MET-001-17 | TV-027, TV-029–TV-031 | Contratto definito; implementazione mancante |
| NS-011 Esplorare strutture multivariate e reti | RF-029, RF-033, RF-036–RF-039, RF-046 | VA-06, GS-MET-001-06, GS-MET-001-10, GS-MET-001-13–16, GS-MET-001-22 | TV-030, TV-032, TV-035 | CA/PCA/LSA, HAC, reti e viste dedicate (GS-VER-099–114); audit su dispositivo aperto |
| NS-012 Eseguire content analysis manuale | RF-043, RF-044, RQ-023, RQ-028 | VA-03, VA-06, GS-MET-001-20 | TV-027, TV-034 | Perimetro confermato; flusso MVP da decidere |
| NS-013 Valutare la qualità linguistica | RF-010, RF-041, RQ-027, RQ-029 | VA-02, VA-05, VA-06, ADR-0004, GS-MET-001-18 | TV-014, TV-026, TV-033 | Gold token V0 con split (GS-VER-036); lemma/POS/NER aperti |
| NS-014 Sintesi e topic classici riproducibili | RF-038, RF-042, RQ-025, RQ-028, CV-014 | VA-06, ADR-0008, ADR-0013, GS-MET-001-15, GS-MET-001-19, GS-PROD-001 | TV-028, TV-032, TV-036 | Specificati come evoluzione post-MVP |
| NS-015 Iniziare da domanda e intenzione | RF-049–RF-050, RF-063, RF-066, RF-074 | VA-07, ADR-0014, GS-UX-001-01, GS-UX-001-07 | TV-038, TV-039, TV-042, TV-045 | Domanda/intenzione/piano in UI Must; studi UX aperti |
| NS-016 Sviluppare indagini persistenti | RF-047–RF-048, RF-070–RF-071, RF-075–RF-076, RF-085, RQ-033, RQ-040, RQ-043 | VA-03, VA-07, GS-DOM-001, GS-DAT-001, ADR-0014, ADR-0016, ADR-0021–ADR-0023 | TV-037, TV-047, TV-050–TV-051, TV-059 | Storia append-only, selezione e proiezione Report PDF/Markdown/CSV/JSON verificate; altri eventi, autosave e UI aperti |
| NS-017 Ottenere analisi applicabili e spiegabili | RF-051, RF-053–RF-056, RF-068, RF-081–RF-083, RQ-035 | VA-04, VA-07, GS-ANA-001, GS-PROD-001, ADR-0014, ADR-0016 | TV-040–TV-042, TV-045, TV-054–TV-055 | Planner/esecutore e interpretazione descrittiva/keyness verificati; CollectionProfile qualitativo e spiegazione UI completa aperti |
| NS-018 Comprendere e verificare i risultati | RF-057–RF-065, RF-071, RF-073–RF-074, RF-082, RF-085, RQ-030–RQ-031, RQ-036, RQ-040 | VA-06, VA-07, GS-ANA-001, GS-VIZ-001, GS-PROD-001, ADR-0014, ADR-0016, ADR-0022–ADR-0023 | TV-043, TV-045, TV-047, TV-055, TV-058–TV-059 | Evidence/Finding/Caveat e Report selettivo nei quattro formati verificati; UI, studi e visualizzazioni aperti |
| NS-019 Interrogare numeri e segni | RF-061–RF-062, RQ-037 | VA-03, VA-06, VA-07, GS-MET-001-01, GS-MET-001-22, GS-UX-001-09 | TV-035, TV-044 | Classi di lineage definite; UI non implementata |
| NS-020 Esplorare oggetti e confrontarli | RF-066–RF-068 | VA-07, ADR-0014, GS-UX-001-07, GS-UX-001-08 | TV-041–TV-042, TV-045 | `compare.objects` pianifica keyness applicabile; oggetti di dominio e interazione da validare |
| NS-021 Comprendere solidità e limiti | RF-051, RF-055, RF-057, RF-064–RF-065, RQ-031, RQ-036 | VA-06, VA-07, GS-UX-001-05, GS-UX-001-06 | TV-040, TV-043, TV-045 | Policy descrittiva/keyness e insufficienza esplicita verificate senza score universale; calibrazione e altre famiglie aperte |
| NS-022 Esperienza nativa e accessibile | RF-052, RF-072–RF-073, RF-084, RQ-030, RQ-032, RQ-034, RQ-037–RQ-039, RQ-047 | VA-05, VA-07, GS-UI-001, GS-VIZ-001, ADR-0006, ADR-0014, ADR-0016 | TV-015, TV-017–TV-018, TV-039, TV-044–TV-045, TV-048, TV-058 | Prima IA adattiva/localizzata implementata; audit assistivi e studi mancanti |
| NS-023 Domande naturali tipizzate | RF-049, RF-069, RQ-036 | VA-04, VA-07, ADR-0008, ADR-0014, GS-UX-001-11 | TV-046 | Funzione post-MVP specificata; implementazione assente |

## Autorità delle specifiche di design

| Specifica | Requisiti primari | View | Verifiche |
| --- | --- | --- | --- |
| GS-DOM-001 | RF-047–RF-048, RF-057–RF-058, RF-075 | VA-02, VA-03, VA-07 | TV-037, TV-043, TV-050 |
| GS-DAT-001 | RF-001–RF-014, RF-076–RF-078, RF-085; RQ-010, RQ-033, RQ-043–RQ-044 | VA-03 | TV-001–TV-006, TV-027, TV-037, TV-047, TV-051, TV-059–TV-060 |
| GS-LNG-001 | RF-008–RF-010, RF-025, RF-041, RF-079; RQ-029 | VA-03, VA-06 | TV-014, TV-033, TV-052 |
| GS-QRY-001 | RF-015–RF-018, RF-080; RQ-042 | VA-02–VA-04 | TV-007, TV-053, TV-060 |
| GS-ANA-001 | RF-053–RF-065, RF-068, RF-081–RF-083; RQ-024, RQ-035–RQ-036 | VA-03, VA-04, VA-06, VA-07 | TV-027, TV-041–TV-045, TV-054–TV-056 |
| GS-RUN-001 | RF-083; RQ-001–RQ-002, RQ-006, RQ-009, RQ-011, RQ-018, RQ-041, RQ-048, RQ-052–RQ-055 | VA-04, VA-05 | TV-009–TV-010, TV-012, TV-018–TV-019, TV-056–TV-057, TV-065–TV-068 |
| GS-UI-001 | RF-050, RF-052, RF-061, RF-066–RF-074; RQ-030–RQ-039, RQ-047 | VA-07 | TV-039–TV-048, TV-058 |
| GS-VIZ-001 | RF-046, RF-062, RF-084; RQ-028, RQ-037 | VA-06, VA-07 | TV-035, TV-044, TV-058 |
| GS-VAL-001 | RF-022, RF-041, RF-045; RQ-008, RQ-023–RQ-029, RQ-045 | Tutte | TV-026–TV-036, TV-052–TV-060 |
| GS-PROD-001 | RF-024–RF-025, RF-086; RQ-020 | VA-01, VA-05, VA-07 | TV-024–TV-025, TV-061 |
| GS-SEC-001 | RQ-042, RQ-044, RQ-046, RQ-049–RQ-050, RQ-057 | Tutte le superfici non fidate | TV-060, TV-062–TV-063, TV-070 |
| GS-API-001 | RF-023, RF-080, RF-083; RQ-007, RQ-011, RQ-058, RQ-060 | VA-01, VA-02, VA-04 | TV-011–TV-012, TV-056, TV-071, TV-073 |

## Matrice di conformità implementativa

La fonte machine-readable è
[`Config/Compliance/specification-matrix.json`](../Config/Compliance/specification-matrix.json).
Ogni riga collega una clausola a requisito, documento autorevole, codice, test,
fixture, evidenza e gate. `make check-compliance` verifica ID univoci, requisiti e
path esistenti e impedisce le promozioni prive delle prove minime.

| Stato | Significato | Riferimenti minimi |
| --- | --- | --- |
| `specified` | contratto presente, implementazione non dichiarata | specifica e requisito |
| `implemented` | codice presente, verifica non ancora acquisita | specifica, requisito e codice |
| `verified` | prova riproducibile registrata | specifica, requisito, codice, test ed evidenza |
| `blocked` | lavoro impedito da una lacuna esplicita | specifica, requisito e `blockingReason` |

La matrice include 45 clausole ad alto rischio e rende visibili, senza
falsi positivi, le lacune su corpus italiano, baseline numerica, SupportPolicy e
ranking, studi UX, PDF/OCR e hardware. La domanda “GS-DAT, protocollo di commit: è
implementato e provato?” ottiene quindi stato, percorsi e blocco dalla stessa riga.
L'estensione alle restanti clausole avviene prima del coding tramite Definition of
Ready; l'assenza di una riga per codice nuovo è una non conformità.

## Evidenze acquisite

| Evidenza | Verifiche coperte | Esito | Limite |
| --- | --- | --- | --- |
| [GS-VER-001](evidenze/GS-VER-001-bootstrap-ambiente.md) | TV-011 preliminare; TV-013 build baseline | Superato | Non copre flussi funzionali, firma o dispositivi fisici |
| [GS-VER-002](evidenze/GS-VER-002-baseline-linguistica-italiana.md) | TV-014 configurazione iniziale | Superato | Non copre ancora la qualità delle analisi linguistiche italiane |
| [GS-VER-003](evidenze/GS-VER-003-interfaccia-internazionalizzabile.md) | TV-015 catalogo e build `it`/`en` | Superato | Test UI del cambio lingua richiesti quando esisteranno flussi interattivi |
| [GS-VER-004](evidenze/GS-VER-004-baseline-applicativa-apple.md) | TV-016 baseline Apple; predisposizione TV-017/TV-018 | Superato | Audit UI, profiling e dispositivi richiesti con i primi flussi funzionali |
| [GS-VER-005](evidenze/GS-VER-005-ridenominazione-glifi-studio.md) | Regressione TV-013, TV-015 e TV-016 dopo ADR-0007 | Superato | Non copre disponibilità legale del nome, firma o sistemi esterni |
| [GS-VER-006](evidenze/GS-VER-006-portafoglio-tecnologico-apple.md) | Strategia ADR-0008 e predisposizione TV-019–TV-021 | Superato | Non sostituisce benchmark e prove funzionali su dispositivi reali |
| [GS-VER-009](evidenze/GS-VER-009-preflight-app-store.md) | TV-022; baseline di TV-023 e TV-025 | Superato localmente | Packaging senza firma; submission, account Apple, prodotto e dispositivi esclusi |
| [GS-VER-012](evidenze/GS-VER-012-revisione-fondazione-scientifica.md) | Revisione documentale di TV-026–TV-036 | Superato per struttura e coerenza | Non costituisce validazione delle future implementazioni né peer review scientifica esterna |
| [GS-VER-013](evidenze/GS-VER-013-revisione-esperienza-utente.md) | Revisione documentale e architetturale di TV-037–TV-048 | Superato per struttura e coerenza | Non costituisce implementazione UI né validazione con utenti o tecnologie assistive |
| [GS-VER-014](evidenze/GS-VER-014-baseline-swift-6-4.md) | CV-020; TV-049 e regressione TV-011/TV-013 | Superato localmente | CI remota non avviata per il budget Actions già registrato |
| [GS-VER-015](evidenze/GS-VER-015-specifiche-di-design.md) | Revisione documentale di TV-050–TV-061 | Superato per struttura e coerenza | Non costituisce implementazione, benchmark o validazione scientifica/UX |
| [GS-VER-016](evidenze/GS-VER-016-osservabilita-e-sostenibilita-macos.md) | TV-062, TV-064–TV-065; baseline statica TV-063/TV-069 | Superato localmente per policy, test, build e packaging | Profiling event-driven, hardware e Organizer TV-063/TV-066–TV-068 ancora aperti |
| [GS-VER-017](evidenze/GS-VER-017-sicurezza-api-e-conformita.md) | Revisione documentale TV-070–TV-076 e gate della matrice | Superato localmente per contratti e automazione | Non prova parser, persistenza, API funzionale, corpus, benchmark o studi UX |
| [GS-VER-018](evidenze/GS-VER-018-primo-incremento-verticale.md) | Slice parziale TV-002, TV-003, TV-040, TV-052 e TV-073 | Superato localmente per TXT bounded e integrazione Xcode | Non prova streaming, package, corpus gold, UI assistiva o dispositivi fisici |
| [GS-VER-019](evidenze/GS-VER-019-package-glifi-transazionale.md) | Slice parziale TV-001, TV-002, TV-051, TV-060, TV-071–TV-073 | Superato localmente per package G2, commit point e API/CLI | Non prova power-loss, provider reali, migrazione, recovery completa o DocumentGroup |
| [GS-VER-020](evidenze/GS-VER-020-query-ast-kwic-bounded.md) | Slice parziale TV-003, TV-007, TV-053, TV-060 e TV-073 | Superato localmente per QueryAST, parser, regex NFA, KWIC e CLI | Non prova indice, metadati/annotazioni, fuzz, benchmark, streaming o navigazione UI |
| [GS-VER-021](evidenze/GS-VER-021-markdown-spanmap.md) | Slice parziale TV-002, TV-003, TV-007, TV-051, TV-060 e TV-073 | Superato localmente per estrazione Markdown, SpanMap e sourceRanges | Non prova document model/CommonMark completo, streaming, fuzz o navigazione UI |
| [GS-VER-022](evidenze/GS-VER-022-profilo-corpus-riproducibile.md) | Slice parziale TV-008, TV-011, TV-029, TV-030, TV-056, TV-064 e TV-073 | Superato localmente per profilo corpus bounded e reference seed indipendente | Non prova segmenti, streaming/spill, tempo, UI, export o benchmark; persistenza acquisita da GS-VER-026 |
| [GS-VER-023](evidenze/GS-VER-023-keyness-gtest-bh.md) | Slice parziale TV-008, TV-011, TV-031, TV-056, TV-064 e TV-073 | Superato localmente per keyness G-test/effect/BH bounded e reference seed indipendente | Non prova Fisher/CI, corpus gold, UI, review esterna o benchmark; persistenza acquisita da GS-VER-026 |
| [GS-VER-024](evidenze/GS-VER-024-analysis-descriptor-dag.md) | Slice parziale TV-004, TV-005, TV-027, TV-028, TV-054 e TV-060 | Superato localmente per descriptor canonico, DAG bounded, invalidazione e riuso | Persistenza/esecuzione acquisite da GS-VER-025/026; scheduler, recovery, fuzz e benchmark aperti |
| [GS-VER-025](evidenze/GS-VER-025-persistenza-artifact-dag.md) | Slice parziale TV-001, TV-004, TV-005, TV-027, TV-051, TV-054, TV-060 e TV-072 | Superato localmente per persistenza Artifact/DAG, riapertura fail-closed e commit point | Non prova kill reale, power-loss, file provider o GC; commit analisi/planner acquisiti da GS-VER-026/027 |
| [GS-VER-026](evidenze/GS-VER-026-analisi-persistenti-riusabili.md) | Slice parziale TV-004, TV-005, TV-008, TV-011, TV-031, TV-054, TV-056, TV-060 e TV-073 | Superato localmente per commit e riuso di profilo corpus e keyness | Non prova altre famiglie, streaming/spill, concorrenza multiprocesso, UI o hardware; planner acquisito da GS-VER-027 |
| [GS-VER-027](evidenze/GS-VER-027-planner-mvp-deterministico.md) | Slice parziale TV-005, TV-041, TV-054, TV-060 e TV-073 | Superato localmente per planner puro, rationale, budget, persistenza e Kit/CLI | Non prova catalogo Must completo, runtime/hardware, esecuzione piano, UI o studi con utenti |
| [GS-VER-028](evidenze/GS-VER-028-esecuzione-piano-progressi.md) | Slice parziale TV-005, TV-012, TV-056, TV-065, TV-071 e TV-073 | Superato localmente per admission, esecuzione, progresso, cancellazione e riuso Core/Kit/CLI | Non prova progresso intra-nodo, checkpoint, parallelismo, UI, hardware o benchmark |
| [GS-VER-029](evidenze/GS-VER-029-loop-qualita-dialetto-swift.md) | CV-020; TV-049; loop GS-DEV-002 / ADR-0020; CI `static-quality`/`format-check`/`verify`/`app-store-baseline` | Superato localmente e sui runner GitHub | Dispositivi fisici, distribuzione firmata e revisione App Store restano aperti |
| [GS-VER-030](evidenze/GS-VER-030-evidence-finding-caveat.md) | Slice parziale TV-027, TV-043, TV-054–TV-055, TV-071 e TV-073 | Superato localmente per interpretazione deterministica, identità e lineage | Conflitti, altre famiglie, UI e validazione scientifica completa aperti |
| [GS-VER-031](evidenze/GS-VER-031-investigation-history.md) | Slice parziale TV-037, TV-047, TV-050–TV-051, TV-059–TV-060 e TV-072–TV-073 | Superato localmente per storia append-only, rami, migrazione e superfici | Altri eventi, autosave, recovery reale e UI aperti |
| [GS-VER-032](evidenze/GS-VER-032-export-scientifico.md) | Slice parziale TV-047, TV-059–TV-060 e TV-072–TV-074 | Superato localmente per Report JSON/Markdown, manifest, digest, staging e superfici | PDF/CSV acquisiti da GS-VER-033; firma, preview UI e kill reale aperti |
| [GS-VER-033](evidenze/GS-VER-033-export-pdf-csv.md) | Slice parziale TV-047, TV-059–TV-060 e TV-072–TV-074 | Superato localmente per PDF/A-2u taggato e CSV lossless in Core/Kit/CLI | Firma, preview UI, VoiceOver manuale e kill reale aperti |
| [GS-VER-072](evidenze/GS-VER-072-process-kill-recovery.md) | Slice parziale TV-051, TV-060 e TV-072 | Superato localmente per 16 checkpoint `SIGKILL`, riapertura/ispezione e retry di import/Artifact/export | Non prova power-loss, indice, autosave, migrazione, storia o file provider reali |
| [GS-VER-073](evidenze/GS-VER-073-recovery-read-only-generazione-precedente.md) | Slice parziale TV-051 e TV-060 | Superato localmente per apertura read-only della generazione precedente verificata senza riscrivere il package | Richiede un manifest leggibile; non copre database inapribile, GC, retention o UI |
| [GS-VER-084](evidenze/GS-VER-084-tabelle-contingenza-cramers-v.md) | Slice parziale TV-008 e TV-031 | Superato localmente per `PearsonChiSquareRxC-v1`, `CramersV-v1` e residui bounded, incrociati con la forma chiusa `erfc` del keyness a df=1 | Non prova persistenza, wiring Kit/CLI, provenienza per cella, Fisher/Monte Carlo RxC o Correspondence Analysis |
| [GS-VER-085](evidenze/GS-VER-085-dispersione-griesdpnorm-juillandd.md) | Slice parziale TV-008 e TV-029 | Superato localmente per `GriesDPnorm-v1` e `JuillandD-equal-v1` bounded su partizione esplicita | Non prova wiring al profilo corpus persistito, altre partizioni, dispersion plot o corpus gold |
| [GS-VER-086](evidenze/GS-VER-086-similarita-insiemi-vettori-distribuzioni.md) | Slice parziale TV-008 e TV-032 | Superato localmente per Jaccard/Dice, Cosine/Euclidean/Manhattan e KL/JS/Hellinger bounded, incrociati con forme chiuse note | Non prova persistenza, wiring Kit/CLI, varianti pesate/multiset o corpus gold |
| [GS-VER-087](evidenze/GS-VER-087-welch-t-oneway-anova.md) | Slice parziale TV-008 e TV-031 | Superato localmente per Welch t e ANOVA one-way con p-value asintotico, incrociati con identità Cauchy e F=t² | Non prova le altre famiglie GS-MET-001-21, intervalli, bootstrap/permutation, persistenza o wiring Kit/CLI |
| [GS-VER-088](evidenze/GS-VER-088-cohen-kappa-krippendorff-alpha.md) | Slice parziale TV-008 e TV-034 | Superato localmente per Cohen's Kappa e Krippendorff's Alpha nominale bounded, con valori a forma chiusa | Non prova codebook, codifiche persistite, livelli ordinali/intervallo, persistenza o wiring Kit/CLI |
| [GS-VER-089](evidenze/GS-VER-089-collocazione-pmi-npmi-dice-logdice.md) | Slice parziale TV-029 e TV-032 | Superato localmente per PMI/NPMI/Dice/Jaccard/t-score/logDice bounded su tabella 2×2 esplicita | Non prova estrazione del contesto dal testo, reti di co-occorrenza, persistenza o wiring Kit/CLI |
| [GS-VER-090](evidenze/GS-VER-090-grafo-degree-pagerank.md) | Slice parziale TV-032 e TV-035 | Superato localmente per grafo diretto, Degree/WeightedDegree, PageRank, Betweenness e HarmonicCloseness bounded, incrociati con casi a forma chiusa | Non prova componenti/eigenvector centrality, costruzione da testo, persistenza o wiring Kit/CLI |
| [GS-VER-091](evidenze/GS-VER-091-similarita-corpus-persistita-kit-cli.md) | Slice parziale TV-004, TV-011, TV-032, TV-054, TV-056 e TV-073 | Superato localmente per `corpus-term-similarity-v1` persistito, riusato e con parità GlifiCore/Kit/CLI | Non prova Euclidean/Manhattan/KL/JS/Hellinger né le altre primitive di sessione wired; `make verify` bloccato da un problema preesistente non correlato |
| [GS-VER-092](evidenze/GS-VER-092-wiring-persistente-moduli-derivati.md) | Slice parziale TV-004, TV-011, TV-029, TV-031, TV-032, TV-034, TV-035, TV-054, TV-056 e TV-073 | Superato localmente per il wiring persistente e riusabile, con parità GlifiCore/Kit/CLI, di association, dispersion, group-metric, collocations, network, agreement e similarity v2 | Non prova metodi SVD, altre famiglie statistiche, co-occorrenze a finestra, soglie/componenti di rete né UI/planner |
| [GS-VER-093](evidenze/GS-VER-093-pdf-xref-traslazione-corretta.md) | Correzione difetto RQ-061 (export PDF) | Superato localmente per offset xref coerenti dopo la sostituzione dei metadati XMP | Non aggiunge un validatore PDF/A esterno né una validazione strutturale generale |
| [GS-VER-094](evidenze/GS-VER-094-collocazioni-a-finestra-persistite.md) | Slice parziale TV-008, TV-029, TV-032, TV-054, TV-056 e TV-073 | Superato localmente per `corpus-window-collocation-v1` persistito, riusato e con parità GlifiCore/Kit/CLI | Non prova pesatura per distanza, lineage per cella, posizioni né UI/planner |
| [GS-VER-095](evidenze/GS-VER-095-statistica-non-parametrica-e-correlazione.md) | Slice parziale TV-031, TV-054, TV-056 e TV-073 | Superato localmente per Pearson, Spearman, Mann–Whitney, Kruskal–Wallis, Bonferroni/BH e wiring group-metric v2 e correlate | Non prova p-value esatti di correlazione, intervalli, Wilcoxon, bootstrap, permutation, post-hoc né UI/planner |
| [GS-VER-096](evidenze/GS-VER-096-t-appaiato-wilcoxon-cohen-d.md) | Slice parziale TV-031, TV-054, TV-056 e TV-073 | Superato localmente per OneSampleT, PairedT, WilcoxonSignedRank bounded e CohenD-pooled nel confronto di gruppo v3 persistito | Non collega test appaiati a operazioni persistite; nessun intervallo per d né Hedges' g |
| [GS-VER-097](evidenze/GS-VER-097-bootstrap-e-permutazione.md) | Slice parziale TV-031, TV-054, TV-056 e TV-073 | Superato localmente per SplitMix64, BootstrapPercentile, PermutationMeanDifference e confronto di gruppo v4 persistito | Non prova BCa, bootstrap a blocchi, seed come parametro di richiesta né UI/planner |
| [GS-VER-098](evidenze/GS-VER-098-post-hoc-a-coppie-con-famiglie.md) | Slice parziale TV-031, TV-054, TV-056 e TV-073 | Superato localmente per il post-hoc a coppie persistito come nodo separato, con Bonferroni e BH per famiglia e parità GlifiCore/Kit/CLI | Non prova Tukey, Games–Howell, Dunn, contrasti pianificati né UI/planner |
| [GS-VER-099](evidenze/GS-VER-099-tukey-games-howell-dunn-effect-size.md) | Slice parziale TV-031, TV-054, TV-056 e TV-073 | Superato localmente con oracolo R per Tukey, Games–Howell, Dunn, Hedges g, rank-biserial, ε², Fisher-z, Spearman esatto e post-hoc v2 persistito | Contrasti pianificati aperti |
| [GS-VER-100](evidenze/GS-VER-100-bca-contrasti-appaiati-intervalli.md) | Slice parziale TV-031, TV-054, TV-056 e TV-073 | Superato localmente con oracolo R per BCa, contrasti pianificati, confronto appaiato persistito, correlazione v2 e confronto di gruppo v5 con opzioni di richiesta | BCa solo per la media |
| [GS-VER-101](evidenze/GS-VER-101-reti-lessicali-componenti-comunita-lineage.md) | Slice parziale TV-008, TV-029, TV-032, TV-035, TV-054, TV-056 e TV-073 | Superato localmente per componenti, eigenvector (oracolo R), cammini pesati, Louvain, soglie, pesatura per distanza e lineage per cella/arco persistiti | Nessun oracolo esterno per Louvain; grafi molto grandi fuori dimensionamento |
| [GS-VER-102](evidenze/GS-VER-102-svd-ca-pca-lsa-nmf-clustering.md) | Slice parziale TV-032, TV-054, TV-056 e TV-073 | Superato localmente con oracolo R per SVD, CA, PCA, LSA, HAC, k-means e proprietà NMF, persistiti | Nessuna SVD sparsa/randomizzata; LDA, MDS, K-medoids e indici di validazione fuori ambito |
| [GS-VER-103](evidenze/GS-VER-103-accordo-livelli-fleiss-fisher-montecarlo.md) | Slice parziale TV-031, TV-034, TV-054, TV-056 e TV-073 | Superato localmente con oracolo R per Krippendorff per livello, Fleiss, bootstrap di alpha, Fisher esatto e χ² Monte Carlo persistiti | Codebook e codifiche persistite (RF-043) aperti |
| [GS-VER-104](evidenze/GS-VER-104-similarita-pesata-partizioni-xref-blocchi.md) | Slice parziale TV-029, TV-031, TV-032, TV-054, TV-056, TV-073 e RQ-061 | Superato localmente per similarità v3, dispersione v2 con partizioni dichiarate, validazione xref e bootstrap a blocchi | Conformità PDF/A completa richiede un validatore esterno |
| [GS-VER-105](evidenze/GS-VER-105-suite-oracoli-r-igraph-nmf.md) | Slice parziale TV-031, TV-032, TV-034, TV-035, TV-054 e TV-073 | Superato localmente: oracoli R/Python rieseguibili (`make check-oracles`) collegati ai letterali dei test, confronto con igraph (Louvain, modularità, cammini pesati, eigenvector, componenti) e NMF | Richiede R con igraph, NMF e Biobase; PDF/A completo non autorizzato |
| [GS-VER-106](evidenze/GS-VER-106-planner-v2-capability-estese.md) | Slice parziale TV-027, TV-028, TV-054, TV-056 e TV-073 | Superato localmente: planner-v2 con sette capability estese pianificate, eseguite e tracciate nell'interpretazione | Regole interpretative e viste UI delle famiglie estese aperte |
| [GS-VER-107](evidenze/GS-VER-107-validazione-pdfa-verapdf.md) | RQ-061 (export PDF) | Superato localmente: PDF esportati conformi PDF/A-2u secondo veraPDF, controllo negativo FAIL su xref corrotta, integrazione in `make verify` | Corpus PDF dedicato a script e font diversi aperto |
| [GS-VER-108](evidenze/GS-VER-108-scala-reti-e-svd-troncata.md) | Slice parziale TV-032, TV-035, TV-054 e TV-073 | Superato localmente: Dijkstra con heap, Louvain sparso e SVD troncata verificati contro igraph e R, LSA oltre il limite denso | Benchmark release su milioni di celle aperto; CA e PCA dense |
| [GS-VER-109](evidenze/GS-VER-109-benchmark-scala-release.md) | RF-038, RF-039 (prestazioni) | Osservato: SVD troncata su 5 milioni di celle 1,63 s, betweenness su 2 000 nodi 2,75 s, Louvain su 20 000 nodi 0,90 s in release | Soglie da confermare in G4 |
| [GS-VER-110](evidenze/GS-VER-110-policy-di-supporto-adr-0026.md) | GS-UX-006, ADR-0026 | Superato localmente: sette policy di supporto eseguibili e silhouette verificata contro R | Applicazione nell'interprete aperta |
| [GS-VER-111](evidenze/GS-VER-111-findings-famiglie-estese.md) | GS-UX-006, ADR-0026, RF-055 | Superato localmente: findings delle famiglie estese con classi, dimensioni e caveat ADR-0026 | Presentazione dedicata nelle app (P4) aperta |
| [GS-VER-112](evidenze/GS-VER-112-ca-pca-svd-troncata.md) | RF-033, RF-038 | Superato localmente: CA e PCA con backend troncato oltre il limite denso, identiche a Jacobi | — |
| [GS-VER-113](evidenze/GS-VER-113-intenzioni-estese-nelle-app.md) | GS-UX-004, GS-UX-006, RF-049 | Superato localmente: intenzioni estese selezionabili e findings estesi presentati nelle app | Viste dedicate in GS-VER-114 |
| [GS-VER-114](evidenze/GS-VER-114-viste-dei-risultati-estesi.md) | Slice parziale TV-035 e TV-044; RF-046, GS-VIZ-001, GS-MET-001-22 | Superato localmente: grafico fattoriale, dendrogramma, rete e tabella delle collocazioni come specifiche versionate da Artifact persistiti, con tabella equivalente, lineage e oracolo R per l'ordine delle foglie | Audit accessibilità su dispositivo (G4), export delle viste e viste collegate aperti |
| [GS-VER-115](evidenze/GS-VER-115-ponderazione-termini-e-bm25.md) | Slice TV-029; RF-030, GS-MET-001-07 | Superato localmente: varianti TF/IDF, normalizzazioni di riga e BM25-v1 verificate contro R e persistite | Normalizzazione pivotata e BM25F fuori specifica |
| [GS-VER-116](evidenze/GS-VER-116-mtld-bidirezionale.md) | Slice TV-029; RF-027, GS-MET-001-04 | Superato localmente: MTLD bidirezionale con +∞ esplicito verificato contro R e persistito | Oracolo R indipendente, non pacchetto terzo |
| [GS-VER-117](evidenze/GS-VER-117-ngrammi-e-frequenze-filtrate.md) | Slice TV-007, TV-008; RF-019, RF-020, GS-MET-001-04 | Superato localmente: n-grammi di caratteri e di parole con filtri dichiarati verificati contro R e persistiti | Nessuna lista di stopword predefinita per scelta |
| [GS-VER-118](evidenze/GS-VER-118-keyness-fisher-e-intervalli.md) | Slice TV-031; RF-031, GS-MET-001-08 | Superato localmente: selezione di Fisher pre-registrata e intervalli di Katz/Woolf verificati contro R e Python, payload keyness.v2 | Soglie di supporto validate in G4 |
| [GS-VER-119](evidenze/GS-VER-119-tassonomia-failure-eseguibile.md) | Slice TV-071; RQ-058, GS-API-001 § 8 | Superato localmente: tassonomia eseguibile, violazioni corrette, controllo statico nel gate | Asserzione solo in debug |
| [GS-VER-120](evidenze/GS-VER-120-fuzz-deterministico-parser.md) | Slice TV-060; RQ-044, THR-001, THR-009 | Superato localmente: 7.000 input di fuzz deterministico, invarianti di SpanMap e lineage, difetto del doppio BOM corretto | Fuzz guidato da copertura e PDF/OCR aperti |
| [GS-VER-121](evidenze/GS-VER-121-validation-manifest-capacita-estese.md) | Slice TV-059; RQ-045, GS-VAL-001 | Superato localmente: manifest V0–V4 per ponderazione/BM25, MTLD, n-grammi e keyness v2 | Stato candidate fino a review esterna degli oracoli |
| [GS-VER-122](evidenze/GS-VER-122-spanmap-componibili.md) | Slice TV-051; RF-078, GS-DAT-001 | Superato localmente: classe contributive e composizione di SpanMap con conservazione delle origini | Pipeline ancora a un passo |
| [GS-VER-123](evidenze/GS-VER-123-parita-queryast-client.md) | Slice TV-053; RF-080, GS-QRY-001 | Superato localmente: parità QueryAST fra GlifiCore, GlifiKit e CLI sulla fixture di query | GUI verificata per architettura, non su dispositivo |
| [GS-VER-124](evidenze/GS-VER-124-export-viste-con-provenienza.md) | Slice TV-058; RF-084, GS-VIZ-001 § Export | Superato localmente: bundle vista con manifest SHA-256, scrittura atomica e rifiuto di Artifact non correnti | PDF/PNG delle viste aperti |
| [GS-VER-125](evidenze/GS-VER-125-privacy-failure-e-revisioni.md) | Slice TV-051, TV-060; RQ-046, RF-077 | Superato localmente: canary assente da failure e CLI; revisioni distinte e incorporate | Log su dispositivo e riferimenti esterni aperti |
| [GS-VER-126](evidenze/GS-VER-126-storia-qualitativa-persistita.md) | Slice TV-034; RF-043, ADR-0027, GS-MET-001-20 | Superato localmente: storia qualitativa append-only persistita, compatibile e migrata | Operazioni Kit/CLI in C3 |
| [GS-VER-127](evidenze/GS-VER-127-codifica-qualitativa-kit-cli.md) | Slice TV-034; RF-043, RF-044 | Superato localmente: codifica e accordo dalle codifiche in GlifiKit e CLI; BOM nel testo sorgente corretto | UI di codifica aperta |
| [GS-VER-128](evidenze/GS-VER-128-codifica-nelle-app.md) | Slice TV-034; RF-043, GS-UX-001-16, ADR-0029 | Superato localmente: sezione «Codifica» nelle app su GlifiKit | Audit su dispositivo in G4 |
| [GS-VER-129](evidenze/GS-VER-129-selezione-libera-del-passaggio.md) | Slice TV-034; RF-043, GS-UX-001-16 § Accessibilità | Superato localmente: passaggi per frasi, caratteri o byte allineati ai confini di carattere in GlifiCore, GlifiKit, CLI e app | Selezione diretta con il puntatore e audit su dispositivo aperti |
| [GS-VER-130](evidenze/GS-VER-130-determinismo-accordo-e-modularita.md) | Slice TV-028; RQ-025, GS-MET-001-03 § Riduzioni concorrenti | Superato localmente: misure d'accordo e modularità identiche bit a bit dopo la correzione delle somme su contenitori hash | Nessun controllo automatico delle riduzioni nel gate |
| [GS-VER-131](evidenze/GS-VER-131-descrittore-v2-revisioni-dichiarate.md) | Slice TV-007; RF-011, GS-MET-001-01 § Profilo v2, ADR-0028 | Superato localmente: revisioni dichiarate nel descrittore, identità v1 invariata per valore d'oro, digest selettivo stabile dopo un'importazione estranea | Invariante, commit e riuso negli incrementi B e C |
| [GS-VER-132](evidenze/GS-VER-132-invariante-selettivo-e-trasporto.md) | Slice TV-005, TV-054; RF-011, GS-MET-001-02 § Validità e invalidazione, ADR-0028 | Superato localmente: invariante unico per i tre punti di enforcement e trasporto degli Artifact immutati al commit d'importazione | Fabbriche di analisi ancora non dichiaranti (incremento C) |
| [GS-VER-133](evidenze/GS-VER-133-riuso-selettivo-osservabile.md) | Slice TV-005, TV-054; RF-011, GS-MET-001-02 § Riutilizzo, ADR-0028 | Superato localmente: analisi dichiaranti riusate dopo un'importazione estranea in motore, GlifiKit e CLI, con fixture di persistenza v2 nel gate | Piano e interpretazione ancora legati all'intera generazione; nessun benchmark |
| [GS-VER-134](evidenze/GS-VER-134-misura-del-riuso-selettivo.md) | Slice TV-005, TV-009; RF-011, ADR-0024 | Osservato localmente: riuso selettivo a 0,066 s contro 0,333 s a freddo (rapporto 5,08) su corpus sintetico; attese della fixture v1 lette dal caso | Soglie non vincolanti; nessuna misura su corpus reali o hardware di riferimento |
| [GS-VER-135](evidenze/GS-VER-135-messaggi-delle-failure.md) | Slice TV-071; GS-API-001 § 8, GS-UX-001-14 | Superato localmente: ripiego per categoria, chiavi di GlifiKit tradotte e controllo nel gate contro la chiave grezza | Codici interni senza messaggio proprio; nessuna validazione con utenti |
| [GS-VER-136](evidenze/GS-VER-136-approvazione-numerica-e-tolleranze.md) | Slice TV-028; RQ-025, GS-VAL-001, ADR-0031 | Superato localmente: tolleranze dichiarate nei dodici manifest, sette capacità supported con oracolo indipendente e review registrata | Review esterna richiesta prima della 1.0; cinque capacità restano candidate |
| [GS-VER-137](evidenze/GS-VER-137-linea-di-base-tokenizzazione.md) | Slice TV-013; GS-MET-001-18, ADR-0030 | Superato localmente: P/R/F1 sui confini con linea di base legata al digest del corpus, regressione bloccata nel gate | Gold ancora sintetico (19 token): la misura non dice nulla sulla lingua reale |
| [GS-VER-138](evidenze/GS-VER-138-gold-italiano-su-prosa-reale.md) | Slice TV-013; GS-LNG-001, GS-MET-001-18, ADR-0030 | Superato localmente: gold su 434 token di prosa italiana di pubblico dominio, annotazione indipendente in accordo pieno con il prodotto | Un solo autore ottocentesco; dialogo, lemma, POS e NER esclusi |
| [GS-VER-139](evidenze/GS-VER-139-cache-di-build-limitata.md) | Slice TV-063; GS-DEV-002 § Cache di build | Superato localmente: picco su disco da ~37 GiB a 1,8 GiB, seconda esecuzione a 303 s contro 773 s, arresto anticipato se lo spazio non basta | Tetto prudenziale non ottimizzato; misure su una sola macchina |
| [GS-VER-141](evidenze/GS-VER-141-prima-ci-remota-verde.md) | TV-011, TV-013, TV-049; GS-STD-001-20, GS-REP-005, GS-WVR-001…004 | Superato su runner remoto: `verify` verde su `xcode-27` con 257 test, 22 checkpoint di recovery e build macOS/iPadOS; deroghe budget in rientro | Rscript e veraPDF assenti sul runner; dispositivi, firma e TestFlight non coperti; non conformità 2026-09-22→2026-10-03 registrata |
| [GS-VER-146](evidenze/GS-VER-146-riassunto-estrattivo.md) | Slice TV-036; RF-042, GS-MET-001-19, CMP-096 | In verifica: oracolo Python indipendente, test di persistenza e contract test CLI aggiunti; controlli statici superati | Una sola famiglia; nessuna valutazione ROUGE o umana; Rscript assente sul runner |
| [GS-VER-142](evidenze/GS-VER-142-letture-directory-package.md) | Slice TV-060; RF-043, RQ-044, RQ-057, CMP-095 | Parziale: letture descriptor-relative, regressioni su directory simboliche e sostituzioni controllate; statici, lint e compilazione Apple superati | Test compilati, non eseguiti su host 26.5.2; scritture, SQLite, ACL e file provider esclusi dalla garanzia |

## Catalogo delle verifiche pianificate

Incremento [GS-VER-146](evidenze/GS-VER-146-riassunto-estrattivo.md): prima slice di
TV-036 con RF-042, GS-DOR-013 e CMP-096 (`implemented`): riassunto estrattivo
`SentenceTFIDFMean-v1` con budget, tie-break, lineage della frase e distinzione dal generativo;
esito del gate remoto registrato nell'evidenza.

Incremento [GS-VER-143](evidenze/GS-VER-143-ingresso-queryast.md): TV-053 e TV-060,
RF-080, RQ-042, RQ-044, RQ-046, CMP-081. Ingresso QueryAST v1 bounded in Core,
Kit e CLI; parità e input avversari aggiunti al gate. Verifica nativa pendente;
nessuna estensione della garanzia a indice, streaming o audit su dispositivo.

Incremento [GS-VER-142](evidenze/GS-VER-142-letture-directory-package.md): TV-060, RF-043,
RQ-044 e RQ-057, CMP-095. Letture descriptor-relative con regressioni sui link intermedi e
sostituzioni controllate delle directory. Statici, lint e compilazione Apple superati; verifica
dinamica del nuovo incremento pendente su macOS 27. Scritture, SQLite, ACL e file provider
non attestati; CMP-095 resta `blocked`.

Incremento [GS-VER-141](evidenze/GS-VER-141-prima-ci-remota-verde.md): prima CI remota
verde su runner Xcode 27, GS-WVR-001…004 in rientro tardivo (chiusura dopo App Store preflight verde). I test aggiunti da
GS-VER-140 sono stati eseguiti dal runner; CMP-095 resta `blocked` finché la review
non li promuove.

Incremento [GS-VER-140](evidenze/GS-VER-140-accessi-file-package.md): TV-060, RF-043,
RQ-044 e RQ-057, CMP-095. Controlli statici superati; test degli accessi ai file e dei
permessi aggiunti ma non ancora eseguiti. Verifica nativa bloccata dal runtime macOS 26.5.2;
nessuna promozione a requisito verificato.

| ID | Metodo | Evidenza attesa |
| --- | --- | --- |
| TV-001 | Test di sistema | Creazione, chiusura e riapertura di un progetto senza perdita di stato |
| TV-002 | Test di importazione | Importazione dei formati approvati con contenuto e metadati attesi |
| TV-003 | Test di round-trip delle posizioni | Dall'occorrenza indicizzata alla porzione corretta della fonte |
| TV-004 | Test di lineage | Ogni risultato espone corpus, trasformazioni, versioni e parametri |
| TV-005 | Test di invalidazione | Una modifica invalida soltanto gli artefatti dipendenti |
| TV-006 | Test PDF/OCR | Distinzione di provenienza e navigazione a pagina/posizione |
| TV-007 | Test funzionale query | Frequenze, ricerca, filtri e concordanze su corpus noto |
| TV-008 | Test numerico | Risultati confrontati con dataset o implementazione di riferimento |
| TV-009 | Benchmark | Throughput, latenza e I/O sui corpus di riferimento |
| TV-010 | Profiling memoria | Memoria entro la soglia approvata su corpus maggiore della memoria assegnata |
| TV-011 | Test headless | Stesso caso d'uso eseguito senza dipendenza dalla GUI |
| TV-012 | Test negativo e robustezza | Input corrotti, errori strutturati e cancellazione controllata |
| TV-013 | Build/test di piattaforma | Build ed esecuzione dei flussi `Must` sulla matrice macOS, iPadOS e hardware approvata |
| TV-014 | Verifica linguistica italiana | Catalogo e regione `it`, default analitico `it`, locale `it_IT` e fixture italiane entro le soglie approvate |
| TV-015 | Verifica internazionalizzazione UI | Chiavi semantiche, cataloghi `it`/`en`, risorse condivise e build di entrambe le app senza modifiche al motore |
| TV-016 | Verifica privacy e capability | Privacy manifest, App Sandbox, Hardened Runtime, entitlement minimi e assenza di capability non autorizzate |
| TV-017 | Audit accessibilità | Accessibility Inspector, VoiceOver, tastiera, Dynamic Type, contrasto, movimento ridotto e testo localizzato sui flussi `Must` |
| TV-018 | Diagnostica e prestazioni UI | Main Thread Checker, Thread Performance Checker, sanitizer applicabili e Instruments sui flussi critici |
| TV-019 | Benchmark e conformità degli acceleratori | Confronto Swift/CPU, Accelerate, Core ML e Metal applicabili per correttezza, tempo, memoria, energia, termica e cancellazione |
| TV-020 | Disponibilità e provenienza dell'intelligenza locale | Prove con modello disponibile/indisponibile, limiti di contesto, fallback, output probabilistico e metadati persistiti |
| TV-021 | Integrazione con il sistema | Test di App Intents, App Entities, Spotlight, Core Transferable, deep link e BackgroundTasks sui target applicabili |
| TV-022 | Packaging App Store | Identità condivisa, version/build, icone, privacy manifest, sandbox, export compliance, analisi e archivi coerenti |
| TV-023 | Audit dichiarazioni | Comportamento, SDK, dati, Required Reason API, privacy manifest, label e policy confrontati sulla stessa build |
| TV-024 | Validazione di prodotto | Flussi `Must`, accessibilità, dispositivi, prestazioni, TestFlight e modello di accesso soddisfano i criteri approvati |
| TV-025 | Validazione di submission | Record, firma, metadati, supporto, App Review e richiesta `unlisted` accettati nei sistemi Apple |
| TV-026 | Review di conformità scientifica | Ogni metodo pubblico soddisfa il contratto minimo GS-MET-001 e possiede un oracolo indipendente |
| TV-027 | Test di descriptor e DAG | Round-trip, identità semantica, lineage, cicli, invalidazione transitiva e riuso selettivo |
| TV-028 | Test di riproducibilità | D0/D1/P1 ripetuti tra processi, scheduling e backend entro tolleranze e invarianti |
| TV-029 | Reference test testuale-statistico | Conteggi, diversità, distribuzioni, weighting, associazioni e dispersione su fixture note |
| TV-030 | Test matrici massive | Equivalenza in-memory/streaming/sparsa, spill su disco e lineage delle celle |
| TV-031 | Test inferenziale | Keyness, contingenza, test, intervalli, effect size e correzioni multiple contro riferimenti |
| TV-032 | Test multivariato | CA, similarità, clustering, SVD/PCA/LSA/NMF e grafi contro invarianti e riferimenti |
| TV-033 | Valutazione linguistica | Corpus gold per lingua/servizio con precision, recall, F1, accuracy, offset e deriva |
| TV-034 | Test di content analysis | Versionamento codebook, lineage delle codifiche, Cohen's kappa e Krippendorff's alpha |
| TV-035 | Test di visualizzazione e navigazione | Mapping dati-segni, accessibilità e round-trip bidirezionale tra vista e fonte |
| TV-036 | Test di sintesi e topic | Budget, tie-break, source lineage, seed e distinzione estrattivo/generativo |
| TV-037 | Test del dominio dell'indagine | Cardinalità Project/Corpus/Investigation, round-trip, revisioni e integrità dei riferimenti |
| TV-038 | Test della tassonomia delle intenzioni | ID, versioni, slot, famiglie candidate e indipendenza dalle localizzazioni |
| TV-039 | Studio del primo percorso | Creazione, importazione e domanda iniziale senza configurazione algoritmica |
| TV-040 | Test del profilo della raccolta | Accuratezza, provenienza, aggiornamento progressivo, problemi e impatto sul piano |
| TV-041 | Decision table del planner | Applicabilità, esclusioni, costo, fallback, ordine e determinismo del piano |
| TV-042 | Test di navigazione ed esplorazione | Oggetti, ambito, confronto, ricerca, ritorno e spiegazione del piano |
| TV-043 | Test della pipeline epistemica | Evidence/Finding/Caveat, rule set, soppressione, propagazione e confine generativo |
| TV-044 | Test del lineage interattivo | Numero/segno alla fonte con classe exact/contributive/derivational e input equivalenti |
| TV-045 | Studio di comprensione | Sintesi, solidità, caveat, associazione/causalità e approfondimenti su utenti rappresentativi |
| TV-046 | Test dell'interpretazione naturale | Domanda originale, struttura canonica, ambiguità, conferma e piano equivalente |
| TV-047 | Test di storia e relazione | Diramazioni, riapertura, selezione editoriale, attribuzione, export e contenuto generativo ostile |
| TV-048 | Test adattivo e accessibile cross-platform | Flussi semantici su macOS/iPadOS, finestre, dimensioni, tastiera, touch e VoiceOver |
| TV-049 | Verifica della baseline Swift | Xcode 27, compilatore Swift 6.4+, serie 6, language mode 6, tools 6.4, strict concurrency, manifest, `.swift-format`, dialetto e build coerenti |
| TV-050 | Test del modello di dominio | Identità tipizzate, cardinalità, aggregate, revisioni, invarianti e lifecycle |
| TV-051 | Test package e lineage | `.glifi` round-trip, commit/recovery, digest, SourceRevision, SpanMap e migrazione N/N-1 |
| TV-052 | Validazione linguistica italiana | Golden corpus `it-token-v1`, offset esatti, lemma/POS/NER e rapporto di deriva |
| TV-053 | Test QueryAST | Grammatica, precedenza, tipi, Unicode, round-trip, ordine, fuzz e limiti regex |
| TV-054 | Test del sistema analitico | Identità nodo, DAG, deduplica, invalidazione, checkpoint e planner deterministico |
| TV-055 | Test interpretazione e ranking | Decision table, evidence conflict, caveat propagation, non-ridondanza e explanation contract |
| TV-056 | Test runtime concorrente | Task ownership, backpressure, cancellation, progress, actor isolation e stati terminali |
| TV-057 | Benchmark del modello di risorse | Classi S/M/L/XL applicabili con memoria, I/O, energia, termica e rifiuto sicuro |
| TV-058 | Test IA, interazione e visualizzazione | Route, restoration, multiwindow, input equivalenti, VisualizationSpec, lineage e accessibilità |
| TV-059 | Validazione ed export | ValidationManifest V0–V4 per ogni Must ed export PDF/Markdown/CSV/JSON con provenance |
| TV-060 | Test ostile, privacy e recovery | Fuzz, path traversal, regex DoS, corruzione, kill injection, rete/telemetria assenti e diagnostica redatta |
| TV-061 | Audit di completezza prodotto 0.1 | Tutto il percorso Must e i gate G1–G5, nessuna capacità post-MVP esposta come stabile |
| TV-062 | Audit di telemetria e raccolta | Nessun SDK, endpoint, identificatore, subscriber MetricKit o dichiarazione difforme nella build 0.1 |
| TV-063 | Test di logging privacy-safe | Solo facciata e categorie approvate; canary di contenuto, query e path assenti da Console e archivio |
| TV-064 | Test dei signpost | Nomi allowlist, ID effimeri, coppie bilanciate e risultato/errore invariati |
| TV-065 | Test della policy di sostenibilità | Matrice completa intento × Low Power Mode × termica × memoria × attività con profilo atteso |
| TV-066 | Profiling idle e App Nap | Nessun polling, timer, task o assertion residui entro 60 secondi; App Nap eleggibile |
| TV-067 | Audit QoS e attività | Priorità coerenti con intento, token owned e conclusi, idle system sleep consentito |
| TV-068 | Baseline operativa macOS | Instruments e Organizer per energia, CPU, memoria, I/O, launch e hang con regressioni governate |
| TV-069 | Audit export diagnostico | Funzione assente in 0.1; una futura versione prova gesto esplicito, preview, limiti, redazione e cleanup |
| TV-070 | Threat review e prove di sicurezza | Asset/TB/THR GS-SEC allineati; corpus avversario, fuzz, limiti, entitlement e rischio residuo riesaminati |
| TV-071 | Contract test delle failure | Tutte le categorie preservano retry, retained state, terminale unico e messaggi localizzabili non sensibili |
| TV-072 | Kill-injection e crash recovery | Import, indice, DAG, autosave, migrazione ed export interrotti a ogni passo espongono solo generazioni verificate |
| TV-073 | Contract test GlifiKit/GlifiCLI | API surface, Sendable/isolation, progress, cancellazione, exit status, stream JSON e parità fra interfacce |
| TV-074 | Test ExportManifest v1 | Schema canonico, digest, descriptor, backend, provenance, file e assenza di path/fonti non selezionate |
| TV-075 | Audit della matrice di conformità | ID, requisiti, path e promozioni di stato validati automaticamente; campione revisionato manualmente |
| TV-076 | Audit Definition of Ready | Ogni feature in coding possiede outcome, requisiti, dominio/API, failure, UX, verifica, sicurezza e prestazioni applicabili |

## Lacune note

- La baseline 0.1 assegna il profilo Must/Should/fuori perimetro; manca la sua
  approvazione formale al gate G1.
- Esistono incrementi funzionali TXT/Markdown, package, query/KWIC e profilo corpus
  bounded; il percorso Must completo è ancora incompleto.
- TV-009, TV-010 e TV-019 richiedono dataset, soglie e hardware di riferimento.
- TV-020 e TV-021 richiedono funzioni di prodotto e contratti persistenti ancora da implementare.
- TV-026–TV-036 restano parziali: GS-VER-022 prova una slice di TV-029/TV-030 con
  seed indipendente e GS-VER-146 una slice di TV-036 (una sola famiglia estrattiva), ma
  corpus gold, review, streaming e le altre famiglie mancano.
- TV-037–TV-048 richiedono prototipi, utenti rappresentativi, soglie UX, dispositivi
  e tecnologie assistive; la revisione GS-UX valida soltanto contratti e coerenza.
- TV-050–TV-061 richiedono implementazione, fixture, prototipi, benchmark,
  dispositivi e approvazioni; GS-VER-015 valida soltanto struttura e integrazione.
- Il runner `xcode-27` non dispone di Rscript né veraPDF: oracoli numerici e PDF/A
  sono verificati solo dal gate locale (GS-VER-141).
- TV-063, TV-066–TV-069 richiedono flussi reali, corpus canary, build di rilascio e
  hardware; la baseline corrente copre soltanto policy, audit statico e test unitari.
- TV-070–TV-074 e TV-076 restano verifiche parziali: le evidenze correnti provano
  query, analisi, esecuzione ed export PDF/Markdown/CSV/JSON bounded, ma non
  sostituiscono fuzz, recovery completa, progresso intra-nodo o prove kill reali.
- La matrice di conformità è inizialmente campionata sulle clausole ad alto rischio;
  ogni feature deve aggiungere le proprie righe al gate Definition of Ready.
- TV-023–TV-025 richiedono una build funzionalmente completa, identità Apple, URL pubblici e attività nei sistemi Apple.
- La matrice deve essere aggiornata insieme a ogni modifica dei requisiti o dell'architettura.
