<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Riassunto estrattivo deterministico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-19 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.6.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-08 |
| Approvazione | Architettura approvata; `SentenceTFIDFMean-v1` fissato (GS-VER-146); `CentroidCosine-v1` fissato (GS-VER-149); `MMR-v1` fissato (GS-VER-151); `LexRankSentence-v1` fissato (GS-VER-164); `Budget-characters-v1` fissato (GS-VER-165) |
| Documento padre | [GS-MET-001](README.md) |

## Contratto

Il riassunto estrattivo seleziona frasi esistenti senza generarne il testo. Input,
segmenter, unità, budget (frasi, token o caratteri), scoring, ridondanza, tie-break e
ordine di presentazione **DEVONO** essere espliciti. Ogni frase selezionata conserva
`SentenceID`, score, rank e posizione sorgente.

Un summarizer dichiarato D0/D1 **DEVE** restituire la stessa selezione a parità di
input, descrittore e versione. L'ordine di output predefinito è quello della fonte;
l'ordine per score è una vista separata.

## Famiglie candidate

- `SentenceTFIDFMean-v1`: media dei pesi TF-IDF dei token inclusi della frase, con
  weighting GS-MET-001-07 e zero per frase senza token; tie-break sulla posizione.
- `CentroidCosine-v1`: centroide come media dei vettori delle unità, rilevanza della
  frase come coseno col centroide; vettori nulli sono esclusi con diagnostica.
- `TextRankSentence-v1`: nodi-frase, archi pesati dalla similarità dichiarata e
  PageRank con damping, soglia, dangling policy, tolleranza e iterazioni persistiti.
- `LexRankSentence-v1`: grafo di similarità coseno tra frasi, continuo o con soglia
  come variante esplicita, seguito dalla centralità versionata.
- `MMR-v1`: seleziona iterativamente
  `argmax_s [λ rel(s) - (1-λ) max_{u∈S} sim(s,u)]`, con `0≤λ≤1`, funzioni `rel` e
  `sim`, stato iniziale e tie-break dichiarati.

L'inclusione in questa specifica non rende tutte le famiglie obbligatorie nel primo
rilascio. Un'implementazione diventa disponibile soltanto dopo avere fissato
completamente la variante, superato fixture di riferimento e registrato i limiti
linguistici.

## Variante implementata: `SentenceTFIDFMean-v1`

L'implementazione di riferimento (`corpus-extractive-summary-v1`, GS-VER-146) fissa la variante
così:

- **unità**: le frasi del tokenizzatore italiano (GS-LNG-001) di ogni revisione del gruppo;
  `SentenceID` è la posizione zero-based della frase nel documento; la posizione sorgente è
  l'intervallo UTF-8 esatto, mai il testo copiato nell'Artifact;
- **token inclusi**: i token lessicali della frase, normalizzati come il profilo corpus
  (`it-token-v1-nfc-lowercase-v1`), ripetizioni comprese; i token fuori da ogni frase sono ignorati;
- **pesi**: matrice documento-termine del gruppo con uno schema GS-MET-001-07 dichiarato nel
  descrittore; il default è `TF-sublinear-v1`, `IDF-smooth-v1`, `RowNorm-none-v1`, definito anche
  per un solo documento; il punteggio di una frase è la media dei pesi `(documento, tipo)` dei suoi
  token, zero senza token;
- **rank**: punteggio decrescente, poi ordine canonico dei documenti, poi `SentenceID`
  (`tie-break.source-position-v1`); frasi duplicate hanno lo stesso punteggio e rank distinti;
- **budget**: `Budget-sentences-v1` (numero massimo di frasi) o `Budget-lexical-tokens-v1`
  (somma massima dei token lessicali), limite in `1…10 000`; la selezione scorre il rank e
  include ogni frase che rientra nel budget residuo, saltando quelle che lo supererebbero;
- **eleggibilità**: una frase senza token lessicali è classificata con punteggio zero ma non
  è mai selezionata (`eligibility.lexical-tokens-required-v1`);
- **ridondanza**: nessuna per default (`redundancy.none-v1`); frasi identiche possono entrare
  entrambe; `MMR-v1` è selezionabile con il parametro `redundancy` (sezione dedicata);
- **ordine di output**: `output-order.source-v1`; ogni frase candidata conserva punteggio, rank e
  flag di selezione, così la vista per rank è derivabile senza ricalcolo.

Il budget in caratteri è fissato in una sezione dedicata; le altre famiglie di punteggio
restano candidate.

