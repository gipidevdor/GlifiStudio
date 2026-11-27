<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Specifiche BDD con CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-BDD-001 |
| Tipo | Contratto di verifica comportamentale |
| Versione | 1.0.0 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di integrare BDD con Cucumber Swift |
| Riferimenti | ADR-0046; GS-STD-001-16 § 16.5; GS-DOR-332; GS-TST-001; GS-API-003; CMP-332 |

## Esecuzione

```sh
make test-bdd
make test
make verify
```

`make test-bdd` esegue la suite comportamentale mirata; `make test` esegue i
test del package. `make verify` include la suite nel gate completo macOS, con
unit test, oracoli, parità CLI/Kit e test applicativi. Il normale `swift test`
del package include anch'esso BDD, ma l'esecuzione diretta non applica il
controllo di completezza del report descritto sotto.
Per il lavoro Xcode si usa sempre `GlifiStudio.xcworkspace`.

`make test-bdd`, `make test` e `make verify` controllano il report Cucumber
JSON contro l'[inventario versionato](../../Config/Testing/bdd-coverage.json)
e richiedono tutti gli scenari espansi e tutti i passaggi superati. Report vuoto,
feature omesse, esempi duplicati e passaggi falliti, indefiniti o saltati
fanno fallire il comando. L'inventario associa digest delle feature, posizioni
degli scenari espansi e numero esatto di passaggi, compreso il contesto comune.
Il report temporaneo viene rimosso alla fine; gli
esiti da conservare si registrano nell'evidenza del lotto. L'inventario
corrente comprende **8 feature, 122 scenari espansi e 697 passaggi**, incluso
il contesto comune di ciascuno scenario.

La completezza del report e l'exit status di Swift Testing sono entrambi
obbligatori. Il reporter CucumberSwift 6.9.0 registra gli esiti dei passaggi,
ma non serializza l'esito complessivo dello scenario: una failure nel cleanup
`AfterScenario` può lasciare i passaggi JSON superati. Swift Testing registra
anche quella failure e fa fallire il comando; il solo JSON non costituisce
prova di successo globale. Ogni comando controllato usa un percorso temporaneo
nuovo e respinge quindi anche report assenti o selezioni senza scenari.

Il target `GlifiBDDTests` risiede in
`Packages/GlifiCore/Tests/GlifiBDDTests`. CucumberSwift **6.9.0** fornisce
`CucumberSwiftTesting`; `CucumberSwiftTestingPlugin` genera un test Swift
Testing per scenario, compresi gli esempi degli schemi di scenario. Le feature
sono sorgenti versionati; il codice generato è un artefatto rigenerabile della
cache di build. Non è richiesto aggiungere una classe XCTest per ogni feature.

Il trait `Macros` è disabilitato: gli step usano la DSL ordinaria e non
richiedono compilare `swift-syntax`. Manifest, lockfile, licenze dirette e
transitive sono riesaminati insieme secondo
[ADR-0046](../adr/0046-bdd-cucumber-swift.md).

## Scrittura e manutenzione

Ogni feature dichiara `# language: it` e l'intestazione SPDX del progetto.
Titoli e passi Gherkin usano il lessico italiano del dominio; identificatori,
nomi Swift e commenti di implementazione restano in inglese. Lo scenario
esprime un comportamento osservabile: una condizione iniziale, un'azione e
attese esplicite. Un semplice controllo di assenza di eccezioni non basta
quando il contratto prevede conteggi, posizioni, identità, contenuto o failure.

Gli schemi di scenario usano esempi con valori attesi dichiarati. Per errori
si verificano categoria e codice tipizzato, oltre allo stato conservato dove
pertinente. Per persistenza e riuso si confrontano generazione e identità
stabili; per query Unicode si risolve il risultato verso il testo sorgente.
I valori scientifici restano verificati anche dagli oracoli indipendenti già
esistenti: il confronto Kit/CLI condivide il Core e non basta da solo.

Con il generatore CucumberSwift 6.9.0 è stata osservata la mancata
sostituzione dei placeholder dentro le DocString degli schemi di scenario.
I parametri degli esempi vanno quindi scritti nel testo del passo; una
DocString contiene soltanto input completi di scenari singoli. I passi che
ricevono JSON raw preservano gli escape con un matching esplicito, senza
decodifica intermedia come stringa Cucumber. La suite verifica l'input
effettivamente ricevuto; non modifica né sostituisce il parser upstream.

Ogni scenario possiede fixture sintetiche e un eventuale progetto temporaneo,
rimossi alla fine anche in caso di errore. Non usa corpus personali, rete,
ordine di esecuzione o pause arbitrarie per attendere il risultato. Le feature
non dipendono dallo stato lasciato da uno scenario precedente.

Un nuovo comportamento richiede nello stesso cambiamento feature, step,
inventario, documentazione e controlli. Step mancanti o ambigui devono far
fallire la suite; una feature priva di test eseguiti non è evidenza positiva.

