<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-332 — Specifiche comportamentali con CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-332 |
| Tipo | Integrazione di verifica BDD e dipendenza di sviluppo |
| Versione | 1.0.0 |
| Stato | Superato localmente: BDD seriale/parallelo e gate completo macOS |
| Responsabile | Codex, con verifica serializzata dall'integratore |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di integrare BDD con Cucumber Swift e scenari completi |
| Riferimenti | GS-DOR-332; ADR-0046; GS-BDD-001; GS-WVR-005; GS-STD-001-13; GS-STD-001-16 § 16.5; CMP-332 |

## Integrazione osservata

Il manifest SwiftPM dichiara CucumberSwift **6.9.0** esatto. Il lockfile risolve
soltanto CucumberSwift, commit `5547f9025c0da3f0276a22a3c746bfebc405741f`, e
CucumberSwiftExpressions **1.4.2**, commit
`ab4c6482d3230d24a13814a961b6fff1d50f830f`. Il target `GlifiBDDTests` usa
`CucumberSwiftTesting` e `CucumberSwiftTestingPlugin`; il trait `Macros` non è
abilitato e `swift-syntax` non compare nel lockfile.

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
| `python3 -B Scripts/check-compliance.py` | Superato con CMP-332 verificata e collegata alle evidenze runtime |
| `python3 -B Scripts/check-licenses.py` | Superato: 25 materiali inventariati, incluse le due dipendenze di sviluppo |
| `python3 -B Scripts/check-licenses-tests.py` | Superati 9 test del verificatore di licenze |
| `make test-bdd` | Exit 0: 8 feature, 116 scenari espansi, 655 passaggi superati |
| `CUCUMBER_PARALLEL_TESTING=YES make test-bdd` | Exit 0: stessi scenari e passaggi, con stato isolato per scenario |
| `Scripts/check-bdd.py --self-test --report` | Inventario e report allineati; regressioni negative del gate superate |
| `make verify` con profilo macOS | Exit 0: statici, oracoli, test SwiftPM, parità CLI/Kit, recovery, test app e build Debug/Release superati |

Il gate completo ha riconfermato formattazione strict, documenti, compliance,
licenze e inventario sul codice finale. Gli esiti strutturati sono conservati
nell'[allegato di verifica](allegati/GS-VER-332-verifica.json).

## Prima esecuzione e correzione delle feature

Nel primo run l'integratore ha osservato il superamento dei 58 esempi di
workflow allora presenti e 14 issue negli scenari CLI. Le issue hanno
rilevato placeholder come `<testo>` e `<richiesta>` rimasti letterali nelle
DocString degli schemi di scenario generati da CucumberSwift 6.9.0.
L'integrazione corregge le feature passando i parametri nel testo dei passi;
il JSON raw mantiene gli escape attraverso un matching esplicito. Le
DocString restano per input completi di scenari singoli.

La correzione riguarda le fixture e il loro adattatore, senza fork o
modifiche dei test upstream. Il run iniziale resta una prova parziale;
l'esecuzione completa successiva include anche le famiglie analitiche
aggiuntive e la correzione CLI.

## Esecuzione BDD completa osservata

L'integratore ha osservato il superamento di **116 esempi espansi**, in
**8 feature**, con **655 passaggi**. Swift Testing riporta 60 test, inclusi
quelli parametrizzati dagli schemi di scenario; questo conteggio differisce
dagli esempi espansi nel report Cucumber. Il controllo
`Scripts/check-bdd.py --self-test --report` ha superato sia le regressioni
negative del verificatore sia il confronto del report con l'inventario.
Il [report Cucumber conservato](allegati/GS-VER-332-cucumber.json) contiene
scenari e passaggi effettivi, con percorsi delle feature normalizzati.

Il report upstream rappresenta i tag senza il prefisso `@`; il verificatore
rispetta quel formato conservando nelle feature la sintassi Gherkin completa.
Le ripetizioni tramite `make test-bdd`, sia in sequenza sia con
`CUCUMBER_PARALLEL_TESTING=YES`, hanno superato gli stessi 116 esempi e
655 passaggi, con controllo del report ed exit status zero. Il gate macOS
ha riconfermato lo stesso inventario senza passaggi saltati.

## Inventario e manutenzione della copertura

L'[inventario](../../Config/Testing/bdd-coverage.json) associa a ogni feature il digest
`sourceSHA256` e, per ogni scenario espanso, la posizione `line` e il numero
esatto di passaggi `stepCount`, compreso il contesto comune. Le posizioni e
cardinalità provengono dal report prodotto dal parser/runner upstream; non
sono ricavate con un secondo parser Gherkin interno.

Una modifica delle feature richiede eseguire nuovamente il generatore e la
suite, riesaminare le nuove attese ed aggiornare l'inventario nello stesso
lotto. Non si aggiorna l'inventario al solo scopo di accettare un report
incompleto o fallito. La guida GS-BDD-001 descrive famiglie e limiti; il report
finale determina conteggi ed esiti effettivamente dichiarabili.

## Verifica finale macOS

`make verify` è terminato con exit status zero su macOS 27.2.1, Xcode 27.2
(27B52), Apple Swift 6.4.2 e Python 3.12.14. È stato selezionato il Python
mise già installato, come previsto da GS-DEV-001, e il validatore veraPDF
1.30.4 già presente nella cache degli strumenti. Il Python 3.9 di sistema
non soddisfa i prerequisiti del gate generale; non è stato modificato.

Sono superati anche i 135 test dell'app macOS, senza fallimenti o test
saltati, la validazione di due PDF/A-2u, i 264 confronti Kit/CLI per 132
operazioni e i 22 checkpoint di recovery. Il controllo del bundle Release
ha verificato risorse, licenze e assenza dei payload di sviluppo previsti
dal proprio contratto. Un'ispezione aggiuntiva non trova elementi Cucumber
nel bundle o collegamenti dinamici a Cucumber nel binario dell'app.

La verifica comprende il working tree corrente, incluse le modifiche
preesistenti conservate. L'allegato identifica HEAD, impronta dei sorgenti,
inventario e report; gli artefatti rigenerabili di build e i download
ridondanti vengono rimossi dopo l'estrazione delle evidenze utili.

BDD headless non qualifica UI, VoiceOver, Voice Control, tastiera, usabilità,
prestazioni, iPadOS, tutte le combinazioni numeriche o G4/G5. Oracoli
scientifici, inventario analitico e verifiche di parità restano necessari.
