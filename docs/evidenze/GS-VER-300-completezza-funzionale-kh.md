<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-300 — Completezza dei profili analitici KH pubblici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-300 |
| Tipo | Implementazione e verifica analitica |
| Versione | 1.0.0 |
| Stato | Superato localmente nella versione unita |
| Responsabile | Codex e tre agenti specializzati |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di finire la completezza rispetto a KH Coder |
| Riferimenti | RF-087; GS-DOR-300; ADR-0043; GS-MET-001-23; GS-API-002; GS-VER-234; CMP-160; CMP-162 |

## Baseline e ambito

Base iniziale db2bac1; integrazioni pubblicate 1728fc1 e b5b0097 incorporate
prima del gate.
Il confronto chiude le lacune analitiche elencate nella fotografia GS-VER-234,
rispetto al manuale KH pubblico del 2016 e ai sorgenti pubblici citati in
GS-MET-001-23. Non attesta un’edizione chiusa/futura, identità RNG o tokenizer
esterni, formati proprietari o approvazione scientifica V6.

Core, GlifiKit e CLI sono aggiornati insieme: 19 nuovi tag nel medesimo comando
text-analysis, schema/versione 1. Le 30 fixture preesistenti restano presenti;
33 nuove fixture portano il totale a 63. La GUI resta separata e il lavoro delle
altre chat è preservato. Si verifica il profilo macOS richiesto in AGENTS;
iPadOS non viene dichiarato verificato da questa consegna.

## Copertura chiusa dall’implementazione

| Lacuna osservata | Nuova capacità e prova indipendente |
| --- | --- |
| Z-score generale | Righe/colonne, varianza campionaria n−1, policy costanti esplicita; base R scale e proprietà affine |
| Denominatore dopo il filtro | Esposizioni complete esterne per riga; formule scalate per evitare overflow intermedi |
| Parola-contesto | Medie condizionate sulle unità con target presente, somma per livelli/pesi alpha; oracolo R e identità/supporti espliciti |
| Tie primary MDS | PAVA con tie liberi, distinta dalla secondary storica; R isoreg, partizioni esaustive e controesempio analitico |
| SOM a due fasi/PCA | Stessi codebook tra le fasi, ordine ciclico e schedule dichiarati; PCA non scalata via LAPACK, oracolo R base e controlli U-matrix/Ward |
| Sette misure KH | MI, MI³, T, Z, Jaccard, Dice e log-likelihood con TF globali/span; formule KH, senza sostituire i margini di opportunità; oracolo Decimal/Fraction e residui Int.max |
| Associazione documentale | Probabilità marginale/condizionata, differenziale, lift, Jaccard, Ochiai e positività esatta, anche con margini sovrapposti |
| Punteggi documenti | TF relativo, TF×IDF e TF/IDF log10, con divisore 1 soltanto per IDF zero; oracolo R e prodotti scalati |
| Ward.D2 KH | Ricorrenza algebrica su dissimilarità Jaccard/cosine, distinta da Ward di varianza; oracolo R hclust e fallimento tipizzato per intermedi non rappresentabili |
| χ²/Yates e crosstab | Yates automatico solo in 2×2; residui Pearson/standardizzati distinti; per codice tabella gruppo×presenza/assenza e gruppi mancanti espliciti; oracolo R fino a 100.000 df |
| Scaling CA | Principal, standard e symmetric biplot sigma^0.5 per entrambe le parti; masse e ricostruzione controllate |
| Continuazione NB | Conteggi sufficienti esatti, espansione canonica di classi/vocabolario, nessun documento trattenuto; equivalenza pooled e predizioni analitiche |
| Kappa del classificatore | Stesse predizioni held-out e confusion matrix della CV, con accuratezza, accordo osservato/atteso e Cohen kappa |
| TermExtract LR/FLR | Frequenza indipendente f, LR token/type, evidenze da run POS dichiarate; oracolo scalare e Decimal, segmentazione sintetica multilingue |

TermExtract qui designa il motore matematico e la formazione esplicita dei
candidati da preannotazioni. Non viene inventato un tokenizer inglese/giapponese
o dichiarata la stessa qualità di MeCab/ChaSen. La baseline automatica italiana
non è modificata e le superfici esterne restano byte-exact.