## Variante implementata: `CentroidCosine-v1`

Seconda variante dello stesso Artifact (`corpus-extractive-summary-v1`, GS-VER-149), scelta
con il parametro `method` del descrittore; unità, token inclusi, pesi, rank, budget, ridondanza
e ordine di output sono quelli di `SentenceTFIDFMean-v1`. Cambiano punteggio ed eleggibilità:

- **vettore della frase**: per ogni tipo `t` del vocabolario del gruppo, `v_s[t] = c_{s,t} ·
  w_{d,t}`, dove `c_{s,t}` è il conteggio del tipo nella frase e `w_{d,t}` il peso
  `(documento, tipo)` dello schema GS-MET-001-07 dichiarato; una frase senza token, o i cui
  pesi sono tutti zero (per esempio `IDF-unsmoothed-v1` con un solo documento), ha vettore nullo;
- **centroide**: media aritmetica dei vettori non nulli di tutte le frasi del gruppo,
  `c = (1/|S⁺|) Σ_{s∈S⁺} v_s`; se `S⁺` è vuoto il centroide è nullo;
- **punteggio**: `cos(v_s, c) = (v_s · c) / (‖v_s‖₂ ‖c‖₂)` per le frasi con vettore non nullo e
  centroide non nullo, in `[0, 1]` perché pesi e conteggi sono non negativi; zero altrimenti.
  Le somme scorrono il vocabolario in ordine lessicografico, così il risultato è identico tra
  esecuzioni;
- **eleggibilità** (`eligibility.non-null-vector-v1`): una frase con vettore nullo è classificata
  con punteggio zero e `isEligible = false` e non è mai selezionata; il flag è persistito per
  ogni frase candidata, così l'esclusione resta diagnosticabile senza ricalcolo. I payload
  scritti prima di questo campo lo derivano dalla presenza di token lessicali, che era la sola
  regola di eleggibilità;
- **rank**: punteggio decrescente con `tie-break.source-position-v1`; frasi identiche hanno lo
  stesso coseno e rank distinti.

Metodi diversi sono nodi di analisi distinti: `method` entra nel descrittore come
rappresentazione, con l'eleggibilità del metodo tra i parametri.

## Ridondanza implementata: `MMR-v1`

Politica di selezione dello stesso Artifact (`corpus-extractive-summary-v1`, GS-VER-151),
scelta con il parametro `redundancy` del descrittore e applicabile a entrambi i metodi di
punteggio; punteggi, rank, eleggibilità, budget e ordine di output non cambiano. Cambiano la
selezione e la sua diagnostica:

- **rilevanza**: `rel(s)` è il punteggio del metodo dichiarato (`SentenceTFIDFMean-v1`,
  `CentroidCosine-v1` o `LexRankSentence-v1`), così com'è persistito in `score`;
- **similarità** (`similarity.sentence-vector-cosine-v1`): `sim(s, u) = cos(v_s, v_u)` tra i
  vettori frase `v_s[t] = c_{s,t} · w_{d,t}` dello schema GS-MET-001-07 dichiarato, gli stessi
  di `CentroidCosine-v1`; vale zero se uno dei due vettori è nullo; frasi con la stessa
  sequenza di token nello stesso documento, o comunque con vettori proporzionali, hanno
  similarità 1, mentre la stessa sequenza in documenti diversi usa pesi `(documento, tipo)`
  diversi e può avere similarità minore di 1;
- **selezione**: a ogni passo, tra le frasi eleggibili non ancora scelte che rientrano nel
  budget residuo, entra quella con il massimo di
  `λ · rel(s) − (1 − λ) · max_{u∈S} sim(s, u)`, con `S` l'insieme già scelto (penalità zero al
  primo passo); a parità di obiettivo vince la prima nell'ordine della fonte
  (`tie-break.source-position-v1`); la selezione termina quando nessuna frase rientra nel budget.
  La penalità di ogni candidata è il massimo corrente sulle frasi accettate, aggiornato una volta
  per accettazione: `k` frasi scelte su `n` candidate costano `k · n` coseni, nessuno con
  `λ = 1`;
- **parametro**: `λ` finito in `[0, 1]`, dichiarato nella richiesta e nel descrittore
  (`redundancyLambda`); `λ = 1` riproduce la scansione per rank di `redundancy.none-v1`,
  `λ = 0` premia soltanto la novità; valori fuori dall'intervallo sono rifiutati con failure
  tipizzata, mai corretti in silenzio;
