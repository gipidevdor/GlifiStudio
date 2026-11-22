<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-174 — Betweenness con molti cammini minimi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-174 |
| Tipo | Evidenza di correttezza numerica e regressione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Implementazione complementare richiesta dall'iniziatore |
| Riferimenti | GS-DOR-174; GS-MET-001-16; GS-STD-001-12; GS-STD-001-16; GS-VER-173; RF-039; RQ-008; RQ-009; RQ-063 |

## Perimetro

Solo `Betweenness-v1` su distanza hop diretta e i relativi helper privati.
Base pubblicata `b59292f`; le altre chat mantengono GUI, nuovi operatori analitici,
linguistica e adozioni Apple. Nessuna nuova API pubblica, variante scientifica,
dipendenza, acceleratore o formato persistente.

## Ingresso e regressione RED

La DoR GS-DOR-174 precede le modifiche implementative. Il baseline Release è
stato compilato e archiviato prima della patch produttiva, insieme all'inventario
SHA-256 di 94 file Core/benchmark. L'harness resta identico nel confronto finale.

Il test `betweennessNumericsLayeredBinaryOverflow` fallisce sul codice precedente:
**exit 1, una failure `finite`, 7,675 secondi**. Grafo sintetico: sorgente e
1026 livelli da due nodi, 2053 nodi e 4102 archi. Ogni nodo di un livello è
collegato ai due del successivo. I contatori dei cammini diventano infiniti,
mentre ogni punteggio esatto è finito. Il fallimento è stato osservato prima
di modificare il kernel, tramite `swift test --filter
betweennessNumericsLayeredBinaryOverflow` nella cache isolata del lotto.

## Riferimenti indipendenti e precisione

Per il nodo al livello `l` del DAG binario, le origini precedenti sono `2l−1`,
le destinazioni successive `2(L−l)` e la quota dei cammini attraverso quel nodo
è `1/2`: la centralità esatta è `(2l−1)(L−l)`. La sorgente ha punteggio zero.
Il test richiede tutti i bit della formula intera, oltre alla finitezza.

Un secondo DAG usa tre nodi per livello e due destinazioni nell'ultimo livello,
con contatori non potenze di due e asimmetria terminale. Il riferimento per
`l<L` è `(3l−2)×(3(L−l)−1)/3`; i due terminali hanno punteggio zero. La tolleranza
relativa `1e-10` è fissata prima della verifica della patch. Un oracolo distinto
enumera direttamente i cammini semplici, seleziona i minimi e conta le quote
su tutti i 4096 digrafi di quattro nodi, senza BFS o ricorrenza di Brandes.
I confronti bitwise con il ciclo precedente riguardano invece il dominio ordinario.

Il recupero estende l'esponente dei contatori mantenendo la precisione della
significand binary64: non introduce aritmetica intera arbitraria né garantisce
l'arrotondamento esatto di ogni quota razionale. I test separano formule esatte,
confronti con tolleranza e casi rappresentabili ai confini dei subnormali.

Nel DAG dei predecessori un cammino minimo non ripete nodi; tra nodi distinti,
per `|V|≥2` e dopo deduplicazione dei paralleli, il numero dei cammini è al più
`2^(|V|−2)`. L'esponente resta
quindi limitato dal numero dei nodi. Una dipendenza per sorgente è al più
`|V|−1` e il punteggio grezzo è limitato dal numero delle coppie ordinate:
l'overflow del contatore non implica un risultato realmente infinito.

## Protocollo delle misure ordinarie

Tre grafi sintetici deterministici: sparso e catena da 600 nodi, 160 diamanti
concatenati con 481 nodi. Configurazione Release, un warm-up e cinque campioni;
mediana, minimo e massimo per chiamata, RSS dell'intero processo. Tutti gli
input ordinati e tutti i bit dell'ultimo risultato sono controllati fuori timer;
le chiamate precedenti non vengono confrontate singolarmente. Due passate
accoppiate e supervisione della contesa; nessuna soglia di rilascio introdotta.

Host osservato: Mac16,3, 16 GiB, 10 CPU logiche, macOS 27.2.1 (26B131),
Xcode 27.2 (27B52), Apple Swift 6.4.2, alimentazione AC e Low Power Mode attivo.
Nessuna preferenza di sistema modificata. UI, energia, I/O fisico e hardware
di riferimento non sono coperti da questo confronto locale.

## Prima verifica verde

