<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-324 — Prestazioni delle distribuzioni e della keyness

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-324 |
| Tipo | Misurazione e verifica di ottimizzazione |
| Versione | 1.0.0 |
| Stato | Superato localmente su macOS |
| Responsabile | Codex e tre agenti |
| Ultima modifica | 2026-11-26 |
| Approvazione | Richiesta esplicita di ottimizzare senza perdere correttezza |
| Riferimenti | GS-DOR-324; CMP-324; GS-DOR-325; GS-DOR-326; GS-VER-319 |

## Perimetro

Misure del prodotto Release reale e controlli dei risultati completi prima
di ottimizzare normale, beta/gamma e il quantile ripetuto nella keyness.
Il confronto comprende una fase con solo hoist, un candidato con beta/gamma
poi scartato e il binario finale con normale e keyness ottimizzate.

## Risultati Release prima del gate

Harness del prodotto invariato, input e binari identificati con SHA-256,
un warm-up e sette batch per processo, ordine A–B–B–A. La mediana seguente
usa tutti i quattordici campioni per variante, con confronto di ogni risultato
fuori dal timer. Low Power Mode è attivo e lo stato termico è nominale
in tutti i passaggi: non si modificano le preferenze energetiche.

| Scenario | Baseline | Finale | Rapporto |
| --- | ---: | ---: | ---: |
| normal-ordinary | 4.155 µs | 0.415 µs | 10.010× |
| normal-extreme | 22.746 µs | 3.184 µs | 7.143× |
| t-upper-tail | 0.393 µs | 0.392 µs | 1.000× |
| f-upper-tail | 0.446 µs | 0.445 µs | 1.002× |
| t-quantile | 45.736 µs | 45.663 µs | 1.002× |
| contingency-association | 2.000 µs | 1.996 µs | 1.002× |
| keyness-512-terms | 2936.039 µs | 463.706 µs | 6.332× |
| keyness-4096-terms | 23564.552 µs | 3759.063 µs | 6.269× |

I tempi keyness riguardano il confronto completo sui profili già preparati.
La fase con solo hoist produce già circa 6,24× su 4096 termini e conserva
tutti gli otto digest del banco: il guadagno keyness non viene attribuito
alla sola inversione normale. Nel banco finale sette digest su otto sono
identici; la normale ordinaria cambia al massimo due ULP, entro D1.
Le code estreme e i risultati completi della keyness sono bit-identici.

Beta/gamma non mostrano un beneficio stabile: il loro candidato è scartato
e i due sorgenti sono ripristinati esattamente alla baseline. I rapporti
prossimi a 1 nei quattro scenari collegati non sono miglioramenti rivendicati.

## Correttezza e riferimenti

Passano otto nuove definizioni sulla baseline e trenta sul candidato
(26 Core, quattro Kit). La griglia indipendente copre 254 probabilità normali,
74 casi t, 132 F, 126 chi-quadrato, 36 BCa e 18 effect-size. Sono attestati
3664 valori con bit pattern e C99 canonico; il generatore R viene rieseguito
e riproduce il JSON byte per byte. Restano invariati gli oracoli e le
tolleranze precedenti.

Un primo nuovo assert confondeva R arrotondato a 1 con l'endpoint matematico
per F(minsubnormal, 0,1, 1000): la baseline restituisce 1−1 ULP. Il criterio
è corretto prima dei kernel candidati: endpoint effettivi a statistica zero
restano esatti; il riferimento arrotondato usa il relativo già dichiarato.
Zero e code subnormali conservano i controlli esatti. Non è una regressione
corretta nel prodotto né una riduzione delle tolleranze esistenti.

I consumatori BCa usano l'immagine Type-7 dell'incertezza dichiarata sulla
probabilità, per rendere esplicito il condizionamento vicino agli indici
interi e con repliche distanti. La revisione indipendente e i relativi limiti
sono nel [verbale GS-REV-324](allegati/GS-VER-324/revisione-indipendente.md).

Il [rapporto strutturato](allegati/GS-VER-324/verifica.json), gli inventari di
build e i campioni grezzi conservano fonti e dispersione. Nessuna misura UI, energetica,
Instruments o nuova soglia prestazionale di rilascio viene attestata.

## Gate integrato macOS

`make verify` termina con exit 0 in 481,160 secondi: 760 test Core, 164 Kit,
133 definizioni native e 420 esecuzioni, senza failure, skip o avvisi runtime
nel report nativo. Passano 248 righe degli oracoli continui, 64 casi Fraction,
due PDF/A-2u, 196 controlli CLI testuali e 132 operazioni con 264 confronti
completi Kit/CLI. L'inventario di 2840 dichiarazioni pubbliche resta invariato;
172 varianti e 22 checkpoint di recovery sono verificati. Il benchmark rifiuta
Debug con exit 64 e diagnostica Release, senza emettere risultati misurati.

Il bundle Release conserva metadati, localizzazioni e testi legali esatti.
La diagnostica IDELaunchSession/placeholder device è di Xcode; il risultato
nativo registra zero avvisi runtime. Nessun archivio App Store, iPadOS, CI
remota, nuovo audit manuale assistivo o nuova esecuzione con sanitizer viene
attestato dal lotto.

La composizione congelata ha 1349 file e 618 input controllati, compresi
generatore R e JSON dei riferimenti. Il fingerprint è
`b87e0f5f3d003339fbb01f07ab8cbe92706699e71afa22464bc048ad8239a800`
e resta identico dopo il gate: codice, test, configurazione e dati degli
oracoli non vengono modificati per la chiusura documentale. La base è il
commit `07547a94724d0446a535eb84c72098a22bd39c6e`.

Il dossier locale `macOS-2026-11-26-performance-324` conserva manifest completo,
binari congelati, log e riassunti sanificati. Gli allegati conservano tutti i
campioni dei confronti, le condizioni e gli inventari collegati ai binari.

## Pulizia

Rimossa la cache di build posseduta dal lotto dopo misurazione `du`:
2.345.512 KiB, circa 2,237 GiB. Rimossi anche 1.294.482 byte di temporanei
degli spike dopo conservazione delle prove utili; la pulizia preliminare di
sette artefatti 326 resta registrata nel relativo dossier. Conservati
toolchain, dipendenze attive, sorgenti e prove; resta il file di lock stabile.
