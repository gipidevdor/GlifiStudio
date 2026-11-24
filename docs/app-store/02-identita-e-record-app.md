# Identità e record App Store Connect

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-002 |
| Tipo | Specifica di configurazione App Store Connect |
| Versione | 1.0.0 |
| Stato | Baseline candidata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Identità candidata

| Attributo | Valore |
| --- | --- |
| Nome | Glifi Studio |
| Piattaforme | macOS e iPadOS |
| Bundle identifier condiviso | `studio.glifi.GlifiStudio` |
| Lingua primaria | Italiano (`it-IT`) |
| Categoria candidata | Produttività |
| Versione iniziale | `0.1.0` |
| Build iniziale | `1` |
| Pubblicazione | Manuale |

Il record deve esistere prima del caricamento. Per una singola app
multipiattaforma le piattaforme condividono il bundle identifier, mentre screenshot
e alcuni metadati restano specifici per piattaforma. Il nome, lo SKU, il team, il
record numerico e la disponibilità territoriale devono essere verificati dal
titolare dell'account prima della registrazione; non vanno inventati nel repository.

## Controlli

- nome tra 2 e 30 caratteri e disponibilità verificata;
- version/build coerenti in entrambi i target e monotoni a ogni upload;
- App ID esplicito, certificati e profili appartenenti al team corretto;
- nessuna capability implicita o entitlement estraneo al requisito;
- record e bundle non eliminati o ricreati durante una release attiva.

## Riferimenti

- [Apple — Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
- [Apple — Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
