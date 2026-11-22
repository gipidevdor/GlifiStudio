<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Evidence, Finding e Caveat

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-05 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.1.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Semantica approvata; regole interpretative da validare |
| Documento padre | [GS-UX-001](README.md) |

## Distinzioni epistemiche

| Concetto | Definizione | Non è |
| --- | --- | --- |
| `Evidence` | osservazione o risultato derivato mediante una procedura identificata | una frase promozionale o un'opinione |
| `Finding` | proposizione strutturata e comprensibile sostenuta da una o più evidenze | un fatto privo di lineage |
| `Caveat` | condizione che limita qualità, validità, generalizzabilità o interpretazione | un disclaimer generico aggiunto alla fine |

Un finding prodotto dal sistema **NON DEVE** esistere senza evidenze risolvibili. Un
caveat si collega al livello minimo pertinente — fonte, profilo, piano, evidenza o
finding — e si propaga ai discendenti che ne dipendono.

## Pipeline epistemica

```text
fonti → trasformazioni documentali → rappresentazioni linguistiche
      → motore analitico → Evidence → motore interpretativo → Finding
                                                     ↘ Caveat ↗
      → esperienza utente → eventuale livello generativo assistivo
```

Ogni elemento conserva la categoria epistemica definita in GS-MET-001-01:
osservato, trasformato, stimato, inferito, annotato o generativo. Si aggiunge
`interpretatoDeterministicamente` per una proposizione prodotta dal motore
interpretativo; questa categoria **NON** converte una stima in osservazione.

## Motore interpretativo deterministico

Il motore trasforma evidenze strutturate in findings mediante regole verificabili.
Ogni esecuzione **DEVE** registrare:

- ID e versione del rule set;
- evidenze di ingresso e relativo stato di validità;
- predicati valutati e risultato;
- tipo canonico del finding e proprietà strutturate;
- chiave del messaggio e argomenti localizzabili;
- valutazione della solidità e caveat prodotti o propagati;
- alternative non emesse e motivo della soppressione.

Il testo localizzato è una rappresentazione del finding, non la sua identità. A
parità di input, regole e locale canonico dei valori, la struttura prodotta **DEVE**
essere deterministica. Una regola non può dedurre causalità da associazione né
omettere un'assunzione violata.

## Struttura minima

Un `Finding` comprende almeno identità, tipo, soggetto, predicato, oggetto o valore,
ambito, direzione, grandezza applicabile, riferimenti alle evidenze, caveat, rule set
e categoria epistemica. Una `Evidence` conserva descriptor, valori, incertezza,
effect size, unità e lineage applicabili. Un `Caveat` conserva tipo, severità,
ambito, causa, conseguenza, azione possibile e origine.

## Capacità di non concludere

Il sistema **DEVE** poter produrre `insufficientEvidence` senza un finding positivo
quando, tra gli altri casi:

- quantità o qualità dei dati sono insufficienti;
- OCR o annotazioni linguistiche non raggiungono la soglia applicabile;
- pochi documenti dominano il risultato;
- gruppi o periodi non sono confrontabili;
- assunzioni metodologiche sono violate;
- il cambiamento osservato può derivare dalla composizione del corpus;
- stabilità o metadati essenziali sono insufficienti.

“Non lo sappiamo con questi dati” è un risultato valido e azionabile, non un errore
da nascondere.

## Slice implementata

`interpretation-rules-mvp-v1` materializza strutture content-addressed per profilo
corpus e keyness e le persiste come Artifact dipendente dal piano e dagli output
analitici. Ogni Evidence porta descriptor, metodo, misure, unità, revisione fonte,
intervalli in byte e caveat; ogni Finding porta rule set, proposizione, assessment,
chiave semantica localizzabile e riferimenti Evidence risolvibili.

La decodifica ricalcola le identità e rifiuta payload alterati. Un confronto che
non supera la policy keyness restituisce `insufficientEvidence`, motivi di
soppressione e caveat bloccante senza costruire Evidence o Finding fittizi. La UI
Conclusione → Evidenza → Fonti → Metodo, i conflitti tra evidenze e le revisioni
editoriali restano aperti e non sono simulati dalla superficie corrente.

## Confine generativo

Foundation Models o altri LLM possono riformulare findings già validi, assistere la
domanda o comporre una bozza di relazione. **NON DEVONO** decidere significatività,
creare evidenze, rimuovere caveat, modificare lineage o essere necessari alla
riproduzione. Ogni aggiunta non sostenuta deve essere bloccata o marcata come testo
generativo non autoritativo e mai persistita come finding del sistema.
