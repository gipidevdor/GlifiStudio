<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-325 — Quantile normale con iterazioni protette

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-325 |
| Tipo | Verifica di ottimizzazione |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e agenti |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di ottimizzare senza perdere correttezza |
| Riferimenti | GS-DOR-325; CMP-325; GS-VER-324; GS-MET-001-21 |

## Baseline e disponibilità nativa

GS-VER-319 aveva misurato un costo aggiuntivo dopo la riscrittura indipendente.
Il banco Release reale di GS-VER-324 misura prima del candidato circa 4,15 µs
per quantile ordinario e 22,74 µs per quelli estremi, su processo quiescente;
i campioni e il protocollo del confronto integrato appartengono a GS-VER-324.
Il confronto appaiato successivo è riportato nella sezione seguente.

La scansione locale e quella indipendente dell'agente di revisione degli header
`math.h` e Accelerate dell'SDK macOS 27.2 confermano `erf`/`erfc`, senza
individuare una primitiva pubblica applicabile per inversa normale o erf inversa.
Non viene introdotto un backend o una dipendenza alternativa.

## Implementazione originale

Solo `normalQuantile` e il relativo helper privato vengono modificati.
Le validazioni, il risultato esatto della mediana e il bracket `[0,40]` restano
quelli della baseline. Il seed centrale è la tangente dell'erf in zero; quello
della coda è `sqrt(-2 log p)`. Non sono introdotti coefficienti esterni.

Al massimo dodici proposte Halley riducono il bracket: il residuo è quello
dell'erf vicino alla mediana e del logaritmo della coda altrove. Con
`h = densità/Q`, le identità `d(log Q)/dx=-h` e `h'=h(h-x)` forniscono la
correzione. Per la coda oltre magnitudine 8, il denominatore della frazione
Mills esistente fornisce anche h; per il ramo ordinario la derivata viene
calcolata soltanto quando serve alla proposta.

Ogni proposta deve essere finita e interna al bracket aggiornato con il
confronto originale. Vicino alla stagnazione si verificano i segni di un
intervallo locale delimitato da otto vicini binary64 per lato; se la verifica
fallisce resta il bracket precedente. Il risultato viene sempre scelto dalla
bisezione finale, senza restituire immediatamente un residuo arrotondato a zero.
Il ciclo conserva il limite complessivo di 200 iterazioni. La derivata serve
solo alla proposta: la decisione finale usa il confronto erf/logQ esistente.

## Spike e revisione indipendente

Lo spike originale esplora 7.627 probabilità: potenze da `2^-1` a `2^-1074`,
subnormali, vicini della mediana e del cambio di ramo, mantisse deterministiche
e riflessi rappresentabili. I riferimenti vengono prodotti da R `stats::qnorm`
eseguito esternamente; nessuna implementazione R viene incorporata.

Il primo trasporto decimale viene scartato: il parser R locale modifica alcune
adiacenze della mediana e mantisse estreme. Il trasporto HEX C99 prodotto da
Python, con forma subnormale a esponente fisso `-1022`, viene confrontato bit
per bit per ogni input. Questo evita di attribuire al prodotto discrepanze
causate da probabilità diverse nell'oracolo.

| Candidato | Valutazioni mediane | Differenze di bit rispetto alla baseline | Monotonia osservata |
| --- | ---: | ---: | --- |
| Bisezione iniziale | 57 | 0 | Conservata |
| Newton senza selezione finale | 6 | 3.130 | Una inversione; scartato |
| Halley senza selezione finale | 4 | 3.167 | Due inversioni; scartato |
| Newton con bisezione finale | 9 | 42 | Conservata |
| Halley con bisezione finale, selezionato | 8 | 41 | Conservata |

Per la baseline e il candidato selezionato, l'errore massimo osservato rispetto
al riferimento R è di cinque ULP; nessun confronto supera la tolleranza assoluta
preesistente di `2e-13`. Le 41 differenze del candidato sono al massimo quattro
ULP dalla baseline: non viene dichiarata identità bitwise. Il limite di otto
ULP della nuova griglia indipendente non sostituisce né allarga le tolleranze
precedenti.

La revisione indipendente dell'altro agente conferma formule, bracket,
finitezza delle proposte e selezione bounded, senza individuare blocker.
Il sorgente applicato supera formattazione, lint Swift rigoroso del solo file
e `git diff --check`. Non sono stati avviati build o test dal sottoagente,
per preservare il coordinamento delle misure.

## Confronto appaiato Release osservato

L'integratore esegue quattro passaggi ABBA con il banco di prodotto Release,
su processi quiescenti; i campioni grezzi, gli inventari e gli hash dei binari
restano in GS-VER-324. Le mediane comunicate per i due passaggi di ciascuna
composizione sono:

| Quantili | Baseline, µs/chiamata | Candidato, µs/chiamata | Riduzione del costo |
| --- | ---: | ---: | ---: |
| Ordinari | 4,156 e 4,154 | 0,417 e 0,415 | Circa 10× |
| Estremi | Circa 22,738 | 3,171 e 3,177 | Circa 7,16× |

Nel banco il delta massimo osservato dei quantili ordinari è di due ULP;
i quantili estremi conservano i bit della baseline. I risultati keyness
con 512 e 4.096 termini conservano gli hash; il relativo miglioramento di
circa 6,4× e 6,3× comprende l'hoisting separato di GS-VER-324. Non viene
attribuito al solo quantile un guadagno complessivo dell'applicazione.

Questi sono risultati appaiati intermedi: l'integratore ricompila la
composizione finale prima di due ulteriori passaggi e di `make verify`.
Non viene dichiarato concluso quel gate in questa stesura.

## Contratto e limiti prima della chiusura integrata

La revisione numerica `2` resta quella del contratto D1 esistente: metodo,
failure e schemi persistenti non cambiano. L'accettazione richiede comunque
la griglia di prodotto e i consumatori, inclusi BCa ed effect-size, perché
un piccolo delta della primitiva non dimostra da solo l'equivalenza downstream.
L'integratore osserva il passaggio di 30 test mirati del candidato, 26 Core
e quattro Kit, inclusi gli otto nuovi controlli indipendenti di quantili,
probabilità, BCa ed effect-size. Il gate macOS completo e la misura finale
della composizione vengono chiusi separatamente in GS-VER-324.

Il [rapporto dello spike](allegati/GS-VER-325-spike.json) registra casi, delta,
hash e limiti. I conteggi delle valutazioni non sono misure di velocità;
lo spike interpretato era eseguito durante una build concorrente. La monotonia
osservata non è una prova su tutte le probabilità binary64. La frazione Mills
resta quella matematica DLMF 7.9.1 già usata e documentata nella baseline,
senza riproduzione di codice o contenuti editoriali esterni.

## Chiusura integrata

La composizione finale GS-VER-324 conserva la normale protetta e il solo
hoist keyness, dopo aver scartato il pairing beta/gamma. L'ABBA finale misura
10,010× sui quantili ordinari e 7,143× sugli estremi; i risultati osservati
restano entro il contratto D1 e le precedenti tolleranze.
`make verify` macOS passa con 760 test Core, 164 Kit e 133 definizioni native
(420 esecuzioni), oltre a oracoli, parità CLI, recovery e bundle Release.
Il fingerprint della composizione e i limiti sono registrati in GS-VER-324.
