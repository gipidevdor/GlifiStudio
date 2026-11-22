<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Laboratorio di analisi testuale macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-17 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.2.0 |
| Stato | Baseline implementativa per incrementi separati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | ADR-0033; richiesta esplicita di completamento dell'analisi testuale macOS |
| Documento padre | [GS-UX-001](README.md) |

## Contesto e percorso

Il laboratorio appartiene alle fonti e all'indagine correnti. Presenta azioni
comprensibili: ottenere un riassunto, trovare documenti pertinenti, descrivere il
lessico. Non richiede di scegliere un algoritmo prima di conoscere ambito e
risultato desiderato. I tre flussi A–C entrano con incrementi autonomi; la loro
presenza nella specifica non li dichiara implementati.

Per A–D l'ambito **DEVE** indicare tutte le fonti oppure le revisioni selezionate,
riconoscibili per nome quando disponibile, altrimenti tramite etichetta locale
“Fonte N” con identità della revisione, formato e byte. Non si inventano nomi
originali né si aggiungono metadati persistenti per la sola presentazione.
I risultati conservano lo scope effettivo e
la generazione usata, distinguendoli dall'eventuale selezione modificata dopo il calcolo.
La UI usa soltanto GlifiKit e non costruisce risultati scientifici locali.

## A — Riassunto estrattivo

La persona vede che il riassunto seleziona frasi esistenti e non genera testo.
Il controllo iniziale è il budget: numero di frasi o token lessicali, nei limiti
GlifiKit `1…10 000`; default tre frasi. I dettagli permettono di scegliere
`SentenceTFIDFMean-v1` o `CentroidCosine-v1` e la ridondanza assente oppure
`MMR-v1` con λ esplicito in `[0, 1]`. La ponderazione predefinita
`TF-sublinear-v1 / IDF-smooth-v1 / RowNorm-none-v1` resta dichiarata nel metodo.
I controlli non correggono silenziosamente parametri invalidi.

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
