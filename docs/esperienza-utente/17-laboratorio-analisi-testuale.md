<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Laboratorio di analisi testuale macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-17 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.3.6 |
| Stato | Baseline implementativa per incrementi separati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | ADR-0033; ADR-0034; richieste esplicite di completamento dell'analisi testuale e riprogettazione della GUI |
| Documento padre | [GS-UX-001](README.md) |

## Contesto e percorso

Il laboratorio appartiene alle fonti e all'indagine correnti. Presenta azioni
comprensibili: ottenere un riassunto, trovare documenti pertinenti, descrivere il
lessico. Non richiede di scegliere un algoritmo prima di conoscere ambito e
risultato desiderato. I tre flussi A–C entrano con incrementi autonomi; la loro
presenza nella specifica non li dichiara implementati.

La successiva riprogettazione di ADR-0034 rende visibili gli accessi agli
strumenti già realizzati, mantenendo i livelli di complessità distinti.
L'introduzione di uno strumento spiega il compito e il risultato atteso; l'ambito
comune precede l'esecuzione, i parametri specialistici si espandono quando
necessari. Una persona esperta può entrare direttamente nello strumento senza
attraversare ogni altro flusso del laboratorio.

La scelta dello strumento e i parametri di lavoro sopravvivono alla navigazione
verso query, fonti e altre sezioni della stessa scena. Il ritorno al laboratorio
non ripristina silenziosamente lo strumento iniziale o i default; un cambio di
progetto pulisce invece il contesto della raccolta precedente.

Configurazione e risultati hanno superfici distinte: con spazio sufficiente e
testo ordinario sono affiancati in pannelli ridimensionabili; con finestra stretta
o dimensioni di accessibilità il percorso è sequenziale mediante tab native
Impostazioni/Risultati. Il risultato appena ottenuto diventa raggiungibile senza
scorrere oltre tutti i parametri. La selezione delle fonti usa una disclosure e
un elenco bounded; il conteggio dell'ambito resta visibile quando è richiusa.
Nella ponderazione, Fonti, Vocabolario e Celle hanno accessi distinti, conservando
le rispettive pagine, lo scope effettivo e il metodo nello stesso contesto.

Per A–D l'ambito **DEVE** indicare tutte le fonti oppure le revisioni selezionate,
riconoscibili per nome quando disponibile, altrimenti tramite etichetta locale
“Fonte N” con identità della revisione, formato e byte. Non si inventano nomi
originali né si aggiungono metadati persistenti per la sola presentazione.
I risultati conservano lo scope effettivo e
la generazione usata, distinguendoli dall'eventuale selezione modificata dopo il calcolo.
La UI usa soltanto GlifiKit e non costruisce risultati scientifici locali.

## A — Riassunto estrattivo

La persona vede che il riassunto seleziona frasi esistenti e non genera testo.
Il controllo iniziale è il budget: numero di frasi, token lessicali o scalari
Unicode del testo esatto della fonte per `Budget-characters-v1`, nei limiti
GlifiKit `1…10 000`; default tre frasi. I dettagli permettono di scegliere
`SentenceTFIDFMean-v1`, `CentroidCosine-v1`, `LexRankSentence-v1`,
`TextRankSentence-v1`, `TextRankSentence-configurable-v1`,
`LexRankSentence-continuous-v1` o `LexRankSentence-threshold-v1` e la ridondanza assente oppure
`MMR-v1` con λ esplicito in `[0, 1]`. La ponderazione predefinita
`TF-sublinear-v1 / IDF-smooth-v1 / RowNorm-none-v1` resta dichiarata nel metodo.
I controlli non correggono silenziosamente parametri invalidi.

Le varianti a grafo mantengono le proprie identità scientifiche. I parametri
di damping, tolleranza, massimo iterazioni e soglia sono modificabili soltanto
per le varianti che li prevedono; i metodi fissi non diventano configurabili
cambiandone il nome nella UI. Configurazione effettiva, nodi/archi, iterazioni e
convergenza sono disponibili nel risultato. Raggiungere un limite non viene
descritto come convergenza e la disponibilità del picker non promuove lo stato
scientifico del metodo.

