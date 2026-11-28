<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Information architecture e interazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UI-001 |
| Tipo | Specifica di design dell'interfaccia |
| Versione | 1.5.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-28 |
| Approvazione | Baseline proposta; prototipi e studi richiesti |
| Riferimenti | GS-UX-001; GS-DOM-001; GS-ANA-001; Apple HIG; ADR-0006; ADR-0016; ADR-0034 |

## Scopo

GS-UI-001 rende implementabile il modello mentale GS-UX su macOS e iPadOS.
Governa route, finestre, selezione, comandi, componenti semantici e stati. Non
ridefinisce Evidence, Finding, metodo o supporto scientifico.

L'interfaccia è italiana per la baseline e interamente localizzabile. Gli ID di
route, comando, stato e oggetto non contengono testo localizzato.

## Architettura dell'informazione

```text
Document browser / Recent projects
└── Project
    ├── Overview
    ├── Sources
    ├── Corpora
    ├── Investigations
    │   └── Investigation
    │       ├── Question & scope
    │       ├── Collection profile
    │       ├── Plan & progress
    │       ├── Findings
    │       │   └── Evidence → Artifact → Source/Method
    │       ├── Compare
    │       ├── History
    │       └── Report
    └── Project diagnostics/settings
```

Ricerca globale e object explorer sono accessi trasversali, non nuove gerarchie.
La route canonica contiene ProjectID, oggetto tipizzato, eventuale subroute e
selezione. Non conserva indici di riga o nomi mutabili.

Nel primo incremento macOS di ADR-0048, **Studio** è un accesso primario nella
sidebar del progetto. Una lettura ampia resta dominante; taccuino e confronto
sono richiesti dalla persona. Il percorso di GS-UX-001-18 mette in sequenza
lettura, raccolta di passaggi e conclusioni collegate. Organizzazione, provenienza
tecnica ed esportazione restano accessi secondari. Il lettore nativo conserva
selezione/copia e offre selezione per frasi o caratteri come alternativa accessibile.
Lo stato autorevole del taccuino è distinto dalla posizione di lettura per scena.

## Modello di scena e finestra

Ogni `.glifi` è un documento. Una scena appartiene a un progetto e conserva route,
selezione, inspector, colonne visibili e compare set; il dominio e gli Artifact
sono condivisi in sicurezza tra scene.

Su macOS il modello primario è finestra documentale con
`NavigationSplitView`: sidebar, contenuto e inspector/detail quando lo spazio lo
consente. Finestre aggiuntive possono mostrare confronto, grafico o fonte dello
stesso progetto mediante ID; non duplicano lo store.

Su iPadOS lo stesso percorso si adatta a una, due o tre colonne. Compact presenta
stack e sheet; regular usa split view. Stage Manager, Split View, orientamento,
touch, puntatore e tastiera non cambiano capacità o significato. La chiusura di una
scena non annulla lavoro condiviso se esiste un altro owner o un commit necessario.

## Selezione e navigazione

`Selection` è una somma tipizzata: source, document, corpus, investigation,
finding, evidence, artifact, annotation o source span. Selezione singola, multipla
e compare set sono distinti. Azioni incompatibili con una selezione multipla sono
disabilitate con motivo accessibile.

Back/forward ripercorre route semantiche. Drill-down da Finding a Evidence, metodo
e fonte conserva l'origine per il ritorno. Un oggetto eliminato mostra una route
degradata con recovery, non reindirizza silenziosamente. Restoration valida ID,
versione e autorizzazioni prima di mostrare contenuto.

Il confronto è una primitive: due o più oggetti compatibili formano un
`ComparisonScope`; tipi incompatibili producono spiegazione e alternative. Drag &
drop aggiunge fonti o oggetti solo dopo validazione, con anteprima dell'operazione.

## Comandi e input

Tutte le azioni principali sono raggiungibili da menu e tastiera su macOS e da
menu/comandi appropriati su iPadOS. Comandi canonici: nuovo/apri/salva, importa,
nuovo corpus, nuova indagine, esegui/pausa/annulla piano, cerca, confronta, mostra
fonte, mostra metodo, aggiungi al rapporto, esporta, undo/redo e diagnostica.

Toolbar contiene solo azioni contestuali frequenti; menu contestuale non è l'unico
accesso a una funzione. Shortcut seguono convenzioni Apple, non interferiscono con
VoiceOver e sono localizzabili nella presentazione. Focus e tab order sono
deterministici; touch target e hover non sono portatori unici di informazione.

## Design system nativo

Il sistema usa font, materiali, controlli, simboli e colori semantici di sistema.
Token Glifi sono ruoli, non valori cromatici rigidi:

