<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-017 — Sicurezza, API e conformità verificabile

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-017 |
| Tipo | Evidenza di verifica documentale e strutturale |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata di ADR-0019 e TV-075 |

## Ambito

- completezza e integrazione di GS-SEC-001 e GS-API-001;
- failure semantics trasversali, crash consistency ed ExportManifest v1;
- matrice di conformità machine-readable e Definition of Ready;
- coerenza fra requisiti RQ-057–RQ-063, TV-070–TV-076, architettura e ADR-0019;
- regressione della baseline macOS/iPadOS e App Store senza firma.

## Procedura

1. validare metadati, identificatori, link e marcatori documentali;
2. validare schema, requisiti, path e regole di promozione della matrice;
3. eseguire l'intero `make verify` in una directory di build temporanea;
4. eseguire il preflight `make verify-app-store` senza firma;
5. riesaminare gli stati bloccati e impedire che siano descritti come prove.

## Risultato osservato

- `check-docs` ha validato 179 file, 178 identificatori univoci, link locali,
  22 specifiche scientifiche, 14 UX, 10 di design e i due contratti trasversali;
- `check-compliance` ha validato 21 clausole, requisiti, path e regole di
  promozione; dopo questa evidenza gli stati sono 5 `verified`, 5 `specified` e 11
  `blocked`, senza clausole presentate come implementate ma non provate;
- `check-fixtures` ha verificato byte e offset di 8 casi italiani, ricalcolato 4
  riferimenti numerici entro `1e-12` e validato 10 descrittori avversari bounded;
- il gate ha conservato sui manifest lo stato seed/non-gold e non li ha promossi a
  corpus o baseline approvati;
- `make verify` è terminato con esito positivo, inclusi controlli repository,
  segreti, toolchain, GitHub, naming, architettura, localizzazione, Apple/App Store,
  formatting Swift, 11 test e build Debug/Release macOS/iPadOS senza firma;
- `make verify-app-store` è terminato con esito positivo, incluse analisi statica e
  archiviazione unsigned di entrambe le app.

## Copertura e limiti

Questa evidenza prova soltanto struttura, coerenza, seed e regressione dello
scaffold corrente. Non prova parser ostili, package writer, kill recovery,
codec ExportManifest, operazioni API/CLI non implementate, corpus gold, oracoli
numerici, ranking, studi UX, benchmark hardware, firma o App Review.

Gli 8 casi italiani non includono lemma/POS/NER, split bloccati o soglie backend. I
4 riferimenti numerici non coprono tutte le varianti GS-MET e il ricalcolo Python
non sostituisce un oracolo esterno revisionato. I 10 casi avversari sono descrittori
safe-by-construction, non file PDF/OCR, fuzz corpus o decompression bomb reali.

## Esito

**Superato localmente per contratti, matrice, seed e regressione senza firma.** Le
11 righe `blocked` restano fail-closed fino alle evidenze concrete dichiarate.
