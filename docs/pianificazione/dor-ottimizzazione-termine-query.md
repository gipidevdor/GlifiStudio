<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Normalizzazione costante del termine query

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-201 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di una nuova iterazione di ottimizzazione |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-QRY-001; RF-080; RQ-009; RQ-042; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Calcolare una volta il valore confrontabile del termine prima della scansione dei token, dopo misura Release del costo corrente; solo ramo term dell'evaluator |
| requisiti | RF-080, RQ-009, RQ-042, RQ-063; stessa normalizzazione NFC/lowercase italiana, semantica dei campi, match e ordine |
| dominio/API | Nessuna grammatica, AST, serializzazione, digest o API nuova; valore immutabile locale all'evaluation, nessuna cache globale |
| failure semantics | Budget, cancellazione, limiti dei risultati e diagnostica non cambiano; spostamento soltanto di una trasformazione pura indipendente dal token |
| esperienza prevista | Identici match, coordinate, KWIC e troncatura; nessuna UI nuova |
| verifica | Baseline/candidato Release su query normalizzata assente e corpus Unicode con import/tokenizzazione fuori timer; almeno sette campioni, confronto checksum e risultati; casi presenti, composto/decomposto, forma esatta, cancellazione/troncatura; GS-VER-201 candidata e make verify |
| dati e migrazione | Nessuna scrittura o migrazione; input tokenizzati e query identici nel confronto |
| sicurezza/privacy | Query e testo sintetici, limiti invariati, nessun dato reale, rete o nuovo privilegio |
| prestazioni/sistema | Normalizzazione del termine da O(T) chiamate a una, scansione ancora O(T); prestazione complessiva da misurare, niente soglie o acceleratori inventati |
| tracciabilità | CMP-201 inizialmente specified; benchmark, test di equivalenza, evidenza e registri aggiornati insieme |
| decisioni e recupero | Contratto GS-QRY-001 invariato; conservare soltanto un miglioramento misurato senza regressioni, rollback per revert |

**Ready** prima del coding. La baseline precede la patch produttiva. Nessuna
estensione a phrase, regex, indice persistente o nuova politica linguistica.
