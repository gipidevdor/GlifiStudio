<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Cronologia, persistenza e relazione dell'indagine

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-10 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-16 |
| Approvazione | Modello, storage ed export PDF/Markdown/CSV/JSON iniziali approvati |
| Documento padre | [GS-UX-001](README.md) |

## InvestigationHistory

La cronologia dell'indagine è un grafo persistente di eventi, non il solo stack di
Undo/Redo. Registra almeno:

- creazione o cambio di domanda e intenzione;
- corpus, versione e selezione usati;
- revisione del piano e motivazioni;
- finding osservato e livello aperto;
- oggetto esplorato, filtro e confronto richiesto;
- evidenza o caveat conservati;
- diramazione, ritorno o confronto tra varianti;
- selezione editoriale per la relazione.

Ogni evento ha identità, tempo, attore, predecessore, payload tipizzato e
riferimenti a entità persistenti. Gli eventi tecnici di scheduling non devono
sommergere il percorso cognitivo, ma restano nella diagnostica del DAG.

## Diramazioni e reversibilità

Modificare una decisione precedente può creare una nuova diramazione senza
distruggere il percorso precedente. La persona deve comprendere quale variante è
attiva, che cosa differisce e quali risultati sono validi. Un merge di rami non è
implicito: richiede semantica, conflitti e provenienza definiti.

Undo/Redo segue le convenzioni di piattaforma per azioni reversibili e descrive
l'effetto previsto. Non sostituisce storia analitica, versioni del DAG o recupero da
scritture interrotte.

## Salvataggio naturale

Progetto, indagine, piani, artefatti validi e cronologia vengono persistiti secondo
una policy recuperabile. La persona **NON DEVE** salvare manualmente ogni grafico.
Azioni come `preserve.result`, `add.to.investigation` o `mark.as.evidence` indicano
intenti semantici da localizzare e validare, non testi definitivi.

La persistenza automatica **DEVE** distinguere:

- contenuto autorevole dell'indagine;
- artefatti ricostruibili e cache;
- stato effimero della vista;
- stato per-scena utile al ripristino.

Il sistema comunica scritture fallite, spazio insufficiente e recupero senza
dichiarare salvato un contenuto non durabile.

## Report

Il rapporto è una proiezione versionata dell'indagine. Deriva strutturalmente da
domanda, corpus e versioni, percorso, findings selezionati, evidenze, caveat,
visualizzazioni, fonti e metodi. Distingue almeno:

- testo e note della persona;
- formulazioni deterministiche del sistema;
- valori e visualizzazioni derivati;
- contenuto generativo assistivo;
- limiti e riferimenti alle fonti.

Un modello generativo può migliorare una bozza, ma **NON DEVE** aggiungere risultati
non presenti, rimuovere caveat o rompere i riferimenti. L'esportazione conserva una
manifestazione verificabile del lineage o un allegato macchina risolvibile secondo
il formato approvato.

## Verifica

Si provano riapertura, diramazione, invalidazione, ripristino per scena, scritture
interrotte, cache mancante, conflitti futuri, export e confronto tra rapporto e
indagine sorgente. I test UX verificano che storia e stato attivo siano distinguibili.

## Stato implementativo 0.1

La prima slice registra eventi `created` ed `editorialSelectionChanged` con
InvestigationID, tempo Unix in millisecondi, classe dell'attore, predecessore e
payload tipizzato. Gli eventi hanno InvestigationEventID SHA-256, formano un grafo
append-only ramificabile e sono committati in una radice distinta dagli Artifact
ricostruibili. Riapertura, selezione di finding, diramazione, nuova importazione e
migrazione additiva dallo schema package 2 sono coperte da test Core/Kit.

Una `ReportRevision` esportabile proietta un head preciso, mantiene l'ordine dei
Finding selezionati e include soltanto la chiusura delle Evidence referenziate.
PDF, Markdown, CSV e JSON condividono manifest, digest e lineage. Il PDF/A-2u è
ricercabile e taggato; il Markdown supporta italiano/inglese con escaping; i CSV
conservano Finding/Evidence e payload canonici senza fonti complete. La destinazione
appare solo dopo verifica dello staging.

Osservazione dei finding, navigazione, note, confronto fra varianti, Undo/Redo UI,
autosave coalesced, persistenza del Report e preview/replace UI restano aperti e
non sono simulati dalle API correnti.
