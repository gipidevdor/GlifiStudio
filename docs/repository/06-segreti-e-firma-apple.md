# Segreti e firma Apple

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REP-006 |
| Tipo | Politica operativa |
| Versione | 1.0.0 |
| Stato | Divieto attivo; provisioning rinviato |
| Responsabile | Responsabile sicurezza e titolare Apple Developer, da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Baseline operativa richiesta dal promotore |

## Stato iniziale

La baseline compila con `CODE_SIGNING_ALLOWED=NO`. Non sono noti Apple Developer Team, bundle identifier definitivi, certificati, profili, issuer o chiavi App Store Connect; nessuno di questi valori viene inventato o archiviato nel repository.

## Divieti

File `.p8`, `.p12`, `.pem`, `.key`, `.cer`, `.mobileprovision`, password, token e contenuti di keychain non devono essere versionati, allegati a issue o stampati nei log. Le variabili di ambiente locali sensibili non devono essere salvate in file tracciati.

## Modello futuro

Quando DA-018 sarà chiusa, la firma automatica dovrà usare un ambiente GitHub protetto, approvazione esplicita, segreti con ambito minimo e credenziali ruotabili. Certificati e profili avranno inventario, titolare, scadenza, procedura di revoca e prova di recupero.

Preferire autenticazione App Store Connect con chiave dedicata al progetto e privilegi minimi rispetto a credenziali personali. Importare materiale di firma in un keychain temporaneo del job, eliminarlo sempre e impedire che output o artefatti lo contengano.

## Separazione

CI non firmata, creazione del candidato, firma/notarizzazione e pubblicazione sono fasi distinte. Un job proveniente da pull request non deve accedere ad ambienti o segreti di rilascio. Gli artefatti passano fra fasi con identità e hash verificabili; la pubblicazione richiede revisione e checklist di rilascio.
