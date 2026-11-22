<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-126 — Storia qualitativa append-only persistita (ADR-0027)

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-126 |
| Tipo | Evidenza di dominio e persistenza |
| Versione | 1.1.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-19 |
| Approvazione | Task C1 e C2 di GS-DOR-007 |

## Ambito

Implementa l'opzione 2 di ADR-0027 per RF-043:

- **Dominio** (`GlifiQualitativeHistory.swift`): eventi immutabili content-addressed
  `codebookRevised`, `categoryMapped`, `segmentCoded`, `codingRetracted`, `memoAttached` in una
  storia lineare; `GlifiQualitativeState` ne è la proiezione deterministica; `agreementTable`
  deriva la tabella di `coding-agreement-v2` dalle codifiche attive.
- **Persistenza**: radice `QualitativeHistory` nel manifest e nel record di generazione; store
  SQLite allo schema 4 con tabella globale `qualitative_event_entries` ordinata per sequenza, perché
  lo stato di ogni generazione è il prefisso dei suoi primi N eventi; oggetti evento in
  `qualitative/events/sha256/`. Ogni commit (importazione, Artifact, indagine, evento qualitativo)
  trasporta la radice. All'apertura si verificano righe, digest radice, oggetti e catena.
- **Compatibilità**: finché la storia è vuota manifest (schema 3) e digest dei record di
  generazione restano identici byte per byte ai package precedenti; lo store SQLite di schema 2 o 3
  migra in modo additivo allo schema 4.

## Procedura e risultato

1. `qualitativeProjectionReplaysHistory`: codebook in due revisioni, codifiche, ritrattazione,
   memo e mapping di fusione; le codifiche storiche restano sulla loro revisione; identità stabile
   al round-trip JSON;
2. `qualitativeAgreementTableMatchesExplicitTable`: la tabella derivata coincide con quella
   esplicita equivalente e produce lo stesso risultato di `GlifiCodingAgreementAnalyzer`; l'unità
   codificata due volte dallo stesso codificatore è esclusa e contata;
3. `qualitativeHistoryRejectsInvalidChanges`: revisione non consecutiva, categoria assente, doppia
   ritrattazione, catena interrotta, gerarchia ciclica, identificatore e testo non validi, arità
   del mapping;
4. `qualitativeHistoryIsPersistedAcrossGenerations`: manifest allo schema 3 senza eventi e allo
   schema 4 con eventi; una nuova importazione conserva radice ed eventi; riapertura con proiezione
   identica; predecessore non corrente e categoria assente rifiutati senza cambiare generazione;
5. `tamperedQualitativeEventIsDetected`: un byte modificato in un evento rende il package non
   apribile;
6. `schemaThreeStoreMigratesToQualitativeHistory`: uno store riportato allo schema 3 migra allo
   schema 4, accetta eventi e si riapre;
7. l'intera suite esistente (persistenza, recovery SIGKILL, indagine, export) resta verde;
8. `check-recovery-kill.sh` termina con SIGKILL un processo al commit di un evento qualitativo in
   ciascuno dei sei checkpoint (staged, objectPromoted, databasePrepared, manifestPrepared,
   manifestReplaced, databaseCommitted): prima della sostituzione del manifest la riapertura vede
   la generazione precedente senza eventi e il retry registra l'evento; dopo, l'evento è
   autorevole. Le righe lasciate da una generazione preparata e mai committata sono ignorate
   all'apertura e sostituite al retry. Totale: 22 checkpoint validi.

## Limiti

La validazione dell'intervallo codificato sul testo della fonte avviene nel motore (C3). Il commit
qualitativo è coperto dalla prova SIGKILL; power-loss e migrazione N-1 restano aperti come per gli
altri commit.

## Esito

**Superato localmente: la storia qualitativa è persistita come radice append-only verificata e
compatibile con i package esistenti.**
