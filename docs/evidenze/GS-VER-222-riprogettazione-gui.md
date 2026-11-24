<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-222 — Riprogettazione ergonomica della GUI

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-222 |
| Tipo | Evidenza di implementazione e verifica applicativa |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro automatico; osservazione GUI parziale |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-222; ADR-0034; richiesta esplicita di riprogettazione GUI |

## Perimetro

Riprogettazione della navigazione e delle presentazioni delle capacità esistenti,
con accesso al laboratorio avanzato macOS attraverso GlifiKit. I risultati di
sessione restano distinti dagli Artifact persistiti. Nessuna nuova formula,
dipendenza, rete o migrazione del progetto è autorizzata da questo lotto.

## Identità del contenuto e record durevole

Il gate finale usa un worktree Git detached isolato, con overlay della copia di
lavoro condivisa, basato su
`02c1c666437a58743dba40193b9a94d4a7a3a11c`. Il fingerprint dei **334 file** di
sorgenti, risorse, configurazione e verifica ha SHA-256
`c77d0e37d78a2d9684de224c8799fedf85aae30781f5665dca42ebb15220129f`.
Il [riepilogo durevole sanificato](allegati/GS-VER-222-verifica-gui.json)
conserva radici, algoritmo, conteggi, esiti e limiti. Il digest concatena, per
path relativo ordinato, path UTF-8, NUL, contenuto e NUL; l'inventario deriva
da `git ls-files --cached --others --exclude-standard` sulle radici dichiarate.

La corrispondenza fra sorgente prima della copia, sorgente dopo la copia e
snapshot isolato è stata verificata durante la preparazione. Questa identità
riguarda l'ingresso del nuovo gate, distinto dalle prove mirate e dal primo gate
interrotto. Non identifica l'intero working tree né i documenti aggiornati con
gli esiti. Il ricontrollo dopo il gate conferma **334 file e lo stesso SHA-256**
nello snapshot isolato. I contributi concomitanti GS-VER-230/231/232 sono
preservati nell'overlay senza una promozione implicita delle loro clausole.

Il successivo fingerprint della copia condivisa è
`233d051f57eba304004cc5e5ce528f4feb0c3acabe777d55225578b7633137f6`.
Il confronto file per file individua una sola differenza rispetto allo snapshot:
`Config/Compliance/specification-matrix.json`, con le sole promozioni documentali
di CMP-230 e CMP-232 da `implemented` a `verified`. Gli altri 333 file coincidono.
Queste promozioni appartengono alle rispettive evidenze; non cambiano il runtime
verificato e richiedono il controllo statico finale della matrice corrente.

## Contenuto implementato

| Percorso | Presentazione e confini |
| --- | --- |
| Workspace e navigazione | Sidebar per compiti, contesto del progetto, catalogo ricercabile e accessi diretti; menu e comandi da tastiera macOS; panoramica con prossima azione contestuale |
| Fonti e query | Elenco delle fonti con apertura del documento separata dalla concordanza; query con editor stabile ed elenco/dettaglio affiancati o sequenziali; selezione e contenuto KWIC preservati |
| Indagine | Azioni di pianificazione/esecuzione subito dopo la domanda; avviso quando intenzione, gruppi o fonti del draft differiscono dal piano visualizzato |
| Laboratorio testuale | Impostazioni e risultati in pannelli ridimensionabili; percorso sequenziale con finestre strette o testo di accessibilità; scelta dello strumento e parametri conservati durante la navigazione |
| Riassunto | Sette identificatori scientifici già esistenti, budget in frasi/token/scalari Unicode e configurazione delle sole varianti a grafo previste dal contratto; diagnostica effettiva e avviso di non convergenza |
| Lessico e ponderazione | BM25, frequenze/n-grammi, MTLD e TF/TF-IDF conservati; accessi distinti a fonti, vocabolario e celle sparse; paginazione e scope effettivo |
| Leggi lessicali | Percorso persistito `corpus-lexical-laws-v1`, osservazioni/fit/residui paginati e grafico della pagina con tabella equivalente; caveat descrittivo visibile ed export JSON esplicito |
| Laboratorio avanzato | Dodici operazioni: MDS, SOM, CLARA, LDA, classificazione, validazione del classificatore, regole, crosstab, dissimilarità, corrispondenze, clustering gerarchico e rete; risultati di sessione e nessuna nuova capability planner |

