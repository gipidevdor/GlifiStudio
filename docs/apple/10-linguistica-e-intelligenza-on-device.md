# Linguistica e intelligenza on-device

| Campo | Valore |
| --- | --- |
| Identificatore | GS-APL-010 |
| Tipo | Standard applicativo Apple |
| Versione | 1.2.0 |
| Stato | Approvato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | ADR-0008 |

## Separazione delle responsabilità

Glifi Studio distingue analisi deterministica, modelli statistici specializzati e funzioni generative. Queste classi di calcolo hanno contratti, verifiche e aspettative di riproducibilità differenti.

## Portafoglio tecnologico

| Tecnologia | Uso candidato | Stato |
| --- | --- | --- |
| Natural Language | Identificazione lingua, tokenizzazione, tagging, lemma, entità ed embedding disponibili | Prima valutazione per la baseline italiana |
| Core ML | Classificatori, tagger, embedding e modelli specializzati locali | Da valutare per singolo modello |
| Foundation Models | Riassunto, estrazione strutturata, formulazione assistita di query e spiegazioni | Condizionale e non autoritativo |
| Core AI tramite Foundation Models | Modelli locali alternativi per dispositivi o compiti non coperti dal modello di sistema | Sperimentale; richiede spike e verifica SDK finale |
| Create ML e Core ML Tools | Produzione o conversione offline dei modelli | Strumenti di sviluppo, non dipendenze runtime obbligatorie |

## Natural Language

- Natural Language **DEVE** essere incapsulato dietro i contratti sostituibili di GlifiCore.
- Capacità, lingue, token, lemma e categorie **DEVONO** essere misurati su corpus italiani versionati.
- Range e offset Foundation **DEVONO** essere convertiti nel modello canonico senza perdere il collegamento alla fonte.
- Una differenza dovuta a versione del sistema operativo o revisione del modello **DEVE** essere registrabile nei metadati dell'artefatto.
- Valutazione, split, metriche e deriva **DEVONO** seguire
  [GS-MET-001-18](../metodi-analitici/18-valutazione-servizi-linguistici.md); la
  disponibilità dell'API **NON È** evidenza di qualità linguistica.

## Core ML e Neural Engine

- Un modello **DEVE** avere identità, versione, licenza, checksum, provenienza, input/output e tolleranze documentati.
- La configurazione iniziale **DOVREBBE** consentire a Core ML di scegliere tra CPU, GPU e Neural Engine con `MLComputeUnits.all`.
- Restrizioni a CPU, GPU o Neural Engine **DEVONO** derivare da compatibilità, background execution o benchmark misurati.
- Inferenza batch, warm-up, memoria e costo energetico **DEVONO** essere profilati su ogni classe hardware supportata.
- Ogni modello **DEVE** avere comportamento definito quando l'unità preferita non è disponibile.

## Foundation Models

- Foundation Models **NON DEVE** essere una dipendenza necessaria per aprire un progetto, cercare, produrre conteggi o riprodurre risultati analitici fondamentali.
- La disponibilità del modello **DEVE** essere interrogata a runtime; l'interfaccia deve offrire un fallback utile sui dispositivi non compatibili con Apple Intelligence.
- Output generativi **DEVONO** essere etichettati come probabilistici e distinguibili dai dati osservati o calcolati deterministicamente.
- Prompt, istruzioni, schema guidato, strumenti, versione logica e porzioni di contesto **DEVONO** essere registrati quando il risultato viene persistito.
- Per output strutturati **DOVREBBE** essere usata la guided generation anziché parsing libero del testo.
- Il limite di contesto **DEVE** essere gestito con chunking e retrieval; un intero corpus non deve essere inserito in una sessione.
- Tool calling **DEVE** esporre operazioni minime, senza effetti collaterali impliciti e con autorizzazione separata per le modifiche.
- Private Cloud Compute o provider server **NON DEVONO** essere abilitati senza requisito, valutazione privacy, rete autorizzata, disclosure e ADR dedicato.
- Una domanda naturale **DEVE** essere trasformata in un'interpretazione canonica
  validata prima di produrre un piano; non viene inoltrata come richiesta di una
  conclusione libera.
- Un modello generativo **NON DEVE** stabilire applicabilità, significatività,
  solidità o stato di un finding e non può rimuovere caveat.
- La prosa generata per una relazione **DEVE** essere controllata contro finding ed
  evidenze strutturati prima di essere conservata.

Il riassunto estrattivo deterministico e i percorsi LSA/NMF/LDA sono governati da
GS-MET-001-19 e GS-MET-001-15. Foundation Models non li sostituisce e produce una
categoria epistemica distinta.

## Riferimenti Apple

- [Natural Language](https://developer.apple.com/documentation/naturallanguage)
- [Core ML](https://developer.apple.com/documentation/coreml)
- [MLComputeUnits](https://developer.apple.com/documentation/coreml/mlcomputeunits)
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Managing the on-device foundation model context window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)
