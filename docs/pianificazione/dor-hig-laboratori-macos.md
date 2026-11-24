<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Componenti e campi nativi nei laboratori macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-304 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.3.1 |
| Stato | Ready |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di applicare le HIG Apple; perimetro circoscritto dal coordinatore prima del codice |
| Riferimenti | RQ-012; RQ-047; RQ-063; GS-STD-001-15; GS-STD-001-29; GS-APL-002; GS-APL-003; GS-I18N-002; GS-UX-001-17; ADR-0034; ADR-0041 |

## Difetti e risultato atteso

La lettura del checkpoint `8901f4a` mostra nei sette laboratori macOS un controllo
segmentato nell'area principale per alternare impostazioni e risultati quando
la larghezza è ridotta o il testo ha dimensione di accessibilità. Le HIG Apple
per macOS prescrivono una tab view per questo impiego. Nel laboratorio
Valutazione diversi campi dipendono dalla sola indicazione interna e le righe
di attributi dispongono due campi affiancati; le azioni ripetute di rimozione
non esplicitano sempre l'oggetto e il gruppo di riferimento.

Il lotto corregge questi impieghi concreti. Il risultato verificabile è una
struttura SwiftUI nativa con etichette permanenti e contesto accessibile, senza
una dichiarazione di conformità HIG o accessibilità dell'intera applicazione.

## Scheda Definition of Ready

| Voce | Contratto e accettazione |
| --- | --- |
| outcome e confini | Solo le view macOS TextAnalysis, AdvancedAnalysis, CorpusMethods, Statistics, Evaluation, Operators e Linguistic: sostituire il selettore compatto impostazioni/risultati con `TabView` nativa. Conservare `HSplitView`, soglie e comportamento del ramo largo. Solo Evaluation: etichette visibili permanenti per i campi editabili, campi multipli disposti verticalmente e contesto dei gruppi/azioni ripetute. Stop al completamento di questi due interventi |
| requisiti | RQ-012 e GS-APL-003: nome, ruolo e contesto comprensibili senza usare il placeholder come unica etichetta; controlli interattivi figli restano raggiungibili. RQ-047: stessi binding di selezione, identità degli elementi e comportamento dei cambi di metodo/risultato/progetto. RQ-063: questa scheda precede codice e nuovi test sostanziali. TV-017, TV-048, TV-058 e TV-076 sono coperti soltanto nella frazione strutturale dichiarata |
| dominio/API | Nessun modello, algoritmo, API pubblica Core/Kit/CLI, formato o identità nuovo. Le tab usano la selezione esistente, compresi i cambi automatici già presenti; i campi mantengono binding, formatter, limiti e ordine dei dati. La correzione non modifica la parità CLI/Kit |
| failure semantics | Nessun nuovo I/O o task. Vuoto, caricamento, errore, cancellazione, retry, risultato precedente e reset restano governati dai modelli esistenti. Il cambio di tab non avvia analisi né cancella la bozza; aggiunta/rimozione conserva le operazioni e i limiti correnti |
| esperienza prevista | Con finestra stretta o testo grande, tab localizzate rendono espliciti impostazioni e risultati; con spazio ampio restano affiancati. In Evaluation l'etichetta resta leggibile anche con il campo compilato. Attributi e valori sono impilati; osservazione/documento, gruppo gold/predetto e indice locale distinguono le azioni ripetute. Non appiattire gli editor in un unico elemento accessibile che nasconda i controlli figli; preservare la sequenza di lettura e tabulazione nativa |
| verifica | Review differenziale dei sette rami e di tutti gli editor Evaluation; controlli di localizzazione it/en, architettura, Swift e documentazione; build e test automatici macOS esistenti pertinenti, poi `make verify` e preflight macOS senza firma. Le anteprime considerano ramo compatto/largo, testo grande, chiaro/scuro e RTL: la sola presenza o compilazione non prova il comportamento visivo. Non aggiungere test che ripetano il sorgente; un'eventuale regressione funzionale richiede fixture e oracolo significativi. GS-VER-304 registra comandi, sorgenti effettivi, esiti e limiti |
| dati e migrazione | Nessun dato nuovo entra o persiste; nessuna migrazione. Testo inserito, coordinate scientifiche, lineage, output ed esportazioni non cambiano. Fixture soltanto sintetiche |
| sicurezza/privacy | Nessuna dipendenza, rete, telemetria, entitlement, logging o nuovo accesso a file. Le etichette di prodotto e i formati contestuali provengono dal catalogo it/en; nessun contenuto reale è introdotto nelle prove o nei documenti |
| prestazioni/sistema | Nessun calcolo o preparazione di dataset aggiunto al Main Actor. Si usano componenti nativi su collezioni già limitate e paginabili. Nessun vantaggio di latenza, energia, memoria o frame budget è dichiarato; eventuali regressioni osservate richiedono misura separata |
| tracciabilità | CMP-304 inizialmente `specified` secondo lo schema vigente, GS-VER-304 pianificata. Prima della consegna aggiornare i soli riferimenti pertinenti di indici, GS-UX-001-17, tracciabilità, stato di adozione e changelog, preservando GS-VER-302 e gli altri contributi concorrenti |
| decisioni e recupero | GS-APL-002/003 e ADR-0034/0041 già autorizzano i componenti nativi dei laboratori; nessuna nuova decisione architetturale. Recupero mediante revert dei soli componenti/label del lotto, senza migrazione o modifica dei risultati |

