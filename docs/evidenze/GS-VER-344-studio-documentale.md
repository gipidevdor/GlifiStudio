<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-344 — Studio documentale, passaggi e conclusioni

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-344 |
| Tipo | Evidenza di integrazione Core, Kit, CLI e GUI macOS |
| Versione | 1.4.1 |
| Stato | Gate automatico e preflight macOS superati dopo il riesame UI; verifica visiva parziale |
| Responsabile | Codex, coordinamento della copia condivisa |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di procedere, mantenendo stile Glifi Studio e priorità a contenuto e conclusioni |
| Riferimenti | RF-089; ADR-0048; GS-DOR-344; GS-API-007; GS-UX-001-18; CMP-344; GS-STD-001-29 § 29.6 |

## Risultato e perimetro

Il primo incremento rende persistente il percorso **leggere → raccogliere passaggi →
scrivere conclusioni → tornare alle fonti**. Comprende lettura del testo con selezione
nativa, PDF originale archiviato, anteprima della citazione, estratti autonomi, note
libere o sostenute da più passaggi, gruppi, ordine misto, confronto di due letture ed
export JSON e Markdown. Il taccuino e il confronto si aprono su richiesta; i dettagli
tecnici restano secondari alla lettura.

Le sei operazioni `study-call` condividono le API native secondo
[GS-API-007](../api/07-studio-documentale.md). Il salvataggio usa storia append-only,
revisione ottimistica, identità del progetto e anchor immutabili con digest,
coordinate UTF-8, quote e SpanMap verificate. Reader 4 lazy e lettura dei progetti
precedenti seguono [ADR-0048](../adr/0048-studio-documentale-e-taccuino.md).
Le note sono annotazioni personali: non generano automaticamente Evidence, Finding
o passi del planner eseguiti. L'analisi linguistica resta italiana.

L'ambito è implementazione e integrazione G3. Non si promuovono G4/G5 né una qualifica
assistiva completa. Lavagna spaziale, Pencil/scrittura a mano, cloud e iPadOS sono
rinviati e non rientrano in questa attestazione.

## Identità della verifica dopo il riesame UI

Le correzioni di inizializzazione e recupero dell'editor hanno superato il RED/GREEN
mirato sotto descritto e il gate completo sul seguente snapshot.

| Campo | Identità |
| --- | --- |
| Checkpoint del codice | `4799dc8d503374c833f7292772260616a3188dc0` |
| Input controllati | 1.037 file, secondo il [manifest degli input](allegati/GS-VER-344-inputs.json) |
| Fingerprint SHA-256 | `eaa7a295b05a99e5a413448993af7b979be65b866b7431adf4a35e36c8336223` |
| Profilo | macOS; Xcode 27.2, Apple Swift 6.4.2 |
| Gate finale | `make verify` macOS, cache gestita `study-344-review`; exit 0, 729,51 s |
| Preflight finale | Analisi statica e archivio macOS senza firma superati; exit 0, 549,24 s |

Questa evidenza e la relativa voce nell'indice sono escluse dal fingerprint degli
input. La loro compilazione durante il gate non modifica il codice sotto verifica.
Il [riepilogo macchina](allegati/GS-VER-344-verifica.json) registra gli esiti finali,
i digest delle prove e il precedente checkpoint `c0e3431`, superato in 728,16 s più
546,54 s di preflight con 186 definizioni native. Nessun risultato precedente
sostituisce la verifica del nuovo codice.

La PR #51 è stata integrata sul remoto durante il riesame. Il suo squash
`8171c3c` ha lo stesso albero di `56dff03`; il commit `0eaa435` ne registra
l'ascendenza senza cambiare l'albero di input `4799dc8`. La PR #52 contiene il
successivo recupero UI. I 1.037 input sono rimasti identici durante gate e preflight.

## Prove osservate

| Verifica | Esito osservato e limite |
| --- | --- |
| Studio Core/Kit/compatibilità | 11 test mirati superati; originali, storia, reader, Markdown/PDF e rifiuto di scritture non valide |
| BDD Study | 25 scenari, 83 passaggi superati; sei operazioni nelle tre fasi, workflow, integrità, conflitti e cancellazione |
| Trasporto di grandi DTO | `statePath` di 1.400.261 byte eseguito due volte nella CLI reale; output completo di 1.400.341 byte identico al DTO nativo |
| Nativi prima del riesame UI | 10 definizioni, 12 esecuzioni mirate superate, più build applicativa; non è il conteggio della suite nativa globale finale |
| Gate globale intermedio | `make verify` su `1e5ced4`: superato in 679,11 s; 823 definizioni Core, 205 Kit, 129 BDD; 820 scenari e 3.347 passaggi; 3.224 dichiarazioni API, 165 fixture e 330 confronti CLI; 22 prove kill/recovery e 2 PDF/A |
| Nativi nel gate intermedio | 184 definizioni, zero failure, skip e runtime warning nel riepilogo del runner |
| Preflight intermedio | Interrotto intenzionalmente dopo il rilievo sul retry delle note: exit 130, 187,67 s; **non è un preflight superato** |
| Gate globale finale | `make verify` macOS superato in 729,51 s: Core 823, Kit 205, BDD 129 definizioni; 820 scenari e 3.347 passaggi; 194 varianti pubbliche e 7 workflow |
| API/CLI finali | 3.224 dichiarazioni pubbliche revisionate, 90 aggiunte e nessuna firma preesistente cambiata; 165 fixture native, 330 confronti di risultato completi |
| Recupero e riferimenti finali | 22 checkpoint con terminazione del processo, 248 righe di oracoli numerici e 64 casi Fraction superati; nessuna promozione scientifica implicita |
| Nativi globali finali | 189 definizioni, 503 esecuzioni incluse quelle parametrizzate, tutte superate; zero failure, skip e runtime warning del prodotto nel riepilogo `.xcresult` |
| PDF/A finale | I medesimi 2 PDF del gate conformi a PDF/A-2u con veraPDF 1.30.4, disponibile nell'ambiente della verifica |
| Preflight finale | `Scripts/check-app-store-packaging.sh --macos-only` superato in 549,24 s sul medesimo fingerprint: analisi statica e archivio senza firma; nessuna submission |

