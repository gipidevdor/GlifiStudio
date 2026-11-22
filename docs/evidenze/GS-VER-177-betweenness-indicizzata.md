<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-177 — Buffer indicizzati della betweenness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-177 |
| Tipo | Evidenza di correttezza e prestazioni |
| Versione | 1.0.0 |
| Stato | Verifica in corso |
| Responsabile | Codex, con quattro agenti concorrenti |
| Ultima modifica | 2026-11-22 |
| Approvazione | Ottimizzazione complementare richiesta dall'iniziatore |
| Riferimenti | GS-DOR-177; GS-MET-001-16; GS-VER-174; CMP-185; GS-STD-001-12; GS-STD-001-17; GS-STD-001-29 |

## Perimetro e ingresso

Base pubblicata `38bba29`, worktree isolato `codex/indexed-optimization-20261122`.
La DoR precede test, harness e codice produttivo. Nessuna modifica a GUI,
trasporti CLI, sessioni o ai file attualmente occupati dalle altre chat.
API pubbliche, dipendenze e formati invariati. Dati esclusivamente sintetici.

## Protocollo

Baseline Release compilata prima della patch produttiva; harness identico nel
confronto. Inventario completo delle fonti, input e risultati verificati fuori
timer. Host Mac16,3, 16 GiB, dieci CPU logiche; macOS 27.2.1 (26B131),
Xcode 27.2 (27B52), Apple Swift 6.4.2. Alimentazione AC, Low Power Mode attivo,
nessuna preferenza modificata. Cache calde, nessun flush; contesa con altre
chat registrata. Le misure locali non costituiscono soglia di rilascio,
audit GUI, misura energetica o attestazione G4.

## Correttezza e memoria

Il riferimento ordinario Dictionary conserva somme e ordine precedenti. Undici
regressioni Release sono verdi, inclusi tutti i 4096 digrafi di quattro nodi
contro enumerazione indipendente, i DAG estremi binario/ternario, collisioni
Hashable, Unicode, self-loop, paralleli e pesi zero. Le nuove prove coprono
componenti, sink e isolati intercalati, dodici seed e permutazioni delle sorgenti.
Un ulteriore DAG ternario da 1952 nodi alterna sorgenti con e senza overflow,
sink e due isolati: tutti i punteggi coincidono bit per bit con il fallback
Dictionary della base GS-VER-174. Quest'ultima prova differenziale è stata
aggiunta dopo la baseline iniziale; non cambia alcun harness misurato.

CSR, ordine BFS, append dei predecessori e riduzioni inverse sono invariati.
Ogni blocco predecessori ha capacità pari al grado entrante; ogni arco semplice
può scrivere al massimo uno slot. Il reset interessa tutti e soli i nodi
visitati. I contatori estesi sono allocati al primo overflow e sovrascritti in
ordine topologico prima di essere letti. BrandesPathCount e helper CSR restano
byte-identici. Scratch O(V+E), circa 64V+16E byte su Int64, più 16V byte quando
serve il fallback; sono esclusi grafo, output, overhead e picco di preparazione.
I grafi densi massimi non sono una classe prestazionale misurata in questo lotto.

## Misure Release

Un warm-up, cinque campioni per chiamata. Quattro workload: sparso 600 nodi,
catena 600, 160 diamanti concatenati, venti componenti da trenta nodi più duecento
isolati (800 nodi, 740 archi). Input ordinato completo e bit di tutti i punteggi
hanno SHA-256 identici nelle sei corse. I campioni grezzi sono nel riscontro.
La coppia iniziale precede/segue la compilazione; le due coppie successive sono
ravvicinate, con ordine invertito A/B/B/A e senza altre compilazioni di questa
chat avviate fra le corse. Non costituiscono prova di isolamento dell'host.

| Workload | Mediana prima, coppie 2/3 (s) | Mediana dopo, coppie 2/3 (s) | Rapporto prima/dopo |
| --- | --- | --- | --- |
| `betweenness-directed-sparse-600` | 1.142226 / 1.634534 | 0.024807 / 0.024559 | 46.04× / 66.55× |
| `betweenness-directed-chain-600` | 0.663166 / 0.760574 | 0.007643 / 0.006921 | 86.76× / 109.89× |
| `betweenness-diamond-dag-160` | 0.543174 / 0.554473 | 0.005804 / 0.005749 | 93.59× / 96.45× |
| `betweenness-components-800-isolates200` | 0.277373 / 0.322698 | 0.003028 / 0.004052 | 91.59× / 79.63× |

RSS massimo dell’intero processo, non del solo scratch: beta-baseline-2: 11649024 byte; beta-candidate-2: 11223040 byte; beta-baseline-3: 11288576 byte; beta-candidate-3: 11223040 byte.

## Riscontri conservati e gate

[Misure, inventari e confronti completi](allegati/GS-VER-177-178-misure.json)
contengono tutte le 42 osservazioni input/output, campioni, termica e censimento
della contesa. Il censimento usa campioni ps, non prova isolamento. Log grezzi
e protocollo sono conservati in `/tmp/GlifiIndexed177Reports` sull'host locale.
CMP-185 e CMP-186 restano implemented; nessuna promozione scientifica.
Il primo make verify sulla base 38bba29 si ferma con exit 2 su due test
preesistenti degli intervalli del testo; i relativi file sono identici alla
base e non dipendono dai kernel di questo lotto. La correzione già pubblicata
dall'altra chat in aec1a00 viene integrata prima di ripetere il gate completo.
Nessun controllo viene indebolito e nessun gate è ancora dichiarato superato.

## Limiti del confronto

Tutte le sei corse dei grafi osservano compilatori esterni. Nelle coppie 2/3
il massimo del censimento è circa 858%, 649%, 875% e 693% CPU aggregata;
le brevi corse candidate hanno soltanto due istantanee ciascuna. I rapporti
sono osservazioni sotto contesa, non una stima causale su host in quiete.
Il censimento include anche nomi di processo fra parentesi e potenzialmente
terminati; ps non misura la contesa istantanea. Tutti e quattro i workload
hanno contatori finiti: il fallback overflow è verificato per correttezza,
senza un benchmark prestazionale dedicato.