## Perimetro della verifica

**Ready** per la correzione strutturale sopra delimitata. Il lavoro parte nel
checkout isolato `/tmp/MacStudio304Work`, derivato da `8901f4a`, senza incorporare
WIP 302 su Home, strumenti o catalogo. Le nuove chiavi necessarie vengono
integrate preservando semanticamente il catalogo concorrente.

L'utente ha richiesto macOS e soli test automatici. iPadOS, interazione GUI
manuale, VoiceOver, Voice Control, Full Keyboard Access osservato, contrasto
misurato, pseudolocalizzazione eseguita e G4 restano aperti. Non si introduce
un nuovo harness UI né si promuovono i criteri EA ancora «Da introdurre» a gate.
RQ-012 e RQ-030 non possono essere chiusi dal presente lotto.

## Fonti primarie consultate il 2026-11-22

- [Apple HIG — Segmented controls, macOS](https://developer.apple.com/design/human-interface-guidelines/segmented-controls#macOS): tab view per cambiare vista nell'area principale; il controllo segmentato conserva altri impieghi appropriati.
- [Apple HIG — Text fields, Best practices](https://developer.apple.com/design/human-interface-guidelines/text-fields#Best-practices): indicazione del campo comprensibile durante l'immissione, disposizione verticale e sequenza logica di tabulazione.
- [Apple HIG — Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): adattamento del testo, semantica dei controlli e audit effettivi; l'adozione dei componenti di sistema è un presupposto, non l'esito dell'audit.

## Allineamento prima del gate

La scheda Ready iniziale e i sette delta sono conservati. Prima di completare
il gate il checkout è stato aggiornato con fast-forward a
`d368285010dca17f5ef72819da25b6890d0de32a`, nuova baseline pubblicata di main.
I 33 file upstream riguardano profili KH, contratti, fixture e documentazione;
nessuna delle sette view cambia. I metadati sovrapposti preservano i nuovi
contenuti upstream. Il catalogo mantiene gli stessi valori e aggiunge soltanto
le dodici chiavi del lotto, senza riformattare le chiavi precedenti.
L'esecuzione precedente è stata interrotta deliberatamente e non è un gate
completato; GS-VER-304 distingue il checkpoint conclusivo.

## Inizializzatore SwiftUI verificato

La compilazione del checkpoint allineato ha rilevato che l'SDK installato non
espone `Tab(titleKey, value:)` senza immagine. La forma applicata è
`Tab(value:) { contenuto } label: { Text(chiave) }`, verificata nella
SwiftUI.swiftinterface del SDK macOS, disponibile da macOS 15. Restano
identici scelta, contenuto e criterio di accettazione; non si aggiungono
simboli decorativi. Le corse fallite sono conservate separatamente e il
checkpoint corretto richiede nuova build e nuovo gate.

## Identità degli editor ripetuti

La review strutturale rileva che materializzare binding per indice in un
array non conserva identità stabili dopo una rimozione. Si mantiene
l'overload nativo `ForEach(Binding)` già impiegato nella baseline, con UUID
catturato per ogni riga e ordinali ricavati da una mappa dei valori O(n).
Il limite delle entità è 2.000, quindi non si aggiunge una ricerca lineare
per ogni riga. Il crash durante un aggiornamento SwiftUI non è stato
riprodotto; la correzione conserva il contratto del componente nativo.

## Esito nel perimetro automatico macOS

Implementazione completata e prove automatiche superate sul checkpoint
`9c9e00989f3b31bc50b6632e55d63afb3882f2c2ac320043a326008d5c285146`,
base `d368285`, 1172 file invariati durante gate e preflight: `make verify`
e preflight macOS senza firma terminano entrambi con exit 0.
[GS-VER-304](../evidenze/GS-VER-304-hig-laboratori-macos.md) registra 771 test
Core/Kit, 113 definizioni e 345 esecuzioni native, i predecessori distinti e
le correzioni degli initializer e delle identità Binding.

CMP-304 resta `implemented`; RQ-012/RQ-030 e gli audit GUI/assistivi,
Full Keyboard Access, contrasto, pseudo-lingua, iPadOS e G4/G5 restano aperti.
La chiusura delle prove automatiche non cambia retroattivamente la Ready
iniziale e non certifica conformità HIG globale.
