# Preparazione App Store

| Campo | Valore |
| --- | --- |
| Identificatore | GS-AS-IDX-001 |
| Tipo | Indice del piano App Store |
| Versione | 1.2.0 |
| Stato | Attivo |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0011 |

## Scopo

Questo profilo governa la preparazione, la verifica e il rilascio di Glifi Studio
come app App Store non in elenco. Non promette l'approvazione di Apple: rende
espliciti requisiti, responsabilità, prove e blocchi prima della submission.

La readiness dell'esperienza è valutata contro [GS-UX-001](../esperienza-utente/README.md):
uno scaffold compilabile o un insieme di schermate non costituiscono funzionalità
minima, comprensione, accessibilità o valore autonomo.

Perimetro e completezza sono valutati contro
[GS-PROD-001](../specifiche-di-design/10-product-baseline-mvp.md); una capacità
scientifica è pubblicabile soltanto con il ValidationManifest richiesto da
GS-VAL-001.

## Information item

1. [Distribuzione non in elenco](01-distribuzione-unlisted.md)
2. [Identità e record applicativo](02-identita-e-record-app.md)
3. [Metadati e materiali](03-metadati-e-materiali.md)
4. [Privacy e conformità](04-privacy-e-conformita.md)
5. [Accessibilità](05-accessibilita.md)
6. [Strategia TestFlight](06-strategia-testflight.md)
7. [Matrice di qualità e dispositivi](07-matrice-qualita-e-dispositivi.md)
8. [Preparazione di App Review](08-app-review.md)
9. [Rilascio e monitoraggio](09-rilascio-e-monitoraggio.md)
10. [Gate di submission](10-gate-di-submission.md)
11. [Runbook unlisted G5](runbook-unlisted-g5.md)

I dati operativi versionati sono in [`Distribution/AppStore`](../../Distribution/AppStore/README.md).
