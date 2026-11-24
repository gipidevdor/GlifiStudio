<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0019 — Sicurezza, API e conformità verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0019 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-15 |
| Data decisione | 2026-09-15 |
| Approvazione | Richiesta di completare threat model, contratti GlifiKit/CLI e passare dalla specifica alla prova |
| Sostituisce | Nessuno |

## Contesto

Le dieci specifiche di design coprono ormai il sistema, ma sicurezza e interfacce
headless sono ancora distribuite fra più documenti. La tracciabilità collega
requisiti e verifiche pianificate, senza poter rispondere meccanicamente dove una
singola clausola sia implementata e provata. Il rischio corrente non è l'assenza di
altre capacità progettate, bensì confondere una specifica completa con software
dimostrato.

`GlifiKit` è dichiarato pubblico nel codice ma viene compilato e distribuito insieme
alle app. Attivare ora library evolution e promettere compatibilità binaria
cristallizzerebbe una superficie ancora minimale senza beneficio per client esterni.

## Decisione

1. `GS-SEC-001` è l'autorità autonoma per threat model e security architecture:
   asset, trust boundary, input ostili, disponibilità, modelli, log ed export.
2. `GS-API-001` è l'autorità per GlifiKit e GlifiCLI: lifecycle, structured
   concurrency, progressi, cancellazione, failure, identificatori, output e
   compatibilità.
3. GlifiKit resta pre-1.0, source-visible e distribuito insieme alle app. Non si
   promettono ABI/module stability né framework binari finché una nuova ADR non
   approva distribuzione separata e library evolution.
4. GS-DAT definisce quasi formalmente il manifest come commit point e specifica lo
   schema ExportManifest; GS-STD-001-18 definisce le failure semantics trasversali.
5. La matrice di conformità machine-readable diventa gate obbligatorio. Uno stato
   `specificato` o `bloccato` non può essere promosso a `implementato`/`verificato`
   senza i riferimenti richiesti.
6. La Definition of Ready impedisce coding di feature prive di contratto, failure
   semantics, UX/verifica e valutazione di sicurezza/prestazioni applicabile.
7. Il prossimo investimento prevalente è in fixture, oracoli, crash test,
   benchmark e studi UX; nuovi documenti di design richiedono una lacuna autonoma.

## Alternative considerate

- aggiungere una specifica per ogni lacuna: respinto perché duplicherebbe autorità
  esistenti e aumenterebbe il costo di coerenza;
- considerare App Sandbox sufficiente come threat model: respinto perché limita
  l'impatto, ma non valida parser, package, query, log o export;
- dichiarare subito GlifiKit SDK stabile: respinto perché non esistono client
  esterni, contract test completi o una superficie 1.0;
- mantenere la sola matrice Markdown: respinto perché non può verificare percorsi,
  requisiti, prove mancanti e promozioni di stato.

## Conseguenze

La documentazione aggiunge soltanto due nuovi contratti sostanziali e rafforza i
documenti esistenti. Il repository può distinguere automaticamente ciò che è
specificato, implementato, verificato o bloccato. Questo rende più visibili le
lacune reali: corpus italiano, oracoli numerici, parser PDF/OCR, ranking, UX e
hardware non vengono dichiarati completi.

Il costo è mantenere la matrice insieme a ogni modifica pertinente e scrivere
contract test prima di stabilizzare nuove API. La futura distribuzione binaria
richiederà lavoro esplicito su resilience, module interface e compatibilità.

## Verifica

- `make check-compliance` valida schema, ID, path e regole di promozione;
- `make check-docs` valida metadati, ID e integrazione dei nuovi contratti;
- review campionata risponde “clausola → codice/test/fixture/evidenza/gate”;
- kill injection, corpus avversari e contract test restano evidenze obbligatorie
  prima delle promozioni riportate dalla matrice.
