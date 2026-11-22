<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Programma di completamento dell'analisi testuale macOS

| Campo | Valore |
| --- | --- |
| Identificatore | GS-PLAN-002 |
| Tipo | Programma operativo con inventario e backlog |
| Versione | 1.3.9 |
| Stato | Attivo; completezza per capacità ed evidenza |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richieste esplicite di completare l'analisi testuale e riprogettare la GUI; ADR-0033; ADR-0034 |

## Scopo e criterio di completezza

Completare prima macOS. I lotti di ADR-0033 usavano soltanto test automatici;
la riprogettazione successiva di ADR-0034 prevede anche osservazione della GUI
quando il Mac è accessibile. iPadOS è rimandato; la baseline storica 0.1 non viene riscritta. Una capacità
disponibile in Core, una API Kit, un comando CLI, una capability planner e un
flusso UI sono livelli distinti: nessuno implica automaticamente gli altri.

Per ogni incremento servono richiesta effettiva ispezionabile, precondizioni,
risultato bounded e leggibile, lineage, failure, test ed evidenza. Disponibilità
di libreria e superamento della build non equivalgono a completamento del prodotto,
validazione UX, revisione scientifica esterna o G4.

## Nuovo turno — Riprogettazione della GUI

La richiesta esplicita del 2026-11-22 autorizza GS-DOR-222 e ADR-0034:
navigazione per compiti, accessi diretti agli strumenti, contesto del progetto,
parametri progressivi e risultati leggibili. Le capacità già realizzate sono il
perimetro d'integrazione; non vengono introdotti metodi per ampliare il catalogo.

Il nuovo laboratorio avanzato macOS può eseguire gli operatori di ADR-0032 su
dati del progetto tramite GlifiKit. Questo supera la precedente esclusione della
UI per il solo client in memoria: persistenza, planner e rapporto dell'indagine
non sono estesi implicitamente. I risultati di sessione devono essere
riconoscibili e conservare scope effettivo, parametri e limiti.

Le implementazioni e le verifiche del nuovo lotto sono registrate in
[GS-VER-222](../evidenze/GS-VER-222-riprogettazione-gui.md): gate completo isolato
superato con 423 test package e 224 esecuzioni native macOS, build Debug/Release
di entrambe le app, oracoli, PDF/A-2u, CLI e recovery. La GUI è stata osservata
parzialmente; il Mac ribloccato impedisce di attestare gli strumenti con dati e
l'ultima correzione delle barre nel dettaglio. CMP-222 resta `implemented` per
gli audit ergonomici e assistivi aperti. L'inventario di ingresso
seguente resta storico e non descrive automaticamente la GUI riprogettata.
Lemma/POS/NER, metadati, indice scalabile, studi ergonomici e gate G4/G5 restano
unità distinte; il loro completamento non è inferito dall'esposizione di controlli.

## Inventario di ingresso, prima degli incrementi A–C

La tabella distingue la base integrata e i contratti già verificati dal codice
concomitante. GS-DOR-168 sviluppa algoritmi headless in una sessione separata:
la sua successiva evidenza GS-VER-168 è distinta dalle prove del programma
applicativo. La tabella seguente conserva lo stato di ingresso; l’aggiornamento
di chiusura distingue sotto le capacità successivamente disponibili.

