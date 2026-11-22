# Integrazione di sistema e lavoro prolungato

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-013 |
| Tipo | Standard applicativo Apple |
| Versione | 1.2.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0008 |

## Esperienze di sistema

| Tecnologia | Valore per Glifi Studio | Stato |
| --- | --- | --- |
| App Intents e App Entities | Progetti, corpus e azioni disponibili a Shortcuts, Siri, Spotlight e Apple Intelligence | Post-MVP; quando identità e permessi sono stabili |
| Core Spotlight | Ritrovamento e apertura profonda di entità | Post-MVP secondo GS-PROD-001 |
| Core Transferable e ShareLink | Importazione, esportazione, drag and drop e condivisione tipizzata | Da adottare con i primi formati stabili |
| Swift Charts | Visualizzazioni statistiche native, accessibili e adattive | Prima scelta per grafici compatibili |
| BackgroundTasks | Continuazione su iPadOS di elaborazioni esplicitamente avviate dalla persona | Condizionale alla prima operazione lunga |
| `NSUserActivity` e Handoff | Ripresa contestuale e passaggio tra dispositivi | Condizionale a DA-017 |
| PencilKit e interazioni Apple Pencil | Annotazione diretta di documenti | Condizionale a un requisito di annotazione |

Indagine, corpus, documento e finding possono diventare `AppEntity` soltanto quando
identità, autorizzazioni e deep link sono stabili. Il testo esposto a Spotlight o
Shortcuts non deve divulgare contenuto sensibile né trasformare un finding invalido
o storico in risultato corrente.

## App Intents

- Azioni e `AppEntity` **DEVONO** riferirsi a servizi di dominio già testati; gli intent non devono duplicare la logica applicativa.
- Ogni entità **DEVE** usare un identificatore persistente e offrire soltanto proprietà necessarie all'esperienza di sistema.
- Intent, parametri e risultati **DEVONO** essere localizzati, accessibili e sicuri quando eseguiti senza interfaccia in primo piano.
- Azioni distruttive, esportazioni e accesso a dati sensibili **DEVONO** mantenere conferme e autorizzazioni appropriate.
- Core Transferable **DOVREBBE** essere adottato per rendere le entità scambiabili tra processi senza formati ad hoc.

## Elaborazioni lunghe su iPadOS

- Un'elaborazione avviata dalla persona che deve proseguire dopo il background **DOVREBBE** valutare `BGContinuedProcessingTask`.
- L'operazione **DEVE** pubblicare titolo e avanzamento localizzati, supportare cancellazione, salvare checkpoint e gestire l'expiration handler.
- Il processo **NON DEVE** presumere che il sistema conceda tempo illimitato o che una chiusura forzata generi una callback.
- Accesso GPU in background **NON DEVE** essere richiesto prima che benchmark e requisito dimostrino la necessità dell'entitlement dedicato.
- `BGProcessingTask` e `BGAppRefreshTask` **DEVONO** essere riservati rispettivamente a manutenzione differibile e aggiornamenti brevi realmente necessari.

Su macOS, il lavoro controllato resta legato a task con ownership, progresso e cancellazione. Scheduler o attività di sistema vengono introdotti solo per manutenzione differibile; processi perpetui e polling non sono ammessi.

## Input e fattori di forma

- macOS **DEVE** offrire menu, comandi da tastiera, mouse/trackpad, finestre multiple e drag and drop per i flussi professionali.
- iPadOS **DEVE** supportare touch, puntatore, tastiera hardware, multitasking e finestre ridimensionabili.
- La parità fra piattaforme riguarda oggetti e azioni semantiche GS-UX; disposizione,
  densità e presentazioni possono seguire convenzioni native differenti.
- Route, scene, selezione e comandi applicano GS-UI-001; progress, cancellazione e
  checkpoint delle operazioni applicano GS-RUN-001.
- Apple Pencil, hover, fotocamera, widget, Live Activities e Handoff **DEVONO** essere attivati soltanto se migliorano un flusso approvato e con fallback accessibile.

## Riferimenti Apple

- [Getting started with App Intents](https://developer.apple.com/documentation/appintents/getting-started-with-the-app-intents-framework)
- [Spotlight integration for App Intents](https://developer.apple.com/documentation/appintents/spotlight)
- [Core Transferable](https://developer.apple.com/documentation/coretransferable)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [Performing long-running tasks on iOS and iPadOS](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados)
- [PencilKit](https://developer.apple.com/documentation/pencilkit)
