# Privacy e sicurezza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-004 |
| Tipo | Standard applicativo Apple |
| Versione | 0.3.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0006 |

## Baseline corrente

- Il privacy manifest dichiara nessun tracking, nessuna raccolta dati e nessuna required-reason API.
- L'app macOS usa App Sandbox e accede in lettura/scrittura soltanto ai file scelti dall'utente.
- Non sono concessi entitlement di rete, hardware, contatti, posizione, foto, microfono o fotocamera.
- Hardened Runtime è attivo per le build Release macOS; Debug mantiene i controlli di sviluppo e App Sandbox.

## Regole

- Privacy manifest, informativa App Store e comportamento effettivo **DEVONO** coincidere.
- Ogni nuova required-reason API **DEVE** avere una ragione Apple ammessa, verificata e registrata prima dell'integrazione.
- Capability e usage description **DEVONO** essere aggiunti soltanto insieme alla funzione che li richiede.
- File e dati dell'utente **DEVONO** essere minimizzati, protetti e rimossi secondo un ciclo di vita dichiarato.
- Segreti **DEVONO** usare Keychain quando esistono; non possono risiedere in sorgenti, preferenze o log.
- Secure Enclave, CryptoKit e LocalAuthentication **DEVONO** essere valutati per chiavi non esportabili o blocco locale del progetto, ma soltanto dopo un requisito e un modello di recupero approvati.
- Crittografia proprietaria **NON DEVE** sostituire primitive e protocolli Apple verificati.
- Eccezioni App Transport Security globali **NON DEVONO** essere abilitate.
- Telemetria e tracking restano disabilitati finché non esiste una decisione esplicita e conforme.
- Il prodotto 0.1 **NON DEVE** richiedere rete, account o sincronizzazione; query,
  estratti, contenuto e path del corpus **NON DEVONO** comparire in diagnostica.
- Spotlight sul contenuto, Quick Look persistente e thumbnail fuori dal container
  restano disabilitati finché minimizzazione, cancellazione e consenso non sono
  progettati e verificati.
- SHA-256 di CryptoKit è usato per integrità e content addressing GS-DAT-001; non
  costituisce cifratura né anonimizzazione del contenuto.

Riferimenti: [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox), [Keychain Services](https://developer.apple.com/documentation/security/keychain-services), [CryptoKit](https://developer.apple.com/documentation/cryptokit) e [LocalAuthentication](https://developer.apple.com/documentation/localauthentication).
