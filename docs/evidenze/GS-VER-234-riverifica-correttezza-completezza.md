<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-234 — Riverifica di correttezza e completezza analitica

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-234 |
| Tipo | Audit indipendente, regressioni e verifica delle correzioni |
| Versione | 0.1.0 |
| Stato | In verifica |
| Responsabile | Codex, coordinamento e tre agenti specializzati |
| Ultima modifica | 2026-11-22 |
| Approvazione | Richiesta esplicita di riverificare tutto in termini di correttezza e completezza estrema |
| Riferimenti | GS-VER-233; GS-DOR-234; GS-DOR-233; RF-087; RQ-025; RQ-058; RQ-060; RQ-063; GS-MET-001-23; GS-API-002; CMP-160; CMP-162 |

## Revisione e metodo

Base immutabile pubblicata `c6fd88e`. Il checkout GUI in evoluzione è escluso e
preservato. Tre audit indipendenti esaminano grafi, MDS/SOM/LDA e linguistica/
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
non misura il picco RSS dell’intero processo.

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

## Gate finale

Gli [esiti strutturati](allegati/GS-VER-234-audit.json) distinguono la prova RED
iniziale dalle suite, sanitizer e build finali. Stato ancora in verifica: nessun
esito futuro è anticipato. GUI concorrente, runtime iPad su dispositivo, energia,
corpus linguistici rappresentativi e firma V6 esterna restano fuori dal gate.
