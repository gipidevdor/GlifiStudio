<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0046 — Specifiche comportamentali eseguibili con CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0046 |
| Tipo | Decisione di verifica e dipendenza di sviluppo |
| Versione | 1.0.1 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di integrare BDD con Cucumber Swift e scenari completi |
| Riferimenti | GS-STD-001-13; GS-STD-001-16; GS-DOR-332; RQ-027; RQ-058; RQ-060; RQ-062; RQ-063 |

## Contesto

Il repository dispone di test unitari, integrazione, oracoli numerici, scenari
analitici e verifiche di parità Kit/CLI. La richiesta aggiunge specifiche
comportamentali leggibili in italiano che eseguano operazioni reali e verifichino
risultati osservabili, precondizioni, failure e conservazione dello stato.
La quantità di scenari non dimostra da sola la completezza del prodotto.

## Decisione

Si adotta [CucumberSwift](https://github.com/cucumberswift/CucumberSwift) come
dipendenza SwiftPM esclusivamente dei test: versione esatta **6.9.0**, commit
`5547f9025c0da3f0276a22a3c746bfebc405741f`. Il target `GlifiBDDTests` del package
`Packages/GlifiCore` usa `CucumberSwiftTesting` con Swift Testing e il build tool
`CucumberSwiftTestingPlugin`, che genera test dalle feature nel proprio workdir.
La dipendenza dichiara esplicitamente `traits: []`: i trait predefiniti,
incluso `Macros`, restano disabilitati e non si compila `swift-syntax`.
L'omissione di `traits` non è equivalente: il manifest upstream abilita
`Macros` quando l'ambiente contiene `SPI_BUILD`. La scelta esplicita impedisce
che quel default ambientale cambi il grafo adottato. La semantica dell'insieme
vuoto è definita dalla
[documentazione SwiftPM](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies/#Packages-with-Traits).
Le revisioni transitive sono registrate nel lockfile versionato;
licenze e provenienza rientrano nell'inventario controllato. Il responsabile
interno della dipendenza è l'iniziatore del progetto.

Il runner 6.9.0 richiede la conformità retroattiva del proprio tipo `Cucumber`
al proprio protocollo `StepImplementation`: il singleton controlla questa
conformità e non espone injection equivalente. La sola soppressione locale
della regola di formattazione è registrata, con scadenza e piano di rientro, in
[GS-WVR-005](../deroghe/GS-WVR-005-conformita-cucumber-test.md). Il controllo
globale resta attivo e l'eccezione non si estende ai target di produzione.

Le feature Gherkin usano il dialetto italiano, descrivono un comportamento per
scenario e chiamano API reali attraverso step Swift. Fixture e valori attesi
sono sintetici e originali. Ciascuno scenario isola il proprio progetto e pulisce
gli eventuali file temporanei. Gli esempi tabellari espandono varianti con attese
esplicite; non limitano il controllo al solo successo della chiamata.

Il runner deve fallire per feature non leggibili, assenza degli scenari previsti,
step mancanti o ambigui e asserzioni non soddisfatte. Una suite vuota o una feature
descrittiva priva di esecuzione non costituisce evidenza positiva. Cancellazione
e asincronia usano i contratti del runtime e sincronizzazione controllata, senza
pause arbitrarie per determinare l'esito.

`make test-bdd` esegue la suite mirata; il normale `swift test` e il percorso
`make verify` macOS la includono. I risultati distinguono
comportamenti coperti e limiti: test headless non attestano interazione UI,
VoiceOver, prestazioni, affidabilità su ogni corpus o verifica iPadOS.

## Alternative considerate

- **Swift Testing e XCTest senza Gherkin:** restano i framework nativi per
  asserzioni e test esistenti; da soli non eseguono le feature richieste.
- **Parser e runner Gherkin interni:** richiederebbero mantenere dialetti,
  espansione degli esempi, matching e report senza beneficio di prodotto.
- **Cucumberish e strumenti di altre piattaforme:** non vengono aggiunti;
  CucumberSwift soddisfa la richiesta con un adattatore Swift nel confine test.

## Valutazione della dipendenza

| Aspetto | Valutazione sulla revisione selezionata |
| --- | --- |
| Manutenzione | Release 6.9.0 del 2026-11-25, documentazione del runner Swift Testing, fixture consumer e test del generatore presenti nel repository upstream; la manutenzione futura resta una responsabilità da riesaminare |
| Licenza | MIT letta nei due checkout puliti corrispondenti ai commit/tag risolti e confrontata con le fonti primarie ai commit; copyright e permesso integrali conservati in `Config/Licenses/bdd-tools.txt`; digest dei due LICENSE in GS-LIC-002 |
| Sicurezza | Il build tool selezionato genera Swift nel proprio workdir senza permessi aggiuntivi di scrittura nel package o rete; le feature sono originali versionate, gli scenari non eseguono input personali |
| Dimensione e costo | Due soli package risolti; nessun `swift-syntax`, macro o framework runtime di produzione. I sorgenti dei componenti selezionati occupano circa 652 KiB sul filesystem di review; questo dato non misura il tempo di build, RAM o dimensione del binario |
| Stabilità API | Versione esatta e integrazione nel solo adattatore di test; il requisito di conformità esterna è isolato e governato da GS-WVR-005; gli aggiornamenti non sono assunti compatibili senza compilazione e prove |

La misura dei sorgenti comprende runner Swift Testing, generatore, parser
Gherkin condiviso e sorgenti Expressions; esclude `.git`, build e componenti
upstream non selezionati. Non costituisce una qualifica prestazionale.

## Conseguenze e aggiornamento

Il grafo delle dipendenze di sviluppo cresce; i target di produzione e i bundle
distribuiti non dipendono da CucumberSwift. I report possono contenere testo
delle fixture e restano artefatti di test locali o CI; non elaborano corpus
personali né introducono telemetria applicativa.

Gli aggiornamenti richiedono review di changelog, licenze, dipendenze transitive,
compatibilità Swift 6 e prove della suite e dei gate esistenti. Il build tool
selezionato non richiede permessi di scrittura nel package o accesso alla rete;
gli altri plugin e le macro opzionali non vengono adottati implicitamente.
In caso di incompatibilità o
cessata manutenzione si conserva il contratto delle feature e si sostituisce il
runner con una decisione successiva; non si disabilitano gli assert per
conservare una dipendenza. La rimozione dell'integrazione non richiede migrazioni
di documenti `.glifi`.

## Verifica della decisione

La consegna richiede scenari nominali e negativi eseguibili, inventario delle
feature, controlli del runner, dipendenze riproducibili e licenze verificate,
risultati mirati e `make verify` nel profilo macOS. L'evidenza GS-VER-332 registra
comandi, risultati e limiti effettivi; l'esistenza di questa ADR non promuove
capacità scientifiche o criteri G4/G5.
