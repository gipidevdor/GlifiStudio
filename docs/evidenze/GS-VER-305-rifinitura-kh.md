<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-305 — Riverifica e rifinitura dei profili KH

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-305 |
| Tipo | Revisione avversariale e regressioni |
| Versione | 1.0.0 |
| Stato | Superato localmente |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di ricontrollare e perfezionare ogni aspetto |
| Riferimenti | RF-087; GS-DOR-305; ADR-0043; GS-VER-300; GS-MET-001-23 |

## Baseline e metodo

Baseline pubblicata d368285. Lavoro nel checkout isolato esistente, senza
incorporare modifiche concorrenti non pubblicate. Tre revisioni indipendenti
esaminano numerica, risorse e determinismo; il coordinatore verifica trasporto,
integrazione e attribuzione delle prove. I rilievi sono riprodotti prima delle
correzioni quando il costo della riproduzione è proporzionato.

## Rilievi riprodotti e correzioni

| Area | Difetto osservato e correzione |
| --- | --- |
| Unicode TermExtract | 24 processi con la stessa richiesta emettono 11 rappresentanti NFD e 13 NFC. Le candidate sono ora ricostruite nell'ordine della prima osservazione; frequenze, ranking ed evidenze restano dichiarati. |
| Likelihood NB | Conteggi 10^15 producono due log-likelihood zero e una falsa classe A. Il complemento intero e log1p recuperano la classe B e il posteriore Decimal. |
| Prior NB | Int.max−1 documenti su Int.max diventavano probabilità uno; la sottrazione intera conserva il log-prior negativo rappresentabile. |
| Risorse NB | Training batch ammetteva etichette/token di 10.000 byte con budget 8. Byte, hash, ordinamenti e matrici sono ammessi prima delle tabelle; la CV riserva gli stessi costi per fold. |
| Punteggi documentali | Due arrotondamenti raddoppiano il minimo subnormale in tutte e tre le modalità. Il percorso eccezionale arrotonda una volta con quoziente/resto UInt128 e nearest-even, con 54 unità di lavoro riservate per cella. |
| Ward.D2 | Quadrati subnormali fondono distanze distinte nello stesso valore. Ora producono numeric-range; il superamento del limite oggetti è insufficientResources. |
| MDS | Secondary, multi-start e backtracking non riservavano tutte le fasi. Workspace, ordinamenti/PAVA e avvii trattenuti condividono il budget; Kruskal include gli obiettivi ripetuti. |
| SOM batch | Il cutoff 1e−15 lasciava prototipi casuali o azzerava contributi. La media gaussiana completa usa i pesi assoluti ordinari; riscalatura e fattori logaritmici intervengono solo nei range estremi. |
| SOM online | Un aggiornamento fisico rappresentabile poteva sparire nello stato normalizzato. Il recupero raro o una failure tipizzata impediscono lo zero plausibile. |
| Composizione SOM | Fit, U-matrix e Ward avevano budget separati. La facciata ora ammette il workflow completo prima del fit; il controesempio superiore a 500M è rifiutato subito. |
| Planner e cache | Con massimo 1.000 erano inclusi 1.668 costi stimati. Si detrae il bundle keyness e si usa il produttore 2: il nuovo DAG non condivide il nodo con il vecchio produttore 1. Payload e descriptor schema restano invariati. |

Corretto anche un commento DocC che dichiarava ammesso null per il POS:
il decoder lo rifiutava già, come richiede il contratto. Nessuna API, lingua,
dipendenza o backend di prodotto è aggiunto. I metodi matematici mantengono
le formule e gli identificatori dichiarati; alcuni risultati prima errati e
ammissioni troppo permissive cambiano esplicitamente.

## Prove discriminanti

Il primo RED Swift registra 12 test Core con 32 issue e un test Kit fallito.
Dopo le correzioni il primo GREEN comprende 18 test Core e due Kit. La revisione
incrociata aggiunge prior, coefficiente gaussiano subnormale e budget planner:
RED di tre test con otto issue; la collisione del produttore ha un RED separato.

