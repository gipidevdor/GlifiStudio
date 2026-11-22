<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Grafici audio, comandi di documento e prova del Neural Engine

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-270 |
| Tipo | Evidenza di integrazione Apple |
| Versione | 1.1.0 |
| Stato | Verifica mirata, audit interattivi e misura OCR aperti |
| Responsabile | Iniziatore del progetto, con supporto Codex |
| Ultima modifica | 2026-11-22 |
| Approvazione | Attuazione di ADR-0008 e ADR-0024 su richiesta dell’iniziatore, con audit di rilascio aperti |
| Riferimenti | RF-084, RQ-037, RQ-038, GS-VIZ-001, GS-APL-002/003/009/010/011, ADR-0008, ADR-0024 |

## Scelte per l'esperienza attuale

| Attività della persona | Tecnologia pertinente | Applicazione |
| --- | --- | --- |
| Aprire un progetto e importare le fonti | DocumentGroup, FileDocument, Uniform Type Identifiers, selettore di file di sistema | Il comando di importazione riusa il flusso del documento attivo e l'accesso ai file scelti dalla persona. |
| Passare dalla domanda alla fonte | NavigationSplitView, FocusedValues, menu SwiftUI | Stesse destinazioni semantiche nelle finestre Mac e iPad. Selezione, calcolo e permessi restano gestiti dal documento. |
| Esplorare una distribuzione o una proiezione | Swift Charts, Canvas e Accessibility | Il laboratorio lessicale Mac usa Swift Charts. I grafici fattoriali conservano il rendering che rispetta la geometria scientifica e pubblicano gli stessi dati al sistema di grafici audio. |
| Calcolare, classificare o cercare | Swift, Accelerate e, per futuri modelli locali, Core ML | Le statistiche e i confronti seguono gli algoritmi di riferimento. Le operazioni a matrice sono candidate a ulteriori accelerazioni solo dopo misure su input rappresentativi. |
| Acquisire una pagina scansionata | Vision | Candidato post-MVP valutato qui su dati sintetici. La validazione dovrà includere la corrispondenza fra testo, pagina e regione. |
| Ritrovare o automatizzare contenuti fuori dal documento | Spotlight, App Intents, Handoff | L'esposizione di corpus e risultati ad altre superfici di sistema dipende dai contratti di identità e privacy dei profili GS-APL-004, 012 e 013. |

## Cicli di perfezionamento

| Ciclo | Intervento | Verifica |
| --- | --- | --- |
| 1. Oracolo numerico | L'oracolo R chiama NMF tramite il namespace. Il caricamento interattivo del pacchetto tentava di configurare il parallelismo quando il conteggio dei core risultava indisponibile. | `make check-oracles` ha riprodotto 194 righe con le fixture e le tolleranze del progetto. |
| 2. Lingua del grafico | Legenda, descrittore audio e colonna delle serie usano i nomi del catalogo della lingua attiva. I numeri seguono la regione richiesta. | Catalogo compilato da Xcode, confronto di Documenti/Documents, Asse/Axis e 1,5/1.5. Controllo della presenza del catalogo nei due target app e nel target dei test macOS. |
| 3. Comandi e focus | Le finestre espongono i comandi attraverso `focusedSceneValue`. ⌘F porta il focus al campo quando la vista della query è pronta. Il foglio degli strumenti, l’anteprima e i tre selettori di file della vista principale sospendono i comandi del documento. | Compilazione per i due target. Resta da provare il passaggio fra finestre con tastiera reale. |
| 4. Preparazione del Canvas | L’assegnazione degli stili visita i segni una volta. Il primo segno di ogni serie, anche un segmento, determina la posizione nella palette. Questo ordine serve al disegno e alla legenda. | Confronto di tutti gli indici rispetto alla versione precedente e tempi riportati sotto. |
| 5. Selezione del dendrogramma | La riga di una fusione risolve l'identificatore del segmento orizzontale corrispondente. Tabella, selezione da tastiera e azione accessibile portano allo stesso insieme di fonti. | Regressione sulla fusione, le due revisioni discendenti, la selezione diretta e gli identificatori con prefisso simile. |
| 6. OCR italiano | La prova esterna genera due immagini, una con accenti e l’altra con numeri, virgola decimale e punteggiatura. Registra testo, tempi delle richieste riuscite ed errori per configurazione. | Dieci tentativi sul Mac, riportati sotto con l'esito del framework. |
| 7. Significato della percentuale | La sintesi del grafico indica l’inerzia totale per CA, la varianza totale per PCA e la somma dei quadrati dei valori singolari per LSA. La chiave precedente resta traducibile per le specifiche già esportate. | Tre risultati sintetici attraversano il costruttore di GlifiKit e il descrittore Accessibility. I test controllano le due lingue, la percentuale e la sostituzione degli argomenti. |
| 8. Avviso per una quota bassa | Gli assi che insieme rappresentano meno del 50% richiamano la quota visualizzata con una frase valida per tutti e tre i metodi. | Lo stesso percorso verifica che una quota del 25% attivi l'avviso e controlla il testo localizzato per i tre metodi in entrambe le lingue. |

