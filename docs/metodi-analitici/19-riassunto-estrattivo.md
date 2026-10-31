<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Riassunto estrattivo deterministico

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-19 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-10-16 |
| Approvazione | Architettura approvata; `SentenceTFIDFMean-v1` fissato (GS-VER-146); `CentroidCosine-v1` fissato (GS-VER-149) |
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
- **ridondanza**: nessuna (`redundancy.none-v1`); frasi identiche possono entrare entrambe;
- **ordine di output**: `output-order.source-v1`; ogni frase candidata conserva punteggio, rank e
  flag di selezione, così la vista per rank è derivabile senza ricalcolo.

Il budget in caratteri e le altre famiglie restano candidate.

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
- Carbonell e Goldstein, [Maximal Marginal Relevance](https://doi.org/10.1145/290941.291025), 1998.
