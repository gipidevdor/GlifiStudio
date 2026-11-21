<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-172 — Query sparse e qualità del clustering

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-172 |
| Tipo | Evidenza di ottimizzazione e correttezza numerica |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-21 |
| Approvazione | Iterazione esplicita successiva al commit e push |
| Riferimenti | GS-DOR-172; GS-VER-171; GS-MET-001-07; GS-MET-001-14; GS-STD-001-17; RF-030; RF-037; RQ-008; RQ-009; RQ-063 |

## Perimetro e baseline

Raffinamento candidato successivo alla pubblicazione di `2386787`, verificata
in [GS-VER-171](GS-VER-171-integrazione-algoritmi.md). Il perimetro comprende
soltanto BM25 per query sparse e silhouette euclidea. Non introduce API,
formati, metodi analitici, dipendenze o backend; conserva le identità dei
metodi e degli Artifact esistenti. Nessuna modifica di interfaccia.

La [Definition of Ready GS-DOR-172](../pianificazione/dor-query-sparse-e-silhouette.md)
precede le modifiche ai kernel. Eseguibile Release e inventario SHA-256 dei
sorgenti sono stati archiviati prima dell'ottimizzazione. La baseline parte da
`2386787f2d3da0d8ce31320d919a073f486e7a20`; SHA-256 dell'eseguibile archiviato:
`255b86b19abaa5f00650226dfa9e508a3ab3158f83ff1696834f0b1d5f7fcfcf`.
Le misure del confronto sono registrate nelle sezioni seguenti; il gate
completo resta separato e non riceve un esito preventivo.

## Contratti implementati

BM25 mantiene DF interi esatti, deduplicazione della query e accumulo dei
contributi per colonna crescente. Il percorso adattivo usa posting ordinati
per riga soltanto quando la stima del lavoro lo giustifica. La stima
conservativa di memoria è limitata a 32 MiB; il superamento abbandona i
posting e usa il percorso diretto, senza aggiungere un rifiuto dell'input.
Conteggi zero e termini fuori vocabolario non producono hit; la validazione
dei conteggi interrogati e il recupero degli intermedi estremi restano
compatibili. La cancellazione deve raggiungere entrambi i percorsi.

Silhouette preindicizza i membri senza riordinare i punti e conserva l'ordine
dei cluster per etichetta e delle riduzioni ordinarie. Valida forma e finitezza
e ammette il lavoro tramite budget di celle e operazioni calcolati senza
overflow. Il recupero numerico interviene soltanto sugli intermedi in
overflow o underflow; conserva medie scalate fino al rapporto negli estremi.
Una distanza realmente non rappresentabile produce failure tipizzata.
Singleton e duplicati non producono NaN o punteggi fittizi.

## Protocollo di misura

Host Mac16,3, 16 GiB, 10 CPU logiche, macOS 27.2.1 (26B131), Xcode 27.2
(27B52), Apple Swift 6.4.2. Alimentazione AC con Low Power Mode attivo nella
configurazione osservata, senza modificare le preferenze di sistema.

Generatori sintetici deterministici, configurazione
Release obbligatoria, un batch di warm-up e cinque batch per caso; tempi
normalizzati per chiamata e batch fisso nella ricetta. Input, configurazione
e risultato completo dell'ultima chiamata sono controllati fuori
dall'intervallo cronometrato. Warm-up e chiamate precedenti non sono confrontati
singolarmente. Confronto
sequenziale della baseline archiviata e del candidato, senza build o misure
concorrenti. Mediana, minimo e massimo sono informativi; nessuna nuova soglia
di rilascio. Hardware, toolchain, stato termico, inventari e comandi sono
conservati con i risultati effettivi.

Il picco RSS del processo deve essere distinto dal tempo del kernel: comprende
anche generatori e controlli. Energia, I/O fisico, UI e hardware di riferimento
approvato restano fuori da questo confronto locale.

## Misure finali

Due passate paired consecutive sul medesimo candidato, ciascuna con un batch
di warm-up e cinque batch misurati. Le coppie `a / b` riportano le mediane
separate delle passate 2 e 3; gli intervalli coprono il minimo e massimo dei
campioni delle due passate. Non viene calcolata una mediana aggregata.

