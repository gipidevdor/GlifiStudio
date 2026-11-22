# Decisioni aperte

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ISS-001 |
| Tipo | Registro delle questioni e decisioni aperte |
| Versione | 0.23.0 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | Non applicabile; registro operativo |
| Riferimento | ISO/IEC/IEEE 15289:2019, profilo tailored |

Questo registro contiene le scelte che incidono sul prodotto o sull'architettura e che gli appunti non risolvono. Quando una decisione viene presa, il suo esito va registrato in un ADR e la voce va chiusa senza cancellarne la storia.

| ID | Tema | Domanda | Evidenza necessaria | Responsabile | Stato |
| --- | --- | --- | --- | --- | --- |
| DA-001 | Matrice piattaforme | Quali classi di capacità, memoria e dispositivi con macOS 27 e iPadOS 27 sono supportate? | Benchmark CPU/GPU/Neural Engine, bacino utenti e costo della matrice di test | Da assegnare | Parzialmente definita: strategia runtime approvata da ADR-0008 |
| DA-002 | MVP | Quali formati, metodi GS-MET e capacità qualitative appartengono al primo rilascio utilizzabile? | Casi d'uso prioritari, dipendenze analitiche e capacità del team | Iniziatore del progetto | Chiusa: GS-PROD-001 e ADR-0016; G1 leggero registrato 2026-09-16 |
| DA-003 | Progetto | Il progetto incorpora le fonti, le referenzia o supporta entrambe le modalità? | Portabilità, sicurezza, duplicazione e gestione file mancanti | Iniziatore del progetto | Chiusa: incorporate per default, riferimento esterno esplicito; GS-DAT-001, ADR-0016 |
| DA-004 | Persistenza | Quale combinazione usare per metadati, posting list, matrici e cache? | Prototipi e benchmark | Iniziatore del progetto | Chiusa come direzione: SQLite di sistema, oggetti versionati e cache esterna; GS-DAT-001, ADR-0016. Layout fisico da prototipare |
| DA-005 | GlifiStore | Quali requisiti copre il progetto esistente e con quali costi di integrazione? | Valutazione tecnica e prestazionale | Da assegnare | Aperta |
| DA-006 | Offset | Qual è il contratto canonico per collegare byte, testo estratto e posizioni UI? | Prototipi Unicode, PDF e OCR | Iniziatore del progetto | Chiusa come contratto: intervalli UTF-8, representation digest e SpanMap; GS-DAT-001, ADR-0016. PDF/OCR da validare |
| DA-007 | Versionamento | Quali identificatori, digest e formati concreti realizzano versioni, descriptor e Analysis DAG? | Prototipo di serializzazione, invalidazione e migrazione | Iniziatore del progetto | Chiusa come contratto: serializzazione canonica, SHA-256, domain separation e formati versionati; GS-DAT-001, GS-ANA-001, ADR-0016 |
| DA-008 | Linguistica | Quali annotazioni italiane e quali lingue successive devono raggiungere quali soglie qualitative? | Corpus gold, split, metriche GS-MET-001-18 e valutazione dei backend | Iniziatore del progetto | Chiusa per la tokenizzazione: gold su prosa italiana di pubblico dominio con linea di base che blocca le regressioni ([ADR-0030](adr/0030-corpus-gold-italiano-esterno.md)); lemma, POS, NER e soglie assolute restano aperti |
| DA-009 | PDF/OCR | Quale qualità e quali informazioni spaziali devono essere preservate? | Corpus PDF rappresentativo e metriche OCR | Da assegnare | Aperta; presenti solo descrittori avversari, nessun corpus PDF/OCR |
| DA-010 | Query | Qual è la sintassi pubblica per query testuali, linguistiche e sui metadati? | Prototipi API e UX | Iniziatore del progetto | Chiusa come contratto: QueryAST e `glifi-query-v1`; GS-QRY-001, ADR-0016. Usability test richiesti |
| DA-011 | Benchmark | Quali dataset, soglie, dispositivi e margini promuovono Swift, Accelerate, Core ML o Metal a backend predefinito? | Scenari reali, energia, termica e riproducibilità | Da assegnare | Parzialmente definita: criteri e policy runtime approvati da ADR-0008/ADR-0018; baseline hardware aperta |
| DA-012 | Distribuzione | App Store, distribuzione diretta o entrambe? | Sandbox, notarizzazione, plugin/modelli e accesso ai file | Iniziatore del progetto | Chiusa: App Store con distribuzione non in elenco, ADR-0011 |
| DA-013 | Privacy | Quali garanzie esplicite offrire su elaborazione locale, telemetria e dati sensibili? | Posizionamento prodotto e minacce | Iniziatore del progetto | Chiusa per 0.1: locale, nessuna telemetria applicativa, logging tipizzato, Organizer primario e nessun subscriber MetricKit; GS-PROD-001, ADR-0016/ADR-0017 |
| DA-014 | Nome | Il nome Glifi Studio è utilizzabile e registrabile? | Ricerca legale e marchi | Da assegnare | Aperta |
| DA-015 | Governo documentale | Chi approva formalmente le baseline? | Nomina dei ruoli e autorità del progetto | Da assegnare | Parzialmente definita: flusso e responsabilità provvisorie approvati da ADR-0009 |
| DA-016 | Contributi e copyright | Come vengono attestati i diritti sui contributi e chi può autorizzare un futuro cambio di licenza? | Titolarità, modello contributivo, eventuale CLA o DCO | Da assegnare | Aperta |
| DA-017 | Parità e trasferimento | Quali funzioni appartengono a ciascun rilascio e come vengono trasferiti o sincronizzati i progetti? | Flussi prioritari, formato progetto, UX documentale e privacy | Da assegnare | Parzialmente definita: perimetro/parità 0.1 e package portabile definiti; sync e trasferimento post-MVP aperti |
| DA-018 | Identità e firma | Quali bundle identifier, Apple Developer Team, entitlements e profili di firma sono definitivi? | Titolarità dell'account, modalità di distribuzione e capacità applicative | Da assegnare | Parzialmente definita: bundle multipiattaforma candidato `studio.glifi.GlifiStudio`; team e profili aperti |
| DA-019 | Intelligenza generativa | Quali funzioni assistive usano Foundation Models e con quali policy di modello, contesto, retention e fallback? | Prototipi italiani, valutazione qualità, privacy e disponibilità dispositivi | Da assegnare | Aperta; vincoli generali approvati da ADR-0008 |
| DA-020 | Sincronizzazione Apple | CloudKit, iCloud e Handoff appartengono al prodotto e con quale modello di conflitto e uso offline? | Identità cross-device, privacy, quote, migrazioni e UX | Da assegnare | Aperta |
| DA-021 | Integrazione di sistema | Quali entità e azioni esporre a Spotlight, App Intents, Siri e Shortcuts? | Flussi MVP, autorizzazioni, deep link e minimizzazione dati | Da assegnare | Aperta |
| DA-022 | Hosting GitHub | Quali organizzazione o account, piano e URL ospitano il remote privato? | Titolarità, costi, funzioni di protezione, backup e continuità | Iniziatore del progetto | Chiusa: `gpicchiarelli/GlifiStudio`, privato, profilo `solo`; ADR-0012 |
| DA-023 | Ownership del codice | Quali handle o team sono proprietari dei percorsi sensibili? | Identità GitHub verificate e separazione delle responsabilità | Da assegnare | Aperta; `CODEOWNERS` intenzionalmente non attivo |
| DA-024 | Accesso all'app non in elenco | Il possesso del link è sufficiente o gli utenti devono anche essere autenticati e autorizzati? | Pubblico previsto, dati trattati e modello di supporto | Iniziatore del progetto | Chiusa per 0.1: il link è sufficiente, nessun account; non è un controllo di accesso; GS-PROD-001, ADR-0016 |
| DA-025 | Baseline numerica | Quali dataset, implementazioni indipendenti, tipi floating-point e tolleranze approvano ogni variante GS-MET iniziale? | Review scientifica, fixture pubblicabili e confronto cross-backend | Iniziatore del progetto | Chiusa per la 0.1: oracoli eseguibili come implementazione indipendente, tolleranze dichiarate nei manifest e review interna registrata ([ADR-0031](adr/0031-approvazione-numerica-con-oracoli-eseguibili.md)); review scientifica esterna richiesta prima della 1.0 |
| DA-026 | Validazione UX | Quali profili utente, compiti, campione e soglie approvano efficacia, efficienza, comprensione e calibrazione? | Ricerca sul campo, protocollo ISO 9241-210 tailored e studi accessibili | Da assegnare | Aperta; dimensioni definite da GS-UX-001-13 |
| DA-027 | Persistenza dell'indagine | Come serializzare storia ramificata, piani, findings, caveat, selezioni editoriali e stato per-scena? | Prototipi, migrazioni, crash recovery, concorrenza multi-finestra e dimensioni reali | Iniziatore del progetto | Chiusa come semantica: aggregate GS-DOM e package GS-DAT; schema fisico da provare al G2 |
| DA-028 | Policy del planner | Quali intenzioni, famiglie, budget, regole di ridondanza e stime di costo appartengono al primo planner? | Casi d'uso, corpus, benchmark, decision table e review scientifica | Iniziatore del progetto | Chiusa per 0.1: `planner-mvp-v1` limitato al nucleo GS-PROD e regole GS-ANA; soglie da validare |
| DA-029 | Solidità dei findings | Quali SupportPolicy e soglie per famiglia consentono strong/moderate/weak/caution/insufficient? | Simulazioni, corpus gold, effect size, stabilità e studi di comprensione | Iniziatore del progetto | Chiusa: policy per famiglia con soglie da letteratura, nessuno score universale ([ADR-0026](adr/0026-policy-di-supporto-per-famiglia.md)); validazione empirica in G4 |
| DA-030 | Relazione ed export | Quali formati, manifesti di lineage, regole editoriali e livelli generativi sono supportati? | Prototipi interoperabili, accessibilità, round-trip e verifica di attribuzione | Iniziatore del progetto | Chiusa per 0.1: PDF/Markdown umano, CSV/JSON macchina ed ExportManifest; generazione esclusa; GS-DAT/GS-PROD |
| DA-031 | Stabilità GlifiKit/CLI | GlifiKit è già un SDK binario stabile e quali garanzie offre la CLI? | Client esterni, API surface, contract test, distribuzione e costo library evolution | Iniziatore del progetto | Chiusa per 0.x: contratto source-visible compilato con le app, nessuna ABI/module stability o SDK binario; GS-API-001, ADR-0019 |
| DA-032 | Estensione analitica post-0.1 | Le famiglie escluse dalla 0.1 (CA, PCA/LSA/NMF, clustering, reti, collocazione avanzata, statistica estesa) entrano nel planner? | Oracoli GS-VER-099…105, persistenza e parità Kit/CLI | Iniziatore del progetto | Chiusa: `planner-v2` con catalogo esteso per l'incremento post-0.1, baseline 0.1 invariata ([ADR-0025](adr/0025-estensione-analitica-planner-v2.md)) |
| DA-033 | Invalidazione selettiva | Gli Artifact che dipendono solo da revisioni selezionate restano validi dopo l'importazione di altre fonti, con descrittore v2 che dichiara le revisioni? | GS-MET-001-02; invariante attuale del package (GS-DAT-001) | Iniziatore del progetto | Chiusa: opzione 2 (descrittore v2 con revisioni dichiarate), attuazione in tre incrementi ([ADR-0028](adr/0028-invalidazione-selettiva-alla-reimportazione.md)) |
| DA-034 | Codifica nelle app | La codifica qualitativa, esclusa dalla baseline 0.1, entra nelle app? | ADR-0027; GS-PROD-001 | Iniziatore del progetto | Chiusa: estensione post-0.1 documentata ([ADR-0029](adr/0029-codifica-qualitativa-nelle-app.md)) |

## Prossime decisioni consigliate

Per il percorso produttivo 0.1 (UI Must + validazione) non restano decisioni bloccanti:
**DA-008** è chiusa per la tokenizzazione da ADR-0030, **DA-025** da ADR-0031 e DA-029 da
ADR-0026. Di DA-008 restano aperti lemma, POS, NER e le soglie assolute, che non bloccano la 0.1. DA-001, DA-011,
DA-015, DA-023 e DA-026 restano **parcheggiati** finché non bloccano G3: non
interrompono la vertical slice UI sul Kit.

DA-005 e DA-009 richiedono prototipi post-baseline; DA-019–DA-021 restano
intenzionalmente post-MVP. Una futura distribuzione separata di GlifiKit riapre
DA-031 mediante una nuova ADR.
