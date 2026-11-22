<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Stato della presentazione dopo un'importazione parziale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-164 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-21 |
| Approvazione | Prosecuzione dello sviluppo richiesta dall'iniziatore |
| Riferimenti | GS-STD-001-07; RF-002; RF-003; RQ-058; GS-UX-001-03; GS-API-001 § 8 |

## Problema e criterio di stop

L'importazione di più file esegue un commit per fonte. Se un file successivo fallisce,
la presentazione non pubblica i commit precedenti; i contatori di progresso rimangono
valorizzati. La correzione rende esplorabile ogni fonte incorporata e conserva la
failure del file rifiutato.

## Scheda Definition of Ready

| Voce | Contratto dell'incremento |
| --- | --- |
| outcome e confini | Pubblicare snapshot, profilo e nome della fonte dopo ciascun import riuscito; azzerare il progresso in ogni esito; nessuna atomicità dell'intero gruppo di file |
| requisiti | RF-002, RF-003, RQ-058; dopo `[valido, non valido]` il primo commit è visibile, interrogabile e riapribile; dopo `[non valido]` lo stato precedente resta utilizzabile |
| dominio/API | Solo modello condiviso delle app; Core, GlifiKit, formato `.glifi`, generazioni e commit point invariati |
| failure semantics | Conservare categoria, retry e retainedState della failure GlifiKit; fermarsi al primo errore; nessun rollback dei commit riusciti |
| esperienza prevista | Fonti e profilo aggiornati progressivamente; risultati analitici, storia e selezioni conservano il lineage esistente; nessun nuovo controllo o testo di interfaccia |
| verifica | Regressioni del modello macOS con file sintetici validi/non validi, query e riapertura del commit riuscito, conservazione dello stato senza commit, progresso azzerato; `make test-macos` e `make verify`; GS-VER-185 candidata |
| dati e migrazione | Nessuna migrazione; fonti originali e generazioni già confermate non vengono riscritte dalla correzione |
| sicurezza/privacy | Accessi security-scoped bilanciati per ciascun file; nessun path o contenuto aggiunto alla failure, nessuna rete, dipendenza o entitlement |
| prestazioni/sistema | Assegnazioni di stato dopo i commit esistenti; nessun nuovo parsing o ricalcolo, I/O invariato fuori dal Main Actor tramite GlifiKit |
| tracciabilità | CMP-108 inizialmente `specified`; RF-002/RF-003, TV-002 e TV-071, evidenza e CHANGELOG nello stesso cambiamento |
| decisioni e recupero | Semantica incrementale già prescritta da GS-UX-001-03; nessuna nuova ADR; rollback tramite revert senza migrazione |

**Ready** prima del primo cambiamento implementativo. Audit GUI, VoiceOver e dispositivi
fisici rimangono verifiche distinte di G4. Invalidazione dei risultati e modifiche della
semantica di cancellazione restano fuori dal presente incremento.

## Avanzamento

Riproduzione del difetto con le tre regressioni registrata in GS-VER-185; modello
corretto e CMP-108 `verified` nel perimetro dichiarato. `make test-macos` dopo la
correzione supera tutti gli 11 test senza failure o skip; `make verify` completo
e il preflight di analisi/archivi senza firma terminano con exit 0. La prova
integrativa verifica due PDF/A-2u; i limiti di dispositivo e G4 restano aperti.
