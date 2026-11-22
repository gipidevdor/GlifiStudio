<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-036 — ValidationManifest del nucleo analitico Must

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-036 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-VAL-001; GS-PROD-001; DA-008; DA-025 |

## Ambito

Introdurre corpus gold token V0 e ValidationManifest machine-readable V0–V4 per
`corpus-profile-it-v1` e `keyness-gtest-ha-bh-v1`.

## Controlli

1. `Fixtures/Linguistics/it-gold-v0/` con `reviewStatus: gold-v0-token` e split
   validation/test disgiunti.
2. `Fixtures/Validation/v1/*.json` con livelli V0–V4 allo stato `pass`.
3. `Scripts/check-fixtures.py` valida catalogo, offset gold e manifesto.
4. CMP-016 e CMP-017 aggiornati a `implemented`.

## Risultato

**Superato** per il nucleo descrittivo/keyness candidate. Lemma/POS/NER, dataset
esterni e SupportPolicy empirica restano aperti.

## Limiti

- Status capability = `candidate`, non ancora `supported`.
- Non chiude DA-029 né studi UX.