| Famiglia e requisiti | Core/Kit/CLI | Planner e app macOS | Lacuna concreta |
| --- | --- | --- | --- |
| Ricerca, regex sicure, booleani, prossimità e KWIC — RF-015…018 | Implementati bounded; QueryAST condiviso e fonte originale mappata | Ricerca e fonte presenti | Lemma/POS, metadati e indice scalabile restano distinti e incompleti |
| Descrittiva, frequenze, TTR/MSTTR/MATTR — RF-019, RF-026…027 | Profilo persistito e riusabile | Profilo e piano presenti | Segmenti/distribuzioni complete aperti; UI termini limitata a venti righe |
| N-grammi parole/caratteri e filtri — RF-019…020 | API persistita e CLI, GS-VER-117 | Profilo mostra n-grammi di parole e anteprima | Parametri completi, caratteri, filtri ed esplorazione delle restanti righe assenti |
| TF/TF-IDF/BM25 — RF-030 | Varianti e ranking persistiti, GS-VER-115 | Profilo mostra pesi predefiniti | Ranking BM25 e configurazione dedicata assenti dalla UI |
| MTLD — RF-027 | Persistito, Kit/CLI, GS-VER-116 | Fuori dal flusso applicativo diretto | Parametri e confronto per documento non esposti |
| Keyness, associazione, dispersione e similarità — RF-031…032, RF-035…036 | Persistiti, varianti e oracoli indipendenti | Keyness diretto; famiglie nel planner-v2 | La UI non espone ogni variante disponibile nella API |
| Collocazioni, reti, CA/PCA/LSA/NMF e clustering — RF-021, RF-033…039 | Persistiti, Kit/CLI; GS-VER-092…112 | Planner e viste dedicate parziali, GS-VER-113/114 | Presentazione non copre tutte le operazioni dirette e i loro parametri |
| Fondazione statistica e accordo — RF-044…045 | Test, post-hoc, ricampionamento e codifiche persistite | Findings e codifica disponibili per flussi registrati | Nessun editor universale dei disegni statistici; validazione empirica distinta |
| Riassunto estrattivo — RF-042 | Due scoring e MMR, Artifact/Kit/CLI, GS-VER-146/149/151 | Nessun flusso UI o capability planner | Incremento A; mapping estratto→originale da rendere esplicito |
| MDS/SOM/CLARA/Naive Bayes/LDA/regole — RF-087 | Primitive e facciata in memoria, dodici operazioni del trasporto CLI; GS-VER-160…162 | Escluse da progetto persistente, planner e UI da ADR-0032 | Servono contratti di integrazione e provenance prima di esporle nel progetto |
| Zipf/Heaps, spectrum e crescita del vocabolario — RF-028 | GS-MET-001-05 specifica osservazioni e OLS; assenza nella base integrata; completamento algoritmico concorrente in corso | Assenti | Nuova unità scientifica, identificatori, ordine/checkpoint, dominio del fitting e oracoli |
| Metadati e tempo — RF-012…013, RF-040 | Contratto GS-MET-001-17; modello e percorso completi assenti | Selezioni per revisione, non metadata-first | Tipi, mancanti, calendario, schema persistente e invalidazione da decidere |
| Lemma/POS/NER e qualità linguistica — RF-010, RF-041 | Tokenizzazione italiana verificata; annotazioni esplicite accettate da alcuni operatori | Nessun backend annotativo completo | DA-008 resta aperta oltre la tokenizzazione; gold e soglie per compito necessari |

Fonti: [requisiti](../requisiti.md), [operazioni Kit/CLI](../api/README.md),
[trasporto headless](../api/02-richieste-analitiche.md),
[roadmap](../roadmap.md), programmi GS-DOR-002/003 già completati per i rispettivi
incrementi. I loro vecchi task completati non sono riaperti come lavoro nuovo.

## Riserva di identificatori

Gli identificatori **190–199** di DoR, evidenze e clausole CMP sono riservati al
programma applicativo macOS. Il completamento algoritmico concorrente usa
GS-DOR-168; il programma complementare GS-PLAN-180 usa i propri identificatori.
Le loro modifiche restano indipendenti e vengono preservate.

Il nuovo turno del 2026-11-22 riserva al programma applicativo macOS gli
identificatori **230–239** di DoR, evidenze e clausole CMP. Il lotto parte dal
commit `f6bba3e` in repository isolato, preservando l'integrazione concomitante
nel checkout originale; non apre nuove funzionalità. GS-DOR-230 corregge la
coppia KWIC/fonte, GS-DOR-231 misura il lookup delle etichette, GS-DOR-232
corregge selezione visuale/contesto. Gli altri ID richiedono un contratto prima
del codice; 171/172 e 205–208 restano assegnati agli altri programmi.

## Sequenza autorizzata

| Incremento | Risultato | Stato alla chiusura del lotto |
| --- | --- | --- |
| A | Riassunto estrattivo contestuale macOS, con mapping corretto dell'originale e contratto legacy esplicito | GS-DOR-190 implementato e prove mirate superate; gate e preflight macOS superati |
| B | Ranking lessicale BM25 dei documenti, distinto dalla query KWIC e con parametri/versione dichiarati | GS-DOR-191 implementato e due test mirati superati; gate e preflight macOS superati |
| C | Frequenze/ngrammi configurabili e MTLD, con risultati completi entro budget e ambito esplicito | GS-DOR-192 implementato, otto esecuzioni mirate superate; gate e preflight macOS superati |

