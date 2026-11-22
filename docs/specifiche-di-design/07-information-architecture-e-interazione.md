<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Information architecture e interazione

| Campo | Valore |
| --- | --- |
| Identificatore | GS-UI-001 |
| Tipo | Specifica di design dell'interfaccia |
| Versione | 1.2.0 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-01 |
| Approvazione | Baseline proposta; prototipi e studi richiesti |
| Riferimenti | GS-UX-001; GS-DOM-001; GS-ANA-001; Apple HIG; ADR-0006; ADR-0016 |

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

## Pattern di stato

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
