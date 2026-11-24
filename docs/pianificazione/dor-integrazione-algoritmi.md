<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Integrazione e pubblicazione degli algoritmi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-171 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita: commit, push e successiva iterazione |
| Riferimenti | GS-DOR-168; GS-DOR-169; GS-DOR-170; GS-MET-001-01; GS-MET-001-19; RQ-008; RQ-063 |

| Voce | Accettazione |
| --- | --- |
| outcome e confini | Pubblicare soltanto gli algoritmi 168–170 in branch dedicato basato su origin/main aggiornato; preservare il working tree condiviso e i sette commit upstream |
| requisiti | Risultati e contratti upstream invariati; nessuna perdita di LexRank, TextRank o budget Unicode già pubblicati; correggere la perdita di precisione Welch su varianze di gruppi con offset differenti tramite riferimento indipendente |
| contratto di dominio/API | Conservare LexRankSentence-v1 e TextRankSentence-v1 upstream; esporre il grafo configurabile con identità distinta TextRankSentence-configurable-v1 e le varianti LexRank continue/threshold esplicite |
| failure semantics | Parametri invalidi, cancellazione, budget e mancata convergenza conservano le rispettive semantiche; nessuna reinterpretazione di Artifact legacy |
| esperienza prevista | Nessuna nuova UI; eventuali nuove etichette usano il catalogo localizzabile esistente |
| verifica | Review della proiezione, fixture/oracoli upstream preservati, compatibilità legacy e make verify sul worktree isolato prima del commit e push |
| dati e migrazione | Nessuna migrazione, nuova dipendenza o backend |
| sicurezza/privacy | Solo fixture sintetiche; esclusi dati e cambiamenti delle altre chat |
| prestazioni/sistema | Le misure 169/170 restano evidenze storiche del relativo snapshot; nuova integrazione verificata separatamente |
| tracciabilità | GS-VER-171 registra esiti, branch, base upstream e limiti; evidenze precedenti conservate senza attribuirle alla nuova revisione |
| decisioni | L'identità distinta evita collisioni semantiche con i commit upstream; push senza force e senza merge automatico su main |

**Ready** prima dell'integrazione funzionale successiva alla copia iniziale dei file.

## Esito

Integrazione verificata in [GS-VER-171](../evidenze/GS-VER-171-integrazione-algoritmi.md):
425 test e 177 righe di oracoli, con correzione numerica Welch e compatibilità
upstream preservata. Pubblicazione su branch dedicato senza force push.
