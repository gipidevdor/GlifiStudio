<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-046 — Progresso percorso Must, n-grammi e lineage export in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-046 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-16 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-PROD-001 G3; GS-UX-001-15; GS-VER-037 |

## Ambito

Mostrare l'avanzamento del percorso Must in Overview, gli n-grammi e l'Artifact
del profilo corpus, la revisione report in export, e rafforzare le etichette
accessibili delle nuove azioni analitiche.

## Controlli

1. Overview: sei passi Must con stato sì/no e `accessibilityValue`.
2. Fonti: ArtifactID, sezione n-grammi, `accessibilityLabel` su analizza corpus.
3. Indagine: `accessibilityLabel` su confronta keyness.
4. Export: `reportRevisionID` nel receipt.
5. Checklist G4 aggiornata per i nuovi controlli.
6. `make quality-static` sul tip.

## Risultato

**Superato** per wiring UI/a11y strutturale. Prove VoiceOver su dispositivo
restano aperte.

## Limiti

Budget Actions: GS-WVR-004. G4 non chiuso.
