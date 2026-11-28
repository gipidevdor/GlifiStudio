<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-335 — Flussi tematici, corrispondenze e dendrogrammi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-335 |
| Tipo | Evidenza di integrazione applicativa, rappresentazione e parità |
| Versione | 1.0.0 |
| Stato | Superato nello snapshot isolato; gate condiviso non attestato |
| Responsabile | Codex, integrazione coordinata nel checkout condiviso |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richieste esplicite di completamento CA/HAC e di tutti gli accessi GUI per tema di ricerca |
| Riferimenti | GS-DOR-335; ADR-0041; ADR-0043; GS-UX-001-17; GS-MET-001-14; GS-VIZ-001; GS-API-003; CMP-335 |

## Cosa cambia

Il catalogo macOS assegna a ogni destinazione un tema e uno scopo specifico.
La ricerca comprende i singoli metodi dei laboratori e le varianti; l'apertura
seleziona il metodo corrispondente e ne mostra il ruolo nel lavoro di ricerca.
Gli otto temi sono Vocabolario e stile, Relazioni e reti, Confronti e differenze,
Temi e strutture, Classificazione dei documenti, Codifica e categorie, Qualità e
validazione, Preparazione delle rappresentazioni.

CA e HAC documentale riusano le implementazioni esistenti. Il nuovo profilo
`term-document-relative-frequency-v1` applica HAC alle distribuzioni di ciascun
termine tra i documenti. Un termine conserva l'elenco dei documenti che lo
contengono: non viene trasformato in una falsa revisione sorgente. L'operazione
`hierarchicalTerms` attraversa Core, Kit, comando condiviso e CLI
`multivariate --method hac --unit terms`; la modalità documentale resta il
default. I profili selezionano gli stessi termini con criterio dichiarato,
poi li ordinano lessicograficamente.

Anche il taglio pubblico `recutDendrogram` ha un percorso operativo CLI:
`project-call` con tag `recut-visualization`, specifica `visualization` ed
esattamente uno tra `clusterCount` e `maximumHeight`. Il trasporto mantiene
risultato e failure della funzione nativa, senza mutare il progetto o
rieseguire l'analisi. Il metadato `dendrogramTree` rimane opzionale per i JSON
precedenti, mentre il nuovo taglio ne richiede la presenza e la validità.

Il dendrogramma conserva topologia e identità di foglie/fusioni nei metadati
opzionali della specifica visuale. Il taglio a numero e il taglio ad altezza
producono la partizione della vista senza rieseguire il corpus. Il taglio ad
altezza include tutte le fusioni alla soglia. Le foglie mostrano i gruppi con
colore e forma; il grafico offre zoom e scorrimento. La compressione del ramo
selezionato segue i figli dell'albero, anche quando più termini condividono
le stesse fonti; tabella ed export mantengono l'albero completo. Le righe di
fusione e i segmenti selezionabili conservano il lineage contributivo.

## Diciannove operazioni KH nella GUI

| Flusso nativo | Tag del trasporto esistente | Input e risultato |
| --- | --- | --- |
| Matrici e misure KH | `matrix-zscore`, `matrix-per-thousand`, `word-context`, `correspondence-scaled`, `kh-collocation`, `word-association`, `document-scores`, `kh-hierarchical-ward-d2`, `kh-chi-square` | Celle numeriche ed identità esplicite, esposizioni/universi dichiarati, scaling e policy; tabelle complete e JSON della richiesta/esito |
| Linguaggio, classificazione e codifica KH | `term-scores`, `term-extraction`, `incremental-classifier`, `continue-classifier`, `validate-classifier-kappa`, `code-crosstab-significance` | Candidati o preannotazioni dichiarate, classi/gruppi/regole; stato incrementale di sessione, score e diagnostici senza annotazioni inventate |
| Esplorazione KH | `mds-ordinal`, `mds-ordinal-search`, `som-pca-initialization`, `som-kh` | Matrice del corpus; parità primary/secondary, avvii/seed/tolleranza; griglia e fasi esplicite, prototipi opzionali forniti dalla persona, U-matrix e Ward |

