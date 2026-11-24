<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-076 — Metadati teste indagine in UI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-076 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza operativa dell'iniziatore del progetto |
| Riferimenti | GS-API-001; GS-PROD-001 G3; GS-VER-066; GS-VER-071 |

## Ambito

Esporre i metadati Kit delle teste di ramo Investigation (identità, intento,
lingua, conteggi Finding/eventi, Artifact piano/interpretazione) nella lista
Must, oltre alla sola domanda e all'head event.

## Controlli

1. Ogni testa mostra `id`, `headEventID`, `intent`, `languageCode`.
2. Conteggi `selectedFindingIDs`, `availableFindingIDs`, `eventIDs`.
3. `planArtifactID` e `interpretationArtifactID` visibili e selezionabili.
4. Trait di selezione accessibile sulla testa attiva.
5. Checklist candidatura G3 aggiornata a GS-VER-035…074.
6. `make quality-static` sul tip; `make verify` non eseguibile (Swift assente).

## Risultato

**Superato** per wiring UI e aggiornamento checklist.

## Limiti

Budget Actions: GS-WVR-004. Runtime Xcode/Swift non disponibile in questo
ambiente.