| Caso | Mediane prima (ms) | Min–max prima (ms) | Mediane dopo (ms) | Min–max dopo (ms) | Prima/dopo |
| --- | ---: | ---: | ---: | ---: | ---: |
| `bm25-sparse-query4-4000x4096` | 0.709 / 0.710 | 0.701–0.718 | 0.718 / 0.714 | 0.706–0.720 | 0.988–0.995× |
| `bm25-sparse-query128-4000x4096` | 24.343 / 24.600 | 24.201–25.177 | 24.932 / 24.495 | 24.394–25.745 | 0.976–1.004× |
| `bm25-sparse-query1024-4000x4096` | 201.233 / 204.067 | 199.374–212.728 | 17.502 / 17.189 | 17.141–17.674 | 11.498–11.872× |
| `bm25-sparse-oov-query1024-4000x4096` | 0.01437 / 0.01437 | 0.01432–0.01446 | 0.01447 / 0.01437 | 0.01435–0.01450 | 0.993–1.000× |
| `bm25-sparse-mixed-query1024-effective512-4000x4096` | 99.189 / 100.408 | 97.413–101.554 | 16.807 / 17.082 | 16.767–17.091 | 5.878–5.902× |
| `bm25-sparse-valid-absent-query1024-4000x8192` | 191.640 / 194.485 | 190.603–195.856 | 7.877 / 7.959 | 7.827–8.142 | 24.328–24.435× |
| `bm25-sparse-zero-empty-query1024-4000x4096` | 189.287 / 191.645 | 188.134–192.900 | 14.238 / 14.078 | 14.029–14.461 | 13.295–13.613× |
| `silhouette-1000x12-clusters2` | 10.135 / 10.139 | 10.128–10.158 | 5.445 / 5.451 | 5.436–5.472 | 1.860–1.861× |
| `silhouette-1000x12-clusters50` | 53.506 / 54.574 | 53.357–55.019 | 5.785 / 5.787 | 5.756–5.806 | 9.249–9.430× |
| `silhouette-1000x12-clusters1000` | 1.07668 / 1.07824 | 1.07558–1.07875 | 0.07180 / 0.07179 | 0.07165–0.07288 | 14.996–15.019× |

**Venti confronti su venti coincidono esattamente** per ricetta/configurazione
e checksum completo dell’ultimo output. Identici anche SHA-256 del candidato
e inventari dei sorgenti fra le due passate. I file del benchmark coincidono
con quelli della baseline. Nessuna tolleranza è stata allargata.

I guadagni sono ripetuti sulle query grandi e sulle tre partizioni silhouette.
BM25 query4 conserva un piccolo costo: +1,24% e +0,50% (circa 0,009 e
0,004 ms). Query128 varia da +2,42% a −0,43%; OOV da +0,73% a circa zero.
Non viene attribuito un beneficio alle query piccole o OOV, né esteso il
guadagno a tutte le distribuzioni.

| Sezione | RSS prima, entrambe le passate (MiB) | RSS dopo, entrambe le passate (MiB) |
| --- | ---: | ---: |
| bm25 | 20.547 | 21.281 |
| silhouette | 9.438 | 9.234 |

BM25 aggiunge 0,734 MiB di picco; silhouette diminuisce di 0,203 MiB.
Sono picchi dell’intero processo, comprensivi di setup e checksum; il budget
di 32 MiB dei posting è una stima dei buffer gestiti, non un limite RSS.

Esecuzioni il 2026-11-21 dalle 21:46:13 alle 21:46:21 UTC e dalle 21:46:29
alle 21:46:37 UTC, dopo rispettivamente 4,181 e 4,183 secondi consecutivi
senza processi rilevanti osservati. La supervisione periodica non ha osservato
build, test o benchmark estranei. Tutte le sezioni dichiarano stato termico
nominale; alimentazione e Low Power Mode invariati prima/dopo. Entrambe le
esecuzioni sono terminate con exit 0 e conservate in `attempt-2` e `attempt-3`.

SHA-256 del candidato Release:
`2ec19b5c85a32e0edeff8a5ce21e92388a5cb3643aeeaa2abc5a2fd2b2978b98`.
SHA-256 degli inventari dei sorgenti prima/dopo:
`2b6b63e95f299035ce9764b630c1c2c2f896d724209037112781edd907ed8d20` e
`cef77e1659a2235989d4fc999b88edbfcd26bb9f7eeb011abd2d7b10cdc0b56a`.

## Primo tentativo e raffinamento

Il primo confronto inconteso, conservato in `attempt-1`, mostrava silhouette
con due cluster da 10,161 a 37,523 ms (+269,29%), query BM25 piccola da 0,706
a 0,759 ms (+7,45%) e query128 da 24,565 a 25,832 ms (+5,16%). Tutti i
risultati coincidevano. Quel candidato è stato affinato separando il percorso
ordinario silhouette, con prova preventiva dei limiti numerici, dal recupero
degli estremi; BM25 evita la costruzione dei posting per query piccole.
Le due misure finali sopra riportate usano soltanto il candidato affinato.
Report e snapshot dei tre sorgenti del primo tentativo restano conservati;
la regressione iniziale non viene occultata o attribuita al candidato finale.

## Riferimento indipendente degli estremi

