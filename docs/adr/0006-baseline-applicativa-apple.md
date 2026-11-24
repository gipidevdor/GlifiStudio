# ADR-0006 — Baseline applicativa Apple

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0006 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Decisione esplicita dell'iniziatore del progetto |
| Fonte | Direzione di prodotto del 2026-09-15 e documentazione Apple |
| Sostituisce | Nessuno |

## Contesto

Le app native richiedono una baseline coerente che impedisca l'introduzione tardiva di accessibilità, privacy, sicurezza, adattabilità e diagnosi. Non tutte le pratiche Apple comportano però una configurazione immediata: aggiungere capability non utilizzate aumenterebbe privilegi e superficie di rischio.

## Decisione

Glifi Studio adotta le pratiche definite nel [profilo Apple](../apple/README.md). La baseline attiva comprende ciclo di vita SwiftUI, Observation sul Main Actor, concorrenza Swift rigorosa, localizzazione, privacy manifest, App Sandbox macOS a privilegio minimo, Hardened Runtime nelle build Release e quality gate condiviso.

Permessi sensibili, rete, persistenza documentale, background execution, servizi cloud e distribuzione vengono configurati soltanto insieme a requisiti e verifiche approvati.

## Conseguenze

- I vincoli di piattaforma vengono verificati automaticamente fin dall'inizio.
- Le app mantengono privilegi minimi e dichiarazioni privacy coerenti con lo scaffold corrente.
- Ogni nuova capability richiede aggiornamento contestuale di requisiti, manifest, entitlement, test e documentazione.
- Alcuni gate restano pianificati finché non esistono flussi UI e dati realistici.

## Verifica

`Scripts/check-apple-baseline.py` verifica configurazioni, manifest, entitlement e struttura dello stato UI. `Scripts/verify.sh` aggiunge lint, test e build Debug/Release delle due app.
