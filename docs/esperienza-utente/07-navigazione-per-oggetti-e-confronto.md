<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Navigazione per oggetti e confronto

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-07 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da prototipare e validare |
| Documento padre | [GS-UX-001](README.md) |

## L'oggetto è esplorabile

La navigazione primaria è organizzata intorno a progetto, corpus, indagine e oggetti
studiati. Termine, concetto, documento, segmento, autore, categoria, periodo, gruppo
e corpus hanno identità e destinazioni esplorabili. La selezione di un oggetto
**NON DEVE** richiedere la scelta preventiva di un algoritmo.

Una destinazione di esplorazione compone dinamicamente le sezioni sostenute dai
dati. Per esempio, un concetto può esporre presenza, frequenza, dispersione,
andamento temporale, contesti, relazioni, gruppi caratterizzati, documenti
rappresentativi e fonti; le sezioni non applicabili non diventano pannelli vuoti.

## Architettura dell'informazione

Il modello logico comprende:

```text
Progetto
├── Profilo della raccolta
├── Corpus e selezioni
├── Indagini
│   ├── Panoramica
│   ├── Findings e caveat
│   ├── Oggetti esplorati
│   ├── Confronti
│   ├── Cronologia
│   └── Relazione
└── Fonti e documenti
```

Questa gerarchia descrive destinazioni semantiche, non impone che ogni voce sia
sempre visibile in una sidebar. Ricerca, deep link e cronologia devono raggiungere
gli stessi oggetti mediante identità persistenti.

## Confronto come primitive UX

La persona può selezionare almeno due corpus, gruppi, autori, categorie o periodi
compatibili e chiedere di confrontarli. Il sistema risolve il piano e organizza i
risultati intorno a domande:

- che cosa caratterizza ciascun gruppo;
- che cosa cresce o diminuisce;
- quali temi e relazioni differiscono;
- quanto gli oggetti risultano simili o differenti;
- quali fonti contribuiscono e quali limiti condizionano il confronto.

Compatibilità, unità indipendente, denominatori, copertura e metadati sono verificati
prima dell'esecuzione. Il test statistico non è un prerequisito per formulare il
confronto, ma variante e parametri restano disponibili nel livello Metodo.

## Selezione e contesto

- La selezione è tipizzata, distinguibile dal filtro e conservabile nella storia.
- Cambiare selezione aggiorna soltanto le viste dipendenti e rende visibile il nuovo
  ambito.
- Il percorso indietro ripristina oggetto, ambito, posizione e livello di dettaglio
  quando ancora validi.
- Un deep link identifica progetto, entità e versione necessaria, non una posizione
  visuale fragile.
- Ricerca globale e ricerca locale mostrano sempre l'ambito effettivo.

## Linguaggio delle viste

Le viste sono denominate principalmente dalla domanda: «Come si distinguono i
gruppi?» può usare una Correspondence Analysis; «Quali concetti sono collegati?»
può usare una rete di co-occorrenza. Il nome scientifico non viene alterato e appare
nel dettaglio metodologico con dimensioni, inerzia, contributi, parametri e limiti.
