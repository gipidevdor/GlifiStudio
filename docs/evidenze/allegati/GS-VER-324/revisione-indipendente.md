<!-- SPDX-License-Identifier: BSD-3-Clause -->

# Revisione indipendente delle ottimizzazioni statistiche

| Campo | Valore |
| --- | --- |
| Identificatore | GS-REV-324 |
| Tipo | Revisione matematica, delle fonti e delle prove |
| Versione | 1.0.0 |
| Stato | Review delle patch preparate; verifica del prodotto registrata dal coordinatore |
| Responsabile | Agente di revisione indipendente dai due implementatori |
| Ultima modifica | 2026-11-26 |
| Approvazione | Revisione nel perimetro GS-DOR-324; nessuna promozione scientifica implicita |
| Riferimenti | GS-MET-001-01; GS-MET-001-03; GS-LIC-002; GS-VER-324 |

## API di sistema e provenienza

L'ispezione di `math.h` e degli header Accelerate del SDK macOS 27 trova
`erf`, `erfc` e `lgamma_r`, già utilizzati dal prodotto. Non sono state trovate
API pubbliche per l'inversa normale o per le beta/gamma incomplete nei percorsi
ispezionati. Le API BNNS per la distribuzione normale generano campioni:
non sono un'alternativa alla CDF o al suo quantile. Non si introduce una
dipendenza, un coefficiente importato o un backend aggiuntivo.

La frazione di Mills resta un riferimento a una relazione matematica DLMF,
con codice proprio. Le restrizioni sui contenuti DLMF e la distinzione tra
formula e codice sono già registrate in GS-LIC-002. Halley deriva dalle
derivate della funzione scelta; non richiede una tabella presa da Acklam,
Numerical Recipes o altre implementazioni.

## Revisione delle patch preparate 325 e 326

Per il residuo centrale `f(x)=erf(x/sqrt(2))-c`, la derivata seconda è
`f''(x)=-x*f'(x)`. Detto `n=-f/f'`, il passo Halley è
`n/(1-x*n/2)`, come nella patch 325.

Per il residuo di coda `g(x)=log Q(x)-log p`, posto
`h(x)=phi(x)/Q(x)`, valgono `g'=-h` e `h'=h*(h-x)`.
Il passo `n=g/h` diventa `n/(1+n*(h-x)/2)`: anche questo segno è corretto.
L'hazard serve soltanto a proporre un punto. Il confronto che aggiorna
l'intervallo e la bisezione finale usano il residuo precedente, senza imporre
che la derivata della frazione troncata coincida con quella della legge esatta.

I seed sono finiti e interni a `[0,40]` per tutte le probabilità binary64
ammesse. Le proposte sono accettate solo se finite e strettamente interne
all'intervallo aggiornato. I probe a otto valori adiacenti richiedono entrambi
i segni del confronto; non si restituisce direttamente un residuo arrotondato
a zero. Il limite di 200 passi, con al massimo dodici tentativi Halley, rimane
esplicito. La bisezione finale resta necessaria: i candidati più aggressivi
scartati dal lotto 325 mostravano inversioni di monotonia vicino a `p=0,25`.

Nella patch 326 ogni coppia visita il termine pari e poi quello dispari,
nello stesso ordine della frazione dal fondo precedente. Per beta,
`Double(k)-1` rappresenta esattamente il vecchio indice dispari nei limiti
ammessi e gli offset sono calcolati separatamente, senza riassociare i prodotti.
Per gamma, `(Double(k-1)+1)-shape` e `Double(k)-shape` coincidono perché
`k<=8192` è un intero esattamente rappresentabile. Le guardie seguono ciascun
aggiornamento; limiti di profondità, convergenza e checkpoint esterni di
cancellazione non cambiano.

Questa review non identifica un blocco strutturale nelle due patch. Non misura
un vantaggio prestazionale: benchmark e confronto di ogni output del prodotto
sono eseguiti serialmente dal coordinatore.

La successiva lettura dei tre file applicati conferma gli stessi aggiornamenti
e guardie. Il file normale coincide con la patch preparata, SHA-256
`e25bed48362a23d1b66350c0dbd2487c5b9d323a6004d15ebbee1caf66baa442`.
È escluso anche un rischio del calcolo anticipato del valore critico keyness:
le guardie per famiglia vuota e massimo numero di ipotesi, poi il controllo
di cancellazione, precedono il calcolo. Nessun filtro rimuove tutte le righe
fra tali guardie e la valutazione; non si introduce una failure del quantile
in un percorso vuoto che prima avrebbe avuto un altro esito.

