<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-066 — Coordinate query, lineage Evidence e indagine in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-066 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-QRY-001; GS-ANA-001; GS-PROD-001 G3; GS-VER-058; GS-VER-062 |

## Ambito

Esporre spazio delle coordinate e provenienza query, digest/rappresentazione
Evidence, motivo di disposizione, metadati interpretazione e lingua/Findings
disponibili dell'indagine salvata.

## Controlli

1. Query: `projectID`, `coordinateSpace`, `sourceText.byteCount`.
2. Evidence: `descriptorDigest`, `representationIdentifier`,
   `disposition.reasonIdentifier`.
3. Interpretazione: intent, planArtifact/Node, `sourceArtifactIDs`.
4. Indagine: `languageCode`, `availableFindingIDs`.
5. `insufficientEvidence.messageArguments` quando presenti.
6. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI.

## Limiti

Budget Actions: GS-WVR-004.
