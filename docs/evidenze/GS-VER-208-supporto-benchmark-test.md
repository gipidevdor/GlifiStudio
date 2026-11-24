<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-208 — Supporto condiviso dei benchmark dei test

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-208 |
| Tipo | Evidenza di infrastruttura di verifica |
| Versione | 1.0.0 |
| Stato | Superato |
| Responsabile | Codex, coordinamento del lotto |
| Ultima modifica | 2026-11-21 |
| Approvazione | GS-DOR-208; RQ-009; RQ-063 |
| Riferimenti | GS-STD-001-17; CMP-208; GS-DOR-205; GS-DOR-206; GS-DOR-207 |

## Cambiamento

Il protocollo di misura già usato da GS-VER-202/203/204 è spostato nel target
interno `GlifiBenchmarkTestSupport`, sotto `Tests`, e importato esplicitamente
dai test interessati. Le tre funzioni del supporto sono esposte dal modulo condiviso per essere
importate dai due target di test; nessuna API di GlifiCore o GlifiKit cambia.

Un'unica implementazione mantiene guard Release, un warmup, sette campioni,
risultati Equatable e checksum completi dopo lo stop del timer, metadati
hardware/OS/termica/Low Power Mode e JSON per scenario. I test piccoli restano
attivi senza variabile di misura. Gli entry grandi sono eseguiti con filtri
separati e seriali.

## Verifica strutturale osservata

Il [record](allegati/GS-VER-208-supporto-benchmark.json) confronta il helper
precedente conservato nell'archivio GS202/204 con quello condiviso: rimuovendo
soltanto `public` dalle tre dichiarazioni, i byte dei file sono identici.

`swift package describe --type json` conferma i soli consumatori
`GlifiCoreTests` e `GlifiKitTests`. Il supporto non possiede product membership;
i prodotti restano GlifiCore, GlifiKit, GlifiCLI, GlifiRecoveryHarness e
GlifiBenchmark. La decisione registrata in GS-DOR-208 non introduce dipendenze
esterne, privilegi, entitlement o un requisito runtime delle app.

## Verifica dinamica osservata

Le tre fasi Release compilano con testability e misurano sedici workload
completi più undici riscontri intermedi. Il [confronto](allegati/GS-VER-205-207-confronto.json)
verifica output e fixture esatti, campioni e sorgenti consentiti. I test Release
mirati superano nove test Core e tre Kit, inclusi i tre entry precedenti
GS202/203/204 migrati al supporto condiviso.

Il [gate completo](allegati/GS-VER-205-208-gate.json) termina con exit 0:
391 test Core e 59 Kit, 55 test macOS distinti (195 esecuzioni), 153 righe di
oracoli, 51 controlli CLI su 15 fixture, 22 checkpoint recovery, due PDF/A-2u
e build Debug/Release macOS/iPadOS. I 376 ingressi runtime e di verifica sono
invariati durante la corsa; l'infrastruttura non indebolisce alcun controllo.
Il [riepilogo nativo](allegati/GS-VER-205-208-test-macos.json) conserva i conteggi
senza identificatori del dispositivo.

La guard è verificata in un processo Debug separato: atteso e osservato exit 1,
`releaseConfigurationRequired` e nessun JSON di misura scritto. Il
[record del controllo negativo](allegati/GS-VER-208-guard-debug.json) e il
[log](allegati/GS-VER-208-guard-debug.txt) distinguono il rifiuto voluto dalla
suite positiva. Non viene introdotto un nuovo gate numerico o criterio EA.

## Conservazione e limiti

L'[archivio dei sorgenti](allegati/GS-VER-205-208-archivio-sorgenti.json),
verificato indipendentemente contro inventari e audit, contiene tutte le fasi
e i test finali aggiuntivi senza cache di build: 729.337 byte, SHA-256
`a9f0ac28e3799f993f7d5e4c62991c87c1d0231247669ad95f775debb4e85da1`.
I [log del gate](allegati/GS-VER-205-208-gate.txt) e dei
[test mirati](allegati/GS-VER-205-208-test-mirati.txt) restano consultabili.

Le build iPadOS usano una destinazione generica e non attestano test runtime:
CoreSimulator installato 1171.7.0 è precedente a 1174.21.0 richiesto da Xcode;
rimangono l'avviso in-place iPadOS e i metadati incompleti delle destinazioni
generiche. Non si attesta un nuovo packaging, audit GUI, energia o G4.


## Pulizia finale

Rimossa la sola cache del lotto dopo tutte le verifiche: **3.277.504 KiB,
circa 3,13 GiB allocati** prima della rimozione. Il
[record di pulizia](allegati/GS-VER-205-208-pulizia.json) conferma l'assenza del
percorso, distinguendo la misura dal delta di spazio libero APFS. Restano
allegati, audit e archivio sorgenti verificato; toolchain, dipendenze e cache
delle altre sessioni sono preservate.
