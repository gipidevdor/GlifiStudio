# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @project
Funzionalità: Progetti locali e revisioni incorporate
  Il ricercatore conserva le fonti originali e uno stato autorevole verificabile.

  Contesto:
    Dato un progetto temporaneo vuoto

  Scenario: Un progetto nuovo non contiene risultati inventati
    Allora il progetto contiene 0 fonti e 0 artifact alla generazione 0

  Schema dello scenario: Importazione esplicita con conteggi indipendenti
    Data una fonte "originale" con testo "<testo>" in formato <formato>
    Quando importo la fonte "originale"
    Allora il profilo contiene <token> token lessicali e <tipi> tipi
    E il progetto contiene 1 fonti e 0 artifact alla generazione 1

    Esempi:
      | formato   | testo                  | token | tipi |
      | plainText | Uno due due.           | 3     | 2    |
      | plainText | Città città mare.      | 3     | 2    |
      | markdown  | # Titolo **mare**      | 2     | 2    |
      | plainText | ... ! ?                | 0     | 0    |

  Scenario: Due revisioni restano disponibili senza la fonte esterna
    Data una fonte "originale" con testo "Prima versione." in formato plainText
    Quando importo la fonte "originale"
    E aggiorno la fonte "originale" con il testo "Seconda versione."
    E elimino tutte le fonti esterne e riapro il progetto
    Allora le due revisioni incorporate conservano i testi "Prima versione." e "Seconda versione."
    E il progetto contiene 2 fonti e 0 artifact alla generazione 2

  Schema dello scenario: Una sessione chiusa rifiuta nuove operazioni
    Quando chiudo la sessione e richiedo <operazione>
    Allora la failure ha codice "project.session-closed" e categoria "invalidInput"

    Esempi:
      | operazione |
      | snapshot   |
      | query      |
      | corpus     |

  Schema dello scenario: Un'importazione fallita conserva tutta la generazione
    Dato lo stato del progetto è memorizzato
    Quando tento di importare una fonte <tipo>
    Allora la failure ha codice "<codice>" e categoria "<categoria>"
    E la failure non rivela il contenuto "private-canary" né percorsi locali
    E lo stato completo del progetto è invariato

    Esempi:
      | tipo          | codice            | categoria    |
      | assente       | file.unreadable   | transientIO  |
      | UTF8-invalida | text.invalid-utf8 | invalidInput |
