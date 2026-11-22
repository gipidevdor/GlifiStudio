<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Sostenibilità di sistema macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-015 |
| Tipo | Standard applicativo Apple |
| Versione | 1.0.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0018 |

## Scopo

Questo documento governa esclusivamente la cooperazione dell'app macOS con CPU,
memoria, energia, stato termico, lifecycle, App Nap, timer e I/O. La correttezza
scientifica e i budget di memoria del dominio restano in GS-MET e GS-RUN.

## Invariante operativo

L'app **DEVE** tornare a idle appena termina il lavoro richiesto. Quando è inattiva
e non esegue un'operazione esplicitamente avviata dalla persona:

- non mantiene polling, timer periodici, animazioni invisibili o refresh della UI;
- non avvia precomputazione, indicizzazione o manutenzione opportunistica;
- non impedisce App Nap o il riposo del sistema;
- non conserva task senza owner, sorgenti Dispatch o osservatori non cancellabili;
- non usa rete, GPU o Neural Engine nella baseline locale 0.1.

## Segnali di sistema

Ogni decisione di admission fotografa condizioni esplicite in
`GlifiSystemConditions`:

- `ProcessInfo.isLowPowerModeEnabled`, aggiornato dalla notifica di power state;
- `ProcessInfo.thermalState`, aggiornato dalla notifica thermal state;
- `DispatchSourceMemoryPressure` per eventi `warning` e `critical`;
- attività/visibilità della scena macOS, ricevuta dal lifecycle e non interrogata
  con polling.

Lo scaffold include il policy engine puro e testabile. Prima della prima operazione
lunga, l'adattatore AppKit/SwiftUI **DEVE** collegare le notifiche e la sorgente di
pressione al runtime; fino ad allora non è consentito implementare lavoro lungo che
dipenda da un profilo soltanto nominale.

Un valore futuro o sconosciuto è trattato conservativamente come pressione seria.
Il nome commerciale del Mac non determina il profilo.

## Profili vincolanti

`GlifiRuntimePolicy` produce una raccomandazione deterministica. Il parallelismo
nominale è limitato a otto unità anche su hardware con più core e viene ulteriormente
ridotto per preservare responsività e working set.

| Condizione | Interattivo | Avviato dall'utente | Utility/manutenzione |
| --- | --- | --- | --- |
| Nominale, app attiva | `responsive`, massimo 2 | `balanced`, massimo 8 | metà dei core / 1 |
| Termica `fair` | `balanced`, metà limite | `balanced`, metà limite | niente lavoro speculativo |
| Low Power Mode, termica `serious` o memoria `warning` | `constrained`, massimo 2 | `constrained`, massimo 2 | nuova admission negata; checkpoint |
| Termica o memoria `critical` | UI minima, massimo 1 | nuova admission negata; checkpoint | nuova admission negata; checkpoint |
| App inattiva | solo eventi necessari | continua solo se già richiesta e recuperabile | `suspended` |

Pressione di risorse **NON DEVE** modificare parametri scientifici, precisione o
significato del risultato. Può ridurre concorrenza, rinviare, fare checkpoint o
terminare con `resourceLimited`.

## Priorità e qualità di servizio

L'intento, non il desiderio di velocità, determina la QoS:

| Intento Glifi | Classe Apple |
| --- | --- |
| `interactive` | `userInteractive`, solo lavoro UI brevissimo |
| `userInitiated` | `userInitiated`, risultato necessario a proseguire |
| `utility` | `utility`, lavoro visibile e cancellabile con avanzamento |
| `maintenance` | `background`, differibile e ricostruibile |

Il runtime **NON DEVE** aumentare artificialmente la priorità, creare task detached
per evitare l'ereditarietà o occupare tutti i performance core. Structured
concurrency, backpressure e cancellazione restano obbligatori.

## App Nap e attività di processo

App Nap resta abilitato. Non sono ammessi opt-out globali o assertion permanenti.
`ProcessInfo.beginActivity` può essere usato soltanto per un'operazione lunga,
esplicita e finita che la persona si aspetta continui; deve preferire
`userInitiatedAllowingIdleSystemSleep`, avere reason statica, owner, `defer` per
`endActivity`, cancellazione e checkpoint.

`idleSystemSleepDisabled`, `idleDisplaySleepDisabled` e `latencyCritical` sono
vietati nella baseline. Una futura eccezione richiede misura energetica e ADR.

## Timer, eventi e I/O

- Gli eventi di sistema **DEVONO** sostituire il polling.
- Un timer necessario **DEVE** essere one-shot o avere tolleranza/coalescing,
  owner e invalidazione; nessun heartbeat serve a simulare avanzamento.
- Progresso e UI derivano da unità di lavoro completate, non da un timer.
- Letture e scritture **DEVONO** essere incrementali, bounded e raggruppate; cache
  ricostruibili hanno quota ed eviction.
- Autosave e checkpoint **DEVONO** accorpare scritture senza indebolire il commit
  point del package.
- Accelerate, Core ML o Metal entrano in un percorso solo se il profiling dimostra
  beneficio end-to-end anche su energia, copie e memoria.

## Verifica e soglie

Ogni release candidate macOS deve includere:

1. Energy Log, Time Profiler, Allocations, SwiftUI e File Activity sui flussi Must;
2. prova su alimentazione e batteria, Low Power Mode, termica simulata/osservata e
   pressione memoria controllata;
3. verifica che, entro 60 secondi dalla fine del lavoro, non restino task applicativi,
   timer ripetuti o assertion di processo e che l'app sia eleggibile per App Nap;
4. confronto con la baseline precedente di CPU, wakeup, dirty memory, disk write,
   launch e hang; una regressione superiore al 10% richiede correzione, spiegazione
   statistica o deroga;
5. matrice di test della policy per ogni condizione e intento;
6. riesame di `Xcode Organizer` dopo il rilascio, quando il campione è sufficiente.

La soglia relativa non autorizza un consumo assoluto elevato: la baseline iniziale
deve prima dimostrare assenza di lavoro inutile. Misure riportano build, hardware,
alimentazione, temperatura, fixture e ripetizioni.

Riferimenti Apple: [ridurre l'uso della batteria](https://developer.apple.com/documentation/xcode/reducing-your-app-s-battery-use),
[App Nap](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/AppNap.html),
[QoS](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheTaskLevel.html),
[timer](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html),
[ProcessInfo](https://developer.apple.com/documentation/foundation/processinfo) e
[DispatchSourceMemoryPressure](https://developer.apple.com/documentation/dispatch/dispatchsourcememorypressure).
