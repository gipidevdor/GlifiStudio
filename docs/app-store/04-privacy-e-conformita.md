# Privacy e conformità App Store

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-004 |
| Tipo | Piano di conformità privacy |
| Versione | 1.1.0 |
| Stato | Baseline candidata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Baseline corrente

La build non dichiara tracking, dati raccolti, SDK di terzi o Required Reason API.
Il privacy manifest e la dichiarazione operativa devono essere aggiornati insieme a
ogni dipendenza, API, telemetria, funzione cloud o modello remoto introdotto.

`ITSAppUsesNonExemptEncryption = NO` è valido soltanto finché app e dipendenze non
usano crittografia non esente. Ogni modifica di rete o sicurezza riapre la
valutazione export compliance.

GS-PROD-001 rende questa scelta un vincolo del prodotto 0.1: elaborazione locale,
nessun account, rete, sincronizzazione o telemetria e nessun contenuto/query/path
del corpus nei log. Qualunque difformità riapre ADR-0016, threat model, manifest,
label e review.

## Prima della submission

- pubblicare una privacy policy raggiungibile, stabile e localizzata;
- rispondere in App Store Connect in base a comportamento reale, SDK inclusi;
- rieseguire l'inventario dei dati e delle API richieste;
- verificare consenso, cancellazione, retention e accesso ai file;
- mantenere App Sandbox su macOS e il minimo privilegio su entrambe le app;
- registrare la revisione in `privacy-declaration.json`.

La privacy policy è obbligatoria anche se l'app dichiara di non raccogliere dati.

## Riferimenti

- [Apple — Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Apple — Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Apple — Encryption declaration](https://developer.apple.com/documentation/BundleResources/Information-Property-List/ITSAppUsesNonExemptEncryption)
- [Apple — Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)
