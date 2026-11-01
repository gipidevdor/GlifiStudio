<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Interfaccia essenziale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-020 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready con rischio accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-01 |
| Approvazione | Direzione UX richiesta dall'iniziatore; integrazione tramite PR #23 |
| Riferimenti | GS-STD-001-07; GS-UI-001; ADR-0014; ADR-0024; CMP-105; GS-VER-150 |

## Unità di lavoro

Rendere la ricerca guidata dalla domanda più essenziale: prossima azione
contestuale, navigazione nativa, dettagli tecnici espandibili e risultati
utilizzabili in finestre strette e con testo di accessibilità. La consegna
comprende soltanto la presentazione e le sue traduzioni; calcolo, formati,
lineage e ciclo documentale macOS sono fuori da questa unità.

## Provenienza della scheda

La scheda è registrata durante la preparazione dell'integrazione, dopo
l'implementazione. Ricostruisce confini, contratti e verifiche dai requisiti e
dall'evidenza esistenti; non dimostra l'avvenuta registrazione prima del coding
richiesta da GS-STD-001-07 § 7.2. Per i prossimi incrementi la scheda va registrata
prima della modifica, senza usare questa registrazione come precedente di deroga.

## Scheda Definition of Ready

| Voce | Evidenza | N/A |
| --- | --- | --- |
| outcome e confini | Una prossima azione primaria nella panoramica; metadati espandibili; risultati sequenziali con spazio ridotto; nessun nuovo metodo | — |
| requisiti | RF-072, RF-073, RQ-030, RQ-032, RQ-038; GS-UI-001, GS-STD-001-15 | — |
| contratto di dominio/API | App → GlifiKit invariato; stessa identità di finding, evidenza e fonte | — |
| failure semantics | Il messaggio resta visibile e la causa espandibile; operazioni e gestione delle failure restano nel modello esistente | — |
| esperienza prevista | Panoramica contestuale, stato vuoto con azione reale, indicazione del lavoro e cancellazione esistente; navigazione e controlli di sistema | — |
| verifica | GS-VER-150: 246 test, build Debug/Release macOS/iPadOS, cataloghi it/en, lint e oracoli; preflight e CI prima del merge; audit manuali distinti | — |
| dati e migrazione | Nessun dato entra o cambia, nessun nuovo formato; lineage invariato | Nessuna migrazione necessaria |
| sicurezza/privacy | Nessuna dipendenza, rete, telemetria, entitlement, credenziale o contenuto sensibile aggiunto | — |
| prestazioni/sistema | Nessuna accelerazione o nuova elaborazione analitica; componenti SwiftUI nativi e stato di navigazione locale | Nessun benchmark di algoritmo modificato |
| tracciabilità | CMP-105 implemented, GS-VER-150 e matrice GS-TRC-001; nessuna promozione implicita dei gate UI | — |
| decisioni | Applicazione di ADR-0014 e ADR-0024; nessuna nuova scelta architetturale | Nessuna nuova ADR necessaria |

## Stato DoR e rischio residuo

**Ready con rischio accettato** per l'integrazione della presentazione.
VoiceOver, Voice Control, contrasto misurato, pseudo-lingua e dispositivi fisici
restano in carico al maintainer prima di G4. Il Mac locale bloccato e CoreSimulator
non allineato impediscono la verifica interattiva in questa sessione; le build e
i controlli automatici non la sostituiscono. Nessuna dichiarazione di conformità
ai criteri ancora da introdurre di GS-STD-001-29.

Rollback: revert dello squash commit UI, senza migrazioni. La condizione di stop
prima del merge è una CI verde, assenza di revisioni bloccanti e completamento
del preflight di packaging; non si disabilitano controlli per integrare.
