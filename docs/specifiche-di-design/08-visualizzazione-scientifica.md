<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Visualizzazione scientifica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VIZ-001 |
| Tipo | Specifica di design delle visualizzazioni |
| Versione | 1.1.4 |
| Stato | Bozza controllata |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-11-28 |
| Approvazione | Baseline proposta; prototipi percettivi e accessibili richiesti |
| Riferimenti | GS-MET-001-22; GS-UX-001-09; GS-UI-001; GS-DAT-001; ADR-0016 |

## Scopo e autorità

GS-MET-001-22 governa il significato scientifico e l'ammissibilità di una
visualizzazione. GS-VIZ-001 governa rendering prodotto, interazioni, riduzione dei
dati, lineage, accessibilità ed export. Un chart non è un Artifact scientifico: è
una vista versionata di Artifact immutabili.

## `VisualizationSpec`

Ogni vista serializzabile dichiara:

- ID/versione della specifica e Artifact sorgenti con digest;
- unità osservativa, campi e trasformazioni applicate;
- mark, canali di encoding, scale, domini, baseline e ordinamenti;
- aggregazione, filtro, binning, normalizzazione e missing/non-finite policy;
- strategia di downsampling o densità e relativo errore/coverage;
- mapping tra mark, dati, Evidence e SourceReference;
- stato di selezione, brush, zoom e confronto;
- descrizione accessibile, tabella equivalente e ordine di esplorazione;
- dimensione, tema semantico ed export profile.

Default impliciti che cambiano interpretazione sono vietati. Zoom e filtro della
vista non mutano l'Artifact; producono ViewState e rendono visibile lo scope.

## Contratti per famiglia

| Vista | Requisiti minimi |
| --- | --- |
| Barre/rank | Baseline zero salvo ragione esplicita; valore, denominatore, ordine e tie-break |
| Serie temporale | Granularità, timezone/calendario, intervalli irregolari, mancanti e incertezza |
| Distribuzione | Bin/estimator, numerosità, outlier policy e accesso alle osservazioni |
| Scatter CA/PCA | Assi con inerzia/varianza, qualità/contributo, scaling e punti supplementari |
| Heatmap | Ordine righe/colonne, scala percettiva, zero/missing e matrice accessibile |
| Dendrogramma | Metrica, linkage, altezza, leaf order e taglio non ingannevole |
| Network | Semantica nodo/arco, direzione, peso, soglia, layout/seed e componenti escluse |
| Contingenza | Osservate/attese/residui, segno, scala divergente e precondizioni |
| KWIC/tabella | Colonne stabili, contesto, ordinamento, virtualizzazione e salto alla fonte |

La terza dimensione prospettica non è usata per codificare dati nel prodotto 0.1.
Assi troncati, scale logaritmiche, normalizzazioni per gruppo e aggregazioni devono
essere evidenti nella vista e nell'export.

## Colore, forma e testo

Palette deriva da ruoli di sistema e viene valutata per contrasto e principali
deficienze cromatiche. Colore non è mai l'unico canale: forma, tratto, pattern,
posizione o etichetta forniscono ridondanza. Una scala sequenziale non viene usata
per valori divergenti; categorie senza ordine non usano una scala ordinata.

Etichette usano formatter locale senza alterare il valore. Precisione visualizzata
deriva dalla precision policy; tooltip non aggiunge cifre non significative.
Legenda è interattiva solo se l'azione è accessibile anche da tastiera e VoiceOver.

## Interazione e interactive lineage

Selezione di un mark produce un `VisualSelection` con datum ID, ArtifactID,
encoding e SourceReference. Le azioni minime sono: descrivi valore, confronta,
filtra/espandi, mostra Evidence, mostra metodo e vai alla fonte quando la classe di
lineage lo consente.

Brushing e linked views condividono ID di dati, non coordinate pixel. Zoom non
elimina punti dal conteggio dichiarato; downsampling conserva numerosità e rende
visibile se un mark aggrega più osservazioni. `exact`, `contributive`, `synthetic`
e `derivational` determinano la formulazione dell'azione “Mostra nella fonte”.