L'esito presenta le frasi selezionate in ordine della fonte, con identificazione del documento secondo la regola sopra
e azione per aprirlo. Il testo è quello estratto, senza parafrasi o markup inventato.
Nei dettagli sono disponibili metodo, parametri effettivi, budget consumato,
score, rank, ordine di selezione, eleggibilità, Artifact e lineage. Il rank non è
una probabilità di correttezza e la ridondanza non garantisce copertura tematica.

Gli intervalli della frase **DEVONO** essere identificati come coordinate del testo
estratto. Per evidenziare l'originale si usano soltanto i `sourceRanges` risolti
da SpanMap. Non si applicano direttamente `startUTF8/endUTF8` della frase ai byte
originali: Markdown e BOM possono modificarne la corrispondenza. Un mapping vuoto,
compreso quello di un DTO precedente, apre la fonte intera senza evidenziazione
e comunica che la localizzazione puntuale non è disponibile.

## B — Documenti pertinenti con BM25

La query lessicale è distinta dalla sintassi QueryAST della concordanza. L'azione
indica che ordina documenti per rilevanza BM25, non che cerca una frase esatta.
Ambito, query, variante `BM25-v1`, `k1` e `b` sono dichiarati e conservati nel
risultato; i default sono quelli GlifiKit. Si mostrano documento, punteggio e
lineage, con apertura della fonte. Il punteggio non è una probabilità e non
autorizza intervalli KWIC o evidenziazioni che l'analisi non ha prodotto.

## C — Descrivere il lessico

Frequenze e n-grammi espongono unità di parola o carattere, `n`, soglie, stopword
esplicite e filtri secondo le varianti GlifiKit; nessuna stoplist italiana è
introdotta implicitamente. La diversità MTLD dichiara soglia, ordinamento e unità
per documento o sequenza concatenata. I valori non sostituiscono TTR/MSTTR/MATTR.

Le forme sono token lessicali normalizzati `it-token-v1`, NFC e minuscole
italiane. `WordNGram-v1` conta sequenze contigue di forme lessicali nello stesso documento,
esclude la punteggiatura e può attraversare i confini di frase;
`CharNGram-graphemes-v1` lavora invece dentro ogni singola forma, per extended
grapheme cluster, senza attraversare il confine fra forme. La variante padded
aggiunge `_` (U+005F) prima e dopo la forma: il segno rappresenta un confine,
non un carattere osservato del testo. Queste regole sono definite in
[GS-MET-001-04, Frequenze filtrate e n-grammi](../metodi-analitici/04-statistiche-descrittive-e-diversita-lessicale.md).

Un'anteprima di venti righe non equivale all'intero risultato: totale, righe
mostrate, limiti di calcolo e troncamento sono distinti. Esplorazione e accesso
alle righe restanti devono rispettare i limiti bounded senza modificare ordinamento
o ricalcolare formule nella view. Ogni unità C deve fissare prima del codice
parametri, paginazione e prove corrispondenti.

## D — Pesare i termini nei documenti

L'azione contestuale spiega che i pesi combinano frequenza nel documento,
diffusione nella raccolta e normalizzazione della riga; non sono significatività
statistica o probabilità. Si usa `analyzeTermWeighting`, con ambito condiviso
esplicito e `corpusOptions.standard`: massimo 1 000 fonti, 256 MiB di fonti,
100 000 termini e 500 000 celle osservate, senza abbassare i limiti Kit.

Il default UI è esplicito: `TF-raw-v1`, `IDF-smooth-v1`, `RowNorm-none-v1`.
I dettagli consentono le sei TF (raw, binary, L1, max, augmented, sublinear), le
tre IDF (none, unsmoothed, smooth) e le tre normalizzazioni (none, L1, L2).
`IDF-none-v1` significa TF senza fattore IDF: l'identità combinata resta la
variante TF, non viene chiamata TF-IDF. Nessun algoritmo è ricalcolato nella view.

La matrice resta sparsa. Sono mostrate tutte le fonti/righe con numero di celle
osservate, comprese quelle con zero celle, e il vocabolario completo con document
frequency. Le celle restituite hanno **count maggiore di zero**, ma il loro peso
può essere zero, per esempio con IDF non smussata e `df=N`; non vengono filtrate.
Una coppia riga/termine assente ha count e peso implicitamente zero.

