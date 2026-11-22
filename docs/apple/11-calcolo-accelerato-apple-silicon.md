# Calcolo accelerato su Apple silicon

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-011 |
| Tipo | Standard applicativo Apple |
| Versione | 1.2.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-22 |
| Approvazione | ADR-0008 |

## Obiettivo

Glifi Studio deve usare l'unità di calcolo più adatta al carico reale: core CPU general purpose, primitive vettoriali, GPU e Neural Engine. La memoria unificata riduce alcune copie ma non elimina costi di allocazione, sincronizzazione, banda, residency o pressione termica.

## Scala di adozione

| Livello | Tecnologia | Uso |
| --- | --- | --- |
| 0 | Swift ottimizzato e I/O incrementale | Implementazione di riferimento corretta, misurabile e portabile tra i target |
| 1 | Accelerate | Statistica, algebra lineare, vettori, matrici, trasformazioni, convoluzioni e primitive BNNS |
| 2 | Core ML | Inferenza e tensori con scelta di CPU, GPU o Neural Engine gestita dal sistema |
| 3 | Metal e Metal Performance Shaders | Kernel massivamente paralleli e pipeline GPU con beneficio end-to-end dimostrato |

## Regole di selezione

La formula e le precondizioni sono definite da
[GS-MET-001](../metodi-analitici/README.md): Accelerate, BNNS, Core ML e Metal/MPS
sono backend e **NON DEVONO** cambiare semantica, zero impliciti, tie-break o classe
di risultato.

- Ogni backend accelerato **DEVE** condividere fixture, semantica e tolleranze con l'implementazione di riferimento.
- Accelerate **DEVE** essere valutato prima di scrivere kernel Metal equivalenti già coperti dalle sue primitive.
- Metal **DEVE** essere introdotto soltanto quando preparazione, trasferimenti, sincronizzazione e lettura dei risultati producono un beneficio end-to-end significativo.
- Core ML **DOVREBBE** lasciare al sistema la selezione delle unità di calcolo salvo evidenza contraria.
- Le capacità **DEVONO** essere interrogate a runtime; il codice **NON DEVE** dipendere da nomi commerciali dei chip.
- Ogni percorso accelerato **DEVE** avere fallback e gestione esplicita di memoria insufficiente, cancellazione ed errore del dispositivo.
- Buffer, batch e rappresentazioni **DEVONO** minimizzare copie e conversioni; l'uso di memoria condivisa o privata deve essere scelto tramite profiling.
- Precisione ridotta, quantizzazione o accumulazione non `Float32` **DEVONO** superare i test numerici approvati.
- Compilazione di pipeline e modelli **DOVREBBE** essere anticipata o memorizzata quando riduce la latenza senza rendere fragile l'avvio.
- Concorrenza CPU e GPU **DEVE** rispettare priorità, backpressure, stato termico ed esperienza interattiva.

## Matrice minima di benchmark

Per ogni algoritmo candidato devono essere confrontati almeno:

- implementazione di riferimento, Accelerate e backend Metal/Core ML applicabile;
- corpus piccolo, medio e stress;
- Mac e iPad rappresentativi della matrice supportata;
- tempo totale, throughput, latenza, memoria massima, copie, energia e stato termico;
- input freddo e caldo, cancellazione e concorrenza con l'interfaccia;
- correttezza esatta o errore numerico entro tolleranza.

Un backend più veloce ma sensibilmente peggiore per memoria, energia o responsività **NON DEVE** diventare il default senza una decisione motivata.

## Neural Engine nei flussi di Glifi Studio

| Flusso | Decisione applicativa | Verifica prima dell'adozione |
| --- | --- | --- |
| Ricerca KWIC, frequenze, indici, BM25 e statistica | Swift e primitive Accelerate già pertinenti alle operazioni numeriche. L'indice e i risultati seguono gli algoritmi scientifici versionati. | Parità con gli oracoli e misure end-to-end per ogni ottimizzazione |
| Testo di una scansione | Primo candidato per la NPU. Vision espone i dispositivi ammessi per la fase di una specifica richiesta OCR. Lasciare al sistema la scelta ordinaria. | Corpus di scansioni approvato, italiano, tassi di errore per carattere e parola, regioni e corrispondenza alla fonte |
| Suggerimento di codici, tagging o embedding | Candidati per Core ML quando esiste un modello locale autorizzato, versionato e valutato. La persona conferma un eventuale suggerimento. | Per tagging o classificazione confrontare precision, recall e F1 per classe. Per recupero semantico misurare il ranking su giudizi di pertinenza separati dall'addestramento |
| Riassunto estrattivo, ordinamento e inferenza statistica correnti | Conservare i metodi riproducibili di GlifiCore. Una funzione assistiva generativa avrebbe requisiti e provenienza propri. | Confronto con i contratti dei metodi e gli artefatti persistiti |

Per un modello Core ML confrontare `.cpuOnly`, `.cpuAndNeuralEngine` e `.all` con
gli stessi dati, includendo caricamento a freddo, richieste calde singole e batch,
tokenizzazione, conversioni e restituzione del risultato. `.cpuAndNeuralEngine`
ammette anche la CPU. Il piano di calcolo indica il dispositivo preferito per
operazione. Per attribuire l'esecuzione e il beneficio servono anche il report
prestazionale di Xcode e una traccia Instruments sul dispositivo. Rilevare qualità,
latenza mediana e p95, memoria, energia e stato termico sulle due piattaforme.
Per Vision si interrogano invece i dispositivi ammessi dalla specifica richiesta.
La prova locale e i limiti osservati sono in [GS-VER-270](../evidenze/GS-VER-270-grafici-comandi-neural-engine.md).

## Tecnologie escluse

ML Compute **NON DEVE** essere adottato perché deprecato; per nuovi lavori si usano BNNS/Accelerate, Metal Performance Shaders e Core ML secondo l'indicazione Apple.

## Riferimenti Apple

- [Core ML — configurazioni delle unità di calcolo](https://developer.apple.com/documentation/coreml/mlcomputeunits)
- [Core ML — analisi delle prestazioni in Xcode](https://developer.apple.com/documentation/coreml/analyzing-a-core-ml-model-s-performance-in-xcode)
- [Vision — dispositivi supportati per fase](https://developer.apple.com/documentation/vision/vnrequest/supportedcomputestagedevices)

- [Accelerate](https://developer.apple.com/documentation/accelerate)
- [Metal](https://developer.apple.com/documentation/metal)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [Core ML](https://developer.apple.com/documentation/coreml)
- [Metal feature set tables](https://developer.apple.com/metal/capabilities/)
- [ML Compute — deprecated](https://developer.apple.com/documentation/mlcompute)
