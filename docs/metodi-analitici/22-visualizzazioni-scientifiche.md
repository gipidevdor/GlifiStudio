<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Visualizzazioni scientifiche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-MET-001-22 |
| Tipo | Specifica normativa dei metodi analitici |
| Versione | 1.1.1 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-22 |
| Approvazione | Catalogo richiesto; design UI da validare |
| Documento padre | [GS-MET-001](README.md) |

## Separazione fra artefatto e view

Una visualizzazione è una proiezione di un artefatto analitico, non l'artefatto.
Il motore produce dati, identità, incertezza e lineage indipendenti da SwiftUI,
AppKit o UIKit. La view **NON DEVE** ricalcolare con formule proprie né scartare
silenziosamente valori non finiti, mancanti o esclusi.

Il nome d'esperienza può descrivere la domanda a cui la vista risponde, secondo
GS-UX-001, ma metodo e variante scientifica **DEVONO** restare espliciti nel
dettaglio e nella provenienza.

## Contratto della specifica di vista

Ogni vista persistibile **DEVE** dichiarare artefatto sorgente, campi, mapping
visivi, aggregazione, filtri, ordinamento, assi, unità, scale lineari/logaritmiche,
trasformazioni, dominio, clipping, palette semantica, precisione visualizzata e
politica di dati mancanti. Downsampling e layout stocastici sono trasformazioni
versionate con seed o bound d'errore.

## Catalogo minimo rappresentabile

| Vista | Artefatto richiesto |
| --- | --- |
| Frequenze e rank-frequency | distribuzione osservata, eventualmente modello separato |
| Dispersion plot | posizioni e partizione delle occorrenze |
| Vocabulary-growth plot | sequenza `V(n)`, ordine e checkpoint |
| Heatmap | matrice con identità di righe/colonne e scala |
| Dendrogramma | albero completo delle fusioni HAC |
| Correspondence plot | coordinate CA, scaling, inerzia, contributi/cos² |
| PCA/factor plot e scree plot | coordinate/loadings e spettro di valori |
| Timeline | intervalli temporali, denominatori e mancanti |
| Tabella/mosaico di contingenza | osservate, attese e residui |
| Rete di co-occorrenza | grafo, pesi, soglie e layout distinto |
| Concordanza KWIC | occorrenza, contesto e posizione sorgente |

## Navigazione bidirezionale

Selezionare punto, barra, cella, arco, nodo, cluster, frase o concordanza **DEVE**
permettere, quando semanticamente possibile, di raggiungere unità, segmenti, token e
posizioni contribuenti. La fonte **DEVE** poter evidenziare a sua volta i risultati
derivati applicabili. Aggregazioni troppo grandi possono restituire una query o un
campione dichiarato, mai un insieme implicito differente.

La vista espone la classe `exact`, `contributive` o `derivational` definita da
GS-MET-001-01. Un'interazione visiva tramite hover **NON DEVE** essere l'unico
accesso al valore o al lineage.

## Correttezza percettiva e accessibilità

Assi troncati, scale logaritmiche, normalizzazioni e incertezza devono essere
visibili. Area, volume e colore **NON DEVONO** rappresentare quantità senza legenda
e mapping coerente. Colore non è l'unico canale. Ogni vista offre descrizione
accessibile, valori tabellari esportabili, navigazione da tastiera e localizzazione
di etichette/numeri senza modificare la semantica dei dati.

## Integrità dell'export macchina

Il profilo v1 di [GS-VIZ-001, Export](../specifiche-di-design/08-visualizzazione-scientifica.md#export)
conserva writer e formati esistenti. Il verificatore **DEVE** controllare
l'inventario canonico dei due payload, i loro media type, dimensioni e digest,
la concordanza dei campi condivisi fra manifest e specifica e l'identità dei
byte CSV rispetto alla rigenerazione della stessa tabella. Un insieme di hash
autocoerenti non sostituisce la concordanza semantica dei payload.

La tabella è rettangolare; gli identificatori di righe, colonne, segni e assi
sono unici entro la rispettiva raccolta e i valori numerici rappresentati sono
finiti. Le osservazioni mantengono la
cardinalità della famiglia: foglie e fusioni del dendrogramma, nodi e archi
della rete, esclusioni e riduzione del factor plot non sono intercambiabili.
Una vista con esclusioni dichiarate può avere meno osservazioni visibili del
totale anche senza riduzione della vista. La verifica non impone una biezione
generale fra segni e righe.

Identità opache, generazione zero, software storico non vuoto e JSON
semanticamente equivalente restano compatibili. La verifica offline attesta
la coerenza del bundle; autenticità, presenza dell'Artifact nel progetto e
corrispondenza con una generazione esterna richiedono prove autorevoli
separate. Le prove di [GS-VER-175](../evidenze/GS-VER-175-integrita-export-viste.md)
non cambiano lo stato scientifico della capacità né chiudono gli audit GUI.

## Verifica

Snapshot visivi non sono sufficienti. I test verificano mapping dato-segno,
etichette/unità, dominio delle scale, inclusione di estremi/mancanti, selezione e
round-trip alla fonte. Fixture “golden” possono controllare resa, mentre test del
motore controllano i valori indipendentemente dalla GUI.
