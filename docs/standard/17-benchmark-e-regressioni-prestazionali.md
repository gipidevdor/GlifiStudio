# 17. Benchmark e regressioni prestazionali

| Campo | Valore |
| --- | --- |
| Identificatore | GS-STD-001-17 |
| Tipo | Capitolo normativo |
| Versione | 0.5.0 |
| Stato | Proposto |
| Responsabile | Da assegnare |
| Ultima modifica | 2026-09-15 |
| Approvazione | Non ancora approvato |
| Documento padre | [GS-STD-001](../standard-di-progetto.md) |

## 17.1 Corpus e ambiente

I benchmark **DEVONO** registrare:

- identificatore e checksum del corpus;
- versione del codice e configurazione;
- modello hardware, memoria, versione di macOS o iPadOS, Xcode e Swift;
- condizioni rilevanti, inclusi cache calde o fredde;
- metrica, unità, numero di ripetizioni e dispersione.

Le classi iniziali S/M/L/XL, i criteri di ammissione e `ResourceBudget v1` sono
definiti da [GS-RUN-001](../specifiche-di-design/06-runtime-e-risorse.md). La classe
XL è stress macOS, non una promessa di latenza finché non esiste una soglia approvata.

## 17.2 Metriche minime

- throughput di importazione, tokenizzazione e indicizzazione;
- latenza mediana e percentile alto delle query principali;
- memoria residente massima;
- byte letti e scritti;
- tempo di apertura e ripristino del progetto;
- dimensione su disco degli indici.
- energia, stato termico e impatto sulla responsività;
- tempo di warm-up, copie e sincronizzazioni per GPU o modelli;
- unità di calcolo selezionata e fallback osservato.
- latenza del primo risultato, cancellazione, spazio temporaneo e riuso cache.

## 17.3 Gate di regressione

Prima che esista una baseline numerica approvata, i benchmark hanno funzione informativa. Dopo la baseline, una regressione superiore alla soglia approvata **DEVE** bloccare il gate oppure ricevere una deroga con analisi del beneficio e del costo.

CPU e GPU **DEVONO** essere confrontate end-to-end sullo stesso dataset. Un kernel più rapido non giustifica Metal se trasferimento, preparazione o memoria peggiorano il risultato complessivo.

Swift/CPU, Accelerate, Core ML e Metal applicabili **DEVONO** essere confrontati sulla stessa semantica. Il benchmark **DEVE** registrare capacità rilevate a runtime e non usare il nome commerciale del chip come unica descrizione dell'ambiente.

Un backend predefinito **DEVE** mantenere un fallback verificato e non può essere promosso se l'errore numerico supera la tolleranza, se degrada sensibilmente energia o stato termico, oppure se rende l'interfaccia non responsiva.

Il confronto **DEVE** usare lo stesso `AnalysisDescriptor`, salvo il campo backend e
gli elementi della politica numerica dichiaratamente dipendenti dal backend. Tempo
di conversione, trasferimento, materializzazione, warm-up e ricostruzione del
lineage fanno parte della misura end-to-end.

Le misure applicative **DEVONO** applicare il profilo Apple per [prestazioni ed energia](../apple/06-prestazioni-ed-energia.md).
