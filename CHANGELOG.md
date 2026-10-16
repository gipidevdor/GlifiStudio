<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Registro delle modifiche

Le modifiche rilevanti per utenti, formati, compatibilità, sicurezza e operazioni vengono raccolte qui. Il progetto segue il versionamento semantico quando esisterà un contratto pubblico stabile; prima di `1.0.0`, ogni incompatibilità deve essere esplicita.

## Non rilasciato

### Aggiunto

- Ingresso `query --ast <query.json>` in alternativa a `--text`: QueryAST v1 condiviso
  tra Core, GlifiKit e CLI, limiti durante lettura/decodifica, rifiuto di file non
  regolari e diagnostiche senza contenuto o path (GS-VER-143).
- Riassunto estrattivo deterministico `SentenceTFIDFMean-v1` (GS-MET-001-19, RF-042): frasi
  esistenti selezionate per media dei pesi TF-IDF entro un budget in frasi o token, con rank,
  tie-break per posizione, intervallo sorgente e ordine della fonte; Artifact
  `corpus-extractive-summary-v1`, `analyzeExtractiveSummary` in GlifiKit e `glifi summarize`
  (GS-VER-146).
- Corpus gold italiano su prosa reale di pubblico dominio (Collodi, «Le avventure di Pinocchio»,
  capitolo 1): 434 token lessicali e 19 frasi annotati da un'implementazione del contratto
  indipendente dal tokenizzatore, in accordo pieno con il prodotto (ADR-0030, GS-VER-138).
- Misura della qualità della tokenizzazione italiana (P/R/F1 sui confini di token e frase) con
  linea di base registrata e legata al digest del corpus: il gate fallisce se il punteggio scende
  e segnala quando sale (ADR-0030, GS-VER-137).
- Benchmark del riuso selettivo in `GlifiBenchmark`: analisi a freddo contro ripetizione dopo
  l'importazione di una fonte estranea, con Artifact conservati e rapporto osservato (GS-VER-134).
- Descrittore di analisi `studio.glifi.analysis-descriptor.v2` (ADR-0028): un'analisi può
  dichiarare le revisioni delle fonti che legge e il suo digest di corpus è la radice ristretta a
  quelle revisioni. I descrittori già persistiti non dichiarano nulla, conservano la loro identità
  e i package esistenti si aprono invariati (GS-VER-131).
- Selezione libera del passaggio da codificare (GS-UX-001-16 § Accessibilità): passaggi per frasi
  consecutive, per intervallo di caratteri o per intervallo di byte, allineati ai confini di
  carattere, con anteprima prima della registrazione, comandi `glifi qualitative segments|passage`
  e testo delle codifiche registrate risolto nell'elenco (GS-VER-129).
- Sezione «Codifica» nelle app macOS e iPadOS (ADR-0029, GS-UX-001-16): codebook, codifica per
  frase, ritiro, note e accordo fra codificatori (GS-VER-128).
- Prova di recovery con SIGKILL estesa ai sei checkpoint del commit qualitativo (GS-VER-126).
- Codifica qualitativa da GlifiKit e dal comando `glifi qualitative`: codebook, codifiche,
  ritrattazioni, memo e accordo calcolato dalle codifiche persistite (GS-VER-127).
- Storia qualitativa append-only (ADR-0027): codebook, mapping di categorie, codifiche,
  ritrattazioni e memo persistiti come radice verificata del package, schema 4 additivo e
  compatibile (GS-VER-126).
- Audit con canary della privacy di failure ed errori CLI e contract test delle revisioni
  incorporate delle fonti (GS-VER-125).
- Export delle viste con provenienza: tabella, specifica e manifest con SHA-256, Artifact e
  generazione, scritti in modo atomico; pulsante «Esporta con provenienza» (GS-VER-124).
- Contract test di parità della QueryAST fra GlifiCore, GlifiKit e CLI sulla fixture di query
  (GS-VER-123).
- SpanMap componibili: classe `contributive`, spazio `normalizedUTF8` e composizione che
  conserva tutte le origini (GS-VER-122).
- ValidationManifest V0–V4 per ponderazione/BM25, MTLD e n-grammi (GS-VER-121).
- Fuzz deterministico di importer TXT/Markdown e linguaggio di query nel gate, con invarianti
  di SpanMap, lineage exact, determinismo e tempo limitato (GS-VER-120).
- Tassonomia delle failure eseguibile (`GlifiFailureTaxonomy`) con controllo statico nel gate;
  retry e stato conservato riallineati a GS-API-001 § 8 dove divergevano (GS-VER-119).
- Keyness `keyness-gtest-fisher-ha-ci-bh-v2`: test esatto di Fisher selezionato prima del calcolo
  quando un'attesa è minore di 5, p del G-test conservato, intervalli di confidenza di Katz per
  il log ratio e di Woolf per l'odds ratio; payload `keyness.v2` (GS-VER-118).
