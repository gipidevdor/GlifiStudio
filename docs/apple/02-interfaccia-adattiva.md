# Interfaccia adattiva

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-002 |
| Tipo | Standard applicativo Apple |
| Versione | 0.4.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0006 |

## Regole comuni

- L'interfaccia **DEVE** usare componenti e materiali di sistema prima di controlli personalizzati.
- Il layout **DEVE** adattarsi a ridimensionamento, orientamento, safe area, Dynamic Type, testo tradotto e direzione di scrittura.
- Informazioni e azioni primarie **DEVONO** rimanere raggiungibili nelle dimensioni supportate della finestra.
- Icone SF Symbols **DEVONO** avere significato coerente e un'etichetta testuale o accessibile.
- Presentazioni modali **DEVONO** essere riservate a decisioni che richiedono attenzione prima di continuare.
- Grafici compatibili **DOVREBBERO** usare Swift Charts e fornire descrizioni, sonificazione o rappresentazioni tabellari accessibili appropriate.
- Drag and drop, copia, condivisione e importazione **DOVREBBERO** convergere su tipi Core Transferable quando i contratti sono stabili.
- Per gerarchie reali, `NavigationSplitView` **DOVREBBE** essere il primo
  meccanismo valutato; la struttura deve collassare preservando percorso, ambito e
  selezione.
- Sidebar e toolbar **DEVONO** rappresentare destinazioni e azioni del dominio, non
  un catalogo delle famiglie algoritmiche.
- Findings, evidenze, fonti e metodo **DEVONO** condividere la stessa catena di
  navigazione progressiva definita da GS-UX-001.
- Route, scene, selezione, compare set, restoration, menu e componenti semantici
  **DEVONO** realizzare GS-UI-001 senza usare posizioni di riga come identità.

## macOS

- Comandi frequenti **DEVONO** essere disponibili da menu e tastiera quando vengono implementati.
- La finestra **DEVE** rimanere utile durante il ridimensionamento e non collocare azioni essenziali soltanto sul bordo inferiore.
- Flussi professionali **DEVONO** considerare selezione multipla, menu contestuali, finestre multiple e drag and drop.
- Evidenza e fonte **DOVREBBERO** poter essere affiancate o aperte in una finestra
  richiesta dalla persona, senza creare finestre automaticamente per ogni risultato.

## iPadOS

- L'app **DEVE** supportare finestre ridimensionabili, multitasking, touch, puntatore e tastiera.
- Il layout **NON DEVE** presumere l'esecuzione a schermo intero.
- La navigazione complessa **DOVREBBE** adottare sidebar o split view adattive quando esiste una gerarchia reale.
- Apple Pencil e hover **DEVONO** essere miglioramenti progressivi: nessuna azione essenziale può richiederli.
- Il collasso delle colonne **NON DEVE** perdere l'oggetto studiato o trasformare
  inspector e lineage in funzioni irraggiungibili.

## Riferimenti Apple

- [Human Interface Guidelines — Layout](https://developer.apple.com/design/human-interface-guidelines/layout)
- [Human Interface Guidelines — Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- [Human Interface Guidelines — Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [Human Interface Guidelines — Windows](https://developer.apple.com/design/human-interface-guidelines/windows)
- [SwiftUI — NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview)
