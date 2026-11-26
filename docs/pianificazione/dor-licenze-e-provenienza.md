<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Licenze e provenienza degli algoritmi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-318 |
| Tipo | Revisione di provenienza e attribuzioni |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Glifi Studio contributors |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di controllo licenze e fonti algoritmiche |
| Riferimenti | GS-LIC-001; GS-STD-001-13; RQ-062; RQ-063; GS-VER-318; GS-VER-319; GS-VER-321 |

## Definition of Ready: problema e risultato verificabile

La baseline ha soltanto la licenza generale BSD: mancano inventario controllato,
avvisi Snowball/SplitMix e distinzione tra annotazioni proprie e trascrizione
Wikisource. I nuclei numerici citano Numerical Recipes e Acklam senza prova
primaria conservata di redistribuzione. Un audit puramente per dipendenze SwiftPM
non rileva questi materiali.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Inventario con relazione fonte/materiale, avvisi completi, attribuzione della fixture e registro delle incertezze; implementazioni sostitutive in GS-DOR-319, distribuzione e gate in GS-DOR-321 |
| dominio/API | Nessuna nuova operazione pubblica; nessuna variazione alla parità Kit/CLI o ai formati persistenti |
| failure semantics | Fonte non verificata non equiparata a licenza BSD; input di inventario modificato richiede nuova review; nessuna dichiarazione di licenza basata soltanto sul nome del metodo |
| esperienza | Nessun nuovo flusso UI; le risorse legali accompagnano il bundle attraverso il lotto 321 |
| dati | Testo e annotazioni gold immutati; manifest distingue licenza del testo e annotazioni e registra hash/permalink |
| verifica | Fonti primarie web; corrispondenza 15 paragrafi alle cinque revisioni; digest dei materiali; checker strutturale, docs e fixture; make verify macOS di composizione |
| sicurezza/privacy | Nessun dato utente o contatto con titolari; sola consultazione fonti pubbliche; nessuna nuova dipendenza o libreria acquisita |
| prestazioni | Nessun miglioramento prestazionale dichiarato; inventario e avvisi testuali piccoli |
| tracciabilità | GS-LIC-002, inventario, GS-VER-318; gate e matrice integrati nel lotto 321 |
| recupero e limiti | Revert dei soli metadati non modifica i dati; nessuna riscrittura della storia Git, certificazione di titolarità o valutazione brevettuale |

**Ready** per registrare la provenienza e correggere i confini delle licenze.
Gli esiti numerici e la verifica integrata rimangono nei lotti che li eseguono.
