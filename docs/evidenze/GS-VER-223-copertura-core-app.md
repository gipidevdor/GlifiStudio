<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-223 — Copertura funzionale del core nell'app

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-223 |
| Tipo | Evidenza di implementazione e verifica applicativa |
| Versione | 1.0.0 |
| Stato | In verifica; audit applicativi aperti |
| Responsabile | Codex, esecuzione automatizzata interna |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita; GS-DOR-223; ADR-0041 |

## Perimetro e copertura

L'incremento espone le capacità analitiche utente già implementate dal core.
Gli operatori infrastrutturali (identificatori, digest, DAG, transazioni,
recovery, tokenizer ed estrazione) restano integrati nei percorsi del prodotto.
Non si introducono algoritmi scientifici, dipendenze, rete, entitlement o
migrazioni `.glifi`. Il laboratorio macOS rimane distinto dall'adattamento
specifico iPadOS ancora pianificato. L'editor qualitativo condiviso è esteso su
entrambe le piattaforme.

| Famiglia del core | Percorso applicativo |
| --- | --- |
| Corpus, query, indagine, keyness e risultati interpretati | Percorsi esistenti: Fonti, Ricerca, Indagine e Risultati |
| Riassunti, BM25, n-grammi, MTLD e ponderazione | Laboratorio testuale esistente; configurazioni e scope espliciti |
| Associazione, dispersione, similarità e collocazioni | Analisi del corpus: API persistite, parametri e risultati completi |
| Reti lessicali e co-occorrenze a finestra | Analisi del corpus: nodi, archi, parametri ed evidenza della provenienza |
| CA, PCA, LSA, NMF, clustering gerarchico e k-means | Analisi del corpus; operatori su dati espliciti per le decomposizioni numeriche |
| Confronti fra gruppi, post-hoc, correlazioni e dati appaiati | Analisi del corpus: gruppi e abbinamenti dichiarati |
| MDS, SOM, CLARA, LDA, classificatore, validazione e regole | Laboratorio avanzato esistente, con richieste e risultati di sessione |
| Descrittive, test, effetti, intervalli e ricampionamento | Statistica: serie, gruppi, conteggi e parametri espliciti |
| Accordo, contingenza e distribuzioni | Statistica: giudizi mancanti distinti dallo zero; misure e diagnostici del core |
| Matrici, distanze, similarità e divergenze | Operatori: dati bounded, trasformazioni e decomposizioni del core |
| Centralità, componenti, comunità e modularità | Operatori: grafo diretto esplicito, pesi e partizione dichiarati |
| Frequenze, spettro, crescita, Zipf e Heaps | Leggi lessicali persistite; operatore esplicito con checkpoint scelti |
| Aggregazione temporale | Valutazione e tempo: date civili o istanti dichiarati, calendario, fuso e policy mancanti/fuori intervallo |
| Classificazione, lemmi, confini, NER e morfologia | Valutazione e tempo: confronto di annotazioni gold/predette, senza backend NLP implicito |
| Codebook e storia qualitativa | Editor condiviso: revisioni complete, genitori, istruzioni, più codebook, mapping merge/split/rename e note di fonte/categoria/codifica |
| Export scientifico e delle viste | Percorsi esistenti; preparazione CSV/JSON/bundle fuori Main Actor e failure degli exporter esplicite |

Il catalogo ricercabile porta al metodo selezionato nel laboratorio corretto.
L'accesso alla funzione non equivale a validazione scientifica, idoneità dei dati
o equivalenza indiscriminata con KH Coder. Gli stati scientifici esistenti non
sono promossi da questo incremento.

## Confini e conservazione

Le diciassette analisi dirette del corpus riusano gli Artifact già previsti e
pubblicano l'esito solo dopo la lettura dello snapshot aggiornato. I laboratori
puri mantengono input e risultati di sessione, congelando i dati effettivi;
il JSON esplicito non è un nuovo formato di progetto. Gli evaluator richiedono
riferimenti forniti dalla persona. Le date non derivano dai nomi dei file.

I nuovi calcoli passano da GlifiKit e si eseguono fuori Main Actor; le viste
mostrano tabelle paginabili. Gli operatori espliciti hanno limiti di 200 × 200
celle, 256 nodi, 4.096 archi e 100.000 token; ogni editor è limitato a 1 MiB.
I contratti delle altre facciate conservano i propri limiti dichiarati. La
cancellazione usa l'ownership del modello; failure e reset non pubblicano un
risultato tardivo. Nessuna riduzione di latenza o consumo è dedotta dalla sola
struttura del codice.

## Composizione con il nuovo core

Durante il lavoro `main` ha pubblicato le capacità native di ADR-0035 e le
integrazioni Foundation/ProcessInfo. La composizione usa
`137595026cf1aa416094fc3bf82aa8b0dfe04027`, preservando il WIP GUI e i delta
concorrenti attraverso merge a tre vie, senza reset del checkout condiviso.
La ADR GUI non pubblicata diventa **0041** per conservare la 0035 pubblicata;
il reset applicativo WIP diventa **235** per conservare GS-DOR/VER/CMP-233
headless. Le rinumerazioni non promuovono verifiche o stati scientifici.

