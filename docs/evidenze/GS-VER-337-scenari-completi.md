<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-337 — Copertura comportamentale dichiarata e fonti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-337 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato nel profilo automatico macOS e preflight senza firma |
| Responsabile | Codex con revisione separata |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di completare scenari e correttezza |
| Riferimenti | GS-DOR-337; CMP-337; GS-BDD-001; GS-LIC-003 |

## Superficie verificata

Il registro `Config/Testing/bdd-contracts.json` collega tutte le **172 varianti**
di GS-TST-001 a tre fasi: nominale, input non valido e cancellazione preventiva.
Sono 44 varianti statistiche, 45 operatori, 13 valutazioni, 26 operazioni di
progetto, quattro formati sorgente e 40 analisi testuali. Le 63 richieste di
`Fixtures/TextAnalysis/v1/cases.json` sono eseguite invariate; cinque alias
modificati sono dichiarati separatamente. Il registro comprende **565 casi
pubblici e 179 supplementari**, nelle **16 feature / 744 scenari / 3092 passi**
certificati dal generatore upstream bloccato. Il planner esercita tutti gli
undici intenti, compresi i tre non eseguibili, oltre a input invalido e cancellazione.

Le attese includono numeri e celle indipendenti, partizioni, conteggi,
coordinate UTF-8, identità persistenti, riuso e riapertura. Per il MDS non
metrico si ricostruisce lo stress del metodo e si verificano convergenza e
storia; non si pretende la riproduzione esatta delle distanze metriche.
KL e Jensen–Shannon usano i bit prescritti da GS-MET-001-13. La parità fra
facciate che condividono il Core non è l'unico oracolo scientifico.

## Integrità del controllo

Il lettore `Scripts/build-bdd-inventory.py` tratta solo l'output Swift del
generatore pinned, senza sostituire il parser Gherkin. Il verificatore collega
matrice, feature, riga, oracolo dichiarato, provenienza e nomi ordinati dei
passi. Witness mancanti e associazioni planner insufficienti sono rifiutati.
I controlli negativi comprendono omissioni, fase mancante, duplicati,
digest alterati, fonti assenti e report scambiati o parziali. Più casi limite
possono coprire la stessa fase; ogni scenario mantiene un indirizzo unico.

Le cinque famiglie di fonti primarie e i termini sono registrati in
[GS-LIC-003](../testing/02-provenienza-scenari.md). Nessun nuovo codice,
corpus, suite o esempio esterno viene acquisito: input e attese sono originali.
Le licenze del runner restano distinte da quelle dei riferimenti consultati.

## Esiti osservati

La selezione finale mirata esegue **325 scenari** (operatori, testo e
interchange), più le due regressioni Kit CSV: exit 0 in **71,63 s**.
Le precedenti esecuzioni conservano gli errori delle fixture risolti e il RED
reale del CSV; non sono presentate come verifiche riuscite. La regressione
di prodotto è descritta in [GS-VER-338](GS-VER-338-csv-crlf.md).
Il gate finale viene registrato nell'[allegato](allegati/GS-VER-337-verifica.json).

## Limiti

Completo significa copertura della superficie e delle dimensioni dichiarate,
non di ogni input o combinazione. GS-SCN-009 resta coperto da test del modello
nativo: nessuna dichiarazione di automazione della GUI. Non sono attestati
VoiceOver, Voice Control, usabilità, rendering interattivo, iPadOS, G4 o G5.
Nessuna nuova ottimizzazione è dichiarata senza benchmark.

I log, le mappe revisionate, l'espansione upstream e i manifest sono conservati
nel dossier locale `macOS-2026-11-27-bdd-complete`. Gli hash degli esiti finali
sono nell'allegato; gli artefatti di build rigenerabili vengono rimossi dopo
la verifica preservando strumenti, dipendenze ed evidenze utili.

## Chiusura automatica macOS

`make verify` è superato in **624,14 s**: 782 definizioni Core, 171 Kit e
107 BDD; il report completo richiede 16 feature, 744 scenari e 3092 passi.
I nativi confermano 144 definizioni e 435 esecuzioni, senza failure o skip.
Sono riprodotte 248 righe di oracoli e 64 casi Fraction; due PDF/A-2u sono
conformi. Passano 132 operazioni / 264 confronti completi CLI/Kit e 22
checkpoint recovery.

`Scripts/check-app-store-packaging.sh --macos-only` è superato in
**451,60 s**: analisi statica e archivio macOS senza firma, metadati,
risorse, privacy e identità byte per byte delle licenze nel bundle.
I due componenti di `verify-app-store.sh` sono eseguiti separatamente sugli
stessi **629 input immutati**, SHA-256
`91ee8fd56ca04b8f0a00aacc20b11d430ea031743e8469f2ef15d59aa78db1d4`.
Il gate completo non è ripetuto dopo un esito positivo in assenza di modifiche.
Xcode emette diagnostica del proprio launcher e del placeholder Any Mac;
la verifica nativa riporta zero runtime warning e l'esito dei comandi è 0.

Il tentativo corrente di accesso al desktop conferma il Mac bloccato: audit
visivo e assistivo restano aperti. Documenti e allegati finali sono ricontrollati
separatamente dai sorgenti immutabili di build e test. Nessuna firma o
submission App Store è eseguita.

## Pulizia e artefatti conservati

Sono rimossi **3.334.976 KiB (3,18 GiB)** di prodotti rigenerabili, misurati
con `du`, al netto dell'app e delle evidenze conservate. Restano dipendenze
SwiftPM bloccate, strumenti, app Release, risultato nativo, espansione upstream
compressa, report completi e log. La pulizia opera soltanto sulla cache posseduta
dal lotto; cartella sorgente originale e file dell'utente sono preservati.