I conteggi di definizioni Swift Testing, esecuzioni parametrizzate e scenari Gherkin
espansi descrivono unità diverse. Non vengono sommati per dichiarare una copertura
maggiore. I risultati intermedi valgono per il proprio checkpoint; il codice finale
include ulteriori correzioni di editor e rollback.

## Regressioni che hanno richiesto le correzioni

Sono considerati RED soltanto i fallimenti funzionali eseguiti dal runner, non i
tentativi fermati in compilazione o dalla selezione di uno scenario non inventariato.
Le attese su citazioni, confini Unicode e conservazione del lavoro sono rimaste ferme.

| Caso | RED osservato | Correzione e riscontro |
| --- | --- | --- |
| Ingresso pubblico assente | CLI reale, scenario Study `:10`, passo 13: exit 2 invece di 0, con compilazione riuscita | Sei operazioni collegate a Kit e CLI; BDD Study e parità superate |
| Confine interno a un grafema | Scenario `:100`: anchor nuova con SHA-256 valido accettata pur dividendo l'emoji composto | Confini di carattere verificati oltre alla validità UTF-8; scenario GREEN |
| Citazione con byte diversi | Scenario `:76`: due ordini di segni combinanti risultavano equivalenti come `String`, ma il writer accettava byte diversi | Confronto degli elementi UTF-8 e immutabilità delle anchor; scenario GREEN |
| Ricaricamento da un'altra finestra | Sei test nativi verdi e una failure: gruppo salvato da una sessione indipendente assente dopo il vecchio reload | Apertura e verifica di una sessione candidata prima dell'adozione; bozza e lettura conservate; GREEN nativo |
| Retry della nuova conclusione | Regressione nativa: due note invece di una dopo errore e nuova pressione di Salva | UUID stabile per intenzione di editor; correzione della bozza e retry non duplicano la conclusione; GREEN |
| Annullamento dopo errore | Tre casi parametrizzati, nota/estratto/ripristino: proposte annullate potevano entrare in un commit successivo | Ripristino esplicito della proposta precedente; GREEN nei tre casi |
| Apertura mentre il progetto è occupato | Vista SwiftUI reale: `hasLoaded` rimaneva falso dopo il termine dell'operazione | Inizializzazione ripresa quando il modello torna libero, senza sostituire una lettura già aperta; GREEN |
| Collegamenti eliminati durante la scrittura | Seconda sessione reale: supporti e gruppo rimossi restavano nella bozza e impedivano Salva | Proiezione riconciliata usata da controlli e Salva, avviso visibile e titolo/testo conservati; selezione e pin obsoleti rimossi; GREEN |
| Estratto eliminato durante la modifica | Salva sull'ID assente non generava l'errore atteso | Failure tipizzata `study.unknown-excerpt`, nessun falso successo, titolo conservato e generazione invariata; GREEN |

Il riesame UI ha eseguito 20 definizioni e 24 esecuzioni native: RED con 17
definizioni superate e tre fallite; GREEN con tutte e 20 superate, zero failure,
skip e runtime warning del prodotto. Un primo tentativo fermato in compilazione
per la view non inclusa nel target test non è contato come RED funzionale.

Il rifiuto di tre pin usa `study.resource-limit`/`insufficientResources`, coerentemente
con il limite di due di GS-API-007. Gli altri riferimenti pendenti rimangono rifiuti
`invalidInput` con codici specifici. La corruzione persistente segue `readOnlyRecovery`;
non viene etichettata `unchanged` per rendere positiva un'attesa.

## Prova interattiva e limiti manuali

Questa sezione descrive il checkpoint `4799dc8`. Dopo lo sblocco, il riesame ha
completato il salvataggio e la riapertura delle conclusioni, ma ha anche
dimostrato che il precedente layout verticale lasciava difetti di composizione
e di misura della finestra. Correzioni, RED/GREEN e nuove prove sono registrati
separatamente in [GS-VER-345](GS-VER-345-scorrimento-studio.md); i gate di questo
checkpoint non attestano quelle modifiche successive.

