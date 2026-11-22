<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-304 — Componenti e campi nativi nei laboratori macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-304 |
| Tipo | Evidenza di implementazione e verifica applicativa |
| Versione | 1.1.0 |
| Stato | Superato nel perimetro automatico macOS; audit GUI e assistivi aperti |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | GS-DOR-304 Ready prima del codice; gate e preflight automatici macOS superati sul checkpoint identificato |
| Riferimenti | GS-DOR-304; CMP-304; RQ-012; RQ-047; RQ-063; GS-APL-002; GS-APL-003; GS-STD-001-29; GS-I18N-002; ADR-0034; ADR-0041 |

## Perimetro

[GS-DOR-304](../pianificazione/dor-hig-laboratori-macos.md) delimita due correzioni
strutturali macOS: tab native nel ramo compatto dei sette laboratori e campi
permanentemente etichettati con azioni contestuali nel laboratorio Valutazione.
Le prove sono automatiche, secondo la richiesta dell'utente; il lotto non
introduce un harness UI, algoritmi, API Core/Kit/CLI, identità di dominio,
formati persistenti o comportamenti iPadOS.

## Identità del checkpoint finale

La copia di lavoro isolata nasce da `8901f4ad3f17a27f02fc7628221641d66346b38c`
e viene allineata prima della verifica alla nuova baseline main
`d368285010dca17f5ef72819da25b6890d0de32a`. I 33 file entranti dei profili KH
non modificano le sette view del lotto. La composizione conserva gli
aggiornamenti upstream degli aggregati e non incorpora il WIP 302 del checkout
principale né il lavoro successivo del lotto 303.

Il checkpoint conclusivo comprende **1172 file** e ha fingerprint SHA-256
`9c9e00989f3b31bc50b6632e55d63afb3882f2c2ac320043a326008d5c285146`.
L'inventario deriva dai file Git versionati e nuovi non ignorati; per ogni path
registra digest del contenuto e modalità. Il fingerprint è il digest del JSON
canonico composto da baseCommit e inventario ordinato. Il produttore controlla
l'identità prima, durante e dopo la cattura dell'archivio.

Le prove durevoli risiedono in
`~/Library/Caches/GlifiStudio/evidence/macOS-2026-11-22-gui-304/`:
`source-manifest.json`, `verified-source-snapshot.tar.gz`, log, risultati e review.
Il digest identifica l'ingresso delle prove, non un successivo aggiornamento
editoriale della documentazione né l'intero checkout condiviso corrente.
Il confronto post-gate registra **1172 file con hash e modalità invariati**,
nessuna variazione durante le prove e i due exit 0. `compiled-view-objects.json`
conserva inoltre i digest di **28 oggetti compilati** delle sette view nelle
configurazioni verificate; non costituisce una prova di rendering.

## Correzioni implementate e review

| Area | Risultato strutturale |
| --- | --- |
| TextAnalysis, AdvancedAnalysis, CorpusMethods, Statistics, Evaluation, Operators, Linguistic | Il cambio fra impostazioni e risultati nell'area principale compatta usa `TabView` nativa con stile grouped, etichette testuali e margine del contenitore. I 14 pannelli usano l'initializer SDK `Tab(value:content:label:)`. Binding, valori selezionati, soglie, ramo largo `HSplitView` e transizioni esistenti restano invariati |
| Contenuti dei pannelli | I Form esistenti restano i contenuti delle tab. Advanced conserva uno ScrollView per pannello, ora interno alla rispettiva tab. Nessun task, calcolo o nuova azione è aggiunto dal cambio di pannello |
| Editor Valutazione | Etichette visibili permanenti con campo compilato, campi multipli disposti verticalmente e nomi contestuali per osservazione/documento, riferimento/predizione e indice locale degli attributi o entità. I contenitori conservano i controlli figli navigabili |
| Localizzazione | Dodici nuove chiavi di formato con traduzioni it/en; 2664 chiavi preesistenti semanticamente invariate. La patch testuale finale del catalogo è minima; non è dedotta da ciò una prova di espansione o RTL realmente renderizzata |
| Identità delle righe annidate | Ripristinati i due `ForEach(Binding)` nativi di attributi ed entità. Ogni editor costruisce una mappa degli ordinali dalla collezione corrente una sola volta, con costo atteso O(n) e limiti preesistenti. Le righe catturano un UUID immutabile usato dalle azioni di rimozione; gli ordinali non diventano indici per leggere una collezione successiva |

Le review indipendenti sono registrate in `review-final-tabs.json`,
`review-tabs-accessibility.json`, `review-tabs-sdk-corrected.json`,
`review-evaluation.json` e `review-binding-final.json`. Il controllo delle
identità rimuove il rischio strutturale rilevato nel tentativo precedente;
**nessun crash SwiftUI è stato riprodotto**. La review non garantisce che
l'API Binding nativa sia immune a ogni possibile errore di stato.

