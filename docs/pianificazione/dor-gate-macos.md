<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Profilo esplicito di verifica macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-167 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Richiesta esplicita di completare macOS prima dello sviluppo dedicato iPadOS |
| Riferimenti | GS-STD-001-07; RQ-005; RQ-063; GS-DEV-002; GS-PROD-001 |

## Problema e criterio di stop

Il gate globale costruisce e archivia entrambe le piattaforme. Per il focus macOS
richiesto serve un profilo esplicito che mantenga tutti i controlli condivisi e
ometta soltanto build, analisi e archivi iPadOS rinviati dall'iniziatore.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Flag `--macos-only` in `verify.sh` e `check-app-store-packaging.sh`; target `make verify-macos` e `make verify-app-store-macos`; comportamento senza argomenti invariato su entrambe le piattaforme |
| requisiti | RQ-005, RQ-063; nessun controllo condiviso rimosso; profilo macOS distinto dal gate globale e dichiarato negli esiti |
| dominio/API | Solo interfaccia degli script di sviluppo e target Make, con helper di parsing in `build-cache.sh` e inoltro nel wrapper `verify-app-store.sh`; nessuna modifica a prodotto, API, toolchain, dipendenze o deployment target |
| failure semantics | Argomenti sconosciuti, duplicati o combinazioni non ammesse falliscono prima di creare temporanei o preparare cache; errori dei controlli e cleanup mantengono la semantica esistente |
| esperienza prevista | Output e documentazione identificano il profilo; nessuna UI di prodotto; comandi riproducibili senza selezioni implicite di piattaforma |
| verifica | Sintassi shell, prove di argomenti invalidi prima degli effetti collaterali, ispezione dei rami default/macOS, esecuzione del profilo macOS e packaging; GS-VER-188 candidata |
| dati e migrazione | Nessun formato di progetto; temporanei e cache seguono il protocollo esistente, senza modifica ai dati utente |
| sicurezza/privacy | Nessun nuovo privilegio, rete, entitlement o installazione; valori degli argomenti non diventano comandi eseguiti |
| prestazioni/sistema | Profilo macOS esegue statici, Core/Kit, CLI, oracoli, fixture, PDF/A e recovery invariati, più test e build Debug/Release macOS; preflight con analisi e archivio macOS senza firma; omette soltanto le azioni iPadOS |
| tracciabilità | CMP-111 inizialmente `specified`; RQ-005/RQ-063, TV-013/TV-049/TV-076, documentazione del loop, evidenza e CHANGELOG nello stesso cambiamento |
| decisioni e recupero | Profilo operativo nella richiesta esplicita; baseline multipiattaforma e gate globali invariati, nessuna nuova ADR; rollback mediante revert degli script e target |

**Ready** prima del coding. Il profilo macOS non equivale al gate globale e non
certifica iPadOS, firma, App Review, GUI reale o G4. I controlli non eseguibili o
opzionalmente saltati devono restare espliciti negli esiti.

## Verifica finale del profilo macOS

Gate e preflight automatici superati sullo snapshot identificato in
[GS-VER-188](../evidenze/GS-VER-188-gate-macos.md). La clausola dell'incremento è
`verified` soltanto nel perimetro documentato; nessuna chiusura di GUI manuale,
VoiceOver, finestre reali, autosave, iPadOS o G4 è inferita.
