<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Prestazioni delle distribuzioni e della keyness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-324 |
| Tipo | Ottimizzazione misurata |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di ottimizzare le performance senza perdere correttezza |
| Riferimenti | RQ-008; RQ-009; RQ-027; RQ-060; RQ-062; RQ-063; GS-STD-001-17; GS-VER-319; CMP-324 |

## Definition of Ready

La riscrittura di provenienza verificabile GS-VER-319 ha aumentato il costo
dei kernel. La keyness ricalcola inoltre lo stesso quantile per ogni termine.
Le misure estratte precedenti non sostituiscono una baseline sul prodotto
Release reale, con risultati completi e compilazioni separate dalle misure.

| Voce | Contratto |
| --- | --- |
| outcome e confini | Harness del prodotto, baseline/candidato riproducibili; spostare il quantile invariato fuori dal ciclo keyness soltanto dopo misura; valutare normale e beta/gamma in GS-DOR-325/326 e conservare soltanto benefici stabili |
| requisiti | RQ-008/027: risultati verificati; RQ-009: riduzione di lavoro misurata; RQ-060: failure e cancellazione conservate; RQ-062/063: Ready e tracciabilità |
| dominio/API | Nessuna nuova API Core/Kit/CLI di prodotto, backend, dipendenza o formato utente; nuovo modo soltanto nell'eseguibile di benchmark esistente |
| failure semantics | Stessi controlli, ordine delle failure e checkpoint; niente risultato approssimato senza convergenza; invalidi e cancellazione verificati prima della consegna |
| esperienza prevista | Nessuna interfaccia modificata; calcolo analitico nei contesti headless già previsti |
| verifica | Release reale, harness identico prima/dopo, binari e inventari fissati, warm-up e sette campioni, hash input/output e confronto di ogni risultato; misure seriali alternate, ambiente/termica/RSS dichiarati; oracoli, griglia indipendente e make verify macOS |
| dati e migrazione | Nessun formato o migrazione; hoist e pairing richiedono identità dei risultati; eventuali differenze D1 della normale devono rispettare le tolleranze e la policy di revisioni, senza invalidare tacitamente i risultati precedenti |
| sicurezza/privacy | Solo generatori sintetici e fonti matematiche; nessun codice o coefficiente di terzi privo di licenza verificata, rete o telemetria nel prodotto |
| prestazioni/sistema | Si misurano kernel pubblici e consumatori keyness/contingenza; setup e confronti fuori timer; RSS riguarda l'intero processo; nessuna soglia di rilascio né affermazione su UI/energia/I/O fisico |
| tracciabilità | CMP-324 inizialmente specified, questa Ready, GS-VER-324 e GS-VER-325/326; indici e CHANGELOG aggiornati con il lotto |
| decisioni e recupero | Architettura invariata; fallback numerici e possibilità di scartare candidati; revert dei soli file del lotto senza toccare dati o storia Git |

**Ready**. Le compilazioni e le misure sono coordinate dall'integratore;
nessun agente modifica i kernel prima della baseline comune.
