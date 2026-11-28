# language: it
# SPDX-License-Identifier: BSD-3-Clause
# Provenance: GS-LIC-003 / BDD-SRC-03,04,05. All examples and fixture data are original.

@GS-CMP-332 @GS-CMP-337 @macos @interchange @fonti-verificate
Funzionalità: Contratti di interscambio JSON Unicode e CSV
  Regole di formati pubblici guidano casi originali con attese esplicite.
  Le verifiche Unicode seguono il contratto Glifi e non attestano conformità UAX completa.

  Schema dello scenario: Numeri JSON validi conservano distanza zero tra vettori identici
    Dato la richiesta analitica JSON {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"dissimilarities","matrix":[[<numero>,1],[<numero>,1]],"metric":"cosine"}
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "dissimilarities"
    E il valore analitico "result.0.0" è "0"
    E il valore analitico "result.0.1" è "0"
    E il valore analitico "result.1.0" è "0"
    E il valore analitico "result.1.1" è "0"
    E la riesecuzione analitica è identica

    Esempi:
      | numero |
      | 0 |
      | -0 |
      | 1 |
      | -2.5 |
      | 1.25 |
      | 1e-3 |
      | 1E+2 |
      | 1e-300 |

  Schema dello scenario: Token numerici non ammessi non producono risultati parziali
    Dato la richiesta analitica JSON {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"dissimilarities","matrix":[[<numero>,1],[1,1]],"metric":"cosine"}
    Quando eseguo la richiesta analitica
    Allora la richiesta analitica fallisce con codice "text-analysis.invalid-request" e categoria "invalidInput"

    Esempi:
      | numero |
      | 01 |
      | +1 |
      | 1. |
      | .5 |
      | 1e |
      | Infinity |
      | -Infinity |
      | NaN |

  Scenario: Un numero sintatticamente JSON oltre binary64 è rifiutato dal contratto Glifi
    Dato la richiesta analitica JSON
      """
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"dissimilarities","matrix":[[1e309,1],[1,1]],"metric":"cosine"}
      """
    Quando eseguo la richiesta analitica
    Allora la richiesta analitica fallisce con codice "text-analysis.invalid-request" e categoria "invalidInput"

  Scenario: Escape JSON equivalenti mantengono la semantica della richiesta
    Dato la richiesta analitica JSON
      """
      {"schema":"studio.glifi.text-analysis-request","schemaVersion":1,"operation":"\u0064issimilarities","matrix":[[1,2],[1,2]],"metric":"\u0063osine"}
      """
    Quando eseguo la richiesta analitica
    Allora l'operazione analitica è "dissimilarities"
    E il valore analitico "result.0.1" è "0"
    E il valore analitico "result.1.0" è "0"
    E la riesecuzione analitica è identica

  Scenario: Un surrogato isolato nello schema JSON è rifiutato prima della dispatch
    Dato la richiesta analitica JSON
      """
      {"schema":"\uD800","schemaVersion":1,"operation":"dissimilarities","matrix":[[1,2],[1,2]],"metric":"cosine"}
      """
    Quando eseguo la richiesta analitica
    Allora la richiesta analitica fallisce con codice "text-analysis.invalid-request" e categoria "invalidInput"

  Scenario: Un carattere di controllo TAB non escapato nella stringa JSON è rifiutato
    Dato la richiesta analitica JSON
      """
      {"schema":"studio.glifi.text-analysis-request	","schemaVersion":1,"operation":"dissimilarities","matrix":[[1,2],[1,2]],"metric":"cosine"}
      """
    Quando eseguo la richiesta analitica
    Allora la richiesta analitica fallisce con codice "text-analysis.invalid-request" e categoria "invalidInput"

  Schema dello scenario: I Character interi preservano i byte distinti di NFC NFD ed emoji ZWJ
    Dato una fonte Unicode originale con scalari "00E9 0020 0065 0301 0020 1F469 200D 1F52C 002E"
    Allora la fonte Unicode contiene 6 caratteri e 19 byte UTF8
    Quando seleziono il passaggio Unicode dai caratteri <inizio> a <fine>
    Allora il passaggio Unicode ha scalari "<scalari>" e intervallo UTF8 da <byte-inizio> a <byte-fine>
    E la codifica Unicode conserva il passaggio identico dopo la riapertura

    Esempi:
      | inizio | fine | scalari | byte-inizio | byte-fine |
      | 0 | 1 | 00E9 | 0 | 2 |
      | 2 | 3 | 0065 0301 | 3 | 6 |
      | 4 | 5 | 1F469 200D 1F52C | 7 | 18 |
      | 0 | 5 | 00E9 0020 0065 0301 0020 1F469 200D 1F52C | 0 | 18 |

  Schema dello scenario: Confini di scalare o di byte interni a un Character non cambiano la storia
    Dato una fonte Unicode originale con scalari "00E9 0020 0065 0301 0020 1F469 200D 1F52C 002E"
    Quando tento un passaggio Unicode con intervallo UTF8 da <inizio> a <fine>
    Allora la failure Unicode ha codice "qualitative.invalid-selection" senza pubblicare un passaggio
    Quando tento una codifica Unicode con intervallo UTF8 da <inizio> a <fine>
    Allora la failure Unicode ha codice "qualitative.invalid-range" senza pubblicare un passaggio
    E snapshot e storia Unicode restano identici anche dopo la riapertura

    Esempi:
      | inizio | fine |
      | 0 | 1 |
      | 3 | 4 |
      | 4 | 6 |
      | 7 | 11 |
      | 11 | 14 |
      | 8 | 18 |
      | 0 | 20 |

  Scenario: Un campo CSV semplice rimane non quotato e i mancanti rimangono vuoti
    Dato una tabella CSV originale con etichetta semplice
    Quando genero il bundle CSV di interscambio
    Allora i byte CSV coincidono con il testo JSON originale
      """
      "datum,node,collocate,joint,log-dice,t-score,npmi,mean-distance\r\npair:sponda|riva,sponda,riva,2,,,,2.5\r\n"
      """
    E il bundle CSV è verificato con provenienza e digest dei byte esatti

  Scenario: Una virgola nel valore e nella identità CSV richiede quoting
    Dato una tabella CSV originale con etichetta virgola
    Quando genero il bundle CSV di interscambio
    Allora i byte CSV coincidono con il testo JSON originale
      """
      "datum,node,collocate,joint,log-dice,t-score,npmi,mean-distance\r\n\"pair:sponda, chiara|riva\",\"sponda, chiara\",riva,2,,,,2.5\r\n"
      """
    E il bundle CSV è verificato con provenienza e digest dei byte esatti

  Scenario: Le virgolette interne CSV vengono raddoppiate
    Dato una tabella CSV originale con etichetta virgolette
    Quando genero il bundle CSV di interscambio
    Allora i byte CSV coincidono con il testo JSON originale
      """
      "datum,node,collocate,joint,log-dice,t-score,npmi,mean-distance\r\n\"pair:sponda \"\"alta\"\"|riva\",\"sponda \"\"alta\"\"\",riva,2,,,,2.5\r\n"
      """
    E il bundle CSV è verificato con provenienza e digest dei byte esatti

  Scenario: CRLF dentro un valore CSV resta dentro il campo quotato
    Dato una tabella CSV originale con etichetta CRLF
    Quando genero il bundle CSV di interscambio
    Allora i byte CSV coincidono con il testo JSON originale
      """
      "datum,node,collocate,joint,log-dice,t-score,npmi,mean-distance\r\n\"pair:sponda\r\nchiara|riva\",\"sponda\r\nchiara\",riva,2,,,,2.5\r\n"
      """
    E il bundle CSV è verificato con provenienza e digest dei byte esatti

  Scenario: Un'etichetta CSV vuota conserva il campo vuoto e il terminatore finale
    Dato una tabella CSV originale con etichetta vuota
    Quando genero il bundle CSV di interscambio
    Allora i byte CSV coincidono con il testo JSON originale
      """
      "datum,node,collocate,joint,log-dice,t-score,npmi,mean-distance\r\npair:|riva,,riva,2,,,,2.5\r\n"
      """
    E il bundle CSV è verificato con provenienza e digest dei byte esatti
