<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-140 — Accessi ai file persistiti del package

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-140 |
| Tipo | Evidenza di rafforzamento della persistenza |
| Versione | 1.0.0 |
| Stato | Parziale; verifica dinamica bloccata dal runtime |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-10-03 |
| Approvazione | In attesa di review e verifica su macOS 27 |
| Riferimenti | GS-DOR-011; GS-SEC-001 § 8; RF-043; RQ-044; RQ-057; CMP-095; TV-060 |

## Ambito

Letture bounded del manifest e della storia qualitativa attraverso la primitiva comune di
lettura degli oggetti, validazione sul file descriptor aperto, creazione esclusiva dei file,
writer lease verificato e permessi privati per nuovi package, file autorevoli e staging export.
La serializzazione, i digest, i manifest esistenti e il protocollo di commit non cambiano.

## Copertura aggiunta

- `GlifiQualitativePersistenceTests`: oggetti qualitativi non regolari, dimensioni incoerenti,
  generazione invariata e riapertura dopo ripristino del payload valido.
- `GlifiProjectPackageTests`: manifest e lock non validi, isolamento della directory delle
  transazioni, conservazione dei file estranei, ripresa del commit e permessi privati.
- `GlifiScientificExportTests`: permessi del bundle esportato nel round-trip esistente.

I dati sono sintetici. Nessuna nuova dipendenza, rete, telemetria o stringa UI.

## Verifiche osservate

- Linux: `make quality-static`, `make check-failure-taxonomy` e
  `make check-failure-messages` superati durante lo sviluppo.
- Linux: `make verify` non eseguibile; si arresta su `df -g`, opzione macOS non disponibile.
  Mancano inoltre Swift e Xcode: i controlli statici non sostituiscono la compilazione.
- Baseline `7294c02`: nella sessione Apple, Xcode 27.0 (`27A266a`), Swift 6.4 e Python 3.12.14
  completano controlli statici, lint e compilazione SwiftPM. Il sistema è macOS 26.5.2 arm64:
  entrambi i bundle test macOS 27 falliscono al caricamento per un simbolo CoreGraphics assente.
  Nessuna asserzione eseguita; recovery, smoke CLI e build app non raggiunti dal gate.
- Compilazione e lint della revisione modificata: in attesa della sessione Apple.

## Limiti e chiusura

Non si dichiara completato TV-060 o il gate G2. Restano da eseguire i nuovi test e le regressioni
esistenti con `make verify` su macOS 27; nessun deployment target o controllo viene indebolito.
Gli oracoli R non sono disponibili nella sessione Apple. Nessuna misura prestazionale o prova
su file provider/dispositivo è stata effettuata.

Il controllo del file terminale e il writer lease non costituiscono un contenimento completo
di ogni accesso al filesystem: la risoluzione degli altri path intermedi e le sostituzioni
concorrenti delle directory richiedono una verifica separata. I permessi POSIX non attestano
assenza di ACL ereditate; le directory preesistenti non sono modificate retroattivamente.
La PR rimane in bozza; per rollback è sufficiente il revert, senza migrazioni dei dati.
