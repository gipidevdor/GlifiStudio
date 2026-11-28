<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Scenari di analisi e copertura automatica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-TST-001 |
| Tipo | Piano controllato degli scenari di verifica |
| Versione | 1.0.3 |
| Stato | Implementato; esiti storici in GS-VER-303, completamento GUI verificato nello snapshot isolato di GS-VER-342; gate condiviso non attestato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di realizzare i test degli scenari di analisi e aggiornare la documentazione |
| Riferimenti | GS-STD-001-16; GS-API-003; GS-UX-001-17; GS-DOR-303; GS-DOR-342; GS-VER-342 |

## Perimetro e inventario

La matrice eseguibile è [analysis-scenarios.json](../../Config/Testing/analysis-scenarios.json).
La matrice enumera le operazioni pubbliche e collega contratti, test, oracoli
e limiti. Il controllo statico attesta inventario e riferimenti, non deduce
l’effettiva esecuzione né la correttezza della mappatura variante/test. Non rappresenta ogni possibile corpus, input o combinazione di
parametri. La sola presenza nella matrice non dimostra il superamento di un test né la correttezza dell’associazione variante/test: quest’ultima richiede revisione e prove runtime separate.

| Gruppo | Varianti correnti | Percorso verificato |
| --- | --- | --- |
| Statistica | 44 | Kit/CLI e modello macOS |
| Operatori | 45 | Kit/CLI e tutti gli esempi del modello macOS |
| Valutazione | 13 | Kit/CLI; cinque evaluator e tempo nel laboratorio macOS |
| Operazioni di progetto | 27 | Sessione Kit/CLI e percorsi nativi pertinenti, incluse 17 analisi corpus e taglio visuale `recut-visualization` |
| Profilo di fonte | 4 formati | TXT, Markdown, PDF ed EPUB espliciti e automatici (GS-VER-310) |
| Analisi testuale | 40 tag, 63 fixture | 12 tag iniziali, 9 avanzati e 19 estensioni KH con binding operativi GUI macOS |

I primi cinque gruppi comprendono **133** varianti; con le richieste testuali
l'inventario ne comprende **173**. Il nuovo taglio visuale mantiene il progetto
invariato e usa il binding operativo condiviso con la funzione GlifiKit.
Le diciannove estensioni KH hanno ora `nativeBindings` espliciti: nove flussi
matriciali, sei linguistici/classificazione/codifica e quattro esplorativi.
Per questi profili `headlessOnly` è vuoto. Gli esiti runtime della nuova
integrazione sono registrati separatamente in GS-VER-342; la dichiarazione
statica non ne anticipa il superamento. Conteggi e prove dei checkpoint
storici GS-VER-300/303 non vengono riscritti con il nuovo inventario.

### Binding GUI dei profili KH

Ogni binding **DEVE** associare il tag compilato al caso della richiesta
Swift, al tool nativo, alla route tematica, al modello, alla vista e alle
prove operative. Il verificatore confronta dispatch tipizzato, presenza
della vista nel percorso applicativo, selezione effettiva del metodo e
inventario `allCases`; richiede il test delle route tematiche e almeno una
prova operativa nativa distinta. Un helper Swift, una stringa di fixture o
un commento non sostituiscono una dichiarazione di test eseguibile.

Le operazioni native e quelle eventualmente soltanto headless **DEVONO**
formare insiemi disgiunti e coprire esattamente l'inventario KH del compilatore.
Promuovere un tag a nativo non consiste nell'eliminarlo da `headlessOnly`:
servono binding coerente e prove. Fixture negative del verificatore coprono
binding mancanti/duplicati, route o richieste incompatibili, test assenti e
sovrapposizione native/headless, oltre all'inventario generale. Non si
attenua il confronto esaustivo con il symbol graph.

## Cinque workflow di integrazione

| Scenario | Invarianti e verifiche |
| --- | --- |
| GS-SCN-007 — Progetto e operazioni pure | Importazione di testo e Markdown Unicode, ordine e digest delle revisioni, matrice osservata, tassi per mille, standardizzazione campionaria, Jaccard, codifica con intervalli UTF-8, crosstab e gruppi mancanti; snapshot immutata |
| GS-SCN-008 — Persistenza e revisioni | Tutte le 17 analisi corpus: riuso, richiesta invalida e riapertura; associazione con risultato manuale, aggiornamento di fonte, revisione storica distinta e riapertura senza dipendere dal file esterno |
| GS-SCN-009 — Stato dei laboratori | Cattura della richiesta, pagine complete, reset durante un task immediato non cancellato, retry, cancellazione preventiva e confine anteprima grafo a 512/513 collegamenti |
| GS-SCN-010 — Varianti e tempo | MDS multiavvio, cinque criteri LDA, SOM rettangolare/esagonale con e senza Ward; istanti e calendario con DST, intervallo superiore esclusivo, policy mancanti/fuori dominio e date invalide |
| GS-SCN-011 — Planner | Tutti gli 11 intenti pubblici, 9 capability, 8 intenti eseguibili e 3 indisponibili sul corpus dichiarato; precondizioni, richieste invalide, progresso, terminale unico, grounding, riuso e popolazione senza token |