- N-grammi di caratteri (grapheme cluster, con o senza marcatori di confine) e frequenze di
  forme e n-grammi con stopword esplicite e soglie dichiarate, da GlifiKit e dal comando
  `glifi ngrams` (GS-VER-117).
- Diversità lessicale `MTLD-bidirectional-v1` per documento e sulla sequenza concatenata, con
  `+∞` esplicito, da GlifiKit e dal comando `glifi diversity` (GS-VER-116).
- Ponderazione dei termini completa (sei varianti TF, IDF non smussata e smussata, normalizzazioni
  di riga L1/L2) e ranking `BM25-v1`, persistiti e disponibili da GlifiKit e dai comandi
  `glifi weighting` e `glifi bm25` (GS-VER-115).
- Viste dedicate ai risultati estesi nel dettaglio del finding: grafico fattoriale CA/PCA/LSA,
  dendrogramma con taglio, rete a layout deterministico e tabella delle collocazioni, come
  specifiche versionate lette dagli Artifact persistiti, con tabella equivalente e lineage
  (GS-VER-114); esportazione CSV della tabella equivalente e JSON della specifica.
- App macOS e iPadOS: intenzioni «esplorare relazioni», «individuare temi» e «trovare elementi simili» e gruppi di confronto per tutte le intenzioni che li usano (GS-VER-113).
- CA e PCA oltre il limite denso con la SVD troncata e backend dichiarato (GS-VER-112).
- Findings delle famiglie estese: l'interprete applica le policy ADR-0026 ai fatti
  estratti dai payload persistiti, con caveat di cautela localizzati e soppressioni
  motivate; silhouette nel risultato del clustering (GS-VER-111).
- Policy di supporto per famiglia di ADR-0026 (chiusura di DA-029) eseguibili in
  `GlifiSupportPolicies` e silhouette di Rousseeuw verificata contro R (GS-VER-110).
- Benchmark di scala riproducibile `GlifiBenchmark` (release) per SVD troncata,
  betweenness pesata e Louvain, con prima osservazione in GS-VER-109.
- Scala delle analisi: Dijkstra con heap binario, Louvain e modularità su righe
  sparse, SVD troncata `SVD-SubspaceIteration-v1` (fino a 5 milioni di celle) usata
  dalla LSA oltre il limite denso, verificate contro igraph e R (GS-VER-108).
- Validazione PDF/A-2u degli export con veraPDF (`Scripts/check-pdfa.py`,
  `make check-pdfa`, inclusa in `Scripts/verify.sh`), con controllo negativo sul
  PDF con xref corrotta (GS-VER-107).
- `planner-v2` con `capability-catalog-v2` (ADR-0025): associazione, collocazioni e
  rete a finestra, Correspondence Analysis, clustering, similarità e confronto di
  gruppo pianificabili ed eseguibili, con lineage nell'interpretazione e catalogo MVP
  invariato (GS-VER-106).
- Suite permanente di oracoli numerici in `Packages/GlifiCore/Tests/Oracles` (R e
  Python) con `make check-oracles`, inclusa in `Scripts/verify.sh`: riesegue gli
  oracoli, confronta con `expected.txt` e verifica che i valori compaiano nei test
  Swift; nuovi confronti con igraph (Louvain, modularità, cammini pesati) e con il
  pacchetto NMF (GS-VER-105).
- Similarità v3 (Jaccard pesato, Dice multinsieme, KL con smoothing Lidstone
  dichiarato), dispersione v2 con partizioni dichiarate (`dispersion --part`),
  validazione strutturale della xref dopo il rendering PDF e bootstrap a blocchi
  mobili (GS-VER-104).
- `KrippendorffAlpha-v2` per livello di misura, `FleissKappa-v1`, intervallo
  bootstrap di alpha, `FisherExact2x2-v1` e `ChiSquareMonteCarlo-v1`, verificati
  contro R; accordo v2 con livello in richiesta e associazione v2 con p Monte Carlo
  (GS-VER-103).
- SVD di Jacobi, `CA-SVD-v1`, `PCA-SVD-v1`, `LSA-SVD-v1`, `NMF-Frobenius-v1`,
  `HAC-v1` e `KMeans-Lloyd-v1` verificati contro R 4.6.0 (NMF per proprietà); nuova
  operazione persistita `analyzeMultivariate` sulla matrice documento×termine con
  comando CLI `multivariate` (GS-VER-102).
- Reti lessicali: componenti deboli e forti, `EigenvectorCentrality-v1` (verificata
  con R), betweenness e closeness pesate su `1/peso`, `Louvain-v1` con modularità;
  collocazioni a finestra v2 con pesatura per distanza, distanza media e posizioni
  sorgente per coppia; nuova rete a finestra persistita con soglie (`window-network`)
  e rete documentale v2 con documenti di supporto per arco (GS-VER-101).
