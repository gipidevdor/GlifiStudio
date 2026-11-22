<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Sintesi editoriale e approfondimenti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-08 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da prototipare e validare |
| Documento padre | [GS-UX-001](README.md) |

## Risultato dell'analisi completa

La destinazione primaria dopo `review.completely` è una sintesi editoriale di ciò
che emerge, non un registro del tipo «27 analisi completate». Il conteggio delle
operazioni appartiene allo stato tecnico ispezionabile.

La sintesi compone soltanto sezioni sostenute da findings validi:

1. panoramica della raccolta;
2. temi principali;
3. parole e concetti caratterizzanti;
4. relazioni tra concetti;
5. differenze tra gruppi;
6. evoluzione nel tempo;
7. similarità e struttura dei documenti;
8. elementi insoliti o instabili;
9. qualità, dati insufficienti e limiti dell'analisi.

Ordine, presenza e priorità sono determinati da una policy editoriale versionata.
L'assenza di una sezione **NON DEVE** essere interpretata come assenza del fenomeno:
quando rilevante, il sistema spiega che dati o applicabilità non consentono di
rispondere.

## Unità editoriale

Ogni unità della sintesi contiene almeno:

- formulazione del finding;
- oggetto e ambito studiati;
- categoria di solidità o assenza motivata della categoria;
- caveat prioritari;
- azioni per evidenza, fonti e metodo;
- stato di conservazione nell'indagine.

Grafico, tabella o testo sono proiezioni sostituibili della stessa struttura. Una
visualizzazione decorativa non può creare un finding né nascondere denominatori,
incertezza o valori mancanti.

## Approfondimenti suggeriti

Un `FollowUpAction` deriva dal tipo del finding, dagli oggetti coinvolti e dalle
analisi ancora applicabili. Per un aumento temporale di un concetto, esempi validi
sono: esplorare relazioni crescenti, vedere documenti contribuenti, identificare i
gruppi che spiegano il cambiamento, confrontare prima/dopo o aprire le fonti.

Ogni suggerimento **DEVE** dichiarare destinazione, input, intenzione, stato di
applicabilità e possibile costo. Il ranking è deterministico e versionato; non usa
suggerimenti casuali o promozionali. La vista iniziale mostra un numero limitato e
comprensibile di azioni, con le altre disponibili per progressive disclosure.

## Aggiornamento progressivo

Durante un'analisi lunga, sezioni complete e valide possono apparire prima delle
altre. Stato parziale e copertura **DEVONO** essere visibili e non confusi con la
sintesi finale. Un finding invalidato scompare dalla vista corrente ma resta nella
cronologia con il proprio stato; un aggiornamento non deve far perdere focus,
selezione o lettura senza segnalazione accessibile.

## Verifica

La verifica copre selezione condizionale delle sezioni, corrispondenza tra finding e
frase, ordinamento deterministico, propagazione dei caveat, approfondimenti validi,
stati parziali e comprensione mediante test con utenti rappresentativi.
