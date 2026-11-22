<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-300 — Completezza dei profili analitici KH pubblici

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-300 |
| Tipo | Implementazione e verifica analitica |
| Versione | 0.1.0 |
| Stato | In verifica |
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

Core, GlifiKit e CLI sono aggiornati insieme: 14 nuovi tag nel medesimo comando
text-analysis, schema/versione 1. Le 30 fixture preesistenti restano presenti;
22 nuove fixture portano il totale a 52. La GUI resta separata e il lavoro delle
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
| MI3/Z KH | TF globali e span, non margini di finestre; oracolo Decimal/Fraction e residui Int.max conservati |
| Scaling CA | Principal, standard e symmetric biplot sigma^0.5 per entrambe le parti; masse e ricostruzione controllate |
| Continuazione NB | Conteggi sufficienti esatti, espansione canonica di classi/vocabolario, nessun documento trattenuto; equivalenza pooled e predizioni analitiche |
| Kappa del classificatore | Stesse predizioni held-out e confusion matrix della CV, con accuratezza, accordo osservato/atteso e Cohen kappa |
| TermExtract LR/FLR | Frequenza indipendente f, LR token/type, evidenze da run POS dichiarate; oracolo scalare e Decimal, segmentazione sintetica multilingue |

TermExtract qui designa il motore matematico e la formazione esplicita dei
candidati da preannotazioni. Non viene inventato un tokenizer inglese/giapponese
o dichiarata la stessa qualità di MeCab/ChaSen. La baseline automatica italiana
non è modificata e le superfici esterne restano byte-exact.

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

## Oracoli e gate

Gli oracoli eseguibili comprendono 215 righe: le 194 precedenti sono confrontate
senza modifiche, con 21 righe nuove da R base e Decimal/Fraction Python. Restano
separate le 64 fixture Fraction dell’accumulatore binary64 già verificato.
Nessun runtime R/Python/Perl o pacchetto statistico è dipendenza del prodotto.

Il primo mirato integrato ha superato 80 test Core e 11 Kit; il primo controllo
CLI è verde su 52 fixture/139 controlli. Queste prove precedono gli ultimi
raffinamenti dei budget e della composizione SOM: i risultati finali saranno
registrati separatamente, senza attribuire loro copertura anticipata.

Le [prove strutturate](allegati/GS-VER-300-verifica.json) conserveranno inventario,
log, ambiente, tempi, test e limiti effettivi. Il gate finale è ancora in corso.
Non si rivendica un guadagno di velocità da compilazioni/test concorrenti;
Accelerate/LAPACK è una scelta numerica verificata, non un benchmark di speedup.
