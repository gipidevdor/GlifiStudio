<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Scenari di analisi e copertura automatica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-TST-001 |
| Tipo | Piano controllato degli scenari di verifica |
| Versione | 1.0.0 |
| Stato | Implementato; esiti in GS-VER-303 |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di realizzare i test degli scenari di analisi e aggiornare la documentazione |
| Riferimenti | GS-STD-001-16; GS-API-003; GS-UX-001-17; GS-DOR-303 |

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
| Operazioni di progetto | 26 | Sessione Kit/CLI e percorsi nativi pertinenti, incluse 17 analisi corpus |
| Profilo di fonte | 2 formati | Plain Text e Markdown espliciti |
| Analisi testuale | 40 tag, 63 fixture | 12 tag iniziali, 9 avanzati e 19 estensioni KH |

I primi cinque gruppi conservano **130** varianti; con le richieste testuali
l'inventario ne comprende **170**. Le diciannove estensioni KH successive sono
verificate come Core/Kit/CLI: non hanno un adattatore GUI dedicato. I quattordici
profili e le cinquantadue fixture di GS-VER-300 restano un checkpoint storico,
non vengono riscritti con i conteggi di questo piano.

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

- `make check-analysis-scenarios` valida matrice e riferimenti contro la baseline API revisionata ed esegue quattordici controlli negativi del verificatore.
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
[GS-VER-303](../evidenze/GS-VER-303-scenari-di-analisi.md).


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
