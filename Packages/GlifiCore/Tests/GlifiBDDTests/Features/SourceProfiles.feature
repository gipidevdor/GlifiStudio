# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @GS-CMP-337 @macos @profile @original-fixtures
Funzionalità: Tutti i formati originali conservano conteggi e provenienza
  Le fixture sono originali del progetto; i conteggi derivano dai testi sorgente.
  Il formato esplicito non dipende dall'estensione, mentre la CLI può rilevarlo.

  @phase-nominal
  Schema dello scenario: Profilo JSON nominale per ogni formato pubblico
    Data la fonte originale di profilo nel formato <formato>
    Quando eseguo il profilo pubblico nella fase nominal
    Allora il profilo originale contiene <token> token e <tipi> tipi
    E la fonte del profilo conserva esattamente i byte originali

    Esempi:
      | formato   | token | tipi |
      | plainText | 3     | 2    |
      | markdown  | 3     | 2    |
      | pdf       | 10    | 6    |
      | epub      | 12    | 8    |

  @phase-invalid-input
  Schema dello scenario: Il formato non rende accettabili campi JSON sconosciuti
    Data la fonte originale di profilo nel formato <formato>
    Quando eseguo il profilo pubblico nella fase invalid-input
    Allora il profilo fallisce con codice "command.unknown-field" e categoria invalidInput
    E la fonte del profilo conserva esattamente i byte originali

    Esempi:
      | formato   |
      | plainText |
      | markdown  |
      | pdf       |
      | epub      |

  @phase-pre-cancelled
  Schema dello scenario: La cancellazione precede la profilazione di ogni formato
    Data la fonte originale di profilo nel formato <formato>
    Quando eseguo il profilo pubblico nella fase pre-cancelled
    Allora il profilo fallisce con codice "command.cancelled" e categoria cancelled
    E la fonte del profilo conserva esattamente i byte originali

    Esempi:
      | formato   |
      | plainText |
      | markdown  |
      | pdf       |
      | epub      |

  Schema dello scenario: La CLI riconosce il formato senza perderne il profilo
    Data la fonte originale di profilo nel formato <formato>
    Quando importo con la CLI rilevando il formato dalla fonte
    Allora il profilo originale contiene <token> token e <tipi> tipi
    E la fonte importata conserva formato, digest e generazione

    Esempi:
      | formato   | token | tipi |
      | plainText | 3     | 2    |
      | markdown  | 3     | 2    |
      | pdf       | 10    | 6    |
      | epub      | 12    | 8    |

  Schema dello scenario: Il formato resta interrogabile senza il file esterno
    Data la fonte originale di profilo nel formato <formato>
    Quando importo la fonte e riapro senza il file originale
    Allora il profilo originale contiene <token> token e <tipi> tipi
    E la fonte incorporata conserva <riscontri> riscontri identici

    Esempi:
      | formato   | token | tipi | riscontri |
      | plainText | 3     | 2    | 1         |
      | markdown  | 3     | 2    | 1         |
      | pdf       | 10    | 6    | 2         |
      | epub      | 12    | 8    | 1         |