Sono flussi dello stesso laboratorio, non un elenco indifferenziato di algoritmi.
Non si introducono nuovi metodi per riempire la UI e non si dichiara completata
l'analisi testuale con il solo incremento A.

## Disponibilità alla chiusura e backlog da rendere Ready

A–C sono disponibili e verificati nel client macOS come sopra. L'incremento
algoritmico separato [GS-VER-168](../evidenze/GS-VER-168-completamento-algoritmi.md)
registra inoltre distribuzioni/Zipf/Heaps, descrittive, aggregazione temporale e
metriche linguistiche in Core/Kit headless; TextRank e LexRank attraversano anche
il percorso persistente Core/Kit/CLI. Le nuove primitive restano candidate nei
loro manifest: questa ricognizione non ne cambia lo stato scientifico e non le
aggiunge alla UI o al planner. L'interfaccia del riassunto macOS conserva i due
metodi esplicitamente verificati da GS-DOR-190.

1. Zipf/Heaps e descrittive headless: integrazione con progetto, Artifact,
   trasporto applicabile, planner e presentazione dei dati osservati/fit/residui;
   formule e parametri già realizzati non sono riaperti come algoritmi mancanti.
2. Metadati/tempo: collegare le primitive temporali headless a schema persistente,
   query, raggruppamento e lineage del progetto. Le decisioni su dati e dimensioni
   restano necessarie; non inventare date da nomi di file.
3. Famiglie KH Coder: ponte dai documenti del progetto agli input e risultati in
   memoria, persistenza/versionamento, budget, viste e policy di interpretazione.
   La request JSON transitoria non è già un Artifact scientifico persistito.
4. Scalabilità, annotazione linguistica, accessibilità e valutazione empirica:
   mantenere separati indice/streaming, backend/gold, prove assistive e review V6.

Queste lacune restano visibili con owner provvisorio nell'iniziatore; richiedono
decisioni o unità dedicate e non entrano accidentalmente in A–C.

## Residui dell'audit macOS automatico

L'ispezione di `Apps/Shared/StudioHomeView.swift` rileva due testi di fonte,
KWIC ed evidence, ai quali `accessibilityLabel` assegna rispettivamente
`query.source` e `finding.evidence.source`, senza un valore accessibile che
esponga il testo della fonte. Il rilievo richiedeva correzione e prova
dedicate: il programma non dichiara zero problemi di accessibilità. Nessuna prova
VoiceOver è eseguita, dato il Mac bloccato e la scelta di soli controlli automatici.
La decisione sul sottoincremento resta separata da A–C; G4 rimane aperto.

GS-DOR-193 estende il rilievo al Text della preview export: i tre override sono
rimossi nel solo ramo macOS, con review statica positiva; compilazione integrata
Debug/Release e preflight macOS superati (GS-VER-193). Nessuna esecuzione VoiceOver viene inferita dalla correzione.

## Ultimo lotto e freeze

GS-DOR-195 completa la cancellazione azionabile delle sei analisi dirette macOS:
A–C, profilo corpus e keyness. Il modello possiede il task, `run` possiede busy e
la pulizia segue l'esito terminale, senza invalidare risultati già committati.
Dopo la stabilizzazione: freeze dei sorgenti e una verifica integrata del profilo
macOS/preflight, senza nuove estensioni spontanee del perimetro.

## Esito del lotto automatico macOS

A–C e le correzioni 165/166/193/194/195 sono verificate nel profilo automatico
macOS sullo snapshot di GS-VER-188: Core/Kit 399 test, 152 righe di oracoli,
due PDF/A-2u, 51 controlli CLI, 22 checkpoint di recovery e 45 esecuzioni native
macOS superate; build Debug/Release, analisi e archivio macOS senza firma validi.
Le clausole del programma sono promosse soltanto nel perimetro dichiarato.
Il backlog e i limiti sopra restano attivi: nessuna dichiarazione di tutte le
famiglie completate, parità iPadOS, audit VoiceOver, GUI reale o G4.

