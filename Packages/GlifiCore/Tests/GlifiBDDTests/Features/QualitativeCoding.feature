# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @qualitative @unicode
Funzionalità: Passaggi Unicode e storia qualitativa
  Selezioni leggibili diventano intervalli codificabili senza dividere un carattere.

  Contesto:
    Dato un progetto temporaneo vuoto
    E nel progetto è importato il testo "Il mare è calmo. 👨‍👩‍👧 resta."

  Schema dello scenario: Gli intervalli di caratteri preservano accenti ed emoji composte
    Quando seleziono i caratteri da <inizio> a <fine>
    Allora il passaggio contiene "<testo>" e occupa <byte> byte UTF8

    Esempi:
      | inizio | fine | testo       | byte |
      | 3      | 7    | mare        | 4    |
      | 8      | 9    | è           | 2    |
      | 17     | 18   | 👨‍👩‍👧       | 18   |

  Schema dello scenario: Selezioni vuote, invertite o fuori dal testo sono rifiutate
    Dato lo stato del progetto è memorizzato
    Quando seleziono i caratteri da <inizio> a <fine>
    Allora la failure ha codice "qualitative.invalid-selection" e categoria "invalidInput"
    E lo stato completo del progetto è invariato

    Esempi:
      | inizio | fine |
      | 5      | 5    |
      | 9      | 3    |
      | -1     | 3    |
      | 0      | 100  |
      | 2      | 3    |

  Scenario: Codifica e memo mantengono la stessa storia dopo la riapertura
    Dato un codebook con la categoria luogo
    Quando seleziono i caratteri da 3 a 7
    E codifico il passaggio selezionato e aggiungo un memo
    Allora codifica e memo sopravvivono identici alla riapertura

  Scenario: Un intervallo che divide un accento non modifica la storia
    Dato un codebook con la categoria luogo
    E lo stato del progetto è memorizzato
    Quando tento una codifica con intervallo UTF8 da 0 a 9
    Allora la failure ha codice "qualitative.invalid-range" e categoria "invalidInput"
    E la storia qualitativa è invariata
    E lo stato completo del progetto è invariato
