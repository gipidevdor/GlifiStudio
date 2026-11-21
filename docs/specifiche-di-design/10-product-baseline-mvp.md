<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Product baseline e MVP

| Campo | Valore |
| --- | --- |
| Identificatore | GS-PROD-001 |
| Tipo | Product baseline e criterio di completezza |
| Versione | 1.1.1 |
| Stato | Baseline controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | G1 leggero approvato: Must 0.1 congelati; G2 headless evidenziato; G3 dipende dalla UI Must |
| Riferimenti | GS-VIS-001; GS-SRS-001; GS-UX-001; GS-MET-001; ADR-0011; ADR-0016 |

## Obiettivo del prodotto 0.1

Glifi Studio 0.1 è un'app document-based nativa per macOS 27 e iPadOS 27 che
permette a una persona di creare un progetto locale, importare una raccolta
italiana, formulare una domanda, ottenere un piccolo insieme di analisi corrette,
verificarne evidenze e fonti e produrre una relazione/esportazione riproducibile.

“MVP” significa primo prodotto completo e affidabile, non prototipo dimostrativo.
Una funzione è inclusa soltanto se dominio, persistenza, motore, UI, accessibilità,
localizzazione, validazione, recovery e distribuzione sono tutti completati.

## Confini invarianti

| Aspetto | Baseline 0.1 |
| --- | --- |
| Target | macOS 27 e iPadOS 27; singola identità App Store multipiattaforma |
| Toolchain | Xcode 27, Apple Swift 6.4+, Swift 6 language mode, strict concurrency |
| Distribuzione | App Store non in elenco; accesso mediante link, non controllo di autorizzazione |
| Modello operativo | Locale, singolo utente, nessun account, server, sync o telemetria |
| Lingua analitica | Italiano `it` con contratto GS-LNG-001 |
| Interfaccia | Italiano iniziale, cataloghi almeno `it`/`en`, sempre internazionalizzabile |
| Licenza | BSD-3-Clause per il repository; asset/dataset con inventario separato |
| Progetto | Package `.glifi` v1, fonti incorporate per default |
| Privacy | Nessun contenuto del corpus in log/diagnostica; rete non richiesta |

La distribuzione “non in elenco” limita la scoperta sullo store ma non autentica
chi possiede il link. Dati sensibili sono protetti dal modello locale e dalla
sandbox, non dalla segretezza dell'URL.

## Percorso Must end-to-end

1. Creare, salvare, riaprire e recuperare un progetto `.glifi`.
2. Importare UTF-8 TXT e Markdown, incorporando gli originali e mostrando errori
   senza perdere il lavoro valido.
3. Creare un corpus da documenti e metadati tipizzati essenziali.
4. Avviare un'indagine con domanda, intenzione e scope; vedere CollectionProfile e
   piano applicabile prima o durante l'esecuzione.
5. Cercare forma/lemma/frase, booleani, prossimità e metadati tramite QueryAST;
   esplorare KWIC e saltare al testo di fonte.
6. Calcolare il nucleo analitico definito sotto con descriptor, lineage e Caveat.
7. Ricevere Findings ordinati, aprire Evidence, metodo e fonti, confrontare oggetti
   e distinguere insufficienza da assenza di effetto.
8. Salvare storia e selezione editoriale; creare un Report accessibile.
9. Esportare Report in PDF/Markdown e dati selezionati in CSV/JSON con manifest di
   provenance.
10. Eseguire lo stesso piano fondamentale da GlifiKit/GlifiCLI per verifica batch.

## Nucleo analitico 0.1

Sono `Must`, nelle sole varianti già specificate da GS-MET e validate GS-VAL:

- conteggi di documenti, segmenti, frasi, token e type;
- frequenze assolute/relative, n-grammi, document frequency e range;
- TTR-v1, MSTTR-v1 e MATTR-v1 con denominatori e limiti espliciti;
- query, concordanze KWIC e dispersione GriesDP-v1;
- matrice unità-termine sparsa e TF/TF-IDF per i flussi che la richiedono;
- confronto di due gruppi con keyness GTest-v1, effect size e correzione
  BenjaminiHochberg-v1 quando esistono confronti multipli;
- andamento temporale descrittivo soltanto con metadati data affidabili.

Il planner `planner-mvp-v1` non propone altri metodi. Una variante Must resta
disabilitata se corpus gold, oracolo, tolleranze o UI verificabile non sono pronti.

L'incremento analitico successivo a 0.1 è governato da
[ADR-0025](../adr/0025-estensione-analitica-planner-v2.md): `planner-v2` estende il catalogo con
le famiglie verificate contro oracoli indipendenti, senza modificare il perimetro della 0.1.

## Funzioni Should se non mettono a rischio il Must

