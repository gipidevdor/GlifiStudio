# language: it
# SPDX-License-Identifier: BSD-3-Clause

@GS-CMP-332 @macos @export @integrity
Funzionalità: Export scientifico verificabile
  Tabella, specifica e manifest devono raccontare gli stessi dati e la stessa provenienza.

  Contesto:
    Data una tabella scientifica con etichetta 'mare, "calmo"'
    E il bundle scientifico è stato generato

  Scenario: Il bundle integro conserva lineage, valori e digest
    Quando verifico il bundle scientifico
    Allora manifest e payload conservano provenienza e valori
    E il CSV contiene l'etichetta quotata secondo RFC4180

  Schema dello scenario: L'alterazione dei byte invalida il bundle
    Quando altero i byte del file "<file>"
    E verifico il bundle scientifico
    Allora la failure ha codice "visual-export.integrity-failed" e categoria "corruption"

    Esempi:
      | file           |
      | view.csv       |
      | view-spec.json |

  Schema dello scenario: Nessun componente obbligatorio può mancare
    Quando rimuovo il file "<file>"
    E verifico il bundle scientifico
    Allora la failure ha codice "visual-export.integrity-failed" e categoria "corruption"

    Esempi:
      | file                        |
      | view.csv                    |
      | view-spec.json              |
      | visual-export-manifest.json |

  Scenario: Un file non dichiarato non viene ignorato
    Quando aggiungo un file non dichiarato al bundle
    E verifico il bundle scientifico
    Allora la failure ha codice "visual-export.integrity-failed" e categoria "corruption"

  Schema dello scenario: La provenienza deve concordare con la specifica
    Quando sostituisco il campo di provenienza "<campo>" del manifest
    E verifico il bundle scientifico
    Allora la failure ha codice "visual-export.integrity-failed" e categoria "corruption"

    Esempi:
      | campo                   |
      | artifactID              |
      | methodIdentifier        |
      | specificationIdentifier |

  Scenario: Un nuovo digest non rende corretto un CSV scientificamente alterato
    Quando altero il CSV e aggiorno il suo digest nel manifest
    E verifico il bundle scientifico
    Allora la failure ha codice "visual-export.integrity-failed" e categoria "corruption"
