<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Registro delle modifiche

Le modifiche rilevanti per utenti, formati, compatibilità, sicurezza e operazioni vengono raccolte qui. Il progetto segue il versionamento semantico quando esisterà un contratto pubblico stabile; prima di `1.0.0`, ogni incompatibilità deve essere esplicita.

- Copertura applicativa delle famiglie analitiche del core: laboratori corpus,
  statistica, valutazione e operatori, ricerca per metodo, risultati con input
  effettivi e stato di convergenza; revisioni qualitative complete e mapping.
  Export delle viste con preparazione asincrona ed errori espliciti (ADR-0041,
  GS-VER-223; audit applicativi distinti).

## Non rilasciato

### Copertura BDD e CSV

- Tutte le 172 varianti pubbliche sono associate a casi nominali, input non
  validi e cancellazione preventiva; tutte le 63 fixture testuali originali
  sono eseguite invariate. Il gate confronta registro, inventario upstream e
  report: 16 feature, 744 scenari e 3092 passaggi (GS-DOR-337).
- Cinque gruppi di fonti primarie web sono riesaminati per condizioni e uso:
  solo fatti e metodi di riferimento, con fixture originali; nessun corpus,
  codice o suite esterna acquisita (GS-LIC-003).
- Corretto l'export CSV di campi contenenti CRLF senza altri delimitatori:
  quoting basato sugli scalari Unicode, byte conservati e verifica fail-closed
  anche dopo rehash. I bundle storici malformati vengono rifiutati; API e
  schema restano invariati (GS-DOR-338).

### Sviluppo BDD e interazione macOS

- Cucumber entra nel ciclo RED/GREEN: `make test-bdd-list` elenca le selezioni;
  `make test-bdd-dev BDD_SELECT='TextQuery.feature:20'` esegue uno scenario o
  un'intera feature e richiede esattamente gli esiti selezionati. Il gate
  completo continua a richiedere tutti gli scenari (GS-DOR-334).
- Ricerca: risultato, espressione, selezione e fonte sono pubblicati insieme;
  interruzioni conservano il contesto valido. La bozza modificata è distinta
  dai risultati e i prerequisiti offrono azioni reali di salvataggio,
  apertura o importazione (GS-DOR-335).
- Catalogo: Invio apre soltanto un risultato unico tra strumenti e metodi,
  con conteggio e istruzioni localizzati. Nome e valore degli stati accessibili
  sono conservati; le nuove failure usano un annuncio di sistema senza
  spostare il focus (GS-DOR-336).

### Specifiche comportamentali eseguibili

- CucumberSwift fissato alla versione 6.9.0 nel solo target di test BDD:
  feature italiane per progetto, query, corpus, codifica, export e parità CLI,
  con oracoli espliciti, failure e conservazione dello stato (GS-DOR-332).
  `make test`, `make test-bdd` e `make verify` richiedono il report completo.
  La base iniziale contava 8 feature, 122 scenari e 697 passaggi verificati;
  la copertura corrente è descritta nell'incremento GS-DOR-337 sopra. Il runner CLI termina e
  raccoglie il processo su timeout o cancellazione. Trait upstream disabilitati
  esplicitamente; licenze MIT, pin e confine test-only sono verificati.

### Correttezza semantica e conservazione del contesto

- Query: capability verificate sull'intero AST prima delle fonti; regex non
  implementate rifiutate senza reinterpretazione, con codec v1 conservato
  (GS-DOR-327).
- Statistica: correzione delle dipendenze da unità e offset nelle permutazioni
  e degli overflow/underflow intermedi di inferenza, bootstrap e quantili
  (GS-DOR-328). Revisione produttore 3 per confronti di gruppi, post-hoc e
  paired, con storici leggibili e famiglie indipendenti conservate.
- Codifica: il cambio fonte pubblica insieme identità, segmenti e testi
  soltanto dopo letture riuscite; failure e cancellazione conservano il
  contesto precedente e consentono il retry (GS-DOR-329).
- Corpus: limiti correnti di vocabolario, n-grammi e matrice applicati anche
  agli Artifact riutilizzati, senza duplicare risultati scientificamente
  identici (GS-DOR-330).
- Export delle viste: nodo, analisi e metodo confrontati con la fonte
  autorevole; metadati contraddittori o payload corrotti impediscono la
  pubblicazione. Errori di ammissione riferiti all'export, messaggio mirato
  it/en e scelte lecite degli assi conservate (GS-DOR-331).

### Prestazioni statistiche con correttezza conservata

- Keyness: quantile dell'intervallo calcolato una sola volta per confronto,
  mantenendo ammissioni, cancellazione, risultati e digest (GS-VER-324).
- Quantile normale: passi Halley protetti restringono il bracket prima della
  bisezione finale; conservati contratto D1, code e tolleranze (GS-VER-325).
- Griglia R indipendente estesa a BCa/effect-size, con attestazione dei bit
  degli input e delle attese. Il candidato beta/gamma è scartato perché il
  guadagno non supera stabilmente il rumore (GS-VER-326).

