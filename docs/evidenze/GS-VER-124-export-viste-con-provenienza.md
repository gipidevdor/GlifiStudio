<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-124 — Export delle viste con manifest di provenienza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-124 |
| Tipo | Evidenza di export e provenienza |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task L4 di GS-DOR-005 |

## Ambito

GS-VIZ-001 § Export chiede per l'export macchina i dati visualizzati in CSV/JSON, la
VisualizationSpec e un manifest, e considera incompleta un'immagine senza provenienza. Una vista
si esporta ora come cartella con tre file:

- `view.csv`: tabella equivalente RFC 4180 (GS-VER-114);
- `view-spec.json`: `GlifiStudioVisualization` completa;
- `visual-export-manifest.json` (`studio.glifi.visual-export-manifest` v1): data di creazione UTC
  esclusa dall'identità, build del motore, progetto e generazione, Artifact, nodo, analisi,
  metodo, specifica, osservazioni totali e visibili, riduzione, layout, cautele e inventario dei
  file con dimensione e SHA-256.

`GlifiStudioVisualExport.bundle` è deterministica a parità di data; `verify` controlla schema,
insieme esatto dei file, dimensioni e digest. `GlifiStudioProjectSession.exportVisualization`
rifiuta un Artifact che non appartiene più alla generazione corrente (`staleArtifact`) e una
destinazione esistente, scrive in una cartella di staging accanto alla destinazione, la sposta in
un passo e rimuove lo staging in caso d'errore. L'app offre «Esporta con provenienza».

## Procedura e risultato

`visualizationExportCarriesVerifiableProvenance`:

1. due costruzioni con la stessa data sono identiche byte per byte;
2. il manifest riporta Artifact e generazione della vista e la data RFC 3339 attesa; la
   specifica riletta dal JSON coincide con la vista;
3. un CSV manomesso fa fallire la verifica con `visual-export.integrity-failed`;
4. la cartella scritta supera la verifica e non lascia staging; una seconda scrittura sulla stessa
   destinazione è rifiutata;
5. dopo una nuova importazione l'export fallisce con `visual-export.stale-artifact`.

## Limiti

Export PDF/PNG delle viste e inclusione delle viste nel pacchetto scientifico dell'indagine non sono
implementati; il salvataggio dall'app usa il pannello di sistema e non è verificato su dispositivo.

## Esito

**Superato localmente: le viste si esportano con dati, specifica e manifest di provenienza
verificabile.**
