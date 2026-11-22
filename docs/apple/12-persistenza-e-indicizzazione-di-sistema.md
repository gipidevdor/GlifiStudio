# Persistenza e indicizzazione di sistema

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-012 |
| Tipo | Standard applicativo Apple |
| Versione | 1.1.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0008 |

## Separazione degli archivi

Metadati transazionali, fonti, posting list, matrici, cache e indice Spotlight hanno caratteristiche differenti e **NON DEVONO** essere forzati in un unico meccanismo di persistenza.

## Portafoglio tecnologico

| Tecnologia | Ruolo | Decisione corrente |
| --- | --- | --- |
| SQLite di sistema | Metadati, relazioni, history e riferimenti agli oggetti | Store canonico `.glifi` 0.1 secondo GS-DAT-001 |
| Foundation, FileWrapper e formato binario versionato | Package, fonti incorporate, indici, matrici e accesso incrementale | Adottati come contratti; layout da prototipare |
| CryptoKit SHA-256 | Digest incrementali e content addressing | Adottato per oggetti e serializzazioni canoniche |
| SwiftData | Eventuali proiezioni locali non autorevoli | Non definisce formato o schema canonico 0.1 |
| Core Spotlight | Ricerca di progetti, documenti e risultati riconoscibili dalla persona | Post-MVP; non sostituisce GlifiIndex |
| CloudKit/iCloud | Sincronizzazione opzionale tra dispositivi | Non adottato finché DA-017 e privacy non sono approvate |
| Keychain e CryptoKit | Segreti, chiavi e integrità crittografica quando richiesti | Obbligatori soltanto per il requisito pertinente |
| Compression/Apple Archive | Packaging, trasferimento e cache | Da valutare su compatibilità e benchmark |

## SwiftData

- SwiftData **NON DEVE** diventare la fonte di verità del package 0.1 né definire
  identità, schema esportabile o migrazione.
- Una futura proiezione SwiftData **DEVE** essere eliminabile e ricostruibile dalla
  fonte canonica, con actor isolation e senza blob massivi.
- L'aggiunta dell'entitlement CloudKit **NON DEVE** essere usata come scorciatoia per decidere la sincronizzazione.

## Core Spotlight

- Spotlight **DEVE** indicizzare soltanto entità utili e riconoscibili dalla persona, con identificatori stabili e deep link risolvibili.
- L'indice Spotlight **NON DEVE** essere la fonte di verità né il motore delle query scientifiche sul corpus.
- Gli elementi devono essere aggiornati o eliminati insieme alla relativa entità; la rigenerazione deve essere idempotente.
- Dati sensibili **DEVONO** usare un indice nominato con classe di protezione appropriata oppure restare esclusi.
- Il contenuto inviato a Spotlight **DEVE** rispettare minimizzazione, privacy e preferenze della persona.

## Sincronizzazione

CloudKit o documenti iCloud richiedono prima un contratto su identità cross-device, conflitti, quote, file mancanti, cifratura, cancellazione, uso offline e compatibilità di schema. La modalità locale **DEVE** rimanere utilizzabile salvo requisito contrario esplicitamente approvato.

Il contratto completo di package, transazioni, cache e migrazioni è
[GS-DAT-001](../specifiche-di-design/02-dati-lineage-e-persistenza.md).

## Riferimenti Apple

- [ModelContainer — SwiftData](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Core Spotlight](https://developer.apple.com/documentation/corespotlight)
- [Adding app content to Spotlight indexes](https://developer.apple.com/documentation/corespotlight/adding-your-app-s-content-to-spotlight-indexes)
- [CloudKit](https://developer.apple.com/documentation/cloudkit)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain-services)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit)
