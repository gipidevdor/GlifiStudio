<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Esperienza adattiva macOS e iPadOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UX-001-12 |
| Tipo | Specifica normativa dell'esperienza utente |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline da prototipare sui target Apple 27 |
| Documento padre | [GS-UX-001](README.md) |

## Parità semantica, espressione nativa

macOS e iPadOS condividono progetto, indagine, intenzioni, evidenze, findings,
caveat e lineage. Non devono condividere forzatamente densità, disposizione o ogni
gesto. La stessa azione semantica mantiene identità ed effetto, mentre la
presentazione segue convenzioni e spazio della piattaforma.

## Navigazione adattiva

Per gerarchie reali, una composizione candidata usa:

- colonna primaria per progetto, corpus e indagini;
- colonna di contenuto per sintesi, elenco o percorso corrente;
- dettaglio per oggetto, evidenza, fonte o metodo.

`NavigationSplitView` è il meccanismo SwiftUI candidato, non una decisione sul
layout definitivo. In larghezze compatte le colonne possono collassare, ma percorso,
selezione, titolo, ambito e azione di ritorno **DEVONO** restare comprensibili. La
sidebar non ospita informazioni o azioni critiche soltanto sul bordo inferiore.

## macOS

- Il progetto o l'indagine può avere una finestra di lavoro persistente; nuove
  finestre si aprono su richiesta, non indiscriminatamente.
- Menu e comandi standard espongono creazione, apertura, importazione, ricerca,
  navigazione, confronto, export, Undo/Redo e gestione finestre.
- Tastiera, mouse, trackpad, selezione multipla, menu contestuali, drag and drop e
  toolbar contestuale supportano flussi professionali.
- Sidebar, inspector e colonne sono ridimensionabili o nascondibili quando
  appropriato; il contenuto resta utile a finestre ridotte.
- L'ampio display può mostrare evidenza e fonte affiancate senza imporre modalità.

## iPadOS

- L'app supporta touch, puntatore, tastiera, Full Keyboard Access, orientamenti,
  multitasking e finestre liberamente ridimensionabili.
- Nessuna funzione essenziale dipende da hover, Apple Pencil o menu contestuale.
- Inspector e dettagli possono diventare destinazioni o presentazioni adattive
  mantenendo l'oggetto selezionato.
- Drag and drop e condivisione usano contratti tipizzati quando approvati; esiste
  sempre un'azione accessibile equivalente.
- Lavori prolungati rispettano sospensione, checkpoint e cancellazione senza
  trattenere la persona in una schermata di attesa.

## Ricerca, toolbar e impostazioni

La ricerca primaria ha un solo ingresso riconoscibile e mostra l'ambito; ricerche
locali sono ammesse quando chiaramente contestuali. Le toolbar contengono poche
azioni frequenti relative al contenuto corrente; le opzioni del metodo appartengono
al piano o all'inspector, non alle impostazioni globali. Impostazioni predefinite
devono permettere di iniziare senza configurazione tecnica.

## Stato e ripristino

Una scena conserva soltanto navigazione, selezione, layout e contesto necessari al
ripristino; il progetto conserva il dominio. La piattaforma non garantisce che lo
stato per-scena sia durabile, quindi non può contenere l'unica copia di una domanda,
evidenza o nota. Più finestre sulla stessa indagine osservano versioni coerenti e
gestiscono esplicitamente modifiche concorrenti.

## Riferimenti Apple

- [Human Interface Guidelines — Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Human Interface Guidelines — Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- [Human Interface Guidelines — Windows](https://developer.apple.com/design/human-interface-guidelines/windows)
- [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Restoring app state with SwiftUI](https://developer.apple.com/documentation/swiftui/restoring-your-app-s-state-with-swiftui)
