# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @query @unicode
Funzionalità: Concordanze e rifiuto delle ricerche ambigue
  Ogni risultato torna ai byte originali senza modificare il progetto.

  Contesto:
    Dato un progetto temporaneo vuoto
    E nel progetto è importato il testo "Casa, casa sul mare. La casa guarda il mare."
    E lo stato del progetto è memorizzato

  Schema dello scenario: Termini, frasi e prossimità hanno intervalli esatti
    Quando cerco '<query>'
    Allora i risultati hanno intervalli UTF8 "<intervalli>"
    E lo stato completo del progetto è invariato

    Esempi:
      | query                                           | intervalli      |
      | normalized:casa                                 | 0:4,6:10,24:28   |
      | form:Casa                                       | 0:4             |
      | "casa sul mare"                                 | 6:19            |
      | normalized:casa BEFORE/1 normalized:mare         | 6:19            |
      | form:/^Casa$/                                   | 0:4             |

  Scenario: L'assenza di risultati è un successo esplicito
    Quando cerco "normalized:montagna"
    Allora la ricerca non contiene risultati
    E lo stato completo del progetto è invariato

  Schema dello scenario: Query non ammesse producono failure tipizzate e riservate
    Quando cerco '<query>'
    Allora la failure ha codice "<codice>" e categoria "invalidInput"
    E la failure non rivela il contenuto "private-canary" né percorsi locali
    E lo stato completo del progetto è invariato

    Esempi:
      | query                         | codice                |
      | private-canary:casa           | query.unknown-field   |
      | form:/(private-canary+)+/     | query.regex-rejected  |