### Licenze, distribuzioni statistiche e cancellazione delle viste

- Inventario delle fonti e avvisi Snowball/SplitMix; attribuzione Wikisource
  distinta dalle annotazioni originali. LICENSE e avvisi di terzi inclusi nel
  bundle con controlli su contenuto e risorse (GS-VER-318, GS-VER-321).
- Esempio LR/FLR derivato da una pubblicazione sostituito da un grafo sintetico
  originale, con oracolo Decimal indipendente e copertura conservata
  (GS-VER-323).
- Nuclei beta/gamma e quantile normale riscritti da identità matematiche,
  log-gamma nativo reentrant; corrette le code estreme e aggiornate
  selettivamente le revisioni della cache (GS-VER-319).
- Export delle viste cancellabile prima della pubblicazione, con staging
  rimosso e file utente conservati; successo mantenuto dopo commit
  (GS-VER-320).

### Cancellazione dell'export e precisione dei controlli

- Export scientifico cancellabile ai checkpoint prima del rename finale;
  staging rimosso e successo conservato dopo il commit (GS-DOR-317).
- Confronto degli oracoli significativo anche per NB/SOM/JS molto piccoli;
  eccezioni limitate ai sei residui di arrotondamento già documentati
  (GS-DOR-316).
- Output temporaneo della validazione PDF/A rimosso anche se l'export
  preliminare fallisce o viene interrotto; input espliciti preservati
  (GS-DOR-315).

### Ricerca statistica e verificatori automatici

- Ricerca statistica macOS coerente con numeri e simboli mostrati nel locale
  della tabella, conservando i valori scientifici e la ricerca canonica
  (GS-DOR-313; verifica del candidato in GS-VER-313).
- Controllo PDF/A subordinato anche all'exit status di veraPDF; numeri non finiti
  rifiutati esplicitamente nei confronti e collegamenti degli oracoli
  (GS-DOR-312; verifica del candidato in GS-VER-312).
- Ammissione in gruppo dei documenti ricchi con indice locale dei soli
  Artifact selezionati, preservando limiti, candidati ignorati e ordine degli
  errori; nessun cambiamento ai dati persistenti (GS-DOR-314; GS-VER-314).

### Invarianti interne delle regole e degli errori

- Tipizzati gli operatori binari dell’AST privato delle regole, con precedenza
  e applicazione esaustive; lexer, valutazione eager, evidenze e budget conservati
  (GS-DOR-286).
- Condivisa la tabella di traduzione failure già identica fra TextAnalytics ed
  ExploratoryCompletion; le policy delle altre famiglie restano esplicite.
- Resa deterministica la prova di cancellazione MDS/SOM dopo un passo completo,
  con checkpoint interni e contratti pubblici invariati; eliminata la dipendenza
  dal tempo di ripresa del test (CMP-288).

### Progetto Xcode completo — GS-DOR-306

- Navigator esteso ai file del repository con cartelle native senza membership
  di build, gruppo Tests e package GlifiCore visibile; Sources delle app e dei
  test preservati.
- Configurazioni hostless Debug/Release distinte, dipendenza GlifiKit esplicita
  nei test e schema macOS con analisi Release e build dei test solo per testing.
- Descrizione del documento localizzata it/en tramite InfoPlist.xcstrings;
  rimossa la chiave secure-restoration non documentata, conservando la policy
  AppKit degli SDK supportati senza nuovo delegate o entitlement.
- Controllo di grafo/inventario con parser nativo e profilo portabile distinto,
  fixture negative e guard lessicale sulle definizioni duplicate. Gate, nativi
  Debug/Release e archivio macOS senza firma superati sul checkpoint 328169f7
  (GS-VER-306); il nuovo Core 305 e le prove interattive restano separati.

### Test degli scenari di analisi

- Producer del piano versione2 per separare la cache della policy corretta dai piani storici, che restano leggibili e immutati; nessuna migrazione del package o cambio di schema.

- Il planner addebita il bundle keyness al budget aggregato prima delle analisi successive, impedendo piani che superano il limite richiesto. Nove casi di confine riproducono e verificano la correzione.

- Test degli scenari di analisi: inventario controllato delle operazioni, integrazione di progetto e revisioni, planner completo e casi limite dei modelli macOS (GS-VER-303).

### Componenti e campi nativi macOS — GS-DOR-304

- Tab native nei rami compatti dei sette laboratori, mantenendo i pannelli
  ridimensionabili con spazio ampio e le selezioni esistenti.
- Editor Valutazione con etichette permanenti, campi verticali e contesto
  accessibile delle azioni ripetute. Nessuna modifica ad analisi o dati;
  gate e preflight macOS superati sul checkpoint 9c9e0098 (GS-VER-304),
  audit interattivi aperti. Gli editor annidati conservano ForEach Binding
  nativi e identità UUID, con ordinali preparati una volta per collezione.

### Robustezza di query, ingressi e chiusura

