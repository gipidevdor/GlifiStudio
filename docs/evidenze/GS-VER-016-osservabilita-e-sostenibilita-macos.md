<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-016 — Osservabilità e sostenibilità macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-016 |
| Tipo | Evidenza di verifica tecnica e documentale |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata di ADR-0017 e ADR-0018 |

## Ambito

- policy di assenza di telemetria applicativa e upload diagnostici nella 0.1;
- facciata Unified Logging e signpost privacy-safe;
- decision table macOS per Low Power Mode, termica, memoria e lifecycle;
- integrazione in standard, requisiti RQ-049–RQ-056 e verifiche TV-062–TV-069;
- regressione del workspace e del packaging App Store senza firma.

## Procedura

1. verificare privacy manifest, entitlement e assenza di rete, MetricKit e SDK di
   telemetria nelle superfici di dipendenza e nei sorgenti;
2. verificare che soltanto `GlifiDiagnostics` istanzi Logger/OSSignposter e che app
   e librerie non usino `print`;
3. eseguire i test della policy, inclusa l'intera combinazione di intenti, Low Power
   Mode, stati termici, memory pressure e attività dell'app;
4. verificare che il wrapper signpost preservi il risultato per ogni fase allowlist;
5. eseguire `make verify` e `make verify-app-store`;
6. riesaminare diff, tracciabilità e limiti dell'evidenza.

## Risultato osservato

- 175 file documentali e 174 identificatori univoci sono validi e tutti i link
  locali si risolvono;
- il gate Apple riconosce 15 documenti di profilo, il privacy manifest vuoto e gli
  entitlement minimi; impone una allowlist esterna vuota e respinge package remoti,
  framework collegati, gestori di dipendenze, logging laterale, `print`, rete e
  MetricKit;
- `GlifiTelemetryPolicy` disabilita telemetria remota/di terzi, export automatico e
  contenuto del corpus nella diagnostica;
- `GlifiRuntimePolicy` limita il parallelismo a otto e produce decisioni
  deterministiche/bounded sull'intera matrice di condizioni; pressione critica e
  app inattiva applicano protezione, checkpoint o sospensione;
- i test Swift del core e di GlifiKit risultano superati;
- `make verify` è terminato con esito positivo, incluse build Debug/Release macOS e
  iPadOS senza firma;
- `make verify-app-store` è terminato con esito positivo, incluse analisi statica e
  archiviazione macOS/iPadOS senza firma.

## Copertura e limiti

TV-062, TV-064 e TV-065 sono coperte per la baseline statica e unitaria. TV-063 è
coperta per struttura/allowlist, non ancora con un corpus canary in un flusso reale.
TV-066–TV-068 richiedono il primo flusso lungo, adattatore eventi, build Release,
hardware, Instruments, App Nap e un campione Organizer sufficiente. TV-069 conferma
che l'export diagnostico è assente nella 0.1; non valida una funzione futura.

Questa evidenza non misura energia, wakeup, memoria o I/O reali e non dimostra un
comportamento sotto pressione del processo applicativo. Non copre firma, notarizzazione,
submission o App Review. La CI remota resta soggetta al blocco budget registrato in
GS-WVR-003 e non costituisce evidenza positiva.

## Esito

**Superato localmente per policy, controlli, unit test, build e packaging senza
firma.** Le prove event-driven e su hardware restano fail-closed prima del primo
flusso lungo e della release candidate.
