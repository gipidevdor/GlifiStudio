<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-025 — Persistenza transazionale di Artifact e DAG

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-025 |
| Tipo | Evidenza di verifica di persistenza analitica |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-001, TV-004, TV-005, TV-027, TV-051, TV-054, TV-060 e TV-072 |

## Ambito

- manifest e store schema 2 con radice e conteggio Artifact inclusi nel digest
  della generazione;
- payload e `AnalysisDescriptor` canonici come oggetti SHA-256 immutabili e
  fisicamente deduplicati;
- ricostruzione fail-closed del DAG dopo verifica di path, tipo, dimensione,
  digest, ArtifactID, AnalysisNodeID, schema e catena delle dipendenze;
- commit idempotente dello stesso risultato e nuova generazione per ogni modifica;
- sostituzione di un nodo con invalidazione dei suoi soli discendenti e
  conservazione dei rami indipendenti nelle proiezioni compatibili;
- invalidazione conservativa di tutti gli Artifact correnti quando cambia il
  corpus tramite import, senza alterare le generazioni storiche;
- fault injection dopo ognuno dei sei passi già usati dal protocollo fonti.

## Procedura

1. creare un package vuoto e un descriptor legato alla radice fonti corrente;
2. committare payload e descriptor, riaprire il package e confrontare snapshot,
   DAG e byte riletti;
3. ripetere lo stesso commit e verificare che non nasca una nuova generazione;
4. aggiungere un figlio che referenzia digest e schema del padre;
5. sostituire l'output del padre e verificare la rimozione del figlio dalla nuova
   generazione;
6. importare una nuova fonte e verificare la proiezione Artifact vuota;
7. alterare il payload raggiungibile e verificare il rifiuto per `corruption`;
8. interrompere il commit dopo staging, promozione oggetti, prepare SQLite,
   manifest candidato, sostituzione manifest e marcatura committed;
9. eseguire `make verify`, incluse le quattro build Xcode previste.

## Risultato osservato

- 60 test Swift complessivi superati: 54 GlifiCore e 6 GlifiKit;
- un commit identico mantiene generazione e snapshot invariati;
- un nodo figlio è accettato soltanto quando il padre raggiungibile ha digest e
  schema attesi;
- la sostituzione del padre produce una nuova radice valida senza il discendente
  stale;
- una modifica ai byte Artifact rende il package non apribile in scrittura e
  conserva `readOnlyRecovery` come stato dichiarato;
- i quattro checkpoint anteriori al commit point espongono la generazione
  precedente; i due successivi espongono quella nuova;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

Il test di interruzione descritto qui è deterministico nello stesso processo; la
successiva [GS-VER-072](GS-VER-072-process-kill-recovery.md) acquisisce la
terminazione reale dell'Artifact sugli stessi sei checkpoint. Power-loss, file
provider e dispositivi fisici restano aperti. Il singolo Artifact
è bounded a 64 MiB e il descriptor a 1 MiB; streaming/spill e garbage collection
non sono implementati. Questa evidenza non copriva il commit automatico delle
analisi, acquisito separatamente da
[GS-VER-026](GS-VER-026-analisi-persistenti-riusabili.md). L'invalidazione al cambio
corpus è volutamente conservativa fino alla persistenza della mappa
SourceRevision→AnalysisNode.

## Esito

**Superato localmente per persistenza, riapertura, integrità e semantica di commit
di `analysis-dag-v1`.** Questa evidenza non promuove recovery completa o percorso
Must a feature complete; il planner è verificato separatamente da GS-VER-027.
