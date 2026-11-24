# ADR-0001 — Piattaforme native iniziali: macOS e iPadOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0001 |
| Versione | 1.0.1 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Appunti iniziali e decisione successiva sul target iPadOS |
| Sostituisce | Bozza proposta di GS-ADR-0001 limitata a macOS |

## Contesto

Glifi Studio richiede elaborazione locale efficiente di grandi collezioni testuali, integrazione documentale e accesso alle capacità dell'hardware Apple contemporaneo. Gli appunti iniziali indicavano macOS come primo target; la decisione di progetto estende il perimetro iniziale anche a iPadOS.

Il motore deve poter essere condiviso senza trascinare dipendenze specifiche dell'interfaccia di una singola piattaforma.

## Decisione

Le piattaforme iniziali di Glifi Studio sono **macOS e iPadOS**.

Swift è il linguaggio principale. SwiftUI è la tecnologia preferenziale per le interfacce condivisibili. AppKit e UIKit possono essere usati soltanto nei target o adattatori specifici rispettivamente di macOS e iPadOS.

GlifiKit e GlifiCore devono rimanere indipendenti da SwiftUI, AppKit e UIKit. Foundation, Natural Language, PDFKit, Vision, Accelerate, Core ML e Metal vengono valutati per ciascuna piattaforma dietro contratti appropriati.

La decisione non stabilisce ancora versioni minime dei sistemi operativi, modelli di iPad supportati, parità completa delle funzioni o sincronizzazione tra dispositivi.

## Alternative considerate

- solo macOS nella fase iniziale;
- macOS iniziale con iPadOS in una fase successiva;
- macOS e iPadOS come target iniziali;
- architettura multipiattaforma comprendente sistemi non Apple.

È accettata la terza alternativa. La quarta non appartiene al perimetro attuale.

## Conseguenze positive

- Il modello condiviso viene progettato sin dall'inizio senza dipendenze da AppKit.
- Il prodotto può servire flussi desktop e tablet mantenendo un solo motore computazionale.
- Framework, formati di progetto e API vengono valutati su entrambe le piattaforme prima di stabilizzarsi.

## Conseguenze negative e rischi

- Aumentano il perimetro di UX, test, prestazioni e compatibilità.
- iPadOS impone vincoli differenti per memoria, ciclo di vita, filesystem e attività in background.
- Componenti AppKit o UIKit specifici richiedono adattatori e test separati.
- La parità funzionale non può essere presunta e deve essere definita per rilascio.

## Verifica della decisione

- I manifest e i target di build includono entrambe le piattaforme approvate.
- GlifiCore compila senza importare SwiftUI, AppKit o UIKit.
- I flussi `Must` del rilascio superano test di sistema su macOS e iPadOS.
- La matrice di compatibilità identifica versioni OS e hardware verificati.
