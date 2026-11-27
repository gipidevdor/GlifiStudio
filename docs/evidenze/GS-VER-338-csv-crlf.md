<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-338 — Quoting CSV dei campi contenenti CRLF

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-338 |
| Tipo | Evidenza di verifica |
| Versione | 1.0.0 |
| Stato | Superato nel profilo automatico macOS e preflight senza firma |
| Responsabile | Codex con revisione separata |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di completare scenari e correttezza |
| Riferimenti | GS-DOR-338; CMP-338; GS-BDD-001; GS-LIC-003 |

## Difetto e correzione

Un'etichetta sintetica con CRLF e senza virgole o virgolette non veniva
quotata. Swift rappresenta CRLF come un solo `Character`; il confronto del
writer con i singoli caratteri CR e LF non lo riconosceva. La fixture
preesistente conteneva anche virgola e virgolette, che mascheravano il difetto.
Il writer ora controlla `unicodeScalars` e conserva integralmente il contenuto.
La regola dei campi con interruzioni di riga è riferita a
[RFC 4180 § 2.6](https://www.rfc-editor.org/rfc/rfc4180.html), con condizioni
storiche e uso di soli fatti documentati in GS-LIC-003.

Il cambiamento riguarda il serializer condiviso dell'export visuale Kit/CLI.
API, schema e writer v1 restano invariati; il contratto CSV era già quello
previsto. I bundle storici malformati con CRLF non quotato sono rifiutati anche
se il loro digest è aggiornato: il verificatore richiede coerenza con la
specifica e il writer, oltre all'integrità dei byte.

## RED e GREEN

Prima del fix, le due nuove regressioni Kit falliscono per la proprietà
attesa in **48,07 s** complessivi: il campo CRLF non è quotato. Dopo il fix,
la selezione combinata di 325 scenari BDD e due test Kit passa in **71,63 s**.
La feature Interchange verifica un documento CSV atteso completo e indipendente,
non soltanto un round-trip fra produttore e lettore. I test Kit distinguono
CRLF, CR, LF e testo semplice; l'alterazione con digest coerente è rifiutata.
Gli hash RED/GREEN e il gate finale sono nell'[allegato](allegati/GS-VER-338-verifica.json).

Non vengono cambiati dati utente né introdotte dipendenze o migrazioni.
Il passaggio agli scalari corregge il riconoscimento dei delimitatori; non
costituisce una dichiarazione di miglioramento prestazionale.

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
