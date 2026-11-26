<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Cancellazione degli export delle viste

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-320 |
| Tipo | Correzione delimitata del lifecycle |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di massima correttezza dei comportamenti |
| Riferimenti | RQ-011; RQ-058; RQ-060; RQ-061; GS-API-001 § 7; GS-API-003; GS-STD-001-18; GS-VER-320 |

## Definition of Ready

L'export scientifico osserva la cancellazione fino al commit (GS-VER-317),
mentre `GlifiStudioProjectSession.exportVisualization` può ancora pubblicare
una vista dopo una cancellazione successiva all'admission.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Interrompere l'export delle viste prima del rename, conservando progetto e file utente; soli writer Kit e test correlati |
| Compatibilità | Stesse API pubbliche, manifest v1, CSV e receipt; nessuna dipendenza, privilegio, persistenza o migrazione nuova |
| failure semantics e commit | Rename staging→destinazione come commit point; cancellazione precedente: `operation.cancelled`, `cancelled`, `export`, `newRequest`, `unchanged`; staging rimosso, destinazione assente; dopo rename conservare successo e receipt |
| Verifica | RED su API nativa e trasporto project-command con cancellazione deterministica dopo admission; checkpoint interni durante scrittura e prima/dopo commit; cleanup, file preesistenti, integrità e parità degli output |
| Sistema | Check cooperativi fra payload e prima del commit; nessuna garanzia di interruzione dentro una chiamata Foundation sincrona |
| tracciabilità | GS-VER-320; registri e gate integrato macOS coordinati dall'agente principale |

**Ready** prima delle modifiche implementative. L'eventuale osservatore di
checkpoint è interno, sincrono, Sendable e non throwing; serve a rendere
deterministica la cancellazione nel writer reale e non modifica il contratto
pubblico. Nessun controllo di cancellazione viene aggiunto dopo il commit.