L'oracolo esagonale ordinario ha inizialmente segnalato 12 differenze: riscalare
sempre i pesi cambiava arrotondamenti e tie del caso già verificato. La
riscalatura è diventata condizionale, conservando il calcolo assoluto ordinario;
nessuna golden o tolleranza è stata modificata. Un ulteriore controesempio CLI
ha discriminato un peso subnormale positivo prima della divisione: la guardia
ora considera tutti i coefficienti. Le prove intermedie restano conservate. Il controllo documentale ha richiesto
di completare i marcatori della scheda DoR iniziale: la scheda è allineata al
contratto controllato, senza modificare il checker.

Le verifiche mirate finali superano 165 test Core e 19 Kit; altre 11 Core e tre
Kit verificano planner e persistenza. La CLI supera 63 fixture e 196 controlli,
compresi sette nuovi controlli esatti. Sulla versione corretta 24 processi
emettono tutti gli stessi byte NFC, il classificatore sceglie B e il punteggio
minimo subnormale coincide esattamente con il riferimento. Gli oracoli eseguibili diventano 244:
le 236 righe precedenti sono conservate letteralmente e si aggiungono otto
righe Decimal/Fraction indipendenti. Le 64 prove binary64 restano separate.

Sono stati confrontati anche 198 punti χ² fino a un milione di gradi di libertà,
5.700 razionali di quantizzazione e casi gaussiani indipendenti. Questi esiti
scalari non sono presentati come benchmark né come esecuzioni Swift aggiuntive.

## Gate finale

Lo stesso inventario di 524 file, digest
`4eea8d1b191efe9279db36f0b6999ab52e68c915be6c17627e658910138fbce2`,
è invariato prima e dopo le prove. `make verify` macOS è superato: 653 test Core,
142 Kit, 113 test nativi (345 esecuzioni), build Debug e Release macOS.
La suite Release e le suite Address Sanitizer e Thread Sanitizer superano
ciascuna gli stessi 795 test Core/Kit; nessuna diagnostica dei sanitizzatori.
La CLI Release ripete 63 fixture e 196 controlli.

Il gate comprende inoltre 244 righe di oracolo e 64 casi Fraction binary64,
2.816 dichiarazioni pubbliche, 40 casi di richiesta, 130 operazioni Kit/CLI con
260 confronti integrali e 51 rifiuti, due formati di importazione espliciti,
22 checkpoint di recupero dopo interruzione del processo e due PDF/A conformi.
Le [prove strutturate](allegati/GS-VER-305-verifica.json) conservano comandi,
UTC, tempi, hash dei log, risultati e inventario. Log completi, riproduzioni e
bundle xcresult sono conservati localmente nell'archivio GS-VER-305.

Xcode ha emesso il preesistente avviso di CoreSimulator non allineato
(1171.7 contro 1174.21); test e build macOS sono completati con esito zero.
Nessun simulatore iPadOS è stato usato. I tempi includono le compilazioni
concorrenti e non costituiscono misure di prestazione del prodotto.

## Pulizia finale

Rimossi soltanto gli artefatti rigenerabili del lotto: riduzione netta misurata
di 3.360.808.960 byte allocati (3,13 GiB), dopo aver preservato le prove utili.
Archivio di 1.031 file in `~/Library/Caches/GlifiStudio/evidence/GS-VER-305`;
toolchain, dipendenze e cache delle altre chat restano conservate. La misura
usa `du -sk` prima e dopo l’archiviazione, non lo spazio libero globale.

## Limiti

Nessuna attestazione di edizioni KH chiuse, identità RNG esterna, V6, prestazioni
misurate, energia o iPadOS. Il percorso ordinario conserva Accelerate; non si
rivendica un guadagno di velocità dalla concorrenza delle verifiche.
