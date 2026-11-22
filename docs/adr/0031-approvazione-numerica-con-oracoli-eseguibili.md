<!-- SPDX-License-Identifier: BSD-3-Clause -->

# ADR-0031 — Approvazione numerica con oracoli eseguibili e tolleranze dichiarate

| Campo | Valore |
| --- | --- |
| Identificatore | GS-ADR-0031 |
| Versione | 1.0.0 |
| Stato | Accettato |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-20 |
| Decisore | Iniziatore del progetto |
| Data proposta | 2026-09-20 |
| Data decisione | 2026-09-20 |
| Approvazione | Opzione «oracoli R e tolleranze dichiarate» scelta esplicitamente (DA-025) |
| Integra | GS-VAL-001, GS-MET-001-03, ADR-0024 |
| Sostituisce | Nessuno |

## Contesto

DA-025 chiedeva quali dataset, implementazioni indipendenti e tolleranze approvano ogni variante
GS-MET. I dodici `ValidationManifest` dichiarano V0–V4 superati ma restano in stato `candidate`,
senza che sia scritto da nessuna parte che cosa manchi per promuoverli. Le tolleranze numeriche
esistono soltanto sparse nelle asserzioni dei test (`1e-12`, `1e-9`, `1e-15`), quindi non sono
confrontabili fra capacità né verificabili dal gate.

Gli oracoli esterni sono già una realtà operativa: dodici script R e uno Python vengono rieseguiti
a ogni `make verify` da `check-oracles.py` e confrontati con i valori attesi versionati.

## Decisione

Una variante passa a `supported`, il vocabolario già in uso per una capacità approvata, quando
valgono tutte queste condizioni:

1. i livelli V0–V4 sono `pass`, oppure `not-applicable` con motivo scritto;
2. il manifest dichiara un blocco `numericAgreement` con la modalità di confronto di
   GS-MET-001-03 e la tolleranza effettivamente imposta dai test, per quella capacità;
3. l'oracolo di V2 è codice **indipendente dall'implementazione sotto test** — uno script R o
   Python rieseguito dal gate, non il prodotto che si sta validando — oppure, per le capacità non
   numeriche, un oracolo strutturale dichiarato (round-trip, ordine, identità);
4. il manifest registra una review con responsabile e data.

La review interna dell'iniziatore è sufficiente per la 0.1. Una review scientifica esterna resta
necessaria prima della 1.0 e non è sostituita da questa decisione.

`Fixtures/Scientific/v1` **non** viene promossa: resta un seed sintetico pre-review, come già
dichiarato da GS-VAL-001. L'approvazione riguarda i manifest delle capacità, non quella collezione.

## Conseguenze

Le tolleranze diventano parte del contratto verificabile e non più un dettaglio dei test:
cambiarle richiede di cambiare il manifest, e `check-fixtures.py` rifiuta un manifest `supported`
senza blocco numerico, senza oracolo indipendente o senza review. Una capacità il cui oracolo coincide con il
prodotto non può essere approvata: resta `candidate` con il motivo scritto.

## Stato

Accettato il 2026-09-20. DA-025 è chiusa per la 0.1; la review esterna pre-1.0 resta aperta.