- Eliminati overflow con limiti KWIC/slop estremi e troncamenti intermedi che
  alteravano prossimità e ordine dei risultati; budget Core separati e failure
  esplicite per ancore e passi, con default condivisi da Kit e CLI.
  Il costruttore Core originale resta utilizzabile anche come valore funzione.
- Lettore CLI bounded su un solo descrittore anche per le richieste legacy;
  errori di file assente, permessi e dimensione seguono la tassonomia comune.
- Chiusura della finestra con cancellazione e attesa delle attività possedute
  prima del rilascio della sessione e degli accessi autorizzati.
- Cache di verifica con proprietà riconosciuta ed esclusione reciproca;
  pulizia senza scansione globale dei temporanei di altre esecuzioni.

### Codifica delle identità canoniche

- Query e tabelle di accordo riusano il codificatore SHA-256 interno,
  conservando i byte canonici e tutti i comportamenti di validazione.
- Revisioni di report e helper dei manifest scientifici mantengono identità,
  preimmagini e formato v1 con la stessa codifica bounded (GS-VER-179).
- Il supporto dei benchmark distingue esplicitamente SHA del produttore,
  incluso nella misura, e checksum di verifica fuori timer.

### Ottimizzazioni complementari di grafi ed export

- Riutilizzo dei buffer nelle visite di betweenness, con ordine numerico e
  fallback estremi conservati bit per bit (GS-VER-177).
- Codifica UTF-8 dei digest degli export visuali, con bundle e controlli di
  integrità invariati; misure distinte del digest e delle operazioni complete
  (GS-VER-178). Le misure locali sotto contesa restano informative.

### Struttura interna e ownership

- Priorità operativa macOS persistita in Make, CI e istruzioni: ingressi predefiniti
  sul profilo macOS con tutti i controlli condivisi; iPadOS rinviato ai target
  espliciti `*-all`. Comandi e policy verificati dal checker del loop.

- Contratti valore, bootstrap e sessione Kit separati per responsabilità; policy
  ordinarie condivise senza cambiare API o mapping specializzati.
- Staging e costruzione digest/manifest del package centralizzati in helper
  privati, conservando ordine I/O e checkpoint delle quattro famiglie.
- Sessioni CLI chiuse anche su failure e cancellazione prima della presentazione;
  raccolta dei risultati execute/visualize condivisa, protocollo invariato
  (GS-VER-280).

### Integrazioni native Apple coordinate

- Letture esterne Foundation coordinate e bounded prima della decodifica, con
  verifica del descriptor e cancellazione fra chunk.
- Attività macOS finita per il piano richiesto dall’utente, con rilascio su ogni
  uscita e idle sleep consentito; comandi nativi sidebar e toolbar nella scena.
- Valutazione del sort Accelerate con confronto completo bitwise: candidato
  scartato per assenza di beneficio robusto; produzione Swift invariata (GS-VER-260).
- Valutazione del portafoglio Apple GS-APL-016, rispettando le aree in lavorazione
  nelle altre chat e i contratti di precisione, privacy e persistenza esistenti.

Le voci GS-VER-168/169/170 conservano gli esiti dei rispettivi snapshot del
working tree sorgente; la verifica della nuova integrazione su `fe6f654`
è registrata separatamente in GS-VER-171 e pubblicata con `2386787`. La variante parametrizzabile
conserva l’identità candidata distinta `TextRankSentence-configurable-v1`,
preservando i metodi upstream già pubblicati.

### Corretto

- Il decoder UTF-8 rifiuta ora range negativi, vuoti o invertiti che il decoder
  precedente lasciava passare; le span map verificano inoltre i vincoli locali
  dei segmenti prima di lookup/composizione. JSON valido invariato; i dati
  malformati richiedono correzione esplicita, senza riparazione automatica
  (ADR-0042).
- Riverifica analitica: intervalli/byte UTF-8, overflow dei conteggi, grammatica e
  lavoro della codifica, ammissione Naive Bayes/KK/LDA, norme estreme SOM/CLARA/HAC.
  Nuova `GirvanNewman-inverse-strength-exact-binary64-v2` con somme dei costi
  rappresentati esatte e budget più restrittivi. Corrette le dichiarazioni di
  completezza KH: alcune preparazioni e varianti restano assenti (GS-VER-234).

### Aggiunto

- Importazione PDF ed EPUB in app, GlifiKit e CLI: PDFKit per il testo digitale,
  Vision per pagine scansionate e lettore EPUB statico con componenti di sistema.
  Originale e testo acquisito restano nello stesso commit, con pagine/capitoli,
  metadati e provenienza OCR; la riapertura non riesegue l'estrazione.
  Nuovi casi `pdf`/`epub` e provenienza opzionale nel risultato `source-text`.
  Il primo import ricco aggiorna lo store a SQL5 e richiede reader 2;
  TXT/Markdown conservano il percorso precedente. Limiti in GS-VER-310.

