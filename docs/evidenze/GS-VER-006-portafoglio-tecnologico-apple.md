# GS-VER-006 — Portafoglio tecnologico Apple

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-006 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Ambito

- Decisione coperta: ADR-0008.
- Profili coperti: GS-APL-009–GS-APL-013 e aggiornamenti a GS-APL-002, GS-APL-004, GS-APL-006 e GS-APL-007.
- Requisiti coperti: RQ-015–RQ-019 e CV-013–CV-016 a livello documentale e strutturale.
- Ambiente: Xcode 27.0 (`27A266a`), Swift 6.4, deployment target macOS/iPadOS 27.0.

## Procedura

Revisione del portafoglio rispetto alla documentazione Apple corrente e assegnazione di ogni tecnologia pertinente a ruolo, stato, gate di attivazione, fallback ed evidenza richiesta. Esecuzione successiva di `Scripts/verify.sh`.

Il gate Apple verifica la presenza del profilo completo e l'assegnazione di Uniform Type Identifiers, PDFKit, Vision, Natural Language, Foundation Models, Accelerate, Core ML, Metal Performance Shaders, SwiftData, Core Spotlight, App Intents, Core Transferable, BackgroundTasks, Logger e OSSignposter.

## Risultato atteso

- portafoglio Apple suddiviso per argomento e collegato ad ADR-0008;
- scala Swift/CPU → Accelerate → Core ML → Metal/MPS con benchmark e fallback;
- Foundation Models separato dai risultati deterministici e disponibile solo con fallback;
- nessuna nuova capability o entitlement introdotta in assenza di una funzione;
- documentazione, test Swift, CLI e build Debug/Release macOS/iPadOS superati.

## Risultato osservato

`Scripts/verify.sh` ha terminato con codice di uscita zero. Il gate tecnologico Apple, la documentazione, i controlli di architettura/localizzazione/naming, i tre test Swift, lo smoke test CLI e le quattro build Xcode sono stati superati. Privacy manifest, sandbox ed entitlement sono rimasti sulla baseline di minimo privilegio.

## Limiti

Questa evidenza approva la strategia e la completezza del portafoglio, non dichiara implementati i framework pianificati. Benchmark CPU/GPU/Neural Engine, qualità Natural Language/Vision/Foundation Models, storage e integrazioni di sistema richiedono ancora prototipi, dataset e dispositivi reali definiti in TV-019–TV-021.

## Esito

- Esecutore e data: automazione locale di progetto, 2026-09-15.
- Esito: **Superato**.
