<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-049 — Salto Evidence→fonte e ValidationManifest Investigation

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-049 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-PROD-001 G3; GS-ANA-001; GS-DAT-001; GS-VER-031; GS-VER-039 |

## Ambito

Chiudere il salto Evidence→fonte nella UI Must, esporre lineage Artifact
dell'indagine e aggiungere il settimo ValidationManifest Must
(`investigation-history-v1`).

## Controlli

1. `openEvidenceSource` carica `sourceText` e ranges dalla prima
   `sourceReference`; evidenziazione in dettaglio Finding.
2. Disposition Evidence localizzata; Artifact piano/interpretazione in UI.
3. `Fixtures/Validation/v1/investigation-history-v1.json` V0–V4 `pass`; catalogo a
   7 manifest; `check-fixtures.py` aggiornato.
4. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI e contratto ValidationManifest.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode e VoiceOver dispositivo aperti.
