<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-234 — Riverifica di correttezza e completezza analitica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-234 |
| Tipo | Audit indipendente, regressioni e verifica delle correzioni |
| Versione | 1.0.0 |
| Stato | Superato nel perimetro locale; limiti KH aperti |
| Responsabile | Codex, coordinamento e tre agenti specializzati |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di riverificare tutto in termini di correttezza e completezza estrema |
| Riferimenti | GS-VER-233; GS-DOR-234; GS-DOR-233; RF-087; RQ-025; RQ-058; RQ-060; RQ-063; GS-MET-001-23; GS-API-002; CMP-160; CMP-162; ADR-0042 |

## Revisione e metodo

Base iniziale immutabile pubblicata `c6fd88e`; integrazione finale fissata a
`38bba2931d9048ce46b0885e4933305b04b3d760`, con le correzioni di questo audit.
La GUI e i workbench già pubblicati sono inclusi nei test e nelle build finali;
eventuali modifiche concorrenti non pubblicate restano escluse e preservate.
Tre audit indipendenti esaminano grafi, MDS/SOM/LDA e linguistica/
completezza; il coordinatore verifica trasporto, intervalli e Naive Bayes.
Non è sufficiente ripetere la suite verde: sono cercati controesempi minimi,
scale estreme, input ambigui e allocazioni/lavoro non ammessi.

Una prima esecuzione sul codice non corretto ha prodotto **quattro test falliti
e dieci issue**, exit 1: decoder degli intervalli, superfici NFC/NFD, diagnostiche
SOM minuscole e preparazione KK. Il log RED è conservato separatamente. I casi
successivi hanno regressioni proprie e riferimenti indipendenti; non si deduce
la correttezza dalla sola condivisione di un helper fra prodotto e test.

## Difetti e correzioni

| Area | Controesempio o rischio osservato | Correzione verificabile |
| --- | --- | --- |
| Intervalli UTF-8 | Decodifica sintetizzata ammetteva estremi negativi/vuoti/traboccanti, incompatibili con il costruttore | Decoder passa dal medesimo costruttore validante; schema invariato |
| Annotazioni esterne | Testo NFC e superficie NFD erano uguali per Swift ma avevano byte/intervalli diversi | Confronto esatto UTF-8 nel documento di codifica; digest e offset del trasporto conservano le due fonti distinte |
| Collocazioni | Conteggi singoli non negativi potevano sommare oltre Int.max | Somma totale con overflow controllato prima di creare il valore; margini conseguentemente sicuri |
| Naive Bayes | CV alloca classi² senza ammissione; predizioni documenti×classi e lavoro aggregato non limitati | Preflight di celle e fasi; inferenza espone limiti con default conservativo, cancellazione anticipata |
| Grammatica di codifica | Frecce ripetute perdevano vincoli; near/seq spezzavano le frecce POS/flessione; 1e309 diventava un termine | Parser dei qualificatori condiviso, validazione di ogni ramo AST, numeri non finiti rifiutati; parole quotate preservate |
| Lavoro della codifica | Candidati di prossimità scartati non contati; ricerche di confine letterale ripetevano scansioni lineari | Budget condiviso, consumo prima dei filtri, binary search dei confini e cursore UTF-8 monotono, cancellazione periodica |
| SOM | Distanze 1e−200 diventavano zero; tolleranza² e rapporto dei raggi potevano under/overflow; mediana subnormale azzerata | Norme stabili, riscalamento estremo reversibile o failure, confronto di tolleranza stabile, schedule log con endpoint esatti, mediana corretta |
| CLARA | Obiettivo minuscolo azzerato e soglia assoluta cambiavano il medoid al cambio unità; colonne pairwise non ammesse | Norme stabili, miglioramento relativo, candidato finito può sostituire costo infinito; celle e lavoro cumulativo completi |
| HAC e composizione Ward | Quadrati di distanze minuscole azzerati e quadrati intermedi grandi non finiti; centroidi costanti alterati | Norme stabili per single/complete/average, Δ Ward recuperato o rifiutato se non rappresentabile, coordinate costanti conservate |
| LDA | Documenti vuoti erano percorsi a ogni sweep, anche senza token, oltre il lavoro ammesso | Visita dei soli documenti attivi per Gibbs/predizione, stesso ordine e RNG; theta resta completo |
| KK e Kit grafi | BFS all-pairs escluse dal budget; posizioni copiate prima della verifica di cardinalità | Lavoro cumulativo prima dei buffer; cardinalità controllata prima della conversione |
| Girvan–Newman | Somme Double perdevano cammini pari e tie dei punteggi | Variante v2 con somme esatte dei costi binary64 rappresentati, bound di lavoro/memoria e arrotondamento finale dichiarati |

