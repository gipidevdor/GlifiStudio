<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Completamento degli algoritmi analitici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-168 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.1 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di continuare e completare tutti gli algoritmi di analisi |
| Riferimenti | RF-026; RF-028; RF-037; RF-038; RF-040; RF-041; RF-042; RF-045; RQ-008; RQ-063 |

## Contratto dell'incremento

Completare i metodi con formula normativa già definita e le primitive headless
di raggruppamento temporale e valutazione linguistica. Sono comprese distribuzioni
lessicali, crescita del vocabolario, fitting diagnostico Zipf/Heaps, statistiche
descrittive, Welch ANOVA, TextRank/LexRank, taglio HAC a soglia e chiusura dei
contratti numerici di clustering, NMF e correlazione.

Le nuove famiglie in memoria conservano variante, parametri, ordine e identità
degli input; GlifiKit espone facciate concorrenti senza dipendenze di GlifiCore
dalle app. Nessun nuovo formato di progetto, backend NLP, dipendenza o servizio
di rete. Non sono comprese estensioni future prive di formula approvata
(t-SNE/UMAP, embedding neurali, Zipf–Mandelbrot stimato) né la promozione automatica
di nuovi metodi nella UI o nel planner persistente.

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Algoritmi con formula normativa e primitive headless descritte sopra; nessuna promozione automatica della superficie di prodotto |
| failure semantics | Input invalidi, dati insufficienti, overflow e budget superati producono GlifiFailure; nessuna correzione silenziosa |
| dati mancanti | Esclusioni, denominatori nulli e date civili/istanti hanno policy esplicite |
| verifica | Oracoli R indipendenti, casi esatti, proprietà, input ostili, cancellazione e parità Core/Kit; `make verify` prima della consegna |
| prestazioni | Conteggi incrementali, input bounded, cancellazione nei cicli e nessun calcolo sul Main Actor dalla facciata |
| tracciabilità | GS-VER-168, requisiti, matrice, registro evidenze e CHANGELOG aggiornati insieme |
| limiti scientifici | Nessuna review umana simulata; validazione empirica NLP, V6 e audit su dispositivo restano distinti |

**Ready** prima del primo cambiamento implementativo.

## Esito

Implementazioni e verifiche completate in
[GS-VER-168](../evidenze/GS-VER-168-completamento-algoritmi.md): gate completo
superato, 431 test e 152 righe di oracoli. Le nuove famiglie headless restano
candidate; integrazione nel prodotto, validazione empirica e promozione scientifica
seguono i gate propri.

## Ricognizione del contratto per la prosecuzione

Questa scheda integrativa esplicita i campi di GS-STD-001-07 per il perimetro
già descritto; non ridefinisce le formule scientifiche né autorizza famiglie
aggiuntive. I contratti applicabili sono GS-MET-001-04/05 per descrittiva,
distribuzioni e fitting diagnostico, GS-MET-001-14/15 per clustering e
fattorizzazioni, GS-MET-001-17/18 per tempo e valutazione linguistica,
GS-MET-001-19 per riassunto estrattivo e GS-MET-001-21 per statistica. Il confine
fra Core, Kit e client e la tassonomia delle failure restano quelli di GS-API-001.