- Varianti native del laboratorio analitico: comunità Girvan–Newman/CNM/Walktrap,
  layout FR/KK, foresta Prim, Simpson, MDS ordinale e multi-start, SOM esagonale
  con diagnostiche, selezione K LDA e pipeline italiana opzionale. Nove operazioni
  aggiuntive nello stesso contratto GlifiKit/CLI; GUI e approvazione scientifica
  delle nuove varianti restano separate (ADR-0035, GS-VER-233).

- Parità continua fra GlifiKit e CLI: ingressi condivisi `statistics`, `operator`,
  `evaluation`, `project-call` e `profile`, con parametri di corpus e keyness
  completi, valutazione linguistica/temporale ed export delle viste. Inventario
  pubblico derivato dal compilatore e confronto integrale delle fixture CLI/Kit
  nel gate; gli stati scientifici rimangono invariati (ADR-0036, GS-API-003;
  verifiche osservate e limiti in GS-VER-275).
  L'importazione accetta il formato esplicito indipendente dall'estensione e
  restituisce il profilo nativo completo in `lastProfile`, aggiungendo conteggi
  di byte/token di superficie e termini ai campi JSON precedenti.
- Profili KH pubblici completati in Core/Kit/CLI: preparazione e contesti,
  tie MDS primary, SOM online a due fasi/PCA, scaling CA, sette misure di
  collocazione e associazione documentale, LR/FLR, punteggi TF/IDF, Ward.D2
  algebrico, χ²/Yates e classificazione incrementale con valutazione kappa. Contratti e limiti in
  GS-VER-300; nessuna promozione scientifica automatica.


- Grafici audio di VoiceOver per le mappe fattoriali, con sintesi specifica per
  CA, PCA e LSA. Le righe delle fusioni del dendrogramma aprono le fonti anche
  da tastiera. Su iPad con tastiera hardware, la navigazione, la ricerca e
  l'importazione operano sulla finestra del progetto attivo (GS-VER-270).

- Riprogettazione applicativa per compiti e accesso diretto agli strumenti già
  realizzati, con ricerca delle destinazioni, contesto del progetto e parametri
  progressivi. Il laboratorio avanzato macOS usa GlifiKit con risultati di
  sessione distinti dagli Artifact persistiti; ADR-0034 e GS-DOR-222 governano
  l'integrazione, con verifiche autonome in GS-VER-222.


- Varianti native del laboratorio analitico: comunità Girvan–Newman/CNM/Walktrap,
  layout FR/KK, foresta Prim, Simpson, MDS ordinale e multi-start, SOM esagonale
  con diagnostiche, selezione K LDA e pipeline italiana opzionale. Nove operazioni
  aggiuntive nello stesso contratto GlifiKit/CLI; GUI e approvazione scientifica
  delle nuove varianti restano separate (ADR-0035, GS-VER-233).
- Completamento delle primitive analitiche specificate: distribuzioni lessicali,
  fitting diagnostico Zipf/Heaps, statistiche descrittive Q7, Welch ANOVA,
  aggregazioni temporali con esposizione e metriche di valutazione linguistica.
  Nuove facciate GlifiKit concorrenti; contratti headless candidati (GS-VER-168).
- Riassunti TextRank e LexRank continuo/a soglia nel percorso Core/Kit/CLI,
  con parametri persistiti e diagnostica di convergenza; taglio HAC a soglia
  e contratti numerici più robusti per K-means, NMF, Pearson e PageRank (GS-VER-168).

- Metodo `TextRankSentence-v1` del riassunto estrattivo: centralità stazionaria del grafo di
  sovrapposizione lessicale (`|T(s) ∩ T(u)| / (ln|s| + ln|u|)`, soglia zero, nodi pendenti
  uniformi, damping 0,85) con limiti condivisi con LexRank e `--method TextRankSentence-v1` in
  `glifi summarize`; messaggi delle failure a grafo estesi a entrambi i metodi; GS-VER-166,
  CMP-165 `implemented`.

- Osservazioni lessicali e leggi empiriche `corpus-lexical-laws-v1`: rank-frequency con
  troncamento dichiarato, spectrum, vocabulary growth `GrowthCheckpoints-linear-v1` e fit
  `ZipfLogOLS-v1`/`HeapsLogOLS-v1` separati, con residui, dominio dell'esponente e avviso
  descrittivo; `analyzeLexicalLaws` in GlifiKit e `glifi laws`; GS-VER-220, CMP-166
  `implemented`.
- Unità di budget `Budget-characters-v1` del riassunto estrattivo: costo in scalari Unicode del
  testo sorgente esatto di ogni frase, stessa selezione delle altre unità e `--characters <n>`
  in `glifi summarize`; nessun nuovo campo nel payload; GS-VER-165, CMP-164 `implemented`.
- Metodo `LexRankSentence-v1` del riassunto estrattivo: centralità stazionaria del grafo coseno
  continuo dei vettori frase (damping 0,85, tolleranza `10⁻¹²`), limiti fail-closed su 2 000
  nodi e 1 000 iterazioni, `--method LexRankSentence-v1` in `glifi summarize`; GS-VER-164,
  CMP-163 `implemented`.

### Verificato