- `BootstrapBCa-v1`, `PlannedContrast-v1`, quantile della t e opzioni di confronto in
  richiesta (livello, B, rietichettature, seed, contrasti); confronto di gruppo v5 con
  BCa, ε², Hedges' g, rank-biserial e contrasti; correlazione v2 con Fisher-z e
  Spearman esatto; nuova operazione persistita `comparePairedMetrics` con comando CLI
  `paired` (t appaiato e Wilcoxon signed-rank) (GS-VER-100).
- Post-hoc specifici `TukeyHSD-v1`, `GamesHowell-v1` e `Dunn-v1`, effect size
  `HedgesG-v1` (con intervallo di d), `RankBiserial-v1`, `KruskalEpsilonSquared-v1`,
  intervallo `PearsonFisherZ-v1` e p esatto `SpearmanExactPermutation-v1`, verificati
  contro R 4.6.0 come oracolo esterno; il post-hoc persistito passa a
  `document-metric-pairwise-posthoc-v2` (GS-VER-099).
- Post-hoc a coppie `document-metric-pairwise-posthoc-v1` come nodo separato
  dall'omnibus: Welch e Mann–Whitney per ogni coppia di almeno tre gruppi, con p
  grezzi, `Bonferroni-v1` e `BenjaminiHochberg-v1` per famiglia dichiarata,
  persistito con `GlifiStudioService.postHocGroupMetric` e comando CLI `posthoc`
  (GS-VER-098).
- PRNG versionato `SplitMix64-v1`, `BootstrapPercentile-v1` della media e
  `PermutationMeanDifference-v1` esatto o Monte Carlo con seed registrato; il
  confronto di gruppo passa a `document-metric-group-comparison-v4` con test di
  permutazione e intervalli bootstrap per gruppo, con parità GlifiKit e CLI
  (GS-VER-097).
- `OneSampleT-v1`, `PairedT-v1`, `WilcoxonSignedRank-v1` (esatto o asintotico
  dichiarato, zeri scartati per policy esplicita) e `CohenD-pooled-v1`; il
  confronto di gruppo passa a `document-metric-group-comparison-v3` con Cohen's d
  come effect size separato, con parità GlifiKit e CLI (GS-VER-096).
- Statistica fondazionale estesa: `PearsonR-v1`, `SpearmanRho-v1`,
  `MannWhitneyU-v1` (esatto o asintotico dichiarato), `KruskalWallis-v1`,
  `Bonferroni-v1` e `BenjaminiHochberg-v1`; il confronto di gruppo aggiunge
  Mann–Whitney e Kruskal–Wallis (`document-metric-group-comparison-v2`) e la
  nuova operazione persistita `correlateMetrics` con `GlifiStudioService.correlateMetrics`
  e comando CLI `correlate` (GS-VER-095).
- Collocazioni a finestra di token (`corpus-window-collocation-v1`): finestra
  simmetrica o direzionale, confini di frase e autocoppie espliciti, universo di
  coppie ordinate nodo→collocato e misure PMI/NPMI/Dice/Jaccard/t-score/logDice,
  persistite come Artifact riusabili, con `GlifiStudioService.analyzeWindowCollocations`
  e comando CLI `window-collocations` (GS-VER-094).
- Wiring persistente di tutte le primitive matematiche rimaste: operazioni
  `analyzeAssociation`, `analyzeDispersion`, `compareGroupMetric`,
  `analyzeCollocations`, `analyzeLexicalNetwork` e `assessCodingAgreement`
  come Artifact riusabili (pattern generico `GlifiDerivedAnalysisArtifactPayload`),
  similarità estesa a Euclidean/Manhattan/Hellinger/JS/KL
  (`corpus-term-similarity-v2`), con parità GlifiKit e comandi CLI
  `association`, `dispersion`, `group-metric`, `collocations`, `network`,
  `agreement` e contract test in `Scripts/verify.sh` (GS-VER-092).
- Operazione `compareSimilarity` (`corpus-term-similarity-v1`: Cosine/
  Jaccard/Dice fra due profili corpus) persistita come Artifact e riusabile
  in GlifiCore, con parità in GlifiKit (`GlifiStudioService.compareSimilarity`)
  e comando CLI `similarity --target --reference`, testo/JSON v1 e contract
  test in `Scripts/verify.sh` (GS-VER-091). Prima primitiva bounded della
  sessione collegata al protocollo generazionale persistente.
- `GlifiNetworkAnalysis` con `GlifiDirectedGraph`, `Degree-v1`/
  `WeightedDegree-v1`, `PageRank-v1` per power iteration con nodi pendenti
  redistribuiti sul vettore di teleport, `Betweenness-v1` tramite l'algoritmo
  di Brandes e `HarmonicCloseness-v1` su distanza hop diretta (GS-VER-090).
- `GlifiCollocationAnalysis` con `PMI-v1`, `NPMI-v1`, `Dice-v1`,
  `Jaccard-v1`, `t-score-v1` e `logDice-v1` su tabella 2×2 di co-occorrenza
  esplicita, ciascuna non definita dove la propria precondizione non è
  soddisfatta invece di uno smoothing implicito (GS-VER-089).
