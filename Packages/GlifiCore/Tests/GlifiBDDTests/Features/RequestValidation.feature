# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @cli @failure @privacy
Funzionalità: Richieste analitiche ambigue o fuori limite vengono rifiutate
  Il confine JSON conserva le failure native senza divulgare il contenuto
  ricevuto o i percorsi dei file temporanei.

  Contesto:
    Dato un ambiente CLI isolato

  Schema dello scenario: Il JSON non conforme restituisce una failure tipizzata e riservata
    Dato una richiesta CLI JSON <richiesta>
    Quando eseguo la richiesta analitica con la CLI
    Allora la CLI termina con codice <uscita>
    E la failure CLI ha codice "<failure>"
    E la failure della richiesta CLI coincide con GlifiKit

    Esempi:
      | richiesta                                                                                                                                                                                                      | uscita | failure                            |
      | {}                                                                                                                                                                                                             | 3      | text-analysis.invalid-request      |
      | {"schema":"BDD_PRIVATE_CANARY","schemaVersion":1,"operation":"coding","units":[],"rules":""}                                                                                                                       | 3      | text-analysis.invalid-schema       |
      | {"schema":"studio.glifi.text-analysis-request","schemaVersion":2,"operation":"coding","units":[],"rules":"BDD_PRIVATE_CANARY"}                                                                                       | 10     | text-analysis.incompatible-version |
      | {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"coding","units":[],"rules":"","BDD_PRIVATE_CANARY":true}                                                                               | 3      | text-analysis.unknown-field        |
      | {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"coding","units":[],"rules":"","rules":"BDD_PRIVATE_CANARY"}                                                                           | 3      | text-analysis.duplicate-key        |
      | {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"coding","units":[],"rules":"","\u0072ules":"BDD_PRIVATE_CANARY"}                                                                      | 3      | text-analysis.duplicate-key        |
      | {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"mds","matrix":[[0,1],[1,0]],"dimensions":null}                                                                                          | 3      | text-analysis.invalid-request      |
      | {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"coding","units":[{"id":"1","text":"BDD_PRIVATE_CANARY"}],"rules":"*A\ncasa"                                                         | 3      | text-analysis.invalid-request      |

  Scenario: Il preflight rifiuta byte che non rappresentano UTF-8
    Dato una richiesta CLI con UTF-8 invalido
    Quando eseguo la richiesta analitica con la CLI
    Allora la CLI termina con codice 3
    E la failure CLI ha codice "text-analysis.invalid-request"
    E la failure della richiesta CLI coincide con GlifiKit

  Scenario: La profondità massima precede la decodifica degli operatori
    Dato una richiesta CLI annidata a profondità 33
    Quando eseguo la richiesta analitica con la CLI
    Allora la CLI termina con codice 7
    E la failure CLI ha codice "text-analysis.depth-limit"
    E la failure della richiesta CLI coincide con GlifiKit

  Scenario: Una richiesta oltre un MiB fallisce prima della lettura completa
    Dato una richiesta CLI di 1048577 byte
    Quando eseguo la richiesta analitica con la CLI
    Allora la CLI termina con codice 7
    E la failure CLI ha codice "text-analysis.request-limit"
    E la failure della richiesta CLI coincide con GlifiKit
