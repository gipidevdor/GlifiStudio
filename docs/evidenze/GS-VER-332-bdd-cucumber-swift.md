<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-332 — Specifiche comportamentali con CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-332 |
| Tipo | Integrazione di verifica BDD e dipendenza di sviluppo |
| Versione | 1.0.0 |
| Stato | Superato nel profilo automatico macOS |
| Responsabile | Codex, con verifica serializzata dall'integratore |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di integrare BDD con Cucumber Swift e scenari completi |
| Riferimenti | GS-DOR-332; ADR-0046; GS-BDD-001; GS-WVR-005; GS-STD-001-13; GS-STD-001-16 § 16.5; CMP-332 |

## Integrazione osservata

Il manifest SwiftPM dichiara CucumberSwift **6.9.0** esatto. Il lockfile risolve
soltanto CucumberSwift, commit `5547f9025c0da3f0276a22a3c746bfebc405741f`, e
CucumberSwiftExpressions **1.4.2**, commit
`ab4c6482d3230d24a13814a961b6fff1d50f830f`. Il target `GlifiBDDTests` usa
`CucumberSwiftTesting` e `CucumberSwiftTestingPlugin`. `traits: []` disabilita
esplicitamente i default upstream: anche una risoluzione con `SPI_BUILD=1`
produce soltanto i due package previsti, senza `swift-syntax`.

Il generatore upstream trasforma le feature italiane in test Swift Testing.
Gli step chiamano API reali e, per gli scenari CLI, il binario headless.
Fixture sintetiche, progetti isolati e cleanup mantengono la suite indipendente
dai corpus personali e dallo stato di altri scenari. Non sono modificati API
di prodotto, formati `.glifi`, entitlement o policy di rete e telemetria.

`make test-bdd` è il comando mirato; il normale `swift test` e `make verify`
includono il target. Il verificatore del report richiede esecuzione completa
e passaggi superati: il successo del processo di test da solo non basta.

## Provenienza e controllo del confine test

Le licenze MIT sono state lette nei checkout delle revisioni risolte e
conservate integralmente in `Config/Licenses/bdd-tools.txt`. L'inventario
controllato include entrambe le dipendenze e i digest di manifest, lockfile
e avvisi. La configurazione globale Swift resta invariata; l'unica conformità
retroattiva necessaria al runner è circoscritta da GS-WVR-005, con scadenza e
piano di rientro.

## Verifiche strutturali osservate

| Comando | Esito e ambito |
| --- | --- |
| `python3 -B Scripts/check-docs.py` | Superato dopo l'introduzione di ADR, DoR, guida BDD, deroga e aggiornamenti dei documenti controllati |
| `python3 -B Scripts/check-compliance.py` | Superato con CMP-332 in stato `implemented`; l'esistenza della riga non attesta il superamento runtime |
| `python3 -B Scripts/check-licenses.py` | Superato: 25 materiali inventariati, incluse le due dipendenze di sviluppo |
| `python3 -B Scripts/check-licenses-tests.py` | Superati 9 test del verificatore di licenze |

Questi risultati precedevano la chiusura della suite finale. Il gate completo
li ha riconfermati insieme alla formattazione rigorosa, senza sopprimere
controlli o allargare le tolleranze.

## Prima esecuzione e correzione delle feature

Lo snapshot iniziale riportava un run parziale con 58 esempi di
workflow e 14 issue negli scenari CLI. Le note di quel run descrivevano
placeholder come `<testo>` e `<richiesta>` rimasti letterali nelle
DocString degli schemi di scenario generati da CucumberSwift 6.9.0.
L'integrazione corregge le feature passando i parametri nel testo dei passi;
il JSON raw mantiene gli escape attraverso un matching esplicito. Le
DocString restano per input completi di scenari singoli.

La correzione riguarda le fixture e il loro adattatore, senza fork o
modifiche dei test upstream. Quel resoconto è conservato come provenienza,
non come evidenza positiva di questa consegna: la composizione seguente è
stata rieseguita integralmente nella worktree isolata.

## Inventario e manutenzione della copertura

Il file `Config/Testing/bdd-coverage.json` associa a ogni feature il digest
`sourceSHA256` e, per ogni scenario espanso, la posizione `line` e il numero
esatto di passaggi `stepCount`, compreso il contesto comune. Le posizioni e
cardinalità provengono dal report prodotto dal parser/runner upstream; non
sono ricavate con un secondo parser Gherkin interno.

