# GS-WVR-001 — Integrazione Dependabot con CI bloccata dal budget

| Campo | Valore |
| --- | --- |
| Identificatore | GS-WVR-001 |
| Tipo | Deroga controllata |
| Versione | 1.1.0 |
| Stato | Scaduta il 2026-09-22; rientro in corso, chiusura dopo entrambi i workflow verdi |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | Richiesta dell'iniziatore di risolvere la PR Dependabot #1 |
| Regola interessata | GS-STD-001-20; integrazione soltanto con check remoti verdi |
| Ambito | PR #1, solo pin `actions/checkout` nei due workflow |
| Scadenza | 2026-09-22 o ripristino del budget Actions, se precedente |

## Motivazione

GitHub crea i check `verify` e `app-store-baseline` ma non avvia alcuno step perché
il budget Actions impedisce ulteriore utilizzo. La PR #1 aggiorna esclusivamente
`actions/checkout` da 5.1.0 a 7.0.1 e mantiene il riferimento a SHA completo.

## Rischio e impatto

Il rischio residuo è un'incompatibilità dell'azione sul runner ospitato che il test
locale non può riprodurre. Non cambiano codice prodotto, permessi del token, trigger,
input dell'azione o materiale di firma.

## Alternative considerate

- Attendere il budget: mantiene una dipendenza precedente nonostante
  l'aggiornamento ufficiale disponibile.
- Disabilitare Dependabot o ignorare le major: nasconde aggiornamenti rilevanti.
- Usare un runner self-hosted: introduce una superficie operativa non approvata.
- Usare una toolchain precedente: viola la baseline Xcode 27.

## Mitigazione

- SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` verificato come commit firmato
  della release ufficiale 7.0.1;
- diff limitato ai due riferimenti `uses` e `persist-credentials: false` preservato;
- assenza dei trigger privilegiati `pull_request_target` e `workflow_run`;
- `make verify-app-store` superato sul branch esatto della PR;
- possibilità di revert immediato del singolo squash commit.

## Verifica compensativa

Il 2026-09-15 il branch `dependabot/github_actions/github-actions-7a5a078ad4` ha
superato repository policy, scansione locale dei segreti, documentazione,
architettura, localizzazione, baseline Apple/App Store, test Swift, build Debug e
Release, analisi statica e archivi senza firma macOS/iPadOS.

## Piano di rientro

Alla riattivazione del budget, rieseguire i due workflow sul commit integrato. Se un
job fallisce per l'azione, effettuare revert e riaprire l'aggiornamento con diagnosi.
Se entrambi sono verdi, aggiornare l'evidenza, chiudere l'issue #2 e marcare questa
deroga come chiusa. In assenza di rientro entro la scadenza, l'eccezione diventa non
conformità e deve essere riesaminata prima di ulteriori integrazioni.

## Rientro

Il budget Actions è stato ripristinato dopo la scadenza. Il 2026-10-03 i workflow sono stati
eseguiti sul runner `xcode-27` per la [PR #11](https://github.com/gpicchiarelli/GlifiStudio/pull/11)
(`main` a `4463b7e`, superinsieme dei commit in ambito): `Verifica` verde,
`App Store preflight` ancora in esecuzione al momento della stesura ([GS-VER-141](../evidenze/GS-VER-141-prima-ci-remota-verde.md)).
Le revisioni storiche non sono state rieseguite singolarmente. Il periodo tra la
scadenza e il rientro resta registrato come non conformità in GS-VER-141.

## Riferimenti

- [PR #1](https://github.com/gpicchiarelli/GlifiStudio/pull/1)
- [Issue #2](https://github.com/gpicchiarelli/GlifiStudio/issues/2)
- [Release ufficiale actions/checkout 7.0.1](https://github.com/actions/checkout/releases/tag/v7.0.1)