- Completamento headless KH: 561 test Core/Kit in Debug e Release, 90 controlli
  CLI, 194 righe di oracoli, 195 esecuzioni macOS, recovery/PDF e build
  macOS/iPadOS Debug/Release superati localmente. Nuove varianti scientifiche
  candidate; GUI separata (GS-VER-233).

- Lotto macOS KWIC, contesto visuale e lookup fonti verificato sul checkpoint
  ffbfb431 di 924 file: 486 test Core/Kit, 224 esecuzioni native, gate e
  preflight senza firma superati (GS-VER-230/231/232). WIP 223 e layout GUI
  successivi esclusi; generazione 4d6969dd conservata separatamente.

- Riprogettazione della GUI: `make verify` completo macOS/iPadOS superato sullo
  snapshot isolato `c77d0e37…0129f`, con 423 test package, 224 esecuzioni native,
  194 righe di oracoli, due PDF/A-2u e build Debug/Release di entrambe le app.
  Osservazione GUI parziale; verifica visiva dell'ultima correzione header,
  audit assistivi e valutazione ergonomica ancora aperti (GS-VER-222).


- Completamento headless KH: 561 test Core/Kit in Debug e Release, 90 controlli
  CLI, 194 righe di oracoli, 195 esecuzioni macOS, recovery/PDF e build
  macOS/iPadOS Debug/Release superati localmente. Nuove varianti scientifiche
  candidate; GUI separata (GS-VER-233).
- Audit di conservazione dei contenuti prima dell’integrazione: sette branch
  storici hanno alberi identici ai commit squash già in `main`; nuova integrazione
  delle PR #37/#38 e gate locale `make verify` superato (GS-VER-221).

- Unità di budget `Budget-characters-v1` del riassunto estrattivo: quattro controlli CI
  `xcode-27` sulla head di #31 e su `main` `4c59a50`; GS-VER-165 superata, CMP-164 `verified`.
- Metodo `LexRankSentence-v1` del riassunto estrattivo: quattro controlli CI `xcode-27` sulla
  head di #29 e su `main` `aaf8ff3`; GS-VER-164 superata, CMP-163 `verified`.
- Ridondanza `MMR-v1` del riassunto estrattivo: quattro controlli CI `xcode-27` sulla head
  definitiva di #24 e su `main` `dfdcdbe` e `a86a53b`; GS-VER-151 superata, CMP-106 `verified`.
- Creazione e apertura documentale non distruttiva su macOS: gate CI `xcode-27` (`verify`,
  `app-store-baseline`) su `main` `a86a53b`, compreso `xcodebuild test` di `GlifiStudio-macOS`;
  GS-VER-163 superata, CMP-107 `verified`.

- Keyness macOS e riuso corretto verificati sullo snapshot di 854 file:
  448 test Core/Kit, 195 esecuzioni native, 153 righe di oracoli, due PDF/A-2u,
  CLI/recovery e build/analisi/archivio macOS senza firma superati. CMP-198/199
  `verified` nel solo perimetro automatico, con archivio riproducibile; GUI,
  iPadOS e G4 restano distinti (GS-VER-198/199).

- Collegamento documentale e ponderazione diretta macOS verificati sul nuovo
  snapshot di 830 file: 433 test Core/Kit, 128 esecuzioni native, 153 righe di
  oracoli e due PDF/A-2u; CLI/recovery e build/analisi/archivio macOS senza firma
  superati. CMP-196/197 `verified` nel solo perimetro automatico; sorgenti e
  risultati conservati, nessuna attestazione G4 o iPadOS (GS-VER-196/197).

- Lotto applicativo macOS verificato su snapshot di 768 file con manifest SHA-256:
  399 test Core/Kit, 45 esecuzioni native, 152 righe di oracoli, due PDF/A-2u,
  CLI e recovery superati; build Debug/Release e analisi/archivio macOS senza firma
  validi. Archiviati sorgenti e risultati riproducibili (GS-VER-188). Nessuna
  attribuzione al gate iPadOS, CI remota, audit VoiceOver o G4.

- Variante `CentroidCosine-v1` del riassunto estrattivo: gate nativo locale e quattro controlli
  CI `xcode-27` sulla head definitiva di #22 e su `main` `3fa454f`; GS-VER-149 superata,
  CMP-097 `verified`.
- Promozione/staging privato del package e letture bounded degli export:
  gate nativi locali e CI superati sulle revisioni `97527ba` e `1883af9`,
  integrate con #14 e #21; GS-VER-144/145/148 aggiornate senza promuovere
  CMP-095. Conservate le verifiche G3 di QueryAST e riassunto estrattivo.

### Modificato

- Kernel analitici: trasposte X/H flat per NMF, BFS indicizzate e buffer riusati
  nella centralità armonica, ultimo blocco bootstrap limitato agli elementi
  necessari e delega equivalente per blocchi unitari. Formule, PRNG e riduzioni
  conservati; 18 confronti identici e gate completo con 544 test in GS-VER-173.
  Benefici e piccoli costi residui misurati senza promozione scientifica.