Gli esiti del planner dipendono da dati, capability e policy. Un piano non
eseguibile può essere persistito come spiegazione: il test verifica che il
successivo rifiuto di esecuzione non aggiunga commit analitici. Le richieste
malformate conservano invece la snapshot fin dall'ammissione.

Il riuso preserva Artifact, nodi, valori, parametri e digest. Alcuni DTO derivati
ricostruiscono le generazioni dalla snapshot di lettura: il riferimento atteso
aggiorna esplicitamente soltanto quei due campi, senza eliminare campi dal
confronto scientifico completo. Un risultato di sessione non muta il progetto e
non viene presentato come Finding persistito.

## Oracoli e dati

I test usano soltanto dati sintetici e fixture versionate. Oltre alla parità
fra API e CLI, restano eseguiti i riferimenti numerici Core, gli oracoli esterni
e le proprietà per famiglia. I nuovi scenari includono calcoli manuali: χ² di
associazione pari a 10/3, Jaccard pari a 0,75, somme per mille, media zero e
varianza campionaria uno, conteggi e rilettura dei byte UTF-8. Non ricalcolano
formule nelle viste del prodotto.

La cancellazione preventiva attraversa tutte le 63 fixture sia come richiesta
tipizzata sia come JSON: **126** percorsi, con failure tipizzata e senza risultato
parziale. Le prove durante il calcolo e dopo il reset restano distinte dalle
prove di pre-cancellazione; non si usano sleep per ordinare gli eventi.

## Esecuzione e manutenzione

- `make check-analysis-scenarios` valida matrice e riferimenti contro la baseline API revisionata ed esegue i controlli negativi del verificatore, compresi i binding nativi KH.
- `make quality-static` include lo stesso controllo senza richiedere Xcode.
- `make verify` esegue tutti i test condivisi e macOS, parità CLI, oracoli, PDF/A, recovery e build Debug/Release; ricontrolla la matrice con il symbol graph appena prodotto dal compilatore.
- `make test-macos` esegue i test del modello app dal workspace. Non è un test di interazione tramite UI.

Una nuova operazione deve aggiornare insieme implementazione, test e matrice:
operazioni mancanti, duplicate o inventate, riferimenti inesistenti e deriva
dell'API compilata fanno fallire il controllo. Le varianti private dei modelli
sono percorse tramite `allCases` nei test nativi; la matrice non analizza Swift
per dedurre una superficie pubblica alternativa.

## Limiti aperti

La copertura software non promuove manifest scientifici, supporto metodologico,
G4/G5 o equivalenza con ogni configurazione di KH Coder. Test dei modelli e build
non sostituiscono UI automation, VoiceOver, Voice Control, contrasto,
pseudo-lingua, RTL, usabilità o misure prestazionali su hardware di riferimento.
La priorità attuale è macOS; iPadOS è rinviato e si esegue soltanto su richiesta
esplicita. Esiti osservati, identità dei sorgenti e diagnostici sono in
[GS-VER-303](../evidenze/GS-VER-303-scenari-di-analisi.md) per il checkpoint
originario e in [GS-VER-342](../evidenze/GS-VER-342-flussi-tematici-e-dendrogrammi.md)
per il completamento dei flussi tematici e dei diciannove adattatori KH.


## Regressione del budget globale del planner

Nove casi di confine verificano il costo aggregato: due profili da 164 e 264
unità più keyness da 556 formano un bundle da 984. Con budget 1.000 non può
aggiungersi una similarità da 684: il totale 1.668 violerebbe il limite. Le
soglie 983/984/1.000/1.667/1.668/6.191/6.192 e due scenari review controllano
operazioni, ruoli, decisioni, dipendenze, costo dei passi e indipendenza
dall'ordine delle fonti. La correzione addebita il bundle prima di valutare le
famiglie successive; non cambia formule, API o formato dei piani.


Due casi persistiti seminano un piano storico di producer `1`, valido oppure
sovrabudget. Il ricalcolo usa producer `2`: schema `1`, `planner-v2` e catalogo
restano invariati, mentre cambia l'identità della cache. I byte, i record e la
leggibilità storici sono conservati; nuova richiesta e successiva riapertura
riusano il piano corretto senza collisioni o commit ripetuti.

## Incremento della ricerca persistente

GS-SCN-012 aggiunge il catalogo `research-call` (15 operazioni), portando
l'inventario complessivo a 188 varianti. GS-SCN-013 registra il percorso dataset,
metadati, preparazione, ripristino e rapporto. Queste sono operazioni di
persistenza e presentazione: non introducono nuovi kernel numerici o prove
scientifiche implicite. I test di contratto e i riferimenti normativi sono nella
matrice; gli esiti realmente osservati sono registrati in GS-VER-343.

## Incremento dello studio documentale

GS-SCN-014 aggiunge le sei operazioni `study-call`, portando il totale a 194
varianti pubbliche; GS-SCN-015 registra lettura, raccolta, conclusioni e ritorno
alle revisioni originali. Il registro BDD comprende 18 feature, 820 scenari
espansi e 3.347 passaggi, conservando invariate le 795 attese precedenti.
Le nuove fasi nominale, input invalido e cancellazione preventiva non attestano
l'usabilità visiva; i test nativi e gli audit sono distinti in GS-VER-344.
