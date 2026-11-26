<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-326 — Valutazione delle frazioni beta e gamma

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-326 |
| Tipo | Esperimento di equivalenza e prestazioni |
| Versione | 1.0.0 |
| Stato | Esperimento concluso: candidato scartato, kernel precedenti conservati |
| Responsabile | Codex con revisione indipendente |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta di ottimizzazione dopo la revisione di correttezza |
| Riferimenti | GS-DOR-326; CMP-326; GS-STD-001-17; GS-MET-001-21; GS-VER-319; GS-VER-324 |

## Proposta e confini

Il candidato accoppia i coefficienti pari e dispari dei loop dal fondo delle
frazioni beta e gamma. La profondità è sempre pari. La sequenza di aggiornamento
del denominatore resta `depth, depth−1, …, 1`, con gli stessi guard dopo ciascun
coefficiente, cancellazione ai medesimi checkpoint, profondità massime e
confronto di convergenza. Non cambia alcuna formula matematica, API, errore,
schema, descriptor, dipendenza o contenuto degli oracoli.

Per beta, il valore intero `m` è convertito una volta e `m−1` è esatto nel
dominio della profondità; gli offset e le parentesi restano separati come
nell'originale. Per gamma, `(m−1)+1` equivale esattamente a `m` per tutti
gli interi usati, al massimo 8192. Non vengono introdotte moltiplicazioni
per reciproci, riassociazioni dei prodotti, nuove soglie o coefficienti.
Le fonti restano le identità DLMF dell'implementazione propria del lotto 319.

## Spike numerico isolato dal prodotto

Lo spike temporaneo estrae i kernel correnti e il candidato accoppiato,
compilati con `swiftc -O` e un errore minimale che conserva il codice della
failure. In 2920 confronti t/F/gamma sono osservati **2739 risultati con
identico bitPattern**, **181 failure con identico codice** e zero differenze.
La griglia comprende probabilità di coda da statistiche subnormali e massime,
gradi di libertà t/F da 0,1 a 1e100 e chi-quadrato fino a un milione di gradi,
incluse regioni attorno al passaggio serie/frazione.

Otto esecuzioni con task già cancellato conservano lo stesso esito, inclusi
i bypass per zero e il comportamento storico delle serie brevi. La revisione
indipendente conferma la corrispondenza degli operandi e dell'ordine delle
operazioni. Questo spike non usa il vero envelope delle failure e non attesta
la suite del prodotto; i controlli nativi restano necessari prima dell'integrazione.

## Confronto sul prodotto e decisione

Il coordinatore cattura la baseline Release tramite API pubbliche prima
di modificare i due sorgenti e verifica la nuova griglia numerica sulla
baseline. Dopo il suo via libera applica il candidato, con lint mirato
superato; la composizione dei candidati supera la build Release e 30 test
mirati. Nessun timing degli estratti concorrenti alle build viene usato
come evidenza prestazionale.

Il confronto del coordinatore alterna baseline e candidato in ordine ABBA,
su API del prodotto. Tempi in microsecondi per chiamata, qui arrotondati
come nel riscontro ricevuto:

| Operazione | A1 | B1 accoppiato | B2 accoppiato | A2 |
| --- | --- | --- | --- | --- |
| t p-value | 0,392 | 0,395 | 0,395 | 0,394 |
| F upper tail | 0,451 | 0,449 | 0,445 | 0,446 |
| Quantile t | 45,69 | 45,03 | 45,02 | 45,79 |
| Associazione di contingenza | 1,982 | 2,014 | 1,932 | 2,007 |

I risultati e i digest delle quattro famiglie sono identici bit per bit.
Le variazioni delle mediane sono inferiori al 5% e non dimostrano un beneficio
stabile che giustifichi la modifica: il candidato è **scartato**. Il confronto
ABBA del prodotto prevale sullo spike numerico e su qualunque aspettativa
basata sul minor numero di operazioni intere.

Vengono ripristinati soltanto i due loop sperimentali; i file corrispondono
esattamente ai rispettivi SHA-256 catturati prima del lotto 326. Le correzioni
di provenienza e numerica del lotto 319 rimangono presenti. Nessuna
specializzazione gamma o nuova identità algoritmica viene introdotta da 326.
Il [riepilogo strutturato](allegati/GS-VER-326-verifica.json) conserva esiti,
tempi e hash di ripristino. Il gate integrato sulla composizione finale è
registrato dal coordinatore in GS-VER-324, senza attribuire a questo esperimento
un'esecuzione autonoma dell'intero gate o delle piattaforme rinviate.