- Lookup delle etichette fonte macOS con indice effimero first-wins,
  ammortamento conservativo e predicato Sendable. Batch sintetico lungo da
  49,061791 a 2,069916 ms; regressioni piccole/first-only e dispersione dichiarate,
  nessun claim di rendering o energia. Tre candidati respinti, output completi
  identici e nuovo gate del sorgente finale superato (GS-VER-231).

- Posting BM25 adattivi bounded e membri silhouette preindicizzati, con
  conservazione delle somme ordinarie e recupero numerico
  degli estremi. Confronto Release e gate completo superati in GS-VER-172;
  nessuna promozione o soglia prestazionale introdotta.

- Welch ANOVA conserva la varianza interna anche per gruppi con offset molto
  differenti tramite traslazione locale e scale comuni; regressione Decimal,
  trasformazioni estreme e compatibilità upstream verificate in GS-VER-171.

- Pianificazione DAG: heap minimo e confronto dei digest già memorizzati,
  stesso ordine Kahn e riuso; stella da 5.000 nodi 7,66× più rapida nella fase
  isolata e 19,88× con le ottimizzazioni digest (GS-VER-205).
- Proiezione CA: due Set locali eliminano scansioni ripetute degli inclusi;
  DTO e JSON invariati, caso grande 84,38× nella fase isolata. Il piccolo caso
  misurato aggiunge meno di un microsecondo; memoria locale esplicita (GS-VER-206).
- Identità content-addressed: validazione UTF-8 del solo linguaggio SHA-256
  precedente e codifica esadecimale con buffer sicuro; 50.000 ID da 388,873 a
  10,805 ms, senza modificare namespace, encoder JSON o hash (GS-VER-207).
- Supporto dei benchmark condiviso esclusivamente dai test Core e Kit, senza
  nuovi prodotti o dipendenze runtime; protocollo di misura invariato (GS-VER-208).

- Raffinamento analitico: NMF con prodotti contigui e obiettivo senza matrice
  temporanea, partizioni temporali indicizzate e ordinamento bounded per
  descrittive a bassa cardinalità. TF-IDF/BM25 con meno allocazioni e failure
  tipizzate per overflow; BM25 conserva risultati finiti con `k1` estremo.
  Confronti completi e compromessi misurati in GS-VER-170.

- Coordinate sorgente: lookup e composizione SpanMap con bounds binari e fallback
  per rappresentazioni legacy non ordinate, conservando serializzazione e origini;
  scenari Release 47,31× e 19,29× più rapidi (GS-VER-202).
- Token speciali: riuso dei confini del run e limite esistente applicato prima
  della copia del suffisso; 8.000 segni senza spazi da 764,499 a 5,236 ms,
  token/frasi identici e cancellazione durante la preparazione (GS-VER-203).
- CSV scientifico: indice locale dei riferimenti Evidence, ordine e byte invariati;
  report sintetico con 2.048 Finding/Evidence da 385,538 a 234,297 ms (GS-VER-204).

- Fonti e Artifact restituiscono byte verificati con una sola lettura/hash, anche
  in recovery, preservando controlli di percorso, tipo, link, dimensione, digest
  e cancellazione; benchmark Release delle API 1,90–1,99 volte più rapido
  (GS-VER-200).
- Il termine query viene normalizzato una volta per valutazione anziché a ogni
  token. Sul workload Unicode preparato da 100.000 token, mediana Release da
  187,203 a 88,112 ms con risultato completo invariato (GS-VER-201).

- Ottimizzazione misurata dei kernel analitici: cache condensata HAC, distanze
  incrementali K-means++, buffer contigui PageRank e riduzione di visite e
  allocazioni per lessico, tempo, linguistica e riassunti. Formule, seed,
  ordinamenti e tolleranze invariati; benchmark Release riproducibili (GS-VER-169).

- Il runtime macOS riceve energia, termica, pressione memoria e attività tramite
  eventi owned, senza polling. Le sessioni verificano l'admission prima del
  lavoro lungo e il piano rivaluta le condizioni fra nodi, preservando i
  risultati e le generazioni già committate (GS-VER-182).
- I quattro commit del package verificano il manifest candidato con lettura
  bounded dal descriptor della transazione e confronto esatto dei byte attesi
  prima della pubblicazione (GS-VER-183).
- Roadmap, stati dei requisiti e adozione distinguono capacità già implementate,
  verifiche storiche e audit ancora aperti (GS-VER-184).

- Il parser testuale rifiuta gli AST oltre il limite di profondità anche quando
  derivano da AND/OR o catene NEAR/BEFORE, mantenendo la radice a zero e le
  failure tipizzate già previste (GS-VER-181).

- Il loop `quality-static` esegue anche i controlli esistenti di tassonomia e
  messaggi delle failure, anticipando il feedback senza richiedere Swift/Xcode
  (GS-VER-180).

- Revisione degli operatori nativi: Stress-1 con secondary ties, probabilità LDA
  come media dei prodotti, log-probabilità Naive Bayes robuste ai subnormali e
  riferimenti binari ai codici con parole riservate quotate. Varianti MDS/LDA/codifica
  versionate e stati per metodo collegati a manifest numerici (GS-VER-161).