Celle e vocabolario sono esplorati in pagine da **50**, nell'ordine restituito
(riga/colonna per le celle, lessicografico per i termini). Sono disponibili pagina
diretta e ultima pagina, oltre alla navigazione sequenziale, fino alle 10 000
pagine di celle del budget standard. Cambiare pagina non ricalcola l'analisi;
pagina non valida non sposta la selezione. Un nuovo risultato o progetto riporta
le pagine iniziali. Non si costruisce una matrice densa.

I conteggi di celle per fonte e i metadati di presentazione sono preparati fuori
dal Main Actor, una volta per risultato; nessuna scansione fonti × celle nella
view. La richiesta effettiva, lo schema di ponderazione, i limiti, le dimensioni e il lineage
restano separati dai draft. Failure e cancellazione conservano il risultato
valido precedente; D usa la stessa ownership `runAnalysis`. L'apertura di una
fonte, se offerta, mostra il documento intero senza inventare occorrenze.

Un risultato riusato con forma incoerente non deve causare crash o una tabella
parziale: prima di mostrarlo si validano fuori dal Main Actor identità delle fonti
e schema di ponderazione rispetto alla richiesta, dimensioni e budget, indici, DF e conteggi
coerenti con le celle osservate, ordine/unicità delle celle e dominio dei pesi. La failure
`failure.weighting.invalid-result` comunica che il risultato non può essere
mostrato e che quelli precedenti restano disponibili. Risultato, metadati, pagine
e snapshot precedenti non cambiano. Questa protezione del client non bonifica
il package né certifica la semantica di ogni Artifact o le formule numeriche.

Il titolo generico dei dettagli è “Metodo”: “Metodo di selezione” resta soltanto
per i controlli del riassunto dove descrive effettivamente la selezione. BM25,
MTLD e ponderazione non sono presentati come metodi di selezione di frasi.

## E — Confrontare il lessico dei gruppi

E completa il confronto diretto dell'Indagine esistente, senza nuova
destinazione o catalogo di test. Usa gruppi target e riferimento espliciti,
non vuoti e disgiunti, con conteggi delle revisioni selezionate e identità
riconoscibili secondo la regola Fonte N. Assegnare una revisione a un gruppo
la rimuove dall'altro; un help spiega il vincolo. Questi due gruppi sono
distinti dall'ambito tutte/selezionate di A–D.

I dettagli consentono di configurare il limite della famiglia di ipotesi,
la soglia diagnostica delle frequenze attese e il livello di confidenza;
default rispettivi 100 000, 5 e 0,95. Si usano i domini GlifiKit senza clamp:
intero non negativo, soglia finita non negativa e livello finito in `(0, 1)`.
Le opzioni corpus restano standard e ispezionabili. La facciata conserva il
costruttore a due argomenti e aggiunge il livello mediante overload distinto;
la UI non introduce una nuova formula.

Il livello di confidenza è separato dai p/q-value e dal giudizio sul risultato.
Per livelli inferiori a 1e-6 la percentuale effettiva usa notazione scientifica,
evitando centinaia di zeri; i livelli ordinari mantengono la percentuale nativa,
per esempio 95%. La soglia cambia soltanto il formato del testo, senza clamp,
modifica del parametro o nuova soglia statistica.
La soglia diagnostica **non cambia** la regola preregistrata
`FisherSelection-min-expected-5-v1`: Fisher è selezionato se un'attesa è minore
di cinque, altrimenti resta il G-test. Non si offre un picker per scegliere il
test dopo averne visto la significatività.

Tutta la famiglia restituita è esplorabile in pagine da **50**, con precedente,
successiva, accesso diretto e ultima pagina, nell'ordine Kit. Nessun filtro o
nuovo ordinamento riduce a posteriori la famiglia BH. Il totale e le righe
mostrate sono espliciti; una pagina non valida non cambia lo stato e cambiare
pagina non ricalcola l'analisi.

Ogni termine mostra conteggi/tassi nei due gruppi e direzione, G e gradi di
libertà, test selezionato, p selezionato e p del G-test, q BH, log ratio e odds
ratio con correzione HA e i rispettivi intervalli Katz/Woolf. La diagnostica
delle attese resta distinta da effect size e significatività; valori piccoli
positivi mantengono una rappresentazione significativa, anche scientifica.
Non si introducono badge universali di affidabilità o soglie di significatività
decise dalla presentazione.

