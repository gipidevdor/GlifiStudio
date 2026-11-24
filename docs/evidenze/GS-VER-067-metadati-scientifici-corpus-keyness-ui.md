<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-067 — Metadati scientifici corpus e keyness in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-067 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-ANA-001; GS-PROD-001 G3; GS-VER-043; GS-VER-044 |

## Ambito

Esporre in UI Must i contratti scientifici e i metadati riproducibili di
`analyzeCorpus` e `compareKeyness`: digest, nodi, determinismo, policy
numeriche, dispersione/frequenze relative e statistiche keyness complete.

## Controlli

1. Corpus: generation/sourceGeneration, analysisNode, digest, contratti,
   matrice, metriche termine (relativa, DF, range, Gries DP), policy diversità.
2. Keyness: analysisNode, digests confronto/target/reference, contratti test,
   frequenze, df, p/q, odds ratio, expected count basso.
3. Chiavi localizzate `it`/`en`; `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
