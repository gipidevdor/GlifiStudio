# ADR-0011 — Distribuzione App Store non in elenco

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0011 |
| Tipo | Architecture Decision Record |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |

## Contesto

Glifi Studio deve essere distribuito inizialmente per macOS e iPadOS tramite App
Store, senza apparire nella ricerca, nelle classifiche, nelle categorie o nelle
raccomandazioni. L'app deve essere raggiungibile soltanto mediante un collegamento
diretto, pur rispettando integralmente App Review e i requisiti della piattaforma.

## Decisione

Si adotta la distribuzione **App Store non in elenco** (`unlisted`). Glifi Studio:

- usa una singola identità multipiattaforma candidata con bundle identifier
  `studio.glifi.GlifiStudio` e lingua primaria italiana;
- affronta la normale App Review come applicazione completa e pronta alla
  distribuzione;
- richiede lo stato non in elenco soltanto dopo la submission, dichiarando
  l'intento nelle note di revisione;
- usa rilascio manuale per separare approvazione, abilitazione del link e
  comunicazione agli utenti;
- non considera segreto il link: chiunque lo possieda può inoltrarlo e scaricare
  l'app nelle regioni abilitate;
- introduce autenticazione e autorizzazione applicative solo se DA-024 stabilirà
  che il pubblico deve essere realmente ristretto.

La readiness è articolata in cinque stati verificabili: baseline tecnica senza
firma, archivi firmati candidati, submission completa, approvazione della richiesta
non in elenco e rilascio del link. Lo scaffold corrente non supera il gate di
funzionalità minima e non può essere inviato come prodotto finito.

## Conseguenze

Una sola scheda App Store coordina le varianti macOS e iPadOS, mantenendo metadati
e materiali specifici per piattaforma quando necessario. Firma, provisioning,
privacy policy pubblica, pagina di supporto, screenshot reali, test su dispositivi e
informazioni di revisione restano obbligatori. L'approvazione finale appartiene ad
Apple e non può essere garantita dai controlli locali.

## Alternative considerate

- App Store pubblico: respinto per il rilascio iniziale perché rende l'app
  ricercabile.
- Custom App tramite Apple Business Manager o School Manager: non scelto perché
  richiede organizzazioni nominate e un diverso modello di distribuzione.
- Distribuzione diretta notarizzata macOS: non copre iPadOS e aumenta la superficie
  operativa.
- TestFlight permanente: respinto perché è un canale beta, non distribuzione finale.

## Riferimenti

- [Unlisted App Distribution](https://developer.apple.com/support/unlisted-app-distribution)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Add a new app](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app)
