<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-168 — Completamento degli algoritmi analitici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-168 |
| Tipo | Evidenza di implementazione e verifica numerica |
| Versione | 1.0.1 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti su richiesta dell'iniziatore |
| Ultima modifica | 2026-11-21 |
| Approvazione | Ambito richiesto dall'iniziatore; nessuna review umana simulata |
| Riferimenti | GS-DOR-168; GS-MET-001-04/05/14/15/17/18/19/21; RQ-008; RQ-063 |

## Perimetro storico e integrazione

Questa evidenza conserva i risultati osservati nel working tree sorgente del
2026-11-21, precedente all'integrazione sulla nuova base upstream `fe6f654`.
I conteggi dei test, i gate e le misure riportati appartengono al relativo
snapshot storico. La verifica della nuova integrazione è registrata separatamente
in [GS-VER-171](GS-VER-171-integrazione-algoritmi.md).

## Implementazioni

| Famiglia | Contratto e superficie |
| --- | --- |
| Distribuzioni lessicali | Frequenze ordinate, spectrum e crescita ai checkpoint; ZipfLogOLS-v1 e HeapsLogOLS-v1 separano osservazioni, previsioni e residui. Core e GlifiKit concorrente |
| Descrittive | Descriptive-Q7-v1: unità, mancanti, varianza campionaria/popolazione, quantili, singleton e insieme vuoto espliciti. Core e GlifiKit concorrente |
| Inferenza | WelchOneWayANOVA-v1; Pearson riscalato per dati finiti estremi, Spearman esatto rifiuta NaN/infinito |
| Multivariata | Taglio HAC a soglia, validazione di alberi decodificati, assegnazioni K-means canoniche, limiti/tolleranze e overflow NMF |
| Tempo | Temporal-calendar-token-rates-v1: giorno/mese/anno gregoriani, date civili distinte dagli istanti, fuso dichiarato, missing/outside policy, frequenze/DF/esposizione e lineage. Core e GlifiKit concorrente |
| Valutazione linguistica | Boundary e unit exact, lemma accuracy, confusion e P/R/F1 micro/macro/weighted, NER span/typed exact, feature morfologiche exact-set e per attributo. Core e GlifiKit concorrente |
| Riassunto | TextRankSentence-v1, LexRankSentence-continuous-v1 e LexRankSentence-threshold-v1; parametri, convergenza e Artifact distinti nel percorso Core/Kit/CLI |
| Stabilità numerica | PageRank con pesi estremi, coseno/distanze/KL senza overflow evitabili, JS vicino all'identità, Hellinger e smoothing Lidstone con contributi subnormali |

## Verifiche eseguite

Oracoli R (`lm`, `quantile`, `oneway.test`, `cor.test`) e Python indipendente
(soluzione del sistema lineare di PageRank e `Decimal(120)` per Jensen–Shannon),
casi esatti, invarianti, metamorfismi di scala/ordine/traslazione, input ostili,
budget e cancellazione. I cinque nuovi ValidationManifest restano `candidate`.

- Primo giro mirato: **45 test Core e 9 test Kit superati**. Le review successive
  hanno aggiunto regressioni che fallivano prima delle correzioni: varianza,
  Pearson e Welch con offset `1e15`; Heaps proporzionale al bordo `β=1`;
  JS con differenze `1e-6…1e-10`; contributi subnormali Hellinger/Lidstone.
- Suite completa nel gate: **347 test Core e 51 test Kit superati**.
- **152 righe di oracoli indipendenti** rieseguite e collegate ai test Swift.
  Per JS vicino all'identità i test impongono errore relativo `1e-12`, anche
  quando la divergenza è inferiore a `1e-15`; i test non si limitano al confronto
  assoluto del gate degli oracoli.
- **Due PDF conformi PDF/A-2u**, validati con veraPDF 1.30.4; nessun controllo
  PDF/A saltato. **51 controlli CLI** sulle 15 fixture condivise, QueryAST CLI
  e **22 checkpoint** di process-kill recovery superati.
- Prova CLI aggiuntiva per tutti e tre i metodi a grafo: configurazione
  `damping=0,75`, tolleranza `1e-11`, massimo 900 iterazioni e soglia `0,2`;
  quattro nodi e cinque archi, convergenza in 36/35/36 iterazioni, punteggi finiti
  e massa uno. Richiesta identica riusa l'Artifact; `damping=0,5` lo distingue.
  `damping=1` fallisce con exit 3 e `summary.invalid-graph-configuration`.
  I progetti sintetici temporanei sono stati eliminati.
- Test nativi macOS: **33 superati, zero falliti e zero saltati**, verificati
  anche tramite il riepilogo `xcresulttool`.
- **`make verify` terminato con exit 0 il 2026-11-21 alle 18:53 CET**:
  test e build macOS Debug, build macOS Release, build iPadOS Debug/Release
  tramite `GlifiStudio.xcworkspace`. Totale dei test: **431**.

Ambiente: Xcode 27.2, Apple Swift 6.4.2, Python 3.12.14 già installato, R e
veraPDF di sviluppo esistenti. Python è selezionato nel PATH della sola
esecuzione. Il primo preflight ha intercettato una chiave di localizzazione del
runtime introdotto dal lavoro concorrente: aggiunta la traduzione italiana e
inglese, il controllo è passato senza indebolire il gate.

Gli avvisi dell'host non sono stati nascosti: CoreSimulator installato
`1171.7.0`, inferiore a `1174.21.0` richiesto da Xcode, e avviso iPadOS sulla
dichiarazione di apertura dei documenti in-place. Le build generiche sono
superate; non è stata eseguita una prova dell'app su simulatore o dispositivo
iPad. Nessun aggiornamento di sistema o variazione dei gate per evitarli.

## Pulizia

La cache dedicata di questa esecuzione, mantenuta soltanto per l'integrazione
incrementale, è stata eliminata a fine verifica: **2.702.404 KiB, circa 2,58 GiB**.
Rimossi anche i log intermedi ridondanti; conservati il log del gate finale,
il piccolo riepilogo nativo e questa evidenza. Le toolchain, veraPDF, dipendenze,
cache di altre attività e file dell'utente sono preservati.

## Confini dell'evidenza

Le nuove primitive restano candidate finché prive della promozione per variante
ADR-0031. Gli algoritmi in memoria non estendono automaticamente planner, UI,
metadati persistenti o formato di progetto. Il riassunto usa il percorso
persistente già esistente. Il codice non introduce rete, telemetria o dipendenze.

Non sono implementate estensioni prive di contratto approvato: t-SNE/UMAP,
embedding neurali, stimatore Zipf–Mandelbrot, crescita media campionata, imputazione
temporale e trend inferenziale. Anche il budget del riassunto in caratteri
richiede una variante con unità definita. Questi confini non costituiscono
algoritmi implementati né evidenza V6, valutazione NLP su corpus reale o audit GUI.

Le tolleranze restano parte del contratto. Per esempio il coseno può arrotondare
a zero un risultato dell'ordine del minimo subnormale di Double: il relativo
errore assoluto è sotto la tolleranza `1e-12`. Non è dichiarata aritmetica esatta
o a precisione estesa per le primitive in virgola mobile.

Le modifiche preesistenti e il lavoro concorrente su documenti macOS, query e
laboratorio applicativo sono preservati; non appartengono a questo incremento.
