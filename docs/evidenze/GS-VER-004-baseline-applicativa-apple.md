# GS-VER-004 — Baseline applicativa Apple

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-004 |
| Tipo | Evidenza di verifica |
| Versione | 0.1.0 |
| Stato | Bozza controllata |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |

## Ambito

- Requisiti coperti: RQ-013, RQ-014 e CV-009–CV-012 per la baseline strutturale.
- Verifica coperta: TV-016; predisposizione di TV-017 e TV-018.
- Revisione del software: working tree iniziale, precedente al primo commit.
- Ambiente: Xcode 27.0 (`27A266a`), Swift 6.4, deployment target macOS/iPadOS 27.0.

## Procedura

Esecuzione di `Scripts/verify.sh`, comprendente validazione documentale, localizzazione, architettura e profilo Apple; lint Swift; tre test; smoke test headless; build Debug e Release delle app macOS e iPadOS.

Il controllo Apple analizza privacy manifest, entitlement macOS, capability registrate, impostazioni di build, isolamento dello stato UI e preview adattive.

## Risultato atteso

- privacy manifest valido e incluso in entrambe le app;
- nessun tracking, raccolta dati o required-reason API nella baseline;
- App Sandbox macOS con soli file scelti dall'utente;
- Hardened Runtime macOS attivo in Release;
- stato UI Observation isolato sul Main Actor e cancellazione cooperativa;
- preview italiana, inglese con Dynamic Type e right-to-left;
- build Debug e Release superate sui due target.

## Risultato osservato

Tutti i controlli hanno terminato con codice di uscita zero. Xcode espone App Sandbox attivo in Debug e Release; Hardened Runtime è disattivato in Debug e attivo in Release. Il privacy manifest e gli entitlement risultano plist validi. Tutti i test e le quattro build applicative sono stati superati.

## Limiti

Lo scaffold non dispone ancora di flussi funzionali su cui eseguire test UI, audit Accessibility Inspector, sanitizer, profiling Instruments o prove su dispositivi fisici. Firma, notarizzazione, icone e distribuzione restano bloccate da DA-012 e DA-018.

## Esito

- Esecutore e data: automazione locale di progetto, 2026-09-15.
- Esito: **Superato**.
