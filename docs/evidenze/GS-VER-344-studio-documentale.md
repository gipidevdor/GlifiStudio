<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-344 — Studio documentale, passaggi e conclusioni

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-344 |
| Tipo | Evidenza di integrazione Core, Kit, CLI e GUI macOS |
| Versione | 1.0.0 |
| Stato | In corso; RED osservato, integrazione e verifica finale da completare |
| Responsabile | Codex, coordinamento della copia condivisa |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di procedere; priorità a usabilità, contenuto e conclusioni |
| Riferimenti | RF-089; ADR-0048; GS-DOR-344; GS-API-007; GS-UX-001-18; CMP-344 |

## Perimetro

Il primo incremento collega lettura dominante, estratti autonomi, note e
conclusioni personali, gruppi e ordine, confronto opzionale, ritorno alla
revisione archiviata ed esportazione del taccuino. Riusa importatori, selezione
di passaggi, SpanMap, indagini e commit generazionali esistenti. Lo studio
non modifica gli originali e non attribuisce autorità scientifica alle note.

## Ciclo BDD osservato

Prima delle modifiche di dominio, `StudyWorkflow.feature:10` importa la fixture
italiana originale con accento ed emoji e richiede lo stato tramite la CLI reale.
`make test-bdd-dev BDD_SELECT=StudyWorkflow.feature` ha compilato con successo
e fallito al passo 13: atteso exit 0, ottenuto **2**, perché `study-call` non
esisteva. Nessun passo era indefinito e non si è usato un errore di compilazione
come RED. Build 96,74 s; exit finale make 2. Il log locale temporaneo
`/tmp/glifi-study-344-red.log` verrà conservato tra le prove utili prima della pulizia.

Contratti ADR-0048, GS-DOR-344 e GS-API-007 sono stati scritti prima
dell'introduzione del payload persistente. Le verifiche GREEN, parità,
compatibilità, native e `make verify` macOS saranno registrate con esiti
effettivi e identificazione degli input prima della consegna.

La review ha inoltre riprodotto un ripristino con identità SHA-256 valida che
divide un emoji composto. `StudyWorkflow.feature:100`, passo 103, ha compilato
e fallito perché il writer accettava un confine di scalar UTF-8 interno al
grafema: log locale `/tmp/glifi-study-grapheme-red.log`, issue alla riga 557
degli step. Il controllo richiesto è il confine di carattere, oltre alla validità
UTF-8. L'esito GREEN non è ancora attestato in questa revisione dell'evidenza.

Un secondo RED di integrità (`StudyWorkflow.feature:76`) ha dimostrato che la
uguaglianza canonica di `String` non basta per una citazione esatta: riordinare
due segni combinanti lasciava invariata la lunghezza e il confronto testuale,
ma cambiava i byte. Il writer accettava la nuova anchor con hash coerente.
Il controllo usa ora confini di carattere e confronto degli elementi UTF-8,
anche nell'immutabilità delle anchor esistenti.

GREEN mirato osservato: tutti i **25 scenari Study, 83 passaggi**; **11 test
Core/Kit/compatibilità**; richiesta `statePath` con **1.400.261 byte**, eseguita
due volte nella CLI reale con risultato completo identico al DTO nativo
(stdout 1.400.341 byte). Il payload corrotto usa `readOnlyRecovery` secondo
GS-API-001; non viene dichiarato `unchanged` per aggirare la tassonomia.

La regressione nativa su due sessioni realmente indipendenti ha riprodotto
un altro RED: compilazione applicativa riuscita, sei test verdi e gruppo
esterno assente dopo il vecchio ricaricamento. Il nuovo percorso apre e verifica
una sessione candidata prima dell'adozione, mantenendo bozza e lettura se fallisce.
L'esito finale nativo e quello globale restano da registrare.

## Limiti di attestazione

Il superamento di un test di modello non prova l'intuitività della vista o
l'accessibilità su dispositivo. Uno studio con utenti rappresentativi e gli
audit VoiceOver, Voice Control, tastiera, contrasto, testo grande, pseudo-lingua
e destra-sinistra restano distinti e saranno dichiarati soltanto se eseguiti.
iPadOS, cloud, lavagna spaziale e scrittura a mano non fanno parte della verifica.
