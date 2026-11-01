<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Operatori analitici delle famiglie KH Coder

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-160 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Richiesta esplicita confermata: tutte le funzioni analitiche, native, corrette e ottimizzate |
| Riferimenti | RF-087; RQ-063; GS-MET-001-23; ADR-0032 |

| Voce | Contratto |
| --- | --- |
| outcome e confini | Colmare le famiglie assenti dal confronto con il manuale ufficiale KH Coder |
| Confini | Libreria Core/Kit in memoria; preservare lavoro applicativo e cache delle altre chat |
| API | Matrici e documenti immutabili, identità/ordine conservati, risultati con diagnostica |
| failure semantics | Tassonomia GlifiFailure, niente risultati parziali completi, overflow e limiti fail-closed |
| UX | Nessuna nuova UI stabile: API candidate, calcolo fuori dall'actor chiamante |
| Verifica | Oracoli R, integrazione probabilistica esatta, metamorfismi, casi degeneri e input ostili |
| Sicurezza | Nessuna rete, telemetria, dipendenza o formato persistente nuovo |
| Prestazioni | Dati sparsi, LAPACK/vDSP Apple, benchmark Release prima/dopo; non cambiare formule |
| Decisioni | Contratti e stato candidate in GS-MET-001-23 e ADR-0032 |
| tracciabilità | TV-087, CMP-160, GS-VER-160, requisito e CHANGELOG nello stesso cambiamento |

## Stato DoR

**Ready** per l'ambito di libreria e le verifiche dichiarate.

## Revisione numerica autorizzata

La prosecuzione dell'iniziatore include confronto con formule primarie e oracoli,
correzione delle divergenze e registrazione di stati per variante secondo ADR-0031.
La review automatica è attribuita a Codex; nessuna approvazione umana è simulata.
