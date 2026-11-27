# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @corpus @numerical-oracle
Funzionalità: Analisi riproducibili di un corpus sintetico
  Conteggi manuali e proprietà matematiche accompagnano cache, limiti e failure.

  Schema dello scenario: Il limite del vocabolario non elimina token osservati
    Dato un corpus sintetico di due documenti
    E lo stato del progetto è memorizzato
    Quando preparo il laboratorio con al massimo <limite> termini
    Allora il laboratorio conserva sei token e vocabolario "<vocabolario>"
    E lo stato completo del progetto è invariato

    Esempi:
      | limite | vocabolario          |
      | 1      | casa                 |
      | 2      | casa,città           |
      | 3      | casa,città,mare      |
      | 4      | casa,città,mare,sole  |

  Schema dello scenario: Ambiti non validi non producono risultati parziali
    Dato un corpus sintetico di due documenti
    E lo stato del progetto è memorizzato
    Quando preparo il laboratorio con ambito <ambito>
    Allora la failure ha codice "text-analysis.invalid-request" e categoria "invalidInput"
    E lo stato completo del progetto è invariato

    Esempi:
      | ambito      |
      | vuoto       |
      | duplicato   |
      | inesistente |

  Schema dello scenario: I limiti del laboratorio sono convalidati prima del calcolo
    Dato un corpus sintetico di due documenti
    E lo stato del progetto è memorizzato
    Quando preparo il laboratorio con al massimo <limite> termini
    Allora la failure ha codice "text-analysis.invalid-request" e categoria "invalidInput"
    E lo stato completo del progetto è invariato

    Esempi:
      | limite |
      | 0      |
      | 1001   |

  Scenario: Il profilo descrive i conteggi osservati e la matrice completa
    Dato un corpus sintetico di due documenti
    Quando calcolo il profilo del corpus
    Allora il corpus ha sei token, quattro tipi e frequenza tre per casa

  Scenario: Il riuso dopo riapertura non pubblica un secondo risultato
    Dato un corpus sintetico di due documenti
    E il profilo del corpus è già in cache
    E lo stato del progetto è memorizzato
    Quando riapro il progetto
    E ricalcolo il profilo del corpus
    Allora il riuso conserva artifact, nodo e valori scientifici
    E lo stato completo del progetto è invariato

  Scenario: Un budget più restrittivo vale anche per un risultato in cache
    Dato un corpus sintetico di due documenti
    E il profilo del corpus è già in cache
    E lo stato del progetto è memorizzato
    Quando richiedo il corpus con budget di vocabolario 3
    Allora la failure ha codice "analysis.vocabulary-limit-exceeded" e categoria "insufficientResources"
    E lo stato completo del progetto è invariato

  Scenario: L'associazione coincide con il calcolo manuale
    Dato un corpus sintetico di due documenti
    Quando calcolo l'associazione fra i documenti
    Allora il chi quadro è dieci terzi con tre gradi di libertà

  Scenario: Jaccard confronta gli insiemi dei termini osservati
    Dato un corpus sintetico di due documenti
    Quando preparo il laboratorio con al massimo 4 termini
    E calcolo la distanza Jaccard del laboratorio
    Allora le distanze sono zero sulla diagonale e tre quarti fuori diagonale

  Scenario: Le frequenze per mille conservano esposizioni e proporzioni
    Dato un corpus sintetico di due documenti
    Quando preparo il laboratorio con al massimo 4 termini
    E normalizzo le righe del laboratorio per mille
    Allora ogni riga somma mille e preserva le proporzioni osservate

  Scenario: La cancellazione preventiva conserva il progetto
    Dato un corpus sintetico di due documenti
    E lo stato del progetto è memorizzato
    Quando preparo il laboratorio con cancellazione preventiva
    Allora la failure ha codice "operation.cancelled" e categoria "cancelled"
    E lo stato completo del progetto è invariato

  Scenario: Un piano senza fonti spiega la precondizione mancante
    Dato un progetto temporaneo vuoto
    Quando pianifico la comprensione della raccolta
    Allora il piano spiega che l'ambito è vuoto senza passi eseguibili

  Scenario: Un corpus senza token non genera finding privi di evidenza
    Dato un progetto temporaneo vuoto
    E nel progetto è importato il testo "... ! ?"
    Quando eseguo la comprensione della raccolta
    Allora l'interpretazione dichiara evidenza insufficiente e nessun finding
