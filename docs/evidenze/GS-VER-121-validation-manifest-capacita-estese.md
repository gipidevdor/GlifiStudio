<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-121 — ValidationManifest delle capacità di GS-DOR-003

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-121 |
| Tipo | Evidenza di validazione |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task S3 di GS-DOR-004 |

## Ambito

RQ-045 richiede un ValidationManifest con livelli V0–V4 di GS-VAL-001 prima che una capacità sia
dichiarata supportata. Le capacità aggiunte da GS-DOR-003 ricevono il proprio manifest, registrato
nel catalogo `Fixtures/Validation/v1/manifest.json`:

| Manifest | Capacità | Metodi | Oracolo V2 |
| --- | --- | --- | --- |
| `validation-term-weighting-bm25-v1` | `corpus-term-weighting-v1`, `corpus-bm25-ranking-v1` | 6 varianti TF, 3 IDF, 3 normalizzazioni, `BM25-v1` | `weighting.R` |
| `validation-lexical-diversity-mtld-v1` | `corpus-lexical-diversity-mtld-v1` | `MTLD-bidirectional-v1` | `diversity.R` |
| `validation-ngram-frequencies-v1` | `corpus-ngram-frequencies-v1` | forme, n-grammi di parole e caratteri, `TermFilter-v1` | `ngrams.R` |
| `validation-keyness-gtest-fisher-ha-ci-bh-v2` | keyness v2 (GS-VER-118) | G-test, Fisher, IC, BH | `keyness.R` e Python |

V0 schema e precondizioni, V1 casi limite, V2 oracolo indipendente, V3 persistenza e parità
Core/Kit/CLI, V4 golden numerico versionato in `Tests/Oracles/expected.txt`; V5 non applicabile con
un solo backend. Lo stato resta `candidate`, come per i manifest del nucleo 0.1.

## Procedura e risultato

`check-fixtures.py` valida schema, licenza, livelli e percorsi dei 12 manifest del catalogo.

## Esito

**Superato localmente: ogni capacità di GS-DOR-003 ha un ValidationManifest completo V0–V4.**
