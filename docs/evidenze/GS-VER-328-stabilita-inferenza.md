<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-328 — Stabilità dell'inferenza alle trasformazioni e agli estremi

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-328 |
| Tipo | Evidenza di regressioni scientifiche |
| Versione | 1.0.0 |
| Stato | RED/GREEN mirato superato; gate macOS comune pendente |
| Responsabile | Codex e agenti |
| Ultima modifica | 2026-11-27 |
| Approvazione | Richiesta esplicita di perfezionare codice e semantica |
| Riferimenti | GS-DOR-328; CMP-328; GS-MET-001-04; GS-MET-001-21 |

## Riproduzione sulla base

Il probe isolato dei metodi correnti sulla base `44dd90f` conserva le istruzioni
di prodotto e sostituisce soltanto i tipi errore e una funzione chi-quadrato
non chiamata dai casi verificati. Non compila il package né usa il suo scratch.
Osserva:

- permutazione esatta `[0,1]` contro `[2,3]`: p `1/3`, che diventa `1` dopo
  scala `1e-14` e `2/3` dopo traslazione `1e12`;
- t a un campione `[1e308,0]`: t zero, p uno e deviazione infinita; il campione
  normalizzato `[1,0]` ha t uno e p un mezzo;
- Cohen d di `[1e308,0]` contro `[0,-1e308]`: d zero e deviazione pooled infinita,
  contro sqrt(2) per il riferimento normalizzato;
- bootstrap costante `[1e308,1e308]`: stima infinita e limiti NaN;
- Q7 su `[-1e308,1e308]`: NaN a p zero e infinito alla mediana.

Le sei assegnazioni della permutazione hanno differenze `-2,-1,0,0,1,2`;
una trasformazione affine positiva che conserva l'informazione del campione
alla precisione dichiarata conserva estremità e tie. Sono escluse trasformazioni
che fanno già collassare dati distinti per arrotondamento. Le forme chiuse
per t e d e il bootstrap costante forniscono oracoli indipendenti. Q7 deve
restare nella combinazione convessa finita degli estremi. Non viene usato
un risultato prodotto dal metodo difettoso come unica attesa.

## RED comune

L'integratore compila ed esegue una sola suite Core mirata comune ai lotti
327/328/330: compilazione riuscita, 16 definizioni e 70 issue attese, exit 1.
Il lotto 328 comprende otto definizioni e dieci casi parametrizzati, con 44
issue registrate. Falliscono tutte le proprietà previste: permutazioni esatte
e Monte Carlo nelle nuove unità, t/paired e d a scala grande/piccola,
bootstrap indipendente e a blocchi, Q7 e rifiuto di output finali non
rappresentabili. Non sono stati aggiunti skip o aumentate tolleranze.

Il log `macOS-2026-11-27-semantics/core-red.log` rimane nel dossier locale;
[il rapporto](allegati/GS-VER-328-verifica.json) conserva hash, conteggi e
risultati del probe. Le API e gli schemi rimangono invariati. Il candidato successivo è registrato
separatamente nella sezione seguente.

## Candidato e casi supplementari

La correzione viene autorizzata soltanto dopo i RED Core e nativo comuni.
Il candidato congela quattro file produttivi: statistiche appaiate,
ricampionamento, estensioni inferenziali e selector delle revisioni derivate.
Il nuovo file di regressioni e il test di selettività delle revisioni sono
gli unici due file Swift di test modificati dal lotto.

I momenti usano origine osservata, esponenti in base due e somme compensate;
non materializzano varianze in scala originale prima della radice. Il pooling
combina scarti nelle stesse unità e conserva i contrasti fra medie vicine anche
su offset grandi. Output finali non finiti o deviazioni azzerate da underflow
falliscono esplicitamente. Il controllo delle differenze appaiate precede
anche Wilcoxon e impedisce tie artificiali creati dall'overflow.

La permutazione usa coordinate centrate/scalate per confronti e tolleranza,
con parametro della strategia ammesso prima del nuovo lavoro. Bootstrap e
leave-one-out conservano le somme originali quando non c'è rischio di overflow;
il percorso raro usa input riscalati mantenendo estrazioni e ordine. Le costanti
vengono preservate esattamente anche con numerosità due, tre e cinque, senza
saltare PRNG o checkpoint. Q7 usa la combinazione convessa soltanto quando la
sottrazione finita non è rappresentabile e conserva gli endpoint in quel ramo;
il percorso finito mantiene l'aritmetica ordinaria, inclusi gli zeri con segno.