Le richieste e gli esiti di sessione conservano i dati effettivi e i parametri
risolti. Per SOM KH sono disponibili prototipi iniziali, intermedi e finali,
numero di aggiornamenti, errori diagnostici e clustering dei codebook opzionale.
L'editor di codebook usa righe numeriche con punto o virgola decimale e rifiuta
forma incompatibile o valori non finiti. Il profilo a due fasi non espone un
seed fittizio: l'ordine di aggiornamento è quello dichiarato dal metodo.
Per MDS con più avvii si mantengono tutti gli avvii, coordinate e storie
obiettivo; non viene esportato soltanto l'avvio scelto.

## Inventario degli scenari e promozione della copertura nativa

La matrice controllata GS-TST-001 include 27 operazioni di progetto con
`recut-visualization` e 173 varianti complessive. I diciannove tag KH hanno
`nativeBindings` che collegano richiesta tipizzata, tool, route, modello,
vista, prova operativa e prova del catalogo tematico; `headlessOnly` per
queste operazioni è vuoto. Il verificatore richiede copertura nativa/headless
esaustiva e disgiunta rispetto al compilatore, senza accettare una semplice
rimozione dalla lista headless. I nuovi controlli negativi rifiutano binding
mancanti o incompatibili, test assenti e sovrapposizioni. Il controllo statico
della mappa resta distinto dall'esecuzione nativa descritta sotto.

## Piano di verifica ed esiti osservati

Il [rapporto strutturato finale](allegati/GS-VER-335-verifica.json) conserva
conteggi, exit status, digest di sorgenti/artefatti/log, ultimo blocco del gate
condiviso e misure della pulizia. Il successo descritto qui è limitato allo
snapshot isolato identificato dal relativo manifesto.


| Controllo | Stato di questo lotto |
| --- | --- |
| Core e Kit completi nello snapshot isolato | Superati con exit 0 e fixture nuove: Core 761 definizioni in tre suite, Kit 167 in dieci suite; totale 928, sorgenti stabili |
| CLI indipendente, inventario API e confronto Kit/CLI nello snapshot isolato | Superati con exit 0: baseline esatta di 2.853 dichiarazioni, 135 fixture per 133 operazioni e due varianti termini/altezza, 270 confronti completi; tutti i 40 tag testuali con 63 fixture e 196 controlli |
| Matrice degli scenari e controlli del verificatore | Superati: 173 varianti, cinque workflow, diciannove binding nativi KH e 20 controlli negativi; esito statico distinto dal runtime |
| Native complete nello snapshot isolato | Terza esecuzione completa superata con exit 0: 148 definizioni e 451 esecuzioni, zero failure e zero skip |
| Native: compressione con parole omonime a identità di fusione e fonti condivise, espansione e taglio | Superate all'interno della suite completa isolata, insieme ai flussi tematici e ai diciannove tag KH |
| Formattazione e whitespace dei file Swift del dendrogramma e delle quattro operazioni esplorative | `swift-format` eseguito; `git diff --check` senza errori per quei sei file |
| `make verify` macOS nel checkout condiviso, ultimo tentativo | Oracoli e scenari superati; arresto su due chiavi mancanti del WIP tabulare concorrente: `failure.tabular.cancelled` e `failure.tabular.invalid-input`. Nessun successo globale attestato |
| Smoke GUI limitato di un'istanza già in esecuzione | Osservate otto schede tematiche e descrizioni localizzate; nessun calcolo. Istanza non attribuita al digest del binario isolato |
| Audit manuali GUI e assistivi, pseudo-lingua/destra-sinistra | Non eseguiti; rimangono aperti e distinti dallo smoke |
| iPadOS | Fuori dal profilo richiesto; non attestato |

### Confine del checkout condiviso e snapshot isolato