Il ponte `prepareProjectInput` usa importer e tokenizer del prodotto, conserva
revisioni e digest e seleziona il vocabolario della sola matrice con una policy
esplicita. I documenti completi restano input di LDA/classificazione/regole.
Calcolo, proiezione delle righe ed elaborazione del filtro avanzato usano
`@concurrent`; la vista mostra pagine da cinquanta righe. Nessun miglioramento di
latenza o consumo viene dedotto dalla struttura del codice.

Classi, ruoli training/prediction, gruppi e regole effettivamente usate sono
catturati con il risultato e distinti dai draft. Il client spiega le
precondizioni evidenti prima dell'esecuzione, senza correggere silenziosamente
parametri scientifici. L'annullamento conserva l'output precedente e il cambio
progetto pulisce risultati, etichette e regole. Le due esportazioni riusano i
JSON esistenti di richiesta e risultato; la provenienza del progetto resta
ispezionabile nella GUI e non viene aggiunta al formato JSON del risultato.

## Verifiche

Controlli documentali `Scripts/check-docs.py`, `Scripts/check-compliance.py` e
`git diff --check` sul dossier: **superati** nella fase di integrazione.
Il primo controllo documentale registra 434 item, 433 identificatori univoci e cinquanta
schede Definition of Ready; la matrice contiene allora 143 clausole. Questi esiti
attestano struttura, riferimenti e stati, non la GUI in esecuzione.

La review statica ha verificato l'allineamento dei percorsi con GS-UI/UX17 e
individuato correzioni recepite nel lotto: selezione dello strumento condivisa
con la scena, draft lessicale posseduto dal modello, annullamento tipizzato,
mapping delle classi e regole catturate, pulizia al cambio progetto, insieme di
fonti preparato una volta per l'editor delle etichette, scope esplicito e MDS 1D
senza una seconda coordinata annunciata come calcolata. Il banner del piano
distingue le nuove impostazioni dall'anteprima precedente. Questa review non è
un audit assistivo né una misura delle prestazioni.

Le prove automatiche aggiunte includono il bridge di progetto e il trasporto in
`GlifiProjectLaboratoryInputTests`, ricerca degli strumenti/contesto delle fonti
in `StudioWorkspaceTests`, varianti e ciclo di vita del laboratorio in
`StudioDocumentLifecycleTests` ed esecuzioni/paginazione/conservazione del
laboratorio avanzato in `StudioAdvancedAnalysisTests`.

## Prove mirate osservate

Il flusso principale ha completato `xcodebuild test` macOS selezionando
`StudioAdvancedAnalysisTests`, `StudioWorkspaceTests` e
`StudioDocumentLifecycleTests`: **exit 0**, riepilogo xcresult con **44 definizioni
di test e 70 esecuzioni sul dispositivo di test**, **zero failure e zero skip**.
Il conteggio include quattordici esecuzioni del client avanzato e sette varianti
del riassunto. Il log dell'esecuzione è `GlifiStudioGUIMirroredTests.log`; lo
riepilogo xcresult è conservato nell’allegato durevole; il bundle temporaneo
è stato rimosso dopo la verifica.

Gli oracoli indipendenti con `--require`, usando Python **3.14** già installato,
riproducono **194 righe**. La scelta esplicita di questa toolchain evita
l'interprete Python 3.9 predefinito, privo delle API `statistics` richieste
dall'oracolo delle leggi lessicali. Localizzazione, architettura, dialetto Swift
e controllo whitespace sono superati nel flusso d'integrazione.

Le prove mirate precedono l'ultima correzione che ignora
`CocoaError.userCancelled` negli exporter avanzato e lessicale: annullare il
dialogo non deve mostrare un errore di esportazione. Formattazione e
`make verify` sul contenuto finale sono successivamente superati come registrato
di seguito. I controlli automatici non attestano una prova manuale del dialogo
di sistema.

## Prima esecuzione integrata interrotta

La prima esecuzione di `make verify` nella copia condivisa è stata interrotta
dal flusso principale perché le modifiche concomitanti e la successiva
correzione visuale avevano invalidato il fingerprint iniziale
`7a70a611de646cf218a4db6067f8e2961137135cf3017d2b8e21c33bde15b5fa`.
Fino all'interruzione erano osservati **423 test package**, **194 righe di
oracoli**, **51 controlli CLI**, **22 checkpoint di recovery** e verifica QueryAST
superati. I due PDF prodotti da quella run sono risultati conformi PDF/A-2u
con verifica esterna `--require`, usando veraPDF **1.30.4** già installato.

