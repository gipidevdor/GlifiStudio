<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Runbook App Store unlisted (G5)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-RUN-001 |
| Tipo | Runbook operativo |
| Versione | 1.0.0 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | ADR-0011; GS-PROD-001 G5; Distribution/AppStore |

## Prerequisiti

1. Apple Developer Team e bundle `studio.glifi.GlifiStudio` definitivi (DA-018).
2. G4 superato su dispositivi fisici (a11y, performance, recovery).
3. Metadata `it-IT`/`en-US`, privacy policy e support page pubblicate.
4. Screenshot approvati nelle cartelle `Distribution/AppStore/Screenshots/`.
5. `make verify` e `make verify-app-store` verdi su Xcode 27.

## Sequenza

1. Archiviare macOS e iPadOS firmati; validare con Transporter/altool.
2. Caricare su TestFlight interno, poi esterno sulla matrice dichiarata.
3. Completare App Review Notes e export compliance già dichiarata (non exempt encryption = NO).
4. Inviare ad App Review.
5. Dopo accettazione, richiedere distribuzione **unlisted** (link ≠ autenticazione).
6. Aggiornare `Distribution/AppStore/Configuration/release-readiness.json` e
   registrare GS-VER di release.

## Fuori ambito automatico

Il CI esegue solo preflight (`make verify-app-store`). Firma, Team ID, TestFlight e
approval unlisted richiedono credenziali umane e non sono simulabili dal gate
locale fail-closed.
