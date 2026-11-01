<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Fixture di test

Questa cartella è riservata a input minimi, deterministici, sintetici o redistribuibili necessari ai test.

Ogni fixture deve avere provenienza, licenza, scopo, formato e risultato atteso documentati accanto al file o in un manifesto. I nomi non devono rivelare identità reali. File grandi, corpus completi, documenti degli utenti, segreti e dati personali sono vietati.

Le fixture ostili devono essere innocue fuori dal test, chiaramente identificate e accompagnate da limiti di risorse. Le fixture generate dovrebbero essere prodotte da uno script deterministico quando questo riduce il rischio legale o la dimensione del repository.

## Catalogo iniziale

[`manifest.json`](manifest.json) registra cinque collezioni seed:

- `Linguistics/it-v1`: otto casi sintetici con offset UTF-8 half-open per
  apostrofi, clitici, abbreviazioni, NFC/NFD, numeri, emoji ed email;
- `Scientific/v1`: sei casi V1 per χ²/Cramér's V, cosine, PMI/NPMI, TF-IDF
  smoothed, profilo corpus italiano e keyness G-test/effect/BH, ricalcolati dal
  gate senza dipendere dal codice prodotto;
- `Adversarial/v1`: dieci descrittori innocui collegati a THR-003–THR-016, senza
  materializzare exploit, archivi espansivi o dati sensibili.
- `Query/v1`: casi sintetici italiani per termini normalizzati, frasi, booleani,
  prossimità, regex sicure, diagnostica e offset UTF-8 attesi.
- `Markdown/v1`: documento sintetico con testo estratto e intervalli sorgente
  attesi per markup inline e entità.

Lo stato `seed` è intenzionale: questi casi non costituiscono ancora corpus gold,
oracolo indipendente approvato, fuzz corpus o baseline di rilascio. La promozione
richiede review, digest, split/soglie e implementazioni sotto test secondo GS-VAL.

## Trasporto degli operatori testuali

[TextAnalysis/v1](TextAnalysis/v1/cases.json) contiene 15 casi sintetici condivisi
fra GlifiKit e CLI. Il gate `check-text-analysis-cli.py` confronta l'intero
risultato e i golden minimi, con tolleranza 1e-12 assoluta e relativa.
