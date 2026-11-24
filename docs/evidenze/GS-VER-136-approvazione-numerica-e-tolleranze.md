<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-136 — Tolleranze dichiarate e promozione dei ValidationManifest

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-136 |
| Tipo | Evidenza di validazione |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Approvazione | ADR-0031 accettato dall'iniziatore (DA-025 chiusa per la 0.1) |

## Ambito

Attua ADR-0031: le tolleranze numeriche smettono di essere un dettaglio sparso nelle asserzioni
dei test e diventano parte del contratto verificabile.

- **Blocco `numericAgreement`** in tutti e dodici i manifest: modalità di confronto del protocollo
  numerico (`exactInteger`, `absoluteTolerance`, `structural`), tolleranza effettiva, oracolo usato
  e nota che spiega la scelta. I valori non sono inventati: sono quelli che i test impongono già,
  per esempio 1e-10 sugli estremi degli intervalli di keyness e 1e-12 sulle formule chiuse di
  ponderazione e diversità, mentre conteggi, frequenze documentali e intervalli UTF-8 restano
  confronti esatti senza tolleranza.
- **Promozione selettiva**: sette capacità passano a `supported`, cinque restano `candidate`.
- **Controllo nel gate**: `check-fixtures.py` rifiuta un manifest senza blocco numerico, con
  tolleranza non positiva dove la modalità la richiede, con oracolo inesistente, `supported` senza
  oracolo indipendente, senza V0–V4 superati o senza review registrata, e `candidate` senza motivo.

## Procedura e risultato

| Capacità | Esito | Oracolo |
| --- | --- | --- |
| `corpus-profile-it-v1` | supported | `check-fixtures.py` (ricalcolo in Python) |
| `glifi-query-v1` | supported | `check-fixtures.py` |
| `keyness-gtest-ha-bh-v1` | supported | `check-fixtures.py` |
| `keyness-gtest-fisher-ha-ci-bh-v2` | supported | `Tests/Oracles/R/keyness.R` |
| `corpus-lexical-diversity-mtld-v1` | supported | `Tests/Oracles/R/diversity.R` |
| `corpus-ngram-frequencies-v1` | supported | `Tests/Oracles/R/ngrams.R` |
| `corpus-term-weighting-v1+corpus-bm25-ranking-v1` | supported | `Tests/Oracles/R/weighting.R` |
| `planner-mvp-v1`, `interpretation-mvp-v1`, `investigation-history-v1`, `analysis-execution-v1`, `scientific-export-v1` | restano candidate | test del prodotto |

Le cinque capacità che restano `candidate` dichiarano il motivo nel manifest: il loro oracolo di
V2 è un test del prodotto, quindi non è indipendente dall'implementazione che dovrebbe validare.
ADR-0031 non ammette di promuoverle, e non sono state promosse.

Controprove eseguite: togliendo il blocco numerico a un manifest il gate fallisce con «blocco
numericAgreement mancante»; sostituendo l'oracolo con un test del prodotto fallisce con
«supported richiede un oracolo indipendente dal prodotto».

## Limiti

La review è **interna**: l'ha svolta l'iniziatore del progetto, non una persona esterna. ADR-0031
mantiene la review scientifica esterna come requisito prima della 1.0, quindi `supported` qui
significa «approvato secondo i criteri dichiarati del progetto», non «validato da terzi».
`Fixtures/Scientific/v1` resta un seed sintetico pre-review e non è stata promossa. Le tolleranze
dichiarate valgono per il backend Swift su CPU: V5 resta non applicabile finché non esiste un
secondo backend.

## Esito

**Superato localmente: sette capacità sono `supported` con tolleranza, oracolo indipendente e
review registrati, e il gate impedisce di dichiararlo senza averne i requisiti.**
