<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-072 — Process-kill recovery del package

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-072 |
| Tipo | Evidenza di verifica della crash consistency |
| Versione | 1.1.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza osservata parziale di TV-051, TV-060 e TV-072 |

## Ambito

- terminazione non intercettabile del processo writer tramite `SIGKILL`;
- sei checkpoint del commit generazionale di import/Artifact: staging, promozione
  oggetti, prepare SQLite, manifest candidato, sostituzione del manifest e
  marcatura committed;
- quattro checkpoint del commit di export: payload scritti, manifest scritto,
  staging validato e destinazione commessa tramite sostituzione atomica;
- percorsi distinti di import SourceRevision, persistenza Artifact/DAG ed export
  scientifico verso una destinazione `.glifiexport`;
- riapertura fail-closed del package e ispezione fail-closed della destinazione
  export in un processo nuovo;
- retry dei casi anteriori al commit point per verificare rilascio del writer
  lease, scarto del candidato/staging e nuova scrittura completa;
- isolamento dell'harness dalla superficie di produzione GlifiKit/app.

## Procedura

1. costruire `GlifiRecoveryHarness` come prodotto SwiftPM diagnostico;
2. creare un package vuoto distinto per operazione e checkpoint;
3. avviare un processo figlio che entra nel commit con input deterministico;
4. al checkpoint selezionato, inviare `SIGKILL` al processo corrente senza
   unwinding, `defer`, chiusura SQLite o rilascio esplicito del lock;
5. richiedere exit status `137`, rifiutando il fallback `_exit(86)`;
6. aprire il package in un altro processo e verificare generazione, fonti e
   Artifact raggiungibili;
7. per i checkpoint pre-commit, ripetere la stessa operazione (`retry-import`,
   `retry-artifact` o `retry-export`) e verificare il commit completo della
   generazione o della destinazione export attesa;
8. eseguire la prova nel gate completo `make verify`.

## Oracolo

| Checkpoint import/Artifact | Stato autorevole dopo `SIGKILL` |
| --- | --- |
| `staged` | `Gₙ`; retry consentito |
| `objectPromoted` | `Gₙ`; oggetto orfano non autorevole; retry consentito |
| `databasePrepared` | `Gₙ`; generazione prepared non autorevole; retry consentito |
| `manifestPrepared` | `Gₙ`; candidato non autorevole; retry consentito |
| `manifestReplaced` | `Gₙ₊₁` interamente verificabile |
| `databaseCommitted` | `Gₙ₊₁` interamente verificabile anche senza cleanup |

Lo stesso oracolo viene applicato indipendentemente a import e Artifact.

| Checkpoint export | Stato autorevole dopo `SIGKILL` |
| --- | --- |
| `payloadsWritten` | destinazione assente; staging isolato; retry consentito |
| `manifestWritten` | destinazione assente; staging isolato; retry consentito |
| `stagingValidated` | destinazione assente; staging isolato; retry consentito |
| `destinationCommitted` | destinazione interamente committata e verificabile anche senza cleanup |

Lo staging di export vive fuori dalla destinazione finale; nessun checkpoint
precedente a `destinationCommitted` può quindi pubblicare una destinazione
parziale, indipendentemente dal cleanup del processo terminato.

## Risultato osservato

- 16 processi writer terminati dal segnale atteso (6 import + 6 Artifact + 4
  export);
- 16 riaperture/ispezioni in un processo nuovo coerenti con il commit point;
- 11 retry pre-commit completati dalla generazione/destinazione assente al
  commit pieno (8 import/Artifact, 3 export);
- nessuna generazione o destinazione parziale esposta come autorevole;
- dopo `SIGKILL` il lock advisory viene rilasciato dal kernel e non impedisce il
  retry;
- il controllo architetturale impedisce a app, GlifiKit e GlifiCLI di importare
  l'API SPI `RecoveryTesting`.

## Limiti

`SIGKILL` prova l'assenza di cleanup applicativo, ma non simula perdita improvvisa
di alimentazione, cache hardware o semantiche di durabilità di ogni filesystem e
file provider. Indice, autosave, migrazione N-1, InvestigationHistory e recovery
read-only verso una generazione precedente non attraversano ancora il medesimo
harness. La prova non sostituisce test su dispositivi fisici con fault injection
del volume.

## Esito

**Superato localmente per la terminazione reale dei commit di import, Artifact ed
export ai rispettivi checkpoint del package e della destinazione `.glifiexport`.**
RQ-043 e RQ-059 restano parziali finché la matrice completa (indice, autosave,
migrazione, power-loss) e le prove su dispositivi fisici non sono acquisite.
