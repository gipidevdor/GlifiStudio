<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-019 — Package `.glifi` transazionale

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-019 |
| Tipo | Evidenza di verifica di persistenza e contratto headless |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-15 |
| Approvazione | Evidenza osservata parziale di TV-001, TV-002, TV-051, TV-060, TV-071–TV-073 |

## Ambito

- creazione e riapertura di package `.glifi` v1 senza sovrascrittura implicita;
- manifest radice bounded come unico commit point;
- SQLite di sistema in modalità rollback journal, foreign key abilitate e
  `synchronous = FULL`;
- fonti incorporate come oggetti immutabili content-addressed SHA-256;
- generazioni append-only `prepared`/`committed`, writer lease di processo e
  rifiuto di sessioni stale;
- verifica fail-closed di schema, ProjectID, generazione, radici, path, tipo,
  dimensione, symlink, hard link e digest degli oggetti;
- `ProjectSession` actor-isolated tramite GlifiKit con chiusura idempotente;
- comandi GlifiCLI `project create`, `project info`, `project validate` e `import`
  con envelope JSON v1 e codici di uscita tipizzati.

## Procedura

1. creare un progetto vuoto nella fixture temporanea e verificare la generazione
   zero;
2. importare il TXT fixture, riaprire il package e confrontare identità, radice,
   byte originali e profilo;
3. iniettare un'interruzione dopo staging, promozione oggetto, prepare SQLite,
   manifest candidato, sostituzione manifest e marcatura post-commit;
4. verificare che prima della sostituzione resti autorevole `Gₙ` e dopo resti
   autorevole `Gₙ₊₁`;
5. riprovare un commit dopo un candidato abbandonato e verificare la rimozione
   bounded della generazione non raggiungibile;
6. alterare un oggetto incorporato e verificare il rifiuto per `corruption` senza
   modifica del package;
7. ripetere create/import/validate attraverso GlifiCLI e confrontare gli envelope;
8. eseguire `make verify`, incluse build Debug/Release macOS e iPadOS.

## Risultato osservato

- 28 test Swift complessivi superati: 24 GlifiCore e 4 GlifiKit;
- i quattro checkpoint anteriori al commit point riaprono la generazione zero e
  consentono un retry pulito;
- i due checkpoint posteriori al commit point riaprono la generazione uno anche
  senza cleanup completato;
- una modifica ai byte content-addressed rende il package non apribile e conserva
  `readOnlyRecovery` come stato dichiarato;
- CLI e GlifiKit osservano la stessa generazione e lo stesso conteggio sorgenti;
- il quality gate completo termina con esito positivo su Xcode 27 e Apple Swift
  6.4.

## Limiti

L'iniezione descritta da questa evidenza è deterministica all'interno del processo;
la successiva [GS-VER-072](GS-VER-072-process-kill-recovery.md) acquisisce la
terminazione reale per import e Artifact. Restano fuori power-loss, provider
documentale e dispositivi fisici. Recovery read-only verso una generazione
precedente, autosave, migrazione N-1 e indice restano aperti. Analysis DAG ed export
Artifact, JSON/Markdown e PDF/CSV sono acquisiti successivamente da
GS-VER-025, GS-VER-032 e GS-VER-033.

Il writer usa `NSFileCoordinator`, un lock advisory con rilascio automatico del
kernel e un vincolo generazionale SQLite. Il VFS SQLite Apple non accetta il flag
`SQLITE_OPEN_NOFOLLOW` pur esponendolo nell'header; lo store viene quindi validato
con `lstat`, tipo regolare e link count prima dell'apertura. La race residua con una
modifica esterna ostile resta oggetto di fault testing su file provider.

## Esito

**Superato localmente per il prototipo G2 del package, il commit point e la
superficie ProjectSession/CLI dichiarata.** Non promuove l'intera matrice di
recovery né il prodotto a feature complete.
