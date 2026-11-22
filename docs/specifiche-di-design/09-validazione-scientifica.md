<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Validazione scientifica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VAL-001 |
| Tipo | Specifica di validazione e correttezza |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-20 |
| Approvazione | Baseline proposta; oracoli e soglie per metodo da approvare |
| Riferimenti | GS-MET-001; GS-LNG-001; GS-QRY-001; GS-ANA-001; GS-RUN-001; GS-STD-001-16 |

## Scopo

Questa specifica definisce come dimostrare che l'implementazione realizza i
contratti scientifici e linguistici. Non approva un metodo per notorietà della
libreria e non sostituisce review scientifica indipendente.

Una capacità non può essere dichiarata `supported` finché possiede almeno un
contratto GS-MET completo, fixture calcolabili, un confronto indipendente o
proprietà equivalenti, casi degeneri, determinismo e lineage verificati.

## Livelli di evidenza

| Livello | Evidenza | Obiettivo |
| --- | --- | --- |
| V0 | Controllo statico di schema e precondizioni | Impedire configurazioni impossibili |
| V1 | Esempi calcolati a mano con razionali/decimali esatti | Provare formula e convenzioni |
| V2 | Implementazione indipendente | Rilevare errori condivisi nel codice prodotto |
| V3 | Property-based e metamorphic testing | Coprire famiglie di input e invarianti |
| V4 | Golden corpus/dataset versionato | Bloccare regressioni semanticamente revisionate |
| V5 | Equivalenza cross-backend e cross-device | Provare sostituibilità entro tolleranza |
| V6 | Review scientifica e riproduzione esterna | Sostenere la promozione a stabile |

V0–V4 sono obbligatori per una capacità MVP. V5 è obbligatorio se esistono più
backend; V6 è criterio per dichiarazioni forti o metodi ad alto impatto.

## Oracoli indipendenti

R e Python/SciPy/scikit-learn possono essere
usati solo come strumenti di validazione, non dipendenze runtime né singola fonte
di verità. Ogni oracolo registra:

- ambiente, versione esatta, lockfile/container o manifest riproducibile;
- script, parametri, seed, locale e tipo numerico;
- input/output con digest e licenza;
- mapping esplicito tra la variante esterna e il contratto GS-MET;
- differenze note e trasformazioni necessarie.

Quando due oracoli divergono, il test resta non risolto finché la variante non è
riconciliata con formula o letteratura primaria. Copiare l'output di una libreria
senza dimostrarne i default non è validazione indipendente.

## Struttura delle fixture

```text
Fixtures/
├── manifest.json
├── Scientific/<method-id>/<case-id>/
├── Linguistics/it-v1/<case-id>/
├── Query/v1/<case-id>/
├── Persistence/v1/<case-id>/
└── Adversarial/<parser>/<case-id>/
```

Ogni caso contiene input minimo, output atteso o proprietà, provenienza/licenza,
digest, generatore opzionale, motivo della presenza e responsabile della review.
Corpus reali sensibili e output non redistribuibili non entrano nel repository.
Generatori sintetici sono seedati e conservano la versione.

La collezione `Fixtures/Scientific/v1` è un seed V1 pre-review: contiene quattro
casi sintetici per χ²/Cramér's V, cosine, PMI/NPMI e TF-IDF smoothed. Il gate li
ricalcola senza codice prodotto, ma non li promuove a V2/V4: mancano ancora
implementazione esterna revisionata, dataset indipendenti e copertura delle altre
varianti Must. Dopo la promozione i casi vengono ripartiti per method ID secondo la
struttura canonica sopra, conservando il seed originario.

## Protocollo numerico

Ogni campo numerico dichiara una modalità di confronto:

- `exactInteger` o `exactRational` per conteggi e fixture esatte;
- `absoluteTolerance` vicino allo zero;
- `relativeTolerance` su scale non nulle;
- `ulpTolerance` solo quando la variante IEEE e il backend lo consentono;
- `structural` per cluster, segni/eigenvector, ordinamenti con tie e grafi;
- `distributional` con intervallo e test predefinito per algoritmi stocastici.

Una tolleranza combina quando necessario `|a-b| ≤ atol + rtol×|b|`. `atol`,
`rtol`, ULP, precisione intermedia e gestione non-finite appartengono al contratto
del metodo, non a un helper globale. Tolleranze non possono essere ampliate solo
per far passare una regressione: serve evidenza e revisione.

