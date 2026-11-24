<!-- SPDX-License-Identifier: BSD-3-Clause -->

# GS-VER-073 — Recovery read-only verso una generazione precedente

| Campo | Valore |
| --- | --- |
| Identificatore | GS-VER-073 |
| Tipo | Evidenza di verifica della crash consistency |
| Versione | 1.0.0 |
| Stato | Superato localmente con limiti dichiarati |
| Responsabile | Iniziatore del progetto |
| Ultima modifica | 2026-09-17 |
| Approvazione | Evidenza osservata parziale di TV-051 e TV-060 |

## Ambito

- apertura fail-closed `GlifiProjectPackage.openReadOnlyRecovery(at:)` quando la
  generazione riferita dal manifest corrente non supera la verifica integrale;
- ricerca a ritroso, generazione per generazione, della più recente generazione
  interamente verificabile in modo indipendente dal manifest fallito, riusando lo
  stesso oracolo di `openVerified` (root digest di fonti/Artifact/storia
  indagine, oggetti sul disco, grafo DAG raggiungibile, catena predecessori);
- handle `GlifiProjectPackage.ReadOnlyRecovery` con lettura di fonti, Artifact ed
  eventi di indagine della sola generazione recuperata; nessuna operazione di
  scrittura è esposta;
- garanzia che né il manifest né il database né alcun oggetto vengano riscritti
  durante il tentativo di recovery.

## Procedura

1. corrompere l'oggetto sorgente della generazione più recente di un package con
   due import successivi;
2. verificare che `GlifiProjectPackage.open(at:)` rifiuti il package con
   `category == .corruption`;
3. invocare `GlifiProjectPackage.openReadOnlyRecovery(at:)` e verificare che
   restituisca la generazione immediatamente precedente, interamente
   verificata, con la sola fonte ivi presente;
4. leggere la fonte della generazione recuperata e confrontarla byte-per-byte
   con l'importazione originale;
5. verificare che una fonte estranea alla generazione recuperata sia rifiutata
   con `project.source-not-found`;
6. riaprire il package originale con `open(at:)` e verificare che il rifiuto
   persista identico: il recovery non ha alterato nulla;
7. verificare separatamente che un manifest illeggibile faccia fallire anche il
   recovery, perché la generazione di partenza da cui risalire non è nota.

## Oracolo

| Condizione | Esito atteso |
| --- | --- |
| Generazione corrente corrotta, generazione precedente integra | `openReadOnlyRecovery` restituisce quella precedente, read-only |
| Generazione recuperata interrogata su un'identità di un'altra generazione | Rifiuto `insufficientData` senza esporre dati fuori scope |
| Package originale dopo il tentativo di recovery | `open(at:)` fallisce esattamente come prima; nessuna riscrittura |
| Manifest illeggibile | `openReadOnlyRecovery` fallisce con `corruption`, come `open(at:)` |

## Risultato osservato

- il recovery individua correttamente la generazione 1 dopo la corruzione della
  generazione 2, con la sola fonte attesa e byte identici all'origine;
- l'accesso a un'identità fuori dalla generazione recuperata è rifiutato senza
  fallback silenzioso;
- il package originale resta bit-per-bit invariato: una riapertura normale fallisce
  in modo identico prima e dopo il tentativo di recovery;
- un manifest illeggibile fa fallire il recovery allo stesso modo dell'apertura
  normale, perché non esiste una generazione di partenza nota da cui risalire.

## Limiti

Il recovery richiede un manifest leggibile per conoscere la generazione da cui
risalire; non copre un manifest interamente assente o illeggibile, né un database
SQLite non apribile. Non simula `SIGKILL` o power-loss durante il recovery stesso
(il recovery è un percorso di sola lettura, non un commit). Garbage collection,
retention di backup e superfici UI per offrire questo percorso alla persona
restano fuori ambito.

## Esito

**Superato localmente per l'apertura read-only della più recente generazione
precedente interamente verificabile, quando la generazione corrente fallisce la
validazione, senza riscrivere il package originale.** RQ-043 e RQ-059 restano
parziali finché indice, autosave, migrazione N-1 e power-loss non sono acquisiti.