Gruppi, conteggi dei token, opzioni e metodi effettivi, livello, ordinamento,
digest, Artifact e generazioni restano ispezionabili e separati dai draft.
Failure e cancellazione conservano risultato, richiesta effettiva, pagina e
snapshot precedenti; un nuovo risultato/progetto riparte dalla prima pagina.
E usa la stessa ownership `runAnalysis`. Non inventa occorrenze o intervalli
KWIC; un'eventuale apertura fonte riguarda il documento intero.

Prima della presentazione si controllano fuori dal Main Actor bounds,
popolazioni/opzioni della richiesta, identità dei termini e domini dei valori.
Un risultato incoerente usa la failure localizzata
`failure.keyness.invalid-result`, conservando lo stato precedente; il client
non attiva read-only recovery né ricalcola formule o certifica gli altri
Artifact. Questa protezione è distinta dai test end-to-end del package.

## F — Distribuzioni lessicali e fit Zipf/Heaps

Il laboratorio rende raggiungibile l'analisi già persistita
`corpus-lexical-laws-v1` attraverso `analyzeLexicalLaws`, senza formule nella
view. L'ambito è quello condiviso del laboratorio. I controlli espongono numero
di checkpoint, primo e ultimo rango del fit Zipf e limite delle righe
rank-frequency; l'ultimo rango osservato è una scelta esplicita, distinta da un
numero fisso. Default e domini rimangono quelli del contratto Kit/Core.

Rank-frequency, frequency spectrum e crescita del vocabolario sono osservazioni
distinte. La persona può sceglierle ed esplorarle in pagine da cinquanta righe.
Il grafico descrive la pagina visibile e offre la tabella equivalente; non fa
apparire la pagina come l'intera distribuzione. La troncatura delle righe
rank-frequency è dichiarata e resta distinta da paginazione e dominio del fit.

Le due procedure `ZipfLogOLS-v1` e `HeapsLogOLS-v1` mostrano separatamente
disponibilità o motivo di assenza, intervallo osservato, parametri, diagnostica e
residui navigabili. Un esponente fuori dominio non viene nascosto o presentato
come fit valido del modello. L'avviso descrittivo resta al primo livello: il
fit non dimostra una legge universale, un meccanismo generativo o una causalità.

L'export JSON esplicito contiene il risultato restituito da Kit, con parametri,
osservazioni, residui e lineage effettivi; preparazione fuori Main Actor e
failure non alterano l'analisi. La presentazione non ricostruisce osservazioni
non persistite e non dichiara completo il vocabolario troncato.

## Estensione del laboratorio e risultati di sessione

ADR-0034 autorizza il nuovo client macOS delle famiglie analitiche già disponibili
in memoria: trasformazioni di matrici, dissimilarità, MDS, SOM, CLARA,
classificazione Naive Bayes, topic model LDA e regole automatiche. La GUI usa
GlifiKit e le fonti effettive del progetto; non richiede JSON nel normale flusso
di ricerca e non implementa nuovamente tokenizzazione, formule o conteggi.

Ogni operazione **DEVE** dichiarare precondizioni e input: fonti selezionate,
unità e trasformazione della matrice, eventuali etichette fornite dalla persona,
parametri e seed. Per la classificazione, le classi non sono dedotte da nomi di
file o ordine dei documenti. Per le regole, lemma/POS assenti non vengono
sostituiti da annotazioni ipotetiche. Gli errori del contratto Kit restano
espliciti e conservano il risultato precedente.

Il risultato mostra dati osservati o stime con la propria unità e i limiti
specifici: uno score non è una probabilità calibrata, la perplexity LDA sul
training non è una misura held-out, una SOM non garantisce le distanze globali.
Lo stato `supported` della variante headless non certifica l'intera GUI o
l'equivalenza con qualsiasi configurazione di KH Coder.

Questi risultati **DEVONO** essere riconoscibili come risultati di sessione:
non sono automaticamente salvati nel progetto, inclusi nel planner o convertiti
in Finding/Evidence del rapporto. Il cambio progetto invalida gli input e
risultati di sessione; lo scope di un risultato ancora visibile è quello
effettivamente calcolato, distinto dai draft correnti. Un eventuale export
esplicito deve dichiarare contenuto, richiesta e provenienza disponibili senza
inventare identità di Artifact persistiti.