## Proprietà e metamorfismi

Il catalogo minimo include:

- invarianza a permutazioni quando l'ordine non è semantico;
- scaling, simmetria, limiti e conservazione delle somme applicabili;
- equivalenza batch/streaming/sparse/spill e tra larghezze concorrenti;
- idempotenza di canonicalizzazione e stabilità degli ID;
- monotonicità o boundedness dichiarate dal metodo;
- trasformazioni Unicode equivalenti senza perdita di offset;
- query logicamente equivalenti con stessi match e ordine;
- invalidazione soltanto dei discendenti e riuso degli indipendenti;
- serializzazione/migrazione senza alterazione degli Artifact storici.

## Linguistica e query

Token e sentence boundary usano exact match degli intervalli UTF-8 e classi;
lemma/POS/NER usano confusion matrix, precision, recall, F1/accuracy per classe,
coverage e bootstrap confidence interval. Soglie separate proteggono apostrofi,
clitici, accenti e classi rare.

Il parser query usa golden valid/invalid, span diagnostici, round-trip AST, fuzzing
Unicode e limiti di complessità. RegEx avverse e input profondi devono terminare
nel budget senza crash o stack exhaustion.

## DAG, interpretazione e visualizzazione

Fixture del DAG coprono canonicalizzazione, collision resistance strutturale,
deduplica, invalidazione, checkpoint e recovery. InterpretationRule e ranking
usano decision table leggibili e casi confliggenti. Ogni visualizzazione è testata
su mapping, scala, missing, downsampling e lineage; snapshot pixel è evidenza
secondaria, non oracolo scientifico.

## Robustezza e sicurezza

Fuzz target obbligatori: parser del package, manifest/JSON, database migration,
Markdown, query e, prima del supporto, PDF/OCR. Il corpus avversario include
dimensioni dichiarate false, nesting, path traversal, symlink, decompression bomb,
Unicode patologico, valori non finiti e cancellazione in ogni fase.

Un crash, hang, accesso fuori memoria o commit parziale è fallimento anche se
l'output numerico nominale è corretto. Sanitizer e strumenti di concorrenza
applicabili sono parte del gate, con limiti documentati.

## Matrice minima per capacità

| Asse | Valori minimi |
| --- | --- |
| Input | vuoto, minimo, tipico, grande, limite, corrotto |
| Dati | mancanti, zero, costanti, sbilanciati, tie, non-finite se ammessi |
| Esecuzione | fresh, cache hit, riaperta, cancellata, spill, migrazione |
| Backend | riferimento e ogni backend promosso |
| Piattaforma | macOS 27 e iPadOS 27 nelle classi supportate |
| Locale | it, en UI, pseudolocale; analisi italiana invariata |
| Accessibilità | struttura, tabella equivalente e navigazione lineage |

## Gate e reporting

Ogni metodo ha un `ValidationManifest` machine-readable con stato
`experimental`, `candidate`, `supported` o `suspended`, evidenze, commit, toolchain,
dataset e limiti. Il CI esegue la suite deterministica piccola; dataset grandi e
dispositivi girano nel gate periodico/release con risultati allegati.

Ogni manifest **DEVE** dichiarare un blocco `numericAgreement` con la modalità di confronto del
[protocollo numerico](#protocollo-numerico), la tolleranza effettivamente imposta dai test quando
la modalità la prevede, l'oracolo usato e una nota che spieghi la scelta. Il passaggio a
`supported` richiede inoltre V0–V4 superati, un oracolo **indipendente dall'implementazione sotto
test** e una review registrata con responsabile e data (ADR-0031). Un manifest che resta
`candidate` **DEVE** dichiarare `statusReason`. Le tre regole sono verificate nel gate da
`check-fixtures.py`: una capacità il cui oracolo è un test del prodotto non può essere dichiarata
`supported`.

Una regressione aggiorna risultato o soglia soltanto dopo classificazione:
correzione di bug, cambio intenzionale di variante o errore dell'oracolo. In tutti
i casi si conserva la fixture precedente e si registra l'impatto sui progetti.

## Criteri di completezza

- nessuna API stabile priva di ValidationManifest;
- almeno V0–V4 e casi degeneri per ogni capacità MVP;
- riproducibilità da checkout pulito senza dati riservati;
- evidenza distinta per correttezza, prestazioni, UX e App Store;
- risultati, limiti e fallimenti pubblicabili in un rapporto privo di corpus.