L’ID nuovo è `GirvanNewman-inverse-strength-exact-binary64-v2`. Non è aritmetica
razionale dei pesi originali: normalizzazione, reciproci e rapporti delle
molteplicità sono binary64. Il superaccumulatore non negativo ha 34 limb UInt64,
packing/carry/confronto esatti e un unico arrotondamento nearest-even all’uscita.
La politica non fonde cammini vicini con epsilon. Per le altre varianti, le
correzioni di input estremi e risorse non attestano identità bitwise su ogni
input della revisione precedente. maximumCells limita ogni rappresentazione,
non misura il picco RSS dell’intero processo. Non si attribuisce un guadagno
prestazionale a questa riverifica: i tempi delle suite sotto compilazioni
concorrenti non sono benchmark. GN v2 privilegia il contratto numerico esplicito
e contabilizza il costo aggiuntivo nei budget; non introduce accelerazioni
SIMD nuove prive di misura.

## Compatibilità degli intervalli e prima suite sanitizzata

La prima suite Address Sanitizer ha eseguito 533 test Core e 86 Kit; due test
Core fallivano perché richiedevano ancora la decodifica di intervalli invalidi.
Non sono diagnostici di Address Sanitizer. [ADR-0042](../adr/0042-invarianti-intervalli-utf8-decodificati.md)
registra il rifiuto anticipato intenzionale: i test continuano a verificare
geometrie legacy valide e ora pretendono failure sui range vuoti/invertiti,
anche annidati. Non è indebolita la validazione e non viene alterato il JSON
valido per eliminare un fallimento.

La successiva validazione locale delle span map richiede contratto non vuoto e
lunghezze non negative; respinge anche exact senza
origine o con lunghezze incoerenti, kind/cardinalità invalidi e range fuori dai
limiti dichiarati, prima di lookup/composizione. Non impone la geometria totale
ai record legacy: disordine, sovrapposizione e gap con segmenti validi mantengono
il fallback precedente. Le traslazioni con estremi Int.max hanno fixture dedicate.

## Completezza effettiva

La precedente tabella attribuiva erroneamente la generazione parola-contesto
alla trasposizione documento-parola. È corretta in GS-MET-001-23. La disponibilità
delle famiglie native non dimostra tutte le varianti del programma KH:

| Profilo KH pubblico | Stato accertato |
| --- | --- |
| Matrice parola-contesto condizionata per livelli/pesi, A.6.8 | Generatore assente; la trasposizione non è equivalente |
| Z-score campionario per righe/colonne, A.5.9/A.6.2 | Operatore generale di preparazione assente; PCA interna non lo sostituisce |
| Frequenze su esposizione completa | perThousand divide per la somma delle colonne fornite; filtrare prima cambia il denominatore |
| MDS ordinale e gestione dei tie | Il profilo nativo impone tie secondary/strong; non implementa la variante primary di smacof |
| SOM a due fasi e inizializzazione PCA | Variante KH non realizzata dal SOM nativo a un solo schedule/random sample |
| MI³/Z e universi TF globali/span | Non operatori dedicati; misure native su opportunità di coppia dichiarano un universo differente |
| Scaling CA e κ delle predizioni | Componibili dai risultati Core; non tutti i passaggi sono esposti come workflow Kit/CLI |
| Continuazione training NB | Statistiche sufficienti non conservate nel modello; rifit richiede i documenti originali |
| TermExtract | Non implementato; lingue di riferimento fuori dalla baseline italiana |

Questi sono limiti reali della completezza, non regressioni risolte con un nome
nuovo. La riverifica non implementa nuovi profili KH non presenti nel contratto
nativo; li rende espliciti e tracciabili. Stemmer e annotazioni Apple restano
italiani, con disponibilità distinta da accuratezza rappresentativa.