| Voce | Contratto e limite della prosecuzione |
| --- | --- |
| outcome e confini | Proseguire esclusivamente le varianti con formula, dominio, ordinamento, parametri e budget già esplicitati nelle specifiche sopra. Il fitting Zipf/Heaps è diagnostico; non dimostra una legge né autorizza estrapolazioni. Tempo e valutazione linguistica sono primitive headless, non nuovi backend o flussi applicativi. Un contratto mancante arresta la relativa variante, senza inferirlo dal codice |
| requisiti | RF-026, RF-028, RF-037, RF-038, RF-040, RF-041, RF-042 e RF-045; RQ-008 e RQ-063. I criteri sono quelli delle rispettive righe di GS-SRS-001 e dei metodi versionati; nessuna approvazione implicita delle capacità ancora candidate |
| dominio/API | Primitive Core senza dipendenze UI; facciate Kit con valori Sendable e calcolo concorrente fuori dal Main Actor. Conservare identità, versione della variante, parametri risolti, ordine degli input, seed applicabile e diagnostica. Nessuna ABI stabile promessa; nessun tipo interno Core esposto dalle nuove facciate Kit |
| failure semantics | Input invalidi, dati insufficienti, non finiti, overflow e budget superati producono failure tipizzate secondo GS-API-001, con retry e stato conservato coerenti con la categoria; cancellazione osservata nei cicli. Nessun dato corretto, escluso o imputato senza policy esplicita. Nessun Artifact parziale marcato completo; un arresto numerico senza convergenza conserva la diagnostica prevista dalla variante |
| esperienza prevista | Nessuna nuova UI o selezione di metodi nel planner. L'esito headless espone parametri, esclusioni, mancanti e diagnostica senza reinterpretazione del client. Audit della nuova interfaccia non applicabile perché non viene introdotta una superficie UI; accessibilità e comprensione dei flussi applicativi richiedono incrementi ed evidenze separati |
| verifica | TV-029, TV-031, TV-032, TV-033 e TV-036 secondo famiglia; oracoli R/Python indipendenti ove previsti, casi esatti, proprietà, degenerazioni, limiti, input ostili, cancellazione e parità Core/Kit. Registrare esiti e variante in GS-VER-168; eseguire `make verify` prima della consegna e dichiarare precisamente controlli non eseguiti o falliti. La presente ricognizione non è evidenza di esecuzione algoritmica |
| dati e migrazione | Le famiglie dichiarate in memoria non introducono schema persistente, nodi planner o migrazioni. Per il riassunto mantenere il percorso Artifact/descriptor esistente e distinguere le configurazioni versionate; decodifica dei payload precedenti e lineage rispettano GS-MET-001-19. Date civili e istanti restano distinti; metadati mancanti o intervalli incerti seguono soltanto le policy della variante, senza derivarli da path o nomi file |
| sicurezza/privacy | Solo input espliciti e fixture sintetiche autorizzate; nessuna rete, dipendenza, entitlement, telemetria o servizio NLP aggiunto. Validare dimensioni, finitezza, identità e riferimenti prima del lavoro costoso; non riportare contenuto, query o path nelle failure. La valutazione di un backend non equivale alla sua introduzione nel prodotto |
| prestazioni/sistema | Applicare limiti di input, celle, iterazioni e lavoro già dichiarati per variante prima delle relative allocazioni; conteggi incrementali dove previsti e controlli di cancellazione nei cicli. Nessun calcolo non banale sul Main Actor e nessuna ottimizzazione senza misura. I limiti del backend in memoria non dimostrano streaming del corpus, baseline energetica o scalabilità sulle classi hardware |
| tracciabilità | GS-DOR-168 identifica il perimetro; GS-VER-168 resta l'evidenza algoritmica da compilare con gli esiti osservati. Requisiti, clausole della matrice, fixture, test ed evidenze devono restare collegati per variante; i registri comuni sono integrati puntualmente dall'agente principale dopo rilettura. GS-VER-184 riguarda soltanto questa ricognizione documentale e non promuove gli algoritmi |
| decisioni | Applicare ADR-0002 per la separazione, ADR-0013 per la fondazione scientifica e ADR-0031 per promozione e review. t-SNE/UMAP, embedding neurali, stima Zipf–Mandelbrot, nuove policy temporali non specificate e integrazione automatica nella UI/planner restano esclusi; una decisione o un contratto mancante richiede una nuova unità delimitata. Recupero tramite revert del relativo incremento, senza migrazioni implicite |

## Stato della prosecuzione e provenienza

**Ready** per la prosecuzione delimitata dai contratti sopra, non per dichiarare
verificati o supportati tutti i metodi. Nuove varianti, backend, schema persistente
o integrazioni applicative restano fuori da questa attestazione. Validazione
empirica NLP, soglie di qualità, review esterna V6, audit GUI e G4 sono aperti.

Questa ricognizione del 2026-11-21 è successiva all'avvio delle implementazioni
nell'altra chat. Esplicita contratti e limiti per la prosecuzione; non attesta
retroattivamente che la scheda completa fosse registrata prima del primo
cambiamento di codice, né sana quel requisito di processo tramite la sola
presenza dei marker documentali.