Tutte le interazioni sono disponibili con tastiera e alternative strutturate.
Focus non viene perso a ogni rerender. Reduce Motion disabilita transizioni non
essenziali senza nascondere il cambiamento di stato.

Per il dendrogramma, la riga di fusione si collega al segmento che unisce
i due rami all'altezza dichiarata. Il segmento conserva il lineage contributivo
di entrambi i rami. Nelle mappe fattoriali il denominatore della quota degli assi
è l'inerzia totale per CA, la varianza totale per PCA e la somma dei quadrati
dei valori singolari per LSA. Per tutti e tre i metodi l'avviso di quota bassa
si attiva quando gli assi rappresentati spiegano insieme meno del 50%.
[GS-VER-270](../evidenze/GS-VER-270-grafici-comandi-neural-engine.md)

### Esplorazione del dendrogramma

Una specifica di dendrogramma può conservare `dendrogramTree`, metadato
opzionale con identità ordinate delle unità, fonti contributive allineate,
tipo di unità e albero completo delle fusioni. L'assenza del campo nei JSON
precedenti rimane ammessa; il client non inventa la topologia mancante.
La topologia **DEVE** essere validata prima di applicare un nuovo taglio.
Identità attive, cardinalità, dimensioni, altezze finite/monotone e fonti
allineate impediscono di seguire un albero incoerente.

Il taglio a numero cambia le appartenenze della sola vista. Il taglio ad
altezza include tutte le fusioni alla soglia, comprese le parità; non viene
presentato come equivalente a un taglio a numero quando le altezze sono
uguali. Si conservano identità, metodo, Artifact, albero e lineage originali;
si aggiornano serie dei gruppi, riferimento di taglio e sintesi. Non viene
rieseguita l'analisi del corpus e non si modifica il risultato persistito.
La medesima operazione è disponibile tramite `project-call`, tag
`recut-visualization`, con `visualization` ed esattamente uno tra
`clusterCount` e `maximumHeight`. Il trasporto conserva risultato e failure
della funzione nativa e lascia il progetto invariato (GS-API-003).

Zoom e scorrimento **DEVONO** conservare la cardinalità dichiarata. La
compressione di un ramo segue i figli dell'albero e rende esplicita la
numerosità delle foglie comprese; non viene inferita dalla somiglianza dei
nomi o dalla coincidenza delle fonti contributive. Nel profilo corrente la
compressione riguarda il grafico: tabella ed export mantengono l'albero
completo e il taglio della vista. L'interfaccia **DEVE** dichiararlo accanto
ai controlli. Espandi ripristina i segni originali senza ricalcolo analitico.

Controlli di sistema per zoom, taglio e ramo selezionato, insieme alla tabella
completa, offrono l'alternativa da tastiera e accessibile alle selezioni nel
grafico. La preparazione della partizione e dei rami avviene fuori Main Actor;
richieste superate, cambio della vista e scomparsa del componente invalidano
la pubblicazione tardiva. La verifica automatica non sostituisce gli audit
assistivi manuali registrati separatamente in
[GS-VER-335](../evidenze/GS-VER-335-flussi-tematici-e-dendrogrammi.md).
## Dataset grandi

Virtualizzazione, tiling, level-of-detail e aggregazione sono ammessi soltanto con
algoritmo deterministico e parametri nella VisualizationSpec. Campionamento casuale
registra seed e probability design. Estremi, selezioni e piccoli gruppi rilevanti
non possono sparire senza Caveat. La vista offre il numero di osservazioni
visibili/totali e un percorso verso la tabella completa o l'export.

Il rendering rispetta GS-RUN; una GPU è un backend sostituibile. Risultati visivi
tra CPU/GPU devono mantenere mapping, ordine, hit testing e tolleranze approvate.

## Accessibilità

Ogni visualizzazione ha:

