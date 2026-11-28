# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @cli @parita
Funzionalità: Trasporto CLI verificabile e coerente con GlifiKit
  Chi usa strumenti headless riceve gli stessi risultati e le stesse failure
  della facciata nativa, con protocollo esplicito e stato persistente integro.

  Contesto:
    Dato un ambiente CLI isolato

  Scenario: Lo stato testuale è adatto allo smoke test headless
    Quando richiedo lo stato CLI in formato "text"
    Allora la CLI termina con codice 0
    E lo stato testuale CLI è pronto

  Scenario: Lo stato JSON dichiara versione ed esito del protocollo
    Quando richiedo lo stato CLI in formato "json"
    Allora la CLI termina con codice 0
    E lo stato JSON CLI è pronto

  Schema dello scenario: Il profilo mantiene il contenuto e le statistiche della facciata nativa
    Dato una fonte CLI in formato <formato> con testo "<testo>"
    Quando profila la fonte con la CLI
    Allora la CLI termina con codice 0
    E il profilo CLI coincide integralmente con GlifiKit
    E il profilo CLI contiene <token> token lessicali

    Esempi:
      | formato   | testo                        | token |
      | plainText | casa casa mare.              | 3     |
      | plainText | Città è città.               | 3     |
      | markdown  | **casa** mare.               | 2     |
      | markdown  | # Città                      | 1     |

  Scenario: Un progetto creato e importato dalla CLI si riapre e si valida
    Dato un progetto CLI con la fonte sintetica
    Quando valido il progetto con la CLI
    Allora la CLI termina con codice 0
    E la validazione CLI dichiara il progetto valido
    E il progetto CLI conserva lo snapshot precedente

  Schema dello scenario: Le concordanze conservano ordine intervalli digest e contesto
    Dato un progetto CLI con la fonte sintetica
    Quando interrogo la CLI con '<query>'
    Allora la CLI termina con codice 0
    E la query CLI coincide con GlifiKit
    E la query CLI produce gli intervalli "<intervalli>"
    E il progetto CLI conserva lo snapshot precedente

    Esempi:
      | query                                        | intervalli     |
      | normalized:casa                              | 0:4,6:10,24:28 |
      | form:Casa                                    | 0:4            |
      | "casa sul mare"                              | 6:19           |
      | normalized:casa BEFORE/1 normalized:mare      | 6:19           |
      | form:/^Casa$/                                | 0:4            |
      | normalized:inesistente                       |                |

  Schema dello scenario: Una query rifiutata non modifica il progetto
    Dato un progetto CLI con la fonte sintetica
    Quando interrogo la CLI con "<query>"
    Allora la CLI termina con codice 3
    E la failure CLI ha codice "<failure>"
    E la failure query CLI coincide con GlifiKit
    E il progetto CLI conserva lo snapshot precedente

    Esempi:
      | query                         | failure              |
      | form:/(a+)+/                  | query.regex-rejected |
      | BDD_PRIVATE_CANARY:casa       | query.unknown-field  |

  Schema dello scenario: Un uso non valido restituisce la guida e un exit status distinto
    Quando invoco la CLI con argomenti JSON <argomenti>
    Allora la CLI termina con codice 2
    E la CLI mostra la guida senza risultato

    Esempi:
      | argomenti                                  |
      | ["comando-inesistente"]                     |
      | ["--format","xml","status"]                |
      | ["project","create"]                       |
      | ["text-analysis"]                          |
      | ["query","manca.glifi","--text"]            |
