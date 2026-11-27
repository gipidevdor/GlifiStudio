<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-327 — Ammissione semantica delle query

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-327 |
| Tipo | Evidenza di correttezza del contratto di ricerca |
| Versione | 1.0.0 |
| Stato | Superato nel profilo automatico macOS |
| Responsabile | Codex e agenti |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di perfezionare codice e semantica |
| Riferimenti | GS-DOR-327; CMP-327; GS-QRY-001; GS-API-003 |

## Difetti e regressioni

Sulla baseline `44dd90f`, un `AND` con termine assente non visita i rami
successivi: lemma, exists, range e scope Project non supportati diventano
risultati vuoti. Un `NOT` può persino trasformarli in un successo. Lo scope
SourceRevision diverso nasconde a sua volta un campo non supportato.
Su un progetto vuoto, l'ammissione dei dati precede la diagnosi della capability.

Le regex `a\1`, `\bparola\b`, `\D+`, `\t`, `[a-z]` e `[[:alpha:]]`
vengono ammesse, ma interpretate diversamente dalla sintassi richiesta.
La correzione le rifiuta; non introduce backreference, range o un altro motore.

Il RED comune compila i sorgenti produttivi invariati e registra 70 issue su
16 definizioni dei lotti 327/328/330. Il lotto query ha tre definizioni negative
con 20 issue: sei capability nascoste, dodici ammissioni regex e due ingressi
Engine sul progetto vuoto. Il controllo positivo di regex supportate passa.
Log locale: `macOS-2026-11-27-semantics/core-red.log` nel dossier delle evidenze.

## Correzione e compatibilità

L'ammissione interna dell'esecuzione visita l'intero AST, dopo la validazione
strutturale e prima di leggere le fonti. Engine testuale, Engine JSON e
valutatore diretto condividono il controllo. La visita è bounded dal limite
AST e osserva la cancellazione a ogni nodo.

Il codec e la validazione strutturale mantengono l'algebra v1 completa: i nodi
per capability future conservano serializzazione e digest, ma non diventano
eseguibili. Le regex ammesse mantengono NFA, budget, flag, risultati e coordinate.
Escape non implementati, intervalli e classi annidate falliscono con il codice
esistente `query.regex-rejected`, senza contenuto delle fonti nei diagnostici.

Non cambia alcuna firma pubblica Kit/CLI, schema persistente, dipendenza,
entitlement o requisito di piattaforma. I test CLI aggiungono ingressi testuali
e AST equivalenti per capability e regex rifiutate, mantenendo privacy,
envelope ed exit status.

## Verifica e limiti

Il candidato supera il GREEN mirato comune: 28 definizioni Core e 17 Kit,
zero issue, con build di 47,04 secondi. Il comando usa lo stesso package
SwiftPM e filtri per query, inferenza, cache, export e bootstrap; il log locale
è `macOS-2026-11-27-semantics/core-green.log`. Le quattro definizioni query
sono tutte verdi, inclusa la conservazione delle query ammesse e dei codec.
La revisione indipendente conferma ordine delle validazioni, cancellazione,
separazione delle capability e preservazione degli escape letterali non ambigui.

Per il GREEN mirato, il manifest locale `source-manifest-targeted.json` fissa 590
input di codice, fixture, configurazione e automazione, comprese le due
reference R esterne al package. Fingerprint SHA-256:
`5aeefb5d07d002001e9ee143bb9c3728e3aeb6c5e509a918d9b16d8c45b99793`.
La baseline Git è `44dd90f`; le correzioni sono lo stato di lavoro successivo,
non il contenuto di quel commit.

## Gate della composizione finale

`make verify` macOS supera il gate completo in **589,88 secondi**: 782
definizioni Core, 169 Kit, 135 native con 425 esecuzioni e nessuno skip,
248 righe di oracoli e 64 casi Fraction indipendenti, due PDF/A-2u verificati,
132 operazioni Kit/CLI con 264 confronti completi, 2.840 dichiarazioni
pubbliche e 22 checkpoint di recovery. I controlli QueryAST CLI conservano
parità, limiti, privacy e failure; la BDD esegue anche AND/NOT con capability
assenti e i rifiuti regex di questo lotto.

La composizione include BDD/Cucumber espressamente richiesta in seguito e
conserva immutati i sorgenti produttivi verificati. Il manifest locale
`composite-source-manifest-before.json` fissa **608 input**, rimasti identici
dopo il gate. Fingerprint finale SHA-256:
`36b05ea14bbeafe91150b84edb8ab74a67a240e75b9430f553797f262714d259`.
Il log `composite-make-verify.log` e il riepilogo locale
`composite-verification-summary.json` documentano la worktree isolata.
La separazione è stata necessaria dopo modifiche concorrenti nella copia
originaria; nessun file di quel lavoro è stato sovrascritto.

Questa evidenza non chiude le capability future, l'indice persistente, gli
audit grafici/assistivi o i gate scientifici e di rilascio ancora aperti.