Questi sono esiti parziali di una run su sorgenti non rimaste stabili: non
costituiscono un gate completo e non sono attribuiti al nuovo snapshot isolato.
Il nuovo `make verify` usa esplicitamente Python 3.14 e `VERAPDF`, senza
installazioni o dipendenze aggiunte al prodotto.

## Gate completo sullo snapshot isolato

`make verify` è terminato con **exit 0** sullo snapshot immutato
`c77d0e37…0129f`, usando il profilo completo macOS e iPadOS.

| Verifica | Esito osservato |
| --- | --- |
| Package Core/Kit | 423 test superati, esecuzione di 13,224 secondi |
| Test nativi macOS | 67 definizioni e 224 esecuzioni, zero failure e zero skip |
| Runtime warning nei test nativi | Zero nel riepilogo xcresult, distinto dagli avvisi host/build |
| Oracoli indipendenti | 194 righe riprodotte |
| PDF/A-2u | Due file conformi, validatore esterno configurato nella stessa run |
| Trasporto analitico CLI | 51 controlli su 15 fixture |
| Recovery | 22 checkpoint superati |
| QueryAST | Verifica superata |
| Build macOS | Debug e Release superate senza firma |
| Build iPadOS | Debug e Release superate senza firma |

Python 3.14 e veraPDF 1.30.4 sono strumenti già installati e selezionati
esplicitamente. Nessun test runtime iPadOS è dedotto dalle build generiche.
Il gate conserva diagnostici host non bloccanti sul framework CoreSimulator
1171.7.0 precedente al build 1174.21.0 atteso da Xcode; resta inoltre aperto
l'avviso iPadOS relativo all'apertura sul posto dei documenti. Non viene
dichiarata assenza di warning di build o conformità completa della gestione
documentale iPadOS.

CMP-222 resta `implemented`: il nuovo client ha superato il gate automatico, ma
la clausola comprende ergonomia e accessibilità con audit ancora aperti. Le
evidenze storiche dei metodi non sono usate per promuovere tali aspetti.

## Osservazione parziale della GUI reale

Dopo lo sblocco del Mac, la sessione Computer Use del flusso principale ha
aperto la nuova build Debug, creato un documento mediante il percorso nativo e
osservato la sidebar, la panoramica vuota e il menu **Area di lavoro**. È stato
acquisito uno screenshot dello stato iniziale. Questa è un'osservazione reale
della nuova finestra, distinta dalle build e dai test del modello.

Una successiva osservazione con progetto temporaneo vuoto aperto e salvato ha
confermato che context/status bar applicate globalmente potevano coprire la
sidebar. Il codice le colloca ora nel dettaglio del `NavigationSplitView`; la
correzione è inclusa nel nuovo snapshot, ma il suo esito visivo dal vivo non è
ancora attestato.

Il Mac si è successivamente ribloccato, impedendo di completare il percorso
interattivo. Non sono attestati strumenti con dati, risultati, scorciatoie in
azione, focus end-to-end, ridimensionamento, tecnologie assistive o comportamento
dei dialoghi di esportazione. La semplice presenza del menu non dimostra che
ogni comando sia stato azionato.

## Pulizia finale

Sono stati rimossi il worktree isolato e gli artefatti rigenerabili della cache
creata per questo lotto: **2 852 132 KiB**, oltre ai **519 936 KiB** della cache
mirata dell’operatore avanzato, già rimossa dal relativo flusso. Il totale
misurato con `du` è circa **3,216 GiB** di artefatti rimossi. Restano l’app Debug
aperta, il progetto sintetico e i quattro testi di prova necessari a riprendere
il controllo visivo, insieme ai riepiloghi e ai log utili di verifica. La pulizia
non riguarda toolchain, dipendenze installate o file delle lavorazioni concomitanti.

## Limiti

L'efficacia ergonomica richiede osservazione della GUI e prove con persone.
VoiceOver, Voice Control, tastiera end-to-end, pseudo-lingua, destra-sinistra,
contrasto, dimensioni di accessibilità e dispositivi non sono attestati da
controlli statici o build. Nessuna chiusura G4/G5 o promozione scientifica viene
dedotta dall'estensione applicativa.
