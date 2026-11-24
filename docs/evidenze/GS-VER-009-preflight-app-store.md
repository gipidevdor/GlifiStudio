# GS-VER-009 — Preflight App Store

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-009 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata; submission non autorizzata |

## Ambito

La verifica copre la baseline App Store non in elenco predisposta nel working tree:
identità multipiattaforma, configurazioni Xcode, icone, privacy, metadati, controlli
repository, analisi statica e packaging senza firma di macOS e iPadOS.

## Ambiente e procedura

- macOS su Apple silicon;
- Xcode 27.0 (`27A266a`);
- Swift 6.4;
- comando: `make verify-app-store`;
- audit separato: `make app-store-submission-check`.

## Risultato osservato

Il 2026-09-15 `make verify-app-store` è terminato con stato zero e senza warning.
Sono risultati verdi: 207 file versionabili e policy repository, scansione segreti,
toolchain, configurazione GitHub, naming, 105 documenti allora presenti con 104
identificatori, architettura, localizzazione, baseline Apple, baseline App Store,
formattazione, 3 test Swift, smoke test CLI, build Debug/Release, analisi statica e
archivi senza firma per entrambe le piattaforme.

Il controllo di submission è terminato non-zero come previsto. I blocchi includono
funzionalità minima e flussi `Must` non implementati, identità e firma Apple, URL
privacy/supporto, metadati e screenshot approvati, audit su dispositivi,
accessibilità, TestFlight, informazioni App Review e approvazione `unlisted`.

## Esito e limiti

**Superato** per baseline tecnica e packaging senza firma. **Submission bloccata**:
questa evidenza non copre prodotto completo, archivi firmati, dispositivi fisici,
servizi Apple, revisione umana o approvazione App Review. L'approvazione finale non
è tecnicamente garantibile dal repository.
