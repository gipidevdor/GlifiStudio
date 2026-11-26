<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-323 — Fixture originale per LR e FLR

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-323 |
| Tipo | Verifica dei dati sintetici di sviluppo |
| Versione | 1.0.0 |
| Stato | Controlli mirati superati; gate integrato registrato dal coordinatore |
| Responsabile | Codex con revisione indipendente |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di controllo delle fonti algoritmiche |
| Riferimenti | GS-DOR-323; GS-LIC-002; GS-MET-001-23; GS-VER-318 |

## Sostituzione effettiva dei dati

Il test Swift e l'oracolo Python usavano un esempio di candidati che l'oracolo
dichiarava adattato dal paper LR/FLR. La nuova fixture è stata creata per il
progetto con cinque simboli artificiali e nove candidati:

| Componenti | Frequenza indipendente |
| --- | --- |
| u v | 4 |
| u w | 2 |
| v w x | 3 |
| x u v x | 1 |
| w w | 2 |
| w u | 5 |
| v | 2 |
| x | 1 |
| z | 4 |

Cambiano cardinalità, frequenze, topologia e tutte le attese correlate.
Il grafo contiene un ciclo, un'auto-adiacenza, una componente ripetuta nella
stessa candidata e una componente isolata; le lunghezze vanno da uno a quattro.
Non è una rinomina dell'esempio precedente. Le citazioni scientifiche restano
riferimenti delle formule, senza attribuire al paper la nuova fixture.

Non sono stati modificati il runtime, gli identificatori dei metodi, API,
descriptor, DTO, schema o trasporto CLI. Le altre sei righe dell'oracolo
`kh_lexical_profiles` sono conservate letteralmente; soltanto le tre righe
TERM in `expected.txt` cambiano e le quattro nuove righe del lotto 319
restano intatte. Il catalogo completo conserva 248 righe.

## Calcolo indipendente e discriminanti

L'oracolo usa prodotti interi esatti e radici Decimal a 80 cifre, con LR
`product^(1/(2L))` e FLR uguale alla frequenza indipendente moltiplicata per LR.
Una seconda revisione ricostruisce una matrice orientata intera, separatamente
dagli accumulatori Counter dell'oracolo: conferma 24 occorrenze indipendenti,
46 componenti ponderate e 22 adiacenze. I fattori con smoothing sono
`[56,30,88,10,1]` in modo token e `[9,6,16,6,1]` in modo type, nell'ordine
u/v/w/x/z. Le diciotto LR, le due FLR della candidata prima in classifica
e i due ordinamenti completi coincidono con il calcolo indipendente.

La candidata `x u v x` usa due volte il fattore di x: il prodotto token è
168000 con radice ottava, quello type è 1944 con la stessa radice. Questo
discrimina una deduplicazione indebita delle componenti. La candidata isolata
z conserva LR=1 e FLR=4. Restano verificati conteggi, distinzione token/type,
frequenza indipendente e invarianza all'inversione dell'ordine dei candidati.
I test separati conservano copertura di nested, duplicati, evidenze UTF-8,
segmentazione multilingue, confini, limiti, overflow e cancellazione.

## Esiti osservati

Il confronto iniziale con il catalogo precedente individua esattamente tre
righe TERM diverse; le altre sei righe del medesimo oracolo sono identiche.
È un controllo della sostituzione dei dati, non un difetto runtime.

La suite Swift mirata `--filter termExtraction` passa con **10 definizioni /
10 esecuzioni**, exit 0, nessuna issue. La rigenerazione Python delle nove
righe dell'oracolo coincide con `expected.txt` e il controllo dei riferimenti
numerici nei test Swift non rileva errori. Il lint Swift mirato passa.
La revisione indipendente non rileva blocker. Il
[riepilogo strutturato](allegati/GS-VER-323-verifica.json) conserva dati,
invarianti ed esiti. Il gate macOS integrato e la parità complessiva sono
registrati dal coordinatore; questa prova non attesta da sola l'intera suite,
iPadOS o una nuova approvazione scientifica.