Una modifica delle feature richiede eseguire nuovamente il generatore e la
suite, riesaminare le nuove attese ed aggiornare l'inventario nello stesso
lotto. Non si aggiorna l'inventario al solo scopo di accettare un report
incompleto o fallito. La guida GS-BDD-001 descrive famiglie e limiti; il report
finale determina conteggi ed esiti effettivamente dichiarabili.

## Correzioni del runner e controlli negativi

Il runner CLI precedente attendeva `Process.waitUntilExit` in una task detached
senza terminazione su cancellazione: un processo bloccato poteva impedire anche
il cleanup. Il nuovo helper test-only possiede il PID fino a `waitpid`, applica
timeout e cancellazione con escalation TERM/KILL e raccoglie il figlio prima
di rimuovere le catture. I file sono privati e non si usano pipe soggette a
deadlock. Cinque test sintetici verificano output, avvio fallito,
pre-cancellazione, cancellazione attiva e timeout; i casi di escalation usano
un figlio inizialmente sospeso per evitare una race di avvio. Il contratto
riguarda il singolo processo CLI, non un albero arbitrario di discendenti.

Le precondizioni prima dell'indicizzazione di intervalli UTF-8 e matrici usano
`#require`: un risultato malformato genera una failure del test e consente
il cleanup, invece di provocare un trap.

Anche il ramo ordinario di `make test` ora verifica il report. Con
`CUCUMBER_TAGS=@__glifi_no_scenario_expected__`, Swift Testing termina con
successo e scenari filtrati, ma `make test` viene correttamente respinto per
report vuoto. Il test della cache che sostituisce Swift con uno stub produce
ora un report sintetico completo: il verificatore reale resta obbligatorio.
Una regressione aggiuntiva richiede il rifiuto dello stub senza report e il
cleanup delle sole risorse possedute; tutti i 15 test della cache passano.

Il JSON upstream da solo non certifica hook e asserzioni: è obbligatorio
anche l'exit status positivo di Swift Testing. `set -e` conserva tale vincolo
nel runner mirato, nel test ordinario e nel gate completo.

## Verifica finale osservata

| Verifica | Esito |
| --- | --- |
| Generatore upstream pinned | 8 feature, 122 scenari espansi, 697 passaggi; inventario derivato senza un secondo parser Gherkin |
| Suite mirata BDD e helper | Superata; tutte le 122 esecuzioni BDD e i cinque test del subprocesso sono verdi |
| Report effettivo | 8 feature / 122 scenari / 697 passaggi superati; nessun passo skipped, undefined o ambiguo ammesso |
| Filtro che elimina gli scenari | Rifiuto atteso di `make test`, dopo successo Swift; nessun falso verde |
| Licenze e dipendenze | 25 materiali, 21 digest verificati, avvisi MIT completi e grafo di due package anche con `SPI_BUILD=1` |
| `make verify` macOS | Exit 0 in 589,88 s: 782 test Core, 169 Kit, 135 definizioni native / 425 esecuzioni, due PDF/A-2u, 248 righe di oracoli e 64 casi Fraction |
| Parità e recovery | 132 operazioni / 264 confronti completi, sei rifiuti CLI dei metadati delle viste, 2.840 dichiarazioni pubbliche, 22 checkpoint |
| Bundle Release | Risorse e testi legali verificati; 17 elementi ispezionati, nessun nome/cartella/estensione di test vietati |

Gli input controllati sono **608**, con fingerprint finale SHA-256
`36b05ea14bbeafe91150b84edb8ab74a67a240e75b9430f553797f262714d259`,
immutato dopo l'esecuzione. Il log locale `composite-make-verify.log` ha SHA-256
`dccda4c30b675a31188afc0dce651a4aaa3d5c56f2a233bb659f9f6da2e6a28a`.
L'[allegato controllato](allegati/GS-VER-332-verifica.json) conserva riepilogo,
pin, hash e limiti. I report raw, i manifest degli input e il risultato nativo
rimangono nel dossier locale `macOS-2026-11-27-semantics`.

I cambiamenti concorrenti della copia originaria sono stati preservati.
La verifica finale è stata eseguita sulla composizione isolata autorizzata,
comprensiva di BDD e dei lotti semantici 327–331.

BDD headless non qualifica UI, VoiceOver, Voice Control, tastiera, usabilità,
prestazioni, iPadOS, tutte le combinazioni numeriche o G4/G5. Oracoli
scientifici, inventario analitico e verifiche di parità restano necessari.