Il checkout condiviso contiene lavori concorrenti estranei al presente lotto.
Il primo `make verify` si arresta sulla nuova
`docs/adr/0047-flusso-di-ricerca-persistente.md`, allora priva dei metadati
Versione, Responsabile, Ultima modifica e Approvazione. Il secondo tentativo
supera quel controllo e si arresta negli oracoli: il Python 3.9 di sistema
non fornisce `statistics.linear_regression`. L'integratore ripete il comando
con il Python Homebrew 3.14 già presente, con un adattatore PATH limitato al
task, senza modifica globale o nuova dipendenza. Questo ultimo tentativo
supera 248 riscontri R/Python, 64 controlli Fraction, 173 varianti di scenario
e 20 controlli negativi. Si arresta poi per le due traduzioni mancanti
`failure.tabular.cancelled` e `failure.tabular.invalid-input` introdotte dal
lavoro tabulare concorrente. I problemi documentali e dell'interprete dei
primi tentativi sono quindi superati; il gate condiviso completo rimane
non attestato per l'ultimo blocco osservato.

Il quinto tentativo nativo si
arresta inoltre nella compilazione di `GlifiStudioSavedAnalysis.swift`, che
riferisce `researchState` non ancora disponibile nel lavoro concorrente.
L'ultimo controllo Xcode del checkout condiviso segnala inoltre i componenti
ResearchModel, ResearchView e relativi test non ancora inseriti nei target.
Questi lavori concorrenti non vengono rimossi o ripristinati dal checkout
condiviso per far passare il presente incremento.

L'integratore prepara quindi un worktree detached sulla baseline `44dd90f`,
con 41 file del lotto copiati e improntati in un manifesto SHA-256. Il gruppo
include la validazione preesistente dei metadati di export in
`GlifiStudioProjectSession`, per preservare il contratto di parità corrente.
Gli altri sorgenti e `Package.swift` restano quelli della baseline.
Soltanto nella copia isolata di `StudioHomeView` vengono rimossi quattro
inserimenti concorrenti del nuovo workspace di ricerca: stato, azione toolbar,
sheet e azione sulla fonte. Il checkout condiviso resta intatto.

Il [manifesto dello snapshot isolato](allegati/GS-VER-335-snapshot-isolato.json)
conserva la baseline completa `44dd90f22f1b4b4930f87a6f6e818ccb3efaa5d4`, i
41 percorsi e SHA-256, l'eccezione della sola copia di `StudioHomeView` e dieci
file nel frattempo divergenti nel checkout condiviso. Tali divergenze sono
esplicite e impediscono di equiparare il sorgente verificato al WIP corrente.
CMP-335 resta `implemented`: il successo isolato non promuove il gate della
composizione condivisa a `verified`.

Le suite complete SwiftPM e macOS usano directory di build isolate.
Gli esiti positivi attestano questo snapshot e il perimetro registrato nel
manifesto, **non** la compilazione del checkout condiviso corrente o un suo
`make verify` completo. Le diagnostiche e gli errori intermedi conservano il
proprio significato separato; le prove CLI e il gate condiviso hanno una
registrazione distinta.

### Smoke della superficie GUI, senza esecuzione dei flussi

L'integratore ha ispezionato in sola lettura lo stato Accessibility di
un'istanza Glifi Studio già in esecuzione, usando un progetto sintetico di
audit già disponibile. Sono osservabili otto schede di ingresso tematiche
con descrizioni localizzate. La selezione tramite percorso ha risolto
l'istanza con lo stesso bundle identifier già attiva nella cache di sviluppo
di un altro lavoro concorrente: l'osservazione **non** è attribuita al digest
del binario dello snapshot isolato. Riguarda soltanto la struttura testuale
esposta da quell'istanza, senza verifica dei risultati analitici o della resa
grafica completa. Le prove native isolate restano indipendenti dallo smoke.
L'istanza già attiva viene lasciata intatta durante la pulizia.

Il tentativo di selezionare un tema fuori dall'area visibile è stato rifiutato
dallo strumento con `cannotClickOffscreenElement`. La successiva acquisizione
dello schermo è stata interrotta prima dell'invio del comando. Non sono stati
eseguiti calcoli o verificati interamente flussi applicativi. Questi limiti
non attestano un difetto del prodotto né un successo dell'interazione.
VoiceOver, Voice Control, Full Keyboard Access, pseudo-lingua, destra-sinistra
e gate G4 rimangono aperti.

### Esito intermedio e correzioni del terzo tentativo nativo