- `GlifiAgreementAnalysis` con `CohenKappaNominal-v1` e `KrippendorffAlpha-v1`
  (nominale), con esclusione delle unità sotto-giudicate ed indefinitezza
  esplicita quando l'accordo atteso satura il dominio (GS-VER-088).
- `GlifiStatisticalFoundation` con `WelchT-v1`, `OneWayANOVA-v1` e p-value
  asintotico t/F tramite beta incompleta regolarizzata condivisa con
  `GlifiContingencyAnalysis` (GS-VER-087).
- `GlifiSetSimilarity`, `GlifiVectorSimilarity` e `GlifiProbabilityDivergence`
  con `JaccardSet-v1`/`DiceSet-v1`, `Cosine-v1`/`Euclidean-v1`/`Manhattan-v1` e
  `KL-v1`/`JSdiv-v1`/`JSdist-v1`/`Hellinger-v1`, ciascuno con le precondizioni
  di dominio dichiarate dalla specifica (GS-VER-086).
- `GlifiDispersionAnalysis` con `GriesDPnorm-v1` e `JuillandD-equal-v1` su
  partizione esplicita, distinti dal `GriesDP-v1` grezzo già persistito nel
  profilo corpus (GS-VER-085).
- `GlifiContingencyAnalysis` con `PearsonChiSquareRxC-v1`, `CramersV-v1` e
  residui grezzi/Pearson/standardizzati su tabelle I×J, esclusione di margini
  degeneri e p-value tramite gamma incompleta regolarizzata (GS-VER-084).
- `GlifiProjectPackage.openReadOnlyRecovery` riapre la più recente generazione
  precedente interamente verificabile quando la generazione corrente fallisce
  la validazione, senza riscrivere manifest, database o oggetti (GS-VER-073).
- Chiave `messageKey` failure/insufficient e `operationID` esecuzione attiva
  in UI (GS-VER-083).
- Catalogo `evidenceReferences` Finding e tipizzazione misure Evidence in UI
  (GS-VER-082).
- Ordine n-grammi corpus e byte/range fonte Evidence in UI (GS-VER-081).
- Espressione Query conservata e coordinate match UTF-8 etichettate in UI
  (GS-VER-080).
- Richiesta selezione editoriale Kit e commit generation/projectID in UI
  (GS-VER-079).
- Richiesta piano/esecuzione Kit (intento, budget, scope, gruppi) in UI
  (GS-VER-078).
- Commit indagine (`projectID`/`generation`) e richiesta di creazione in UI
  (GS-VER-077).
- Metadati teste Investigation (intento, lingua, Finding/eventi, Artifact) in UI
  (GS-VER-076).
- Vocabolario matrice e bound opzioni corpus/keyness in UI (GS-VER-075).
- Identità `projectID` su piano, corpus ed esecuzione in UI (GS-VER-074).
- Progresso esecuzione (`revision`/nodo), argomenti failure e Finding
  selezionati dell'indagine in UI (GS-VER-071).
- Popolazioni keyness, diagnostica e frequenze relative in UI (GS-VER-070).
- Matrice sparsa Kit, unità di carattere e identificatori MSTTR/MATTR in UI
  (GS-VER-069).
- Richiesta export scientifica e progresso Query nel percorso Must
  (GS-VER-068).
- Metadati scientifici corpus e keyness (digest, contratti, frequenze) in UI
  (GS-VER-067).
- Coordinate query, lineage Evidence e metadati indagine in UI (GS-VER-066).
- Provenienza fonti (digest/byte/ID) e fallimenti strutturati in UI
  (GS-VER-065).
- Catalogo capability, scope, dipendenze e backend del piano in UI
  (GS-VER-064).
- Stato terminale, progresso dettagliato e nodi di analisi dell'esecuzione in UI
  (GS-VER-063).
- Digest QueryAST, generazione e fonti corrispondenti in UI query
  (GS-VER-062).
- CollectionPlanningProfile, step/decisioni del piano e Artifact piano in
  esecuzione (GS-VER-061).
- Caveat strutturati (causa/conseguenza/azione) e Artifact piano in UI
  (GS-VER-060).
- Proposizione Finding tipizzata e formati export Must in UI (GS-VER-059).
- Ruolo/regione/range delle SourceReference Evidence in UI (GS-VER-058).
- Checklist candidatura G3 funzionale e limiti ambiente (GS-VER-057).
- Lineage Evidence, uncertainty/effect size e Caveat tipizzati in UI
  (GS-VER-056).
- Dettaglio `insufficientEvidence` e methodIdentifiers Evidence in UI
  (GS-VER-055).
- Navigazione Overview→sezioni Must e severità Caveat in UI (GS-VER-054).
- Definition of Ready operativa (scheda, template PR, check-docs) e CMP-014
  `implemented` (GS-VER-053).