- La variante di riassunto a centroide conserva la costante pubblica del metodo
  predefinito e decodifica anche nei messaggi GlifiKit i payload precedenti senza
  `isEligible`, con test di compatibilità dedicati (GS-VER-149).

- Interfaccia più essenziale: prossima azione contestuale nella panoramica, sidebar
  orientata alla ricerca, menu di progetto e dettagli tecnici espandibili.
- Risultati adattivi alle finestre strette e al testo di accessibilità, selezioni
  di gruppo riconoscibili senza colore e tabelle attivabili da tastiera.
- Conclusioni con argomenti risolti, stato vuoto con creazione effettiva del
  progetto e valori iniziali localizzati in italiano e inglese (GS-VER-150).

### Aggiunto

- Confronto keyness macOS con tutta la famiglia in pagine da 50, richiesta e
  popolazioni effettive, test selezionato, p del G-test, q BH e intervalli.
  Livello di confidenza configurabile tramite addizione Kit compatibile con il
  costruttore a due argomenti; test e gate/preflight macOS superati sullo
  snapshot conservato (GS-VER-198).

- Ponderazione TF/TF-IDF diretta nel laboratorio macOS: 54 combinazioni esistenti,
  matrice sparsa con celle osservate anche a peso zero, righe/fonti e vocabolario
  completi, pagine da 50 con accesso diretto e ultima pagina. Risultati incoerenti
  contenuti prima della presentazione con failure tipizzata; test dedicati e
  gate/preflight macOS superati sullo snapshot conservato (GS-VER-197).

- Laboratorio testuale post-0.1 macOS: riassunto estrattivo con due metodi e MMR,
  ambito e budget dichiarati, fonte originale mappata tramite SpanMap e fallback
  esplicito dei messaggi precedenti (ADR-0033, GS-VER-190).
- Ranking BM25 contestuale, con query lessicale distinta da KWIC, punteggi zero
  e termini fuori vocabolario conservati; frequenze/ngrammi configurabili con
  pagine da 50 righe, denominatori e troncamento espliciti; MTLD con valori
  finiti, infiniti o non disponibili distinti (GS-VER-191/192).

- Completamento delle primitive analitiche specificate: distribuzioni lessicali,
  fitting diagnostico Zipf/Heaps, statistiche descrittive Q7, Welch ANOVA,
  aggregazioni temporali con esposizione e metriche di valutazione linguistica.
  Nuove facciate GlifiKit concorrenti; contratti headless candidati (GS-VER-168).
- Riassunti TextRank e LexRank continuo/a soglia nel percorso Core/Kit/CLI,
  con parametri persistiti e diagnostica di convergenza; taglio HAC a soglia
  e contratti numerici più robusti per K-means, NMF, Pearson e PageRank (GS-VER-168).

- Profilo esplicito di verifica macOS: `make verify-macos` e
  `make verify-app-store-macos` mantengono i controlli condivisi e omettono soltanto
  le azioni iPadOS; i gate globali conservano il comportamento predefinito (GS-VER-188).

- Request analitica Swift/JSON versionata e CLI `text-analysis --request` condivisa
  con GlifiKit: digest canonico, default espliciti, limiti, failure private e
  fixture di parità per tutte le nuove operazioni (GS-API-002, GS-VER-162).

- Operatori analitici nativi candidati in GlifiCore/GlifiKit: MDS classica/Kruskal/Sammon,
  SOM batch, CLARA, Naive Bayes, LDA Gibbs e regole automatiche KH Coder, con matrici
  condivise per parole e codici, oracoli indipendenti e benchmark Release (ADR-0032, GS-VER-160).

- Ingresso `query --ast <query.json>` in alternativa a `--text`: QueryAST v1 condiviso
  tra Core, GlifiKit e CLI, limiti durante lettura/decodifica, rifiuto di file non
  regolari e diagnostiche senza contenuto o path (GS-VER-143).
- Riassunto estrattivo deterministico `SentenceTFIDFMean-v1` (GS-MET-001-19, RF-042): frasi
  esistenti selezionate per media dei pesi TF-IDF entro un budget in frasi o token, con rank,
  tie-break per posizione, intervallo sorgente e ordine della fonte; Artifact
  `corpus-extractive-summary-v1`, `analyzeExtractiveSummary` in GlifiKit e `glifi summarize`
  (GS-VER-146).
- Variante `CentroidCosine-v1` del riassunto estrattivo (GS-MET-001-19, RF-042): metodo di
  punteggio come parametro del descrittore (`method`, `--method` in `glifi summarize`), coseno
  tra il vettore della frase e il centroide del gruppo, vettori nulli esclusi con flag
  `isEligible` persistito per frase e derivato dai token nei payload precedenti (GS-VER-149).
