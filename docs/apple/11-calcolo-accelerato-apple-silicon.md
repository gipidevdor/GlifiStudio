# Calcolo accelerato su Apple silicon

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-011 |
| Tipo | Standard applicativo Apple |
| Versione | 1.1.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
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

## Tecnologie escluse

ML Compute **NON DEVE** essere adottato perché deprecato; per nuovi lavori si usano BNNS/Accelerate, Metal Performance Shaders e Core ML secondo l'indicazione Apple.

## Riferimenti Apple

- [Accelerate](https://developer.apple.com/documentation/accelerate)
- [Metal](https://developer.apple.com/documentation/metal)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [Core ML](https://developer.apple.com/documentation/coreml)
- [Metal feature set tables](https://developer.apple.com/metal/capabilities/)
- [ML Compute — deprecated](https://developer.apple.com/documentation/mlcompute)
