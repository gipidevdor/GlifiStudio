<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Specifiche BDD con CucumberSwift

| Campo | Valore |
| --- | --- |
| Identificatore | GS-BDD-001 |
| Tipo | Contratto di verifica comportamentale |
| Versione | 1.3.0 |
| Stato | Attivo |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di integrare BDD con Cucumber Swift |
| Riferimenti | ADR-0046; GS-STD-001-16 § 16.5; GS-DOR-332; GS-DOR-341; GS-TST-001; GS-API-003; CMP-332; CMP-341; GS-VER-333; GS-VER-334; GS-VER-341 |

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
JSON contro l'inventario e
richiede tutti gli scenari espansi e tutti i passaggi superati. Report vuoto,
feature omesse, esempi duplicati e passaggi falliti, indefiniti o saltati
fanno fallire il comando. L'inventario V2 associa digest delle feature,
identità della feature e posizione esatta e univoca di ogni scenario espanso,
numero di passaggi e digest dei metadati ordinati di ciascun passo, compreso
il contesto comune. Duplicare, sostituire o riordinare passaggi non soddisfa
il controllo, anche se conteggio ed esiti restano positivi.
Il report temporaneo viene rimosso alla fine; gli
esiti da conservare si registrano nell'evidenza del lotto. L'inventario
corrente comprende **8 feature, 122 scenari espansi e 697 passaggi**.

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

La dipendenza dichiara esplicitamente `traits: []`: gli step usano la DSL
ordinaria e non richiedono compilare `swift-syntax`. L'opt-out impedisce che
il default upstream abiliti `Macros` quando l'ambiente contiene `SPI_BUILD`.
Manifest, lockfile, licenze dirette e
transitive sono riesaminati insieme secondo
[ADR-0046](../adr/0046-bdd-cucumber-swift.md).

Il target contiene inoltre `GlifiBDDLicenseTests`, un test Swift ordinario
che legge tre file da `Bundle.module`, nella risorsa `Licenses`, e verifica
ciascun digest: `THIRD_PARTY_NOTICES.txt` con i quattro avvisi MIT BDD,
`GlifiStudio-LICENSE.txt` con la BSD del progetto e
`GlifiStudio-THIRD_PARTY_NOTICES.txt` con gli avvisi Core, inclusi Snowball e
SplitMix. Il test bundle collega anche GlifiKit e GlifiCore e deve conservare
anche questi testi. Non è uno scenario Gherkin e non aumenta i **122 esempi**
o i **697 passaggi** dell'inventario BDD. Il verificatore statico confronta
le tre risorse byte per byte con `Config/Licenses/bdd-tools.txt`, `LICENSE`
e `THIRD_PARTY_NOTICES.txt` alla radice, rispettivamente.

Le copie dei test, degli strumenti e degli artefatti CI distribuiti devono
conservare questi avvisi. Gli snapshot immutabili delle licenze Gherkin e
Cucumber Expressions documentano il testo primario riesaminato e non la
revisione storica esatta degli adattamenti. Il riesame del sorgente e delle
attribuzioni rimane distinto dal confronto automatico dei byte; dettagli e
risultati sono in [GS-VER-333](../evidenze/GS-VER-333-licenze-bdd.md).

## Ciclo di sviluppo RED → GREEN → refactor

```sh
make test-bdd-list
make test-bdd-dev BDD_SELECT='TextQuery.feature:20'
make test-bdd-dev BDD_SELECT='TextQuery.feature'
./Scripts/test.sh --bdd-dev --select 'TextQuery.feature:20,TextQuery.feature:39'
```

`test-bdd-list`, equivalente a `Scripts/test.sh --bdd-dev --list`, elenca file,
righe degli scenari espansi e conteggi dall'inventario; non compila, non richiede
Xcode e non crea o acquisisce cache. Per uno schema si sceglie la riga del
singolo esempio, non l'intestazione dello schema. Più identificatori separati
da virgole formano un'unione; il nome del file da solo seleziona tutti i suoi
scenari. Il selettore usa il nome del file senza cartelle; `:` è riservato
alla riga e non è ammesso nei nomi dell'inventario. Nomi o righe non
inventariati e selezioni vuote falliscono prima di
allocare la cache o invocare Swift.