Le due azioni di export riusano separatamente il JSON canonico della richiesta e
il JSON del risultato di GS-API-002. Progetto, generazione, revisioni e digest di
contenuto rimangono ispezionabili nella GUI ma non vengono aggiunti al formato
del risultato: il file non è presentato come export completo della provenienza.

Le leggi lessicali già persistite, quando raggiunte dalla nuova presentazione,
conservano `corpus-lexical-laws-v1`, il dominio dei fit, i residui e l'avviso che
Zipf/Heaps sono descrizioni diagnostiche. Il riordino delle viste non cambia
l'ordine del corpus o dei checkpoint e non chiama completo un sottoinsieme
troncato. Il lotto non introduce backend lemma/POS/NER, metadati temporali o
formati di importazione prima dei relativi contratti.

## Stati e conservazione del lavoro

- Senza progetto o fonti: spiegazione e azione contestuale; nessun risultato simulato.
- Durante il calcolo: stato occupato posseduto dal task, azioni incompatibili disabilitate.
- Successo: risultato con richiesta e lineage effettivi; riuso dell'Artifact osservabile.
- Nessuna frase eleggibile o nessun elemento selezionabile nel budget: esito vuoto
  esplicito, distinto da errore tecnico e da riassunto completo.
- Failure: messaggio localizzato dalla tassonomia; il risultato valido precedente
  rimane identificato dal proprio scope e non viene dichiarato ricalcolato.
- Cambio di progetto: stato effimero e selezioni del laboratorio precedente ripuliti.

Riassunto, BM25, frequenze/ngrammi, MTLD, ponderazione, profilo corpus e keyness diretti su
macOS espongono Annulla nella barra esistente. Il modello possiede il task e
propaga la cancellazione del chiamante; la sola richiesta non rilascia handle o
stato occupato prima del terminale. Un risultato già committato può precedere la
cancellazione e non viene convertito in failure. La cancellazione del piano
rimane distinta; nessun nuovo comportamento iPadOS è introdotto (GS-DOR-195).

## Accessibilità e verifica

Componenti SwiftUI nativi, testo selezionabile, nomi accessibili, label dei campi,
ordine di tastiera e messaggi localizzati italiano/inglese sono obbligatori.
Metodo e parametri non dipendono dal colore; testo grande e finestre strette
devono conservare azioni e informazioni. Pseudo-lingua e destra-sinistra rientrano
nelle verifiche strutturali e nei limiti dichiarati; nessun audit dispositivo
viene inferito dalla build.

Test automatici del modello verificano richiesta, scope, failure, riuso,
conservazione e pulizia. Per A includono Markdown, BOM e Unicode multibyte;
Core/Kit verificano mapping e compatibilità dei DTO precedenti. Il profilo macOS
e il preflight senza firma non dimostrano GUI reale, VoiceOver o G4. Lo sviluppo
dedicato iPadOS rimane rimandato.

### Componenti e campi del lotto GS-DOR-304

Il ramo compatto dei sette laboratori macOS usa `TabView` nativa per alternare
impostazioni e risultati nell'area principale; il ramo largo mantiene i pannelli
ridimensionabili. Binding, identità e transizioni di selezione esistenti sono
conservati. Il cambio di tab non esegue analisi né azzera la bozza.

Nel laboratorio Valutazione le etichette dei campi restano visibili con dati
compilati, i campi multipli sono disposti verticalmente e i gruppi distinguono
osservazione o documento, riferimento o predizione e indice degli elementi.
Le azioni ripetute espongono tale contesto senza nascondere i controlli figli
alla navigazione assistiva. Stringhe e formati contestuali sono localizzati
in italiano e inglese; l'ordine nativo dei controlli resta significativo.

[GS-DOR-304](../pianificazione/dor-hig-laboratori-macos.md) delimita questa
correzione strutturale implementata; [GS-VER-304](../evidenze/GS-VER-304-hig-laboratori-macos.md)
registra gate e preflight macOS superati sul checkpoint 9c9e0098, con 113
definizioni e 345 esecuzioni native. Gli editor annidati mantengono i ForEach
Binding nativi, UUID stabili e una mappa ordinale O(n). Il contratto non dichiara audit GUI,
VoiceOver, Voice Control, Full Keyboard Access, pseudo-lingua o G4 superati.

## Accesso alle altre capacità del core (ADR-0041)

