# GS-VER-011 — Aggiornamento Dependabot di actions/checkout

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-011 |
| Tipo | Evidenza di verifica della supply chain |
| Versione | 1.0.0 |
| Stato | Superato con deroga temporanea CI |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Integrazione richiesta dall'iniziatore del progetto; GS-WVR-001 |

## Ambito

Revisione e integrazione della PR Dependabot
[#1](https://github.com/gpicchiarelli/GlifiStudio/pull/1), aggiornamento
`actions/checkout` dalla release 5.1.0 alla 7.0.1 nei workflow `verify` e
`app-store-baseline`.

## Controlli

- diff remoto limitato a due righe `uses`;
- SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` presente in entrambi i workflow;
- commit della release verificato come firmato tramite GitHub API;
- `persist-credentials: false`, permessi in lettura e trigger non privilegiati
  preservati;
- `Scripts/check-repository.py` accetta soltanto SHA completi;
- `make verify-app-store` superato sul branch esatto della PR;
- squash merge `5fb96c17ef411fad4b49d8fea2817f1f1f721aa4` completato e branch remoto rimosso.

## Esito

**Superato con GS-WVR-001.** L'aggiornamento ufficiale firmato è integrato e la PR
Dependabot è chiusa. I check remoti non hanno eseguito step per il budget Actions,
condizione indipendente dalla modifica e ancora tracciata nell'issue #2. La deroga
scade il 2026-09-22 e richiede il rientro descritto nel relativo documento.

## Riferimenti

- [GS-WVR-001](../deroghe/GS-WVR-001-integrazione-dependabot-budget-ci.md)
- [Release actions/checkout 7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1)
- [Issue #2 — Budget Actions](https://github.com/gpicchiarelli/GlifiStudio/issues/2)
