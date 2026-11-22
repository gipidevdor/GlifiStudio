# Test e diagnostica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-007 |
| Tipo | Standard applicativo Apple |
| Versione | 0.5.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0006 |

## Strategia

- Swift Testing **DEVE** coprire dominio e API Swift; XCTest **DEVE** coprire interazioni UI e metriche che lo richiedono.
- I modelli di presentazione **DEVONO** essere testabili senza avviare l'intera app.
- I flussi principali **DEVONO** essere provati su macOS e su simulatori/dispositivi iPad rappresentativi.
- Test UI **DEVONO** coprire italiano, inglese, testo lungo, tastiera e almeno un audit di accessibilità.
- Test UI **DEVONO** coprire primo percorso, profilo progressivo, sintesi,
  confronto, lineage, dati insufficienti, storia e ripristino definiti da GS-UX.
- Studi di usabilità e comprensione **DEVONO** usare compiti, campione, soglie e
  build identificati e registrare anche errori e sovrainterpretazioni.
- Address Sanitizer e Thread Sanitizer **DEVONO** essere eseguiti periodicamente in configurazioni separate compatibili.
- Main Thread Checker e Thread Performance Checker **DEVONO** rimanere attivi durante lo sviluppo, salvo profiling controllato.
- Crash e hang riproducibili **DEVONO** ricevere test di regressione quando possibile.
- I test prestazionali **DEVONO** usare Release, condizioni dichiarate e baseline versionate.
- `Logger` **DEVE** usare subsystem e categorie stabili, livelli coerenti e privacy esplicita per ogni valore interpolato.
- `OSSignposter` **DEVE** delimitare almeno importazione, estrazione, tokenizzazione, indicizzazione, query e inferenza quando tali fasi esistono.
- Log e signpost **NON DEVONO** contenere testo dei documenti, prompt, path personali o identificatori sensibili per impostazione predefinita.
- Instruments **DEVE** verificare Time Profiler, Allocations, SwiftUI, I/O, energia e Metal/Core ML quando il flusso usa tali tecnologie.
- Xcode Organizer **DEVE** essere il canale primario per le metriche aggregate di
  campo. La 0.1 **NON DEVE** sottoscrivere MetricKit o caricare diagnostica,
  secondo [GS-APL-014](14-osservabilita-e-telemetria-macos.md).
- Logger e signpost tecnici **NON DEVONO** diventare la cronologia visibile
  dell'indagine; i due flussi hanno scopo e retention differenti.
- Le capacità scientifiche **DEVONO** seguire i livelli V0–V6 e i
  ValidationManifest di GS-VAL-001; XCTest o snapshot isolati non costituiscono
  oracolo scientifico.
- Package, migrazioni e query **DEVONO** aggiungere kill injection e fuzzing
  bounded oltre ai test nominali.

Il protocollo completo è [GS-VAL-001](../specifiche-di-design/09-validazione-scientifica.md).
Riferimenti: [Testing and performance](https://developer.apple.com/documentation/technologyoverviews/testing-and-performance), [diagnosing issues early](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early), [performance tests](https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests), [Logging](https://developer.apple.com/documentation/os/logging) e [OSSignposter](https://developer.apple.com/documentation/os/ossignposter).