La chiusura sopra riguarda esattamente lo snapshot conservato di GS-VER-188.
Turni successivi di altre sessioni modificano Core, test e benchmark: restano
esclusi da questa attestazione e hanno propri owner ed evidenze. Il programma
non dichiara verificata la compatibilità con tali ottimizzazioni correnti.

## Nuovo turno — Incremento D

La successiva richiesta di miglioramenti e completamenti apre GS-DOR-197:
ponderazione TF/TF-IDF diretta, con varianti esistenti, celle osservate/zeri,
fonti e vocabolario completi, pagine da 50 e cancellazione posseduta. ADR-0033
registra l'estensione successiva; A–C e la loro attestazione storica non cambiano.
Il default UI raw/smooth/none è esplicito. Il confine app contiene i risultati
incoerenti con failure tipizzata prima della pubblicazione, senza nuove formule
o modifiche al formato. GS-DOR-196 governa il collegamento del documento dopo
busy, con richiesta più recente e cancellazione riferita al proprio token.

CMP-196 e CMP-197 sono `verified` nel perimetro automatico macOS: il lotto ha superato `make test-macos`
con 47 definizioni/128 esecuzioni, incluse cinque regressioni documentali e
78 esecuzioni specifiche per D (54 varianti, 20 DTO incoerenti, quattro ulteriori
test). `make verify-macos` e il packaging `--macos-only` sono superati sul nuovo
snapshot di 830 file, manifest `58d18024…80e8b`: 433 test Core/Kit, 153 righe di
oracoli, due PDF/A-2u, CLI/recovery e build/analisi/archivio macOS validi. Non si
riutilizza il vecchio gate come prova del nuovo codice. GS-VER-196/197 registrano
copertura e limiti, senza G4 o attestazione delle modifiche successive al freeze;
La chiusura conserva lo stato storico di quel lotto.

## Nuovo turno — Incremento E

La successiva richiesta di miglioramenti e completamenti assegna GS-DOR-198
alla keyness diretta nel confronto dell'Indagine macOS. L'anteprima di venti
termini lascia spazio all'intera famiglia paginata da cinquanta, con popolazioni
esplicite e tutti i campi v2: test selezionato, p G-test/selezionato, q BH,
effect size e intervalli. La soglia diagnostica non modifica la regola Fisher
fissa e la presentazione non riduce la famiglia dopo aver visto i p-value.

ADR-0033 E approva un ponte compatibile del livello di confidenza Core già
maturo: init Kit a due argomenti invariato e nuovo init a tre argomenti senza
default. UX17 E e la DoR Ready precedono il codice; non vengono introdotti
nuovi metodi, formule, schema o migrazioni. Il contenimento app è bounded e
precede ogni pubblicazione dello stato effimero.

CMP-198 è `verified` nel perimetro automatico macOS: 67 nuove esecuzioni client e sette di facciata superate;
target macOS complessivo con 55 definizioni/195 esecuzioni, zero fallite/saltate.
GS-VER-198 registra freeze e gate/preflight propri superati. La sua
dipendenza GS-DOR-199 corregge l'identità
del descrittore e l'admission della cache: livello di confidenza corrispondente
alla richiesta e limite della famiglia rispettato anche sul riuso; nessun nuovo
kernel o formato. CMP-199 è `verified` nello stesso perimetro: due RED osservati prima del fix e
quattro test Core superati dopo, inclusi il guard su un payload di livello
difforme sotto un nodo reale e la riapertura del legacy senza riscrittura
(payload keyness v2 con livello, descrittore precedente privo del parametro).

`make verify-macos` e packaging `--macos-only` sono superati sullo snapshot
di 854 file, manifest `0ed9b459…add91`: 448 test Core/Kit, 153 righe di oracoli,
due PDF/A-2u, CLI/recovery/QueryAST e 195 esecuzioni native; build Debug/Release,
analisi e archivio macOS validi. Sorgenti e prove sono conservati nel dossier
di GS-VER-198. Nessuna build iPadOS, GUI reale o chiusura G4 è attribuita al lotto;
i sorgenti successivi al freeze richiedono nuove prove.
A–D e i lotti lifecycle precedenti rimangono chiusi sul rispettivo contenuto
provato; iPadOS è rimandato e l'intervallo 190–199 è ora assegnato.

