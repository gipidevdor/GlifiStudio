<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Valutazione dei servizi linguistici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-18 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.2.1 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-21 |
| Approvazione | Italiano come baseline; soglie da approvare |
| Documento padre | [GS-MET-001](README.md) |

## Contratto del servizio

Tokenizzazione, sentence segmentation, lemmatizzazione, POS tagging, morphological
features, named entity recognition e futura analisi sintattica **DEVONO** essere
servizi sostituibili. Ogni output conserva lingua, locale quando rilevante, schema di
tag, backend, versione del backend/modello, versione OS, configurazione e offset
verso la fonte.

La disponibilità di Apple Natural Language o di un modello Core ML **NON È**
evidenza di correttezza. L'italiano è la baseline iniziale; aggiungere una lingua
richiede un profilo di valutazione proprio e non modifica gli artefatti italiani già
versionati.

## Corpus di riferimento

Ogni valutazione **DEVE** dichiarare:

- corpus, versione, checksum, licenza e modalità di acquisizione;
- lingua, varietà, dominio, genere, epoca e criteri di campionamento;
- linee guida e schema delle annotazioni gold;
- split train/dev/test senza contaminazione nota;
- unità di valutazione, esclusioni e gestione dei casi ambigui;
- backend e ambiente esatti.

Corpora reali con restrizioni **NON DEVONO** essere inclusi nel repository; possono
essere riferiti tramite manifest riproducibile e checksum.

## Metriche

Con `TP`, `FP`, `FN`:

```text
precision = TP/(TP+FP)
recall    = TP/(TP+FN)
F1        = 2PR/(P+R)
accuracy  = corretti/totale
```

Denominatori nulli seguono una policy dichiarata e non diventano automaticamente
uno. Micro, macro e weighted average sono risultati distinti.

| Servizio | Valutazione minima |
| --- | --- |
| Tokenizzazione/segmentazione | precision, recall e F1 dei confini; exact match delle unità |
| Lemmatizzazione | accuracy esatta per token gold; errori per forma/POS |
| POS | accuracy e F1 per classe, matrice di confusione |
| Feature morfologiche | exact-set accuracy e P/R/F1 per attributo |
| NER | P/R/F1 span-level exact e, separatamente, tipo corretto |
| Sintassi futura | metrica dipendente dallo schema, per esempio UAS/LAS, specificata prima dell'uso |

Il matching parziale di span **DEVE** avere variante separata. Intervalli di
confidenza, se prodotti, dichiarano metodo e unità di resampling.

## Primitive di valutazione headless

`GlifiLinguisticEvaluation` implementa le metriche su annotazioni gold e predette
fornite dal chiamante, senza introdurre un backend linguistico o inferire un
allineamento. L'ordine dei token e dei documenti è quello del gold; lunghezze
diverse falliscono. L'uguaglianza delle etichette usa `String` Swift, sensibile
alle maiuscole e con equivalenza canonica Unicode; non si applica case folding.
Ogni risultato conserva conteggi ricostruibili e policy dei denominatori nulli:
`undefined` (predefinita) conserva `nil`, `zero` assegna zero, mai uno.

| Variante candidate | Contratto |
| --- | --- |
| `LinguisticBoundaries-exact-UTF8-v1` | P/R/F1 dei confini esatti nello stesso documento; P/R/F1 delle unità come intervalli fra confini consecutivi aggiungendo sempre `0` e lunghezza; accuracy dei documenti con tutti i confini identici |
| `LinguisticLemmas-exact-v1` | Accuracy sui token gold; forme e POS gold opzionali e allineati producono conteggi degli errori per gruppo canonico |
| `LinguisticClassification-exact-v1` | Matrice righe gold/colonne predette nell'unione ordinata delle classi; accuracy, P/R/F1 one-vs-rest, micro, macro e weighted distinti |
| `LinguisticMorphology-exact-set-v1` | Accuracy dell'intero dizionario di feature; P/R/F1 per attributo sul valore esatto, con FP e FN entrambi incrementati per valore errato |
| `LinguisticNER-exact-UTF8-v1` | P/R/F1 separati per span esatto senza tipo e per span più tipo; nessun credito per overlap parziale |