Il censimento finale A5/A6/A7 ha esteso la prima fotografia ai punteggi dei
documenti, alle sette scale globali, all’associazione documentale e alle
significatività dei crosstab. La copertura è di primitive e composizioni
analitiche pubbliche: ordinamento/filtro delle viste sono responsabilità della
presentazione. Non è una certificazione di parità totale dell’applicazione KH.
I default del solo nuovo profilo SOM sono 1.000 passi iniziali e 500 per unità
nella seconda fase; i profili SOM preesistenti conservano i propri default.

## Difetti discriminanti emersi durante il lavoro

- Il percorso Jacobi condiviso perdeva PC2 quando la sua norma quadrata andava
  in underflow. Il nuovo profilo PCA SOM usa LAPACK locale: il caso con PC2 di
  ordine 1e-200 fallisce prima della correzione (un test, quattro issue).
  Il backend e i risultati delle API preesistenti non vengono sostituiti.
- Il primo helper Matrix perdeva il segno di un fattore negativo nella forma a
  esponenti; i test alpha negativo e ricostruzione CA lo hanno discriminato.
- La review Kit ha individuato l’inferenza Optional<T> nel decoder generico:
  il rifiuto esplicito di null è ora imposto con decode(T.self) e regressioni.
- Le ammissioni NB conteggiano vocabolario, byte e ordinamento sparso prima della
  tabella; la CV riserva questi costi per tutti i fold senza contaminare il
  vocabolario di training. Lo stato incrementale non riparte da un budget nuovo.
- Le adiacenze TermExtract aggiornano i set nel dizionario in place, evitando
  copie COW quadratiche non rappresentate dal lavoro ammesso.

Sono conservati anche i fallimenti intermedi di compilazione durante l’aggiunta
file e l’integrazione del refactoring, l’uso iniziale di Python ambientale troppo
vecchio e la correzione del tipo floating point nelle nuove golden LR/FLR.
Non sono presentati come difetti del prodotto né nascosti come esiti positivi.
La nuova fixture crosstab dichiarava una costante come token senza spazi:
la regola è stata corretta in `1 == 1`, mantenendo l’atteso all-present e il
confronto esatto dei conteggi. Nel primo χ² il quadrato di un residuo radicato
introduceva arrotondamento evitabile: il contributo usa direttamente residuo²/E,
conservando l’asserzione esatta Pearson=2. Nessuna tolleranza è stata allargata.

## Oracoli e gate

Gli oracoli eseguibili comprendono 236 righe: le 194 precedenti sono conservate
letteralmente, con 42 righe nuove da R base e Decimal/Fraction Python. Restano
separate le 64 fixture Fraction dell’accumulatore binary64 già verificato.
Nessun runtime R/Python/Perl o pacchetto statistico è dipendenza del prodotto.

Il primo mirato integrato ha superato 80 test Core e 11 Kit; il primo controllo
CLI è verde su 52 fixture/139 controlli. Queste prove precedono gli ultimi
raffinamenti dei budget e della composizione SOM: i risultati finali saranno
registrati separatamente, senza attribuire loro copertura anticipata.

Il checkpoint intermedio a 52 fixture ha superato Debug/Release, ASan e
make verify; la successiva TSan è stata interrotta intenzionalmente per
completare i profili emersi dal censimento. Questi esiti sono storici e non
attribuiti al contenuto finale. Sulla revisione completa il mirato ha superato
100 test Core e 12 Kit; la CLI ha superato 63 fixture e 182 controlli.

## Verifica dei profili prima dell’integrazione finale

| Controllo | Esito osservato |
| --- | --- |
| Suite Debug | 631 Core + 120 Kit = 751 test superati |
| Suite Release | 751 test superati; zero errori e avvisi di compilazione |
| Address Sanitizer | 751 test superati, nessun diagnostico |
| Thread Sanitizer | 751 test superati, nessun diagnostico |
| Parità CLI/Kit | 63 fixture, 182 controlli, anche in Release; tolleranza 1e−12 |
| Oracoli | 236 righe R/Decimal/Fraction riprodotte e collegate ai test, più 64 casi binary64 |
| macOS nativo | 99 test superati, zero falliti o saltati; build Debug e Release |
| Recupero e formati | 22 checkpoint process-kill; 2 PDF/A-2u conformi; QueryAST CLI superato |
| Gate richiesto | make verify macOS, exit 0 |

