<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Affidabilità dei verificatori automatici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-312 |
| Tipo | Correzione dei controlli di qualità |
| Versione | 1.1.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-24 |
| Approvazione | Richiesta esplicita di proseguire correzioni e ottimizzazioni con tutti gli agenti |
| Riferimenti | RQ-062; RQ-063; GS-STD-001-16; GS-STD-001-20; GS-STD-001-29; CMP-312; GS-VER-312 |

## Problema e confini

Sulla base `741da2e`, il verificatore PDF/A accetta un processo veraPDF terminato
con errore se il suo output contiene tante righe PASS quanti sono i PDF. Il
caso discriminante è un processo con exit status 79 e output PASS completo.
La correzione riguarda i controlli automatici; non modifica PDF esportati,
algoritmi numerici, API, CLI di prodotto o formati persistenti.

Estensione Ready precedente al relativo codice: il confronto degli oracoli
accetta infinito al posto di un valore finito perché confronta infinito con
infinito nella disuguaglianza della tolleranza. Ogni operando non finito deve
essere rifiutato, anche se i due operandi sono uguali. Regressioni NaN e ±infinito
coprono confronto e collegamento ai letterali Swift. Questa correzione conserva
le tolleranze finite esistenti; l'eventuale revisione delle tolleranze dei valori
molto piccoli richiede una decisione separata sulle quantità prossime a zero.

## Scheda Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Nessuna attestazione di conformità PDF/A dopo un exit status diverso da zero; conservare il controllo sul numero dei risultati e sui FAIL; nessun numero non finito accettato dagli oracoli; fermarsi ai difetti riprodotti dei verificatori |
| requisiti | RQ-062 e GS-STD-001-16: una verifica fallita non diventa evidenza positiva; RQ-063: Ready registrata prima del codice |
| dominio/API | Solo strumenti di sviluppo Python e relativa integrazione nel gate; opzioni PDF/A esistenti compatibili, nessun cambiamento Core/Kit/CLI di prodotto |
| failure semantics | Nonzero del validatore, risultati assenti/incompleti o FAIL producono exit nonzero; successo richiede processo riuscito e un PASS per ogni PDF; diagnostica di lunghezza limitata |
| esperienza prevista | Messaggi di verifica chiari e distinti da una conformità positiva; nessuna modifica alla GUI o ai suoi stati/accessibilità |
| verifica | Regressioni deterministiche con esiti del processo controllati, inclusi nonzero con PASS completo, successo, FAIL e risultati mancanti; NaN/±infinito nel confronto e nei collegamenti, tolleranze finite conservate; RED/GREEN; veraPDF e oracoli reali nel make verify macOS; GS-VER-312 |
| dati e migrazione | Nessun dato di progetto o migrazione; fixture temporanee sintetiche rimosse dai test |
| sicurezza/privacy | Nessuna nuova dipendenza, rete, entitlement o contenuto utente; non esporre ambiente o diagnostica illimitata; conservare file e cache delle altre attività |
| prestazioni/sistema | Cambia la decisione successiva al processo già eseguito e aggiunge controlli di finitezza costanti per valore numerico; complessità invariata, nessuna accelerazione o riduzione di latenza rivendicata |
| tracciabilità | CMP-312 inizialmente specified, questa Ready e GS-VER-312; aggiornare indici e collegamenti nel medesimo lotto |
| decisioni e recupero | Correzione interna nell'architettura esistente, nessuna nuova ADR; revert dei soli strumenti e test del lotto; eventuali ulteriori difetti richiedono estensione della Ready prima del relativo codice |

**Ready** per la correzione circoscritta del controllo PDF/A e della finitezza
degli oracoli.