Le scelte corrispondono al caso macOS indicato dalle HIG per
[segmented controls](https://developer.apple.com/design/human-interface-guidelines/segmented-controls#macOS)
e [tab views](https://developer.apple.com/design/human-interface-guidelines/tab-views).
Le [HIG dei campi](https://developer.apple.com/design/human-interface-guidelines/text-fields#Best-practices)
orientano etichette e disposizione verticale. L'adozione del componente corretto
è una correzione concreta, non una certificazione HIG dell'intera app.

## Esiti osservati sul checkpoint finale

Il runner di `make verify` registra **exit 0**, durata 427,839 secondi e
fingerprint `9c9e0098…85146`; il preflight macOS registra **exit 0**, durata
305,723 secondi e lo stesso fingerprint. I dati seguenti provengono dai log di
questa generazione, senza trasferire esiti dai checkpoint precedenti.

| Controllo | Esito osservato |
| --- | --- |
| Swift Testing Core/Kit | **771 test** nei due riepiloghi: 631 Core e 140 Kit, entrambi superati |
| Oracoli numerici | **236 righe** riprodotte e collegate ai test Swift; controllo Binary64 Fraction distinto, **64 casi sintetici** riprodotti senza codice prodotto |
| Trasporto analitico | **63 fixture condivise, 189 controlli CLI**, parità nativa entro 1e-12; tutti i 40 casi request enumerati dal compilatore hanno fixture CLI |
| Parità Kit/CLI | **130 operazioni, 260 confronti completi**; 2816 dichiarazioni pubbliche/firme/membri DTO recensiti dal controllo API |
| Input ostili CLI | **51 controlli** JSON, versione, risorse, file, permessi, argomenti e privacy |
| Recovery e query | **22 checkpoint** di process-kill recovery validi; QueryAST CLI: parità, limiti e input ostili superati |
| PDF/A-2u | **Due PDF conformi**, con veraPDF configurato nella stessa run |
| Test nativi macOS | **113 definizioni, 345 esecuzioni**: 16 definizioni parametrizzate producono 248 esecuzioni, più 97 non parametrizzate. Zero failure, skip e expected failure; runtimeWarnings e insights vuoti nel nuovo xcresult |
| Build Debug/Release macOS | Debug e Release superate nello stesso gate macOS terminato con exit 0 |
| Preflight App Store macOS | Analisi statica Release e archivio senza firma validi; il comando termina con exit 0 |

Il log finale del preflight ha SHA-256
`2cb9e5e2d1147c40eae52d159120b7f7c63831d1819022cbd00b3ce5bd2d72ff`.
Xcode 27.2 (27B52), Apple Swift 6.4.2, host macOS 27.2.1 Apple silicon;
Python 3.12.14 e veraPDF 1.30.4 già installati. I log conservano i diagnostici
host relativi a CoreSimulator 1171.7.0, precedente al build 1174.21.0 atteso,
e al placeholder Any Mac. L'exit 0 non diventa una dichiarazione di assenza
universale di diagnostici. Nessuna firma, notarizzazione o pubblicazione è
eseguita dal preflight senza firma.

## Generazioni precedenti distinte

| Generazione | Esito e motivazione |
| --- | --- |
| `9ae1f25f` | Verifica e preflight interrotti deliberatamente per allineare la baseline main avanzata; nessuna failure del compilatore motiva questo arresto |
| `96abbea1` | Gate exit 2 e preflight exit 65: initializer `Tab(titleKey, value:)` senza immagine non disponibile nel SDK installato, con errori espliciti e timeout del type-checker. L'archivio non è raggiunto. Nessuna suite nativa è dichiarata eseguita da tale fallimento |
| `c7ba703c` | Initializer corretto con closure label testuale; build Debug e preflight macOS superati. Il gate completo è interrotto deliberatamente dopo la review delle identità Binding, prima della chiusura. Nessun crash riprodotto; risultati non trasferiti automaticamente al checkpoint finale |
| `9c9e0098` | Due ForEach Binding nativi con mappa ordinale; nuove corse indipendenti del gate e preflight, entrambe exit 0. Riepilogo nativo della stessa run acquisito: 113 definizioni e 345 esecuzioni |

Le prove e i sorgenti dei predecessori restano in sottodirectory di generazione;
non vengono sovrascritti né qualificati come risultato della generazione finale.

## Stato e limiti

CMP-304 rimane **implemented**: i componenti e gli editor sono corretti nel
perimetro strutturale e hanno prove automatiche circoscritte; la clausola
include aspetti di interazione che le sole prove automatiche esistenti non
attestano. RQ-012 e RQ-030 restano aperti.

Non sono osservati layout con dati durante ridimensionamento, focus effettivo,
sequenza di tabulazione, cancellazione e aggiunta delle righe tramite GUI,
VoiceOver, Voice Control, Full Keyboard Access, testo massimo, contrasto
misurato, pseudo-lingua o RTL renderizzati. Anteprime, label e suite dei modelli
non sostituiscono un audit end-to-end o studi con persone rappresentative.
Il lotto non aggiunge test che rispecchiano il sorgente per una modifica
presentazionale reversibile. Nessun nuovo requisito EA «Da introdurre» è
convertito in gate; non si dichiarano G4/G5, iPadOS, conformità universale HIG,
accessibilità completa o un beneficio prestazionale/energetico.

`native-results.json` seleziona il solo bundle con avvio e fine compresi
nell'intervallo del gate riuscito e distingue definizioni logiche, esecuzioni
parametrizzate e diagnostici host. `post-gate-source-comparison.json` registra
l'identità dei sorgenti durante gate e preflight. I metadata conclusivi
aggiornano soltanto gli esiti del lotto dopo le prove, senza cambiare il runtime
congelato; richiedono verifica documentale separata.