Il catalogo macOS deve ricercare anche il singolo metodo dei laboratori corpus,
statistico, temporale/linguistico e matrici/grafi, aprendo la relativa selezione.
Le diciassette analisi dirette del corpus usano le API persistite; le operazioni
pure hanno risultati di sessione con dati effettivi congelati e JSON esplicito.
Statistica ed evaluator linguistici devono funzionare senza progetto.

Date, checkpoint, giudizi, gold/predizioni, partizioni e coefficienti dei contrasti
sono input espliciti. Nessun nome di file diventa una data e nessuna annotazione
linguistica viene simulata. I valori mancanti e non definiti restano distinti
dallo zero. Le viste devono mostrare l'output precedente con la propria identità
quando la bozza cambia o una nuova esecuzione fallisce. L'assenza di convergenza
è visibile prima dell'interpretazione. Le tabelle sono complete e paginabili,
con editor e risultati separati nelle finestre strette.

L'estensione non cambia planner, schemi persistenti o stati scientifici.
La copertura per famiglia, i limiti interattivi e le prove sono registrati in
[GS-VER-223](../evidenze/GS-VER-223-copertura-core-app.md); l'adattamento dedicato
iPadOS e gli audit assistivi restano distinti.

## Barriera di reset dei laboratori macOS

Il reset di un modello di laboratorio invalida la pubblicazione delle
operazioni precedenti anche quando il loro Task non è stato cancellato.
Al completamento, l'operazione confronta la generazione privata catturata prima
del lavoro async con quella corrente, immediatamente prima di pubblicare sul
Main Actor senza un ulteriore await. Una generazione superata termina con la
failure cancellata e conserva lo stato corrente del modello, compreso un
eventuale risultato successivo. L'ownership dello stato occupato resta del
coordinatore applicativo.

La barriera protegge output e presentazione di sessione; non annulla Artifact
Core già committati. La verifica deterministica e i limiti del confine di test
sono definiti in [GS-DOR-273](../pianificazione/dor-barriera-reset-laboratori-macos.md)
e registrati in [GS-VER-273](../evidenze/GS-VER-273-barriera-reset-laboratori-macos.md).

## Presentazione corpus coerente durante la preparazione

Tabella, asse e ricerca identificano la presentazione derivata corrente.
Quando un loro cambiamento richiede lavoro async, righe, indici, conteggio e
pagina obsoleti devono essere invalidati sincronicamente. Durante pending si
mostra il progresso nativo localizzato e accessibile; le richieste di pagina
non possono usare dati della tabella precedente. Asse dichiarato e valori
visibili appartengono sempre alla stessa proiezione completata.

Filtro e proiezione hanno identità separate: una nuova ricerca o scelta di
tabella non annulla la proiezione dell'asse. Quest'ultima applica le scelte più
recenti ancora valide, e completamenti vecchi non ripristinano stato superato.
Reset e nuovo output invalidano entrambi i percorsi. Il risultato scientifico
catturato rimane invariato. Contratto e prove sono in
[GS-DOR-274](../pianificazione/dor-presentazione-corpus-coerente-macos.md) e
[GS-VER-274](../evidenze/GS-VER-274-presentazione-corpus-coerente-macos.md).

## Completamento delle capacità native

La GUI su ADR-0041 comprende i metodi del completamento nativo ADR-0035:
selezione LDA con tutti i criteri, MDS ordinale e con più avvii, SOM con geometria
e U-matrix, comunità, layout, foreste minime, Simpson e pipeline linguistica.
Il catalogo apre anche la singola variante MDS, comunità o layout. Le richieste
e risposte canoniche restano quelle di GS-API-002; gli esiti di sessione non
vengono promossi nel planner.

Il laboratorio linguistico funziona senza progetto e acquisisce, su azione
esplicita, una copia del testo estratto delle fonti. Mostra se la copia cambia,
gli offset UTF-8 del testo in esame, stati risolto/ignoto/non richiesto, provenienza
OS e versione del modello non esposta. L'indisponibilità locale non attiva
download o sostituzioni automatiche. Le variabili delle regole sono per unità.

I layout hanno tabelle complete e un'anteprima nativa con pari scala dei due
assi, fino a 512 collegamenti distinti; oltre tale limite l'anteprima non viene
presentata come grafo completo. La foresta usa costi non negativi (zero ammesso);
le altre proiezioni spiegano forza, topologia e policy di direzione.
