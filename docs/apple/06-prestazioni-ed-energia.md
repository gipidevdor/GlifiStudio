# Prestazioni ed energia

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-006 |
| Tipo | Standard applicativo Apple |
| Versione | 0.5.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0006 |

## Regole

- Parsing, I/O e analisi non banali **NON DEVONO** bloccare il Main Actor.
- Task lunghi **DEVONO** avere ownership, priorità, avanzamento, cancellazione e backpressure espliciti.
- L'app inattiva **NON DOVREBBE** consumare CPU in modo persistente.
- Memoria, latenza, I/O ed energia **DEVONO** essere misurati su dispositivo oltre che nel simulatore.
- SwiftUI view update, hitch, hang, allocazioni e picchi di memoria **DEVONO** essere profilati sui flussi critici.
- Ottimizzazioni, uso di Accelerate o Metal **DEVONO** partire da una baseline corretta e misurata end-to-end.
- Core ML **DEVE** essere profilato sulle unità di calcolo ammesse, includendo warm-up, memoria, energia e qualità del risultato.
- La disponibilità di memoria unificata **NON DEVE** giustificare copie, residency o buffer illimitati.
- Stato termico, pressione di memoria e priorità del lavoro **DEVONO** produrre riduzione controllata, checkpoint o cancellazione quando necessario.
- Lavoro in background **DEVE** usare le API di sistema appropriate e rispettare sospensione e limiti della piattaforma.
- Profilo, evidenze e findings validi **DOVREBBERO** apparire progressivamente; la
  persona deve poter esplorare contenuto già pronto o svolgere altro lavoro.
- Il planner **DEVE** considerare costo, memoria, energia e stato termico senza
  cambiare silenziosamente il significato del piano; rinvii e fallback sono
  spiegabili.
- Su macOS, admission e parallelismo **DEVONO** applicare la decision table
  [GS-APL-015](15-sostenibilita-di-sistema-macos.md), preservando App Nap e idle.

Gli strumenti di riferimento sono Instruments, Organizer e i checker di Xcode. La strategia dei backend è definita in [Calcolo accelerato su Apple silicon](11-calcolo-accelerato-apple-silicon.md). Riferimento: [Testing and performance](https://developer.apple.com/documentation/technologyoverviews/testing-and-performance).

Task tree, code bounded, pressure response, classi S/M/L/XL e budget quantitativi
sono governati da [GS-RUN-001](../specifiche-di-design/06-runtime-e-risorse.md).