1. titolo che esprime la domanda o il confronto;
2. sintesi testuale non causale;
3. descrizione di assi, scala, unità, scope e Caveat;
4. tabella equivalente navigabile e ordinabile;
5. navigazione per elementi significativi, con raggruppamento sui dataset grandi;
6. azioni accessibili equivalenti a pointer/touch;
7. supporto a VoiceOver e, quando disponibile e appropriato, audio graph.

La tabella è parte della stessa vista e conserva selezione/lineage; non è un export
separato usato come alibi di accessibilità.

## Export

Export umano: PDF vettoriale quando la vista lo consente, PNG ad alta densità per
uso raster, titolo, legenda, note, scope e Caveat. Export macchina: dati visualizzati
in CSV/JSON più VisualizationSpec ed ExportManifest. SVG può essere aggiunto solo
dopo audit di compatibilità e sicurezza; non è requisito MVP.

L'export dichiara filtri, dimensione, versione software, downsampling e data di
generazione. Un'immagine senza provenance non è considerata export scientifico
completo.

### Verifica della fonte nella sessione

Prima di scrivere l'export di una vista, la sessione **DEVE** verificare che
l'Artifact sia corrente e che nodo produttore, analisi e metodo dichiarati
corrispondano alla fonte persistita. La lettura del payload necessario al
confronto mantiene i controlli di schema, identità e integrità del progetto;
failure e cancellazione attraversano il confine GlifiKit con operazione
`export`. Un payload non appartenente agli schemi di vista supportati viene
rifiutato.

Anche l'ammissione di questa operazione attraversa lo stesso confine:
la sessione chiusa conserva codice, retry e stato del lifecycle con operazione
`export`; una task già cancellata conserva l'operazione `export` e lo stato
`unchanged`. Il lifecycle delle altre operazioni non cambia.

Metadati scientifici incompatibili producono
`visual-export.source-mismatch`, categoria `invalidInput`, senza pubblicare
file o modificare la generazione. La vista deve essere rigenerata dalla
fonte prima di ripetere l'export. L'Artifact assente conserva la failure
`visual-export.stale-artifact`.

Questo confronto non richiede l'uguaglianza con la vista standard: assi
alternativi ammessi e altre scelte di presentazione restano disponibili.
La verifica riguarda i metadati del produttore; non autentica eventuali
coordinate, valori o trasformazioni modificati dal chiamante. Il controllo
offline descritto sotto conserva il proprio contratto distinto.

### Profilo macchina v1 e verifica offline

Il profilo esistente comprende esattamente `view-spec.json`, `view.csv` e
`visual-export-manifest.json`. Schema, versione, nomi dei file e writer restano
invariati. L'inventario `files` del manifest **DEVE** contenere esattamente due
record, nell'ordine `view-spec.json`, `view.csv`, con media type rispettivamente
`application/json` e `text/csv`. Record duplicati, file aggiuntivi e percorsi
alternativi **DEVONO** essere rifiutati. Dimensione non negativa e SHA-256 di
ciascun record **DEVONO** corrispondere ai byte effettivi del relativo payload.

La resa canonica del digest è `sha256:` seguito da 64 cifre ASCII minuscole.
La codifica diretta dei nibble in UTF-8 è un dettaglio privato: non sostituisce
CryptoKit, non memorizza hash in cache e **DEVE** conservare tutti i byte,
i controlli e i fallimenti del profilo. GS-VER-178 confronta i vettori SHA-256,
il formatter precedente e l'intero bundle v1 prima e dopo l'ottimizzazione.

La `VisualizationSpec` **DEVE** essere decodificabile e concordare con tutti i
campi condivisi del manifest: Artifact, nodo analitico, analisi, metodo,
identificatore della specifica, osservazioni totali e visibili, riduzione,
layout e array dei Caveat nel suo ordine dichiarato. Gli identificatori sono
opachi e non vuoti: il verificatore non richiede UUID né un metodo appartenente
a un elenco chiuso. La generazione zero è ammessa. L'identificatore software
non vuoto può appartenere a una build storica; non è vincolato alla versione
del lettore corrente. I conteggi rispettano `0≤visibili≤totali`.