BCa normalizza i contributi prima dei cubi del jackknife, condividendo la
preparazione stabile della media. La nuova regressione usa la trasformazione
esatta `2^500` di un campione sintetico. Altri casi supplementari verificano
d su piccoli contrasti con offset `1e6`, il rifiuto di differenze appaiate
infinite e le costanti bootstrap con più numerosità. Questi casi seguono il
RED comune iniziale: il loro esito di prodotto è raccolto nello stage successivo,
senza attribuire loro una corsa RED non eseguita.

Format, lint Swift rigoroso sui sei file e `git diff --check` passano prima
del congelamento. La suite Swift del secondo stage supera tutti i nuovi casi
inferenziali ma registra due issue in una regressione esistente dei bit MBB:
il nuovo shortcut Q7 a frazione zero restituiva -0 dove la formula ordinata
precedente dava +0. La causa viene corretta limitando lo shortcut al ramo
con differenza in overflow, senza cambiare test o tolleranze. La regressione
puntuale signed-zero viene aggiunta. Il terzo stage supera 781 definizioni Core,
incluse queste correzioni, senza failure Core; restano soltanto due RED Kit
previsti del lotto331 e la chiusura macOS comune.

La revisione indipendente individua poi un corner del criterio max/n: per
n pari a 100 o 1.000, una costante appena inferiore a max/n può ancora far
traboccare la somma ordinata per arrotondamento cumulato. Il RED Swift mirato
`bootstrap-headroom-red.log` conferma una definizione e due casi, entrambi con
`statistics.non-finite-result` (compilazione 47,41 secondi, test 0,002 secondi).
Soltanto dopo questo RED viene applicato il criterio conservativo max/(2n),
che riserva margine per gli arrotondamenti ai conteggi ammessi. Il GREEN finale
mirato `core-green.log` supera 28 definizioni Core e 17 Kit senza issue, incluse
headroom, zeri con segno, paired bounded e revisioni selettive; compilazione
47,04 secondi. Il gate macOS comune resta pendente. Non si modificano attese o tolleranze
preesistenti. Non viene dichiarata un'ottimizzazione; il banco Release resampling
esistente può misurare il costo senza introdurre un nuovo benchmark.

## Consumatori e revisioni selettive

Il laboratorio GlifiKit usa le primitive per t, d, bootstrap, permutazione e
BCa su vettori del chiamante. I nuovi casi estremi rimangono quindi esposti
anche senza persistenza. Il confronto di gruppi persistito usa permutazione,
bootstrap/BCa e d; il post-hoc usa gli effect-size. Gruppi, post-hoc e paired passano alla revisione algoritmo `3`, conservando
identità scientifiche e schemi.

Per paired, il coordinatore individua un controesempio anche nel dominio
persistibile: quattro valori `999999/1000000` e uno `999998/999999`, confrontati
con la frequenza zero di un termine assente. Sono frequenze ottenibili da
cinque documenti sintetici di circa un milione di token, entro i budget.
La vecchia somma/quadratura produce t circa `5000105580119,011`, contro
`5000105610935,903` della centratura indipendente: delta relativo circa
`6,16e-9`, superiore alla tolleranza D1. Il limite bounded dei valori non
impedisce uno spread molto piccolo. La nuova regressione ricava SD e t dalla
forma chiusa del campione con quattro valori a e uno a+d.

Il bootstrap dell'accordo ha supporto distinto e bounded dai dati/budget del
modello: il nuovo ramo Q7 per sottrazione in overflow non modifica i suoi
risultati. Nessun bump per accordo, associazione, correlazione, keyness o
famiglie estranee.

Il test di selettività confronta i nuovi nodi di gruppi/post-hoc/paired con i
descrittori `2` precedenti e verifica identità per le altre famiglie; i
vecchi schemi restano decodificabili. La propagazione ai risultati aggregati
segue le dipendenze dei nuovi nodi già presenti nel DAG.

La revisione indipendente dell'altro agente non individua ulteriori blocker
oltre il corner headroom registrato: conferma pooling, BCa, Q7, preservazione
di draw/checkpoint e selettività dei tre produttori. Il suo riscontro chiarisce
anche che l'invarianza non promette di recuperare dati già collassati durante
una trasformazione arrotondata.

## Limiti numerici espliciti

Non viene promesso un accumulatore esatto per ogni dinamica binary64.
Se la normalizzazione non può rappresentare un contributo non nullo,
l'operazione fallisce con `statistics.non-finite-result` anziché ignorarlo.
Questo limite è distinto dai casi riprodotti con risultato finale
rappresentabile, che devono superare gli oracoli. Non si aumentano tolleranze,
non si usano clamp e non si inventano zeri. I nuovi passaggi lineari hanno
checkpoint ogni 1.024 valori; i budget diagnostici delle osservazioni
ricampionate rimangono invariati.