- Ridondanza `MMR-v1` del riassunto estrattivo (GS-MET-001-19, RF-042): politica di selezione
  come parametro del descrittore (`redundancy`, `--mmr <λ>` in `glifi summarize`), obiettivo
  `λ·rel − (1−λ)·max sim` con similarità coseno tra vettori frase, `λ` validato in `[0, 1]`,
  `selectionOrder` persistito per frase scelta e assente nei payload precedenti (GS-VER-151).
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

- Registrati i gate Xcode 27 dell'ingresso QueryAST e della regressione permessi
  (GS-VER-143/147, PR #18): CMP-081 verificata nel perimetro G3 Core/Kit/CLI;
  nessuna estensione a GUI su dispositivo, PDF/A o distribuzione firmata.
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

- La selezione KWIC macOS e i mark visuali pubblicano il nuovo contesto fonte
  soltanto dopo il caricamento riuscito; busy/failure conservano lo stato
  precedente. Un mark senza fonti ammesso azzera il contesto Evidence estraneo.
  Cinque regressioni riprodotte e superate, gate/preflight macOS superati sullo
  checkpoint 4d6969dd e rivalidati su ffbfb431; layout GUI e WIP successivi
  hanno evidenze separate (GS-VER-230/232).

- Betweenness non pesata conserva punteggi finiti quando i contatori dei cammini
  superano Double.max, con recupero scalato e percorso ordinario invariato
  (GS-VER-174).
- Verifica degli export scientifici: inventario rigoroso, congruenza fra
  manifest e specifica, tabella rettangolare e CSV equivalente al profilo v1;
  quattro famiglie compatibili e failure di integrità esistente (GS-VER-175).
- Bootstrap indipendente e moving-block osservano la cancellazione entro
  4096 osservazioni ricampionate, anche durante una replica; il kernel condiviso
  estende la granularità a BCa, preservando risultati e validazioni (GS-VER-176).

- Costi del riassunto estrattivo: l'API Core rifiuta conteggi di caratteri non positivi con
  `summary.invalid-character-count`; selezione per rank e MMR confrontano il costo con il
  budget residuo, evitando overflow per costi estremi. Formula e payload invariati;
  regressioni ed evidenza GS-VER-167, CMP-164 torna `implemented` fino alla CI su `main`.

- La keyness distingue nel descrittore i livelli di confidenza richiesti e
  applica il limite della famiglia anche agli Artifact riusati; un budget diverso
  ma sufficiente conserva il riuso. Due RED e quattro test Core superati,
  inclusi guard su payload difforme e riapertura del legacy senza riscrittura;
  nessuna formula o migrazione nuova, gate macOS superato sullo snapshot
  conservato (GS-VER-199).

- Il collegamento dei documenti macOS richiesto durante un'operazione occupata
  attende il termine e conserva soltanto la richiesta più recente; cancellare
  una richiesta non invalida quella successiva. Cinque regressioni automatiche e
  gate/preflight macOS superati sullo snapshot conservato (GS-VER-196).

- Le sei analisi dirette macOS possiedono il task e consentono Annulla senza
  liberare busy prima del terminale; cancellazione del chiamante propagata,
  risultati già committati preservati (GS-VER-195).
- Anteprima Markdown macOS letta e decodificata fuori dal Main Actor, integrale
  entro 1 MiB e facoltativa, senza invalidare l'export autorevole (GS-VER-194).
- Tre etichette accessibili sostitutive rimosse dai testi di fonte e preview
  soltanto su macOS; nessuna attestazione VoiceOver o G4 (GS-VER-193).

- Riapri su macOS usa l’azione documentale nativa e conserva lo stato della finestra
  chiamante; corretta la creazione dei bookmark security-scoped, con prove separate
  del bookmark e del routing (GS-VER-187).

- Annullamento dell’esecuzione nel modello macOS: handle e stato occupato restano
  posseduti dal task fino all’esito terminale; il progresso viene ripulito anche
  su cancellazione (GS-VER-186).

- Dopo un errore durante l'importazione di più file, fonti e profilo mostrano
  ogni commit già riuscito e i contatori di progresso vengono azzerati; la
  sessione resta interrogabile senza ripetere gli import confermati (GS-VER-185).

- L'app macOS usa il ciclo documentale nativo per Nuovo/Apri e propone il salvataggio del nuovo
  progetto prima dell'importazione. L'inizializzazione non cancella package esistenti e un'apertura
  fallita conserva la sessione precedente; test di regressione in `make test-macos` (GS-VER-163).

- Errori di permesso `EACCES`/`EPERM` in `query --ast` classificati come
  `authorizationDenied` con retry dopo intervento utente, non backoff; exit code
  6 e diagnostica senza percorsi invariati. Test CLI su file non leggibile e
  correzione della disponibilità AST nel contratto headless (GS-VER-147).
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

- Verifica export con letture bounded di manifest e payload relative alla radice aperta,
  controlli sul descriptor e rifiuto di link/file speciali; regressioni su budget,
  ripristino e preservazione dei dati (GS-VER-148). Formato e pubblicazione invariati;
  inventario, scritture, ACL e file provider non diventano coperti integralmente.

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