- modalità di fonte esterna con gestione bookmark e stato degradato;
- MTLD-bidirectional-v1;
- BM25-v1 per ranking esplicitamente richiesto;
- tabelle di contingenza con residui ed effect size;
- export PNG dei grafici oltre al PDF vettoriale;
- più finestre macOS dedicate a confronto o fonte.

Le funzioni Should non bloccano la release e non possono lasciare codice a metà
nei flussi Must.

## Fuori dal prodotto 0.1

- PDF, OCR, immagini e formati office;
- Correspondence Analysis, PCA/LSA/NMF/LDA, clustering e reti;
- co-occorrenza/collocazione avanzata e content analysis multi-codificatore;
- riassunto estrattivo e qualsiasi funzione generativa/Foundation Models;
- annotazione collaborativa, account, cloud, CloudKit, Handoff e condivisione;
- Spotlight sul contenuto, App Intents pubblici e automazioni esterne;
- plugin, scripting di terzi, modelli scaricabili e dipendenze non essenziali;
- piattaforme diverse da macOS/iPadOS e distribuzione pubblica indicizzata.

“Fuori” significa nessuna promessa UI, API stabile o formato persistente anticipato.
Le specifiche scientifiche restano catalogo di evoluzione, non scope implicito.

## Estensioni applicative successive

La baseline 0.1 sopra resta storica e invariata. La richiesta del 2026-11-21 e
[ADR-0033](../adr/0033-laboratorio-analisi-testuale-macos.md) autorizzano il programma
post-0.1 di riassunto estrattivo, ranking BM25 e frequenze/MTLD nel laboratorio
macOS, con DoR e prove separate. L'esclusione del riassunto dalla release 0.1 non
impedisce questo incremento successivo; nessun nuovo Must viene aggiunto alla 0.1.
La presenza di una API o del programma non dichiara completate tutte le famiglie,
la UI, iPadOS o G4.

## Completezza qualitativa

Il rilascio è candidato solo se:

- tutti i requisiti Must sono tracciati a test ed evidenza acquisita;
- package, autosave, migrazione e recovery superano kill/corruption testing;
- ogni capacità analitica Must possiede ValidationManifest almeno V0–V4;
- benchmark S passa su tutta la matrice e M sul dispositivo minimo dichiarato;
- nessun flusso Must causa lavoro lungo sul Main Actor o crescita non limitata;
- audit VoiceOver, tastiera, Dynamic Type, contrasto, localizzazione `it`/`en` e
  pseudolocalizzazione è superato su macOS e iPadOS;
- threat model, privacy manifest, sandbox, segreti e supply chain sono riesaminati
  sulla build candidata;
- TestFlight copre upgrade, riapertura di progetti, cancellazione e pressione di
  risorse su dispositivi fisici;
- crash, perdita dati e finding non verificabile sono zero nella suite bloccante;
- metadati, supporto, privacy, export compliance e richiesta unlisted coincidono
  col binario sottoposto ad App Review.

## Criteri di uscita G1–G5

| Gate | Uscita necessaria per 0.1 | Stato 2026-09-17 |
| --- | --- | --- |
| G1 Baseline | GS-DOM/DAT/LNG/QRY/ANA/RUN/UI/VIZ/VAL/PROD approvati; owner e rischi assegnati | **Chiuso (leggero)**: Must congelati, ADR-0002 accettato, owner minimi sull'iniziatore; decisioni non bloccanti parcheggiate |
| G2 Architettura | Vertical slice `.glifi` TXT → query/KWIC → fonte; prototipi persistence/runtime validati | **Chiuso (headless)**: evidenze GS-VER-018…033; UI nativa aperta |
| G3 Feature complete | Tutti i Must integrati, nessun placeholder nei flussi, migrazioni e export attivi | **Candidato funzionale**: checklist GS-VER-057; UI Must + ValidationManifest (GS-VER-035…071, GS-VER-074…083); audit dispositivo e studi UX aperti |
| G4 Release candidate | Suite completa, dispositivi, accessibilità, performance, sicurezza e TestFlight superati | Aperto |
| G5 Release | Firma/record definitivi, review accettata, richiesta unlisted approvata e runbook operativo | Aperto |

Un gate non è superato dalla sola presenza del documento. Ogni risultato deve
puntare a evidenze riproducibili e limiti residui.

## Misure di successo iniziali

Prima dell'approvazione G1 vanno fissate soglie numeriche per: successo del percorso
Must, tempo al primo Finding verificabile, accuratezza di salto alla fonte,
comprensione di Evidence/Caveat, peak memory per benchmark e recovery. App Store
approval, assenza di crash e validazione scientifica sono vincoli, non metriche di
vanità.

## Regola di cambiamento

L'aggiunta di un Must o lo spostamento di un'esclusione richiede impatto su
requisiti, architettura, privacy, matrice dispositivi, validazione, tempi e ADR. Una
funzione incompleta viene rimossa dal piano di rilascio o mantenuta dietro una
capability non pubblica; non si abbassano i gate per preservare una data.