I 502 file di runtime, app, package, fixture e strumenti di verifica hanno
lo stesso inventario prima e dopo le prove: digest
`a6ec8f44d55a33ec455000e7aae69de323baf8762930d4a429579553f3119bda`.
La documentazione di governo è controllata separatamente dopo l’allineamento
agli esiti. L’ambiente è Apple M4, macOS 27.2.1, Xcode 27.2, Swift 6.4.2,
R 4.6.0 e Python 3.12.14. Le prove non sono benchmark di velocità o consumo.

Le [prove strutturate](allegati/GS-VER-300-verifica.json) riportano inventario,
hash dei log, tempi e conteggi. Log completi, snapshot e parità sono conservati
nell’archivio locale `~/Library/Caches/GlifiStudio/evidence/GS-VER-300`;
le cache rigenerabili del solo lotto sono rimosse a chiusura.

## Limiti dell’attestazione

Il gate certifica il contenuto verificato nel perimetro dichiarato; i nuovi
metodi restano candidate e non ricevono promozione scientifica V6.
Non attesta identità con edizioni KH chiuse, RNG esterni, tokenizer di altre
lingue, dispositivi fisici, energia o accelerazioni misurate. iPadOS e archivio
firmato/App Store non sono stati rieseguiti per questa consegna.
Il diagnostico preesistente CoreSimulator 1171.7 rispetto a 1174.21 richiesto
da Xcode disabilita i simulatori; test e build macOS richiesti sono passati.
Non viene dichiarata copertura UBSan Swift.

## Verifica della versione unita con main

Il consolidamento remoto 8901f4a ha pubblicato GUI, comandi Kit/CLI e parte
del checkpoint KH durante le prove. È incorporato integralmente prima della
consegna. I 62 file non sovrapposti e i 205 sorgenti/test Core sono conservati
byte per byte; i conflitti di trasporto e testi preservano l’unione delle prove.
La baseline API è aggiornata dal compilatore con gli stessi flag del gate:
2.816 dichiarazioni, 63 aggiunte, nessuna firma preesistente rimossa o cambiata.
Quattro binding e due alias esatti estendono il controllo alle nuove richieste.

| Controllo combinato | Esito osservato |
| --- | --- |
| Debug e Release | 631 Core + 140 Kit = 771 test superati in ciascuna configurazione |
| ASan e TSan | 771 test superati in ciascun controllo, nessun diagnostico |
| CLI analitica | 63 fixture, 189 controlli; tutti i 40 tag compilati coperti |
| Parità permanente | 130 operazioni, 260 confronti integrali, 51 rifiuti e 2 formati di import |
| macOS nativo | 113 test superati, zero falliti/saltati; build Debug e Release |
| Gate e oracoli | make verify macOS exit 0; 236 righe, 64 Fraction, 2 PDF/A e 22 checkpoint |

L’inventario combinato di 516 file è invariato prima/dopo le esecuzioni:
`3ccc2419c8f7b1db50452a3b39ecf6a4481c35fa6a7ae727671b86c6a5a81701`.
Gli esiti a 751 test/502 file restano il checkpoint pre-integrazione e non
sono trasferiti alla nuova unione. GS-VER-301 conserva il proprio snapshot
storico; la presente sezione attesta il controllo successivo completo.
I limiti di piattaforma, candidabilità e assenza di benchmark sopra dichiarati
restano applicabili. Gli stati delle clausole di conformità non sono promossi.

## Pulizia finale

Rimossi soltanto scratch e cache del lotto, dopo aver archiviato log, inventari,
parità e risultato nativo. La riduzione netta misurata con du è 5,36 GiB,
comprese le scratch Matrix e Lexical eliminate durante il lavoro. Toolchain,
dipendenze, file utente e cache delle altre chat restano preservati.