Il comando di sviluppo trasporta la selezione a `CUCUMBER_SCENARIOS` secondo
il [contratto della revisione CucumberSwift bloccata](https://github.com/cucumberswift/CucumberSwift/blob/5547f9025c0da3f0276a22a3c746bfebc405741f/Sources/CucumberSwift/Coverage/ScenarioList.swift). Il valore passa come
dato tramite ambiente, senza valutazione come comando shell o macro Make.
Il target usa il valore letterale di `BDD_SELECT` e non esporta la variabile
originale: anche espressioni come `$(shell ...)` restano testo da convalidare. Il comando
ignora eventuali `CUCUMBER_TAGS` ereditati e sostituisce `CUCUMBER_SCENARIOS`:
il report deve contenere **esattamente** gli scenari scelti e tutti i loro
passaggi superati. Scenari aggiuntivi, omessi o duplicati, report mancanti e
passaggi saltati, indefiniti o falliti producono exit nonzero. L'esito reca
l'etichetta esplicita «BDD sviluppo» e non costituisce il gate completo.
Swift Testing può mostrare come saltati i test fuori selezione; uno scenario
selezionato mancante o un suo passaggio saltato fanno invece fallire il controllo.

Per ogni comportamento nuovo o corretto il ciclo **DEVE** essere:

1. scrivere uno scenario con fixture originale e attese osservabili, aggiornando
   l'inventario dal generatore upstream per il nuovo sorgente; eseguire la
   selezione e osservare **RED** per la proprietà attesa o lo step ancora
   indefinito. Un errore di toolchain o un inventario non allineato non dimostra
   la regressione del comportamento;
2. implementare il minimo cambiamento e rieseguire la stessa selezione fino a
   **GREEN**, conservando attese, failure e oracoli scientifici;
3. rifattorizzare e rieseguire scenari e feature interessati; prima della
   consegna eseguire `make test-bdd` e `make verify` nel profilo macOS.

I comandi completi `make test-bdd`, `make test` e `make verify` richiedono
sempre l'intero inventario: un report verde di sviluppo resta insufficiente.
La verifica del workflow è tracciata in GS-VER-334; le proprietà scientifiche,
UI e assistive continuano ad avere le evidenze dedicate.

## Ciclo di vita dei subprocessi CLI

Gli step CLI delegano l'esecuzione a `BDDSubprocess`, che possiede il figlio
diretto dal `posix_spawn` al `waitpid`, con controllo di cancellazione
sincronizzato. La durata predefinita è 30 secondi; alla cancellazione o alla
scadenza invia SIGTERM e, dopo 250 millisecondi di tolleranza, SIGKILL se il
figlio è ancora attivo. Prima di restituire l'esito raccoglie il figlio e
rimuove i file di cattura. Non viene gestito un albero di discendenti arbitrario:
il contratto riguarda soltanto il figlio diretto avviato dall'adattatore.

Stdout e stderr restano separati. Per ciascun file si controlla il limite di
**1 MiB prima di leggerlo in memoria**, dopo la terminazione del figlio.
Questo controllo non impone una quota alle scritture su disco durante
l'esecuzione. Le fixture rimangono nella directory posseduta dallo scenario
e vengono rimosse dal relativo cleanup.

`BDDSubprocessTests` contiene sei prove: flussi ed exit status, cancellazione
preventiva senza avvio, cancellazione di un figlio sospeso, scadenza dello
stesso tipo di figlio con escalation, avvio fallito e output oltre limite.
Le prove di terminazione ricevono il PID dal callback di avvio e usano
`POSIX_SPAWN_START_SUSPENDED`, senza dipendere dall'avvio della shell o da
pause arbitrarie. Verificano che `waitpid` restituisca `ECHILD`, confermando
la raccolta del figlio. Questi test Swift ordinari sono separati dai 122 esempi
Gherkin. Il limite di memoria e il controllo V2 dei metadati sono tracciati
in GS-VER-341; il ciclo di sviluppo resta tracciato in GS-VER-334.

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

L'inventario `Config/Testing/bdd-coverage.json`, schema
`studio.glifi.bdd-coverage` versione **2**, conserva `sourceSHA256` per ogni
feature e `line`, `stepCount`, `stepsSHA256` per ogni scenario espanso.
`stepsSHA256` è il digest SHA-256 della sequenza ordinata di oggetti con
`line`, `keyword` e `name` di ciascun passo, compresi i passi del contesto
comune. La serializzazione canonica è JSON UTF-8, senza escape ASCII
aggiuntivi, con chiavi ordinate e separatori compatti. Il confronto verifica
posizioni e identità dei passi, oltre alla loro cardinalità e all'esito.

Per aggiornarlo si eseguono il generatore e il runner upstream, si leggono
gli scenari e i metadati dei passi dal report Cucumber e si usa la funzione
`step_metadata_digest` del verificatore per calcolare il digest. Il progetto
non mantiene un secondo parser Gherkin per calcolare le espansioni. Un digest
nuovo richiede review del sorgente e delle attese; l'inventario non va adattato
per rendere positivo un report incompleto o fallito.

Inventario e report vengono letti come JSON rigoroso: chiavi duplicate,
`NaN`, `Infinity`, `-Infinity` e letterali che traboccano a valori floating
non finiti vengono rifiutati prima della validazione semantica. La verifica
dei tipi non tratta booleani come contatori interi. Le regressioni negative
del gate coprono questi ingressi ambigui e le alterazioni dei passaggi.

Una selezione mirata tramite filtri di `swift test` o `CUCUMBER_TAGS` serve
allo sviluppo e non sostituisce la verifica completa prima della consegna:
un'esecuzione parziale non soddisfa il controllo del report di `make test-bdd`
`make test` o `make verify`.

## Copertura e confini

La collezione attraversa i comportamenti di dominio condivisi e la CLI
macOS: progetto/fonti, ricerca, analisi, persistenza, codifica ed export.
L'[inventario versionato](../../Config/Testing/bdd-coverage.json) identifica
**122 esempi espansi e 697 passaggi** nelle otto feature correnti; l'evidenza
del lotto registra gli esiti. La matrice di
[GS-TST-001](../pianificazione/scenari-di-analisi.md) continua a inventariare
le varianti pubbliche delle analisi; la parità permanente resta governata da
[GS-API-003](../api/03-parita-continua-cli.md).

| Feature | Comportamenti e oracoli principali |
| --- | --- |
| [ProjectLifecycle](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/ProjectLifecycle.feature) | Progetto vuoto, import TXT/Markdown/Unicode, revisioni incorporate e riapertura senza fonte esterna, sessione chiusa, UTF-8 e file non validi |
| [TextQuery](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/TextQuery.feature) | Termini, frasi, prossimità e regex ammesse con intervalli UTF-8 esatti, assenza di risultati, capability e regex rifiutate, failure riservate e stato conservato |
| [CorpusAnalysis](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/CorpusAnalysis.feature) | Vocabolario e scope, limiti anche a cache calda, riuso dopo riapertura, conteggi manuali, χ² e Jaccard con attese esplicite, cancellazione e planner con dati insufficienti |
| [AnalyticalMethods](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/AnalyticalMethods.feature) | Sei distanze, z-score, tassi e ponderazioni TF/IDF, associazione e collocazioni, Pearson/Yates, CA e MDS, clustering gerarchico, Naive Bayes e LDA, codifica automatica/crosstab, foresta minima, Unicode e casi degeneri con valori manuali |
| [QualitativeCoding](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/QualitativeCoding.feature) | Passaggi con accenti ed emoji, confini Unicode e range rifiutati, codebook, codifiche e memo persistenti |
| [ScientificExport](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/ScientificExport.feature) | Bundle, lineage e digest, escaping CSV, file mancanti o inattesi, contenuto alterato e provenienza |
| [CLIParity](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/CLIParity.feature) | Esecuzione del binario CLI, protocollo JSON e stato testuale, import e riapertura, profilo e query coerenti con Kit, exit status e guida |
| [RequestValidation](../../Packages/GlifiCore/Tests/GlifiBDDTests/Features/RequestValidation.feature) | JSON ambiguo o fuori contratto, UTF-8, profondità e dimensione, failure tipizzate senza contenuti sensibili |

BDD non attesta tutte le combinazioni di input, comportamento visivo,
VoiceOver, Voice Control, tastiera, usabilità, prestazioni o correttezza di
ogni metodo scientifico. Non esegue né qualifica iPadOS. Questi ambiti restano
nei test e audit dedicati; nessuna capacità o ValidationManifest viene
promossa per la sola presenza di una feature. Le regressioni numeriche
GS-VER-328, il modello di selezione macOS GS-VER-329 e il legame fra export e
sessione aperta GS-VER-331 conservano i propri test dedicati: le feature BDD
non dichiarano di esercitare questi tre ambiti.