## Lettura e navigazione del risultato

Per CA, PCA e LSA il Canvas espone un `AXChartDescriptor` con titolo, sintesi,
domini e serie discrete. Ogni punto porta etichetta e coordinate originali.
Un risultato a un asse fornisce una sola coordinata accessibile. Reti,
dendrogrammi, tabelle e assi a estensione nulla si esplorano tramite la tabella.
Le righe selezionabili offrono un’azione accessibile e rispondono a Invio e Spazio.

Sulle due piattaforme ⌘F apre la query, ⌘K gli strumenti, ⇧⌘I il selettore
delle fonti e ⌘1…⌘7 le sezioni del progetto. L’importazione richiede un progetto
pronto e libero. Nella finestra compatta un comando di navigazione apre il dettaglio.

## Tempi di assegnazione degli stili

Un eseguibile compilato con `swiftc -O` ha confrontato la precedente ricerca
per punto e l'indice per serie su macOS 27.2.1 arm64 con Swift 6.4.2. Dopo il
riscaldamento, sette coppie di misure hanno alternato quale versione veniva
eseguita per prima. Ogni misura verifica l'uguaglianza di tutti gli indici.

| Segni sintetici | Punti | Mediana precedente | Mediana con indice |
| ---: | ---: | ---: | ---: |
| 60 | 52 | 0,059 ms | 0,013 ms |
| 1.200 | 1.050 | 20,468 ms | 0,149 ms |

Il cronometro comprende la preparazione degli stili per un passaggio di disegno.
Rasterizzazione, interazione e frequenza dei fotogrammi richiedono una misura
dell'app in esecuzione. [Campioni e impronte dei sorgenti](allegati/GS-VER-270-stili.json) · [Procedura di riproduzione](../../Benchmarks/README.md)

## Neural Engine per l'OCR italiano

La prova usa la revisione 3 di Vision e richiede il riconoscimento in italiano.
Per ciascuna immagine esegue la configurazione automatica e una richiesta per
ogni dispositivo dichiarato per la fase principale. A ogni risposta riuscita
registra testo e durata, con cinque ripetizioni successive alla prima lettura.
L’esito positivo richiede la trascrizione esatta in tutte le letture.
[Codice della prova](../../Benchmarks/macOS/StudioVisionTextProbe.swift)

```sh
swift Benchmarks/macOS/StudioVisionTextProbe.swift > prova-ocr.json
```

| Vision su macOS 27.2.1 arm64, SDK 27.2 | Dispositivi ammessi per la fase principale | Esito sui due campioni |
| --- | --- | --- |
| Rapida, italiano supportato | CPU | Quattro errori fra modalità automatica e CPU |
| Accurata, italiano supportato | CPU e Neural Engine | Sei errori fra modalità automatica, CPU e Neural Engine |

Tutti i tentativi si sono fermati con `Vision.VisionError 1`, dettaglio
`Failed to create CVPixelBuffer`, prima di restituire il testo. Rimangono da
misurare la qualità del riconoscimento, la latenza e l'energia su Mac e iPad
fisici, verificando con Instruments il dispositivo effettivamente usato. L’OCR
resta un candidato post-MVP. [Rapporto integrale della prova](allegati/GS-VER-270-ocr-italiano.json) · [Valutazione per carico](../apple/11-calcolo-accelerato-apple-silicon.md)

## Stato delle verifiche

| Controllo | Esito osservato |
| --- | --- |
| Controlli statici e oracoli | `make quality-static` con Python 3.14 verifica anche documenti, matrice, localizzazioni, privacy e baseline Apple. L'oracolo obbligatorio riproduce 194 righe. |
| Sorgenti app e framework nativi | Compilazione e collegamento con Apple Swift 6.4.2 di GlifiCore, GlifiKit e app per arm64 macOS 27.0 e iPadOS Simulator 27.0, SDK 27.2. La verifica diretta copre gli eseguibili. Schemi, firma, lancio e interfaccia richiedono la verifica dal workspace. |
| Test mirati | Sei test sull'integrazione dei grafici e sulla selezione. La selezione più ampia comprende questi sei test e totalizza 14 test superati in quattro suite, con 44 casi parametrizzati per i metodi statistici. |
| Suite applicativa macOS completa | Il runner nativo ha eseguito 94 test in 14 suite e registrato 453 problemi. Tra gli errori compare `project.coordination-failed`. Una prova indipendente di scrittura coordinata su file temporaneo ha restituito `NSCocoaErrorDomain 512` prima di entrare nell'accessor. |
| `make verify` | Gli oracoli e il controllo di formattazione passano. SwiftPM si arresta durante il caricamento del manifest perché il processo non può creare la sandbox annidata (`sandbox_apply: Operation not permitted`). |
| Audit aperti | In questa sessione Xcode rifiuta l'apertura del workspace e CoreSimulatorService è indisponibile. Restano aperti la build degli schemi Xcode, l'ascolto con VoiceOver e rotore su entrambe le piattaforme, tastiera e finestre su iPad e il profilo OCR su hardware. |