Sul Mac è stato osservato un percorso reale in italiano con una fonte TXT:
selezione nativa → anteprima → titolo → raccolta della citazione. Il taccuino è stato
reso visibile mediante apertura manuale; una conclusione è stata compilata con un
passaggio di supporto. Cmd-W ha conservato il foglio e il testo della bozza.
Il tentativo di Salva è stato interrotto dal blocco del Mac: non prova il salvataggio
interattivo della conclusione.

La review ha individuato un header non visibile nel layout ampio e la mancata apertura
automatica del taccuino dopo Salva. Il codice finale usa il layout verticale adattivo
e mostra il taccuino dopo il salvataggio della conclusione; build e prove native
successive sono superate. **Il risultato visivo finale non è stato ricontrollato**,
in attesa dello sblocco manuale del Mac.

La prova limitata di tastiera non equivale a un audit completo. VoiceOver,
Voice Control, tastiera completa, contrasto, testo grande, pseudo-lingua e
destra-sinistra non sono attestati qui come verifiche manuali concluse. L'intuitività
richiede inoltre osservare persone rappresentative leggere, raccogliere, concludere
e ritrovare le fonti; i conteggi dei test non certificano questo risultato.

## Riesame delle aree toccate — GS-STD-001-29 § 29.6

| Area | Riscontro e limite |
| --- | --- |
| API | GS-API-007, commenti delle API, 3.224 dichiarazioni e parità completa verificati nel gate finale |
| Correttezza | Anchor immutabili, confini di carattere, byte esatti e rifiuti atomici coperti da regressioni |
| Concorrenza | Sessioni indipendenti, ownership delle letture e completamenti tardivi verificati nei test nativi |
| Dati | Reader 4 lazy, compatibilità precedente, revisioni e provenienza conservati nelle prove Core/Kit |
| Sicurezza/privacy | Fixture sintetiche; nessuna nuova dipendenza di terzi, rete, telemetria o entitlement |
| Accessibilità/localizzazione | Controlli ed etichette native; limiti degli audit manuali dichiarati sopra |
| Piattaforma | AppKit/NSTextView e PDFKit; lettura e lifecycle nativi, prova visiva finale ancora da completare |
| Prestazioni/energia | Preparazione del testo e parsing PDF fuori dal Main Actor, limiti prima della materializzazione; profiling Instruments non attestato |
| Test/evidenza | RED/GREEN descritti, parità e risultati finali identificati; sanitizer aggiuntivi non attestati |
| Documentazione | RF-089, ADR-0048, DoR, GS-API-007, UX18 e CMP-344; manifest, preflight e pulizia registrati in questa evidenza |

## Conservazione delle prove

Il coordinamento conserva manifest, riepiloghi macchina, log utili sanitizzati e
risultati `.xcresult` prima di pulire i soli artefatti della sessione. Origini locali:
`glifi-study-344-red.log`, `glifi-study-grapheme-red.log`,
`glifi-study-quote-bytes-red.log`, `glifi-study-bdd-green.log`,
`glifi-study-package-tests.log`, `glifi-study-native-red2.log`,
`glifi-study-note-retry-red2.log`, `glifi-study-note-retry-green.log`,
`glifi-study-cancel-red.log`, `glifi-study-cancel-green.log`,
`glifi-study-344-verify.log` e `glifi-study-344-packaging.log`.
Il checkpoint `c0e3431` usa `glifi-study-344-final-verify.log` e
`glifi-study-344-final-packaging.log`; quello finale `4799dc8` usa
`glifi-study-review-verify.log` e `glifi-study-review-packaging.log`.
Il riesame UI conserva `glifi-study-review-red2` e `glifi-study-review-green`,
con log, riepiloghi e risultati `.xcresult`.
Questi nomi identificano le prove di origine; `/tmp` non è l'archivio permanente.

## Pulizia della sessione

Le prove utili sono conservate nella cache locale delle evidenze GS-VER-344:
manifest, riepiloghi, log, report Cucumber, PDF conformi e risultati `.xcresult`.
Le cache gestite completate sono state rimosse mediante `make clean-cache` dopo
averne conservato le prove: 3.884.180 KiB prima del riesame e 3.896.524 KiB dopo.
Della cache intermedia interrotta sono stati rimossi 2.911.604 KiB di prodotti
rigenerabili, con ownership e inattività verificate, conservando l'app della prova
grafica ancora aperta e i suoi file. Le rimozioni misurate sulle tre cache sono
10.692.308 KiB allocati, circa 10,20 GiB, oltre ai temporanei headless.

I file temporanei dei test, gli input sintetici headless e le copie temporanee delle
prove archiviate sono stati rimossi. Restano l'app della prova grafica e il suo
progetto sintetico finché la sessione bloccata non può essere chiusa senza perdere
la bozza. Cache preesistenti, toolchain, dipendenze, file utente e worktree con
modifiche uniche sono conservati. I lock esterni delle cache non sono eliminati.