- Confini App→Kit→Core e CMP-001 `implemented` (GS-VER-052).
- ValidationManifest `analysis-execution-v1`, catalogo a otto manifest Must e
  CMP-010 `implemented` (GS-VER-051).
- Artifact di esecuzione, metadati interpretazione e dimensioni assessment in UI
  (GS-VER-050).
- Salto Evidence→fonte in UI Must e ValidationManifest
  `investigation-history-v1` (GS-VER-049).
- ValidationManifest `interpretation-mvp-v1` e catalogo a sei manifest Must
  (GS-VER-048).
- Misure Evidence tipizzate, Artifact keyness e aggiornamento CMP-012 alle
  superfici UI Must (GS-VER-047).
- Progresso percorso Must in Overview, n-grammi/Artifact corpus, revisione
  report in export e a11y strutturale delle nuove azioni (GS-VER-046).
- Trasparenza UI di ranking Findings, policy di supporto e diversità lessicale
  del corpus (GS-VER-045).
- Confronto keyness diretto in UI Must per `compare.objects` (GS-VER-044).
- Analisi corpus diretta in UI Must, ValidationManifest `planner-mvp-v1` e
  catalogo a cinque manifest Must (GS-VER-043).
- ValidationManifest export, storia eventi indagine in UI, stati piano
  localizzati e CMP-012 `implemented` (GS-VER-042); G3 candidato funzionale.
- ValidationManifest `glifi-query-v1`, progresso import multiplo e anteprima
  Markdown dell'export (GS-VER-041).
- DocumentGroup SwiftUI per `.glifi` con UTType `studio.glifi.project`, Info.plist
  document types e bookmark app-scope (GS-VER-040).
- Salto KWIC→fonte via `sourceText` Kit, teste di indagine multiple, cancellazione
  esecuzione e import multiplo nella UI Must (GS-VER-039).
- Selezione editoriale dei findings e riapertura dell'ultimo progetto `.glifi` nella
  UI Must condivisa; deroga GS-WVR-004 / evidenza GS-VER-038 per CI bloccata dal
  budget Actions sulla PR #7.
- Percorso produttivo 0.1: G1 leggero (ADR-0002 accettato, roadmap attiva),
  vertical slice UI Must su GlifiKit (progetto, import, indagine, piano/esecuzione,
  KWIC, findings, export), corpus gold token V0, ValidationManifest V0–V4 per
  profilo corpus e keyness, checklist G4 a11y e runbook App Store unlisted.
- Evidenze GS-VER-034…037 e aggiornamento CMP-016/CMP-017 a `implemented`.

- Loop di qualità locale `make format` / `make lint` / `make quality-static` /
  `make quality` con controllo dialettale `check-swift-dialect`, job CI
  `static-quality` (Ubuntu), `format-check` e `verify` (Xcode 27), più cache SPM
  anche su `app-store-baseline`; autorità stilistica Apple `swift-format`
  (ADR-0020, GS-DEV-002).
- Primo percorso funzionale condiviso: import TXT UTF-8 bounded, digest SHA-256,
  tokenizzazione italiana con offset, profilo e frequenze su macOS e iPadOS.
- Identificatori opachi e tipizzati, tassonomia di failure eseguibile e
  sostituibilità del tokenizer nel motore headless.
- Output JSON v1 di `GlifiCLI status` e contract check nel quality gate.
- Package `.glifi` v1 con manifest commit point, SQLite di sistema, oggetti fonte
  SHA-256 immutabili, verifica di integrità e fault injection generazionale.
- `GlifiStudioProjectSession` actor-isolated e comandi CLI `project
  create|info|validate`/`import` con envelope e codici di uscita v1.
- `QueryAST v1` canonico, parser `glifi-query-v1` bounded, query per forma/frase,
  booleani, prossimità e regex NFA senza backtracking sul corpus TXT incorporato.
- Concordanze KWIC con SourceRevision, offset UTF-8, contesto configurabile,
  troncatura esplicita e comando CLI `query --text` testuale/JSON v1.
- Estrazione Markdown `md-extract-v1` non eseguibile con `SpanMap` totale da
  `extractedUTF8` a `sourceBytes`, entità derivazionali e budget anti-lookahead.
- Importazione, profilo e query Markdown condivisi da app, GlifiKit e GlifiCLI;
  le righe KWIC JSON espongono coordinate estratte e intervalli sorgente.
- Profilo corpus `corpus-profile-it-v1` bounded e riproducibile con conteggi,
  frequenze, document frequency/range, GriesDP-v1, n-grammi, TTR/MSTTR/MATTR e
  matrice documento-termine sparsa con TF-raw/IDF-smooth/TFIDF versionati.
- Operazione `analyzeCorpus` in GlifiCore/GlifiKit, comando CLI `analyze` con
  JSON v1 completo, signpost locale allowlist e reference test indipendente.
