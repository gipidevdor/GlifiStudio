<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Lineage interattivo e numeri interrogabili

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-09 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Principio approvato; implementazione da progettare |
| Documento padre | [GS-UX-001](README.md) |

## Principio universale

Ogni numero significativo, segno visuale e proposizione analitica **DEVE** essere
interrogabile. L'azione apre valore, unità, ambito, denominatore, qualità,
incertezza, contributor, caveat e metodo applicabili. Un tooltip non è l'unico
mezzo, perché deve esistere un percorso equivalente per touch, tastiera e VoiceOver.

Esempi obbligatori quando semanticamente possibili:

- frequenza → occorrenze e documenti;
- punto temporale → intervallo, denominatore e documenti contribuenti;
- relazione fra termini → contesti che hanno generato l'arco;
- cluster → elementi, rappresentazione e criterio di appartenenza;
- cella o regione → righe, colonne e osservazioni sottostanti;
- finding → evidenze → fonti → metodo.

## Classi di lineage

| Classe | Garanzia |
| --- | --- |
| `exact` | insieme completo e risolvibile delle osservazioni che determinano il valore |
| `contributive` | contributori e pesi/ruoli rilevanti, senza pretendere un'inversione uno-a-uno |
| `derivational` | input e procedura esatti sono noti, ma la trasformazione non è matematicamente invertibile |

Un risultato dichiara la classe effettiva. Il sistema **NON DEVE** simulare lineage
esatto tramite top-k, campioni, documenti rappresentativi o nearest neighbor. Un
campione o una query di ricostruzione è identificato come tale e conserva metodo,
ordinamento, limite e copertura.

## Navigazione bidirezionale

La navigazione deve operare in entrambi i sensi quando semanticamente definita:

```text
Finding ↔ Evidence ↔ elemento analitico ↔ unità ↔ segmento ↔ SourceReference
```

Dalla fonte, la persona può vedere findings ed evidenze validi che citano la
selezione corrente. L'evidenziazione mantiene versione del corpus e sistema di
coordinate; se la fonte esterna è cambiata o manca, l'errore non viene mascherato.

## Interazioni coordinate

Selezionare un segno può filtrare o evidenziare viste collegate soltanto quando la
relazione è dichiarata. Il sistema conserva:

- origine della selezione e oggetto canonico;
- ambito prima e dopo il cross-filter;
- cardinalità completa, visualizzata e campionata;
- trasformazioni o soglie applicate;
- azione per rimuovere il filtro e ripristinare il contesto.

## Accessibilità e scala

Ogni vista offre alternativa strutturata o tabellare, ordinamento e ricerca dei
contributori. Per insiemi molto grandi, paginazione o streaming **NON DEVONO**
cambiare silenziosamente il totale. Focus, posizione di lettura e selezione restano
stabili durante caricamenti incrementali; gli aggiornamenti importanti sono
annunciati senza interrompere ripetutamente VoiceOver.

## Verifica

I test campionano ogni tipo di risultato e verificano il round-trip alla fonte, la
classe di lineage, la correttezza dei contributor, l'assenza di falsi exact e la
parità tra interazione visiva, tastiera e tecnologia assistiva.
