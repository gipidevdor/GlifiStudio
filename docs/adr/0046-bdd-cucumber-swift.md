<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0046 — Specifiche comportamentali eseguibili con CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0046 |
| Tipo | Decisione di verifica e dipendenza di sviluppo |
| Versione | 1.1.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di integrare BDD con Cucumber Swift; richiesta successiva di rispettare tutte le licenze per il riesame delle attribuzioni |
| Riferimenti | GS-STD-001-13; GS-STD-001-16; GS-DOR-332; GS-VER-333; RQ-027; RQ-058; RQ-060; RQ-062; RQ-063 |

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
Il trait `Macros` resta disabilitato e non si compila `swift-syntax`.
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
| Licenza | MIT delle due dipendenze e dei materiali Cucumber incorporati; copyright, permesso e disclaimer integrali in `Config/Licenses/bdd-tools.txt` e nella risorsa del test bundle; fonti e limiti storici distinti nella sezione sulle attribuzioni indirette |
| Sicurezza | Il build tool selezionato genera Swift nel proprio workdir senza permessi aggiuntivi di scrittura nel package o rete; le feature sono originali versionate, gli scenari non eseguono input personali |
| Dimensione e costo | Due soli package risolti; nessun `swift-syntax`, macro o framework runtime di produzione. I sorgenti dei componenti selezionati occupano circa 652 KiB sul filesystem di review; questo dato non misura il tempo di build, RAM o dimensione del binario |
| Stabilità API | Versione esatta e integrazione nel solo adattatore di test; il requisito di conformità esterna è isolato e governato da GS-WVR-005; gli aggiornamenti non sono assunti compatibili senza compilazione e prove |

La misura dei sorgenti comprende runner Swift Testing, generatore, parser
Gherkin condiviso e sorgenti Expressions; esclude `.git`, build e componenti
upstream non selezionati. Non costituisce una qualifica prestazionale.

## Attribuzioni indirette e copie degli strumenti

Il riesame richiesto dopo l'integrazione identifica due materiali da trattare
anche in assenza di pin SwiftPM propri:

| Materiale incorporato | Fonte primaria della licenza e ambito della revisione |
| --- | --- |
| Dialetti Gherkin in `Languages.swift` e nei tipi di passo localizzati | [Cucumber/Gherkin MIT](https://raw.githubusercontent.com/cucumber/gherkin/81ef221bd9e1f0d41b62e3986c5dd61439641117/LICENSE), snapshot di revisione `81ef221bd9e1f0d41b62e3986c5dd61439641117`; copyright 2017 Cucumber Ltd, Gaspar Nagy, Björn Rasmusson, Peter Sergeant e contributori |
| Diagnostica delle espressioni adattata in `SyntaxError.swift` | [Cucumber Expressions MIT](https://raw.githubusercontent.com/cucumber/cucumber-expressions/eb1ad273949ad8bfd20632f73f1959bae6135a45/LICENSE), snapshot di revisione `eb1ad273949ad8bfd20632f73f1959bae6135a45`; copyright 2016 Cucumber Ltd e contributori |

Questi SHA fissano il testo di licenza primario riesaminato; **non** identificano
la revisione storica esatta adattata dalle dipendenze Swift. L'inventario e gli
avvisi devono conservare questa distinzione. I materiali non diventano
contributi BSD del progetto per la loro incorporazione nel runner.

SwiftGen è un generatore usato upstream con template proprio: questa decisione
non lo aggiunge come dipendenza né copia i suoi template. I dati Cucumber
incorporati richiedono comunque i propri avvisi, indipendentemente dallo
strumento che ha generato il file Swift.

I testi MIT completi delle quattro attribuzioni sono conservati in
`Config/Licenses/bdd-tools.txt` e copiati byte per byte nella risorsa `Licenses`
di `GlifiBDDTests`. Un test Swift separato dagli scenari Gherkin verifica il
contenuto nel bundle compilato; il verificatore statico controlla la
corrispondenza delle copie. Il semplice uso esclusivo nei test non elimina
gli obblighi sulle copie: test bundle, strumenti e artefatti CI distribuiti
devono mantenere gli avvisi applicabili insieme al materiale.

Ogni pin remoto del lockfile richiede una voce revisionata propria, fonte
immutabile della licenza sul commit risolto e avviso completo. Questa verifica
del grafo non scopre da sola materiali adattati senza package manager; il
riesame del sorgente resta necessario quando cambia la dipendenza.

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
risultati mirati e `make verify` nel profilo macOS. L'evidenza GS-VER-332
registra l'integrazione iniziale; GS-VER-333 registra il successivo riesame
delle attribuzioni e dei relativi controlli. Queste evidenze non costituiscono
certificazione legale universale né ricostruzione della provenienza storica
completa; l'esistenza della ADR non promuove capacità scientifiche o criteri
G4/G5.
