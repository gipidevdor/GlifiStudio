# Pacchetto App Store

Questa cartella contiene la sorgente versionata delle informazioni necessarie a
preparare Glifi Studio per App Store Connect. I file JSON sono intenzionalmente
separati dai documenti normativi in `docs/app-store`: rappresentano dati operativi
validabili e non sostituiscono App Store Connect.

## Regole

- `Configuration/` contiene identità, dichiarazioni e stato dei gate.
- `Metadata/` contiene una scheda per lingua; `it-IT` è la lingua primaria.
- `Review/` contiene le informazioni riservate ad App Review e la richiesta
  `unlisted`; non inserirvi credenziali reali.
- `Screenshots/` accetta soltanto acquisizioni di build reali.
- `TestFlight/` conserva la strategia e, in futuro, riferimenti alle evidenze.

`make check-app-store` verifica la baseline. `make app-store-submission-check` è
deliberatamente più severo e deve rimanere rosso finché ogni requisito umano,
commerciale e di prodotto non è soddisfatto.