Il CSV **DEVE** essere identico byte per byte alla rigenerazione della tabella
dalla specifica mediante il writer v1 esistente: UTF-8, campi testuali con
escape RFC 4180, separatore virgola, terminatori CRLF anche sull'ultima riga,
valori numerici indipendenti dal locale e reali che conservano il round-trip
binary64; una cella mancante resta un campo vuoto. Aggiornare soltanto digest e
dimensione di un CSV alterato non ne ripristina la coerenza semantica.
I payload JSON e il manifest possono usare spaziatura e ordine dei campi
diversi da quelli prodotti dal writer, purché siano decodificabili, coerenti
e accompagnati dai digest dei byte effettivamente presenti.

La tabella **DEVE** essere rettangolare. Gli identificatori di colonne, righe,
segni e assi **DEVONO** essere non vuoti e unici entro la rispettiva raccolta.
Coordinate, estremi dei domini, quote degli assi, grandezze dei segni, celle
decimali e argomenti numerici della sintesi **DEVONO** essere finiti; gli estremi
degli assi sono ordinati, anche quando coincidono. Le identità sorgenti
presenti nel lineage dei segni sono non vuote.

Le cardinalità mantengono il significato della famiglia:

- nel dendrogramma le osservazioni visibili sono foglie, mentre le righe della
  tabella descrivono fusioni; più segni possono disegnare una sola fusione;
- nella rete i segni comprendono nodi e archi, mentre la tabella può descrivere
  soltanto i nodi;
- nel factor plot esclusioni dichiarate o valori non finiti esclusi dal builder
  possono ridurre le osservazioni visibili senza un `reductionIdentifier`.

Non si impone quindi una corrispondenza universale fra conteggi, righe e segni.
Esclusione del metodo e riduzione della vista restano concetti distinti.

La data usa il profilo calendario UTC del produttore
`YYYY-MM-DDTHH:MM:SSZ`; sono ammesse frazioni di secondo, l'offset esplicito
`+00:00` e le lettere `t`/`z` equivalenti. Il calendario deve essere valido.
Questo profilo non attesta il supporto completo a RFC 3339 o ai secondi
intercalari.

La verifica offline controlla la consistenza interna, non autentica l'origine.
Progetto e generazione dichiarati non vengono confrontati con un progetto
esterno; la loro attestazione richiede quel contesto autorevole. Una riscrittura
coerente di tutti i payload e del manifest non è distinguibile senza un digest
atteso fidato. L'incoerenza rilevata produce la failure di integrità esistente
`visual-export.integrity-failed`, senza risultato parziale.
[GS-VER-175](../evidenze/GS-VER-175-integrita-export-viste.md) registra le prove
strutturali, semantiche e di compatibilità del profilo; non attesta audit GUI,
accessibilità manuale o promozione scientifica.

## Errori percettivi vietati

- area o volume per valori lineari senza trasformazione dichiarata;
- doppio asse con relazione non esplicita;
- interpolazione temporale che nasconde mancanti;
- jitter non deterministico non registrato;
- scala cromatica che rende missing equivalente a zero;
- clipping silenzioso, etichette sovrapposte usate come unica fonte o animazione
  necessaria per comprendere il risultato;
- causalità suggerita da frecce o linguaggio quando l'Artifact è associativo.

## Conformità

- fixture percettive per ogni famiglia e snapshot semanticamente revisionati;
- round-trip datum → Evidence → SourceReference e selezione tra linked views;
- test di aggregazione/downsampling contro dati completi;
- audit contrasto, VoiceOver, tastiera, Dynamic Type e Reduce Motion;
- export reimportabile per i dati e manifest verificabile per la vista;
- studi di comprensione che includano letture errate e caveat, non solo gradimento.
