<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Copertura comportamentale dichiarata e provenienza

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-337 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di scenari completi anche da fonti web legalmente utilizzabili |
| Riferimenti | GS-BDD-001; GS-TST-001; GS-LIC-002; GS-STD-001-13; GS-STD-001-16 |

## Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Collegare tutte le varianti pubbliche inventariate a scenari Cucumber eseguibili con attese osservabili; conservare i workflow esistenti e distinguere la copertura headless dall'interazione GUI |
| superficie | 44 varianti statistiche, 45 operatori, 13 valutazioni, 26 operazioni di progetto, quattro formati sorgente e 40 varianti testuali, come enumerati in GS-TST-001 |
| failure semantics | Per le operazioni JSON: esecuzione nominale, richiesta non valida e cancellazione preventiva con failure tipizzata e nessun risultato parziale; per operazioni persistenti anche stato conservato e riuso/riapertura quando applicabili |
| qualità delle attese | Numeri, celle, conteggi, struttura scientifica, identità o failure espliciti; successo, output non vuoto e parità fra chiamate che condividono il Core non bastano come unico oracolo |
| provenienza | Fonti primarie web e condizioni lette, revisione fissata quando disponibile, distinzione fra riferimento a fatti/metodi e materiale copiato; fixture sintetiche originali preferite |
| sicurezza e licenze | Nessuna nuova dipendenza eseguibile, corpus personale o codice scaricato eseguito; citare una pubblicazione non concede permesso di copiarla |
| verifica | Contratto di copertura confrontato con la matrice pubblica, inventario dal generatore upstream, report completo, controlli negativi contro omissioni e associazioni errate, suite mirata e make verify macOS |
| tracciabilità | GS-VER-337 e matrice di copertura collegano variante, scenario, fase, attesa e fonte; lacune e non applicabilità rimangono esplicite |

**Ready** per l'estensione delle specifiche eseguibili e del loro controllo.
"Completo" indica la copertura della superficie e delle dimensioni dichiarate,
non una prova su ogni input possibile. Test headless e modelli nativi non
attestano tastiera reale, VoiceOver, rendering, iPadOS, G4 o G5.

Non cambiano API o formati di prodotto. Una nuova regressione sostanziale deve
essere riprodotta prima della correzione; aggiungere copertura di comportamenti
già implementati non deve essere presentato come RED di un difetto inesistente.
Rollback tramite revert di test, inventari e documentazione, senza migrazioni.