- Keyness `keyness-gtest-ha-bh-v1` tra gruppi espliciti con G-test, p-value χ²,
  odds/log ratio Haldane–Anscombe, correzione Benjamini–Hochberg, diagnostica dei
  conteggi attesi, digest, limiti e fixture indipendente.
- Operazione `compareKeyness`, identificatori revisioni nello snapshot pubblico e
  comando CLI `keyness` testuale/JSON v1 con contract smoke end-to-end.
- `AnalysisDescriptor` v1 canonico con algebra di parametri tagged,
  `AnalysisNodeID`/`ArtifactID` SHA-256 tipizzati e decodifica fail-closed.
- Analysis DAG bounded con deduplica, verifica di cicli/dipendenze/schema, ordine
  topologico, sottografo minimo, invalidazione transitiva e riuso selettivo.
- Persistenza transazionale di descriptor, DAG e Artifact content-addressed nella
  generazione `.glifi`, con commit idempotente, verifica fail-closed, invalidazione
  dei discendenti e fault injection sugli stessi sei checkpoint del manifest.
- Payload analitici tipizzati e versionati per profilo corpus e keyness, con
  descriptor pianificato prima del calcolo, dipendenze esplicite, commit automatico
  e riuso senza tokenizzazione anche dopo la riapertura del progetto.
- Risultati Core, GlifiKit e GlifiCLI con generazione sorgente, generazione
  committata, `ArtifactID` e `AnalysisNodeID` per un lineage verificabile.
- `planner-mvp-v1` deterministico con tassonomia completa delle intenzioni,
  catalogo versionato per profilo corpus/keyness, CollectionPlanningProfile,
  budget, dipendenze, caveat, esclusioni, fallback espliciti e piano persistito.
- Operazione `planAnalysis` in GlifiCore/GlifiKit e comando CLI `plan --request`
  con richiesta JSON bounded, output v1 e riuso dopo riapertura.
- Esecutore del piano con admission energetica/termica, verifica del DAG, Artifact
  durevoli in ordine canonico, riuso idempotente e failure fail-closed.
- Stream GlifiKit bounded posseduto dalla `ProjectSession`, progresso monotono,
  cancellazione cooperativa e comando CLI `execute --request` con `--no-progress`.
- Modello `Evidence`/`Finding`/`Caveat` tipizzato e content-addressed con categorie
  epistemiche, SourceReference esatte, misure tagged e payload fail-closed.
- `interpretation-rules-mvp-v1` per profilo corpus e keyness, con SupportPolicy
  specifiche, `editorial-rank-v1`, soppressioni bounded e `insufficientEvidence`
  senza conclusioni o dati inventati.
- Artifact di interpretazione persistito nel DAG e riusato idempotentemente;
  proiezione completa in GlifiKit e JSON CLI con chiavi localizzabili.
- `InvestigationID` e `InvestigationEventID` tipizzati, eventi cognitivi canonici
  `created`/`editorialSelectionChanged` e replay append-only ramificabile.
- Radice InvestigationHistory distinta dagli Artifact nel package `.glifi` schema
  3, conservata su nuova importazione e verificata fail-closed alla riapertura.
- Migrazione additiva manifest/SQLite schema 2→3 e comandi CLI
  `investigation create|select|list` con request JSON bounded.
- ADR-0021 e GS-VER-031 per separazione tra contenuto autorevole dell'indagine e
  output analitici ricostruibili.
- `ReportRevisionID` e `ReportRevision` content-addressed derivati da un head
  Investigation, limitati ai Finding selezionati e alla chiusura delle Evidence.
- `ExportManifest` v1 con corpus, descriptor, backend, determinismo, selezione,
  file, lineage, Caveat e validazione; export JSON/Markdown in staging verificato.
- Operazione export in GlifiCore/GlifiKit e comando CLI `export --request --output`,
  con digest, receipt, tamper detection e tre checkpoint di interruzione pre-commit.
- ADR-0022 e GS-VER-032 per il confine transazionale e privacy-safe dell'export.
- Renderer Apple-native PDF/A-2u con Core Graphics/Core Text, testo ricercabile,
  struttura taggata, paginazione bounded e verifica strutturale.
- Export RFC 4180 `findings.csv`/`evidence.csv` con payload canonici, relazioni,
  protezione formula-like e confronto con la ReportRevision JSON.
- ADR-0023 e GS-VER-033 per i formati PDF/CSV verificabili e interoperabili.
- Harness SwiftPM isolato per process-kill recovery con `SIGKILL` ai sei
  checkpoint di import e Artifact più i quattro checkpoint del commit export,
  riapertura/ispezione in un nuovo processo e retry dei casi pre-commit; gate
  `make check-recovery` (16 checkpoint) integrato in `make verify`.
- GS-VER-072 per la prova di commit atomico con terminazione reale del processo,
  incluso l'export scientifico verso `.glifiexport`.
