# Ciclo di vita e stato SwiftUI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-001 |
| Tipo | Standard applicativo Apple |
| Versione | 0.2.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0006 |

## Regole

- Le app **DEVONO** usare il ciclo di vita SwiftUI `App` e scene dichiarative.
- Lo stato di presentazione mutabile **DEVE** essere isolato sul `MainActor` e usare Observation quando condiviso da più aggiornamenti della view.
- Le view **DEVONO** descrivere la presentazione; I/O, analisi e persistenza appartengono a GlifiKit/GlifiCore.
- Dipendenze e servizi **DEVONO** essere iniettabili nei modelli per consentire test deterministici.
- Le operazioni asincrone avviate da una view **DEVONO** cooperare con la cancellazione e non aggiornare stato dopo la cancellazione.
- Stato effimero, stato di navigazione e stato persistente **DEVONO** rimanere distinti.
- Ripristino di scene e finestre **DEVE** essere introdotto insieme al formato progetto, con test di riapertura.
- Progetto, indagine e risultati **NON DEVONO** esistere soltanto in `State` o
  `SceneStorage`; lo stato per-scena conserva selezione, navigazione e layout.
- Snapshot o flussi di profilo, piano, evidenze e findings **DEVONO** arrivare da
  servizi GlifiKit tipizzati; una view non decide applicabilità né interpreta test.
- Aggiornamenti progressivi **DEVONO** preservare focus e selezione oppure dichiarare
  la transizione in modo accessibile.

La baseline usa `StudioHomeModel`, `@Observable`, `@MainActor` e `.task`. Riferimento: [Managing model data in your app](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app/).

La baseline corrente resta uno scaffold e non realizza ancora i contratti
[GS-UX-001](../esperienza-utente/README.md).
