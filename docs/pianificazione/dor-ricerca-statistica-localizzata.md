<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Ricerca dei risultati statistici localizzati

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-313 |
| Tipo | Correzione del laboratorio macOS |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di correzioni e ottimizzazioni trasversali |
| Riferimenti | RF-041; RQ-058; RQ-060; RQ-062; RQ-063; GS-STD-001-15; GS-STD-001-16; CMP-313; GS-VER-313 |

## Problema e risultato atteso

Sulla base `741da2e`, il filtro statistico cerca String(Double), +Infinity e ?,
mentre le celle mostrano numeri localizzati, ∞ e un'etichetta localizzata.
Con Bonferroni, input 0,01 e 0,04, il valore corretto 0,02 visibile in italiano
non è ricercabile come 0,02. La ricerca deve usare anche la rappresentazione
effettivamente mostrata, conservando il risultato scientifico immutato.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Filtrare le celle statistiche per numeri, simboli e testo visualizzati; aggiornare il filtro al cambio del locale; conservare la ricerca canonica esistente; solo modello, vista statistica e test macOS |
| requisiti | RQ-060 e GS-STD-001-15: presentazione e ricerca coerenti; RQ-058: failure e cancellazione conservano stato valido; RQ-062/063: tracciabilità e Ready prima del codice |
| dominio/API | Risultato, richiesta, digest, formule, API e trasporto CLI invariati; formattazione condivisa fra celle e filtro, senza introdurre un secondo contratto numerico |
| failure semantics | Cancellazione/reset/nuovo filtro o cambio locale impediscono la pubblicazione tardiva; fallimento dell'analisi non distrugge il risultato precedente |
| esperienza prevista | Una stringa visibile nella tabella deve individuare la sua riga; conteggio e paginazione coerenti; componenti, focus, etichette accessibili e controlli nativi esistenti conservati |
| verifica | Regressioni RED/GREEN it_IT/en_US, decimali, notazione scientifica, interi, simboli e indefinito; risultato e richiesta invariati; cambio locale e reset durante filtro; test automatici e make verify macOS; GS-VER-313 |
| dati e migrazione | Stato di sessione e sola proiezione dei risultati; nessuna scrittura di progetto, nuovo formato o migrazione |
| sicurezza/privacy | Nessuna dipendenza, rete, permesso o diagnostica di contenuti; sole fixture sintetiche bounded |
| prestazioni/sistema | Formattazione/filtro fuori Main Actor, cancellazione nel loop, una passata sulle righe; nessuna accelerazione dichiarata senza misura |
| tracciabilità | CMP-313 inizialmente specified, questa Ready e GS-VER-313; indici e matrice aggiornati nello stesso lotto |
| decisioni e recupero | Correzione di presentazione nell'architettura esistente, nessuna ADR nuova; revert dei soli file del lotto senza effetti sui dati |

**Ready**. Audit visuale, VoiceOver e interazione manuale non fanno parte della
verifica automatica autorizzata e non saranno attestati come eseguiti.
