<!-- SPDX-License-Identifier: BSD-3-Clause -->

# DoR — Flussi tematici e dendrogrammi esplorabili

| Campo | Valore |
| --- | --- |
| Identificatore | GS-DOR-335 |
| Tipo | Scheda Definition of Ready |
| Versione | 1.0.0 |
| Stato | Ready per integrazione e verifica |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-11-28 |
| Approvazione | Richiesta esplicita di completare corrispondenze e clustering e di rendere tutti gli algoritmi raggiungibili in flussi GUI tematici |
| Riferimenti | ADR-0041; ADR-0043; GS-UX-001-17; GS-MET-001-10; GS-MET-001-14; GS-VIZ-001; GS-API-003; RF-033; RF-087; RQ-027; RQ-028; RQ-033; RQ-037; RQ-038; RQ-058; RQ-060; RQ-063; CMP-335 |

## Contesto e perimetro autorizzato

CA e clustering gerarchico documentale sono già implementati. La richiesta
chiude le lacune dell'esperienza: clustering delle parole sulle distribuzioni
tra documenti, esplorazione dell'albero e accessi tematici a ogni metodo,
comprese le diciannove operazioni KH già disponibili in GlifiKit/CLI.
La scheda consolida il perimetro durante l'integrazione autorizzata e non
retrodata la propria registrazione o una verifica ancora da eseguire.

L'integrazione applica ADR-0041 e ADR-0043. Riusa kernel, tassonomia e trasporto
esistenti. I metadati opzionali della vista conservano la topologia necessaria
alle interazioni; gli Artifact multivariati mantengono lo schema esistente e
aggiungono il lineage per termine quando pertinente. Non sono introdotti un
nuovo contenitore `.glifi`, backend, dipendenza, entitlement o servizio remoto.

## Definition of Ready

| Voce | Contratto |
| --- | --- |
| outcome e confini | Ogni metodo del catalogo ha tema di ricerca, scopo specifico e destinazione operativa; CA mostra il grafico; HAC consente documenti o parole e dendrogramma con zoom, taglio e compressione |
| temi | Vocabolario e stile; Relazioni e reti; Confronti e differenze; Temi e strutture; Classificazione dei documenti; Codifica e categorie; Qualità e validazione; Preparazione delle rappresentazioni |
| clustering delle parole | Profilo termine×documento a somma uno per termine; linkage esistente e taglio espliciti; identità dei termini e documenti contributivi conservati |
| parità | `hierarchicalTerms` nelle facciate e nel comando condiviso; CLI `multivariate --method hac --unit terms`; `recut-visualization` di `project-call` con specifica completa e numero o altezza; stessi risultati/failure; default documentale invariato e altre combinazioni di `--unit` rifiutate |
| dendrogramma | Topologia completa con identità di foglie e fusioni; tagli a numero o altezza senza rieseguire l'analisi; compressione limitata al grafico; tabella ed export conservano l'albero completo e il taglio scelto |
| famiglie KH | Nove preparazioni/misure di matrice, sei operazioni linguistiche/classificazione/codifica e quattro operazioni esplorative con editor nativi, parametri effettivi e output completo |
| failure semantics | Input non valido, risorse e cancellazione rimangono distinti; risultato precedente conservato in caso di errore; cambio progetto e reset impediscono pubblicazioni tardive |
| esperienza/accessibilità | Componenti SwiftUI di sistema, etichette it/en, tastiera e azioni accessibili; tabella equivalente e lineage selezionabili; audit manuali distinti dai test automatici |
| prestazioni | Preparazione di tagli, rami e tabelle fuori Main Actor; limiti prima dei buffer; nessuna promessa prestazionale senza misura |
| verifica | Suite Core/Kit, trasporto CLI e parità; native per inventario/temi, diciannove tag, parametri e lifecycle; regressioni su termini con stessa fonte e identità simili; `make verify` macOS prima della consegna |
| tracciabilità | GS-VER-335 e CMP-335 con esiti osservati, revisione del sorgente e limiti; nessuna promozione implicita degli stati scientifici o dei gate G4/G5 |
| recupero/pulizia | Modifiche concorrenti e file utente conservati; fixture temporanee possedute eliminate; deliverable e prove utili mantenuti |

**Ready** per la verifica integrata del perimetro registrato.

La presenza di un metodo nel catalogo o l'esito di un test di modello non
certificano un audit percettivo, VoiceOver, Voice Control, Full Keyboard Access,
pseudo-lingua o destra-sinistra. iPadOS resta fuori dalla verifica richiesta.