- **diagnostica**: ogni frase scelta conserva `selectionOrder`, l'ordine uno-based di
  accettazione (per `redundancy.none-v1` coincide con l'ordine di rank tra le frasi scelte);
  le frasi non scelte non lo hanno. I payload scritti prima di questo campo non hanno
  `selectionOrder`, `redundancyLambda` né `similarityIdentifier`: decodificano come
  `redundancy.none-v1`.

Politiche diverse, o lo stesso `MMR-v1` con `λ` diversi, sono nodi di analisi e Artifact
distinti.

## Variante implementata: `LexRankSentence-v1`

Terzo metodo di punteggio dello stesso Artifact (`corpus-extractive-summary-v1`, GS-VER-164),
scelto con il parametro `method`; unità, token inclusi, pesi, rank, tie-break, budget, ridondanza
e ordine di output sono quelli già fissati. La variante è la LexRank continua di Erkan e Radev:

- **nodi**: le frasi con vettore frase `v_s[t] = c_{s,t} · w_{d,t}` non nullo, gli stessi vettori
  di `CentroidCosine-v1` e di `similarity.sentence-vector-cosine-v1`, in ordine della fonte;
  le frasi con vettore nullo non sono nodi, hanno punteggio zero e non sono eleggibili
  (`eligibility.non-null-vector-v1`);
- **archi**: grafo continuo, nessuna soglia: il peso dell'arco da `s` a `u` è
  `cos(v_s, v_u) ≥ 0`, autoanello compreso (`cos(v_s, v_s) = 1`); ogni riga è divisa per la
  propria somma, che vale almeno 1, quindi la matrice `M` è stocastica e nessun nodo è
  pendente: non serve una dangling policy;
- **centralità**: iterazione delle potenze `p ← (1 − d)/N + d · Mᵀ p` dal vettore uniforme
  `1/N`, con `N` il numero di nodi e damping `d = 0,85`; si arresta alla prima iterazione con
  variazione L1 non superiore a `10⁻¹²`. La contrazione di fattore `d` garantisce la convergenza
  in circa 170 iterazioni; oltre 1 000 iterazioni la stima fallisce chiusa con
  `summary.centrality-not-converged` (`invariantViolation`), senza Artifact;
- **punteggio**: `score` è la probabilità stazionaria del nodo; i punteggi delle frasi
  eleggibili sommano a 1 entro l'arrotondamento e il rank segue il tie-break dichiarato;
- **limite**: il grafo è denso e costa `N²` coseni e `N²` celle per iterazione; oltre
  2 000 nodi l'analisi fallisce con `summary.graph-limit-exceeded`
  (`insufficientResources`), mai su un sottoinsieme scelto in silenzio;
- **parametri**: damping, tolleranza, limite di iterazioni e di nodi sono fissati
  dall'identificatore versionato `LexRankSentence-v1`; valori diversi richiedono un nuovo
  identificatore e producono Artifact distinti. Il payload non aggiunge campi e non richiede
  migrazioni.

Frasi con la stessa sequenza di token nello stesso documento hanno lo stesso vettore e la stessa
centralità: il tie-break per posizione le ordina, `MMR-v1` le distingue. Con un solo nodo il
punteggio vale 1. La variante con soglia resta candidata; TextRank è fissato nella sezione seguente.

## Variante implementata: `TextRankSentence-v1`

Quarto metodo di punteggio dello stesso Artifact (`corpus-extractive-summary-v1`, GS-VER-166),
scelto con il parametro `method`; unità, token inclusi, rank, tie-break, budget, ridondanza e
ordine di output sono quelli già fissati. La variante segue Mihalcea e Tarau sul grafo di
sovrapposizione lessicale, resa stocastica come `LexRankSentence-v1`:

- **nodi**: le frasi con almeno un token lessicale, in ordine della fonte; le frasi senza token
  non sono nodi, hanno punteggio zero e non sono eleggibili
  (`eligibility.lexical-tokens-required-v1`); lo schema di ponderazione GS-MET-001-07 non entra
  nel grafo, resta dichiarato nel descrittore e serve soltanto alla similarità di `MMR-v1`;
- **archi** (`similarity.textrank-overlap-v1`): il peso fra `s ≠ u` è
  `|T(s) ∩ T(u)| / (ln|s| + ln|u|)`, con `T` l'insieme dei tipi della frase e `|s|` il numero
  dei suoi token, ripetizioni comprese; senza tipi comuni, o se entrambe le frasi hanno un solo
  token (`ln 1 + ln 1 = 0`), il peso è zero; nessun autoanello; soglia zero: entra ogni arco di
  peso positivo;
- **nodi pendenti** (`dangling.uniform-v1`): ogni riga è divisa per la propria somma; una frase
  senza archi salta uniformemente su tutti gli `N` nodi, così la matrice `M` resta stocastica;
- **centralità**: iterazione delle potenze `p ← (1 − d)/N + d · Mᵀ p` dal vettore uniforme con
  `d = 0,85`, tolleranza L1 `10⁻¹²`, limiti di 1 000 iterazioni e 2 000 nodi condivisi con
  `LexRankSentence-v1`, con le stesse failure `summary.centrality-not-converged` e
  `summary.graph-limit-exceeded`;
- **punteggio**: `score` è la probabilità stazionaria del nodo; i punteggi delle frasi
  eleggibili sommano a 1 entro l'arrotondamento;
- **parametri**: similarità, soglia, politica dei nodi pendenti, damping, tolleranza e limiti
  sono fissati dall'identificatore versionato; il payload non aggiunge campi e non richiede
  migrazioni.

Due frasi identiche a un solo token non si collegano fra loro e hanno la stessa centralità; essa
è uniforme soltanto se il grafo è fatto di soli nodi pendenti, mentre una terza frase con tipi
comuni e più token riceve la massa dei loro salti uniformi e le supera (oracolo
`TEXTRANK_UNIGRAM_SCORES`); frasi identiche con più token hanno peso `|T| / (2 ln|s|)` e la
stessa centralità, ordinate dal tie-break per posizione. La LexRank con soglia resta candidata.

## Budget implementato: `Budget-characters-v1`

Terza unità di budget dello stesso Artifact (GS-VER-165), indipendente dal metodo di punteggio e
dalla politica di ridondanza:

- **costo**: il numero di scalari Unicode del testo sorgente esatto dell'intervallo UTF-8 della
  frase, senza normalizzazione, rimozione di spazi o copia del testo nell'Artifact; un accento
  decomposto conta due scalari, come i code point di Python; i cluster di grafemi non sono usati
  perché la loro segmentazione dipende dalla versione Unicode della piattaforma;
- **limite**: lo stesso intervallo `1…10 000` delle altre unità, fuori dal quale l'analisi
  fallisce con `summary.invalid-budget`;
- **selezione**: identica alle altre unità: senza ridondanza la selezione scorre il rank e
  include ogni frase eleggibile che rientra nel budget residuo, saltando quelle che lo
  supererebbero; con `MMR-v1` il vincolo è lo stesso a ogni passo; una frase più lunga del
  budget non è mai selezionata e non è troncata;
- **intervallo non risolvibile**: se l'intervallo della frase non corrisponde al testo sorgente
  l'analisi fallisce con `summary.sentence-range-invalid` (`invariantViolation`), senza Artifact;
- **persistenza**: `budgetUnit` è già un parametro del descrittore, quindi l'unità produce un
  Artifact distinto; `consumedBudget` registra gli scalari consumati. Il payload non aggiunge
  campi e non richiede migrazioni: il costo di ogni frase si ricava dall'intervallo e dal testo
  sorgente.

## Separazione dalla generazione

Foundation Models o altri modelli che producono nuovo testo appartengono alla
categoria generativa N1. Il loro output **DEVE** essere marcato non autoritativo e
conservare modello disponibile, versione logica, configurazione, istruzioni,
contesto, strumenti, timestamp e provenienza. Un riassunto generativo **NON DEVE**
sostituire o essere esportato come riassunto estrattivo.

## Valutazione

I test verificano budget, tie, frasi duplicate, input vuoto, source order, offset e
ripetibilità. ROUGE o valutazioni umane, se adottate, richiedono tokenizzazione,
variante, riferimenti e protocollo propri; non provano da sole correttezza fattuale.

## Riferimenti scientifici

- Mihalcea e Tarau, [TextRank](https://aclanthology.org/W04-3252/), 2004.
- Erkan e Radev, [LexRank](https://doi.org/10.1613/jair.1523), 2004.
- Carbonell e Goldstein, [The Use of MMR, Diversity-Based Reranking for Reordering Documents and
  Producing Summaries](https://doi.org/10.1145/290941.291025), 1998.
- Carbonell e Goldstein, [Maximal Marginal Relevance](https://doi.org/10.1145/290941.291025), 1998.