Fonti primarie: [manuale KH pubblico del 2016](https://khcoder.net/en/manual_en_v3.pdf),
[preparazione del clustering](https://raw.githubusercontent.com/ko-ichi-h/khcoder/master/kh_lib/gui_window/doc_cls.pm),
[SOM KH](https://raw.githubusercontent.com/ko-ichi-h/khcoder/master/kh_lib/plotR/som.pm),
[API R som](https://cran.r-project.org/web/packages/som/refman/som.html),
[regole Snowball italiano](https://snowballstem.org/algorithms/italian/stemmer.html).
La release [smacof 1.8-13 del 2016](https://raw.githubusercontent.com/cran/smacof/1.8-13/man/smacofSym.Rd)
ha default primary per `mds`; il callsite pubblico KH non fissa una versione del
package. Questo non prova quale release fosse installata in ogni distribuzione KH.
Sorgenti pubblici e versioni non fissate non certificano l’edizione chiusa corrente.

## Prove indipendenti aggiuntive

Il nuovo accumulatore è confrontato con 64 fixture sintetiche generate da
`fractions.Fraction` Python a precisione arbitraria, senza eseguire codice prodotto:
confronto bit per bit e invarianza a permutazione. Il generatore versionato e il
suo digest sono incorporati nei test Swift e ricontrollati da `check-oracles`.
Si aggiungono 6.141 round-trip di packing sugli esponenti, 256 insiemi diadici,
carry, sticky bit, nearest-even e overflow. I due grafi K4 hanno un oracolo
razionale Int64 indipendente dai pesi normalizzati e dal motore dei cammini.

## Ambito dei sanitizer

Sull’integrazione finale, ASan e TSan hanno superato ciascuno 550 test Core e
110 Kit (660 complessivi), exit 0, senza diagnostici di memoria o race rilevati.
Le impronte di Package.swift, Sources e Tests restano identiche prima e dopo
entrambi i cicli. I precedenti 536 Core/86 Kit si riferiscono alla revisione
anteriore a `38bba29`, non vengono riutilizzati come prova del delta importato.

Il ciclo finale ASan usa soltanto `--sanitize address`. La configurazione
storica richiedeva anche UBSan, ma la [documentazione Apple](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early)
limita UBSan ai linguaggi C: non è una prova della correttezza Swift e non
strumenta i framework di sistema precompilati. ASan verifica memoria del codice
strumentato; TSan cerca race nei percorsi eseguiti. L’assenza di diagnostici non
è una dimostrazione formale per ogni esecuzione possibile.

## Gate finale

`make verify` è terminato con exit 0 sull’integrazione dichiarata; il controllo
conclusivo conferma invariati tutti i 469 file dell’inventario. Gli
[esiti strutturati](allegati/GS-VER-234-audit.json) conservano impronte, ambiente,
log e differenza fra prova RED, revisioni intermedie e risultato finale.

| Controllo | Risultato osservato |
| --- | --- |
| Core/Kit Debug | 550 + 110 test, tutti superati |
| Core/Kit Release | 550 + 110 test, tutti superati |
| Address Sanitizer | 660 test, nessun diagnostico di memoria |
| Thread Sanitizer | 660 test, nessun diagnostico di race |
| App macOS | 99 test, nessun fallimento o test saltato |
| Oracoli indipendenti | 194 righe R/Python e 64 casi Fraction riprodotti |
| Trasporto CLI/Kit | 30 fixture, 95 controlli, tolleranza assoluta/relativa 1e-12 |
| PDF/A-2u | 2 PDF conformi con veraPDF |
| Recovery process-kill | 22 checkpoint validi |
| App macOS e iPadOS | Debug e Release compilati senza firma |

Xcode segnala CoreSimulator locale 1171.7.0 rispetto a 1174.21.0 richiesto e
metadati mancanti dei placeholder di destinazione generici. Le build generiche
sono passate; questo non attesta l’esecuzione iPadOS su simulatore o dispositivo.
Resta il warning preesistente iPadOS sulla dichiarazione di apertura documenti
in place (`LSSupportsOpeningDocumentsInPlace`/`UISupportsDocumentBrowser`), fuori
dalle modifiche GUI di questo audit. Non è dichiarato un gate privo di warning.

Il superamento riguarda la verifica locale dichiarata, non la completezza KH
totale o la promozione delle varianti candidate. Modifiche concorrenti non
pubblicate, runtime iPad su dispositivo, energia, corpus linguistici
rappresentativi, accessibilità manuale e firma V6 esterna restano fuori dal gate.
Le prove grezze utili sono conservate in
`~/Library/Caches/GlifiStudio/evidence/GS-VER-234`; non sono commesse cache di build.

## Riscontro statico dell’integrazione pubblicata

Il delta importato da `1375950` a `38bba29` è stato esaminato separatamente:
Brandes storico, cancellazione resampling, nuovi ingressi Kit di operatori,
statistica, valutazione, corpus ed export visuale. Nessun ulteriore difetto
concreto è emerso nel perimetro letto; questa è una revisione statica, distinta
dalle suite eseguite. Il fallback Brandes usa precisione Double con esponente
esteso, non l’aritmetica esatta dei costi GN v2. La funzione storica Brandes
resta sincrona, non throwing e senza checkpoint/limiti del nuovo kernel; il
benchmark ereditato misura solo carichi senza overflow, non il costo del fallback.

## Chiusura e pulizia

`make quality` conclusivo è superato. Le sette clausole pertinenti citano questa
evidenza senza promozione: 157 clausole, 116 verified, 31 implemented, 2 specified
e 8 blocked. CMP-160 resta implemented; il gate locale non approva V6.

Sono state rimosse soltanto le cache temporanee di questa riverifica: SwiftPM,
macOS, iPadOS, temporanei del gate e cache sanitizer inattive. Misura `du -sk`
prima della rimozione: 4.835.164.160 byte allocati, circa 4,50 GiB, senza doppio
conteggio. La misura non attribuisce variazioni globali di spazio libero in
presenza di altre attività. Log, parità CLI, inventari e risultato macOS sono
archiviati; il risultato xcresult è stato confrontato file per file prima della
rimozione. Checkout, cache e file delle altre chat restano preservati.
