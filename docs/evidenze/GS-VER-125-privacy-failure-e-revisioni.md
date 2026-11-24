<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-125 — Privacy delle failure e revisioni incorporate delle fonti

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-125 |
| Tipo | Evidenza di privacy e persistenza |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task V1 e V2 di GS-DOR-006 |

## V1 — RQ-046: nessun contenuto nelle failure

GS-API-001 § 8: «Nessun messaggio contiene contenuto, query, path o nomi file». Un canary compare
nel nome della cartella del progetto, nei nomi dei file, nel testo della fonte e nelle query.
`failuresNeverCarryCorpusContentQueriesOrPaths` provoca otto failure diverse (campo di query
sconosciuto, regex rifiutata, virgolette non chiuse, file assente, UTF-8 invalido, progetto
assente, query BM25 oltre il limite, unità di n-grammi sconosciuta) e verifica che nessun campo
della `GlifiStudioFailure`, argomenti compresi, contenga il canary o il path della cartella, e che
ogni chiave di messaggio sia `failure.*`. In `verify.sh` l'envelope JSON d'errore della CLI per una
query con il canary non contiene né il canary né il path del progetto.

La diagnostica runtime (`GlifiDiagnostics`) accetta solo eventi enum con valori `public` non
derivati dal corpus; `check-apple-baseline.py` vieta rete e telemetria.

## V2 — RF-077: revisioni distinte e fonti incorporate

`sourceUpdatesBecomeDistinctEmbeddedRevisions`: la reimportazione dello stesso file modificato crea
una seconda SourceRevision con digest diverso in una generazione successiva; dopo la rimozione del
file esterno e la riapertura del progetto entrambe le revisioni restituiscono esattamente il testo
originale; i record delle fonti non contengono il path esterno.

## Limiti

I riferimenti esterni non incorporati (RF-077, Should) non sono implementati. L'audit dei log di
sistema su dispositivo e dei bundle diagnostici resta nel gate G4.

## Esito

**Superato localmente: le failure non espongono contenuti né percorsi e ogni aggiornamento di una
fonte è una revisione incorporata distinta.**