## Lotto del 2026-11-22 — Correttezza e lookup misurato

Il lavoro isolato sulla base `f6bba3e` applica la riserva 230–239 senza
introdurre nuove funzioni analitiche. GS-DOR-230 e GS-DOR-232 correggono
rispettivamente coppia KWIC/fonte e selezione visuale/contesto, comprese le
condizioni busy, failure e assenza di fonte. Una prima corsa RED aveva due
aspettative di test errate sul retained state; dopo la sola correzione delle
aspettative, cinque RED pertinenti precedono la patch. Il GREEN completo
supera 60 definizioni/200 esecuzioni, zero fallite/saltate. Dopo integrazione con
GUI 222, il gate e preflight dello snapshot 4d6969dd sono superati, con 67
definizioni/224 esecuzioni native e 486 test Core/Kit. CMP-230/232 sono
`verified` nel perimetro automatico dello snapshot; il layout HomeView successivo
del lavoro GUI resta escluso e ha evidenza separata.

GS-DOR-231 misura il helper reale per le etichette nelle viste macOS. Le sonde
SHA/alias rimangono diagnostiche; il protocollo finale usa UUID, storage distinto
e lifetime esplicito. Baseline e quattro candidati hanno output completi
identici: tre varianti sono respinte per regressioni, il predicato Sendable
di Ready 1.5 mantiene lo stato MainActor e migliora il batch lungo da
49,061791 a 2,069916 ms. I piccoli costi aggiuntivi e la dispersione restano
espliciti; il beneficio non è universale e non viene attribuito a SwiftUI.body,
GUI o energia. Il helper finale è integrato; gate e preflight ffbfb431 sono
superati, con 486 test Core/Kit e 67 definizioni/224 esecuzioni native.
CMP-230/231/232 sono `verified` nel perimetro automatico di tale checkpoint,
derivato da 4d6969dd più il helper finale e i documenti del lotto. Il WIP 223 e
il layout HomeView successivo sono esclusi e preservati nella copia condivisa.
Le evidenze 230–232 mantengono le generazioni distinte; iPadOS e G4 restano aperti.

## Sottoincremento GS-DOR-273 — Barriera di reset dei laboratori macOS

GS-DOR-273 attua il lifecycle richiesto da GS-DOR-223. La Ready precede codice
e test con l'identificatore locale iniziale 233, poi 235; l'allineamento usa
GS-DOR-273 e GS-VER-273 del registro remoto, senza inventare nuove corse. Il fix
Advanced legacy e i guard preesistenti di Evaluation/Corpus mantengono le
rispettive attribuzioni. Il candidato latest137 preserva executionRevision
peer, più forte perché protegge anche dalle esecuzioni superate.
CMP-233 è verified per automatici sul checkpoint ea48ba88: 592 test Core/Kit,
104 definizioni/327 esecuzioni native, 90 controlli CLI/30 fixture condivise,
oracoli, PDF/A, recovery e gate/preflight macOS superati. L'originale legacy02
conserva la GUI diversa; non viene certificato l'intero checkout corrente.
Nessuna nuova formula, API pubblica, migrazione o backend appartiene al lotto.

## Sottoincremento GS-DOR-274 — Presentazione corpus coerente su macOS

GS-DOR-274 è Ready prima della correzione di invalidazione sincrona e
separazione dei task di filtro/proiezione. L'ultima scelta di asse, tabella e
ricerca è conservata; pending espone progresso localizzato, nasconde conteggio
e vuoto transitori e disabilita le pagine senza bloccare le scelte. La suite
StudioCorpusPresentationTests distingue l'errore iniziale di fixture dal RED
pertinente, senza trap volontari o hook di produzione. GREEN legacy e allineato
restano distinti; CMP-234 è verified per automatici sul checkpoint ea48ba88,
con gate e packaging macOS superati, senza cambiamenti numerici Core/Kit.
Il lotto resta limitato a GS-DOR-273/274; budget e ulteriori problemi di chiarezza
statistica sono nel backlog. Nessuna nuova feature o promozione scientifica;
iPadOS, GUI manuale e G4 restano fuori perimetro.