**Otto test superati con exit 0**, 12,760 secondi. Il test RED binario ora
coincide bit per bit con la formula esatta e tutti i punteggi sono finiti.
Passano anche il DAG ternario asimmetrico, l'enumerazione esaustiva dei piccoli
grafi, 24 confronti legacy con ordine dei nodi variato, identità in collisione,
Unicode, pesi zero, self-loop, paralleli e grafo vuoto.

Tre test del contatore interno verificano somma/normalizzazione, contributi
recuperabili dopo underflow della quota e confini di arrotondamento. Per esempio,
`1/2^1080 × 1024` e `1536/(3×2^1079)` sono `16×Double.leastNonzeroMagnitude`.
Per il denominatore `Σ 2^k`, `k=1023...1074`, il reciproco supera di poco metà
del minimo subnormale e deve arrotondare a quest'ultimo. Un prodotto non
normalizzato prima della conversione perde questo contributo per doppio
arrotondamento: il test copre la normalizzazione adottata nel fallback.

## Esiti ancora aperti

La revisione indipendente non lascia problemi concreti irrisolti. Il gate
funzionale è concluso; resta aperta la verifica delle prestazioni isolate,
per la contesa osservata durante tutti i tentativi di misura.

## Composizione con la base aggiornata

Durante il lavoro è stata pubblicata la revisione `c6fd88e`, con ulteriori metodi
analitici e relativi trasporti. Il lotto è stato riallineato a questa base senza
modificare i tre sorgenti produttivi delle milestone. I soli conflitti erano nei
registri e nella specifica delle reti; entrambe le parti sono state preservate.

Il primo gate sulla base precedente è stato interrotto intenzionalmente con
exit 143 per verificare la nuova composizione: erano passati 447 test Core,
66 Kit, 194 righe di oracoli, due PDF/A-2u, 51 controlli CLI e 22 checkpoint
recovery. Non viene attribuito un esito completo a quell'esecuzione.

Le misure restano separate dall'integrazione: eseguibili statici congelati prima
e dopo i due kernel numerici, stesso harness e snapshot della base `b59292f`.
L'inventario prova che differiscono soltanto `GlifiNetworkAnalysis.swift` e
`GlifiResamplingStatistics.swift`; gli stessi due file coincidono con quelli
della composizione aggiornata. Le nuove famiglie integrate non partecipano a
questo confronto e non ricevono risultati prestazionali da queste misure.

## Gate congiunto delle milestone

Sulla composizione aggiornata sono passati **497 test Core, 85 test Kit e
55 test nativi macOS**, 637 complessivi. `xcresulttool` conferma per l'app zero
test falliti e zero saltati. Sono passati anche 194 riscontri degli oracoli
numerici, due PDF/A-2u con veraPDF, 90 controlli CLI su 30 fixture condivise,
QueryAST e 22 checkpoint di recovery. **`make verify` è concluso con exit 0
il 2026-11-22 alle 11:42 CET**, incluse le build Debug/Release macOS e iPadOS
tramite `GlifiStudio.xcworkspace`. Nessun controllo richiesto saltato o ridotto.

Restano gli avvisi dell’host: CoreSimulator 1171.7.0 precedente al 1174.21.0
richiesto, callback di diagnostica del processo Xcode e dichiarazione in-place
iPadOS. Le build generiche sono passate; non attestano esecuzione su iPad.

## Riscontri sotto contesa

Sono stati tentati quattro avvii della supervisione isolata, senza ottenere una
finestra quiet di quattro secondi entro il timeout di sessanta secondi. Sono
state quindi conservate separatamente due passate accoppiate per ciascuna
famiglia, con ordine A/B e B/A e osservazione dei processi concorrenti: tutte
le quattro passate sono marcate con contesa. **Dodici confronti su dodici
coincidono per input e tutti i bit dell’ultimo risultato**. Mediane, minimi,
massimi e RSS sono negli allegati; non dimostrano benefici o assenza di
regressioni prestazionali. La prestazione isolata resta non verificata.

I [riscontri portabili del lotto](allegati/GS-VER-174-176-riscontri.json) conservano
conteggi, digest, controlli negativi e osservazioni con contesa, senza dati personali.

## Pulizia del lotto

Rimosse soltanto le cache e le copie dedicate, il worktree di misura e i due
eseguibili rigenerabili: **3.679.752 KiB, circa 3,51 GiB allocati** misurati
prima della rimozione. Non è un delta dello spazio libero APFS. Conservati
riscontri portabili, log, digest e copie dei tre sorgenti finali. Dipendenze,
toolchain, worktree attivo e artefatti delle altre attività restano intatti.
