# 14. Sicurezza e privacy

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-14 |
| Tipo | Capitolo normativo |
| Versione | 0.7.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 14.1 Pratiche di sviluppo sicuro

Il progetto applica le quattro aree del NIST SSDF: preparare l'organizzazione, proteggere il software, produrre software ben protetto e rispondere alle vulnerabilità.

## 14.2 Modellazione delle minacce

Il modello normativo di asset, confini di fiducia, minacce, controlli e prove è
[GS-SEC-001](../sicurezza/README.md). La sua revisione è obbligatoria prima di G2,
prima di G4 e quando cambia un parser, un formato, un entitlement, una dipendenza,
la rete, un modello o una destinazione dati.

Prima di G2 devono essere modellate almeno le minacce relative a:

- parser di PDF, Markdown, OCR, archivi e input malformati;
- path traversal, symlink, hard-link, collisioni Unicode/case e accesso a file non autorizzati;
- decompression bomb, dimensioni dichiarate false, nesting, regex DoS ed esaurimento di memoria, CPU o disco;
- corruzione o sostituzione di progetto, indice e cache;
- fuga di contenuto tramite log, crash report o telemetria;
- dipendenze e strumenti di build compromessi;
- file temporanei, Quick Look, thumbnail, backup e Spotlight che rivelano contenuto;
- export che include più dati, fonti o metadati di quanto selezionato;
- modelli ML o risorse esterne non affidabili;
- prompt injection, esfiltrazione tramite tool calling e confusione tra output generato e dati osservati.

## 14.3 Regole minime

- Il sistema **DEVE** applicare minimo privilegio a file, entitlement e processi.
- Dati testuali dell'utente **NON DEVONO** comparire nei log per impostazione predefinita.
- Credenziali e segreti **NON DEVONO** essere registrati nel repository o negli artefatti diagnostici.
- Telemetria contenente dati o metadati dell'utente **NON DEVE** essere attivata senza finalità, minimizzazione, informativa e consenso applicabili.
- File temporanei sensibili **DEVONO** avere permessi restrittivi e ciclo di vita definito.
- Limiti di parsing e allocazione **DEVONO** essere verificati prima dell'uso delle risorse.
- Componenti di package e archivi **DEVONO** essere risolti sotto una radice
  verificata; path assoluti, traversal, link inattesi e collisioni **DEVONO** essere rifiutati.
- Query e regex **DEVONO** avere limiti di dimensione, profondità, complessità,
  tempo e cancellazione; un risultato parziale **NON DEVE** essere marcato completo.
- Vulnerabilità note **DEVONO** essere classificate, tracciate, corrette o derogate prima del rilascio.
- Contenuto dell'utente **NON DEVE** essere inviato a Private Cloud Compute o provider server senza requisito, minimizzazione, informativa e autorizzazione applicabili.
- Tool esposti a modelli generativi **DEVONO** applicare least authority, validazione degli argomenti e conferme per effetti irreversibili.

## 14.4 Modello privacy e protezione dati 0.1

La baseline 0.1 è locale, singolo utente e senza account, rete, sincronizzazione o
telemetria. Nessun contenuto, query, estratto o path del corpus entra in log, crash
report o bundle diagnostico per default. Questa garanzia **DEVE** essere verificata
sul binario di rilascio e riallineata a privacy manifest e dichiarazioni App Store.

Non sono ammessi SDK analytics/crash/session replay, identificatori diagnostici
persistenti, upload automatici o subscriber MetricKit. Le metriche aggregate rese
disponibili da Apple in Xcode Organizer non autorizzano raccolta aggiuntiva da
parte dell'app. [GS-APL-014](../apple/14-osservabilita-e-telemetria-macos.md)
definisce allowlist, gate e condizioni per una futura modifica.

- Fonti, rappresentazioni, Artifact e report sono dati potenzialmente sensibili.
- Cache e thumbnail seguono la vita del progetto e sono eliminabili senza aprirlo.
- Indicizzazione Spotlight del contenuto è fuori dal prodotto 0.1; una futura
  attivazione richiede opt-in, minimizzazione e cancellazione verificabile.
- Quick Look e preview **NON DEVONO** materializzare contenuto fuori dal container
  senza un requisito e un threat model aggiornato.
- Backup di sistema può conservare copie oltre la cancellazione locale: UI e policy
  **DEVONO** evitare promesse di cancellazione sicura che il sistema non può garantire.
- Export richiede selezione esplicita, riepilogo del contenuto e manifest; non
  include automaticamente fonti complete.

## 14.5 Risposta alle vulnerabilità

Ogni segnalazione **DEVE** ricevere identificatore, severità, responsabile, analisi dell'impatto e decisione. Una correzione di sicurezza **DEVE** includere un test di regressione quando riproducibile senza esporre materiale pericoloso.

Le app **DEVONO** applicare il profilo Apple dedicato a [privacy e sicurezza](../apple/04-privacy-e-sicurezza.md).

## 14.6 Repository e collaborazione

- Gli accessi al repository privato **DEVONO** seguire minimo privilegio, identità individuale, autenticazione forte e riesame periodico.
- Issue, pull request, log e artefatti CI **NON DEVONO** contenere documenti reali, dati personali o dettagli sfruttabili non necessari.
- Materiale di firma Apple **NON DEVE** essere disponibile a job di pull request.
- Un controllo locale euristico dei segreti **DEVE** essere affiancato da protezione server-side quando disponibile; nessuno dei due elimina la revisione.
- Una segnalazione di vulnerabilità **DEVE** usare il canale privato definito in [SECURITY.md](../../SECURITY.md).
- Un cambio di visibilità **DEVE** includere scansione dell'intera storia, verifica legale e rotazione preventiva delle credenziali interessate.