## Griglia indipendente e integrità degli input

Il [generatore R originale](griglia-kernel.R) produce
[riferimenti con attestazione dei bit](griglia-kernel.json): 254 probabilità
normali, 74 casi t, 132 F, 126 chi-quadro, 36 BCa e 18 intervalli di effect size.
R fornisce soltanto risultati numerici tramite un processo separato; nessun
sorgente o coefficiente R viene incorporato nel prodotto.

La griglia copre probabilità subnormali, confini normale/subnormale, mediana
e valori adiacenti, 32 passi in ciascuna direzione intorno a `0,25`, il cambio
di ramo normale di magnitudine otto, i cambi di ramo beta/gamma, alternative
t e riflessione. Il test nuovo aggiunge ammissione, limite numerico fail-closed
e cancellazione all'ingresso delle frazioni, senza pretendere una nuova
garanzia di cancellazione nel quantile normale sincrono e limitato.

Non si presume esatta la lettura decimale di R. Inoltre
`as.numeric("0x1p-1074")` azzera il minimo subnormale nell'ambiente osservato:
il generatore usa la forma equivalente `0x0.0000000000001p-1022`.
Ogni scalare e ogni elemento degli array conserva sia il bit pattern originale
sia il C99 hex canonico. Il round-trip hex è verificato in R; 3664 valori
sono stati confrontati anche con la decodifica JSON e hex di Python.
I test Swift ricontrollano i bit prima di invocare le funzioni, distinguendo
un errore di fixture da una regressione del kernel.

Il primo tentativo sul prodotto di riferimento ha rilevato una sola
asserzione nuova eccessiva: F con statistica minima positiva binary64,
`df1=0,1` e `df2=1000`, aveva riferimento R arrotondato a uno e risultato
`0,9999999999999999`. Uno a statistica positiva non è un endpoint matematico.
Il nuovo helper mantiene l'uguaglianza esatta per statistica zero, riferimenti
zero e subnormali; per un riferimento arrotondato a uno applica il relativo
già dichiarato nella stessa riga. Non cambia alcuna tolleranza preesistente.
Il coordinatore ha successivamente registrato gli otto test nuovi superati
sul prodotto di riferimento, prima dell'applicazione delle patch 325/326.

## Propagazione nei consumatori e identità della cache

La griglia BCa combina bias negativo, nullo e positivo, accelerazione nulla e
non nulla, livelli adiacenti a un confine di rango Type-7 e repliche distanti
fino a `1e150`. Richiede errore della probabilità aggiustata non superiore a
`4e-15`, fissato prima della prova del prodotto candidato.

Il quantile Type-7 è continuo, monotono e lineare a tratti. Per ciascuna
probabilità di riferimento `u`, R calcola il quantile a `max(0,u-4e-15)` e
a `min(1,u+4e-15)`. Il risultato nativo deve appartenere a quell'immagine,
con un margine dichiarato per l'aritmetica del quantile. Il confronto conserva
il condizionamento locale anche quando si attraversa un rango intero; non
impone un errore relativo malcondizionato a un endpoint vicino a zero.
Gli effect size sono verificati separatamente su componenti ed endpoint,
anche con campioni di scala `1e140`. Le failure per livelli che arrotondano
la probabilità critica a uno restano verificate.

GS-MET-001-03 definisce D1 tramite valori semantici, tolleranze e invarianti;
non promette byte identici. Differenze di arrotondamento entro lo stesso
contratto non richiedono da sole una nuova variante logica o l'invalidazione
della revisione 2 corretta dal lotto 319. Questa conclusione è condizionata
al mantenimento di dominio, failure, endpoint, monotonia e contratto dei
consumatori. Non autorizza tolleranze maggiori per ottenere velocità.

Le griglie finite non provano monotonia per tutti i bit pattern né esattezza
universale di libm. La review non include interfaccia, assistive technology,
iPadOS o una dichiarazione G4. Il gate integrato e i risultati del candidato
rimangono nelle evidenze del coordinatore.

## Chiusura dopo il confronto prestazionale

Il pairing beta/gamma era un candidato intermedio, numericamente equivalente
nei campioni ma scartato per beneficio non significativo. La composizione
finale conserva soltanto il quantile normale protetto GS-VER-325 e lo
spostamento del calcolo invariato nella keyness GS-VER-324. L'ABBA finale usa
un nuovo binario e inventario dedicati; quello intermedio non viene presentato
come misurazione della composizione consegnata.