Il risultato Xcode del 2026-11-28 alle 00:15 registra tre failure, senza
skip, nelle prove di `StudioAdvancedAnalysisTests`. Il caso parametrizzato
`executesEveryProjectDrivenOperator` fallisce soltanto per `.somKH`: la
richiesta conservata nella GUI aveva fasi opzionali assenti, mentre il
trasporto canonico le risolveva ai default. Il modello ora attraversa
canonicalizzazione e decodifica prima dell'esecuzione e conserva la stessa
richiesta effettiva risolta che viene eseguita ed esportata.

Le altre due failure riguardano una preparazione di test inserita per errore
nel controllo dell'identità della bozza, anziché nell'helper comune. La
preparazione delle fasi personalizzate 20/30 viene spostata nell'helper;
le asserzioni sui parametri e sul ripristino della bozza restano conservate.
Una nuova prova separata verifica le fasi omesse risolte a 1.000/2.000
aggiornamenti sulla griglia 2×2, tassi/raggi, round-trip canonico e identità
dell'output dopo un cambio della bozza. Il parsing dei due file corretti,
la formattazione e `git diff --check` passano. In quel momento la successiva
esecuzione nativa rimaneva necessaria; il suo esito è registrato separatamente
nella sezione delle suite isolate.

### Quarto e quinto tentativo nativo

Nel quarto tentativo l'asserzione
`invalidClassifierStateRetainsTypedFailureAndPreviousState` attendeva
`ui.kh-language.invalid-input` per un JSON con chiave sconosciuta; il DTO
conservava invece `text-analysis.unknown-field`. Durante gli aggiornamenti
concorrenti sono state acquisite versioni non allineate del modello e delle
prove. Il confine finale conserva le failure strutturate `GlifiStudioFailure`
del decoder, compresa `text-analysis.unknown-field`; errori sintattici JSON o
altri errori Foundation di decodifica diventano `ui.kh-language.invalid-input`.
Entrambi restano correggibili, con cancellazione controllata e stato precedente
conservato. La validazione semantica del backend prima della pubblicazione non
cambia. I test devono distinguere esattamente questi ingressi, senza silenziare
il caso o ammettere codici alternativi indiscriminatamente.

Il successivo quinto tentativo non raggiunge il runtime per l'errore di
compilazione concorrente descritto sopra; la nuova verifica procede sullo
snapshot isolato con tale confine esplicito.

### Prime suite complete dello snapshot isolato

La prima esecuzione SwiftPM isolata osserva 167 definizioni Kit superate e
761 definizioni Core con due failure nei test PDF. Il runner diretto non
aveva predisposto la directory `IsolatedPDFA` richiesta per l'output di
validazione. La directory viene creata e la suite completa rieseguita; il
problema di predisposizione del runner non viene attribuito al kernel del
clustering o nascosto come esito positivo.

La prima esecuzione nativa completa dello snapshot isolato osserva 148
definizioni e 451 esecuzioni: una sola failure riguarda l'allineamento del
codice d'importazione dello stato tra modello e test acquisiti durante le
modifiche condivise. La copia isolata del modello viene aggiornata al confine
strutturato sopra descritto e il manifesto dei digest viene aggiornato. Le
prove restano specifiche per input e codice atteso. La suite completa viene
rieseguita; gli esiti finali sono registrati nella sezione successiva. Nessuna
revisione del checkout condiviso viene annullata o ripristinata.

### Esiti finali delle suite isolate

La suite completa con fixture nuove termina con exit 0: **761 definizioni
Core in tre suite e 167 Kit in dieci suite**, per un totale di **928**.
Un ulteriore tentativo intermedio aveva quattro failure Kit
`profile.invalid-destination`: il riuso della directory scratch lasciava
destinazioni della suite di profilo già presenti. Il runner viene corretto
usando directory `IsolatedParityFinal` univoche. Le failure di predisposizione
delle fixture non richiedono una modifica del prodotto e non vengono omesse
dalla storia della verifica.