Micro somma TP/FP/FN prima della divisione; macro media ciascuna metrica sulle
classi dell'unione; weighted usa i supporti gold, escludendo soltanto i pesi zero.
F1 medio è la media degli F1, non l'armonica di P/R medi. Con `undefined`, un
addendo non definito con peso positivo rende non definita la relativa media;
F1 viene calcolato direttamente come `2TP/(2TP+FP+FN)`. Tutti gli insiemi vuoti
hanno le metriche con denominatore nullo non definite oppure zero secondo policy.

Gli offset sono byte UTF-8 half-open per NER, posizioni in `0...lunghezza` per
confini; i confini dichiarati partecipano al conteggio anche se sono gli estremi
del documento. Confini duplicati e span con estremi duplicati nella stessa
annotazione (anche con tipo diverso) sono errori. NER ammette span annidati.
Il chiamante verifica la validità Unicode degli offset sulla stessa fonte
immutabile: la primitiva riceve lunghezze, non legge né normalizza il testo.

Limiti prima delle allocazioni principali: un milione di token/documenti o
annotazioni per lato, 256 classi/attributi, 1.024 byte per etichetta o valore;
per la morfologia il milione limita anche il totale delle feature per lato.
Il totale di etichette, lemmi, forme/POS opzionali e chiavi/valori delle feature
non supera 64 MiB per richiesta, contando entrambe le annotazioni e ogni
occorrenza anche quando la stringa è ripetuta. La prelettura del budget osserva
la cancellazione prima delle strutture di conteggio e matching.
Superamenti, etichette vuote, range fuori fonte e disallineamenti producono
`GlifiFailure` senza risultati parziali. Le scansioni osservano la cancellazione.
La facciata `GlifiStudioLinguisticEvaluation` esegue con `@concurrent`, conserva
metriche e failure e restituisce DTO indipendenti dal Core.

Dopo la prelettura dei limiti, la morfologia visita gli attributi gold e poi
quelli presenti soltanto nella predizione, evitando insiemi e ordinamenti
temporanei per ogni token. L'ordinamento canonico avviene sul risultato per
attributo. La valutazione dei lemmi calcola una sola volta il confronto gold/predetto
e aggiorna nella stessa scansione accuracy ed eventuali strati per forma/POS;
le etichette già validate nel budget aggregato non richiedono una seconda
prelettura. Queste strutture conservano conteggi esatti, policy dei denominatori,
ordine dei gruppi, budget e cancellazione. Le misure Release prima/dopo e i
checksum distinti di input e risultato sono registrati in GS-VER-169, senza
cambiare gli identificatori delle varianti o il loro stato `candidate`.

Queste API sono `candidate`: i test a conteggi esatti, invarianti e parità Core/Kit
verificano il calcolo, senza attestare la qualità di alcun servizio NLP, promuovere
lingue o definire soglie di accettazione. Non producono intervalli di confidenza,
nuovi artefatti persistenti o estensioni del planner.

## Gate e deriva

Fino a quando non esiste una soglia assoluta approvata, il gate protegge la qualità con una
**linea di base registrata** (ADR-0030): `Fixtures/Linguistics/<corpus>/baseline.json` dichiara il
corpus, il suo digest e i valori P/R/F1 osservati; il test di qualità fallisce se il punteggio
scende sotto quei valori e segnala quando è salito, perché una linea di base non aggiornata
nasconderebbe la regressione successiva. Cambiare il corpus invalida la linea di base: il digest
non coincide più e il gate chiede di rimisurarla. Una linea di base non è una soglia di
accettazione e non dichiara che la qualità sia sufficiente.

Soglie per lingua, servizio, dominio e release sono approvate tramite DA-008. Un
backend può essere promosso soltanto se supera dataset gold, casi avversi, round-trip
degli offset e test di stabilità. Aggiornamenti di macOS/iPadOS o del modello
richiedono una nuova valutazione di deriva; regressioni oltre soglia impediscono il
riuso trasparente della vecchia versione logica.

## Verifica italiana iniziale

Le fixture devono includere apostrofi ed elisioni, clitici, parole composte,
abbreviazioni, numeri e date italiane, punteggiatura, virgolette, Unicode composto,
nomi propri e code-switching. Le fixture sintetiche verificano contratti e offset;
non sostituiscono un corpus gold rappresentativo: `it-gold-v0` misura oggi l'assenza di
regressioni, non la qualità su lingua reale.