L'inventario `Config/Testing/bdd-coverage.json` conserva `sourceSHA256` per
ogni feature e le coppie `line`/`stepCount` degli scenari espansi, compresi i
passaggi del contesto comune. Per aggiornarlo si eseguono il generatore e il
runner upstream, si leggono posizioni e numero di passaggi dal report
Cucumber e si riesaminano i cambiamenti insieme alle feature. Il progetto
non mantiene un secondo parser Gherkin per calcolare le espansioni. Un digest
nuovo richiede review del sorgente; l'inventario non va adattato per rendere
positivo un report incompleto o fallito.

Una selezione mirata tramite filtri di `swift test` o `CUCUMBER_TAGS` serve
allo sviluppo e non sostituisce la verifica completa prima della consegna:
un'esecuzione parziale non soddisfa il controllo del report di `make test-bdd`,
`make test` o `make verify`.

L'inventario si aggiorna dal sorgente Swift emesso da
`CucumberSwiftTestingGenerator` della revisione bloccata: ciascun
`GherkinScenario` contiene la posizione dello scenario o dell'esempio espanso
e i passaggi già comprensivi del contesto. Non si conta il Gherkin con un
parser sostitutivo. Dopo la revisione della feature si registrano digest SHA-256,
righe degli scenari e conteggi dei passaggi; il controllo statico respinge
file nuovi, rimossi o modificati senza l'aggiornamento corrispondente.

## Copertura e confini

La collezione attraversa i comportamenti di dominio condivisi e la CLI
macOS: progetto/fonti, ricerca, analisi, persistenza, codifica ed export.
L'inventario versionato della suite e l'evidenza del lotto identificano
scenari, varianti effettive ed esiti. La matrice di
[GS-TST-001](../pianificazione/scenari-di-analisi.md) continua a inventariare
le varianti pubbliche delle analisi; la parità permanente resta governata da
[GS-API-003](../api/03-parita-continua-cli.md).

| Feature | Scenari espansi | Comportamenti e oracoli principali |
| --- | --- | --- |
| [ProjectLifecycle](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/ProjectLifecycle.feature) | 11 | Progetto vuoto, import TXT/Markdown/Unicode, revisioni incorporate e riapertura senza fonte esterna, sessione chiusa, UTF-8 e file non validi |
| [TextQuery](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/TextQuery.feature) | 14 | Termini, frasi, prossimità e regex ammesse con intervalli UTF-8 esatti, assenza di risultati, capability e regex rifiutate, failure riservate e stato conservato |
| [AnalyticalMethods](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/AnalyticalMethods.feature) | 27 | Distanze, z-score, tassi e TF/IDF, associazioni e collocazioni, χ² Pearson/Yates, CA e MDS, linkage, Naive Bayes e LDA, codifica/crosstab, foresta minima e coordinate linguistiche con forme chiuse o conteggi manuali; popolazioni degeneri rifiutate |
| [CorpusAnalysis](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/CorpusAnalysis.feature) | 18 | Vocabolario e scope, limiti anche a cache calda, riuso dopo riapertura, conteggi manuali, χ² e Jaccard con attese esplicite, cancellazione e planner con dati insufficienti |
| [AnalyticalMethods](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/AnalyticalMethods.feature) | Sei distanze, z-score, tassi e ponderazioni TF/IDF, associazione e collocazioni, Pearson/Yates, CA e MDS, clustering gerarchico, Naive Bayes e LDA, codifica automatica/crosstab, foresta minima, Unicode e casi degeneri con valori manuali |
| [QualitativeCoding](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/QualitativeCoding.feature) | 10 | Passaggi con accenti ed emoji, confini Unicode e range rifiutati, codebook, codifiche e memo persistenti |
| [ScientificExport](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/ScientificExport.feature) | 11 | Bundle, lineage e digest, escaping CSV, file mancanti o inattesi, contenuto alterato e provenienza |
| [CLIParity](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/CLIParity.feature) | 20 | Esecuzione del binario CLI, protocollo JSON e stato testuale, import e riapertura, profilo e query coerenti con Kit, exit status e guida |
| [RequestValidation](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/RequestValidation.feature) | 11 | JSON ambiguo o fuori contratto, UTF-8, profondità e dimensione, failure tipizzate senza contenuti sensibili |

BDD non attesta tutte le combinazioni di input, comportamento visivo,
VoiceOver, Voice Control, tastiera, usabilità, prestazioni o correttezza di
ogni metodo scientifico. Non esegue né qualifica iPadOS. Questi ambiti restano
nei test e audit dedicati; nessuna capacità o ValidationManifest viene
promossa per la sola presenza di una feature. Le regressioni numeriche
GS-VER-328, il modello di selezione macOS GS-VER-329 e il legame fra export e
sessione aperta GS-VER-331 conservano i propri test dedicati: le feature BDD
non dichiarano di esercitare questi tre ambiti.