La **terza esecuzione nativa completa isolata** termina con exit 0:
**148 definizioni e 451 esecuzioni**, **zero failure e zero skip**.
La seconda esecuzione conservava ancora un ciclo di test incoerente con il
confine strutturato del decoder. La correzione specifica per ciascun ingresso
mantiene `text-analysis.unknown-field` per chiave sconosciuta e
`ui.kh-language.invalid-input` per JSON malformato, con tutte le asserzioni
su stato, categoria e retry conservate. Modello e test vengono allineati sia
nel checkout condiviso sia nella copia isolata; la suite finale passa sullo
snapshot stabile e non costituisce un ripristino del lavoro condiviso.

Questi risultati comprendono i nuovi flussi KH, i parametri effettivi,
la canonicalizzazione delle fasi SOM, le route tematiche, la compressione e
l'espansione dei rami. Non attestano un audit UI interattivo; le verifiche
CLI completate sono registrate qui sotto.

### Parità CLI e inventario pubblico dello snapshot isolato

La verifica finale termina con exit 0 e confronta esattamente **2.853
dichiarazioni** con la baseline API revisionata. I cinque ingressi non
testuali producono **135 fixture** per **133 operazioni univoche**, con le
due varianti aggiuntive di clustering dei termini e taglio ad altezza;
sono superati **270 confronti completi** dei risultati. Le prove negative
comprendono **sei** rifiuti di metadati visuali incompatibili, **51** rifiuti
JSON/ammissione/privacy e **64** rifiuti degli input di progetto. Sono
verificati i **quattro formati di importazione**.

Il percorso testuale copre tutti i **40 tag**, con **63 fixture e 196
controlli**. Il confronto con il risultato nativo mantiene la tolleranza
assoluta/relativa `1e-12` per i reali, senza eliminare campi dai risultati.
Il primo avvio con Python 3.9 si arrestava sull'argomento `strict` di `zip`;
la medesima verifica, senza modificare script o attese, passa usando il
Python 3.14 già disponibile. Il nuovo `recut-visualization` è verificato per
numero e soglia inclusiva, con identità/albero conservati e progetto
immutato. Questi esiti sono dello snapshot isolato improntato nel manifesto,
non un successo del `make verify` sul checkout condiviso successivo.

La tabella distingue codice e test predisposti dagli esiti realmente osservati.
Nessun successo storico di GS-VER-102/114/223/300 è esteso automaticamente al
nuovo sorgente. Le maturità scientifiche, la validazione esterna dei profili KH,
i gate G4/G5 e la parità con edizioni non pubbliche di KH Coder restano separati.

## Confini e pulizia

Sono preservati i cambiamenti preesistenti nel checkout condiviso. Non sono
modificati gli appunti sorgente e non sono introdotti dipendenze di produzione,
rete, telemetria o entitlement. La topologia opzionale della vista non è una
nuova sorgente autorevole: Artifact, metodo e lineage restano quelli dell'analisi.
Le fixture possedute dai test sono temporanee e hanno cleanup; i file utente e
le prove utili non vengono rimossi.


### Archivio delle prove e pulizia misurata

L'integratore conserva l'archivio locale
`~/Library/Caches/GlifiStudio/evidence/GS-VER-335/run-20261128-GNIEvW`.
Comprende i 41 sorgenti dello snapshot, tutti i log intermedi/finali,
le fixture CLI complete con i PDF sintetici e il risultato Xcode finale
`NativeFinal.xcresult`. Il rapporto strutturato elenca i digest degli archivi,
dei log e del binario verificato, insieme al manifesto dei sorgenti; tali
prove rimangono disponibili dopo la rimozione delle directory di compilazione.

Sono rimossi soltanto il worktree detached e le directory temporanee del
presente task, con download ridondanti e artefatti rigenerabili di build/test.
Il materiale scratch passa da **3.768.004 KiB a zero**; le prove conservate
occupano **8.172 KiB**. La riduzione netta del materiale posseduto dal task
è **3.759.832 KiB, pari a 3,586 GiB**. Questi conteggi descrivono i percorsi
del lotto, non una misura dello spazio libero dell'intero volume.
Il checkout condiviso, i file utente, le toolchain e l'istanza applicativa
attiva nella cache dell'altro lavoro restano intatti. La pulizia non modifica
il confine della verifica: il gate del checkout condiviso non è attestato.