- Baseline Xcode 27 per app native macOS e iPadOS.
- Package condiviso `GlifiCore`, libreria `GlifiKit` e smoke test headless `GlifiCLI`.
- Standard di progetto, documentazione controllata e portafoglio tecnologico Apple.
- Governo del repository privato, modelli di collaborazione, CI e controlli locali.
- Specifica normativa GS-MET con 22 contratti matematici, statistici, linguistici e algoritmici.
- `AnalysisDescriptor`, Analysis DAG, classi di determinismo e fondazione concettuale `GlifiMath` tramite ADR-0013.
- Requisiti e verifiche tracciate per metodi analitici, content analysis e visualizzazioni scientifiche.
- Specifica normativa GS-UX con 14 contratti per paradigma d'indagine, intenzioni,
  profilo della raccolta, planner, findings, navigazione, lineage, storia e rapporto.
- Modello concettuale di Project/Corpus/Investigation, motore interpretativo
  deterministico e progressive disclosure Conclusione → Evidenza → Fonti → Metodo.
- ADR-0014, requisiti e verifiche tracciate per esperienza macOS/iPadOS,
  accessibilità, comprensione e localizzazione semantica.
- ADR-0015 e verifica TV-049 per distinguere compilatore Apple Swift 6.4,
  Swift 6 language mode e SwiftPM tools 6.4.
- Famiglia GS-DSG con dieci specifiche implementative per dominio, package `.glifi`
  e lineage, italiano, QueryAST, sistema analitico, runtime, UI, visualizzazioni,
  validazione scientifica e product baseline 0.1.
- ADR-0016 per formato di progetto, store SQLite di sistema, oggetti SHA-256,
  SpanMap, perimetro locale e nucleo analitico del primo prodotto completo.
- ADR-0017 e policy macOS per zero telemetria applicativa, Unified Logging
  centralizzato, signpost tipizzati e Xcode Organizer come canale di campo.
- ADR-0018 e `GlifiRuntimePolicy` per Low Power Mode, termica, pressione memoria,
  lifecycle, QoS, App Nap e parallelismo adattivo coperti da test.
- GS-SEC-001 con asset, trust boundary, minacce THR-001–THR-020, input ostili,
  resource exhaustion, modelli, logging, export e gate di sicurezza.
- GS-API-001 per lifecycle GlifiKit, structured concurrency, progressi,
  cancellazione, failure semantics, CLI, exit status e compatibilità pre-1.0.
- Matrice di conformità machine-readable e `make check-compliance`, con stati
  verificabili e blocchi espliciti per le evidenze ancora mancanti.
- Seed verificabili per otto casi linguistici italiani, quattro riferimenti
  numerici e dieci descrittori avversari safe-by-construction.
- ADR-0019 e Definition of Ready rafforzata per spostare il progetto dalla
  completezza documentale alla prova di implementazione.

### Modificato

- Prima esecuzione remota dei workflow sul runner `xcode-27` dopo il ripristino del budget
  Actions: deroghe GS-WVR-001…004 in rientro tardivo con non conformità registrata,
  badge del repository riportato a privato, stato CI allineato (GS-VER-141).

- I ValidationManifest dichiarano la tolleranza numerica, l'oracolo e la review: sette capacità
  passano a `supported`, cinque restano `candidate` perché il loro oracolo è un test del prodotto.
  Il gate impedisce di dichiarare `supported` senza averne i requisiti (ADR-0031, GS-VER-136).

- L'importazione di una fonte non invalida più tutti gli Artifact: conserva quelli il cui corpus
  dichiarato è immutato e la loro catena di dipendenze, invalidando con esattezza solo il resto
  (ADR-0028, GS-VER-132). `project.artifact-corpus-mismatch` significa ora «l'analisi non
  corrisponde più alle fonti che dichiara».
- Profilo di corpus, keyness, similarità e analisi derivate dichiarano le fonti che leggono e
  vengono riusate dopo l'importazione di fonti estranee, senza ricalcolo; piano e interpretazione
  restano legati all'intera generazione (ADR-0028, GS-VER-133).

- Configurazione Dependabot con etichette controllate e aggiornamenti GitHub Actions raggruppati.
- `actions/checkout` aggiornato dalla versione 5.1.0 alla 7.0.1 con SHA immutabile.
- `actions/cache` aggiornato alla 6.1.0 con SHA immutabile e runtime Node 24.
- Quality gate documentale esteso a indicizzazione, copertura e integrazione delle specifiche GS-MET.
- Quality gate documentale esteso alla copertura e integrazione delle specifiche GS-UX.
- Quality gate documentale esteso a presenza, identificatori, copertura e
  integrazione delle dieci specifiche di design.
- Manifest SwiftPM elevato a tools 6.4 e controllo toolchain reso vincolante sulla
  versione minima compatibile, sul language mode e sulla strict concurrency.
- Quality gate Apple esteso per respingere logging libero, output non strutturato,
  rete, MetricKit e SDK di telemetria non autorizzati.