| Token/Componente | Significato |
| --- | --- |
| `surface.primary/secondary` | Gerarchia delle superfici |
| `status.informative/success/warning/critical` | Stato con icona e testo, mai solo colore |
| `evidence.observed/modeled/inferred/generative` | Classe epistemica con etichetta |
| `FindingCard` | Conclusione, supporto, caveat e azioni |
| `EvidencePanel` | Osservazione, misura, scope e lineage |
| `CaveatBanner` | Limite, impatto e possibile rimedio |
| `SourceExcerpt` | Estratto verificabile e coordinate |
| `MethodDisclosure` | Variante, parametri, precondizioni e versione |
| `ProgressSummary` | Stato aggregato, fase, annulla e risultato parziale |

Spaziatura e tipografia usano una scala piccola basata sulle metriche di sistema e
Dynamic Type; non si fissano dimensioni che taglino localizzazioni. Reduce Motion,
Differentiate Without Color, Increase Contrast e dimensioni di testo sono
rispettati. Grafici hanno alternativa tabellare GS-VIZ.

## Gerarchia essenziale

La panoramica **DEVE** rendere evidente la prossima azione utile rispetto allo
stato effettivo del progetto: crearlo o aprirlo, importare testi, formulare una
domanda oppure esplorare i risultati. Una sola azione riceve enfasi primaria;
riapertura e azioni secondarie restano disponibili quando applicabili.

Il percorso di ricerca precede gli strumenti trasversali nella sidebar. La
toolbar privilegia l'importazione contestuale; le azioni sul progetto sono
raccolte in un menu di sistema. Il riepilogo del percorso è espandibile.

Conteggi, conclusioni, limiti e copertura restano leggibili al primo livello.
Identificatori, digest, richieste serializzate e contratti di implementazione
sono raggiungibili tramite disclosure native nello stesso contesto. Il dettaglio
non può occultare un caveat necessario all'interpretazione.

La barra di stato appare durante il lavoro o in presenza di un errore. Il
messaggio di errore resta visibile; la causa strutturata è espandibile. Lo stato
di motore pronto non occupa stabilmente il contenuto del progetto.

Con spazio insufficiente o testo di accessibilità, l'elenco dei risultati e il
relativo dettaglio **DEVONO** usare un percorso sequenziale; i pulsanti si
dispongono in verticale prima di troncare le etichette. Una selezione di gruppo
**DEVE** essere riconoscibile anche da simbolo e valore accessibile. Le tabelle
interattive **DEVONO** offrire attivazione da tastiera oltre a touch e VoiceOver.

Queste regole applicano GS-UX-001 e GS-STD-001-29 senza cambiare metodi, lineage,
formato persistente o capacità analitiche. L'evidenza di implementazione e i
limiti della verifica sono registrati in
[GS-VER-150](../evidenze/GS-VER-150-interfaccia-essenziale.md).

## Riprogettazione per compiti e laboratorio avanzato

La nuova richiesta applicativa di ADR-0034 amplia gli accessi alle capacità già
realizzate. La sidebar **DEVE** distinguere i compiti del progetto e della ricerca
dagli strumenti specialistici e dalle azioni di condivisione. Gli strumenti del
laboratorio sono raggiungibili direttamente, con etichette comprensibili e nomi
scientifici disponibili nel contesto. La ricerca delle destinazioni filtra gli
accessi; non esegue query sul corpus e non cambia la selezione effettiva dei dati.

Progetto corrente, disponibilità delle fonti e stato del lavoro **DEVONO** restare
riconoscibili. La panoramica orienta verso una prossima azione reale e offre
accessi al lavoro già disponibile senza richiedere di completare in ordine una
procedura che non rappresenta il compito della persona. Un controllo disabilitato
indica la precondizione mancante e non simula un risultato.

La selezione dello strumento **DEVE** essere distinta dall'ambito delle fonti.
Cambiare strumento non può dichiarare ricalcolato un risultato precedente;
richiesta effettiva e draft restano separati. Parametri avanzati e dettagli
metodologici si espandono nel contesto, mentre limiti che cambiano
l'interpretazione restano leggibili accanto al risultato. Le liste estese hanno
totali, pagine o selezioni bounded; una preview non è chiamata risultato completo.

Il laboratorio avanzato macOS usa le API GlifiKit in memoria. La sua UI **DEVE**
dichiarare quando un risultato è disponibile soltanto nella sessione e non è
stato salvato come Artifact o incluso nel rapporto dell'indagine. Riapertura,
export persistente e presenza nella cronologia non possono essere suggeriti da
azioni o badge che il dominio non sostiene. Le identità e i metodi dei risultati
già persistiti continuano a usare i contratti esistenti.

Ricerca/KWIC e conclusioni **DEVONO** conservare selezione, ambito e possibilità
di risalire alla fonte durante il drill-down. Con spazio ridotto il dettaglio è
sequenziale; finestre larghe possono affiancare elenco e dettaglio. Nessuna nuova
gerarchia di algoritmi sostituisce domanda, osservazioni ed evidenze.