Sono esposti selezione LDA (cinque criteri), MDS ordinale/multiavvio, SOM
rettangolare/esagonale con U-matrix/Ward, comunità Girvan–Newman/CNM/Walktrap,
layout FR/KK con inizializzazione esplicita, foresta minima con costi zero,
Simpson e disponibilità/annotazione/codifica linguistica. Le unità supportano
variabili esplicite e annotazioni ignote. I metadati Apple non esposti restano
ignoti, senza fallback inventati. Le prove a 02c1c66 sotto sono storiche.

Prima build macOS della composizione: **superata**. Kit mirato: **13 definizioni**,
45 operatori e 44 metodi statistici parametrizzati, più varianti dei nuovi grafi
e controlli di dominio/cancellazione, **superato**. Native mirate: **35 definizioni
in cinque suite, 78 esecuzioni**, **superate** senza failure o skip.
La prima compilazione dei test Kit ha richiesto un `try` interno a `#require` e
la disambiguazione di due `Bool?` nei nuovi test di comando: i controlli di
presenza, compreso il valore valido `false`, restano conservati.

Il gate completo della composizione finale resta da acquisire.

## Identità del contenuto

La verifica usa un worktree detached isolato con overlay del checkout condiviso.
La baseline Git è `02c1c666437a58743dba40193b9a94d4a7a3a11c`; i sorgenti
effettivi sono identificati dal fingerprint, perché includono lavoro non
committato. Il terzo snapshot comprende **432 file** delle radici di sorgenti,
risorse, configurazione, fixture, benchmark e verifica, con SHA-256
`3ad8feda28bbde898893a3b5dfde954740f8921e2a4f83b0dcfc5acc5c96d693`.
Il digest concatena path relativo ordinato UTF-8, NUL, contenuto e NUL;
l'inventario deriva da `git ls-files --cached --others --exclude-standard`.
Prima/dopo la copia e snapshot isolato coincidono. La prova riguarda questa
fotografia, non ulteriori implementazioni pubblicate da altre chat su `main`.

I contributi concorrenti sono preservati nell'overlay; GS-VER-230/231/232/235 e
GS-VER-270 mantengono i propri ambiti. Nessun benchmark Vision, accelerazione
o audit assistivo è dedotto da `make verify`. Gli esiti del gate e gli scostamenti
finali della copia condivisa sono registrati separatamente.

## Verifiche osservate

La prova mirata `GlifiCoreOperatorsTests` è superata: cinque definizioni,
quarantuno casi parametrizzati del test di esecuzione e quattro ulteriori casi
su chiavi/checkpoint espliciti, input invalidi/limiti, failure KL e cancellazione.
Il primo test KL aveva assunto un infinito mentre il core rifiuta quel dominio:
la verifica ora conserva il contratto `similarity.kl-undefined`, senza cambiare
il comportamento produttivo.

Il successivo gruppo mirato Core/Kit è superato: dodici definizioni, con
41 operatori espliciti e 44 metodi statistici parametrizzati, oltre ai controlli
su parsing, domini, limiti, cancellazione e alle tre verifiche linguistiche/
temporali (95 esecuzioni complessive). I metodi statistici includono quantile t,
bootstrap BCa e contrasti pianificati.

Il gruppo mirato macOS ha superato 56 definizioni e 134 esecuzioni, senza
failure o skip, prima delle ultime regressioni aggiunte per reset, identità
delle celle e selezione storica del codebook. La build Debug di integrazione
è successivamente superata.

Il primo gate isolato è fallito nei tre test di riferimento della proiezione
multivariata: i confronti completi non includevano i tre nuovi metadati del DTO.
Il riferimento è stato esteso con i valori provenienti dal Core, conservando
confronti di DTO, JSON e digest; il retest mirato è superato (tre test della
proiezione più una verifica della proiezione qualitativa). La decodifica legacy
resta verificata separatamente. Il secondo `make verify` è superato, incluse
le build Debug/Release macOS e iPadOS: 423 definizioni Core, 76 Kit e
92 native (312 esecuzioni), zero failure e zero skip nativi.

La verifica conclusiva aggiunge i delta concorrenti dei grafici, la gestione
del focus/etichetta di una categoria appena creata e il controllo del costo
delle permutazioni esatte: il numero di assegnazioni viene ammesso insieme
al numero di elementi che il core somma per ciascuna assegnazione. Il test
mirato rifiuta due gruppi fortemente sbilanciati quando eccedono il budget e
accetta l'ordine di input che resta nel budget; nessun campione viene invertito
o troncato. La suite statistica mirata è nuovamente superata (44 varianti e
tre ulteriori test). Il gate completo su questo terzo snapshot è superato, comprese le quattro build.

## Ergonomia e limiti della verifica

La progettazione usa Form, Picker, DisclosureGroup, Table, NavigationSplitView e
comandi di sistema, colori semantici e layout sequenziale su finestre strette o
testo di accessibilità. Il risultato rimane identificato dall'input catturato e
segnala la bozza modificata e la mancata convergenza. Le etichette sono italiane
e inglesi; le anteprime includono testo grande, scuro e destra-sinistra.

La revisione fa riferimento alle HIG Apple per
[macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos),
[layout](https://developer.apple.com/design/human-interface-guidelines/layout),
[tabelle](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables)
e [accessibilità](https://developer.apple.com/design/human-interface-guidelines/accessibility).
La build e le anteprime non sono un audit VoiceOver, Voice Control, contrasto,
pseudo-lingua o usabilità su dispositivo. Questi controlli e G4/G5 restano
aperti; CMP-223 non viene promossa a conformità globale.