- GS-DAT-001 esteso con commit point formale, recovery per operazione e schema
  riproducibile ExportManifest v1.
- Modello trasversale degli errori esteso con categorie, retry, terminali e stato
  che rimane valido.

### Corretto

- Il test del budget di decodifica QueryAST costruiva un albero `not` di 200 livelli e lo
  codificava con `JSONEncoder` sullo stack limitato di un thread di test: dal merge di GS-VER-143
  `GlifiCoreTests` terminava con segnale 10 (SIGBUS) su `verify` e `app-store-baseline`. L'input
  profondo è ora JSON costruito testualmente; il decodificatore sotto test resta bounded dal budget
  di profondità.
- Gli script di qualità creavano una cache di compilazione nuova a ogni esecuzione: nulla veniva
  riusato e ogni giro riscriveva circa 37 GiB, fino a riempire il disco e far morire il gate con
  «No space left on device». Le cache vivono ora in `~/Library/Caches/GlifiStudio/verify`, riusate
  con un tetto dichiarato e **rimosse al termine**, anche in caso di errore: il picco scende a
  1,8 GiB e sul disco non resta nulla. Il gate si ferma prima di iniziare se lo spazio libero non
  basta. Con `GLIFI_VERIFY_KEEP_CACHE=1` la cache si conserva e la seconda esecuzione passa da
  773 s a 303 s (GS-VER-139). Nuovi comandi `make cache-size` e `make clean-cache`.
- Le failure senza messaggio nel catalogo mostravano all'utente la chiave grezza, per esempio
  `failure.project.io-failed`: ogni categoria ha ora un messaggio di ripiego in italiano e
  inglese, le chiavi emesse da GlifiKit sono tradotte e `check-failure-messages.py` impedisce di
  reintrodurre il difetto (GS-VER-135).
- Le misure d'accordo (Cohen, Krippendorff nominale, Fleiss) e la modularità delle reti lessicali
  sommavano iterando contenitori hash: a parità di input l'ultima cifra poteva cambiare e con essa
  il digest dell'Artifact. Ogni riduzione segue ora un ordine dichiarato ed è identica bit a bit
  (GS-VER-130).
- Il testo sorgente restituito da GlifiKit perdeva un BOM iniziale e risultava spostato di tre
  byte rispetto agli intervalli dell'evidenza (GS-VER-127).
- Un secondo BOM UTF-8 in testa a una fonte TXT o Markdown veniva scartato in silenzio dalla
  decodifica, lasciando testo e SpanMap incoerenti; ora è conservato come contenuto (GS-VER-120).
- Export PDF/A-2u: la tabella `xref` non veniva traslata dopo la sostituzione dei
  metadati XMP, producendo offset errati (testo non estraibile) in circa un export
  su venti; la condizione di riconoscimento delle voci xref è corretta e coperta da
  un test di regressione (GS-VER-093).
- Gate architetturale e smoke del progresso CLI portabili sui runner Xcode privi
  di `ripgrep`, con fallback `grep` fail-closed.

### Sicurezza

- Staging delle transazioni creato esclusivamente tramite directory aperte: `mkdirat`
  `0700`, file `openat`/`O_EXCL` `0600` e promozione dallo stesso descriptor. Regressioni
  per collisioni, sostituzioni controllate e permessi ai checkpoint (GS-VER-145).
  Formato e commit point invariati; accessi path-based al manifest candidato, cleanup,
  SQLite e identità globale della radice restano fuori dall'incremento.

- Pubblicazione di fonti, Artifact, descriptor ed eventi tramite directory aperte: creazione
  privata `mkdirat`, attraversamento nofollow e rinomina esclusiva `renameatx_np` senza
  sovrascrivere oggetti esistenti. Convalida bounded sul descriptor di destinazione e
  regressioni su collisioni e directory sostituite (GS-VER-144). Nessun cambio al formato;
  staging iniziale, manifest replacement, cleanup e SQLite restano fuori dall'incremento.

- Letture di manifest e oggetti del package relative a directory aperte: rifiuto dei link
  intermedi e dei percorsi anomali, mantenimento dei controlli bounded sul file finale e
  regressioni di sostituzione controllata delle directory (GS-VER-142). La garanzia non si
  estende alle scritture o a SQLite; CMP-095 resta bloccata.

- Letture, creazione e permessi dei file persistiti rafforzati, con regressioni sintetiche
  per package ed export; verifica dinamica su macOS 27 ancora necessaria
  ([GS-VER-140](docs/evidenze/GS-VER-140-accessi-file-package.md)).
- Controllo locale di credenziali, materiale di firma e riferimenti immutabili delle azioni CI.

## Politica di compilazione

Le sezioni vuote vengono rimosse al rilascio. Ogni voce descrive l'effetto osservabile e collega, quando applicabile, issue, requisito, ADR, migrazione o advisory senza esporre dettagli riservati.