`silhouette_extremes.py` valuta direttamente distanze euclidee, medie e
rapporti con Decimal a 80 cifre, partendo dai valori binari esatti degli input
Double. Non riproduce le strutture o il recupero numerico del kernel Swift.
Il caso `[0,s,3s,4s]` con due coppie ha coefficienti `[5/7,3/5,3/5,5/7]` e
media `23/35`, per scale `2^±600`. Il caso `[0,s,10s,11s]` ha coefficienti
`[19/21,17/19,17/19,19/21]` e media `359/399`: copre il minimo subnormale,
`1e±200` e `Double.max/16`, dove la somma delle distanze può traboccare anche
se ogni distanza e la media sono rappresentabili. La versione bidimensionale
subnormale con coordinate uguali conserva il fattore comune `sqrt(2)` fino
al rapporto. La partizione `[0,1e308,1e308,8e307]` con etichette `[0,0,0,1]`
copre anche il ramo negativo: coefficienti `[-0,2;-0,6;-0,6;0]` e media
`-0,35`, con somma interna in overflow e singleton zero.

Per le scale decimali, l'oracolo conserva anche gli arrotondamenti introdotti
dalla costruzione degli input Double; non impone che le frazioni ideali siano
bitwise identiche. Gli otto output sono stati prodotti dallo script e collegati
ai literal dei test nativi; `expected.txt` aggiornato contiene 185 righe
complessive. I controlli bitwise delle fixture ordinarie sono separati
da questi confronti ad alta precisione degli estremi.

## Verifica funzionale e riferimenti

Quindici test aggiunti coprono i due kernel. La review indipendente ha
controllato l'ordine delle riduzioni, i DF, la selezione a larghezza completa,
il fallback bounded, i budget sul lavoro effettivo, le scorciatoie singleton,
la propagazione delle failure e il recupero numerico. Nessun difetto concreto
residuo emerso nella review; non equivale all'esecuzione dei test.

Il primo lotto mirato ha superato **20 test** con exit 0: sette BM25, sette
silhouette e sei regressioni preesistenti di ponderazione/silhouette. Copre
confronti bitwise con somma diretta indipendente, query piccole e grandi,
termini fuori vocabolario, zeri, fallback per byte/hit, confronto intero
completo, etichette arbitrarie, singleton, duplicati, input malformati,
cancellazione ed estremi numerici. I controlli statici documentali, conformità,
fixture, profilo Apple e tassonomia delle failure sono passati. Il gate
`make verify` ha superato **386 test Core e 46 test Kit**,
185 righe di oracoli, due PDF/A-2u conformi, 51 controlli CLI, QueryAST e
22 checkpoint di recovery. Gli otto test nativi macOS sono passati con zero
falliti e zero saltati, confermati con `xcresulttool`: **440 test complessivi**
(386 Core + 46 Kit + 8 nativi). Anche le build Debug/Release macOS e iPadOS
sono terminate con esito positivo, come registrato nel gate finale.

La regressione del primo tentativo ha motivato un percorso ordinario con
prova preventiva: minULP non nulla almeno `2^-510` e coordinata massima entro
`sqrt(Double.max/(8p))`. Quadrati non nulli almeno normali, somma dei quadrati
entro circa `Double.max/2` e limite di 5.000.000 celle proteggono anche somme
e medie delle distanze. La review separata ha verificato questi vincoli, gli
zeri e le fixture ai valori adiacenti delle due soglie. Il secondo lotto
mirato ha superato **21 test**, incluso il nuovo confine, con exit 0. BM25
evita inoltre la chiamata al costruttore dei posting per query effettive con
meno di 128 colonne, mantenendo il medesimo percorso diretto.

## Gate finale e pulizia

**`make verify` concluso con exit 0 il 2026-11-21 alle 22:55 CET**:
386 test Core, 46 test Kit e 8 test nativi macOS, **440 complessivi**,
185 righe di oracoli, due PDF/A-2u, 51 controlli CLI, QueryAST e 22 checkpoint
recovery superati. Build Debug/Release macOS e iPadOS eseguite tramite
`GlifiStudio.xcworkspace`. Nessun controllo richiesto saltato o indebolito.

Restano gli avvisi dell'host già noti: CoreSimulator 1171.7.0 inferiore a
1174.21.0 richiesto da Xcode e dichiarazione di apertura in-place iPadOS.
Le build generiche sono passate; nessuna esecuzione su dispositivo o
simulatore iPad è attribuita a questa evidenza.

Rimosse soltanto cache e temporanei dedicati alle iterazioni 171/172 e il
binario di baseline, conservandone il digest: **2.920.992 KiB, circa 2,79 GiB**.
Restano **544 KiB** in `/tmp/GlifiAlgorithms172Reports`, con tre tentativi,
mediane/minimi/massimi, RSS, ambiente, alimentazione, source snapshot, inventari,
hash e protocollo/supervisione. Conservati i log finali 171/172, il RED/verde
Welch, i 21 test mirati e i riepiloghi nativi senza identificatori del dispositivo.
Toolchain, dipendenze e file delle altre attività non sono stati rimossi.

## Stato e limiti

CMP-176 è `implemented`: kernel e test sono presenti, misure acquisite; il
gate completo è passato nel perimetro locale dichiarato. Le varianti e i manifest
scientifici esistenti non sono promossi da questo lavoro. RQ-008 e RQ-009
restano incompleti nell'ambito generale; un confronto locale non sostituisce
la validazione scientifica esterna o le misure su hardware di riferimento.
