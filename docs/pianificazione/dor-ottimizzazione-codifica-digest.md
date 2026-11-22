<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Validazione e codifica esadecimale dei digest

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-207 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di ottimizzare ancora ogni aspetto |
| Riferimenti | GS-STD-001-07; GS-STD-001-17; GS-DAT-001; RQ-009; RQ-010; RQ-023; RQ-063 |

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Ridurre formatter e visite Character ripetute nella validazione e resa dei digest SHA-256, senza saltare alcun hash o controllo di dominio. |
| requisiti | RQ-009, RQ-010, RQ-023, RQ-063; correttezza, compatibilità e provenienza invariate |
| contratto di dominio/API | Accettare esattamente sha256: e 64 simboli ASCII 0-9a-f; prefisso, namespace generico Unicode, UUID, encoder JSON, nodeID, errori e byte canonici invariati. Helper interno puro; integrazione Graph sequenziale dopo GS205. |
| failure semantics | Nessun controllo indebolito o dato mutato; categorie, codici, retry e stato conservato invariati; nessuna nuova operazione async o I/O produttivo |
| esperienza prevista | Identici risultati e provenienza; nessuna modifica UI, localizzazione o accessibilità |
| verifica | Digest validi/malformati, tutti ASCII e confini Unicode, vettori SHA e namespace Unicode; identificatori e descrittori v1/v2 piccoli/grandi. Riferimento CryptoKit+formatter originale, fallimenti tipizzati completi. Grafi misurati anche prima del cambiamento digest per separare contributi. Un warmup e sette campioni grezzi, preparazione/riferimenti/checksum fuori timer; GS-VER-207 candidata, revisione indipendente e make verify |
| dati e migrazione | Nessuno schema, backend, formato persistente o migrazione; dati sintetici deterministici |
| sicurezza/privacy | Nessuna rete, telemetria, privilegio o corpus reale; stringhe malformate e limiti nei test applicabili |
| prestazioni/sistema | Baseline Release prima delle patch produttive, fasi intermedie per contributi sovrapposti, hardware/OS/toolchain/termica/Low Power Mode e memoria dichiarati; nessuna soglia G4 nuova |
| tracciabilità | CMP-207 inizialmente specified; codice, test, evidenza e registri aggiornati insieme |
| decisioni e recupero | Decisione interna al lotto: supporto SwiftPM riservato ai test secondo GS-DOR-208, senza prodotto né dipendenza esterna; nessuna scelta architetturale del prodotto nuova. Ripristino per revert puntuale |

**Ready** prima del coding. Le modifiche produttive attendono la baseline.
Il supporto dei test è preparato e congelato prima di tutte le misure.
