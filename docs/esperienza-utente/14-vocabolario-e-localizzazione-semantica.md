<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Vocabolario e localizzazione semantica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-14 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-22 |
| Approvazione | Italiano iniziale approvato; microcopy da validare |
| Documento padre | [GS-UX-001](README.md) |

## Semantica prima della frase

Intenzioni, tipi di finding, caveat, azioni, stati e sezioni editoriali hanno
identificatori stabili indipendenti dalla lingua. Il catalogo Xcode contiene le
formulazioni; il modello persistente contiene chiavi e argomenti tipizzati. Una
modifica editoriale non cambia identità né invalida un'analisi.

## Registro terminologico iniziale italiano

| Concetto | Termine preferito nel primo livello | Termine tecnico accessibile |
| --- | --- | --- |
| `Investigation` | indagine | Investigation |
| `CollectionProfile` | profilo della raccolta | CollectionProfile e metriche |
| `Finding` | risultato emerso o conclusione, secondo contesto | Finding e tipo canonico |
| `Evidence` | evidenza | Evidence e artefatto GS-MET |
| `Caveat` | limite o aspetto da interpretare con cautela | Caveat, causa e severità |
| `AnalysisPlan` | piano dell'analisi | AnalysisPlan e descriptor |
| `notApplicable` | non applicabile ai dati disponibili | precondizione non soddisfatta |
| `insufficientEvidence` | i dati non permettono di concludere | regola e dimensioni insufficienti |
| `SourceReference` | fonte o passaggio di origine | ID, versione, coordinate e lineage |

“Conclusione” è ammesso soltanto per un finding sostenuto; non è sinonimo di dato
osservato. “Confidenza” non viene usato come etichetta generica per solidità,
confidence OCR, probabilità di modello e intervallo statistico, che restano concetti
distinti.

## Regole di scrittura

- Il primo livello usa italiano corrente, frasi brevi, attive e verificabili,
  con un'idea per frase e l'informazione necessaria per prima.
- Titoli e azioni descrivono domanda o esito, non il nome dell'algoritmo. Le
  etichette dei comandi iniziano con un verbo che ne chiarisce l'effetto:
  “Apri progetto”, “Importa fonti”, “Esporta relazione”.
- Lo stesso concetto mantiene lo stesso termine fra viste, messaggi e documenti.
  Il registro terminologico prevale sulla ricerca di sinonimi per variare il testo.
- Ogni parola deve aiutare a capire un dato o a compiere un'azione. Slogan,
  superlativi, interiezioni e formule decorative non sostituiscono l'informazione.
- I messaggi di errore dichiarano che cosa non è riuscito, la conseguenza,
  l'ambito preservato e il recupero possibile. Indicano una prossima azione
  disponibile, senza promettere salvataggio o assenza di modifiche che la failure
  tipizzata non garantisce.
- “Non lo sappiamo” viene espresso con rispetto e precisione, indicando che cosa
  manca senza attribuire colpa alla persona.
- Quantità, date, intervalli, percentuali, liste e pluralizzazione usano formattatori
  sensibili al locale; i dati delle fonti non vengono tradotti.
- Frasi non vengono costruite concatenando frammenti localizzati.
- Il dettaglio metodologico mantiene nomi scientifici standard e ne offre una
  descrizione localizzata senza rinominarli.

Le etichette restano comprensibili fuori dalla frase circostante: un collegamento
nomina la destinazione, un comando l'azione. “Leggi i limiti del metodo” è più
utile di “Clicca qui”. Istruzioni e messaggi non presuppongono mouse, tocco o
una particolare modalità di accesso.

## Ordine e approfondimento

Il primo livello presenta l'esito o lo stato e la prossima azione utile. Metodo,
parametri e spiegazioni estese emergono per approfondimento, secondo
[GS-UX-001-06](06-progressive-disclosure-e-solidita.md). Limiti che cambiano il
significato di un risultato o la decisione da prendere restano accanto al
risultato: la riduzione del testo visibile non deve nascondere incertezza,
non applicabilità o insufficienza dei dati.

Uno stato vuoto spiega che cosa manca e come proseguire, se un'azione è
disponibile. La brevità non elimina unità, fonte o qualificazioni necessarie
per interpretare un valore.

## Applicazione alla documentazione del repository

README e guide usano titoli Markdown in ordine gerarchico, paragrafi brevi e
collegamenti che descrivono la destinazione. Le tabelle servono a confrontare
valori; i blocchi di codice distinguono comandi e output dal testo. La struttura
deve restare leggibile con ingrandimento, lettura lineare e tecnologie assistive,
senza dipendere da allineamenti ottenuti con spazi o da immagini del testo.

Le immagini informative hanno un testo alternativo utile; stato e significato
di un controllo restano espressi anche in parole. Badge, colori e icone non sono
l'unica fonte di informazione. Le sintesi rimandano ai documenti controllati e
alle evidenze, distinguendo ciò che è disponibile da ciò che è pianificato.

## Contratto dei messaggi deterministici

Una formulazione del motore interpretativo conserva `messageKey`, argomenti
tipizzati, unità, regola e versione. Le traduzioni **DEVONO** preservare soggetto,
direzione, negazione, forza, quantità e caveat. Se una struttura non può essere
espressa correttamente in una lingua, la funzione resta non disponibile in quella
localizzazione anziché usare una frase ambigua.

## Verifica

Italiano e inglese devono essere verificati su pluralizzazione, testo lungo,
VoiceOver, termini scientifici, negazioni e categorie di solidità. Stress test
destra-sinistra verificano layout e ordine, senza dichiarare una lingua tradotta che
non possiede catalogo e revisione. Studi di comprensione validano le formulazioni
italiane iniziali prima di promuoverle a baseline.

La revisione editoriale controlla anche coerenza dei termini, etichette lette
isolatamente, prossima azione nei messaggi e ordine di lettura dei documenti.
Queste regole e i riferimenti HIG orientano la scrittura; non attestano conformità
dell'interfaccia o superamento di audit. Standard controllati e profili Apple
restano le fonti normative del progetto.

## Riferimenti

- [GS-I18N-002](../internazionalizzazione-interfaccia.md)
- [Apple Human Interface Guidelines — Writing](https://developer.apple.com/design/human-interface-guidelines/writing)
- [Apple Human Interface Guidelines — Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Apple Human Interface Guidelines — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple Human Interface Guidelines — Inclusion](https://developer.apple.com/design/human-interface-guidelines/inclusion)