Le azioni frequenti hanno accesso da tastiera, focus riconoscibile e label
localizzate; la sidebar non è l'unico mezzo per raggiungerle. L'ordine semantico
funziona con testo grande e layout da destra a sinistra. La disponibilità di
questi controlli nel codice non dimostra la loro efficacia con tecnologie
assistive: esiti e limiti del nuovo lotto sono in
[GS-VER-222](../evidenze/GS-VER-222-riprogettazione-gui.md).

## Pattern di stato

### Ricerca e catalogo strumenti

Il campo di ricerca è presentato quando esistono progetto e fonti. In assenza
di questi prerequisiti la UI offre azioni reali di salvataggio, apertura o
importazione coerenti con lo stato del documento. Non invita a scrivere in un
campo disabilitato. Il risultato, l'espressione eseguita, la selezione e la fonte
si pubblicano insieme dopo le letture necessarie; una failure conserva il
contesto precedente. Una bozza diversa dall'espressione eseguita è segnalata
esplicitamente, con testo e simbolo, e l'espressione effettiva resta leggibile.

Invio nel catalogo apre soltanto un risultato complessivo unico tra strumenti
e metodi. Più famiglie con corrispondenze non introducono precedenze implicite.
Il riepilogo mostra conteggio e istruzione coerente con la selezione possibile.

Nome e valore accessibili della diagnostica e dello stato del motore sono
distinti. Una nuova failure viene annunciata tramite API di sistema senza
spostare il focus; il progresso ordinario non genera annunci ripetitivi.
L'efficacia con tecnologie assistive richiede un audit dedicato, distinto dalla
verifica del codice e dalla compilazione delle API di accessibilità.

Ogni superficie data-driven implementa gli stati:

- `empty`: spiega il valore e offre un'azione reale;
- `loading`: mostra fase e cancellazione, evitando spinner indefiniti quando esiste
  progresso misurabile;
- `partial`: dichiara ciò che è pronto, ciò che manca e se è già verificabile;
- `ready`: mostra risultato, scope e freshness;
- `insufficient`: distingue dati insufficienti da “nessun effetto”;
- `recoverableError`: conserva lavoro valido e offre retry/correzione;
- `blocked`: indica precondizione o autorizzazione mancante;
- `corrupt`: impedisce mutazioni e conduce a recovery/diagnostica.

Il testo di errore è prodotto da codice e argomenti localizzabili. Non espone path,
stack trace o contenuto sensibile. L'azione primaria non promette recupero se non è
tecnicamente disponibile.

## Presentazione progressiva

Livello 1: conclusione e stato di supporto. Livello 2: Evidence e confronto.
Livello 3: fonti e visualizzazione interrogabile. Livello 4: metodo, parametri,
versioni e diagnostica. Ogni livello è raggiungibile senza perdere scope o focus.
Una persona esperta può aprire direttamente il dettaglio tecnico; ciò non trasforma
la home in un catalogo di algoritmi.

## Accessibilità e localizzazione

Ogni oggetto interattivo possiede label, value, hint e azioni appropriate; gruppi,
heading e rotori riflettono la struttura semantica. Selezione in grafico aggiorna
un'annunciazione concisa e la tabella equivalente. Ordine di lettura segue ordine
logico, non coordinate casuali.

Stringhe, plurali, date, misure e numeri passano da String Catalog e formatter.
Testi scientifici usano chiavi GS-UX-001-14 con argomenti tipizzati. Layout è
provato con italiano, inglese, pseudolocalizzazione espansa e direzione RTL anche
se l'arabo non è una lingua di rilascio iniziale.

## Criteri di validazione

- prototype test delle route Must su tutte le size class;
- round-trip di restoration, back/forward, multiwindow e selezione;
- audit VoiceOver, tastiera, Dynamic Type, contrasto e Reduce Motion;
- studi con compiti GS-UX per efficacia, comprensione e calibrazione;
- snapshot e UI test localizzati senza basarsi esclusivamente su coordinate;
- nessun comportamento di dominio implementato soltanto nella view.

## Stato implementativo iniziale

La prima superficie condivisa usa `NavigationSplitView`, file importer di sistema,
chiavi semantiche `it`/`en` e stati `empty`, `loading`, `ready` e
`recoverableError` per il profilo TXT. Il lavoro attraversa `StudioHomeModel`,
GlifiKit e GlifiCore; la view non implementa tokenizzazione o conteggi.

Build macOS/iPadOS e localizzazione sono verificate automaticamente. Restoration,
document scene `.glifi`, route complete, VoiceOver manuale, tastiera end-to-end e
studi con utenti restano gate aperti; la presenza della UI non li dichiara superati.
