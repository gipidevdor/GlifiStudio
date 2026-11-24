# Firma e distribuzione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-008 |
| Tipo | Standard applicativo Apple |
| Versione | 0.2.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Regole prima del rilascio

- Team, bundle identifier, certificati e profili **DEVONO** essere definitivi e appartenere al titolare autorizzato.
- Archivi Release **DEVONO** essere prodotti da una revisione identificata e con Hardened Runtime su macOS.
- La distribuzione Mac App Store **DEVE** mantenere App Sandbox; la notarizzazione diretta non appartiene al canale iniziale approvato.
- Privacy manifest, privacy label, usage description ed entitlement **DEVONO** essere riesaminati insieme.
- Icone, metadati, screenshot, localizzazioni e dichiarazioni di accessibilità **DEVONO** essere completi per ogni piattaforma.
- Il candidato **DEVE** superare validazione dell'archivio, test su dispositivo, regressione e checklist di rilascio.
- Simboli di debug e informazioni necessarie alla diagnosi **DEVONO** essere conservati secondo la policy di retention.

ADR-0011 stabilisce App Store non in elenco, con singola identità multipiattaforma,
revisione ordinaria e rilascio manuale. La build completa **DEVE** essere inviata ad
App Review indicando tale intento; la richiesta `unlisted` segue la submission. Il
link risultante **NON È** un controllo degli accessi.

DA-018 blocca ancora team, profili e firma definitiva. La procedura e i gate
operativi sono nel [piano App Store](../app-store/README.md).
